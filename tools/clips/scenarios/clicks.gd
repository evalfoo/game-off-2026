extends "res://tools/clips/scenario.gd"

# The button counts three clicks.
#
#   tools/clips/record.sh tools/clips/scenarios/clicks.gd [<before-ref>] [<after-ref>]
#
# To write a new scenario, copy this file and change run():
# - The game scene is already running with isolated saves. Set up what you
#   need and say how with fixture().
# - Call start_clip() once the scene is on screen. Earlier frames are dropped.
# - Drive the game with hold(seconds) and Events.click(), move_mouse() and key().
# - Call strip(step, note) just before the motion you want in the frame strip:
#   8 frames, step frames apart. Without it, the strip spreads 8 frames over
#   the whole clip.
# - Name events with mark(). They are listed in the clip README with times.
# - End with finish(). It removes the test saves and calls quit().
#
# Scenarios are recorded on old refs too, so stick to game APIs that exist on
# both sides of the change.

func run() -> void:
	fixture("a new game")
	start_clip()
	await hold(0.5)
	var button: Button = game.get("button")
	strip(6, "three clicks")
	for i: int in 3:
		mark("click %d" % (i + 1))
		Events.click(button.get_global_rect().get_center())
		await hold(0.5)
	await hold(0.5)
	finish()
