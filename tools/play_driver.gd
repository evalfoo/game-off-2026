extends SceneTree

# Lets an agent play the real game in a native window, one turn at a time,
# through files. tools/game_mcp.py wraps it as an MCP server; an agent can also
# drive it directly. Saves go to <out>/saves, never the player's folder.
#
# This file is generic: tools/update.sh copies it from the template. The game's
# part, its HUD text, events and own actions, lives in game/play_hooks.gd,
# which the driver loads when it plays the game, and does without when the
# game has none.
#
#   mise exec -- tools/native.sh godot --path . --fixed-fps 60 \
#       --script tools/play_driver.gd -- --out=<new folder> [--seed=0] \
#       [--turn-seconds=300] [--session-seconds=2700] \
#       [--scene=res://prototypes/<name>/main.tscn] [--replay=<old folder>]
#
# --fixed-fps 60 is Godot's own option. It makes each frame 1/60 s of game
# time, however fast or busy the machine is. With it, the same --seed and actions
# replay the same, so two sessions compare like with like. --seed (default 0)
# goes to the game's rng_seed through tests/lib/fixture.gd, and to a --scene
# scene that declares rng_seed. --scene plays that scene instead of the game,
# such as a prototype. Its turns have no HUD text, so read the screenshots.
#
# Start it in the background, then play turns from another shell, waiting for
# each turn like this:
#   until [ -e <out>/turn-003.json ]; do sleep 1; done
#
#   1. At each turn k (001, 002, ...) Godot stops time and writes turn-<k>.png
#      (the window), turn-<k>.jpg (the same at half size) and then
#      turn-<k>.json (what the screen shows, below).
#   2. The agent reads them and writes action-<k>.json. Write it to another
#      name and `mv` it into place, so Godot never reads half a file.
#   3. Godot applies the action, logs it with the seed and its result to
#      actions.jsonl, and runs time for the action's wait. Then turn k+1
#      begins.
#
#   If no action-<k>.json arrives within --turn-seconds real seconds, the run
#   stops with TURN TIMEOUT, so a dead agent can't keep the game running. The
#   whole run stops after --session-seconds real seconds.
#
#   Actions, one per turn: ACTIONS below, and the game's own in
#   game/play_hooks.gd, name each with its fields and a line on what it does,
#   and turn-001.json lists them as "actions". An action is
#   {"do": <name>, <its fields>}, such as {"do": "click", "x": 720, "y": 450},
#   with x and y in window pixels, as in turn-<k>.png. Every action also takes
#   "why", free text kept in actions.jsonl, and "wait": seconds of game time
#   to run before the next turn (default 0, or 1 for "wait"), counted in
#   frames (60 a second with --fixed-fps 60), not on the clock. With 0 time
#   stays still, so the next turn shows the same moment; give a click a short
#   wait, such as 0.3, when the next image should show its animation done. A
#   field an action doesn't take is refused, so a typo can't quietly fall back
#   to a default. A refused action skips its wait, with the reason in
#   last_action.
#
#   turn-<k>.json holds:
#     turn, seed, last_action ({"ok": true, ...} or {"ok": false, "reason": ...}),
#     the fields of screen() in game/play_hooks.gd: what the screen shows, as
#     text,
#     and "ui": the controls in view that a player can read or press (buttons,
#     labels, text fields, ranges, lists and any control with a tooltip), each
#     {"node", "class", "text", "rect", "disabled"} and "tooltip" when it has
#     one. "node" is its path below the window root, such as "Main/Box/Button",
#     and "rect" is [x, y, width, height] in window pixels. Controls inside a
#     Window node, such as a dialog or popup, aren't listed.
#     "events": what the game did since the last turn, in order, each
#     {"event": <name>, "time": <game seconds since the start>, ...its fields},
#     such as {"event": "pressed", "time": 3.52, "node": "Button"}; turn 1
#     holds those of the launch. At most MAX_EVENTS per turn: the rest are
#     left out and "events_dropped" counts them. watch() in
#     game/play_hooks.gd names the events; a --scene run has none.
#     turn-001.json also holds "actions" ([{"name", "fields", "description"}])
#     and "screen_fields", the names of the fields screen() returned.
#
#   click, hover and drag take "node", a path from "ui", in place of x and y.
#   The pointer then moves to the middle of the node's rect and the same real
#   input events follow, so it acts as a player's click would. A missing,
#   hidden, disabled, clipped or covered node, or one that ignores the mouse,
#   is refused. A child button over a parent covers it.
#
#   hold keeps keys down while game time runs for its "seconds", then releases
#   them with time stopped, before its wait. Whatever an action holds is
#   released before the next turn, also when the action is refused halfway,
#   and when the session ends.
#
# Replay: --replay=<old folder> plays an old session's actions.jsonl again, in
# order, without waiting for action files, with the seed it logged; give the
# same --scene as the old session, if it had one, and no --seed. It writes the
# new turns to --out as usual and compares each turn's JSON with the old
# folder's. At the first turn that differs it prints the fields that changed,
# such as `label: "Clicks: 1" -> "Clicks: 2"`, and exits 1; when every turn
# matches it prints REPLAY OK and exits 0. Images aren't compared: both folders
# keep them for a person or an agent to compare. Without --fixed-fps 60, turns
# differ by chance. Hover and drag can too: hover waits for a tooltip on the
# clock, and drag's pointer events come when the display sends them.
#
#   mise exec -- tools/native.sh godot --path . --fixed-fps 60 \
#       --script tools/play_driver.gd -- --out=<new folder> --replay=<old folder>
#
# This header, the actions and turn-001.json are the whole manual an agent
# gets. game/play_hooks.gd says how to add the game's part.

