extends "res://tests/lib/test.gd"

# In a native window, a real mouse click on the button counts once.

func run() -> void:
	var game := Fixture.launch(root)
	await frames(2)
	var button: Button = game.button
	Events.click(button.get_global_rect().get_center())
	await frames(2)
	check(game.clicks == 1, "a mouse click counts one click")
	Events.click(Vector2(10, 10))
	await frames(2)
	check(game.clicks == 1, "a click beside the button counts nothing")
