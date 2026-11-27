extends Node2D

# A grey-box room for the linked platforms (game/platform_pair.tscn): each sits
# level with the floor over a pit, so the player walks onto it at either size.
# The big player sinks one into its pit while the other rises out of its own.
# Open it with res://game/rooms/platforms.tscn; the game still starts in
# game/main.tscn.
#
# Made in the editor, as the wide room: the tiles on Tiles, the pair and the
# player's start, PlayerStart. The pixel view makes its world in code, so they
# sit under the room's root, where the editor shows them, and this script
# moves them into the world at startup.

const Player := preload("res://game/player.gd")
const PlatformPair := preload("res://game/platform_pair.gd")
const PixelView := preload("res://game/pixel_view.gd")

# These describe the painted scene for the tests; keep them in step with it.
# The floor's top edge.
const FLOOR_Y := 112.0
const FONT_SIZE := 8

var player: Player
var pair: PlatformPair
var view := PixelView.new()
var readout := Label.new()


func _ready() -> void:
	var start := ($PlayerStart as Marker2D).position
	pair = $PlatformPair
	view.name = "View"
	add_child(view)
	# The level, with whatever else is placed in the scene.
	for child: Node in get_children():
		if child != view:
			child.reparent(view.world, false)

	# After the pair, so each step the pair moves before the player.
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
	var size := player.shape.size
	readout.text = "Arrows: move   Space: jump   Shift: hold\nsize: %d x %d\nmass: %.1f\nspeed: %d" % [
		size.x, size.y, player.mass, player.speed]
