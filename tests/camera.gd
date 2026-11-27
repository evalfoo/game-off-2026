extends "res://tests/lib/test.gd"

# The camera in the wide room, at both sizes: it starts on the look-ahead
# point in front of the player inside the room's limits, holds still while that
# point moves inside its window, scrolls with the window's edge when it pushes
# against it, keeps the point on the side the player walks toward until they
# walk flip_distance back, keeps its height through a jump and moves it after
# landing on the step, and stops at the room's edges. Every physics frame
# checks the view stays inside the room.

const HALF_VIEW := Vector2(160, 90)

var room: Node2D
var player: CharacterBody2D
var camera: Camera2D
# Frames whose view showed something outside the room.
var outside := 0
# How far ahead of the player the view's centre settles walking right, by size.
var leads := {}


func run() -> void:
	await _check_size(false)
	await _check_size(true)


func _check_size(big: bool) -> void:
	var label := "big" if big else "small"
	room = (load("res://game/rooms/wide.tscn") as PackedScene).instantiate()
	root.add_child(room)
	player = room.player
	camera = room.camera
	var feet_below: float = camera.feet_below_centre
	var margin: float = camera.window_margin * HALF_VIEW.x
	var floor_y: float = room.FLOOR_Y
	var size: Vector2 = room.SIZE
	var small_ahead: float = camera.small_look_ahead
	var ahead: float = camera.big_look_ahead if big else small_ahead
	var flip: float = camera.flip_distance
	outside = 0

	await physics(1)
	var start := Vector2(player.position.x + small_ahead, floor_y - feet_below)
	check(_centre().distance_to(start) < 0.01,
		"%s: the view starts on the point %d px right of the player: %s" % [label, small_ahead, _centre()])
	if big:
		Events.hold_key(KEY_SHIFT, true)
		await physics(40)

	# Walk right past the window's right edge, to short of the step. While
	# walking, the view eases after the window's edge rather than keeping up
	# with it.
	var start_x := _centre().x
	await _walk(KEY_RIGHT, func() -> bool: return player.position.x >= 360.0)
	var lag := player.position.x + ahead - margin - _centre().x
	check(_centre().x > start_x + 1.0 and lag > 2.0,
		"%s: walking right, the view follows but trails the window's edge: view x %.1f -> %.1f, %.1f px behind" % [label, start_x, _centre().x, lag])
	await physics(90)
	var lead := _centre().x - player.position.x
	check(absf(lead - (ahead - margin)) < 0.5,
		"%s: walking right, the look-ahead point ends at the window's right edge, %.1f px ahead of the player" % [label, lead])
	leads[label] = lead

	# A short turn, under flip_distance back from where the player stopped: the
	# look-ahead point stays right and moves inside the window, so the view
	# holds.
	var held := _centre().x
	var turned_at := player.position.x
	await _walk(KEY_LEFT, func() -> bool: return player.position.x <= turned_at - (flip - 8.0))
	await physics(30)
	check(camera.side == 1.0 and absf(_centre().x - held) < 0.5,
		"%s: a short turn back %.1f px leaves the look-ahead point right and the view: %.1f -> %.1f" % [label, turned_at - player.position.x, held, _centre().x])
	# On left: the point flips once the player is flip_distance back.
	var flipped_at := await _walk_until_flip(label, KEY_LEFT, turned_at - 3.0 * margin)
	check(turned_at - flipped_at >= flip and turned_at - flipped_at < flip + 3.0,
		"%s: walking on left, the look-ahead point flips %.1f px back from where the player turned" % [label, turned_at - flipped_at])
	await _walk(KEY_LEFT, func() -> bool: return player.position.x <= turned_at - 4.0 * margin)
	await physics(120)
	check(absf(_centre().x - (player.position.x - ahead + margin)) < 0.5,
		"%s: walking on left, the look-ahead point ends at the window's left edge: player x %.1f, view x %.1f" % [label, player.position.x, _centre().x])

	# Flipping back right needs the full distance again.
	held = _centre().x
	turned_at = player.position.x
	await _walk(KEY_RIGHT, func() -> bool: return player.position.x >= turned_at + (flip - 8.0))
	await physics(30)
	check(camera.side == -1.0 and absf(_centre().x - held) < 0.5,
		"%s: a short turn right %.1f px leaves the look-ahead point left and the view: %.1f -> %.1f" % [label, player.position.x - turned_at, held, _centre().x])
	flipped_at = await _walk_until_flip(label, KEY_RIGHT, turned_at + 3.0 * margin)
	check(flipped_at - turned_at >= flip and flipped_at - turned_at < flip + 3.0,
		"%s: walking on right, the look-ahead point flips back %.1f px from where the player turned" % [label, flipped_at - turned_at])

	# Jump in place: the height holds.
	var floor_view_y := _centre().y
	check(absf(floor_view_y - (floor_y - feet_below)) < 0.5,
		"%s: on the floor, the view centres %d px above the feet: %.1f" % [label, feet_below, floor_view_y])
	Events.hold_key(KEY_SPACE, true)
	var jump := await _air_time()
	Events.hold_key(KEY_SPACE, false)
	check(jump.rise > 15.0 and jump.moved < 0.5,
		"%s: a jump in place rises %.1f px and moves the view %.1f px" % [label, jump.rise, jump.moved])

	# Walk into the step's side and jump onto it: the height holds in the air
	# and moves to the step's after landing.
	var step_y: float = (room.STEP_ROW as int) * 16.0
	await _walk(KEY_RIGHT, func() -> bool: return player.is_on_wall(), true)
	Events.hold_key(KEY_SPACE, true)
	var climb := await _air_time()
	Events.hold_key(KEY_SPACE, false)
	Events.hold_key(KEY_RIGHT, false)
	check(absf(player.position.y - step_y) < 0.5 and climb.moved < 0.5,
		"%s: jumping onto the step lands at y %.1f with the view moved %.1f px in the air" % [label, player.position.y, climb.moved])
	# Jump again one step after landing, while the view is still easing up to
	# the step's height: it holds where it is until the player lands again.
	await physics(1)
	Events.hold_key(KEY_SPACE, true)
	var again := await _air_time()
	Events.hold_key(KEY_SPACE, false)
	check(absf(player.position.y - step_y) < 0.5 and again.rise > 15.0 and again.moved < 0.5,
		"%s: jumping again right after landing rises %.1f px and moves the view %.1f px in the air" % [label, again.rise, again.moved])
	await physics(120)
	check(absf(_centre().y - (step_y - feet_below)) < 0.5,
		"%s: after landing on the step the view rises with it: %.1f -> %.1f" % [label, floor_view_y, _centre().y])

	# Walk into the right wall: the view stops at the room's right edge.
	player.position = Vector2(size.x - 40.0, floor_y)
	await _walk(KEY_RIGHT, func() -> bool: return player.is_on_wall())
	await physics(180)
	check(absf(_centre().x - (size.x - HALF_VIEW.x)) < 0.01,
		"%s: at the right wall the view stops at the room's edge: %.1f" % [label, _centre().x])
	# Turning back from the wall, the view leaves the edge and follows the
	# look-ahead point left.
	await _walk(KEY_LEFT, func() -> bool: return player.position.x <= size.x - 2.0 * HALF_VIEW.x)
	await physics(120)
	check(camera.side == -1.0 and absf(_centre().x - (player.position.x - ahead + margin)) < 0.5,
		"%s: walking back from the wall, the view follows the look-ahead point: player x %.1f, view x %.1f" % [label, player.position.x, _centre().x])
	# Staged at whole-pixel positions, so the distances are exact: the player,
	# standing with the point left, is moved to x 600 and then right. Just short
	# of flip_distance the point stays left; exactly on it, it flips.
	player.position.x = 600.0
	await physics(2)
	player.position.x = 600.0 + flip - 0.01
	await physics(2)
	var short_side: float = camera.side
	player.position.x = 600.0 + flip
	await physics(2)
	check(short_side == -1.0 and camera.side == 1.0,
		"%s: standing %.2f px back keeps the point left, %.2f px back flips it: side %d, then %d" % [label, flip - 0.01, flip, short_side, camera.side])

	check(outside == 0, "%s: the view stays inside the room every frame: %d frames outside" % [label, outside])
	if big:
		check(leads.big > 0.0 and leads.big < leads.small,
			"the big player gets less look-ahead than the small one: %.1f px against %.1f px" % [leads.big, leads.small])
	Events.hold_key(KEY_SHIFT, false)
	room.free()
	await physics_frame
	await physics_frame


