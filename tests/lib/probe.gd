extends Button

# The game MCP self-test's scene, so the test passes whatever the game does.
# The whole window is one button, so a click lands whatever the window size.
# It clips its text, so a view narrower than the text doesn't widen it past
# the window's edges.
# A press shows the count in the button's tooltip, which the driver's hover
# reports for any scene. Reading current_scene in _ready() fails, as a SCRIPT
# ERROR on turn 1, when the driver sets it too late, as for a prototype.
#
# The text also shows the input that the driver's other actions send, once
# there is some: right clicks, the last drag with its motions that carried the
# left button, and for each key that stayed down while time ran, its game time
# down. Keys down now show as "down".
#
# It ends with the game time so far and a number drawn from rng_seed, which the
# driver sets, on every frame that game time ran. Two sessions with the same
# seed and actions show the same, and a different seed shows another.

var clicks := 0
var scene := ""
var right_clicks := 0
var drag := ""
var drag_from := Vector2.ZERO
var drag_moves := 0   # motions with the left button down since its press
var down: Array[Key] = []
var held := {}   # key name -> seconds of game time down
var rng_seed := 0
var rng := RandomNumberGenerator.new()
var time := 0.0
var roll := 0

func _ready() -> void:
	scene = get_tree().current_scene.name
	rng.seed = rng_seed
	roll = rng.randi_range(0, 999999)
	pressed.connect(_on_pressed)
	_refresh()

func _on_pressed() -> void:
	clicks += 1
	_refresh()

func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and not key.echo:
		if key.pressed and key.keycode not in down:
			down.append(key.keycode)
		elif not key.pressed:
			down.erase(key.keycode)
		_refresh()

func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
		right_clicks += 1
	elif button and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			drag_from = _window(button.position)
			drag_moves = 0
		elif drag_moves > 0:
			var to := _window(button.position)
			drag = "%d,%d to %d,%d in %d moves" % [drag_from.x, drag_from.y, to.x, to.y, drag_moves]
	var motion := event as InputEventMouseMotion
	if motion and motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
		drag_moves += 1
	_refresh()

# A point in this control's own pixels, in window pixels as the driver gives them.
func _window(point: Vector2) -> Vector2:
	return get_viewport_transform() * get_global_transform() * point

func _process(delta: float) -> void:
	# Frames with time stopped, which run however long the agent thinks, don't count.
	if delta > 0.0:
		time += delta
		roll = rng.randi_range(0, 999999)
		_refresh()
	for code in down:
		var name := OS.get_keycode_string(code)
		held[name] = float(held.get(name, 0.0)) + delta
	if not down.is_empty():
		_refresh()

func _refresh() -> void:
	text = "%s scene, clicks: %d" % [scene, clicks]
	if right_clicks > 0:
		text += ", right clicks: %d" % right_clicks
	if not drag.is_empty():
		text += ", dragged %s" % drag
	for name: String in held:
		text += ", %s held %.2f s" % [name, held[name]]
	if not down.is_empty():
		text += ", down: %s" % ", ".join(down.map(OS.get_keycode_string))
	text += ", time %.3f s, roll %d" % [time, roll]
	tooltip_text = "Clicks: %d" % clicks
