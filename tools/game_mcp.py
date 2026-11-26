#!/usr/bin/env python3
"""MCP server that lets an agent play a native game window, one turn at a time.

A thin stdio bridge over the file driver in tools/play_driver.gd, whose
header documents the turn JSON. Its ACTIONS and those of game/play_hooks.gd
hold the actions, and the first turn lists them. Standard library only: MCP over stdio is one JSON-RPC
message per line.

.mcp.json at the project root registers it as "game", so Claude Code offers
mcp__game__start, mcp__game__act, mcp__game__click and mcp__game__stop:

  start(path, scene?, seed?)    launches the game for the checkout at `path`
                                (a worktree or the main checkout), or another
                                scene such as a prototype's, with the game's
                                random seed (default 0), and returns the
                                first turn: a screenshot and its JSON, which
                                lists the actions
  act(action, image?)           one driver action, such as {"do": "hover",
                                "x": 388, "y": 426}; returns the next turn
  click(x, y | node, image?)    a left click at pixels of the turns'
                                screenshots, or on a control named by its
                                "node" in the turn's "ui"; returns the next
                                turn
  stop()                        ends the game, also while start or act
                                still waits for a turn; so does cancelling
                                that call

A turn's screenshot is the driver's turn-<k>.jpg, the window at half size,
so the server doubles x, y, to_x and to_y in actions and halves "clicked",
"hovered" and "dragged" in results and each "rect" in "ui"; image false leaves
it out.

One server serves every agent in a Claude Code session, worktree subagents
included, and can't tell their worktrees apart: hence `path`, and a second
start while a game runs is refused with "busy: <path>".

start first imports the checkout's assets, as `mise run import` does, so a
class added since the last import is found. An import that runs past 30 s, as
in a fresh worktree, is stopped, and start asks for `mise run import`. The
game then runs as
  mise exec -- tools/native.sh godot --path . --fixed-fps 60 --script tools/play_driver.gd -- --out=...
in `path`, at 60 frames per second of game time however fast the machine is,
so the same seed and actions replay the same, through this server's tools/native.sh, so on Linux it gets its own
Xvfb display, with XDG_DATA_HOME=<path>/tests/output/userdata as in the mise
test tasks, writing turns to <path>/tests/output/mcp/<time>/ and Godot's output
to <time>.log beside it (the import's to <time>-import.log). Each turn lists
the SCRIPT ERROR lines that log gained since the last turn. The game ends on
stop, when this server exits, and when no action comes within --turn-seconds
(default 300) or the game has run 45 minutes. A first turn that hasn't come
75 s after launch stops the game, so start returns within Claude Code's 120 s.

  python3 tools/game_mcp.py [--turn-seconds=<n>]
  python3 tools/game_mcp.py --self-test   # drives tests/lib/probe.tscn over stdio
"""

import base64
import json
import os
import signal
import subprocess
import queue
import re
import sys
import threading
import time

IMPORT_LIMIT = 30
# Real seconds for the first turn. Claude Code moves a call past 120 s to the
# background, so the import and this stay under it.
START_LIMIT = 75
MAX_ERROR_LINES = 20
# This server's copy, as a checkout from before it has none.
NATIVE = os.path.join(os.path.dirname(os.path.realpath(__file__)), "native.sh")
SCALE = 2           # window pixels per turn-<k>.jpg pixel
# Godot runs at this many frames per game second, however fast the machine is,
# so the same actions run the same frames and physics ticks.
FPS = 60

