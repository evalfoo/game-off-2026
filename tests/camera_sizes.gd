extends "res://tests/lib/test.gd"

# The camera window, smoothing and look-ahead blend from their small values to
# their big ones as the player grows: checked small, partway and big. The big
# window and smoothing start equal to the small ones, so the test sets its own
# big values to tell them apart. Big, the view settles the big look-ahead less
# the big window's half width ahead of a player who walked right.

const HALF_VIEW_X := 160.0

var room: Node2D
var player: CharacterBody2D
var camera: Camera2D


func run() -> void:
	room = (load("res://game/rooms/wide.tscn") as PackedScene).instantiate()
	root.add_child(room)
	player = room.player
	camera = room.camera
	camera.big_window_margin = 0.1
	camera.big_smoothing_speed = 2.0
	await physics(1)

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
	room.free()


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
	check(absf(camera.position.x - player.position.x - ahead) < 0.01,
		"%s: at t %.2f the look-ahead point is %.1f px ahead: %.1f" % [label, t, ahead, camera.position.x - player.position.x])


func _check_between(property: String, setting: String) -> void:
	var value: float = camera.get(property)
	var a: float = camera.get("small_" + setting)
	var b: float = camera.get("big_" + setting)
	check(value > minf(a, b) and value < maxf(a, b),
		"partway: %s %.3f sits between small %.3f and big %.3f" % [property, value, a, b])


func _check_between_ahead() -> void:
	var ahead: float = camera.position.x - player.position.x
	check(ahead > camera.big_look_ahead and ahead < camera.small_look_ahead,
		"partway: the look-ahead point %.1f px ahead sits between big %.1f and small %.1f" % [ahead, camera.big_look_ahead, camera.small_look_ahead])


func physics(count: int) -> void:
	for i: int in count:
		await physics_frame
