extends "res://tests/lib/test.gd"

# Holding Shift eases the player to big, heavy and slow, with its feet still on
# the floor. Letting go eases it back.

func run() -> void:
	var game := Fixture.launch(root)
	await physics(10)
	var player: CharacterBody2D = game.player
	var floor_y: float = game.FLOOR_Y
	check(_is(player, "small"), "a new game starts small, light and fast")

	Events.hold_key(KEY_SHIFT, true)
	await physics(40)
	check(_is(player, "big"), "holding Shift makes the player big, heavy and slow: %s, %s, %s" % [player.size, player.mass, player.speed])
	check(absf(player.position.y - floor_y) < 2.0, "it grows upward, feet on the floor: y %.1f" % player.position.y)

	Events.hold_key(KEY_SHIFT, false)
	await physics(40)
	check(_is(player, "small"), "letting go makes it small, light and fast again")

func _is(player: CharacterBody2D, state: String) -> bool:
	return player.size == player.get(state + "_size") \
		and is_equal_approx(player.mass, player.get(state + "_mass")) \
		and is_equal_approx(player.speed, player.get(state + "_speed"))

func physics(count: int) -> void:
	for i: int in count:
		await physics_frame
