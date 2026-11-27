extends "res://tools/clips/scenario.gd"

# The seesaw room: the small player jumps onto the raised end, holds Shift and
# pushes it down, then lets go. The room isn't the main scene, so this swaps
# it in; record it on one ref, as main has no room to compare with.
#
#   tools/clips/record.sh tools/clips/scenarios/seesaw.gd HEAD

func run() -> void:
	game.free()
	game = (load("res://game/rooms/seesaw.tscn") as PackedScene).instantiate()
	root.add_child(game)
	fixture("the seesaw room, game/rooms/seesaw.tscn")
	await hold(1.0)
	start_clip()
	strip(20, "jump onto the raised end, hold Shift, let go")
	mark("walk right")
	Events.hold_key(KEY_RIGHT, true)
	await hold(0.4)
	mark("jump")
	Events.hold_key(KEY_SPACE, true)
	await hold(0.1)
	Events.hold_key(KEY_SPACE, false)
	await hold(0.6)
	Events.hold_key(KEY_RIGHT, false)
	await hold(0.5)
	mark("hold Shift")
	Events.hold_key(KEY_SHIFT, true)
	await hold(1.5)
	mark("let go of Shift")
	Events.hold_key(KEY_SHIFT, false)
	await hold(2.0)
	finish()
