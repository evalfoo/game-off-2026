extends "res://tests/lib/test.gd"

# The game's part of the play driver, game/play_hooks.gd, loaded as the driver
# loads it: its HUD text.

const Driver := preload("res://tools/play_driver.gd")

func run() -> void:
	var game := Fixture.launch(root)
	await frames(2)
	var driver := Driver.new()
	driver.game = game
	driver._load_hooks()
	var screen := driver._screen()
	check(screen.keys() == ["readout"], "a turn shows the readout: %s" % screen)
	check("mass: 1.0" in str(screen.get("readout", "")), "a new game reads as small and light: %s" % screen)
	check(driver._actions() == Driver.ACTIONS, "the game adds no actions of its own")
	driver.free()
