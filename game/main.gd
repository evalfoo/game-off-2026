extends Node2D

# A grey-box: holding Shift makes the player bigger, heavier and slower. Two
# boxes of different mass show the weight. Tests, clips and shots launch this
# scene through tests/lib/fixture.gd.

const Player := preload("res://game/player.gd")
const Tiles := preload("res://game/tiles.gd")
const Box := preload("res://game/box.gd")

# The floor's top edge, at tile row 10 of the 320x180 view. The player starts
# standing on it.
const FLOOR_Y := 160.0
# Labels at the 320x180 view's scale.
const FONT_SIZE := 8

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
	add_child(Tiles.room(FLOOR_Y))

	_add_box("BoxA", "BOX A", Vector2(168, FLOOR_Y - 8), preload("res://art/box_a.png"), 2.0)
	_add_box("BoxB", "BOX B", Vector2(240, FLOOR_Y - 16), preload("res://art/box_b.png"), 8.0)

	player = Player.new()
	player.name = "Player"
	player.position = Vector2(56, FLOOR_Y)
	add_child(player)

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


# A box the size of its sprite.
func _add_box(node_name: String, label_text: String, pos: Vector2, texture: Texture2D, box_mass: float) -> void:
	var size := texture.get_size()
	var body := Box.new()
	body.name = node_name
	body.position = pos
	body.mass = box_mass
	body.add_child(_rect_shape(size))
	var sprite := Sprite2D.new()
	sprite.texture = texture
	body.add_child(sprite)
	var label := Label.new()
	label.text = "%s\nmass %d" % [label_text, box_mass]
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.position = Vector2(-size.x / 2, -size.y / 2 - 28)
	body.add_child(label)
	add_child(body)


func _rect_shape(size: Vector2) -> CollisionShape2D:
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	return col
