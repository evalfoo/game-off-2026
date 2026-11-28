extends Node2D

# A grey-box level three views wide and taller than one, for the camera
# (game/camera.gd) to scroll along. A one-tile step, which both sizes can jump
# onto, changes the height the player stands at. Open it with
# res://game/levels/wide.tscn; the game still starts in the main
# level, game/main.tscn.
#
# The scene holds the level: its tiles, painted on Tiles, and the player's
# start, PlayerStart. The pixel view makes its world in code, so they sit
# under the level's root, where the editor shows them, and this script moves the
# tiles into the world at startup. The camera's limits are the painted tiles'
# bounds less the wall column on each side.

const Player := preload("res://game/player.gd")
const Tiles := preload("res://game/tiles.gd")
const PlayerCamera := preload("res://game/camera.gd")
const PixelView := preload("res://game/pixel_view.gd")

# These describe the painted scene for the tests; keep them in step with it.
const COLUMNS := 60
const ROWS := 18
const SIZE := Vector2(COLUMNS * Tiles.TILE, ROWS * Tiles.TILE)
# The floor's top edge, two tile rows above the level's bottom.
const FLOOR_Y := SIZE.y - 2 * Tiles.TILE
# The step: a platform one tile above the floor, ending at column STEP_LAST.
const STEP_ROW := ROWS - 3
const STEP_LAST := 31
const FONT_SIZE := 8

var player: Player
var camera: PlayerCamera
var view := PixelView.new()
var readout := Label.new()


func _ready() -> void:
	view.name = "View"
	add_child(view)
	var tiles: TileMapLayer = $Tiles
	tiles.reparent(view.world, false)

	player = Player.new()
	player.name = "Player"
	player.position = ($PlayerStart as Marker2D).position
	view.world.add_child(player)

	camera = PlayerCamera.new()
	camera.name = "Camera"
	camera.target = player
	# The bounds in cells, then in the world, wherever the layer sits, also
	# when it's flipped.
	var cells := tiles.get_used_rect().grow_individual(-1, 0, -1, 0)
	var bounds := tiles.transform * Rect2(cells.position * Tiles.TILE, cells.size * Tiles.TILE)
	camera.limit_left = roundi(bounds.position.x)
	camera.limit_top = roundi(bounds.position.y)
	camera.limit_right = roundi(bounds.end.x)
	camera.limit_bottom = roundi(bounds.end.y)
	view.world.add_child(camera)

	# On its own canvas layer, so it stays put while the view scrolls.
	var hud := CanvasLayer.new()
	hud.name = "Hud"
	readout.name = "Readout"
	readout.position = Vector2(4, 2)
	readout.add_theme_font_size_override("font_size", FONT_SIZE)
	hud.add_child(readout)
	add_child(hud)
	_refresh_readout()


func _process(_delta: float) -> void:
	_refresh_readout()


func _refresh_readout() -> void:
	var size := player.size
	readout.text = "Arrows: move   Space: jump   Shift: hold\nsize: %d x %d\nmass: %.1f\nspeed: %d" % [
		size.x, size.y, player.mass, player.speed]
