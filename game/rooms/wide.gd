extends Node2D

# A grey-box room three views wide and taller than one, for the camera
# (game/camera.gd) to scroll along. A one-tile step, which both sizes can jump
# onto, changes the height the player stands at. Open it with
# res://game/rooms/wide.tscn; the game still starts in game/main.tscn.

const Player := preload("res://game/player.gd")
const Tiles := preload("res://game/tiles.gd")
const PlayerCamera := preload("res://game/camera.gd")

const COLUMNS := 60
const ROWS := 18
const SIZE := Vector2(COLUMNS * Tiles.TILE, ROWS * Tiles.TILE)
# The floor's top edge, two tile rows above the room's bottom.
const FLOOR_Y := SIZE.y - 2 * Tiles.TILE
# The step: a platform one tile above the floor.
const STEP_ROW := ROWS - 3
const STEP_FIRST := 24
const STEP_LAST := 31
const FONT_SIZE := 8

var player: Player
var camera: PlayerCamera
var readout := Label.new()


func _ready() -> void:
	var tiles := Tiles.room(FLOOR_Y, COLUMNS, ROWS)
	Tiles.platform(tiles, STEP_ROW, STEP_FIRST, STEP_LAST)
	add_child(tiles)

	player = Player.new()
	player.name = "Player"
	player.position = Vector2(120, FLOOR_Y)
	add_child(player)

	camera = PlayerCamera.new()
	camera.name = "Camera"
	camera.target = player
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(SIZE.x)
	camera.limit_bottom = int(SIZE.y)
	add_child(camera)

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
	var size := player.shape.size
	readout.text = "Arrows: move   Space: jump   Shift: hold\nsize: %d x %d\nmass: %.1f\nspeed: %d" % [
		size.x, size.y, player.mass, player.speed]
