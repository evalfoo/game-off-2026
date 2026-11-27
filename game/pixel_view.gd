extends Node2D

# Renders a room's world at 320x180 game pixels into its own image, with one
# pixel to spare on each side, and draws that image at the window's scale,
# shifted by the camera's leftover fraction of a game pixel. The world moves in
# whole game pixels, so its art stays on the pixel grid, while the picture moves
# in screen pixels: a quarter of a game pixel at 1280x720. So the slow end of
# the camera's ease doesn't step a whole game pixel at a time.
#
# The window stretches its canvas to the screen (stretch/mode="canvas_items"),
# so the image can sit between game pixels. A room adds its world, with its
# camera, to `world`. What the room adds to itself after this node, such as its
# readout, draws above the image and holds still while the camera moves.

const VIEW := Vector2i(320, 180)

var world := SubViewport.new()
# Where the image's top-left corner sits, in game pixels: up to one pixel up
# and left of the window's, at whole screen pixels.
var _corner := -Vector2.ONE


func _ready() -> void:
	world.name = "World"
	world.size = VIEW + Vector2i(2, 2)
	# The camera sees the 320x180 view, as it would with the window's size.
	world.size_2d_override = VIEW
	# Unlike the window, a SubViewport doesn't take these from the project.
	world.snap_2d_transforms_to_pixel = true
	world.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(world)


# The camera sets the world's offset in its physics step, before this.
func _process(_delta: float) -> void:
	var offset := world.canvas_transform.origin
	var rest := offset - offset.floor()
	# The world renders at the whole pixels of the offset, one pixel in from
	# the image's top-left corner, and the image moves by the rest. That goes
	# in the draw call: the window snaps a node's position to whole game
	# pixels.
	world.global_canvas_transform = Transform2D(0.0, Vector2.ONE - rest)
	var scale := get_viewport_transform().get_scale()
	_corner = ((rest - Vector2.ONE) * scale).round() / scale
	queue_redraw()


func _draw() -> void:
	draw_texture(world.get_texture(), _corner)