const Fixture := preload("res://tests/lib/fixture.gd")
const Events := preload("res://tests/lib/events.gd")
# The game's part of the driver. See its header.
const HOOKS := "res://game/play_hooks.gd"
# Each action's own fields and what it does, without units: an agent through
# tools/game_mcp.py gives x and y in pixels of the half-size screenshot.
const ACTIONS := {
	"click": {"fields": ["x", "y", "node", "button"], "description": "A click at x, y, or at the middle of a control named by \"node\", a path from \"ui\". The pointer moves there first and stays, as a player's would. \"button\" is left (the default), right or middle."},
	"drag": {"fields": ["x", "y", "node", "to_x", "to_y"], "description": "Presses the left button at x, y, or at the middle of \"node\", moves the pointer to to_x, to_y over a few frames and releases it there. Time stays still during the drag."},
	"hover": {"fields": ["x", "y", "node"], "description": "Rests the pointer at x, y, or at the middle of a control named by \"node\", until a tooltip opens; last_action.tooltip holds its lines, and the next image shows it."},
	"key": {"fields": ["key"], "description": "Presses and releases a key, named as Godot names it, such as Space, Escape, A or F1."},
	"hold": {"fields": ["keys", "seconds"], "description": "Holds keys down, such as [\"W\", \"D\"], while game time runs for \"seconds\" (at most 10), then releases them. Its wait runs after the release."},
	"wait": {"fields": [], "description": "Only lets time run: its wait, or 1 second without one."},
}
const MAX_HOLD_SECONDS := 10.0
const MAX_EVENTS := 50
const MAX_CHANGES := 20
const DRAG_STEPS := 8
const BUTTONS := {"left": MOUSE_BUTTON_LEFT, "right": MOUSE_BUTTON_RIGHT, "middle": MOUSE_BUTTON_MIDDLE}

