extends "res://tests/lib/test.gd"

# In a native window, a real Shift key held down grows the player, and letting
# go shrinks it again.

func run() -> void:
	var game := Fixture.launch(root)
	await physics(10)
	var player: CharacterBody2D = game.player
	Events.hold_key(KEY_SHIFT, true)
	await physics(40)
	check(player.shape.size == player.big_size, "holding Shift grows the player: %s" % player.shape.size)
	Events.hold_key(KEY_SHIFT, false)
	await physics(40)
	check(player.shape.size == player.small_size, "letting go shrinks it: %s" % player.shape.size)

func physics(count: int) -> void:
	for i: int in count:
		await physics_frame
