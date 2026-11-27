extends "res://tests/lib/test.gd"

# Looking up and down in the wide room: holding Up or Down on the floor moves
# the view by look_distance, and letting go brings it back. The room's floor
# sits near its bottom, so the full look down is checked with the room's bottom
# limit staged lower, and the unstaged room checks the view stops at its edge
# and starts back as soon as Down is let go.
#
# Also: the held look stays put at smoothing speeds 0 and 30 and through a
# jump with Up held, walking off the step while looking up keeps the player on
# screen, and looking down from a platform at the room's top leaves the view
# at its top edge.

const Tiles := preload("res://game/tiles.gd")
const HALF_VIEW := Vector2(160, 90)

var room: Node2D
var camera: Camera2D


func run() -> void:
	room = (load("res://game/rooms/wide.tscn") as PackedScene).instantiate()
	root.add_child(room)
	camera = room.camera
	var distance: float = camera.look_distance
	await physics(60)
	var rest := _centre_y()

	await _hold(KEY_UP, 120)
	check(absf(_centre_y() - (rest - distance)) < 0.5,
		"holding Up moves the view up %d px: %.1f -> %.1f" % [distance, rest, _centre_y()])
	await physics(120)
	check(absf(_centre_y() - rest) < 0.5,
		"letting go of Up brings the view back: %.1f" % _centre_y())

	# Staged: the room's bottom limit lowered, so the look down has room.
	var bottom: int = camera.limit_bottom
	camera.limit_bottom = bottom + 200
	await _hold(KEY_DOWN, 120)
	check(absf(_centre_y() - (rest + distance)) < 0.5,
		"staged: holding Down moves the view down %d px: %.1f -> %.1f" % [distance, rest, _centre_y()])
	await physics(120)
	check(absf(_centre_y() - rest) < 0.5,
		"staged: letting go of Down brings the view back: %.1f" % _centre_y())
	camera.limit_bottom = bottom

	# Unstaged: the view stops at the room's bottom edge and leaves it on the
	# first frames after Down is let go.
	var edge := bottom - 90.0
	await _hold(KEY_DOWN, 120)
	check(absf(_centre_y() - edge) < 0.01,
		"holding Down at the room's bottom stops the view at its edge: %.1f" % _centre_y())
	var still := 0
	for i: int in 60:
		await physics(1)
		if _centre_y() < edge - 0.01:
			break
		still += 1
	check(still <= 1, "letting go of Down at the room's edge, the view starts back after %d frames" % still)
	await physics(120)
	check(absf(_centre_y() - rest) < 0.5,
		"and comes back to where it was: %.1f" % _centre_y())

	# The look holds through a jump, as the height does.
	Events.hold_key(KEY_UP, true)
	await physics(120)
	var looked := _centre_y()
	Events.hold_key(KEY_SPACE, true)
	await physics(2)
	Events.hold_key(KEY_UP, false)
	var moved := 0.0
	for i: int in 120:
		await physics(1)
		if room.player.is_on_floor():
			break
		moved = maxf(moved, absf(_centre_y() - looked))
	Events.hold_key(KEY_SPACE, false)
	check(moved < 0.5, "letting go of Up in the air holds the view until landing: moved %.1f px" % moved)
	await physics(120)
	check(absf(_centre_y() - rest) < 0.5, "after landing the view comes back: %.1f" % _centre_y())
	room.free()
	await physics(2)

	await _check_held_up(0.0)
	await _check_held_up(30.0)
	await _check_jump_looking_up()
	await _check_walk_off_looking_up()
	await _check_down_at_top()


func _new_room() -> void:
	room = (load("res://game/rooms/wide.tscn") as PackedScene).instantiate()
	root.add_child(room)
	camera = room.camera


func _free_room() -> void:
	room.free()
	await physics(2)


# Holding Up on the floor, the view sits look_distance higher on every frame.
func _check_held_up(speed: float) -> void:
	_new_room()
	camera.small_smoothing_speed = speed
	camera.big_smoothing_speed = speed
	await physics(60)
	var rest := _centre_y()
	Events.hold_key(KEY_UP, true)
	await physics(60)
	var view := [_centre_y(), _centre_y()]
	for i: int in 30:
		await physics(1)
		view[0] = minf(view[0], _centre_y())
		view[1] = maxf(view[1], _centre_y())
	Events.hold_key(KEY_UP, false)
	check(view[1] - view[0] < 0.01 and absf(view[0] - (rest - camera.look_distance)) < 0.5,
		"smoothing speed %.0f: holding Up, the view stays %d px up on every frame: y %.1f to %.1f, from %.1f" % [speed, camera.look_distance, view[0], view[1], rest])
	await _free_room()


