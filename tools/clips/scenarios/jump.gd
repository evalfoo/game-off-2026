extends "res://tools/clips/scenario.gd"

# The player jumps small, then holds Shift and jumps big.
#
#   tools/clips/record.sh tools/clips/scenarios/jump.gd [<before-ref>] [<after-ref>]

func run() -> void:
	fixture("a new game")
	start_clip()
	strip(10, "jump small, hold Shift, jump big")
	mark("jump small")
	await _jump()
	await hold(0.6)
	mark("hold Shift")
	Events.hold_key(KEY_SHIFT, true)
	await hold(0.6)
	mark("jump big")
	await _jump()
	await hold(1.2)
	Events.hold_key(KEY_SHIFT, false)
	finish()

# Holds Space through the rise, for a full jump.
func _jump() -> void:
	Events.hold_key(KEY_SPACE, true)
	await hold(0.6)
	Events.hold_key(KEY_SPACE, false)
