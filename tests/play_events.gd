extends "res://tests/lib/test.gd"

# The play driver's turn events: each turn takes the events since the last one,
# in order and with their game time, at most MAX_EVENTS, and counts the rest.
# Then how it uses the game's hooks, with stand-in hooks; tests/play_hooks.gd
# checks the game's own.

const Driver := preload("res://tools/play_driver.gd")

func run() -> void:
	var driver := Driver.new()
	driver.game_time = 1.234
	driver._event("first", {"node": "A"})
	driver.game_time = 2.0
	driver._event("second")
	var taken := driver._take_events()
	check(taken == {"events": [{"event": "first", "time": 1.23, "node": "A"}, {"event": "second", "time": 2.0}]}, "a turn takes the events in order, with their game time and fields: %s" % taken)
	check(driver._take_events() == {"events": []}, "the next turn starts with none")

	for i in Driver.MAX_EVENTS + 3:
		driver._event("tick", {"i": i})
	taken = driver._take_events()
	var events: Array = taken.events
	check(events.size() == Driver.MAX_EVENTS and events[-1].i == Driver.MAX_EVENTS - 1 and taken.events_dropped == 3, "a turn keeps the first %d events and counts the 3 it left out" % Driver.MAX_EVENTS)
	check(driver._take_events() == {"events": []}, "the count starts again at the next turn")

	# Without game/play_hooks.gd, as with --scene, the turns have no HUD text
	# and only the driver's actions.
	check(driver._screen() == {} and driver._actions() == Driver.ACTIONS, "without hooks a turn has no HUD text and the driver's actions")

	# A game action from the hooks is listed after the driver's, its fields are
	# checked, and the hooks apply it.
	driver.hooks = FakeHooks.new()
	check(driver._actions().keys() == Driver.ACTIONS.keys() + ["jump"], "the hooks' action follows the driver's: %s" % [driver._actions().keys()])
	var result: Dictionary = await driver.apply({"do": "jump", "height": 2, "why": "test"})
	check(result == {"ok": true, "height": 2}, "the hooks apply their own action: %s" % result)
	result = await driver.apply({"do": "jump", "speed": 2})
	check(not result.ok and "doesn't take \"speed\"" in result.reason, "a field the game action doesn't take is refused: %s" % result)
	driver.free()

class FakeHooks:
	const ACTIONS := {"jump": {"fields": ["height"], "description": "Jumps."}}

	func apply(action: Dictionary) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"ok": true, "height": action.height}
