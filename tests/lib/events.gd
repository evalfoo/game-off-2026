extends RefCounted

# Real input events for native tests, clips and shots. They go through
# Input.parse_input_event(), so they reach the game like a player's. A click
# sends press and release in the same frame, so a moving real mouse can't split it.
# hold_key and joy_button send one press or release, so input can stay down
# while time runs; the caller releases it.

static func click(position: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	move_mouse(position)
	for pressed: bool in [true, false]:
		mouse_button(position, button, pressed)

static func mouse_button(position: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = position
	event.global_position = position
	event.pressed = pressed
	if pressed:
		event.button_mask = 1 << (button - 1)
	Input.parse_input_event(event)

# `buttons` is the mask of mouse buttons down, such as MOUSE_BUTTON_MASK_LEFT
# during a drag; a control only sees a drag when its motion carries it.
static func move_mouse(position: Vector2, relative := Vector2.ZERO, buttons := 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = relative
	event.screen_relative = relative
	event.button_mask = buttons
	Input.parse_input_event(event)

static func key(code: Key) -> void:
	for pressed: bool in [true, false]:
		hold_key(code, pressed)

static func hold_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

static func joy_axis(device: int, axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)

static func joy_button(device: int, button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)

# Relative motion only, as a mouse-look camera reads it.
static func mouse_motion(relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	event.screen_relative = relative
	Input.parse_input_event(event)
