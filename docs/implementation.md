# Implementation notes

This file records engine and implementation decisions.

## Runtime

Godot 4.7.2 stable (pinned in `mise.toml`), GDScript, Forward+ renderer. The main scene is `game/main.tscn`.

The game uses custom physics: the player, boxes and seesaw plank are moved by code, and their rules (who can push what, which way the plank turns) are code too. There are no `RigidBody2D`s; real physics made those rules depend on tuning forces and gave the player no inertia against them.

The player's collision shape is a rectangle. A capsule would round off catches on corners and tile joins, but walking across the tile floor's joins doesn't catch at either size, so the rectangle stays for now.

`project.godot` reports the GDScript warnings `untyped_declaration`, `unsafe_property_access`, `unsafe_method_access` and `unsafe_call_argument` at the Warn level. Move one to Error once nothing triggers it.

## Code map

Keep the game's simulation apart from presentation, so headless tests can drive the rules without a window.

- `game/main.gd`: builds the level (tiles, `BOX A`, `BOX B`) and the player in a `game/pixel_view.gd`, at `View/World`, and the box labels and readout above it, in code.
- `game/tiles.gd`: builds a room's floor and side walls as a `TileMapLayer` from `art/tiles.tres`, one view in size unless the room gives its own, and one-tile-thick platforms.
- `game/player.gd`: the player, a `CharacterBody2D`. Holding Shift eases size, mass, speed and jump speed from the small values to the big ones; its origin sits at the feet, so it grows upward. It pushes boxes up to `push_ratio` times its mass, moving the box before itself in the same step, and weighs down the plank it stands on. Its controls have separate start and stop times, stronger gravity when falling or when jump is let go early, coyote time and a jump buffer.
- `game/box.gd`: a box, a `CharacterBody2D` that falls and moves only when pushed. It puts its x back after its own `move_and_slide()`: on the tile floor, sliding pressed against the other box crept both about 1 px/s.
- `game/seesaw_plank.gd`: a seesaw plank, an `AnimatableBody2D` that turns toward the side with the larger mass × distance from the pivot, counting its fixed counterweight and what stands on it.
- `game/pixel_view.gd`: renders a room's world into its own 322×182 image and draws it shifted by the camera's fraction of a pixel; see Assets and coordinates. A room adds its world, with its camera, to the view's `world`; what it adds to itself after the view, such as the readout, draws above the image and holds still. `follow()` shows a label above a world body from the window's viewport, at whole game pixels. Bodies must share the view's `world`, which has its own physics space.
- `game/camera.gd`: a `Camera2D` that follows the player, with Camera2D's position smoothing and limits. The script keeps the horizontal camera window itself rather than using Camera2D's drag margins (it leaves `drag_horizontal_enabled` off and keeps the blended window size in `drag_left_margin` and `drag_right_margin`), so a pull moves the view by its full amount, and adds that the height follows the player only on a floor and holds while they're in the air or on a seesaw plank, so the view doesn't bob as the plank tilts. Once the feet drop more than `window_bottom` below the view's centre, on a floor too, the height follows them in the same step: Camera2D's smoothing would trail a fast fall, so the script aims past the wanted height by the share smoothing moves each step. Looking up on a floor puts the feet lower on purpose, so the fall line drops by how far the view sits above the standing height as of the last step on a floor, held through a jump and dropped for a fall below the standing height or on landing on a plank. A blended smoothing speed of 0 turns smoothing off, as Camera2D at speed 0 never moves. It keeps the heights it aims for inside the limits, as Camera2D clamps only the view it shows and a fall from an eased position past a limit would trail. It follows a look-ahead point in front of the player rather than the player, on the side they last walked toward. The window, smoothing and look-ahead each have a small and a big value and blend by the player's `t`, as the player's speed does. The big window and smoothing default to the small values. The point changes sides only after the player walks `flip_distance` back from the furthest x they reached on the current side. It updates in the physics step, where the bodies move. Camera2D's own physics update runs before the script's, which would leave the view a step behind, so the script turns it off, again after each change to the smoothing speed, which turns it back on, and updates the view itself with `force_update_scroll()`. Holding Up or Down (`ui_up`, `ui_down`) moves its height target by `look_distance` while the player is on a floor, clamped to the limits, since smoothing would otherwise run on behind a limit and hold the view there after the key is let go. `shake(strength, length)` shakes the view through Camera2D's `offset`, fading over `length` seconds, with directions from a `RandomNumberGenerator` seeded by `rng_seed`. Camera2D adds the offset after its limits, so the script clamps it to them. It needs the view's place without the shake for that, which only Camera2D's update gives, so it updates a second time with `position_smoothing_speed` at 0, else that update would ease the view a second step; it then restores the speed and turns Camera2D's own physics update off again. The air hold and the fall check subtract the offset, so a shake doesn't move where the camera goes. A room marks an object with `pull_toward(node, inner_radius, outer_radius, share)`. While the player's feet are inside the outer ring, the camera's target moves toward the object: `share` of the way at the inner ring and inside, blending in between. Where pulls overlap, the strongest counts. The pull starts from the point the limits let the view rest at, so a pull back from a room edge moves the full amount, and applies to the height only where the height follows the floor: after the look and the limits, and not during a jump, a plank hold, a fall or a camera's first view in the air. The pulled target stays inside the limits too, as with the other heights it aims for. The window and the clamp divide the view's half size by the zoom. No room marks anything yet; which objects pull is the owner's call. The room sets its target and limits, and adds it after the player.
- `game/play_hooks.gd`: the readout text for the play driver.
- `game/rooms/seesaw.tscn`: a grey-box room for the seesaw puzzle, separate from the main scene. Open it with `mise exec -- godot --path . res://game/rooms/seesaw.tscn`, or the game MCP server's `scene`.
- `game/rooms/wide.tscn`: a grey-box room three views wide and taller than one, with a one-tile step, for the camera, made in the editor (see Rooms made in the editor). Its readout sits on a `CanvasLayer`, so it stays put while the view scrolls. The constants in `game/rooms/wide.gd`, such as `FLOOR_Y` and `STEP_ROW`, describe the painted scene for the tests; `tests/wide_room.gd` checks they match it.

