extends RefCounted

# The game's part of tools/play_driver.gd, which lets an agent play the game
# one turn at a time. The driver is generic and tools/update.sh replaces it
# with the template's; this file is the game's, and update.sh leaves it alone.
# The driver loads it when it plays the game, not a --scene, and plays without
# it when it's missing. Each part is optional.
#
# TODO(template): as the game grows, add its actions to ACTIONS and apply() (as
# a player would do them, through the game's own rules), what its HUD shows to
# screen() and the signals worth reporting to watch(). The driver's header,
# the actions and turn-001.json are the whole manual an agent gets. Build an
# action that holds input, such as a "drive" that holds a stick and a trigger,
# on driver._press() and driver._run_held(), with the helpers in
# tests/lib/events.gd (hold_key, joy_axis, joy_button, mouse_motion), so its
# input is released as hold's is.

const Driver := preload("res://tools/play_driver.gd")

# The game's own actions, beside the driver's: each name with its "fields" and
# a "description", as in the driver's ACTIONS, such as
#   "build": {"fields": ["x", "y", "kind"], "description": "Builds ..."}
# apply() carries them out.
const ACTIONS := {}

# Set by the driver before watch().
var game: Node
var driver: Driver

# What the screen shows, as text: each turn's fields beside "ui", such as
# {"label": "Clicks: 3"}.
func screen() -> Dictionary:
	var label: Variant = game.get("label")
	if not label is Label:
		return {}
	return {"label": (label as Label).text}

# Connects the game's signals to driver._event(), so each turn lists what
# happened while time ran. The game doesn't know about the driver. Name events
# such as a building knocked down or a beacon found, each with the few fields
# an agent needs.
func watch() -> void:
	var button: Variant = game.get("button")
	if button is Button:
		(button as Button).pressed.connect(func() -> void: driver._event("pressed", {"node": "Button"}))

# Applies one of ACTIONS, its fields already checked, and returns
# {"ok": true, ...} or {"ok": false, "reason": ...}.
func apply(action: Dictionary) -> Dictionary:
	return {"ok": false, "reason": "the game has no action \"%s\"" % action.do}
