extends "res://tests/lib/test.gd"

# The camera window, smoothing and look-ahead blend from their small values to
# their big ones as the player grows: checked small, partway and big. The test
# sets its own small and big values, all different, so the game's tuning can't
# hide a blend. Big, the view settles the big look-ahead less the big window's
# half width ahead of a player who walked right. After growing and shrinking
# back, walking eases as it does in a fresh room: Camera2D's own physics update,
# which setting the smoothing speed turns back on, stays off.

const HALF_VIEW_X := 160.0

var room: Node2D
var player: CharacterBody2D
var camera: Camera2D


func run() -> void:
	# A fresh small walk, to compare with one after growing and shrinking.
	await _open_room()
	var fresh_lag := await _walk_lag()
	_close_room()

	await _open_room()
	_check_blend("small")
	Events.hold_key(KEY_SHIFT, true)
	await physics(12)
	var t: float = player.t
	check(t > 0.0 and t < 1.0, "partway: holding Shift 12 frames leaves the player partway grown: t %.2f" % t)
	_check_blend("partway")
	_check_between("drag_left_margin", "window_margin")
	_check_between("position_smoothing_speed", "smoothing_speed")
	_check_between_ahead()
	await physics(30)
	_check_blend("big")

	# Walk right past the window's edge, then stand until the view settles.
	Events.hold_key(KEY_RIGHT, true)
	await physics(240)
	Events.hold_key(KEY_RIGHT, false)
	await physics(300)
	var lead := camera.get_screen_center_position().x - player.position.x
	var expected: float = camera.big_look_ahead - camera.big_window_margin * HALF_VIEW_X
	check(absf(lead - expected) < 0.5,
		"big: after walking right the view settles %.1f px ahead of the player, expected %.1f" % [lead, expected])
	Events.hold_key(KEY_SHIFT, false)
	_close_room()

	# Grow and shrink back, then walk as in the fresh room.
	await _open_room()
	Events.hold_key(KEY_SHIFT, true)
	await physics(40)
	Events.hold_key(KEY_SHIFT, false)
	await physics(40)
	_check_blend("shrunk back")
	var lag := await _walk_lag()
	check(absf(lag - fresh_lag) < 0.5,
		"shrunk back: walking right, the view trails the window's edge by %.1f px, as in a fresh room: %.1f px" % [lag, fresh_lag])
	_close_room()


func _open_room() -> void:
	room = (load("res://game/rooms/wide.tscn") as PackedScene).instantiate()
	root.add_child(room)
	player = room.player
	camera = room.camera
	camera.small_window_margin = 0.2
	camera.big_window_margin = 0.1
	camera.small_smoothing_speed = 5.0
	camera.big_smoothing_speed = 2.0
	camera.small_look_ahead = 80.0
	camera.big_look_ahead = 48.0
	await physics(1)


func _close_room() -> void:
	room.free()


# Walks right for 2 seconds and returns how far the view's centre trails the
# window's right edge on the look-ahead point.
func _walk_lag() -> float:
	Events.hold_key(KEY_RIGHT, true)
	await physics(120)
	Events.hold_key(KEY_RIGHT, false)
	# The script's window sits at its edge on the look-ahead point while walking.
	return camera.position.x - camera.get_screen_center_position().x


# Checks the window, smoothing and look-ahead point match the blend at the
# player's t.
func _check_blend(label: String) -> void:
	var t: float = player.t
	var margin := lerpf(camera.small_window_margin, camera.big_window_margin, t)
	var smoothing := lerpf(camera.small_smoothing_speed, camera.big_smoothing_speed, t)
	var ahead := lerpf(camera.small_look_ahead, camera.big_look_ahead, t)
	check(is_equal_approx(camera.drag_left_margin, margin) and is_equal_approx(camera.drag_right_margin, margin),
		"%s: at t %.2f the window margin is %.3f: %.3f, %.3f" % [label, t, margin, camera.drag_left_margin, camera.drag_right_margin])
	check(is_equal_approx(camera.position_smoothing_speed, smoothing),
		"%s: at t %.2f the smoothing speed is %.2f: %.2f" % [label, t, smoothing, camera.position_smoothing_speed])
	check(absf(_ahead() - ahead) < 0.01,
		"%s: at t %.2f the look-ahead point is %.1f px ahead: %.1f" % [label, t, ahead, _ahead()])
	check(not camera.is_physics_processing_internal(),
		"%s: Camera2D's own physics update stays off" % label)


func _check_between(property: String, setting: String) -> void:
	var value: float = camera.get(property)
	var a: float = camera.get("small_" + setting)
	var b: float = camera.get("big_" + setting)
	check(value > minf(a, b) and value < maxf(a, b),
		"partway: %s %.3f sits between small %.3f and big %.3f" % [property, value, a, b])


func _check_between_ahead() -> void:
	var ahead := _ahead()
	check(ahead > camera.big_look_ahead and ahead < camera.small_look_ahead,
		"partway: the look-ahead point %.1f px ahead sits between big %.1f and small %.1f" % [ahead, camera.big_look_ahead, camera.small_look_ahead])


# How far ahead of the player the look-ahead point is. The view's position is
# the window's centre, which can sit up to half the window behind the point.
func _ahead() -> float:
	return camera.call("_look_ahead_x") - player.position.x


func physics(count: int) -> void:
	for i: int in count:
		await physics_frame
