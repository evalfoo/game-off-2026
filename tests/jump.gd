extends "res://tests/lib/test.gd"

# The big player jumps half as high as the small one.

func run() -> void:
	var small := await _jump_height(false)
	check(small > 110.0, "the small player jumps about 120 px: %.1f" % small)
	var big := await _jump_height(true)
	var ratio := big / small
	check(ratio > 0.45 and ratio < 0.55, "the big player jumps half as high: %.1f px, %.2f of small" % [big, ratio])

# Jumps in place and returns how far the feet rose.
func _jump_height(big: bool) -> float:
	var game := Fixture.launch(root)
	var player: CharacterBody2D = game.player
	if big:
		Events.hold_key(KEY_SHIFT, true)
	await physics(40)
	var start := player.position.y
	var top := start
	Events.hold_key(KEY_SPACE, true)
	for i: int in 60:
		await physics_frame
		top = minf(top, player.position.y)
	Events.hold_key(KEY_SPACE, false)
	Events.hold_key(KEY_SHIFT, false)
	game.free()
	await physics(2)
	return start - top

func physics(count: int) -> void:
	for i: int in count:
		await physics_frame
