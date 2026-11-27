extends "res://tests/lib/test.gd"

# Looking up and down in the wide room: holding Up or Down on the floor moves
# the view by look_distance, and letting go brings it back. The room's floor
# sits near its bottom, so the full look down is checked with the room's bottom
# limit staged lower, and the unstaged room checks the view stops at its edge
# and starts back as soon as Down is let go.

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


func _hold(key: Key, count: int) -> void:
	Events.hold_key(key, true)
	await physics(count)
	Events.hold_key(key, false)


func _centre_y() -> float:
	return camera.get_screen_center_position().y


func physics(count: int) -> void:
	for i: int in count:
		await physics_frame