func _centre() -> Vector2:
	return camera.get_screen_center_position()


# Holds `key` until `done` returns true, up to 20 seconds, and lets go unless
# `keep` is true.
func _walk(key: Key, done: Callable, keep := false) -> void:
	Events.hold_key(key, true)
	for i: int in 1200:
		await physics(1)
		if done.call():
			break
	if not keep:
		Events.hold_key(key, false)


# Holds `key` until the look-ahead point changes sides, then lets go. Fails
# the check if the player reaches `limit` first. Returns the player's x on the
# frame it changed.
func _walk_until_flip(label: String, key: Key, limit: float) -> float:
	var side: float = camera.side
	var dir := 1.0 if key == KEY_RIGHT else -1.0
	Events.hold_key(key, true)
	for i: int in 1200:
		await physics(1)
		if camera.side != side or (player.position.x - limit) * dir >= 0.0:
			break
	Events.hold_key(key, false)
	check(camera.side == -side, "%s: the look-ahead point changes sides before x %.1f: at %.1f" % [label, limit, player.position.x])
	return player.position.x


# Waits for the player to leave the floor and land again. Returns how far the
# feet rose, and how far the view's height moved between the last frame on the
# floor and the landing. Before takeoff the view may still be easing.
func _air_time() -> Dictionary:
	var start_y := player.position.y
	var view_y := _centre().y
	var top := start_y
	var moved := 0.0
	var left := false
	for i: int in 300:
		await physics(1)
		top = minf(top, player.position.y)
		if player.is_on_floor():
			if left:
				break
			view_y = _centre().y
			continue
		left = true
		moved = maxf(moved, absf(_centre().y - view_y))
	return {"rise": start_y - top, "moved": moved}


func physics(count: int) -> void:
	for i: int in count:
		await physics_frame
		var c := _centre()
		var room_size: Vector2 = room.SIZE
		if c.x < HALF_VIEW.x - 0.01 or c.x > room_size.x - HALF_VIEW.x + 0.01 \
				or c.y < HALF_VIEW.y - 0.01 or c.y > room_size.y - HALF_VIEW.y + 0.01:
			outside += 1