var options := {"out": "", "seed": "0", "turn-seconds": "300", "session-seconds": "2700", "scene": "", "replay": ""}
var out := ""
var rng_seed := 0
var game: Node
# An instance of HOOKS, when the driver plays the game and the game has one.
var hooks: Object
var turn := 0
var finished := false
var started_ms := 0
var last_result := {}
# The input an action holds down, as the calls that release it. See _press().
var releases: Array[Callable] = []
# Where a drag's pointer is, so a drag cut short releases the button there.
var drag_point := Vector2.ZERO
# Game seconds since the driver started, and the events since the last turn.
var game_time := 0.0
var events: Array[Dictionary] = []
var events_dropped := 0
# With --replay: the old session's folder, and its logged actions by turn.
var replay := ""
var replay_actions := {}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=", true, 1)
		if pair.size() != 2 or not options.has(pair[0]):
			printerr("Unknown option %s. Options: --out= --seed= --turn-seconds= --session-seconds= --scene= --replay=" % arg)
			quit(2)
			return
		options[pair[0]] = pair[1]
	if options.out.is_empty():
		printerr("--out=<new folder> is required")
		quit(2)
		return
	if not options.seed.is_valid_int():
		printerr("--seed=%s is not a whole number" % options.seed)
		quit(2)
		return
	rng_seed = options.seed.to_int()
	if not options.scene.is_empty() and not ResourceLoader.exists(options.scene, "PackedScene"):
		printerr("--scene=%s is not a scene in this project" % options.scene)
		quit(2)
		return
	out = _absolute(options.out)
	if not options.replay.is_empty():
		var problem := _load_replay()
		if not problem.is_empty():
			printerr(problem)
			quit(2)
			return
	DirAccess.make_dir_recursive_absolute(out)
	call_deferred("_run")

