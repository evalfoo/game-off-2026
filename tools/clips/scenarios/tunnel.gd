extends "res://tools/clips/scenario.gd"

# The tunnel level: the big player walks into the wall and stops. It lets go of
# Shift, walks into the tunnel small, holds Shift there and stays small, then
# walks out and grows once big fits. The level isn't the main scene, so this
# swaps it in; record it on one ref, as the main branch had no such level to
# compare with.
#
#   tools/clips/record.sh tools/clips/scenarios/tunnel.gd HEAD

func run() -> void:
	game.free()
	game = (load("res://game/levels/tunnel.tscn") as PackedScene).instantiate()
	root.add_child(game)
	fixture("the tunnel level, game/levels/tunnel.tscn")
	await hold(0.5)
	start_clip()
	strip(30, "big into the wall, small into the tunnel, Shift held in it and out of it")
	mark("hold Shift, walk right")
	Events.hold_key(KEY_SHIFT, true)
	await hold(0.5)
	Events.hold_key(KEY_RIGHT, true)
	await hold(2.0)
	mark("let go of Shift")
	Events.hold_key(KEY_SHIFT, false)
	var player: Node2D = game.player
	while player.global_position.x < 176.0:
		await hold(1.0 / FPS)
	Events.hold_key(KEY_RIGHT, false)
	await hold(0.3)
	mark("hold Shift in the tunnel")
	Events.hold_key(KEY_SHIFT, true)
	await hold(1.0)
	mark("walk out, Shift held")
	Events.hold_key(KEY_RIGHT, true)
	await hold(2.0)
	Events.hold_key(KEY_RIGHT, false)
	await hold(0.5)
	Events.hold_key(KEY_SHIFT, false)
	finish()
