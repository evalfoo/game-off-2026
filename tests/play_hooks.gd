extends "res://tests/lib/test.gd"

# The game's part of the play driver, game/play_hooks.gd, loaded as the driver
# loads it: its HUD text and its events.
# TODO(template): replace with the game's HUD text, events and actions.

const Driver := preload("res://tools/play_driver.gd")

func run() -> void:
	var game := Fixture.launch(root)
	await frames(2)
	var driver := Driver.new()
	driver.game = game
	driver._load_hooks()
	check(driver._screen() == {"label": "Clicks: 0"}, "a turn shows the click count: %s" % driver._screen())
	driver.game_time = 5.0
	(game.button as Button).pressed.emit()
	var taken := driver._take_events()
	check(taken == {"events": [{"event": "pressed", "time": 5.0, "node": "Button"}]}, "the game's button press is an event: %s" % taken)
	check(driver._screen() == {"label": "Clicks: 1"}, "the next turn shows the new count")
	driver.free()
