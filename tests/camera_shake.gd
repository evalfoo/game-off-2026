extends "res://tests/lib/test.gd"

# Screen shake in the wide room: the view stays within the shake's strength of
# where it would be, and the shake ends once its length has passed. With time
# stopped, as the play driver does between turns, it holds still. The same
# walk and jumps, run with and without a long shake, follow the same path, so
# a shake doesn't move where the camera goes.

const STRENGTH := 4.0
const FRAMES := 30
const STEP := 1.0 / 60.0


func run() -> void:
	var room := _room()
	var camera: Camera2D = room.camera
	await physics(30)
	camera.shake(STRENGTH, FRAMES * STEP)
	var largest := 0.0
	var at_last := 0.0
	for i: int in FRAMES:
		await physics(1)
		largest = maxf(largest, camera.offset.length())
		if i == FRAMES - 2:
			at_last = camera.offset.length()
	check(largest <= STRENGTH + 0.001 and largest > STRENGTH * 0.5,
		"a %d px shake moves the view up to %.2f px" % [STRENGTH, largest])
	check(at_last > 0.0 and camera.offset == Vector2.ZERO,
		"the shake runs to its last step (%.3f px) and ends after %d frames" % [at_last, FRAMES])
	await physics(10)
	check(camera.offset == Vector2.ZERO, "and stays ended")

	# Time stopped: the frame under way keeps its length, so the pause starts a
	# frame later.
	camera.shake(STRENGTH, 1.0)
	await physics(5)
	Engine.time_scale = 0.0
	await physics(1)
	var before := camera.offset
	await physics(20)
	var paused := camera.offset
	Engine.time_scale = 1.0
	await physics(2)
	check(before != Vector2.ZERO and paused == before and camera.offset != paused,
		"with time stopped the shake holds still, and moves on once time runs: %s -> %s" % [before, paused])
	room.free()
	await physics(2)

	var calm := await _walk_and_jump(false)
	var shaken := await _walk_and_jump(true)
	var apart := 0.0
	for i: int in calm.size():
		apart = maxf(apart, calm[i].distance_to(shaken[i]))
	check(calm.size() == shaken.size() and apart < 0.001,
		"walking and jumping, a shake leaves the camera's path alone: %.4f px apart" % apart)


func _room() -> Node2D:
	var room: Node2D = (load("res://game/rooms/wide.tscn") as PackedScene).instantiate()
	root.add_child(room)
	return room


# Walks right, jumping twice, and returns the view's centre less the shake
# each frame.
func _walk_and_jump(shaking: bool) -> Array[Vector2]:
	var room := _room()
	var camera: Camera2D = room.camera
	var path: Array[Vector2] = []
	await physics(2)
	if shaking:
		camera.shake(6.0, 10.0)
	Events.hold_key(KEY_RIGHT, true)
	for i: int in 240:
		Events.hold_key(KEY_SPACE, i % 100 < 20)
		await physics(1)
		path.append(camera.get_screen_center_position() - camera.offset)
	Events.hold_key(KEY_RIGHT, false)
	Events.hold_key(KEY_SPACE, false)
	room.free()
	await physics(2)
	return path


func physics(count: int) -> void:
	for i: int in count:
		await physics_frame
