extends Node2D

# A grey-box level for fitting through things: a floor and a wall with a
# 1-tile-tall tunnel at floor level. Only the small player fits through it; the
# big one is blocked, and holding Shift in it keeps the player small until big
# fits. Open it with res://game/levels/tunnel.tscn; the game still starts in
# the main level, game/main.tscn.
#
# Made in the editor, as the wide level: the tiles on Tiles and the player's
# start, PlayerStart. The pixel view makes its world in code, so they sit under
# the level's root, where the editor shows them, and this script moves them
# into the world at startup.

const Player := preload("res://game/player.gd")
const PixelView := preload("res://game/pixel_view.gd")

# These describe the painted scene for the tests; keep them in step with it.
# The floor's top edge.
const FLOOR_Y := 112.0
# The wall's first and last columns. The tunnel runs under it, in the row
# above the floor.
const WALL_FIRST := 9
const WALL_LAST := 12
const FONT_SIZE := 8

var player: Player
var view := PixelView.new()
var readout := Label.new()


func _ready() -> void:
	var start := ($PlayerStart as Marker2D).position
	view.name = "View"
	add_child(view)
	# The level, with whatever else is placed in the scene.
	for child: Node in get_children():
		if child != view:
			child.reparent(view.world, false)

	player = Player.new()
	player.name = "Player"
	player.position = start
	view.world.add_child(player)

	readout.name = "Readout"
	readout.position = Vector2(4, 2)
	readout.add_theme_font_size_override("font_size", FONT_SIZE)
	add_child(readout)
	_refresh_readout()


func _process(_delta: float) -> void:
	_refresh_readout()


func _refresh_readout() -> void:
	var size := player.size
	readout.text = "Arrows: move   Space: jump   Shift: hold\nsize: %d x %d\nmass: %.1f\nspeed: %d" % [
		size.x, size.y, player.mass, player.speed]
