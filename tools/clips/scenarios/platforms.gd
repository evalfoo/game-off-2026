extends "res://tools/clips/scenario.gd"

# The platforms room: the small player walks onto the left platform, holds
# Shift and sinks it while the right one rises, then lets go and both return.
# The room isn't the main scene, so this swaps it in; record it on one ref, as
# main has no room to compare with.
#
#   tools/clips/record.sh tools/clips/scenarios/platforms.gd HEAD

func run() -> void:
	game.free()
	game = (load("res://game/rooms/platforms.tscn") as PackedScene).instantiate()
	root.add_child(game)
	fixture("the platforms room, game/rooms/platforms.tscn")
	await hold(0.5)
	start_clip()
	strip(20, "walk onto the left platform, hold Shift, let go")
	mark("walk right")
	Events.hold_key(KEY_RIGHT, true)
	var player: Node2D = game.player
	var left: Node2D = game.pair.left
	while player.global_position.x < left.global_position.x:
		await hold(1.0 / FPS)
	Events.hold_key(KEY_RIGHT, false)
	await hold(0.3)
	mark("hold Shift")
	Events.hold_key(KEY_SHIFT, true)
	await hold(2.0)
	mark("let go of Shift")
	Events.hold_key(KEY_SHIFT, false)
	await hold(2.0)
	finish()
