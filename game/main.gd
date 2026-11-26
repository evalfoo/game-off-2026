extends Node2D

# A grey-box: holding Shift makes the player bigger, heavier and slower. Two
# boxes of different mass show the weight. Tests, clips and shots launch this
# scene through tests/lib/fixture.gd.

const Player := preload("res://game/player.gd")

# The floor's top edge. The player starts standing on it.
const FLOOR_Y := 840.0

# The folder every save goes under. tests/lib/fixture.gd sets it before
# _ready() for tests, clips, stills and agent play sessions, so they never touch
# the player's saves. The game saves nothing yet.
var save_directory := "user://"

# The seed of the game's randomness. tests/lib/fixture.gd sets it before
# _ready(). The game has no randomness yet.
var rng_seed := randi()

var player: Player
var readout := Label.new()


func _ready() -> void:
	# Wider than the 1440 px view, so a wider window still shows floor.
	_add_static("Floor", Vector2(720, FLOOR_Y + 30), Vector2(2880, 60))
	_add_static("WallLeft", Vector2(-10, 450), Vector2(20, 900))
	# At the visible edge: the stretch mode widens the 1440 px view on wider
	# windows, such as 1600 px at 16:9.
	_add_static("WallRight", Vector2(get_viewport_rect().size.x + 10, 450), Vector2(20, 900))

	_add_box("BoxA", "BOX A", Vector2(750, FLOOR_Y - 24), Vector2(48, 48), 2.0)
	_add_box("BoxB", "BOX B", Vector2(1050, FLOOR_Y - 40), Vector2(80, 80), 8.0)

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


func _add_box(node_name: String, label_text: String, pos: Vector2, size: Vector2, box_mass: float) -> void:
	var body := RigidBody2D.new()
	body.name = node_name
	body.position = pos
	body.mass = box_mass
	body.add_child(_rect_shape(size))
	body.add_child(_rect_visual(size, Color(0.6, 0.6, 0.6)))
	var label := Label.new()
	label.text = "%s\nmass %d" % [label_text, box_mass]
	label.position = Vector2(-size.x / 2, -size.y / 2 - 52)
	body.add_child(label)
	add_child(body)


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
