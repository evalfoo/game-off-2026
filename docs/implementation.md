# Implementation notes

This file records engine and implementation decisions.

## Runtime

Godot 4.7.2 stable (pinned in `mise.toml`), GDScript, Forward+ renderer. The main scene is `game/main.tscn`.

`project.godot` reports the GDScript warnings `untyped_declaration`, `unsafe_property_access`, `unsafe_method_access` and `unsafe_call_argument` at the Warn level. Move one to Error once nothing triggers it.

## Code map

Keep the game's simulation apart from presentation, so headless tests can drive the rules without a window.

- `game/main.gd`: builds the level (floor, walls, `BOX A`, `BOX B`), the player and the readout in code.
- `game/player.gd`: the player, a `RigidBody2D` with rotation locked. Holding Shift eases size, mass and speed from the small values to the big ones; its origin sits at the feet, so it grows upward.
- `game/play_hooks.gd`: the readout text for the play driver.

## Persistence

The game saves nothing yet.

Every save goes under `save_directory` in `game/main.gd`, `user://` by default. The game creates the folder when it doesn't exist. `tests/lib/fixture.gd` sets it before `_ready()`, so tests, clips, stills and agent play sessions never touch the player's saves, also on macOS, where Godot ignores `XDG_DATA_HOME`. Keep the variable when the main scene changes; the fixture fails without it. The fixture also sets `rng_seed`, 0 unless the caller gives one, for the game's `RandomNumberGenerator` (see [the coding standards](../CODING_STANDARDS.md#randomness)); keep it too.

## Assets and coordinates

TODO(template): units, axes, origin and naming conventions for imported assets.

## Testing

- `tests/run.sh` runs every `tests/*.gd` headless and every `tests/*_native.gd` in a window, so new tests need no registration. It fails a script on a `SCRIPT ERROR` line too, because Godot often exits 0 after one.
- On Linux, `tools/native.sh` gives each native run its own Xvfb display, so runs in different worktrees don't share a mouse pointer. Godot still renders on the GPU there.
- New worktrees and the clip scripts' throwaway worktrees start from a copy of the main checkout's `.godot/` (`tools/seed_import.sh`). Godot reimports only the assets whose source file or import settings differ from what the cache recorded, and the editor scan rebuilds the class and UID caches. Assets deleted on the ref leave unused files in `.godot/imported/`, which nothing loads. The import must still run after the copy. Without it, the game runs on the other ref's scripts and assets.
- A recorded session under `tests/sessions/` must not end a turn while a moving rigid body touches something. The play driver freezes time with `Engine.time_scale = 0`, physics keeps stepping with a zero delta, and such a body's position turns to NaN, so the recording no longer replays. `tests/sessions/grow` stays clear of the boxes for this reason.
- Godot 4.7.2 can hang when a native check quits on a cold Vulkan pipeline cache. The test tasks keep `tests/output/userdata` between runs, so only the first run in a worktree is cold.
- `tools/play_driver.gd` is generic and comes from the template through `tools/update.sh`. It loads `game/play_hooks.gd`, the game's HUD text, events and actions, only when it plays the game, not a `--scene`, and skips `screen()` or `watch()` when the file has none.
- `tools/play_driver.gd` stops time at each turn and trades files with the agent; `tools/game_mcp.py` only relays them. The server runs it with `--fixed-fps 60`, and the driver runs a `wait` or `hold` until its own sum of frame times reaches it, so the same seed and actions run the same frames. Frames still run, with no game time, while the driver waits for an action, so game code that must replay counts time from `delta`, not from frames. The server kills the whole process group on stop, because `xvfb-run` can exit before Godot does, and a stopped Godot ignores SIGTERM. With `--scene`, the driver sets that scene as the tree's current scene before adding it, as a normal launch does, so a prototype's `_ready()` and its `reload_current_scene()` restart both see it. `--replay` can't check for `--fixed-fps`, because Godot keeps its own options out of `OS.get_cmdline_args()`, so the docs give the command with it.