TOOLS = [
    {"name": "start", "description": "Start the game in a native window for the checkout at `path` and return the first turn: a screenshot and what the screen shows as text, with \"actions\", the actions act takes. Imports the assets first; if that takes over 30 s, run `mise run import` in `path` and start again. Refused with \"busy: <path>\" while a game runs; call stop first.",
     "inputSchema": {"type": "object", "properties": {
         "path": {"type": "string", "description": "Absolute path of the checkout or worktree to run"},
         "scene": {"type": "string", "description": "A scene to play instead of the game, such as res://prototypes/<name>/main.tscn. Its turns have no HUD text; read the screenshot."},
         "seed": {"type": "integer", "description": "The seed of the game's randomness (default 0). Each turn's \"seed\" holds it. The same seed and actions replay the same, so use one seed for a before and after, and others to see variety."}},
         "required": ["path"]}},
    {"name": "act", "description": "Apply one action and return the next turn's screenshot and JSON. The first turn's \"actions\" lists each action with its fields and what it does; a checkout without that list documents them in the header of tools/play_driver.gd. An action is {\"do\": <name>, <its fields>}. x and y, and drag's to_x and to_y, are pixels of the turn screenshots, not of the window, which is twice their size. click and hover take \"node\", a path from the turn's \"ui\" list of controls, in place of x and y. Each takes an optional \"wait\" in seconds of game time, run as 60 frames a second however long they take; without one, time stays still and the next turn shows the same moment. Pass image false when the answer is text. A turn's \"events\" lists what the game did since the last turn, with game times. A turn lists any new SCRIPT ERROR lines from the game's log.",
     "inputSchema": {"type": "object", "properties": {
         "action": {"type": "object", "description": "For example {\"do\": \"hover\", \"x\": 388, \"y\": 426}, {\"do\": \"click\", \"node\": \"Main/Box/Button\"}, {\"do\": \"key\", \"key\": \"Escape\"}, {\"do\": \"hold\", \"keys\": [\"W\", \"D\"], \"seconds\": 0.5} or {\"do\": \"wait\", \"wait\": 2}"},
         "image": {"type": "boolean", "description": "Return the screenshot (default true)"}},
         "required": ["action"]}},
    {"name": "click", "description": "Left-click at x, y, pixels of the turn screenshots, or on a control named by \"node\", a path from the turn's \"ui\", and return the next turn. Time stays still; to see an animation finish, use act with {\"do\": \"click\", \"x\": ..., \"y\": ..., \"wait\": 0.3}.",
     "inputSchema": {"type": "object", "properties": {"x": {"type": "number"}, "y": {"type": "number"}, "node": {"type": "string", "description": "A \"node\" from the turn's \"ui\", in place of x and y"}, "image": {"type": "boolean", "description": "Return the screenshot (default true)"}}}},
    {"name": "stop", "description": "End the game. Also ends a start or act that is still waiting for its turn.", "inputSchema": {"type": "object", "properties": {}}},
]


class Session:
    def __init__(self, path, out, log, proc):
        self.path, self.out, self.log, self.proc = path, out, log, proc
        self.turn = 0
        self.stopped_on_request = False
        self.seen = 0       # bytes of the log already checked for script errors

    # The whole group (xvfb-run, Xvfb and Godot) is the game, and xvfb-run can
    # exit before Godot does, so the group, not xvfb-run, says whether it runs.
    def running(self):
        self.proc.poll()   # reaps xvfb-run, so a dead one doesn't count
        try:
            os.killpg(self.proc.pid, 0)
            return True
        except (ProcessLookupError, PermissionError):
            return False

    def stop(self):
        for sig in (signal.SIGTERM, signal.SIGKILL):
            if not self.running():
                break
            os.killpg(self.proc.pid, sig)
            deadline = time.monotonic() + 5
            while self.running() and time.monotonic() < deadline:
                time.sleep(0.1)
        self.proc.wait()

    # The first parse or compile error in the log, or "". Godot keeps running
    # after one, so without this check start would wait out START_LIMIT.
    def script_error(self):
        try:
            with open(self.log, encoding="utf-8", errors="replace") as file:
                return next((line.strip() for line in file if "Parse Error:" in line or "Compile Error:" in line), "")
        except OSError:
            return ""

    # The SCRIPT ERROR lines, each with its "at:" line, that the log gained
    # since the last call. Plain ERROR lines are left out: they include noise
    # such as the ALSA ERR_CANT_OPEN of every session.
    def new_errors(self):
        try:
            with open(self.log, "rb") as file:
                file.seek(self.seen)
                chunk = file.read()
        except OSError:
            return []
        chunk = chunk[:chunk.rfind(b"\n") + 1]   # a line still being written waits for the next turn
        self.seen += len(chunk)
        lines, found = chunk.decode("utf-8", "replace").splitlines(), []
        for index, line in enumerate(lines):
            if line.startswith("SCRIPT ERROR"):
                found.append(line)
                if index + 1 < len(lines) and lines[index + 1].lstrip().startswith("at:"):
                    found.append(lines[index + 1])
        if len(found) > MAX_ERROR_LINES:
            found = found[:MAX_ERROR_LINES] + [f"... {len(found) - MAX_ERROR_LINES} more lines in {self.log}"]
        return found

    def log_tail(self, lines=15):
        try:
            with open(self.log, encoding="utf-8", errors="replace") as file:
                return "".join(file.readlines()[-lines:])
        except OSError:
            return ""


