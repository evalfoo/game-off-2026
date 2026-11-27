extends "res://tools/clips/scenario.gd"

# A long fall in the wide room: the player stands on a ledge 112 px above the
# floor, walks right off its end and falls to the floor. The wide room has no
# ledge that high, so this adds one, the same on both refs. Pass -- --big to
# hold Shift throughout.
#
#   tools/clips/record.sh tools/clips/scenarios/fall.gd [-- --big]

const Tiles := preload("res://game/tiles.gd")
# A platform in row 9, its top 112 px above the floor.
const LEDGE_ROW := 9
const LEDGE_FIRST := 40
const LEDGE_LAST := 45


func run() -> void:
	var big := "--big" in OS.get_cmdline_user_args()
	game.free()
	game = (load("res://game/rooms/wide.tscn") as PackedScene).instantiate()
	root.add_child(game)
	Tiles.platform(game.get_node("Tiles"), LEDGE_ROW, LEDGE_FIRST, LEDGE_LAST)
	game.player.position = Vector2((LEDGE_FIRST + 4) * Tiles.TILE, LEDGE_ROW * Tiles.TILE)
	fixture("the wide room with a ledge added at y %d, %s player" % [LEDGE_ROW * Tiles.TILE, "big" if big else "small"])
	if big:
		Events.hold_key(KEY_SHIFT, true)
	await hold(3.0)
	start_clip()
	await hold(0.3)
	# The big player walks a third as fast, so it takes longer to reach the end.
	var walk := 1.8 if big else 0.6
	strip(roundi((walk + 1.5) * FPS / 8.0), "walk off the ledge, fall, land")
	mark("walk right")
	Events.hold_key(KEY_RIGHT, true)
	await hold(walk)
	Events.hold_key(KEY_RIGHT, false)
	await hold(1.5)
	Events.hold_key(KEY_SHIFT, false)
	finish()
