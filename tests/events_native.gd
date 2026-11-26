extends "res://tests/lib/test.gd"

# The input helpers in tests/lib/events.gd that no game action uses yet reach
# the scene tree with the fields they were given, and held input stays down
# until its release.

var seen: Array[InputEvent] = []

class Recorder extends Node:
	var events: Array[InputEvent]

	func _input(event: InputEvent) -> void:
		events.append(event)

func run() -> void:
	var recorder := Recorder.new()
	recorder.events = seen
	root.add_child(recorder)
	await frames(2)

	Events.hold_key(KEY_W, true)
	await frames(3)
	check(Input.is_key_pressed(KEY_W), "a held key stays down across frames")
	Events.hold_key(KEY_W, false)
	await frames(2)
	check(not Input.is_key_pressed(KEY_W), "its release lifts it")

	seen.clear()
	Events.joy_axis(0, JOY_AXIS_LEFT_X, 0.5)
	Events.joy_button(0, JOY_BUTTON_A, true)
	Events.mouse_motion(Vector2(12, -4))
	Events.mouse_button(Vector2(30, 40), MOUSE_BUTTON_RIGHT, true)
	Events.move_mouse(Vector2(50, 40), Vector2(20, 0), MOUSE_BUTTON_MASK_RIGHT)
	await frames(2)
	var axis := _first(InputEventJoypadMotion) as InputEventJoypadMotion
	check(axis != null and axis.axis == JOY_AXIS_LEFT_X and is_equal_approx(axis.axis_value, 0.5), "joy_axis sends the stick's value")
	var button := _first(InputEventJoypadButton) as InputEventJoypadButton
	check(button != null and button.button_index == JOY_BUTTON_A and button.pressed, "joy_button sends the button down")
	var motions := seen.filter(func(event: InputEvent) -> bool: return event is InputEventMouseMotion)
	check(motions.size() == 2 and (motions[0] as InputEventMouseMotion).relative == Vector2(12, -4), "mouse_motion sends relative motion")
	check(motions.size() == 2 and (motions[1] as InputEventMouseMotion).button_mask == MOUSE_BUTTON_MASK_RIGHT, "a move with buttons down carries their mask")
	Events.joy_button(0, JOY_BUTTON_A, false)
	Events.mouse_button(Vector2(50, 40), MOUSE_BUTTON_RIGHT, false)
	await frames(1)

func _first(type: Variant) -> InputEvent:
	for event in seen:
		if is_instance_of(event, type):
			return event
	return null
