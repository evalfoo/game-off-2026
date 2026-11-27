extends Node2D

# A grey-box room for the seesaw: the small player can't push the plank down
# against the WEIGHT fixed to the other end, the big one can. Open it with
# res://game/rooms/seesaw.tscn; the game still starts in game/main.tscn.

const Player := preload("res://game/player.gd")
const Tiles := preload("res://game/tiles.gd")
const Plank := preload("res://game/seesaw_plank.gd")
const PixelView := preload("res://game/pixel_view.gd")

# The floor's top edge, as in game/main.gd. The player starts standing on it.
const FLOOR_Y := 160.0
# Where the plank turns, and its size. The plank's ends rest on the floor.
const PIVOT := Vector2(200, FLOOR_Y - 16)
const PLANK_SIZE := Vector2(160, 4)
const WEIGHT_SIZE := Vector2(20, 20)
const WEIGHT_MASS := 4.0
# The weight's centre, along the plank from the pivot.
const WEIGHT_X := 63.0
const FONT_SIZE := 8

var player: Player
var plank: Plank
var view := PixelView.new()
var readout := Label.new()


func _ready() -> void:
	view.name = "View"
	add_child(view)
	view.world.add_child(Tiles.room(FLOOR_Y))

	var pivot := StaticBody2D.new()
	pivot.name = "Pivot"
	pivot.position = PIVOT
	var triangle := Polygon2D.new()
	triangle.polygon = PackedVector2Array([Vector2(0, 0), Vector2(9, FLOOR_Y - PIVOT.y), Vector2(-9, FLOOR_Y - PIVOT.y)])
	triangle.color = Color(0.4, 0.4, 0.4)
	pivot.add_child(triangle)
	var pivot_shape := CollisionPolygon2D.new()
	pivot_shape.polygon = triangle.polygon
	pivot.add_child(pivot_shape)
	view.world.add_child(pivot)

	# Turns on the pivot's tip, between its ends resting on the floor on
	# either side. Starts level; the weight turns its right end down.
	plank = Plank.new()
	plank.name = "Plank"
	plank.position = PIVOT
	plank.max_angle = asin((FLOOR_Y - PIVOT.y) / (PLANK_SIZE.x / 2))
	plank.counterweight_mass = WEIGHT_MASS
	plank.counterweight_x = WEIGHT_X
	var board := Vector2(0, -PLANK_SIZE.y / 2)
	plank.add_child(_rect_shape(PLANK_SIZE, board))
	plank.add_child(_rect_visual(PLANK_SIZE, Color(0.6, 0.6, 0.6), board))
	var plank_label := Label.new()
	plank_label.text = "SEESAW"
	plank_label.add_theme_font_size_override("font_size", FONT_SIZE)
	plank_label.position = Vector2(-12, 2)
	plank.add_child(plank_label)
	var weight_at := Vector2(WEIGHT_X, -PLANK_SIZE.y - WEIGHT_SIZE.y / 2)
	plank.add_child(_rect_shape(WEIGHT_SIZE, weight_at))
	plank.add_child(_rect_visual(WEIGHT_SIZE, Color(0.6, 0.6, 0.6), weight_at))
	var weight_label := Label.new()
	weight_label.text = "WEIGHT\nmass %d" % WEIGHT_MASS
	weight_label.add_theme_font_size_override("font_size", FONT_SIZE)
	weight_label.position = weight_at - WEIGHT_SIZE / 2 - Vector2(0, 28)
	plank.add_child(weight_label)
	view.world.add_child(plank)

	player = Player.new()
	player.name = "Player"
	player.position = Vector2(43, FLOOR_Y)
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


func _rect_shape(size: Vector2, at := Vector2.ZERO) -> CollisionShape2D:
	var col := CollisionShape2D.new()
	col.position = at
	var rect := RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	return col


func _rect_visual(size: Vector2, color: Color, at := Vector2.ZERO) -> ColorRect:
	var vis := ColorRect.new()
	vis.size = size
	vis.position = at - size / 2
	vis.color = color
	vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return vis