## Rooms made in the editor

The wide room is the first room made in the editor; `game/main.tscn` and the seesaw room still build theirs in code. Open it with `mise run editor` and `game/rooms/wide.tscn`.

- Paint the floor, walls and platforms on the `Tiles` node, a `TileMapLayer` with `art/tiles.tres`. The walls go in the column just outside each side of the room.
- The `PlayerStart` marker is where the player's feet start.
- The camera's limits are the painted tiles' bounds less the wall column on each side; the top and bottom are the painted bounds.
- The pixel view makes its world, a `SubViewport`, in code, so the scene has no world to put the level in. The level's nodes sit under the room's root, where the editor shows them, and the room script moves `Tiles` into `view.world` at startup, keeping its local position. The player, camera and readout are made in code.

## Persistence

The game saves nothing yet.

Every save goes under `save_directory` in `game/main.gd`, `user://` by default. The game creates the folder when it doesn't exist. `tests/lib/fixture.gd` sets it before `_ready()`, so tests, clips, stills and agent play sessions never touch the player's saves, also on macOS, where Godot ignores `XDG_DATA_HOME`. Keep the variable when the main scene changes; the fixture fails without it. The fixture also sets `rng_seed`, 0 unless the caller gives one, for the game's `RandomNumberGenerator` (see [the coding standards](../CODING_STANDARDS.md#randomness)); keep it too.

## Assets and coordinates

- The view is 320×180 game pixels, drawn at the largest whole multiple that fits the window (`scale_mode="integer"`), with nearest filtering and transforms snapped to whole pixels. The window opens at 1280×720.
- Each room renders its world into a 322×182 `SubViewport` (`game/pixel_view.gd`): the camera's view with one spare pixel on each side. The world renders at the camera's whole-pixel offset, and the image is drawn shifted by the leftover fraction, in screen pixels (Hyper Light Drifter's approach). So the camera can move a quarter of a game pixel at 1280×720 while the art stays on the game-pixel grid. The window stretches its canvas (`stretch/mode="canvas_items"`), so the image can sit between game pixels. The window snaps a node's position to whole game pixels, so the shift goes in the draw call. Font oversampling is off, so text outside the world image, such as the readout, still renders at game pixels and is scaled up like the art.
- Screenshots, stills and clips capture the window's picture, 1280×720 in a 1280×720 or 1440×900 window, not a 320×180 image.
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
- The play driver maps a control's rectangle through its own viewport's transform only, so it lists controls inside a room's world image in the 322×182 image's pixels rather than the window's. That is why the box labels sit outside the image (`PixelView.follow()`). The seesaw's plank labels turn with the plank, so they stay in the image, and the driver lists them in image pixels.
- `tools/play_driver.gd` is generic and comes from the template through `tools/update.sh`. It loads `game/play_hooks.gd`, the game's HUD text, events and actions, only when it plays the game, not a `--scene`, and skips `screen()` or `watch()` when the file has none.
- `tools/play_driver.gd` stops time at each turn and trades files with the agent; `tools/game_mcp.py` only relays them. The server runs it with `--fixed-fps 60`, and the driver runs a `wait` or `hold` until its own sum of frame times reaches it, so the same seed and actions run the same frames. Frames still run, with no game time, while the driver waits for an action, so game code that must replay counts time from `delta`, not from frames. The server kills the whole process group on stop, because `xvfb-run` can exit before Godot does, and a stopped Godot ignores SIGTERM. With `--scene`, the driver sets that scene as the tree's current scene before adding it, as a normal launch does, so a prototype's `_ready()` and its `reload_current_scene()` restart both see it. `--replay` can't check for `--fixed-fps`, because Godot keeps its own options out of `OS.get_cmdline_args()`, so the docs give the command with it.
