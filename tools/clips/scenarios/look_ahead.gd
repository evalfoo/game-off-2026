extends "res://tools/clips/scenario.gd"

# The camera's look-ahead in the wide room: the player walks right, turns back
# a little and walks on, then turns back further and walks left. Pass -- --big
# to hold Shift throughout. The wide room is on both refs, so record both:
#
#   tools/clips/record.sh tools/clips/scenarios/look_ahead.gd [-- --big]

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
	# The big player walks a third as fast, so it holds each key longer.
	var scale := 2.5 if big else 1.0
	strip(roundi((1.6 + 0.2 + 0.6 + 0.8 + 0.6 + 1.2 + 1.5) * scale * FPS / 8.0),
		"walk right, a short turn back, walk on, a long turn back")
	await _walk(KEY_RIGHT, 1.6 * scale, "walk right")
	await _walk(KEY_LEFT, 0.2 * scale, "short turn left")
	await hold(0.6 * scale)
	await _walk(KEY_RIGHT, 0.8 * scale, "walk right again")
	await hold(0.6 * scale)
	await _walk(KEY_LEFT, 1.2 * scale, "long turn left")
	await hold(1.5 * scale)
	Events.hold_key(KEY_SHIFT, false)
	finish()


func _walk(key: Key, seconds: float, event: String) -> void:
	mark(event)
	Events.hold_key(key, true)
	await hold(seconds)
	Events.hold_key(key, false)
