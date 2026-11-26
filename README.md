# Game Off 2026

A [Game Off 2026](https://itch.io/jam/game-off-2026) jam entry (theme: SHIFT), in Godot 4. Holding Shift makes the player bigger, heavier and slower. It started as a grey-box prototype and is still one. The tooling below came with the project template. The [docs index](docs/README.md) lists the docs.

## Setup

Use **Godot 4.7.2 stable**. [Install mise](https://mise.jdx.dev/installing-mise.html) to get the pinned Godot version and the task shortcuts. From the repository root:

```sh
mise trust
mise install
mise tasks ls
```

If `mise install` can't fetch Godot, as in a cloud agent session whose network blocks mise's release lookups, run `tools/setup.sh`. It downloads the release from GitHub into `~/.cache/godot-releases/` and registers it with `mise link`, so the tasks below work as usual. This fallback is Linux only. In Claude Code on the web it also installs mise from npm when mise is missing. `.agents/worktree-setup` runs it, so Claude Code's session-start hook does too.

| Command | Action |
| --- | --- |
| `mise run editor` | Open the Godot editor. |
| `mise run play` | Import assets, then launch the game. |
| `mise run import` | Import Godot assets. |
| `mise run test` | Import assets, then run the [headless checks](#headless-checks). |
| `mise run test:native` | Import assets, then run the [native checks](#native-checks) and the [game MCP server](#let-an-agent-play)'s self-test. Needs Xvfb on Linux or a desktop. |
| `mise run export:windows` | Export a single-file Windows build to `build/windows/`. |
| `mise run export:linux` | Export a single-file Linux build to `build/linux/`. |
| `mise run export:macos` | Export a universal, ad-hoc-signed macOS app to `build/macos/`. |

Machine-specific settings, such as `DISPLAY` for a headless GPU server, go in a git-ignored `mise.local.toml`:

```toml
[env]
DISPLAY = ":1"
```

The exports need Godot's export templates: **Editor → Manage Export Templates** in the editor, or the install step in `.github/workflows/ci.yml`.

### Agent permissions

Codex and Claude Code each have a project allowlist, so agents run the checks without asking. When one changes, check the other.

| | Codex: `.codex/rules/project.rules` | Claude Code: `.claude/settings.json` |
| --- | --- | --- |
| Allowed | `git add`, `commit`, `fetch`, `switch`; native Godot (`godot --path .`, `mise exec -- tools/native.sh godot --path .`); `mise exec -- tests/run.sh`; `mise run test:native`, `play`; `tools/clips/record.sh`, `stills.sh` | The same, plus headless Godot (`godot --headless`, `mise exec -- godot --headless`) and `mise run import`, `test`, which Codex runs inside its sandbox |
| Asks | Other commands that need to leave the sandbox, such as `git push` | Other commands that aren't read-only, such as `git push` |
| Fresh worktree | Orchestration skills run `.agents/worktree-setup` | A session-start hook runs `.agents/worktree-setup` when `.godot/` is missing |

Codex's rules let a command out of its sandbox, and Claude Code's skip the prompt. Both allow `git switch -f` and `git commit --amend` along with the rest of those commands.

### Template updates

A game made from this template gets a copy of its generic tools, which share no history with the template. `tools/update.sh <template tag>` brings them up to a tag of the template: it fetches the tag, copies the files listed in that tag's `tools/update.sh` (the play driver and its MCP server, `tests/run.sh`, `tests/lib/`, the clip tools and a few more), and stages them. It records the tag in `tools/template-version`, so you can compare it with the template's newest tag. A game that has never updated has no such file.

```sh
tools/update.sh v0.2.0
git diff --staged
mise run import && mise run test && mise run test:native
```

It leaves the game's own files alone, such as `game/play_hooks.gd` and `tools/ui_shots.gd`. It refuses while a listed file has uncommitted changes, and replaces a listed file the game edited with the template's copy, so fix those files in the template instead. It fetches from `evalfoo/godot-template` over SSH; set `TEMPLATE_REPO` to fetch from another URL or a local clone.

A game made before the update script has no `tools/update.sh`, and its `tools/play_driver.gd` and `tests/play_events.gd` hold game code, which the first update replaces. Copy `tools/update.sh` from the template, move the driver's `_screen()`, `_watch()` and the game's actions into `game/play_hooks.gd` (start from the template's copy) and the game's event checks into `tests/play_hooks.gd`, commit, then update.

In the template, tag a commit by hand to make it a version games can update to. The weekly release workflow stays off there.

### Releases

[`.github/workflows/release.yml`](.github/workflows/release.yml) releases `main` every Monday. It runs the headless checks, exports Windows, Linux and macOS, uploads them to itch.io with butler and then tags the commit.

- Git tags such as `v0.3.0` are the only record of the version. The workflow writes it into `project.godot` for the build without committing it.
- Each weekly release raises the minor version, starting at `v0.1.0`. A week without commits since the last tag doesn't release.
- To release now, or ship a fix as a patch version, run **Release** from the Actions tab and choose `minor` or `patch`.
- The `release-notes` skill writes a GitHub release for a tag.

The workflow needs the repository secret `BUTLER_API_KEY` (itch.io → Settings → API keys) and the repository variable `ITCH_TARGET`, the itch.io `user/game` slug. It stays off until `ITCH_TARGET` is set.

## Verify

`tests/run.sh` finds the tests by name, so a new test needs no registration:

- `tests/<name>.gd` runs headless in `mise run test`.
- `tests/<name>_native.gd` runs in a real window in `mise run test:native`.
- `tests/lib/` holds helpers and is never run.

A test extends `tests/lib/test.gd`, overrides `run()` and calls `check()`. It fails on a `FAIL` check, on a `SCRIPT ERROR` line in its output, because Godot often exits 0 after one, or after 5 minutes. Every script runs, then the runner lists the failures. Logs go to `tests/output/logs/`.

Tests, clips, stills and agent play sessions of the game give it a save folder of their own. `tests/lib/fixture.gd` sets `save_directory` in `game/main.gd` before `_ready()`, to the folder the caller gives or a new one under `tests/output/saves/`, so a game that saves only under `save_directory` never touches the player's saves in a check. The test tasks also set `XDG_DATA_HOME` to `tests/output/userdata`, so on Linux each worktree keeps Godot's own user folder, with its logs and shader cache, in its own git-ignored folder.

### On macOS

Nobody has run these on a Mac yet. This is what each part expects there:

- `tests/run.sh` limits each script with `timeout`, else `gtimeout` from Homebrew's coreutils, else `tests/lib/timeout.sh`.
- Godot ignores `XDG_DATA_HOME`, so its logs and shader cache go to the player's folder under `~/Library/Application Support/`. Saves don't; see above.
- `tools/native.sh` uses Xvfb only on Linux, so native checks, stills and agent play sessions open a window on your desktop, which takes focus. An agent play session moves your real mouse pointer. The native checks send their clicks as events and leave it alone.
- `tools/clips/stills.sh` needs Bash 4 and GNU `timeout`: `brew install bash coreutils`. `tools/clips/record.sh` and `tools/setup.sh` are Linux only.

### Headless checks

`mise run test` covers rules and saves, not rendering. The task ends by parse-checking every `.gd` script under `game/`, `tools/` and `tests/` with `--check-only`, and fails on a `class_name` in a prototype script.

Run one with `mise exec -- tests/run.sh tests/<name>.gd`.

### Native checks

These send mouse, keyboard and gamepad events to a real Godot window through `tests/lib/events.gd`. A click sends press and release in the same frame, so moving the real mouse can't split it. `hold_key`, `joy_button` and `mouse_button` send a press or a release alone, so input can stay down while time runs; `joy_axis` and `mouse_motion` send stick and mouse-look motion.

On Linux, each runs through `tools/native.sh`, which gives it its own Xvfb display (`xvfb-run -a`), so its mouse pointer is its own and runs in different worktrees don't collide. Godot still renders on the GPU there. Wrap direct native commands the same way, inside the mise environment, because mise sets `DISPLAY` from `mise.local.toml`: `mise exec -- tools/native.sh godot --path . ...`.

Run one with `mise exec -- tests/run.sh tests/<name>_native.gd`.

CI runs them too, in the Native checks job. Its runner has no GPU, so Godot falls back to the Compatibility renderer on software OpenGL. That covers input, focus and UI logic, not how Forward+ looks: stills and clips for visual changes still come from a machine with a GPU.

### Let an agent play

Claude Code agents can play a native window through the `game` MCP server in `.mcp.json` (`tools/game_mcp.py`): `start` with the checkout's path, and a `scene` such as `res://prototypes/<name>/main.tscn` to play a prototype instead of the game, then `act` or `click` one turn at a time, each returning a screenshot and the screen's text, then `stop`. Besides clicks, the actions include right clicks, drags, keys, and `hold`, which keeps keys down while time runs. Each turn's `ui` lists the visible buttons, labels and other controls with their text, rectangle, disabled state and tooltip, and `click` and `hover` can name one by its `node` instead of giving pixels. Each turn's `events` lists what the game did since the last turn, such as a button press, with the game time of each. Time stands still between turns. The game runs with `--fixed-fps 60`, and an action's `wait` counts game time in frames. So the same `seed` in `start` (default 0) and the same actions replay the same turns on any machine. Use one seed for a before and after. On Linux the game gets its own Xvfb display; on macOS it opens on your desktop and moves your mouse pointer. One game runs at a time per Claude Code session. The server's header lists the tools and limits.


The server wraps `tools/play_driver.gd`, which any agent can also drive through files; its header documents the turn files, and its `ACTIONS` holds each action's fields and description, which the first turn lists, so `start` returns them. The driver is generic. The game's part lives in `game/play_hooks.gd`, which export leaves out: add the game's own actions to its `ACTIONS` and `apply()`, its HUD text to `screen()`, and the signals worth reporting to `watch()`, as the game grows. The driver plays without the file. This is for looking and trying; PRs still need scripted checks. `mise run test:native` ends with `python3 tools/game_mcp.py --self-test`, which drives a native window through the server. Its actions run on `tests/lib/probe.tscn`, not the game, so a new first screen doesn't break it.

To see whether a session still plays out the same after a change, replay it. Pass the old session's folder, such as one from `tests/output/mcp/`, and the `--scene` it played, if any:

```sh
mise exec -- tools/native.sh godot --path . --fixed-fps 60 --script tools/play_driver.gd -- \
    --out=tests/output/replay/<name> --replay=<old folder>
```

It applies the old `actions.jsonl` in order with its seed, without waiting for action files, and compares each new turn's JSON with the old one. At the first turn that differs it lists the changed fields, such as `label: "Clicks: 1" -> "Clicks: 2"`, and exits 1. It doesn't compare the screenshots; both folders keep them. Hover and drag can differ by chance, so leave them out of sessions you mean to replay. `mise run test:native` replays each session under `tests/sessions/` through `tests/replay_native.gd`. To add one, or re-record one after the game or the action list changes on purpose, play a short session and copy only its `actions.jsonl` and `turn-*.json` into `tests/sessions/<name>/`.

### Screenshots

For UI changes, `tools/clips/stills.sh` runs a shot script on `origin/main` and `HEAD`, each in a throwaway worktree, and writes `before-<name>.png` and `after-<name>.png` into a new `tests/output/stills/<script>-<date>/` folder:

```sh
tools/clips/stills.sh                                  # tools/ui_shots.gd on origin/main and HEAD
tools/clips/stills.sh a37bc38~1 a37bc38 --out tests/output/pr-123
tools/clips/stills.sh tools/my_shots.gd HEAD           # another shot script, one ref
```

A shot script extends `tools/clips/scenario.gd` and calls `shot(<name>)`. It runs from your working tree on both refs, so both get the same fixture, and it must still compile on the older ref. Game changes are shot from the commit, so commit them first. Each ref's import starts from a copy of the main checkout's `.godot/` import cache, so it redoes only the assets that differ. It needs Bash 4, GNU `timeout` (`gtimeout` on macOS), `godot`, and `xvfb-run` on Linux.

### Recording clips

`tools/clips/record.sh` records a scripted scenario on two git refs and writes before/after clips for a PR:

```sh
tools/clips/record.sh tools/clips/scenarios/grow.gd                  # origin/main and HEAD
tools/clips/record.sh tools/clips/scenarios/grow.gd a37bc38~1 a37bc38
tools/clips/record.sh tools/clips/scenarios/grow.gd HEAD             # one ref, no side by side
```

Each ref is checked out into a throwaway worktree under `/tmp`, imported from a copy of the main checkout's import cache as in `stills.sh`, and recorded with Godot Movie Maker at 30 fps and 1440×900, then removed. Commit game changes first: they're recorded from the commit, while the scenario and `tools/clips/scenario.gd` come from your working tree. The same commit gives the same frames every run. Linux only; it also needs an `ffmpeg` with the `drawtext` filter and a font, and checks for each tool before it starts.

Each run creates a new folder under `tests/output/clips/` with `before.mp4`, `after.mp4`, `before-after.mp4`, `after.gif`, an 8-frame strip per ref, and a `README.md` with the refs, fixture, timeline and commands. To write a scenario, copy `tools/clips/scenarios/grow.gd`; its header explains the helpers.

To attach clips to a PR, run from the clip folder. `--attach` needs gh 2.99.0 or newer; older versions reject it.

```sh
gh pr comment <n> --body-file comment.md --attach ./before-after.mp4 --attach ./after-strip.png
```

In the body, reference an image as `![After: 8 frames of the click](./after-strip.png)`, and gh replaces the path with the uploaded file. gh adds a video as a URL at the end of the body. AI reviewers can't watch video and see one frame of a GIF, so always include the frame strips.