func _absolute(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path if path.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(path)

# Reads the old session's actions.jsonl into replay_actions and takes its seed.
# Returns why it can't, or "".
func _load_replay() -> String:
	replay = _absolute(options.replay)
	if replay.simplify_path() == out.simplify_path():
		return "--replay and --out must be different folders"
	if Array(OS.get_cmdline_user_args()).any(func(arg: String) -> bool: return arg.begins_with("--seed=")):
		return "--replay plays with the old session's seed; leave out --seed"
	var logged := replay.path_join("actions.jsonl")
	if not FileAccess.file_exists(logged):
		return "No actions.jsonl in --replay=%s" % options.replay
	# The seed as written, not through JSON's floats, which round one above 2^53.
	# JSON.stringify() sorts the keys, so it comes last but for "turn".
	var seed_text := RegEx.create_from_string("\"seed\":(-?\\d+),\"turn\":\\d+}$")
	for line in FileAccess.get_file_as_string(logged).split("\n", false):
		var entry: Variant = JSON.parse_string(line)
		var found := seed_text.search(line)
		if not entry is Dictionary or not entry.has("turn") or found == null:
			return "%s has a line that isn't a logged action: %s" % [logged, line]
		replay_actions[int(entry.turn)] = entry.get("action")
		rng_seed = found.get_string(1).to_int()
	if replay_actions.is_empty():
		return "%s holds no actions" % logged
	return ""

func _process(delta: float) -> bool:
	game_time += delta
	if started_ms > 0 and not finished and (Time.get_ticks_msec() - started_ms) / 1000.0 >= float(options["session-seconds"]):
		printerr("SESSION TIMEOUT after %s real seconds" % options["session-seconds"])
		_finish(1)
	return false

func _run() -> void:
	started_ms = Time.get_ticks_msec()
	if options.scene.is_empty():
		game = Fixture.launch(root, out.path_join("saves"), rng_seed)
	else:
		var scene := (load(options.scene) as PackedScene).instantiate()
		if "rng_seed" in scene:
			scene.set("rng_seed", rng_seed)
		# Sets current_scene before adding the scene, as a normal launch does, so
		# _ready() sees it and a restart key's reload_current_scene() works.
		# The change happens at the end of the frame.
		change_scene_to_node(scene)
		await process_frame
		game = current_scene
	if options.scene.is_empty():
		_load_hooks()
	root.add_child(PhysicsStop.new())
	for frame in 3:
		await process_frame
	print("PLAY START in ", out)
	while not finished:
		await _turn()

func _finish(code: int) -> void:
	if finished:
		return
	finished = true
	_release()
	_set_time_running(true)
	quit(code)

# One turn: stop time, write what the screen shows, wait for the agent's action
# and apply it, then run time for its wait.
func _turn() -> void:
	turn += 1
	_set_time_running(false)
	await RenderingServer.frame_post_draw
	if finished:
		return
	var name := "turn-%03d" % turn
	var image := root.get_texture().get_image()
	image.save_png(out.path_join(name + ".png"))
	# A small copy for tools/game_mcp.py, whose turns would otherwise carry the whole PNG.
	image.resize(image.get_width() / 2, image.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	image.save_jpg(out.path_join(name + ".jpg"), 0.8)
	var screen := _screen()
	if turn == 1:
		var actions := []
		var all := _actions()
		for kind: String in all:
			actions.append({"name": kind}.merged(all[kind]))
		screen.merge({"actions": actions, "screen_fields": screen.keys()})
	screen.merge({"turn": turn, "seed": rng_seed, "last_action": last_result, "ui": _ui(root, Rect2(Vector2.ZERO, Vector2(root.size)), [])})
	screen.merge(_take_events())
	var text := JSON.stringify(screen, "  ", false)
	var file := FileAccess.open(out.path_join(name + ".json"), FileAccess.WRITE)
	file.store_string(text)
	file.close()

	var action: Variant = null
	if replay.is_empty():
		print("TURN %d: waiting for action-%03d.json" % [turn, turn])
		action = await _read_action()
		if finished:
			return
	else:
		# A session stopped during its last action's wait has no turn after it.
		var ended := not FileAccess.file_exists(replay.path_join(name + ".json")) and not replay_actions.has(turn)
		if not ended and not _matches_replay(name, text):
			_finish(1)
			return
		if not replay_actions.has(turn):
			print("REPLAY OK: %d turns match %s" % [turn - 1 if ended else turn, replay])
			_finish(0)
			return
		action = replay_actions[turn]
	last_result = {"ok": false, "reason": "action-%03d.json is not a JSON object" % turn}
	var wait := 0.0
	if action is Dictionary:
		last_result = await apply(action)
		_release()
		if last_result.ok:
			wait = float(action.get("wait", 1.0 if action.do == "wait" else 0.0))
	var actions := FileAccess.open(out.path_join("actions.jsonl"), FileAccess.READ_WRITE if FileAccess.file_exists(out.path_join("actions.jsonl")) else FileAccess.WRITE)
	actions.seek_end()
	actions.store_line(JSON.stringify({"turn": turn, "seed": rng_seed, "action": action, "result": last_result}))
	actions.close()
	print("TURN %d: %s -> %s" % [turn, JSON.stringify(action), JSON.stringify(last_result)])
	if wait > 0.0:
		await _run_time(wait)

# Waits for the agent's action-<turn>.json and returns what it holds, or ends
# the session when none comes within --turn-seconds.
func _read_action() -> Variant:
	var path := out.path_join("action-%03d.json" % turn)
	var unreadable := 0
	var waiting_since := Time.get_ticks_msec()
	while true:
		if FileAccess.file_exists(path):
			var action: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			unreadable += 1
			# A file still being written reads as broken; give it a second.
			if action is Dictionary or unreadable >= 4:
				return action
		if (Time.get_ticks_msec() - waiting_since) / 1000.0 >= float(options["turn-seconds"]):
			printerr("TURN TIMEOUT: no action-%03d.json after %s real seconds" % [turn, options["turn-seconds"]])
			_finish(1)
			return null
		# On the clock: with --fixed-fps a timer counts frames, which run faster.
		var polled := Time.get_ticks_msec()
		while Time.get_ticks_msec() - polled < 250 and not finished:
			await process_frame
		if finished:
			return null
	return null

# Compares the turn just written, as `text`, with the old session's turn of the
# same name. When they differ, prints the fields that changed and returns false.
func _matches_replay(name: String, text: String) -> bool:
	var old_path := replay.path_join(name + ".json")
	var changes: Array[String] = []
	var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(old_path)) if FileAccess.file_exists(old_path) else null
	if old is Dictionary:
		_changes(_whole(old), _whole(JSON.parse_string(text)), "", changes)
	else:
		changes.append("the old session has no readable %s.json" % name)
	if changes.is_empty():
		print("TURN %d: matches %s" % [turn, old_path])
		return true
	printerr("REPLAY DIFFERS at turn %d, from %s (old -> new):" % [turn, old_path])
	for change in changes.slice(0, MAX_CHANGES):
		printerr("  ", change)
	if changes.size() > MAX_CHANGES:
		printerr("  ... and %d more" % (changes.size() - MAX_CHANGES))
	return false

# Appends to `found` each field where two parsed JSON values differ, by its
# path, such as `ui[0].text: "Clicks: 1" -> "Clicks: 2"`.
func _changes(old: Variant, new: Variant, path: String, found: Array[String]) -> void:
	if old is Dictionary and new is Dictionary:
		var keys: Array = old.keys()
		keys.append_array(new.keys().filter(func(key: Variant) -> bool: return not old.has(key)))
		for key: String in keys:
			var at := key if path.is_empty() else path + "." + key
			if old.has(key) and new.has(key):
				_changes(old[key], new[key], at, found)
			else:
				found.append("%s: %s -> %s" % [at, _shown(old, key), _shown(new, key)])
	elif old is Array and new is Array:
		for index in maxi(old.size(), new.size()):
			var at := "%s[%d]" % [path, index]
			if index < old.size() and index < new.size():
				_changes(old[index], new[index], at, found)
			else:
				found.append("%s: %s -> %s" % [at, _shown(old, index), _shown(new, index)])
	elif typeof(old) != typeof(new) or old != new:
		found.append("%s: %s -> %s" % [path, JSON.stringify(old), JSON.stringify(new)])

# A parsed JSON value with its whole numbers as ints, as the turn files show
# them: JSON.parse_string() reads every number as a float.
func _whole(value: Variant) -> Variant:
	if value is float and is_finite(value) and value == floorf(value):
		return int(value)
	if value is Array:
		return value.map(_whole)
	if value is Dictionary:
		var copy := {}
		for key: Variant in value:
			copy[key] = _whole(value[key])
		return copy
	return value

# The JSON of a field of a dictionary or array, or "(none)" when it has none.
func _shown(container: Variant, key: Variant) -> String:
	if container is Dictionary:
		return JSON.stringify(container[key]) if container.has(key) else "(none)"
	return JSON.stringify(container[key]) if key < container.size() else "(none)"

# Loads game/play_hooks.gd, if the game has one, and lets it connect the
# game's signals to _event(). Another scene's HUD and events are unknown, so a
# --scene run doesn't load it.
func _load_hooks() -> void:
	if not ResourceLoader.exists(HOOKS):
		return
	hooks = (load(HOOKS) as GDScript).new()
	hooks.set("game", game)
	hooks.set("driver", self)
	if hooks.has_method("watch"):
		hooks.call("watch")

# What the screen shows, as text, from the hooks: none without them.
func _screen() -> Dictionary:
	if hooks == null or not hooks.has_method("screen"):
		return {}
	return hooks.call("screen")

# The driver's actions, then the game's own from the hooks' ACTIONS. A game
# action can't replace a driver action of the same name.
func _actions() -> Dictionary:
	var own: Variant = hooks.get("ACTIONS") if hooks else null
	return ACTIONS.merged(own) if own is Dictionary else ACTIONS

# Records an event for the next turn, with the game time now.
func _event(event: String, fields := {}) -> void:
	if events.size() >= MAX_EVENTS:
		events_dropped += 1
		return
	events.append({"event": event, "time": snappedf(game_time, 0.01)}.merged(fields))

# The events since the last turn, as the turn's "events" and, when some were
# left out, "events_dropped"; then starts the next turn's list.
func _take_events() -> Dictionary:
	var taken := {"events": events}
	if events_dropped > 0:
		taken.events_dropped = events_dropped
	events = []
	events_dropped = 0
	return taken

# The visible controls under `node` that a player can read or press, in tree
# order. `clip` is the part of the window that ancestors with clip_contents,
# such as a ScrollContainer, leave in view. Skips Window nodes, whose controls
# sit in their own viewport.
func _ui(node: Node, clip: Rect2, found: Array) -> Array:
	for child in node.get_children():
		# A hidden CanvasItem or CanvasLayer hides everything below it.
		if child is Window or child.get("visible") == false:
			continue
		var inner := clip
		if child is CanvasLayer:
			inner = Rect2(Vector2.ZERO, Vector2(root.size))
		var control := child as Control
		if control:
			var rect := _rect(control)
			if _readable(control) and rect.intersects(clip):
				var text: Variant = (control as RichTextLabel).get_parsed_text() if control is RichTextLabel else control.get("text")
				var entry := {
					"node": str(root.get_path_to(control)),
					"class": control.get_class(),
					"text": text if text is String else "",
					"rect": [roundi(rect.position.x), roundi(rect.position.y), roundi(rect.size.x), roundi(rect.size.y)],
					"disabled": _disabled(control),
				}
				if not control.tooltip_text.is_empty():
					entry.tooltip = control.tooltip_text
				found.append(entry)
			if control.clip_contents:
				inner = clip.intersection(rect)
		_ui(child, inner, found)
	return found

func _readable(control: Control) -> bool:
	for type: String in ["BaseButton", "Label", "RichTextLabel", "LineEdit", "TextEdit", "Range", "ItemList", "Tree", "TabBar"]:
		if control.is_class(type):
			return true
	return not control.tooltip_text.is_empty()

func _disabled(control: Control) -> bool:
	return control.get("disabled") == true or control.get("editable") == false

# A control's rectangle in window pixels, through the window's stretch.
func _rect(control: Control) -> Rect2:
	return control.get_viewport_transform() * control.get_global_transform() * Rect2(Vector2.ZERO, control.size)

# Applies one action and returns {"ok": true, ...} or {"ok": false, "reason": ...}.
func apply(action: Dictionary) -> Dictionary:
	var kind := str(action.get("do", ""))
	var actions := _actions()
	if not actions.has(kind):
		return {"ok": false, "reason": "Unknown action \"%s\"; use %s" % [kind, ", ".join(actions.keys())]}
	var fields: Array = ["do", "why", "wait"] + actions[kind].fields
	for key: String in action:
		if key not in fields:
			return {"ok": false, "reason": "%s doesn't take \"%s\"; it takes %s" % [kind, key, ", ".join(fields)]}
	var wait: Variant = action.get("wait", 0)
	if not (wait is float or wait is int) or float(wait) < 0.0:
		return {"ok": false, "reason": "wait must be a number of seconds of game time, 0 or more"}
	match kind:
		"click":
			return await _click(action)
		"hover":
			return await _hover(action)
		"key":
			return await _key(action)
		"hold":
			return await _hold(action)
		"drag":
			return await _drag(action)
		"wait":
			return {"ok": true}
	return await hooks.call("apply", action)

# Moves the pointer to the action's window pixels, or to the middle of its
# node: the real pointer first, so a control sees it hovered. Returns
# {"point"}, with "node" for a node, or the refusal.
func _point(action: Dictionary, kind: String) -> Dictionary:
	var control: Control = null
	var point := Vector2.ZERO
	if action.has("node"):
		if action.has("x") or action.has("y"):
			return {"ok": false, "reason": "%s takes \"node\" or \"x\" and \"y\", not both" % kind}
		var path: Variant = action.node
		if path is String and not path.is_empty():
			control = root.get_node_or_null(NodePath(path)) as Control
		if control == null:
			return {"ok": false, "reason": "No control at \"%s\"; use a \"node\" from \"ui\"" % str(path)}
		if not control.is_visible_in_tree():
			return {"ok": false, "reason": "%s is hidden" % path}
		if _disabled(control):
			return {"ok": false, "reason": "%s is disabled" % path}
		if control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			return {"ok": false, "reason": "%s ignores the mouse, so a pointer there reaches what is behind it" % path}
		point = _rect(control).get_center()
	else:
		for key: String in ["x", "y"]:
			var value: Variant = action.get(key)
			if not (value is int or value is float) or not is_finite(float(value)):
				return {"ok": false, "reason": "%s needs \"x\" and \"y\" (window pixels, as in the turn image) or \"node\"" % kind}
		point = Vector2(float(action.x), float(action.y))
	if not Rect2(Vector2.ZERO, Vector2(root.size)).has_point(point):
		return {"ok": false, "reason": "(%d, %d) is outside the %dx%d window" % [point.x, point.y, root.size.x, root.size.y]}
	root.warp_mouse(point)
	for frame in 3:
		await process_frame
	Events.move_mouse(point)
	await process_frame
	if control == null:
		return {"point": point}
	var hovered := root.gui_get_hovered_control()
	if hovered and hovered.is_ancestor_of(control):
		return {"ok": false, "reason": "%s is out of view at its middle, such as clipped by a scroll container" % action.node}
	if _takes_pointer_from(hovered, control):
		var cover := str(root.get_path_to(hovered)) if hovered else "nothing that takes the mouse"
		return {"ok": false, "reason": "%s is covered at its middle by %s" % [action.node, cover]}
	return {"point": point, "node": action.node}

# Whether the control under the pointer, `hovered`, would take a click or show
# a tooltip in place of `control`: anything outside it, or a descendant that
# stops the mouse, is a button or field, or has a tooltip of its own.
func _takes_pointer_from(hovered: Control, control: Control) -> bool:
	if hovered == control:
		return false
	if hovered == null or not control.is_ancestor_of(hovered):
		return true
	var node: Node = hovered
	while node != control:
		var between := node as Control
		if between and (between.mouse_filter == Control.MOUSE_FILTER_STOP or not between.tooltip_text.is_empty() or (_readable(between) and not between is Label)):
			return true
		node = node.get_parent()
	return false

func _click(action: Dictionary) -> Dictionary:
	var button: Variant = action.get("button", "left")
	if not BUTTONS.has(button):
		return {"ok": false, "reason": "click's \"button\" is left, right or middle"}
	var index: MouseButton = BUTTONS[button]
	var moved := await _point(action, "click")
	if not moved.has("point"):
		return moved
	Events.click(moved.point, index)
	await process_frame
	await process_frame
	var result := {"ok": true, "clicked": [int(moved.point.x), int(moved.point.y)]}.merged(_named(moved))
	if action.has("button"):
		result.button = button
	return result

func _drag(action: Dictionary) -> Dictionary:
	for key: String in ["to_x", "to_y"]:
		var value: Variant = action.get(key)
		if not (value is int or value is float) or not is_finite(float(value)):
			return {"ok": false, "reason": "drag needs \"to_x\" and \"to_y\": window pixels where it ends"}
	var to := Vector2(float(action.to_x), float(action.to_y))
	if not Rect2(Vector2.ZERO, Vector2(root.size)).has_point(to):
		return {"ok": false, "reason": "(%d, %d) is outside the %dx%d window" % [to.x, to.y, root.size.x, root.size.y]}
	var moved := await _point(action, "drag")
	if not moved.has("point"):
		return moved
	var from: Vector2 = moved.point
	drag_point = from
	_press(Events.mouse_button.bind(from, MOUSE_BUTTON_LEFT, true), _release_drag)
	await process_frame
	for step in range(1, DRAG_STEPS + 1):
		var point := from.lerp(to, float(step) / DRAG_STEPS)
		Events.move_mouse(point, point - drag_point, MOUSE_BUTTON_MASK_LEFT)
		drag_point = point
		await process_frame
		if finished:
			return {"ok": false, "reason": "the session ended during the drag"}
	_release()
	# The real pointer follows, so it stays where the drag ended, as a player's would.
	root.warp_mouse(to)
	for frame in 3:
		await process_frame
	return {"ok": true, "dragged": [int(from.x), int(from.y), int(to.x), int(to.y)]}.merged(_named(moved))

func _release_drag() -> void:
	Events.mouse_button(drag_point, MOUSE_BUTTON_LEFT, false)

func _hover(action: Dictionary) -> Dictionary:
	var moved := await _point(action, "hover")
	if not moved.has("point"):
		return moved
	# Godot opens a tooltip after a real-time delay (0.5 s by default).
	for attempt in 20:
		await create_timer(0.1, true, false, true).timeout
		if not _tooltip(root).is_empty():
			break
	for frame in 3:
		await process_frame   # the popup places itself
	return {"ok": true, "hovered": [int(moved.point.x), int(moved.point.y)], "tooltip": _tooltip(root).split("\n", false)}.merged(_named(moved))

func _named(moved: Dictionary) -> Dictionary:
	return {"node": moved.node} if moved.has("node") else {}

func _key(action: Dictionary) -> Dictionary:
	var code := OS.find_keycode_from_string(str(action.get("key", "")))
	if code == KEY_NONE:
		return {"ok": false, "reason": "key needs \"key\": a key name such as Space, Escape or A"}
	Events.key(code)
	await process_frame
	await process_frame
	return {"ok": true, "pressed": OS.get_keycode_string(code)}

func _hold(action: Dictionary) -> Dictionary:
	var names: Variant = action.get("keys")
	if not names is Array or (names as Array).is_empty():
		return {"ok": false, "reason": "hold needs \"keys\": a list of key names, such as [\"W\", \"D\"]"}
	var codes: Array[Key] = []
	for name: Variant in names as Array:
		var code := OS.find_keycode_from_string(str(name)) if name is String else KEY_NONE
		if code == KEY_NONE:
			return {"ok": false, "reason": "\"%s\" is not a key name; name keys as Godot does, such as W, Space or Shift" % str(name)}
		if code not in codes:
			codes.append(code)
	var seconds: Variant = action.get("seconds")
	if not (seconds is int or seconds is float) or not (float(seconds) >= 0.0 and float(seconds) <= MAX_HOLD_SECONDS):
		return {"ok": false, "reason": "hold needs \"seconds\" from 0 to %d" % MAX_HOLD_SECONDS}
	for code in codes:
		_press(Events.hold_key.bind(code, true), Events.hold_key.bind(code, false))
	if not await _run_held(float(seconds)):
		return {"ok": false, "reason": "the session ended during the hold"}
	return {"ok": true, "held": codes.map(OS.get_keycode_string), "seconds": float(seconds)}

# Sends `press` now and keeps `release`, which _release() sends after the
# action, whether it finished, was refused or the session ended.
func _press(press: Callable, release: Callable) -> void:
	press.call()
	releases.append(release)

func _release() -> void:
	for release in releases:
		release.call()
	releases.clear()

# Runs `seconds` of game time with the pressed input down, then stops time and
# releases it. False when the session ended meanwhile.
func _run_held(seconds: float) -> bool:
	await _run_time(seconds)
	if finished:
		return false
	_release()
	await process_frame
	return true

# Runs `seconds` of game time, frame by frame, then stops time. It counts the
# game's own frame times, not the clock, so with --fixed-fps the same seconds
# always run the same frames. A frame's time is fixed when the frame starts, so
# time stopped here still lets this frame run.
func _run_time(seconds: float) -> void:
	var end := game_time + seconds - 0.000001   # leaves out float rounding
	_set_time_running(true)
	while game_time < end and not finished:
		await process_frame
	_set_time_running(false)

# Starts or stops game time, and the 2D and 3D physics servers with it. Frames
# still run while time is stopped, and a physics step of no time can make
# touching rigid bodies' positions NaN. Call it outside a frame's physics,
# whose step already has its time; then it takes effect from the next frame.
# Physics starts unless the tree is paused, which stops it too. Otherwise it
# starts whether or not the game had stopped it: Godot can't tell.
static func _set_time_running(running: bool) -> void:
	Engine.time_scale = 1.0 if running else 0.0
	PhysicsStop.time_stopped = not running
	var on := running and not (Engine.get_main_loop() as SceneTree).paused
	PhysicsServer2D.set_active(on)
	PhysicsServer3D.set_active(on)

# Unpausing the tree turns physics on at once, even while the driver has time
# stopped, such as when the game's Resume key runs during a turn. This node,
# which the tree pauses whatever the game sets on the root, turns it off again
# before any step.
class PhysicsStop extends Node:
	static var time_stopped := false

	func _init() -> void:
		process_mode = PROCESS_MODE_PAUSABLE

	func _notification(what: int) -> void:
		if what == NOTIFICATION_UNPAUSED and time_stopped:
			PhysicsServer2D.set_active(false)
			PhysicsServer3D.set_active(false)

# The text of the tooltip popup on screen, or "".
func _tooltip(node: Node) -> String:
	for child in node.get_children(true):
		if child is Window and not child.visible:
			continue
		if child is Label and child.get_parent() is PopupPanel:
			return child.text
		var text := _tooltip(child)
		if not text.is_empty():
			return text
	return ""
