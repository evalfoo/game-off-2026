extends RefCounted

# The game's part of tools/play_driver.gd, which lets an agent play the game
# one turn at a time. The driver is generic and tools/update.sh replaces it
# with the template's; this file is the game's, and update.sh leaves it alone.
# The driver loads it when it plays the game, not a --scene, and plays without
# it when it's missing. Each part is optional.
#
# The game has no actions of its own: an agent plays it with the driver's
# "hold", such as {"do": "hold", "keys": ["Shift", "Right"], "seconds": 2}.
# As the game grows, add its actions to ACTIONS and apply(), what its HUD shows
# to screen() and the signals worth reporting to watch().

const Driver := preload("res://tools/play_driver.gd")

const ACTIONS := {}

# Set by the driver before watch().
var game: Node
var driver: Driver

# What the screen shows, as text: the readout of the player's size, mass and
# speed.
func screen() -> Dictionary:
	var readout: Variant = game.get("readout")
	if not readout is Label:
		return {}
	return {"readout": (readout as Label).text}

# The game emits no signals worth reporting yet.
func watch() -> void:
	pass

func apply(action: Dictionary) -> Dictionary:
	return {"ok": false, "reason": "the game has no action \"%s\"" % action.do}
