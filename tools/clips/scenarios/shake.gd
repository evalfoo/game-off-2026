extends "res://tools/clips/scenario.gd"

# Screen shake in the wide room: a 4 px shake for 0.5 s while the player
# stands, then a 6 px shake for 1 s while they walk right and jump. Nothing in
# the game shakes yet, so the scenario calls the camera's shake(). It isn't on
# origin/main, so record one ref:
#
#   tools/clips/record.sh tools/clips/scenarios/shake.gd HEAD

func run() -> void:
	game.free()
	game = (load("res://game/rooms/wide.tscn") as PackedScene).instantiate()
	root.add_child(game)
	fixture("the wide room, small player; the scenario calls camera.shake()")
	var camera: Camera2D = game.get("camera")
	start_clip()
	await hold(0.3)
	strip(4, "a 4 px shake standing, then a 6 px shake walking and jumping")
	mark("shake 4 px for 0.5 s")
	camera.call("shake", 4.0, 0.5)
	await hold(1.0)
	mark("shake 6 px for 1 s, walk right and jump")
	camera.call("shake", 6.0, 1.0)
	Events.hold_key(KEY_RIGHT, true)
	Events.hold_key(KEY_SPACE, true)
	await hold(0.3)
	Events.hold_key(KEY_SPACE, false)
	await hold(1.0)
	Events.hold_key(KEY_RIGHT, false)
	await hold(0.5)
	finish()
