extends "res://tools/clips/scenario.gd"

# The camera in the wide room: the player walks right, turns and walks back
# inside the camera window, jumps in place, then walks onto the step with a
# jump. Pass -- --big to hold Shift throughout. The room is new, so record one
# ref:
#
#   tools/clips/record.sh tools/clips/scenarios/camera.gd HEAD [-- --big]

func run() -> void:
	var big := "--big" in OS.get_cmdline_user_args()
	game.free()
	game = (load("res://game/rooms/wide.tscn") as PackedScene).instantiate()
	root.add_child(game)
	fixture("the wide room, %s player" % ("big" if big else "small"))
	if big:
		Events.hold_key(KEY_SHIFT, true)
		await hold(0.6)
	start_clip()
	await hold(0.3)
	var walk := 3.0 if big else 1.6
	# The big player walks a third as fast, so its clip runs about twice as long.
	var seconds := 15.0 if big else 8.0
	strip(roundi(seconds * FPS / 8.0), "walk right, turn, jump, walk onto the step")
	mark("walk right")
	Events.hold_key(KEY_RIGHT, true)
	await hold(walk)
	Events.hold_key(KEY_RIGHT, false)
	mark("turn left")
	Events.hold_key(KEY_LEFT, true)
	await hold(walk * 0.4)
	Events.hold_key(KEY_LEFT, false)
	await hold(0.5)
	mark("jump in place")
	Events.hold_key(KEY_SPACE, true)
	await hold(0.3)
	Events.hold_key(KEY_SPACE, false)
	await hold(0.6)
	mark("walk right into the step and jump onto it")
	Events.hold_key(KEY_RIGHT, true)
	var player: CharacterBody2D = game.get("player")
	while not player.is_on_wall():
		await hold(1.0 / FPS)
	Events.hold_key(KEY_SPACE, true)
	await hold(0.3)
	Events.hold_key(KEY_SPACE, false)
	await hold(0.8 if big else 0.5)
	Events.hold_key(KEY_RIGHT, false)
	await hold(1.5)
	Events.hold_key(KEY_SHIFT, false)
	finish()
