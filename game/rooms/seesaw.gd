extends Node2D

# A grey-box room for the seesaw: the small player can't push the plank down
# against the WEIGHT on the other end, the big one can. Open it with
# res://game/rooms/seesaw.tscn; the game still starts in game/main.tscn.

const Player := preload("res://game/player.gd")

# The floor's top edge. The player starts standing on it.
const FLOOR_Y := 840.0
# Where the plank turns, and its size. The plank's ends rest on the floor.
const PIVOT := Vector2(720, FLOOR_Y - 48)
const PLANK_SIZE := Vector2(480, 16)
const PLANK_MASS := 2.0
const WEIGHT_SIZE := Vector2(64, 64)
const WEIGHT_MASS := 4.0

var player: Player
var plank: RigidBody2D
var weight: RigidBody2D
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
	# The joint keeps the plank from colliding with it; the player can't pass.
	var pivot_shape := CollisionPolygon2D.new()
	pivot_shape.polygon = triangle.polygon
	pivot.add_child(pivot_shape)
	add_child(pivot)

	# Starts level; the weight tips its right end down onto the floor.
	plank = RigidBody2D.new()
	plank.name = "Plank"
	plank.position = PIVOT - Vector2(0, PLANK_SIZE.y / 2)
	plank.mass = PLANK_MASS
	plank.add_child(_rect_shape(PLANK_SIZE))
	plank.add_child(_rect_visual(PLANK_SIZE, Color(0.6, 0.6, 0.6)))
	var plank_label := Label.new()
	plank_label.text = "SEESAW"
	plank_label.position = Vector2(-30, 12)
	plank.add_child(plank_label)
	add_child(plank)

	var joint := PinJoint2D.new()
	joint.name = "Joint"
	joint.position = PIVOT
	add_child(joint)
	joint.node_a = joint.get_path_to(pivot)
	joint.node_b = joint.get_path_to(plank)

	weight = _add_box("Weight", "WEIGHT", Vector2(PIVOT.x + 190, plank.position.y - (PLANK_SIZE.y + WEIGHT_SIZE.y) / 2), WEIGHT_SIZE, WEIGHT_MASS)

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


# Same as game/main.gd: skip the zero-length physics steps of the play driver's
# pause, which turn touching rigid bodies into NaN (evalfoo/godot-template#44).
func _physics_process(delta: float) -> void:
	PhysicsServer2D.set_active(delta > 0.0)


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


func _add_box(node_name: String, label_text: String, pos: Vector2, size: Vector2, box_mass: float) -> RigidBody2D:
	var body := RigidBody2D.new()
	body.name = node_name
	body.position = pos
	body.mass = box_mass
	body.add_child(_rect_shape(size))
	body.add_child(_rect_visual(size, Color(0.6, 0.6, 0.6)))
	var label := Label.new()
	label.text = "%s\nmass %d" % [label_text, body.mass]
	label.position = Vector2(-size.x / 2, -size.y / 2 - 52)
	body.add_child(label)
	add_child(body)
	return body


func _rect_shape(size: Vector2) -> CollisionShape2D:
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	return col


func _rect_visual(size: Vector2, color: Color) -> ColorRect:
	var vis := ColorRect.new()
	vis.size = size
	vis.position = -size / 2
	vis.color = color
	vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return vis
