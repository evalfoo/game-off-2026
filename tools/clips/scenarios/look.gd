extends "res://tools/clips/scenario.gd"

# Looking up and down in the wide level: the player stands, holds Up, lets go,
# holds Down, lets go. The floor sits near the level's bottom, so the look down
# stops at the level's edge. The wide level is on both refs, so record both:
#
#   tools/clips/record.sh tools/clips/scenarios/look.gd

func run() -> void:
	game.free()
	game = (load("res://game/levels/wide.tscn") as PackedScene).instantiate()
	root.add_child(game)
	fixture("the wide level, small player standing")
	start_clip()
	await hold(0.5)
	strip(roundi(5.5 * FPS / 8.0), "hold Up, let go, hold Down, let go")
	await _look(KEY_UP, "hold Up")
	await _look(KEY_DOWN, "hold Down")
	finish()


func _look(key: Key, event: String) -> void:
	mark(event)
	Events.hold_key(key, true)
	await hold(1.5)
	Events.hold_key(key, false)
	mark("let go")
	await hold(1.2)