# Jumping while Up is held: the view holds the look through the jump and the
# landing, the landing frame included.
func _check_jump_looking_up() -> void:
	_new_room()
	var player: CharacterBody2D = room.player
	await physics(60)
	Events.hold_key(KEY_UP, true)
	await physics(120)
	var looked := _centre_y()
	Events.hold_key(KEY_SPACE, true)
	await physics(2)
	var moved := 0.0
	var landed := false
	var after := 0
	for i: int in 300:
		await physics(1)
		moved = maxf(moved, absf(_centre_y() - looked))
		if not player.is_on_floor():
			Events.hold_key(KEY_SPACE, false)
			landed = true
		elif landed:
			after += 1
			if after >= 30:
				break
	Events.hold_key(KEY_SPACE, false)
	Events.hold_key(KEY_UP, false)
	check(landed and after >= 30 and moved < 0.5,
		"jumping with Up held, the view holds the look through the landing and 30 frames after: moved at most %.2f px" % moved)
	await _free_room()


# Walking off the step while looking up: the look ends on the first frame of
# the drop, so the feet stay inside the view while the player falls.
func _check_walk_off_looking_up() -> void:
	_new_room()
	var player: CharacterBody2D = room.player
	var step_y := float(room.STEP_ROW * Tiles.TILE)
	player.position = Vector2((room.STEP_LAST - 2) * Tiles.TILE, step_y)
	await physics(120)
	Events.hold_key(KEY_UP, true)
	await physics(120)
	var looked: float = step_y - camera.feet_below_centre - camera.look_distance
	check(player.is_on_floor() and absf(_centre_y() - looked) < 0.5,
		"staged: on the step and looking up, the view is at y %.1f" % _centre_y())
	# The look itself puts the feet below the view on purpose, so only the
	# frames in the air count.
	var off_screen := 0
	var lowest := -INF
	var airborne := 0
	Events.hold_key(KEY_RIGHT, true)
	for i: int in 300:
		await physics(1)
		if player.is_on_floor():
			if airborne > 0:
				break
			continue
		airborne += 1
		var feet := player.position.y - _centre_y()
		lowest = maxf(lowest, feet)
		if feet > HALF_VIEW.y or feet - player.shape.size.y < -HALF_VIEW.y:
			off_screen += 1
	Events.hold_key(KEY_RIGHT, false)
	Events.hold_key(KEY_UP, false)
	check(airborne > 0 and off_screen == 0 and lowest <= camera.window_bottom + 0.5,
		"walking off the step while looking up, the player stays on screen in the air: %d of %d frames off, feet at most %.2f px below the view's centre" % [off_screen, airborne, lowest])
	await _free_room()


# Looking down from a platform near the room's top: the view is already at
# the top edge, and the look doesn't move it down past the feet.
func _check_down_at_top() -> void:
	_new_room()
	var player: CharacterBody2D = room.player
	Tiles.platform(room.get_node("Tiles"), 2, 4, 12)
	player.position = Vector2(8 * Tiles.TILE, 2 * Tiles.TILE)
	await physics(120)
	check(player.is_on_floor() and absf(_centre_y() - HALF_VIEW.y) < 0.01,
		"staged: on a platform at y 32, the view is at the room's top edge: %.1f" % _centre_y())
	Events.hold_key(KEY_DOWN, true)
	var highest := _centre_y()
	for i: int in 120:
		await physics(1)
		highest = maxf(highest, _centre_y())
	Events.hold_key(KEY_DOWN, false)
	check(absf(highest - HALF_VIEW.y) < 0.01,
		"holding Down on a platform at the room's top leaves the view at its top edge: at most y %.1f" % highest)
	await _free_room()


func _hold(key: Key, count: int) -> void:
	Events.hold_key(key, true)
	await physics(count)
	Events.hold_key(key, false)


func _centre_y() -> float:
	return camera.get_screen_center_position().y


func physics(count: int) -> void:
	for i: int in count:
		await physics_frame
