extends "res://tests/lib/test.gd"

# The camera's height in a fall and on the seesaw plank. Staged: neither room
# has a camera on a plank or a drop taller than one tile, so this test adds a
# high ledge to the wide room and a camera to the seesaw room.
#
# A fall: at both sizes, the player walks off a ledge 112 px above the wide
# room's floor, and off one 640 px above it with the camera's top limit open.
# Every physics frame of the fall, the landing's included, the whole player
# stays inside the view and the feet no lower than the camera window's bottom
# edge, and after landing the view settles on the floor's height. The 640 px
# fall runs once more with the window's bottom edge at a fractional 79.6 px.
#
# A start in the air: the room's camera is swapped for one added while the
# player is in the air near the room's top. Falling to the floor keeps the
# feet on or above the window's bottom edge, also with smoothing off
# (smoothing_speed 0).
#
# The plank: in the seesaw room, the player stands on the plank's raised end,
# grows to push it down and shrinks to let it rise again. The feet move with
# the plank while the view's height holds.

const PlayerCamera := preload("res://game/camera.gd")
const Tiles := preload("res://game/tiles.gd")
const HALF_VIEW := Vector2(160, 90)
# The ledges: platforms in row 9, their top 112 px above the floor, and in row
# -24, 640 px above it.
const LEDGE_ROW := 9
const HIGH_LEDGE_ROW := -24
const LEDGE_FIRST := 40
const LEDGE_LAST := 45

var camera: Camera2D


func run() -> void:
	await _check_fall(false, LEDGE_ROW)
	await _check_fall(true, LEDGE_ROW)
	await _check_fall(false, HIGH_LEDGE_ROW)
	await _check_fall(true, HIGH_LEDGE_ROW)
	await _check_fall(false, HIGH_LEDGE_ROW, 79.6)
	await _check_start_in_air(5.0)
	await _check_start_in_air(0.0)
	await _check_plank()


func _check_fall(big: bool, ledge_row: int, bottom_edge := 80.0) -> void:
	var room: Node2D = (load("res://game/rooms/wide.tscn") as PackedScene).instantiate()
	root.add_child(room)
	Tiles.platform(room.get_node("Tiles"), ledge_row, LEDGE_FIRST, LEDGE_LAST)
	var player: CharacterBody2D = room.player
	camera = room.camera
	var floor_y: float = room.FLOOR_Y
	var ledge_y := float(ledge_row * Tiles.TILE)
	var label := "%s, %d px drop, window bottom %.1f" % ["big" if big else "small", floor_y - ledge_y, bottom_edge]
	camera.set("window_bottom", bottom_edge)
	# Above the room: the top limit opens so the view can show the ledge.
	if ledge_y < 0.0:
		camera.limit_top = -10000000
	player.position = Vector2((LEDGE_FIRST + 3) * Tiles.TILE, ledge_y)
	if big:
		Events.hold_key(KEY_SHIFT, true)
	await physics(180)
	check(player.is_on_floor() and absf(player.position.y - ledge_y) < 0.5,
		"%s: staged standing on the ledge at y %.1f" % [label, player.position.y])

	# Walk right off the ledge's end and keep walking until landing.
	var off_screen := 0
	var lowest := -INF
	var left := false
	Events.hold_key(KEY_RIGHT, true)
	for i: int in 600:
		await physics(1)
		var feet := player.position.y - _centre().y
		var height: float = player.shape.size.y
		var head := feet - height
		lowest = maxf(lowest, feet)
		if feet > HALF_VIEW.y or head < -HALF_VIEW.y:
			off_screen += 1
		if not player.is_on_floor():
			left = true
		elif left:
			break
	Events.hold_key(KEY_RIGHT, false)
	check(absf(player.position.y - floor_y) < 0.5,
		"%s: the fall drops %.1f px to the floor" % [label, player.position.y - ledge_y])
	check(off_screen == 0,
		"%s: the player stays on screen through the fall: %d frames partly off screen, feet at most %.1f px below the view's centre" % [label, off_screen, lowest])
	# Missing on a camera without the rule; the check then fails, not errors.
	var bottom: Variant = camera.get("window_bottom")
	check(bottom != null and lowest <= float(bottom) + 0.5,
		"%s: falling, the feet drop no lower than the window's bottom edge, %s px below the view's centre" % [label, bottom])
	await physics(120)
	var feet_below: float = camera.feet_below_centre
	check(absf(_centre().y - (floor_y - feet_below)) < 0.5,
		"%s: after landing the view settles %d px above the feet: %.1f" % [label, feet_below, _centre().y])
	Events.hold_key(KEY_SHIFT, false)
	room.free()
	await physics_frame
	await physics_frame


