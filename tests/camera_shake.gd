extends "res://tests/lib/test.gd"

# Screen shake in the wide level: the view stays within the shake's strength of
# where it would be, and the shake ends once its length has passed. A one-step
# shake still moves the view, and a shake of length 0 stops the one running.
# At the level's edge the shake stays inside the level. With time stopped, as the
# play driver does between turns, it holds still. The same walk and jumps, run
# with and without a long shake, follow the same path, so a shake doesn't move
# where the camera goes.

const STRENGTH := 4.0
const FRAMES := 30
const STEP := 1.0 / 60.0
const HALF_VIEW := Vector2(160, 90)


func run() -> void:
	var level := _level()
	var camera: Camera2D = level.camera
	await physics(30)
	# Each step shows the shake as it is when the step starts, so a shake of
	# FRAMES steps moves the view on steps 1 to FRAMES and is gone on the next.
	camera.shake(STRENGTH, FRAMES * STEP)
	var largest := 0.0
	var smallest := INF
	for i: int in FRAMES:
		await physics(1)
		largest = maxf(largest, camera.offset.length())
		smallest = minf(smallest, camera.offset.length())
	await physics(1)
	check(largest <= STRENGTH + 0.001 and largest > STRENGTH * 0.5,
		"a %d px shake moves the view up to %.2f px" % [STRENGTH, largest])
	check(smallest > 0.0 and camera.offset == Vector2.ZERO,
		"the shake moves the view on each of its %d steps (at least %.3f px) and is gone the step after" % [FRAMES, smallest])
	await physics(10)
	check(camera.offset == Vector2.ZERO, "and stays ended")

	camera.shake(STRENGTH, STEP)
	await physics(1)
	var one := camera.offset.length()
	await physics(1)
	check(absf(one - STRENGTH) < 0.001 and camera.offset == Vector2.ZERO,
		"a one-step shake moves the view %.2f px and is gone the step after" % one)

	camera.shake(STRENGTH, 1.0)
	await physics(5)
	var running := camera.offset
	camera.shake(STRENGTH, 0.0)
	await physics(1)
	var stopped := camera.offset
	await physics(60)
	check(running != Vector2.ZERO and stopped == Vector2.ZERO and camera.offset == Vector2.ZERO,
		"a shake of length 0 stops the one running: %s -> %s" % [running, stopped])

	# At the level's bottom edge, which Down reaches on the wide level's floor.
	# The shake still moves the view, but no frame shows past the level.
	Events.hold_key(KEY_DOWN, true)
	await physics(120)
	var bottom := float(camera.limit_bottom) - HALF_VIEW.y
	var at_edge := absf(camera.get_screen_center_position().y - bottom) < 0.01
	camera.shake(STRENGTH, FRAMES * STEP)
	var outside := 0.0
	var moved := 0.0
	for i: int in FRAMES:
		await physics(1)
		var c := camera.get_screen_center_position()
		var size: Vector2 = level.SIZE
		outside = maxf(outside, maxf(c.y - (size.y - HALF_VIEW.y), HALF_VIEW.y - c.y))
		outside = maxf(outside, maxf(c.x - (size.x - HALF_VIEW.x), HALF_VIEW.x - c.x))
		moved = maxf(moved, camera.offset.length())
	Events.hold_key(KEY_DOWN, false)
	check(at_edge and moved > STRENGTH * 0.5 and outside <= 0.001,
		"at the level's bottom edge a shake moves the view up to %.2f px and shows %.2f px past the level" % [moved, maxf(outside, 0.0)])
	await physics(120)

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
	level.free()
	await physics(2)

	var calm := await _walk_and_jump(false)
	var shaken := await _walk_and_jump(true)
	var apart := 0.0
	for i: int in calm.size():
		apart = maxf(apart, calm[i].distance_to(shaken[i]))
	check(calm.size() == shaken.size() and apart < 0.001,
		"walking and jumping, a shake leaves the camera's path alone: %.4f px apart" % apart)


func _level() -> Node2D:
	var level: Node2D = (load("res://game/levels/wide.tscn") as PackedScene).instantiate()
	root.add_child(level)
	return level


# Walks right, jumping twice, and returns the view's centre less the shake
# each frame.
func _walk_and_jump(shaking: bool) -> Array[Vector2]:
	var level := _level()
	var camera: Camera2D = level.camera
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
	level.free()
	await physics(2)
	return path


func physics(count: int) -> void:
	for i: int in count:
		await physics_frame
