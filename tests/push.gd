extends "res://tests/lib/test.gd"

# BOX B is too heavy for the small player. Only the big one pushes it. The
# player can only push one box: not BOX A when it rests against BOX B.

func run() -> void:
	var small_push := await _push(false)
	check(small_push < 1.0, "the small player can't move BOX B: moved %.1f px" % small_push)
	var big_push := await _push(true)
	check(big_push > 7.0, "the big player pushes BOX B: moved %.1f px" % big_push)
	var stack_push := await _push_stack()
	check(stack_push < 1.0, "the big player can't push BOX A against BOX B: moved %.1f px" % stack_push)

# Walks right into BOX B for 3 seconds and returns how far the box moved.
func _push(big: bool) -> float:
	var game := Fixture.launch(root)
	game.get_node("View/World/BoxA").free()
	var box: CharacterBody2D = game.get_node("View/World/BoxB")
	var player: CharacterBody2D = game.player
	player.position.x = box.position.x - 50
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

# Walks the big player right into BOX A, resting against BOX B, for 3 seconds
# and returns how far BOX A moved.
func _push_stack() -> float:
	var game := Fixture.launch(root)
	var box_a: CharacterBody2D = game.get_node("View/World/BoxA")
	var box_b: CharacterBody2D = game.get_node("View/World/BoxB")
	box_a.position.x = box_b.position.x - 16 - 8
	var player: CharacterBody2D = game.player
	player.position.x = box_a.position.x - 50
	Events.hold_key(KEY_SHIFT, true)
	await physics(40)
	var start := box_a.position.x
	Events.hold_key(KEY_RIGHT, true)
	await physics(180)
	Events.hold_key(KEY_RIGHT, false)
	Events.hold_key(KEY_SHIFT, false)
	var moved := box_a.position.x - start
	game.free()
	await physics(2)
	return moved

func physics(count: int) -> void:
	for i: int in count:
		await physics_frame
