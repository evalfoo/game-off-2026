extends Node2D

# A grey-box room for the seesaw: the small player can't push the plank down
# against the WEIGHT fixed to the other end, the big one can. Open it with
# res://game/rooms/seesaw.tscn; the game still starts in game/main.tscn.

const Player := preload("res://game/player.gd")
const Plank := preload("res://game/seesaw_plank.gd")

# The floor's top edge. The player starts standing on it.
const FLOOR_Y := 840.0
# Where the plank turns, and its size. The plank's ends rest on the floor.
const PIVOT := Vector2(720, FLOOR_Y - 48)
const PLANK_SIZE := Vector2(480, 16)
const WEIGHT_SIZE := Vector2(64, 64)
const WEIGHT_MASS := 4.0
# The weight's centre, along the plank from the pivot.
const WEIGHT_X := 190.0

var player: Player
var plank: Plank
var readout := Label.new()


func _ready() -> void:
	_add_static("Floor", Vector2(720, FLOOR_Y + 30), Vector2(2880, 60))
	_add_static("WallLeft", Vector2(-10, 450), Vector2(20, 900))
	_add_static("WallRight", Vector2(get_viewport_rect().size.x + 10, 450), Vector2(20, 900))

	var pivot := StaticBody2D.new()
	pivot.name = "Pivot"
	pivot.position = PIVOT
	var triangle := Polygon2D.new()
	triangle.polygon = PackedVector2Array([Vector2(0, 0), Vector2(28, FLOOR_Y - PIVOT.y), Vector2(-28, FLOOR_Y - PIVOT.y)])
	triangle.color = Color(0.4, 0.4, 0.4)
	pivot.add_child(triangle)
	var pivot_shape := CollisionPolygon2D.new()
	pivot_shape.polygon = triangle.polygon
	pivot.add_child(pivot_shape)
	add_child(pivot)

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
	plank_label.position = Vector2(-30, 4)
	plank.add_child(plank_label)
	var weight_at := Vector2(WEIGHT_X, -PLANK_SIZE.y - WEIGHT_SIZE.y / 2)
	plank.add_child(_rect_shape(WEIGHT_SIZE, weight_at))
	plank.add_child(_rect_visual(WEIGHT_SIZE, Color(0.6, 0.6, 0.6), weight_at))
	var weight_label := Label.new()
	weight_label.text = "WEIGHT\nmass %d" % WEIGHT_MASS
	weight_label.position = weight_at - WEIGHT_SIZE / 2 - Vector2(0, 52)
	plank.add_child(weight_label)
	add_child(plank)

	player = Player.new()
	player.name = "Player"
	player.position = Vector2(250, FLOOR_Y)
	add_child(player)

	readout.name = "Readout"
	readout.position = Vector2(16, 16)
	add_child(readout)
	_refresh_readout()


func _process(_delta: float) -> void:
	_refresh_readout()


func _refresh_readout() -> void:
	var size := player.shape.size
	readout.text = "Arrows: move   Space: jump   Shift: hold\nsize: %d x %d\nmass: %.1f\nspeed: %d" % [
		size.x, size.y, player.mass, player.speed]


func _add_static(node_name: String, pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = node_name
	body.position = pos
	body.add_child(_rect_shape(size))
	body.add_child(_rect_visual(size, Color(0.4, 0.4, 0.4)))
	add_child(body)


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
