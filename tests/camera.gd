extends "res://tests/lib/test.gd"

# The camera in the wide room, at both sizes: it starts on the player inside
# the room's limits, holds still while the player walks inside its window,
# scrolls with the window's edge when they push against it, keeps its height
# through a jump and moves it after landing on the step, and stops at the
# room's edges. Every physics frame checks the view stays inside the room.

const HALF_VIEW := Vector2(160, 90)

var room: Node2D
var player: CharacterBody2D
var camera: Camera2D
# Frames whose view showed something outside the room.
var outside := 0


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
	outside = 0

	await physics(1)
	check(_centre().distance_to(Vector2(HALF_VIEW.x, floor_y - feet_below)) < 0.01,
		"%s: the view starts on the player, held off the left edge: %s" % [label, _centre()])
	if big:
		Events.hold_key(KEY_SHIFT, true)
		await physics(40)

	# Walk right past the window's right edge.
	await _walk(KEY_RIGHT, func() -> bool: return player.position.x >= 300.0)
	await physics(90)
	check(absf(_centre().x - (player.position.x - margin)) < 0.5,
		"%s: walking right, the player ends at the window's right edge: player x %.1f, view x %.1f" % [label, player.position.x, _centre().x])

	# Turn and walk left, inside the window: the view holds.
	var held := _centre().x
	var turned_at := player.position.x
	await _walk(KEY_LEFT, func() -> bool: return player.position.x <= turned_at - margin)
	check(absf(_centre().x - held) < 0.5,
		"%s: turning and walking inside the window leaves the view: %.1f -> %.1f" % [label, held, _centre().x])
	# On past its left edge: the view follows that edge.
	await _walk(KEY_LEFT, func() -> bool: return player.position.x <= turned_at - 3.0 * margin)
	await physics(90)
	check(absf(_centre().x - (player.position.x + margin)) < 0.5,
		"%s: walking on left, the player ends at the window's left edge: player x %.1f, view x %.1f" % [label, player.position.x, _centre().x])

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
	await physics(120)
	check(absf(_centre().y - (step_y - feet_below)) < 0.5,
		"%s: after landing on the step the view rises with it: %.1f -> %.1f" % [label, floor_view_y, _centre().y])

	# Walk into the right wall: the view stops at the room's right edge.
	player.position = Vector2(size.x - 40.0, floor_y)
	await _walk(KEY_RIGHT, func() -> bool: return player.is_on_wall())
	await physics(180)
	check(absf(_centre().x - (size.x - HALF_VIEW.x)) < 0.01,
		"%s: at the right wall the view stops at the room's edge: %.1f" % [label, _centre().x])

	check(outside == 0, "%s: the view stays inside the room every frame: %d frames outside" % [label, outside])
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


# Waits for the player to leave the floor and land again. Returns how far the
# feet rose and how far the view's height moved while in the air.
func _air_time() -> Dictionary:
	var start_y := player.position.y
	var view_y := _centre().y
	var top := start_y
	var moved := 0.0
	for i: int in 300:
		await physics(1)
		top = minf(top, player.position.y)
		if player.is_on_floor() and i > 2:
			break
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
