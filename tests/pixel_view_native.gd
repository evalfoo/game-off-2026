extends "res://tests/lib/test.gd"

# In a native window, game/pixel_view.gd moves the picture by the camera's
# fraction of a game pixel in whole screen pixels, while the world's art keeps
# whole game pixels, and its spare pixel on each side fills the window's edges.
# A white 8 px square sits on a backdrop wider and taller than the view, and a
# plain Camera2D is staged at quarter-pixel steps.

const PixelView := preload("res://game/pixel_view.gd")
const SQUARE := Rect2(100, 50, 8, 8)
const BACKDROP := Color(0.0, 0.0, 1.0)

var camera := Camera2D.new()


func run() -> void:
	var view := PixelView.new()
	root.add_child(view)
	var backdrop := ColorRect.new()
	backdrop.position = Vector2(-20, -20)
	backdrop.size = Vector2(360, 220)
	backdrop.color = BACKDROP
	view.world.add_child(backdrop)
	var square := ColorRect.new()
	square.position = SQUARE.position
	square.size = SQUARE.size
	view.world.add_child(square)
	camera.position = Vector2(160, 90)
	view.world.add_child(camera)
	await frames(3)

	var image := await _capture()
	var scale := image.get_width() / 320
	check(image.get_size() == Vector2i(1280, 720) and scale == 4,
		"the window's picture is %s, %d screen pixels a game pixel" % [image.get_size(), scale])
	var row := int(SQUARE.position.y + 4) * scale
	var column := int(SQUARE.position.x + 4) * scale
	for step: int in 5:
		var x := 0.25 * step
		camera.position = Vector2(160 + x, 90 - x)
		image = await _capture()
		var left := _first_white(image, row, true)
		var top := _first_white(image, column, false)
		var width := _first_not_white(image, row, left) - left
		check(left == int(SQUARE.position.x) * scale - step and top == int(SQUARE.position.y) * scale + step,
			"the camera %.2f px right and up moves the square %d screen px left and down: left %d, top %d" % [x, step, left, top])
		check(width == int(SQUARE.size.x) * scale, "the square stays %d game pixels wide: %d screen px" % [SQUARE.size.x, width])
		var corners := [Vector2i(0, 0), Vector2i(image.get_width() - 1, image.get_height() - 1)]
		var filled := corners.all(func(p: Vector2i) -> bool: return image.get_pixelv(p).is_equal_approx(BACKDROP))
		check(filled, "the window's corners show the world: %s, %s" % [image.get_pixelv(corners[0]), image.get_pixelv(corners[1])])


func _capture() -> Image:
	camera.force_update_scroll()
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


# The first white pixel along row `at` (or column, when `across` is false).
func _first_white(image: Image, at: int, across: bool) -> int:
	var length := image.get_width() if across else image.get_height()
	for i: int in length:
		var p := Vector2i(i, at) if across else Vector2i(at, i)
		if image.get_pixelv(p).is_equal_approx(Color.WHITE):
			return i
	return -1


func _first_not_white(image: Image, row: int, from: int) -> int:
	for i: int in range(from, image.get_width()):
		if not image.get_pixel(i, row).is_equal_approx(Color.WHITE):
			return i
	return image.get_width()
