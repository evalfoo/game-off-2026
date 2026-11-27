# Implementation notes

This file records engine and implementation decisions.

## Runtime

Godot 4.7.2 stable (pinned in `mise.toml`), GDScript, Forward+ renderer. The main scene is `game/main.tscn`.

The game uses custom physics: the player, boxes and seesaw plank are moved by code, and their rules (who can push what, which way the plank turns) are code too. There are no `RigidBody2D`s; real physics made those rules depend on tuning forces and gave the player no inertia against them.

The player's collision shape is a rectangle. A capsule would round off catches on corners and tile joins, but walking across the tile floor's joins doesn't catch at either size, so the rectangle stays for now.

`project.godot` reports the GDScript warnings `untyped_declaration`, `unsafe_property_access`, `unsafe_method_access` and `unsafe_call_argument` at the Warn level. Move one to Error once nothing triggers it.

## Code map

Keep the game's simulation apart from presentation, so headless tests can drive the rules without a window.

- `game/main.gd`: builds the level (tiles, `BOX A`, `BOX B`), the player and the readout in code.
- `game/tiles.gd`: builds a room's floor and side walls as a `TileMapLayer` from `art/tiles.tres`.
- `game/player.gd`: the player, a `CharacterBody2D`. Holding Shift eases size, mass, speed and jump speed from the small values to the big ones; its origin sits at the feet, so it grows upward. It pushes boxes up to `push_ratio` times its mass, moving the box before itself in the same step, and weighs down the plank it stands on. Its controls have separate start and stop times, stronger gravity when falling or when jump is let go early, coyote time and a jump buffer.
- `game/box.gd`: a box, a `CharacterBody2D` that falls and moves only when pushed. It puts its x back after its own `move_and_slide()`: on the tile floor, sliding pressed against the other box crept both about 1 px/s.
- `game/seesaw_plank.gd`: a seesaw plank, an `AnimatableBody2D` that turns toward the side with the larger mass × distance from the pivot, counting its fixed counterweight and what stands on it.
- `game/play_hooks.gd`: the readout text for the play driver.
- `game/rooms/seesaw.tscn`: a grey-box room for the seesaw puzzle, separate from the main scene. Open it with `mise exec -- godot --path . res://game/rooms/seesaw.tscn`, or the game MCP server's `scene`.

## Persistence

The game saves nothing yet.

Every save goes under `save_directory` in `game/main.gd`, `user://` by default. The game creates the folder when it doesn't exist. `tests/lib/fixture.gd` sets it before `_ready()`, so tests, clips, stills and agent play sessions never touch the player's saves, also on macOS, where Godot ignores `XDG_DATA_HOME`. Keep the variable when the main scene changes; the fixture fails without it. The fixture also sets `rng_seed`, 0 unless the caller gives one, for the game's `RandomNumberGenerator` (see [the coding standards](../CODING_STANDARDS.md#randomness)); keep it too.

## Assets and coordinates

- The view is 320×180 game pixels, drawn at the largest whole multiple that fits the window (`stretch/mode="viewport"`, `scale_mode="integer"`), with nearest filtering and transforms snapped to whole pixels. The window opens at 1280×720.
- Positions and sizes are in game pixels; tiles are 16 px. Moving to this scale divided the earlier lengths, speeds and gravity by 3, so jumps keep their shape.
- Art lives in `art/`: PNGs with their `.import` files, and the tile set `art/tiles.tres`, whose one tile has a full-square collision polygon. The PNGs there are flat placeholders. The player's sprite is drawn at the small size and stretched as it grows; box collision takes its size from the box's sprite.
- `art/tiles.png` is a sheet of 8×4 tiles of 16 px; draw over it in place and `art/tiles.tres` keeps each tile's collision. In the placeholder, a light line marks a side that faces open air. By column and row:
  - 0–2, 0–2: a 3×3 block: corners, edges and, at 1,1, the fill. Rooms use 1,0 for the floor's surface and 1,1 below it.
  - 3–4, 0–1: inner corners, a full tile with one open corner: top-left, top-right, bottom-left, bottom-right.
  - 5, 0–2: a one-tile-wide pillar: top, middle, bottom.
  - 0–3, 3: a one-tile-thick platform: left, middle, right, and a single block.
  - 6–7, 0: 45° slopes rising right and rising left.
  - 6–7, 1: a 22.5° slope rising right over two tiles, low then high. 6–7, 2: rising left, high then low.
  - 6–7, 3: 45° ceiling slopes, solid at the top-left and at the top-right.
  - 3–4, 2 and 4–5, 3 are empty.

## Testing

- `tests/run.sh` runs every `tests/*.gd` headless and every `tests/*_native.gd` in a window, so new tests need no registration. It fails a script on a `SCRIPT ERROR` line too, because Godot often exits 0 after one.
- On Linux, `tools/native.sh` gives each native run its own Xvfb display, so runs in different worktrees don't share a mouse pointer. Godot still renders on the GPU there.
- New worktrees and the clip scripts' throwaway worktrees start from a copy of the main checkout's `.godot/` (`tools/seed_import.sh`). Godot reimports only the assets whose source file or import settings differ from what the cache recorded, and the editor scan rebuilds the class and UID caches. Assets deleted on the ref leave unused files in `.godot/imported/`, which nothing loads. The import must still run after the copy. Without it, the game runs on the other ref's scripts and assets.
- The play driver freezes time between turns with `Engine.time_scale = 0` and turns the physics servers off with it ([evalfoo/godot-template#44](https://github.com/evalfoo/godot-template/issues/44)), but `_physics_process` still runs with a zero delta. The game's bodies skip zero-length steps; `tests/pause.gd` checks a pushed box holds still.
- Godot 4.7.2 can hang when a native check quits on a cold Vulkan pipeline cache. The test tasks keep `tests/output/userdata` between runs, so only the first run in a worktree is cold.
- `tools/play_driver.gd` is generic and comes from the template through `tools/update.sh`. It loads `game/play_hooks.gd`, the game's HUD text, events and actions, only when it plays the game, not a `--scene`, and skips `screen()` or `watch()` when the file has none.
- `tools/play_driver.gd` stops time at each turn and trades files with the agent; `tools/game_mcp.py` only relays them. The server runs it with `--fixed-fps 60`, and the driver runs a `wait` or `hold` until its own sum of frame times reaches it, so the same seed and actions run the same frames. Frames still run, with no game time, while the driver waits for an action, so game code that must replay counts time from `delta`, not from frames. The server kills the whole process group on stop, because `xvfb-run` can exit before Godot does, and a stopped Godot ignores SIGTERM. With `--scene`, the driver sets that scene as the tree's current scene before adding it, as a normal launch does, so a prototype's `_ready()` and its `reload_current_scene()` restart both see it. `--replay` can't check for `--fixed-fps`, because Godot keeps its own options out of `OS.get_cmdline_args()`, so the docs give the command with it.
