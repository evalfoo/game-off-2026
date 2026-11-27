extends "res://tests/lib/test.gd"

# The play driver stops physics with time. Frames still run between turns,
# with no time, and a physics step of no time can make touching rigid bodies'
# positions NaN. Here a body pushes a box, in 2D and in 3D, when time stops.

const Driver := preload("res://tools/play_driver.gd")

func run() -> void:
	var floor_2d := StaticBody2D.new()
	floor_2d.position = Vector2(0, 100)
	_add_shape(floor_2d, WorldBoundaryShape2D.new())
	var pusher_2d := Pusher2D.new()
	var box_2d := RigidBody2D.new()
	for body: RigidBody2D in [pusher_2d, box_2d]:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(20, 20)
		_add_shape(body, shape)
	pusher_2d.position = Vector2(0, 89)
	box_2d.position = Vector2(25, 89)

	var floor_3d := StaticBody3D.new()
	_add_shape(floor_3d, WorldBoundaryShape3D.new())
	var pusher_3d := Pusher3D.new()
	var box_3d := RigidBody3D.new()
	for body: RigidBody3D in [pusher_3d, box_3d]:
		_add_shape(body, BoxShape3D.new())
	pusher_3d.position = Vector3(0, 0.5, 0)
	box_3d.position = Vector3(1.2, 0.5, 0)

	var bodies: Array[Node] = [floor_2d, pusher_2d, box_2d, floor_3d, pusher_3d, box_3d]
	for body in bodies:
		root.add_child(body)
	var physics_stop := Driver.PhysicsStop.new()   # as the driver adds it
	root.add_child(physics_stop)
	# A second of physics, at whatever tick rate the game sets.
	await _physics_frames(Engine.physics_ticks_per_second)
	check(box_2d.position.x > 100 and box_3d.position.x > 3, "the pushers push the boxes: %s, %s" % [box_2d.position, box_3d.position])

	# The driver stops and starts time after a frame's physics, as here. In a
	# frame's physics, its step's time is already fixed, and a step of no time
	# with physics running is what made the NaN.
	await frames(1)
	Driver._set_time_running(false)
	var before := _positions(bodies)
	var steps := [pusher_2d.steps, pusher_3d.steps]
	await _physics_frames(30)
	var after := _positions(bodies)
	check(after.all(func(position: Variant) -> bool: return position.is_finite()), "30 frames with time stopped leave every position finite: %s" % [after])
	check(after == before, "nothing moves while time is stopped: %s -> %s" % [before, after])
	check([pusher_2d.steps, pusher_3d.steps] == steps, "the 2D and 3D physics servers don't step while time is stopped")

	# A change made while time is stopped, such as a key the agent pressed,
	# applies on the first step once time runs.
	pusher_2d.speed = 600.0
	await frames(1)
	Driver._set_time_running(true)
	await physics_frame
	check(pusher_2d.steps == steps[0] + 1 and pusher_2d.used_speed == 600.0, "the first physics frame with time running calls _integrate_forces() with the new speed")
	await _physics_frames(9)
	check(box_2d.position.x > before[2].x and box_3d.position.x > before[5].x, "the boxes move again once time runs: %s, %s" % [box_2d.position, box_3d.position])

	# A pause menu: pausing the tree stops physics, and unpausing starts it.
	# Time runs on a paused tree without moving a body. A pause menu that
	# unpauses in its own _physics_process(), which runs before the step,
	# doesn't start physics while time is stopped. The game here keeps its root
	# processing while paused, which the driver's node mustn't inherit.
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	await frames(1)
	paused = true
	before = _positions(bodies)
	Driver._set_time_running(false)
	await frames(1)
	Driver._set_time_running(true)
	await _physics_frames(30)
	check(_positions(bodies) == before, "nothing moves while the tree is paused, though time runs: %s -> %s" % [before, _positions(bodies)])
	await frames(1)
	Driver._set_time_running(false)
	var menu := PauseMenu.new()
	root.add_child(menu)
	await _physics_frames(30)
	after = _positions(bodies)
	check(not paused and after.all(func(position: Variant) -> bool: return position.is_finite()) and after == before, "a menu unpausing the tree while time is stopped steps nothing and leaves every position finite: %s -> %s" % [before, after])
	await frames(1)
	Driver._set_time_running(true)
	await _physics_frames(10)
	check(box_2d.position.x > before[2].x and box_3d.position.x > before[5].x, "the boxes move once time runs on the unpaused tree: %s, %s" % [box_2d.position, box_3d.position])

	for body in bodies:
		body.free()
	menu.free()
	root.process_mode = Node.PROCESS_MODE_PAUSABLE

	# The game's own stop of time within a wait. Once it starts time again, a
	# body moves on. Its body touches nothing: the game's own steps of no time
	# can still make NaN.
	var ball := RigidBody2D.new()
	ball.gravity_scale = 0.0
	ball.linear_velocity = Vector2(100, 0)
	_add_shape(ball, CircleShape2D.new())
	root.add_child(ball)
	await _physics_frames(10)
	Engine.time_scale = 0.0
	await _physics_frames(5)
	Engine.time_scale = 1.0
	await _physics_frames(1)
	var x := ball.position.x
	await _physics_frames(10)
	check(ball.position.x > x, "a body moves again once the game's own stop of time ends: %s -> %s" % [x, ball.position.x])
	ball.free()
	physics_stop.free()

func _physics_frames(count: int) -> void:
	for i in count:
		await physics_frame

func _add_shape(body: Node, shape: Resource) -> void:
	var collision: Node = CollisionShape2D.new() if shape is Shape2D else CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

func _positions(bodies: Array[Node]) -> Array:
	return bodies.map(func(body: Node) -> Variant: return body.position)

# Keeps moving right whatever it hits, as a player's body would, and counts
# the physics steps that called it.
class Pusher2D extends RigidBody2D:
	var steps := 0
	var speed := 300.0
	var used_speed := 0.0

	func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
		steps += 1
		used_speed = speed
		state.linear_velocity = Vector2(speed, 0)

class Pusher3D extends RigidBody3D:
	var steps := 0

	func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
		steps += 1
		state.linear_velocity = Vector3(10, 0, 0)

# Unpauses the tree in its first physics frame, as a Resume key handled there
# would.
class PauseMenu extends Node:
	func _init() -> void:
		process_mode = PROCESS_MODE_ALWAYS

	func _physics_process(_delta: float) -> void:
		if get_tree().paused:
			get_tree().paused = false