func _check_start_in_air(smoothing: float) -> void:
	var room: Node2D = (load("res://game/rooms/wide.tscn") as PackedScene).instantiate()
	root.add_child(room)
	var player: CharacterBody2D = room.player
	var size: Vector2 = room.SIZE
	room.camera.free()
	player.position = Vector2(120, 64)
	camera = PlayerCamera.new()
	camera.target = player
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(size.x)
	camera.limit_bottom = int(size.y)
	camera.small_smoothing_speed = smoothing
	camera.big_smoothing_speed = smoothing
	room.add_child(camera)
	var lowest := -INF
	for i: int in 300:
		await physics(1)
		lowest = maxf(lowest, player.position.y - _centre().y)
		if player.is_on_floor():
			break
	var bottom: Variant = camera.get("window_bottom")
	check(player.is_on_floor() and bottom != null and lowest <= float(bottom) + 0.5,
		"smoothing speed %.0f: starting in the air at y 64, the feet fall no lower than the window's bottom edge, %s px below the view's centre: at most %.1f" % [smoothing, bottom, lowest])
	room.free()
	await physics_frame
	await physics_frame


func _check_plank() -> void:
	var room: Node2D = (load("res://game/rooms/seesaw.tscn") as PackedScene).instantiate()
	root.add_child(room)
	var player: CharacterBody2D = room.player
	var plank: AnimatableBody2D = room.plank
	# The room is one view, so its top stays open: with every limit the view
	# could not move at all, whatever the rule.
	camera = PlayerCamera.new()
	camera.target = player
	camera.limit_left = 0
	camera.limit_right = 320
	camera.limit_bottom = 180
	room.add_child(camera)
	await physics(60)
	var floor_view_y := _centre().y

	# Staged on the raised left end, as in tests/seesaw.gd.
	player.global_position = plank.to_global(Vector2(-room.PLANK_SIZE.x / 2 + 16, -room.PLANK_SIZE.y - 1))
	await physics(30)
	var raised_y := player.position.y
	var feet := [player.position.y, player.position.y]
	var view := [_centre().y, _centre().y]
	Events.hold_key(KEY_SHIFT, true)
	for i: int in 120:
		await physics(1)
		_track(feet, view, player)
	check(plank.rotation < -0.1 and player.position.y - raised_y > 20.0,
		"growing pushes the plank down %.1f px with the player on it" % (player.position.y - raised_y))
	var lowered_y := player.position.y
	Events.hold_key(KEY_SHIFT, false)
	for i: int in 120:
		await physics(1)
		_track(feet, view, player)
	check(plank.rotation > 0.1 and lowered_y - player.position.y > 20.0,
		"shrinking lets the plank lift the player %.1f px" % (lowered_y - player.position.y))
	check(view[1] - view[0] < 0.5 and absf(view[0] - floor_view_y) < 0.5,
		"on the tilting plank the feet move %.1f px and the view's height %.1f px, from %.1f on the floor" % [feet[1] - feet[0], view[1] - view[0], floor_view_y])
	room.free()
	await physics_frame


# Widens [lowest, highest] ranges of the feet's and the view's heights.
func _track(feet: Array, view: Array, player: CharacterBody2D) -> void:
	feet[0] = minf(feet[0], player.position.y)
	feet[1] = maxf(feet[1], player.position.y)
	view[0] = minf(view[0], _centre().y)
	view[1] = maxf(view[1], _centre().y)


func _centre() -> Vector2:
	return camera.get_screen_center_position()


func physics(count: int) -> void:
	for i: int in count:
		await physics_frame
