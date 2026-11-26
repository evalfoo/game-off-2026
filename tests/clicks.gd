extends "res://tests/lib/test.gd"

# Pressing the button raises the click count by one.

func run() -> void:
	var game := Fixture.launch(root)
	await frames(1)
	check(game.label.text == "Clicks: 0", "a new game shows no clicks")
	game.button.pressed.emit()
	check(game.clicks == 1, "a press counts one click")
	check(game.label.text == "Clicks: 1", "the label shows the new count")
