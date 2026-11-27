extends "res://tools/clips/scenario.gd"

# The camera on the seesaw plank: as in seesaw.gd, the small player jumps onto
# the raised end, holds Shift to push it down, then lets go and rides it up.
# The seesaw room has no camera, so this adds one, the same on both refs, with
# the room's side and bottom edges as limits. The room is one view, so its top
# stays open: with every limit the view could not move at all.
#
#   tools/clips/record.sh tools/clips/scenarios/seesaw_camera.gd

const PlayerCamera := preload("res://game/camera.gd")


func run() -> void:
	game.free()
	game = (load("res://game/rooms/seesaw.tscn") as PackedScene).instantiate()
	root.add_child(game)
	# After the room, whose _ready() adds the player.
	var camera := PlayerCamera.new()
	camera.target = game.player
	camera.limit_left = 0
	camera.limit_right = 320
	camera.limit_bottom = 180
	(game.view.world if "view" in game else game).add_child(camera)
	fixture("the seesaw room with a camera added, its top limit open")
	await hold(1.0)
	start_clip()
	strip(20, "jump onto the raised end, hold Shift, let go")
	mark("walk right")
	Events.hold_key(KEY_RIGHT, true)
	await hold(0.4)
	mark("jump")
	Events.hold_key(KEY_SPACE, true)
	await hold(0.6)
	Events.hold_key(KEY_SPACE, false)
	await hold(0.1)
	Events.hold_key(KEY_RIGHT, false)
	await hold(0.5)
	mark("hold Shift")
	Events.hold_key(KEY_SHIFT, true)
	await hold(1.5)
	mark("let go of Shift")
	Events.hold_key(KEY_SHIFT, false)
	await hold(2.0)
	finish()
