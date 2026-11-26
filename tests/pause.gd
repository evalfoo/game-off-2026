extends "res://tests/lib/test.gd"

# With time stopped (Engine.time_scale = 0, as the play driver does between
# turns), a box the player is pushing stays where it is instead of turning to
# NaN, and moves again once time runs. See evalfoo/godot-template#44.

func run() -> void:
	var game := Fixture.launch(root)
	var box: RigidBody2D = game.get_node("BoxA")
	var player: RigidBody2D = game.player
	player.position.x = box.position.x - 60
	Events.hold_key(KEY_RIGHT, true)
	await physics(30)
	# The frame under way keeps the length it started with, so the pause starts
	# a frame later.
	Engine.time_scale = 0.0
	await physics(1)
	var before := box.position
	await physics(30)
	var paused := box.position
	Engine.time_scale = 1.0
	await physics(30)
	Events.hold_key(KEY_RIGHT, false)
	check(paused.is_finite() and paused.is_equal_approx(before), "a pushed box holds still while time is stopped: %s -> %s" % [before, paused])
	check(box.position.is_finite() and box.position.x > paused.x + 5.0, "it moves on once time runs: %s" % box.position)

func physics(count: int) -> void:
	for i: int in count:
		await physics_frame