class Server:
    def __init__(self, turn_seconds):
        self.turn_seconds = turn_seconds
        self.session = None
        # The stdin reader thread counts stop calls and notes cancelled request
        # ids as they arrive, so a turn wait can end before they are handled.
        self.stops_read = self.stops_handled = 0
        self.cancelled = set()
        self.current = None   # id of the request being handled

    # A stop call is queued behind this one, or this one was cancelled.
    def interrupted(self):
        return self.stops_read > self.stops_handled or self.current in self.cancelled

    def call(self, name, args):
        self.stops_handled += name == "stop"
        tool ={"start": self.start, "act": self.act, "click": self.click, "stop": self.stop}.get(name)
        if tool is None:
            return error(f"Unknown tool {name}")
        try:
            return tool(**args)
        except TypeError as problem:
            return error(f"{name}: {problem}")

    def start(self, path, scene=None, seed=None):
        if self.session and self.session.running():
            return error(f"busy: {self.session.path}")
        path = os.path.realpath(path)
        if not os.path.isfile(os.path.join(path, "tools", "play_driver.gd")):
            return error(f"{path} is not a checkout of this game")
        if scene is not None and not (isinstance(scene, str) and scene.startswith("res://") and os.path.isfile(os.path.join(path, scene.removeprefix("res://")))):
            return error(f"No scene at {scene} in {path}; give a res:// path such as res://prototypes/<name>/main.tscn")
        if seed is not None and type(seed) is not int:   # not a bool, which Python counts as an int
            return error(f"seed must be a whole number, not {json.dumps(seed)}")
        out = os.path.join(path, "tests", "output", "mcp", time.strftime("%Y%m%d-%H%M%S"))
        while os.path.exists(out + ".log"):
            out += "b"
        os.makedirs(os.path.dirname(out), exist_ok=True)
        options = [f"--out={os.path.relpath(out, path)}", f"--turn-seconds={self.turn_seconds}"]
        # Only when given, so a checkout whose driver predates --scene or --seed still starts.
        if scene is not None:
            options.append(f"--scene={scene}")
        if seed is not None:
            options.append(f"--seed={seed}")
        command = ["mise", "exec", "--", NATIVE, "godot", "--path", ".", "--fixed-fps", str(FPS), "--script", "tools/play_driver.gd", "--"] + options
        # Test saves go to the worktree, as in the mise test tasks; mise keeps its shared tools (README, "Verify").
        shared = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
        env = dict(os.environ, XDG_DATA_HOME=os.path.join(path, "tests", "output", "userdata"),
                   MISE_DATA_DIR=os.environ.get("MISE_DATA_DIR") or os.path.join(shared, "mise"))
        log, import_log = out + ".log", out + "-import.log"
        # Its own log, as an import with a stale class cache prints parse errors that the import then resolves.
        with open(import_log, "w") as file:
            importer = subprocess.Popen(["mise", "exec", "--", "godot", "--headless", "--editor", "--path", ".", "--import"], cwd=path, stdin=subprocess.DEVNULL, stdout=file, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            if importer.wait(IMPORT_LIMIT):
                return error(f"The asset import failed; run `mise run import` in {path} to see why. Its log, {import_log}, ends:\n{Session(path, out, import_log, importer).log_tail()}")
        except subprocess.TimeoutExpired:
            Session(path, out, import_log, importer).stop()   # ends the whole process group
            return error(f"The asset import ran past {IMPORT_LIMIT} s, so it was stopped. Run `mise run import` in {path}, then start again.")
        with open(log, "w") as file:
            proc = subprocess.Popen(command, cwd=path, env=env, stdin=subprocess.DEVNULL, stdout=file, stderr=subprocess.STDOUT, start_new_session=True)
        self.session = Session(path, out, log, proc)
        return self.next_turn(START_LIMIT)

    def act(self, action, image=True):
        if not isinstance(action, dict):
            return error("action must be a JSON object")
        session = self.session
        if session is None or not session.running():
            return error("No game is running; call start." + (f" The last one ended:\n{session.log_tail()}" if session else ""))
        action = {key: value * SCALE if key in ("x", "y", "to_x", "to_y") and type(value) in (int, float) else value for key, value in action.items()}
        target = os.path.join(session.out, "action-%03d.json" % session.turn)
        with open(target + ".tmp", "w") as file:
            json.dump(action, file)
        # The driver reads the file once it exists, so it must appear whole.
        os.replace(target + ".tmp", target)
        return self.next_turn(None, image)

    def click(self, x=None, y=None, node=None, image=True):
        given = {"x": x, "y": y, "node": node}
        return self.act({"do": "click", **{key: value for key, value in given.items() if value is not None}}, image)

    def stop(self):
        if self.session is None:
            return text("No game was running.")
        was_running = self.session.running() or self.session.stopped_on_request
        self.session.stopped_on_request = False
        self.session.stop()
        return text(("Stopped" if was_running else "The game had already ended") + f"; files in {self.session.out}")

    def next_turn(self, limit, image=True):
        session = self.session
        base = os.path.join(session.out, "turn-%03d" % (session.turn + 1))
        began = time.monotonic()
        while not os.path.exists(base + ".json"):
            if self.interrupted():
                session.stop()
                session.stopped_on_request = True
                return error(f"Stopped before turn {session.turn + 1}, as asked; files in {session.out}")
            if not session.running():
                return error(f"The game ended before turn {session.turn + 1}:\n{session.log_tail()}")
            if session.turn == 0 and (problem := session.script_error()):
                session.stop()
                return error(f"The game scripts don't compile, so the game was stopped. If a class can't be found, run `mise run import` in {session.path}. First error, of the log {session.log}:\n{problem}")
            if limit and time.monotonic() - began > limit:
                session.stop()
                return error(f"No first turn after {limit} s, so the game was stopped.\n{session.log_tail()}")
            time.sleep(0.2)
        session.turn += 1
        with open(base + ".json", encoding="utf-8") as file:
            state = json.load(file)
        last = state.get("last_action")
        for key in ("clicked", "hovered", "dragged"):
            if isinstance(last, dict) and isinstance(last.get(key), list):
                last[key] = [value // SCALE for value in last[key]]
        for control in state.get("ui", []):
            control["rect"] = [value // SCALE for value in control["rect"]]
        note = f"Turn {session.turn}, {base}.png"
        if problems := session.new_errors():
            note += f"\nScript errors since the last turn, from {session.log}:\n" + "\n".join(problems)
        content = [{"type": "text", "text": note + "\n" + json.dumps(state, ensure_ascii=False)}]
        if image:
            with open(base + ".jpg", "rb") as file:
                data = base64.b64encode(file.read()).decode()
            content.insert(0, {"type": "image", "data": data, "mimeType": "image/jpeg"})
        return {"content": content}

    def shutdown(self):
        if self.session:
            self.session.stop()


def text(message):
    return {"content": [{"type": "text", "text": message}]}


def error(message):
    return {"content": [{"type": "text", "text": message}], "isError": True}


def handle(server, message):
    method, params = message.get("method"), message.get("params") or {}
    if method == "initialize":
        return {"protocolVersion": params.get("protocolVersion", "2025-06-18"), "capabilities": {"tools": {}}, "serverInfo": {"name": "game", "version": "1"}}
    if method == "ping":
        return {}
    if method == "tools/list":
        return {"tools": TOOLS}
    if method == "tools/call":
        return server.call(params.get("name"), params.get("arguments") or {})
    raise LookupError(method)


def serve(turn_seconds):
    server = Server(turn_seconds)
    for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        signal.signal(sig, lambda *_: sys.exit(0))
    lines = queue.Queue()

    # Requests are still handled one at a time, in order; this thread only
    # looks ahead for a stop or a cancel, which a turn wait can't otherwise see.
    def read():
        for line in sys.stdin:
            try:
                message = json.loads(line)
            except ValueError:
                message = None   # the main loop raises on it, as before
            if isinstance(message, dict):
                params = message.get("params") if isinstance(message.get("params"), dict) else {}
                if message.get("method") == "tools/call" and params.get("name") == "stop":
                    server.stops_read += 1
                elif message.get("method") == "notifications/cancelled":
                    server.cancelled.add(params.get("requestId"))
            lines.put(line)
        lines.put(None)

    threading.Thread(target=read, daemon=True).start()
    try:
        for line in iter(lines.get, None):
            if not line.strip():
                continue
            message = json.loads(line)
            if "id" not in message:
                continue   # notifications, such as notifications/initialized
            reply = {"jsonrpc": "2.0", "id": message["id"]}
            server.current = message["id"]
            try:
                reply["result"] = handle(server, message)
            except LookupError as method:
                reply["error"] = {"code": -32601, "message": f"Unknown method {method}"}
            server.current = None
            sys.stdout.write(json.dumps(reply) + "\n")
            sys.stdout.flush()
    finally:
        server.shutdown()


# ---------------------------------------------------------------- self-test

def self_test():
    """Drives the server over stdio against a native window: initialize,
    tools/list, start, act, click and stop on tests/lib/probe.tscn, then
    checks that no process of a game outlives stop, an idle timeout or the
    server's exit."""
    path = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
    turn_seconds = 20
    proc = None
    ids = iter(range(1, 1000))

    def launch(seconds=turn_seconds):
        return subprocess.Popen([sys.executable, os.path.realpath(__file__), f"--turn-seconds={seconds}"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)

    def rpc(method, params=None):
        number = next(ids)
        proc.stdin.write(json.dumps({"jsonrpc": "2.0", "id": number, "method": method, "params": params or {}}) + "\n")
        proc.stdin.flush()
        reply = json.loads(proc.stdout.readline())
        assert reply["id"] == number, reply
        return reply["result"]

    def tool(name, **args):
        result = rpc("tools/call", {"name": name, "arguments": args})
        words = [c["text"] for c in result["content"] if c["type"] == "text"]
        print(f"{name}{args}: {'ERROR ' if result.get('isError') else ''}{words[0][:200] if words else ''}", flush=True)
        return result

    def turn(result, image=True):
        assert not result.get("isError"), result
        kinds = [c["type"] for c in result["content"]]
        assert kinds == (["image", "text"] if image else ["text"]), kinds
        if image:
            assert base64.b64decode(result["content"][0]["data"])[:3] == b"\xff\xd8\xff"
            print(f"  image {len(result['content'][0]['data']) // 1024} KiB as base64", flush=True)
        body = result["content"][-1]["text"]
        # A renamed private function the driver calls shows here first.
        assert "\nScript errors since the last turn" not in body, body
        return body.split("\n", 1)[0], json.loads(body.split("\n", 1)[1])

    def start(**args):
        return tool("start", path=path, **args)

    def game_time(state):
        return float(re.search(r", time ([\d.]+) s,", state["ui"][0]["text"])[1])

    def folder(note):
        return note.split(", ", 1)[1].rsplit("/", 1)[0]

    def gone(note, seconds):
        # Every process of a session (xvfb-run, Godot) but Xvfb carries its --out.
        deadline = time.monotonic() + seconds
        while subprocess.run(["pgrep", "-f", "--", f"--out=tests/output/mcp/{os.path.basename(out)}"], stdout=subprocess.DEVNULL).returncode == 0:
            assert time.monotonic() < deadline, f"{note}: the game still runs after {seconds} s"
            time.sleep(1)
        print(f"PASS: the game is gone {note}", flush=True)

    sample = os.path.join(path, "tests/output/mcp-self-test.log")
    os.makedirs(os.path.dirname(sample), exist_ok=True)
    with open(sample, "w") as file:
        file.write("PLAY START\nSCRIPT ERROR: Parse Error: Could not find type \"Hud\" in the current scope.\nSCRIPT ERROR: Compile Error: Failed to compile depended scripts.\n")
    assert Session(path, None, sample, None).script_error() == "SCRIPT ERROR: Parse Error: Could not find type \"Hud\" in the current scope."
    with open(sample, "w") as file:
        file.write("PLAY START\nERROR: some runtime warning\n")
    assert Session(path, None, sample, None).script_error() == ""
    print("PASS: a parse or compile error in the log is found", flush=True)
    with open(sample, "w") as file:
        file.write("PLAY START\nERROR: Condition \"status < 0\" is true. Returning: ERR_CANT_OPEN\n   at: init_output_device (drivers/alsa/audio_driver_alsa.cpp:97)\n")
    session = Session(path, None, sample, None)
    assert session.new_errors() == []
    with open(sample, "a") as file:
        file.write("SCRIPT ERROR: Invalid call. Nonexistent function 'foo' in base 'Nil'.\n          at: _on_click (res://game/hud.gd:12)\nERROR: other\nSCRIPT ERROR: half a li")
    assert session.new_errors() == ["SCRIPT ERROR: Invalid call. Nonexistent function 'foo' in base 'Nil'.", "          at: _on_click (res://game/hud.gd:12)"]
    with open(sample, "a") as file:
        file.write("ne\n" + "SCRIPT ERROR: again\n" * 30)
    found = session.new_errors()
    assert found[0] == "SCRIPT ERROR: half a line" and len(found) == MAX_ERROR_LINES + 1 and found[-1].startswith("... 11 more"), found
    assert session.new_errors() == []
    os.remove(sample)
    print("PASS: a turn gets only the new SCRIPT ERROR lines, without the ERR_CANT_OPEN noise", flush=True)

    global IMPORT_LIMIT
    limit = IMPORT_LIMIT
    IMPORT_LIMIT = 0.01   # too short for any import, as 30 s can be in a fresh worktree
    slow = Server(turn_seconds).start(path)
    IMPORT_LIMIT = limit
    assert slow.get("isError") and "`mise run import` in" in slow["content"][0]["text"], slow
    print("PASS: start stops a slow import and asks for `mise run import`", flush=True)

    proc = launch()
    info = rpc("initialize", {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "self-test", "version": "1"}})
    assert info["capabilities"] == {"tools": {}}, info
    proc.stdin.write(json.dumps({"jsonrpc": "2.0", "method": "notifications/initialized"}) + "\n")
    names = sorted(t["name"] for t in rpc("tools/list")["tools"])
    assert names == ["act", "click", "start", "stop"], names
    print("PASS: initialize and tools/list", flush=True)

    # A stop or a cancel ends a start still waiting for its first turn.
    def send(message):
        proc.stdin.write(json.dumps({"jsonrpc": "2.0", **message}) + "\n")
        proc.stdin.flush()

    def reply():
        return json.loads(proc.stdout.readline())

    began = time.monotonic()
    send({"id": "waiting", "method": "tools/call", "params": {"name": "start", "arguments": {"path": path}}})
    send({"id": "stop", "method": "tools/call", "params": {"name": "stop", "arguments": {}}})
    started, stopped = reply(), reply()
    assert started["id"] == "waiting" and "Stopped before turn 1" in started["result"]["content"][0]["text"], started
    assert stopped["id"] == "stop" and stopped["result"]["content"][0]["text"].startswith("Stopped;"), stopped
    send({"id": "cancelled", "method": "tools/call", "params": {"name": "start", "arguments": {"path": path}}})
    time.sleep(1)   # into the import or the launch, well before turn 1
    send({"method": "notifications/cancelled", "params": {"requestId": "cancelled"}})
    started = reply()
    waited = time.monotonic() - began
    assert started["id"] == "cancelled" and "Stopped before turn 1" in started["result"]["content"][0]["text"], started
    tool("stop")
    print(f"PASS: a stop or a cancel ends a waiting start; both took {waited:.0f} s", flush=True)

    # The actions run on tests/lib/probe.tscn, not the game, so this test passes
    # whatever the game does. The probe is one button over the whole window,
    # and a press shows in its tooltip. It reads current_scene in _ready(), so
    # turn 1 lists a SCRIPT ERROR unless the driver sets it first, as a normal
    # launch does. A missing scene or a non-string is refused before anything
    # launches.
    for scene in ("res://prototypes/missing/main.tscn", 5):
        missing = tool("start", path=path, scene=scene)
        assert missing.get("isError") and missing["content"][0]["text"].startswith("No scene at"), missing
    note, state = turn(start(scene="res://tests/lib/probe.tscn"))
    out = folder(note)
    actions = state.pop("actions")
    ui = state.pop("ui")
    assert state == {"turn": 1, "seed": 0, "last_action": {}, "screen_fields": [], "events": []}, state
    assert len(ui) == 1 and ui[0]["rect"][:2] == [0, 0], ui
    probe = ui[0]
    assert {key: probe[key] for key in ("node", "class", "disabled", "tooltip")} == {"node": "Probe", "class": "Button", "disabled": False, "tooltip": "Clicks: 0"}, probe
    assert re.fullmatch(r"Probe scene, clicks: 0, time [\d.]+ s, roll \d+", probe["text"]), probe
    print(f"PASS: the turn lists the probe's button in \"ui\" with its text: {probe}", flush=True)
    print("PASS: start refuses a missing scene and plays another one, without the game's HUD text", flush=True)
    fields = {action["name"]: action["fields"] for action in actions if action.get("description")}
    template = {"click": ["x", "y", "node", "button"], "drag": ["x", "y", "node", "to_x", "to_y"], "hover": ["x", "y", "node"], "key": ["key"], "hold": ["keys", "seconds"], "wait": []}
    assert {name: fields.get(name) for name in template} == template, actions
    print(f"PASS: the first turn lists the actions, with their fields and descriptions: {', '.join(fields)}", flush=True)
    busy = tool("start", path=path)
    assert busy.get("isError") and busy["content"][0]["text"] == f"busy: {path}", busy
    print("PASS: a second start is refused", flush=True)
    note, state = turn(tool("click", x=99999, y=0, image=False), image=False)
    assert not state["last_action"]["ok"] and "outside" in state["last_action"]["reason"], state["last_action"]
    note, state = turn(tool("click", x=20, y=20))
    assert state["last_action"] == {"ok": True, "clicked": [20, 20]}, state["last_action"]
    with open(os.path.join(out, "action-%03d.json" % 2)) as file:
        written = json.load(file)
    assert [written["x"], written["y"]] == [40, 40], written
    print("PASS: click refuses a point outside the window and clicks one inside, at twice the image's pixels", flush=True)
    note, state = turn(tool("act", action={"do": "hover", "x": 20, "y": 20}))
    assert state["last_action"]["ok"] and state["last_action"]["tooltip"] == ["Clicks: 1"], state["last_action"]
    print(f"PASS: hover opens the tooltip, which shows the click counted once; see {note.split(', ', 1)[1]}", flush=True)
    note, state = turn(tool("click", node="Probe", image=False), image=False)
    middle = [probe["rect"][0] + probe["rect"][2] / 2, probe["rect"][1] + probe["rect"][3] / 2]
    clicked = state["last_action"].get("clicked", [])
    assert state["last_action"]["ok"] and state["last_action"]["node"] == "Probe" and all(abs(a - b) <= 1 for a, b in zip(clicked, middle)) and len(clicked) == 2, (state["last_action"], middle)
    assert state["ui"][0]["text"].startswith("Probe scene, clicks: 2, time"), state["ui"]
    for action in ({"do": "click", "node": "Probe/Missing"}, {"do": "hover", "node": "Probe", "x": 1, "y": 1}):
        note, state = turn(tool("act", action=action, image=False), image=False)
        assert not state["last_action"]["ok"], state["last_action"]
    print("PASS: a click by node lands in the middle of its rect and counts as one by pixel does; a missing node or node with x and y is refused", flush=True)
    note, state = turn(tool("act", action={"do": "key", "key": "Escape"}, image=False), image=False)
    assert state["last_action"] == {"ok": True, "pressed": "Escape"}, state["last_action"]
    note, state = turn(tool("act", action={"do": "key", "key": "NoSuchKey"}, image=False), image=False)
    assert not state["last_action"]["ok"], state["last_action"]
    note, state = turn(tool("act", action={"do": "wait", "wait": 0.2, "typo": 1}, image=False), image=False)
    assert not state["last_action"]["ok"] and "typo" in state["last_action"]["reason"], state["last_action"]
    note, state = turn(tool("act", action={"do": "dance"}, image=False), image=False)
    assert not state["last_action"]["ok"] and all(name in state["last_action"]["reason"] for name in fields), state["last_action"]
    before = game_time(state)
    note, state = turn(tool("act", action={"do": "wait", "wait": 1}, image=False), image=False)
    assert state["last_action"]["ok"] and abs(game_time(state) - before - 1) < 0.001, (before, state["ui"])
    print("PASS: key, a refused key, a refused field, an unknown action and a wait of 1 s of game time", flush=True)
    # The probe shows each key that stayed down while time ran, with its game
    # time down, and the keys down now. W, not Space: the focused button takes Space.
    note, state = turn(tool("act", action={"do": "hold", "keys": ["W", "D"], "seconds": 0.5}, image=False), image=False)
    assert state["last_action"] == {"ok": True, "held": ["W", "D"], "seconds": 0.5}, state["last_action"]
    shown = state["ui"][0]["text"]
    held = {name: float(seconds) for name, seconds in re.findall(r", (\w+) held ([\d.]+) s", shown)}
    assert set(held) == {"W", "D"} and all(abs(seconds - 0.5) <= 0.02 for seconds in held.values()) and "down:" not in shown, shown
    print(f"PASS: hold keeps W and D down for 0.5 s of game time and releases them before the next turn: {shown}", flush=True)
    for action in ({"do": "hold", "keys": ["W", "NoSuchKey"], "seconds": 0.5}, {"do": "hold", "keys": ["W"], "seconds": 11}, {"do": "hold", "keys": [], "seconds": 1}, {"do": "hold", "keys": "W", "seconds": 1}):
        note, state = turn(tool("act", action=action, image=False), image=False)
        assert not state["last_action"]["ok"] and state["ui"][0]["text"] == shown, (state["last_action"], state["ui"])
    print("PASS: hold refuses an unknown key, more than 10 s and keys that aren't a list, before pressing anything", flush=True)
    note, state = turn(tool("act", action={"do": "click", "x": 20, "y": 20, "button": "right"}, image=False), image=False)
    assert state["last_action"] == {"ok": True, "clicked": [20, 20], "button": "right"}, state["last_action"]
    assert state["ui"][0]["text"].startswith("Probe scene, clicks: 2, right clicks: 1,"), state["ui"]
    note, state = turn(tool("act", action={"do": "click", "x": 20, "y": 20, "button": "side"}, image=False), image=False)
    assert not state["last_action"]["ok"], state["last_action"]
    print("PASS: a right click reaches the probe as one, without a left click; an unknown button is refused", flush=True)
    note, state = turn(tool("act", action={"do": "drag", "x": 20, "y": 20, "to_x": 200, "to_y": 100}))
    assert state["last_action"] == {"ok": True, "dragged": [20, 20, 200, 100]}, state["last_action"]
    dragged = re.search(r", dragged 40,40 to 400,200 in (\d+) moves", state["ui"][0]["text"])
    assert dragged and int(dragged[1]) > 1, state["ui"]
    for action in ({"do": "drag", "x": 20, "y": 20, "to_x": 99999, "to_y": 0}, {"do": "drag", "x": 20, "y": 20}):
        note, state = turn(tool("act", action=action, image=False), image=False)
        assert not state["last_action"]["ok"], state["last_action"]
    print(f"PASS: a drag presses the left button, moves over {dragged[1]} frames with it down and releases at its end; an end outside the window or none is refused", flush=True)
    # Godot stopped (SIGSTOP) ignores SIGTERM while xvfb-run exits on it; stop must still end it.
    # ps, not pgrep -a: on macOS -a means ancestors and prints bare PIDs.
    listed = [line.split() for line in subprocess.run(["ps", "-A", "-o", "pid=,args="], capture_output=True, text=True).stdout.splitlines() if f"--out=tests/output/mcp/{os.path.basename(out)}" in line]
    frozen = [int(fields[0]) for fields in listed if "xvfb-run" not in map(os.path.basename, fields[1:3])]
    assert frozen, listed
    for pid in frozen:
        os.kill(pid, signal.SIGSTOP)
    assert "Stopped" in tool("stop")["content"][0]["text"]
    gone("after stop, with Godot ignoring SIGTERM", 15)

    # Two sessions with the same seed and actions write the same turns, though
    # the second thinks longer between turns; another seed draws other numbers.
    # Only click, hold and wait: hover and drag wait on the pointer's real
    # events, which come when the display sends them.
    def replay(seed, pause):
        session_out = None
        states = []
        for index, action in enumerate([None, {"do": "click", "node": "Probe", "wait": 0.3}, {"do": "hold", "keys": ["W"], "seconds": 0.5, "wait": 0.2}, {"do": "wait", "wait": 1}]):
            time.sleep(pause)
            note, state = turn(start(scene="res://tests/lib/probe.tscn", seed=seed) if action is None else tool("act", action=action, image=False), image=action is None)
            session_out = session_out or folder(note)
            states.append(state)
        tool("stop")
        with open(os.path.join(session_out, "actions.jsonl")) as file:
            assert [json.loads(line)["seed"] for line in file] == [seed] * 3
        return states

    for bad in ("7", True, 1.5):
        refused = tool("start", path=path, scene="res://tests/lib/probe.tscn", seed=bad)
        assert refused.get("isError") and refused["content"][0]["text"].startswith("seed must be"), refused
    first, second = replay(7, 0), replay(7, 2)
    assert first == second, (first, second)
    assert all(state["seed"] == 7 for state in first) and abs(game_time(first[-1]) - game_time(first[0]) - 2.0) < 0.001, first
    other = replay(8, 0)
    rolls = [[re.search(r"roll (\d+)", state["ui"][0]["text"])[1] for state in states] for states in (first, other)]
    assert all(a != b for a, b in zip(*rolls)), rolls
    print(f"PASS: two sessions with seed 7 and the same actions write the same turns, one with 2 s pauses; seed 8 draws other numbers: {first[-1]['ui'][0]['text']}", flush=True)
    print("PASS: start refuses a seed that isn't a whole number", flush=True)

    # The game itself, through Fixture.launch. Only the turn is checked, not
    # its HUD text, which is the game's.
    note, state = turn(start())
    out = folder(note)
    assert state["turn"] == 1 and state["last_action"] == {} and isinstance(state["events"], list), state
    print("PASS: start plays the game and returns turn 1, with its events", flush=True)
    proc.stdin.close()
    assert proc.wait(30) == 0
    gone("after the server exits", 15)

    # A server with a short turn limit, so the idle wait stays short.
    idle_seconds = 3
    proc = launch(idle_seconds)
    out = folder(turn(start(scene="res://tests/lib/probe.tscn"))[0])
    print(f"Idle for {idle_seconds} s, the turn limit", flush=True)
    gone("after the idle timeout", idle_seconds + 90)
    late = tool("act", action={"do": "wait"})
    assert late.get("isError") and "TURN TIMEOUT" in late["content"][0]["text"], late
    print("PASS: act after the timeout says the game ended, and why", flush=True)
    tool("stop")
    proc.stdin.close()
    assert proc.wait(30) == 0
    print("SELF-TEST OK", flush=True)


if __name__ == "__main__":
    arguments = sys.argv[1:]
    if arguments == ["--self-test"]:
        self_test()
    elif all(a.startswith("--turn-seconds=") for a in arguments) and len(arguments) <= 1:
        serve(arguments[0].split("=", 1)[1] if arguments else "300")
    else:
        sys.exit(__doc__)
