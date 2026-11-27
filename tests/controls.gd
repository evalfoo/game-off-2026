extends "res://tests/lib/test.gd"

# The small player's controls: quick starts and stops, a short jump on a short
# press, falling faster than rising, a jump just after walking off an edge, and
# a jump pressed just before landing.

func run() -> void:
	await _speed()
	await _jump_cut()
	await _fall()
	await _coyote()
	await _buffer()

func _speed() -> void:
	var game := Fixture.launch(root)
	var player: CharacterBody2D = game.player
	await physics(10)
	Events.hold_key(KEY_RIGHT, true)
	await physics(8)
	var running := player.velocity.x
	Events.hold_key(KEY_RIGHT, false)
	await physics(4)
	var stopped := player.velocity.x
	check(is_equal_approx(running, 300.0), "it reaches full speed in 8 frames: %.1f" % running)
	check(stopped == 0.0, "it stops 4 frames after letting go: %.1f" % stopped)
	await _end(game)

func _jump_cut() -> void:
	var game := Fixture.launch(root)
	var player: CharacterBody2D = game.player
	await physics(10)
	var start := player.position.y
	Events.hold_key(KEY_SPACE, true)
	await physics(1)
	Events.hold_key(KEY_SPACE, false)
	var top := start
	for i: int in 60:
		await physics_frame
		top = minf(top, player.position.y)
	check(start - top > 20.0 and start - top < 60.0, "a one-frame press jumps under half as high as a held one: %.1f px" % (start - top))
	await _end(game)

func _fall() -> void:
	var game := Fixture.launch(root)
	var player: CharacterBody2D = game.player
	await physics(10)
	Events.hold_key(KEY_SPACE, true)
	while player.is_on_floor():
		await physics_frame
	var rising := 0
	var falling := 0
	for i: int in 90:
		if player.is_on_floor():
			break
		if player.velocity.y < 0.0:
			rising += 1
		else:
			falling += 1
		await physics_frame
	Events.hold_key(KEY_SPACE, false)
	check(falling < rising * 0.8, "a jump falls faster than it rises: %d frames up, %d down" % [rising, falling])
	await _end(game)

# Walks right off BOX B and presses jump after the given frames in the air.
# Returns whether the player rose.
func _jump_off_edge(frames: int) -> bool:
	var game := Fixture.launch(root)
	var player: CharacterBody2D = game.player
	var box: CharacterBody2D = game.get_node("BoxB")
	player.position = box.position + Vector2(0, -40)
	await physics(10)
	Events.hold_key(KEY_RIGHT, true)
	for i: int in 60:
		await physics_frame
		if not player.is_on_floor():
			break
	await physics(frames)
	Events.hold_key(KEY_SPACE, true)
	await physics(2)
	var rose := player.velocity.y < 0.0
	Events.hold_key(KEY_SPACE, false)
	Events.hold_key(KEY_RIGHT, false)
	await _end(game)
	return rose

func _coyote() -> void:
	check(await _jump_off_edge(3), "a jump 3 frames after walking off an edge still works")
	check(not await _jump_off_edge(12), "12 frames after, it doesn't")

# Drops the player from height and presses jump the given frames before it
# lands. Returns whether it jumped again on landing.
func _press_before_landing(frames: int) -> bool:
	var game := Fixture.launch(root)
	var player: CharacterBody2D = game.player
	await physics(10)
	var floor_y := player.position.y
	# Lands about 18 frames after the drop.
	player.position.y = floor_y - 80.0
	await physics(18 - frames)
	Events.hold_key(KEY_SPACE, true)
	var jumped := false
	var landed := false
	for i: int in 30:
		await physics_frame
		landed = landed or player.is_on_floor()
		if landed and player.velocity.y < 0.0:
			jumped = true
			break
	Events.hold_key(KEY_SPACE, false)
	await _end(game)
	return jumped

func _buffer() -> void:
	check(await _press_before_landing(3), "a jump pressed 3 frames before landing jumps on landing")
	check(not await _press_before_landing(12), "pressed 12 frames before, it doesn't")

func _end(game: Node) -> void:
	game.free()
	await physics(2)

func physics(count: int) -> void:
	for i: int in count:
		await physics_frame
