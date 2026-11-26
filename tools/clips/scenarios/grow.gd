extends "res://tools/clips/scenario.gd"

# The player holds Shift, grows, walks right into BOX A, then lets go.
#
#   tools/clips/record.sh tools/clips/scenarios/grow.gd [<before-ref>] [<after-ref>]

func run() -> void:
	fixture("a new game")
	start_clip()
	await hold(0.5)
	strip(30, "hold Shift, walk right into BOX A, let go")
	mark("hold Shift")
	Events.hold_key(KEY_SHIFT, true)
	await hold(0.6)
	mark("walk right")
	Events.hold_key(KEY_RIGHT, true)
	await hold(6.0)
	Events.hold_key(KEY_RIGHT, false)
	mark("let go of Shift")
	Events.hold_key(KEY_SHIFT, false)
	await hold(1.0)
	finish()
