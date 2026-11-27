extends "res://tests/lib/test.gd"

# The seesaw room: the WEIGHT holds the plank's right end down. The small
# player standing on the left tip can't tip it; growing there pushes the left
# end down.

func run() -> void:
	var room: Node2D = (load("res://game/rooms/seesaw.tscn") as PackedScene).instantiate()
	root.add_child(room)
	var plank: RigidBody2D = room.plank
	var player: RigidBody2D = room.player
	await physics(60)
	check(plank.rotation > 0.1, "the weight holds the right end down: rotation %.2f" % plank.rotation)

	# The worst case for the small player is the very tip, the longest lever.
	var tip := plank.to_global(Vector2(-room.PLANK_SIZE.x / 2 + 16, -room.PLANK_SIZE.y / 2 - 1))
	player.global_position = tip
	await physics(120)
	check(plank.rotation > 0.1, "the small player on the left tip leaves it there: rotation %.2f" % plank.rotation)

	Events.hold_key(KEY_SHIFT, true)
	await physics(120)
	check(plank.rotation < -0.1, "growing there pushes the left end down: rotation %.2f" % plank.rotation)
	var weight: RigidBody2D = room.weight
	check(weight.position.is_finite() and weight.position.y < plank.position.y, "the weight stays on the plank: %s" % weight.position)
	Events.hold_key(KEY_SHIFT, false)

func physics(count: int) -> void:
	for i: int in count:
		await physics_frame
