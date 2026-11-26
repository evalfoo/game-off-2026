extends "res://tests/lib/test.gd"

# BOX B is too heavy for the small player. Only the big one pushes it.

func run() -> void:
	var small_push := await _push(false)
	check(small_push < 3.0, "the small player can't move BOX B: moved %.1f px" % small_push)
	var big_push := await _push(true)
	check(big_push > 20.0, "the big player pushes BOX B: moved %.1f px" % big_push)

# Walks right into BOX B for 3 seconds and returns how far the box moved.
func _push(big: bool) -> float:
	var game := Fixture.launch(root)
	game.get_node("BoxA").free()
	var box: RigidBody2D = game.get_node("BoxB")
	var player: RigidBody2D = game.player
	player.position.x = box.position.x - 150
	if big:
		Events.hold_key(KEY_SHIFT, true)
	await physics(40)
	var start := box.position.x
	Events.hold_key(KEY_RIGHT, true)
	await physics(180)
	Events.hold_key(KEY_RIGHT, false)
	Events.hold_key(KEY_SHIFT, false)
	var moved := box.position.x - start
	game.free()
	await physics(2)
	return moved

func physics(count: int) -> void:
	for i: int in count:
		await physics_frame
