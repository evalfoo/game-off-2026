extends "res://tests/lib/test.gd"

# The seesaw room, played: the small player runs and jumps onto the plank's
# raised left end, grows there to push it down, and rides it up again after
# shrinking.

func run() -> void:
	var room: Node2D = (load("res://game/rooms/seesaw.tscn") as PackedScene).instantiate()
	root.add_child(room)
	var plank: AnimatableBody2D = room.plank
	var player: CharacterBody2D = room.player
	await physics(30)
	Events.hold_key(KEY_RIGHT, true)
	await physics(24)
	Events.hold_key(KEY_SPACE, true)
	await physics(36)
	Events.hold_key(KEY_SPACE, false)
	Events.hold_key(KEY_RIGHT, false)
	await physics(30)
	var pivot_x: float = room.PIVOT.x
	check(player.is_on_floor() and player.position.x < pivot_x and plank.rotation > 0.1, "the player lands on the raised left end: %s, rotation %.2f" % [player.position, plank.rotation])

	Events.hold_key(KEY_SHIFT, true)
	await physics(90)
	check(plank.rotation < -0.1, "growing there pushes the left end down: rotation %.2f" % plank.rotation)
	Events.hold_key(KEY_SHIFT, false)

	await physics(120)
	var floor_y: float = room.FLOOR_Y
	check(plank.rotation > 0.1, "shrinking lets the weight lift the left end again: rotation %.2f" % plank.rotation)
	check(player.is_on_floor() and player.position.y < floor_y - 20.0, "the player rides it up and stays on: feet at y %.1f" % player.position.y)

func physics(count: int) -> void:
	for i: int in count:
		await physics_frame
