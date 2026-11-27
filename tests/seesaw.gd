extends "res://tests/lib/test.gd"

# The seesaw room: the WEIGHT holds the plank's right end down. The small
# player standing on the left tip can't tip it; growing there pushes the left
# end down, and shrinking lets the weight lift it, and the player, again.

func run() -> void:
	var room: Node2D = (load("res://game/rooms/seesaw.tscn") as PackedScene).instantiate()
	root.add_child(room)
	var plank: AnimatableBody2D = room.plank
	var player: CharacterBody2D = room.player
	await physics(60)
	check(plank.rotation > 0.1, "the weight holds the right end down: rotation %.2f" % plank.rotation)

	# The worst case for the small player is the very tip, the longest lever.
	var tip := plank.to_global(Vector2(-room.PLANK_SIZE.x / 2 + 16, -room.PLANK_SIZE.y - 1))
	player.global_position = tip
	await physics(120)
	check(plank.rotation > 0.1, "the small player on the left tip leaves it there: rotation %.2f" % plank.rotation)

	Events.hold_key(KEY_SHIFT, true)
	await physics(120)
	check(plank.rotation < -0.1, "growing there pushes the left end down: rotation %.2f" % plank.rotation)
	Events.hold_key(KEY_SHIFT, false)

	await physics(120)
	check(plank.rotation > 0.1, "shrinking lets the weight lift the left end again: rotation %.2f" % plank.rotation)
	var floor_y: float = room.FLOOR_Y
	check(player.is_on_floor() and player.position.y < floor_y - 20.0, "the player rides it up: feet at y %.1f" % player.position.y)

func physics(count: int) -> void:
	for i: int in count:
		await physics_frame
