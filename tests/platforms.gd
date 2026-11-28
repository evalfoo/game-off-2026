extends "res://tests/lib/test.gd"

# The linked platforms (game/platform_pair.gd) in their level: each sits level
# with the floor over a pit.
#
# Played: the small player walks onto the left platform and moves nothing.
# While it grows the pair stays level. Fully big, it sinks the platform to its
# stop while the right one rises as far, and shrinking brings both back to
# level. The platform carries the player all the
# way, and the pair moves one way only. The big player walks onto the left
# platform from the floor: half on the floor it stands on the floor, and wholly
# on the platform it sinks it, also pressed against the pit's wall.
#
# Staged, with the player moved by hand: the big player stepping off the sunk
# platform, as the level has no way out of the pit at that size; the big player
# on the right platform; and a pair with other travel and speeds.

const STEP := 1.0 / 60.0

var level: Node2D
var pair: Node2D
var player: CharacterBody2D
var floor_y := 0.0


func run() -> void:
	_load_level()
	var travel: float = pair.travel
	check(travel == 48.0, "the level's pair has the default travel of three tiles, 48 px: %.1f" % travel)
	var left: Node2D = pair.left
	var right: Node2D = pair.right

	# The small player walks right until it stands on the left platform.
	await physics(10)
	Events.hold_key(KEY_RIGHT, true)
	for i: int in 300:
		await physics(1)
		if player.position.x >= left.global_position.x:
			break
	Events.hold_key(KEY_RIGHT, false)
	await physics(60)
	check(_on(left) and pair.offset == 0.0,
		"the small player walks onto the left platform and it stays level: feet %s, offset %.2f" % [player.position, pair.offset])

	# Growing there sinks it once fully big, and the player with it.
	Events.hold_key(KEY_SHIFT, true)
	var growing := 0
	var moved_early := 0
	while player.t < 1.0 and growing < 120:
		await physics(1)
		if player.t < 1.0:
			growing += 1
			if pair.offset != 0.0:
				moved_early += 1
	check(growing > 10 and moved_early == 0,
		"while the player grows, 0 < t < 1, the pair stays level: %d of %d steps moved" % [moved_early, growing])
	var ride := await _track(left, 180)
	check(ride.one_way and ride.carried,
		"growing, the left platform sinks only downward and carries the player: %s" % ride)
	check(pair.offset == travel and is_equal_approx(left.global_position.y, floor_y + travel) \
			and is_equal_approx(right.global_position.y, floor_y - travel),
		"the big player sinks the left platform %.0f px to its stop and the right rises as far: left %.1f, right %.1f" % [
			travel, left.global_position.y, right.global_position.y])
	check(_on(left) and absf(player.position.y - (floor_y + travel)) < 0.5,
		"the player rides it down: feet at y %.2f" % player.position.y)

	# Shrinking on it brings both back, the player riding up.
	Events.hold_key(KEY_SHIFT, false)
	ride = await _track(left, 240)
	check(ride.one_way and ride.carried,
		"shrinking, the left platform rises only upward and carries the player: %s" % ride)
	check(pair.offset == 0.0 and is_equal_approx(left.global_position.y, floor_y) \
			and is_equal_approx(right.global_position.y, floor_y),
		"shrinking on it brings both back to level: offset %.2f" % pair.offset)
	check(_on(left) and absf(player.position.y - floor_y) < 0.5,
		"the player rides it back up to the floor's height: feet at y %.2f" % player.position.y)

	# Staged: the big player steps off the sunk platform onto the floor.
	Events.hold_key(KEY_SHIFT, true)
	await physics(180)
	check(pair.offset == travel, "staged: the big player sinks the left platform again: offset %.2f" % pair.offset)
	player.position = Vector2(48, floor_y)
	player.velocity = Vector2.ZERO
	await physics(180)
	check(player.t == 1.0 and player.is_on_floor() and pair.offset == 0.0 \
			and is_equal_approx(left.global_position.y, floor_y) and is_equal_approx(right.global_position.y, floor_y),
		"staged: once the big player leaves, both return to level: offset %.2f, t %.2f" % [pair.offset, player.t])

	# Staged: the big player on the right platform sinks it instead.
	player.position = right.global_position
	await physics(180)
	check(_on(right) and pair.offset == -travel and is_equal_approx(right.global_position.y, floor_y + travel) \
			and is_equal_approx(left.global_position.y, floor_y - travel),
		"staged: the big player sinks the right platform and the left rises: left %.1f, right %.1f" % [
			left.global_position.y, right.global_position.y])
	Events.hold_key(KEY_SHIFT, false)
	level.free()
	await physics(2)

	# Played: the big player walks onto the left platform from the floor and on
	# into the pit's far wall. Half on the floor, it stands on the floor.
	_load_level()
	left = pair.left
	Events.hold_key(KEY_SHIFT, true)
	await physics(60)
	Events.hold_key(KEY_RIGHT, true)
	var pit_edge := left.global_position.x - 24.0
	var half_on := 0.0
	for i: int in 300:
		await physics(1)
		if player.position.x - float(player.shape.size.x) / 2.0 < pit_edge:
			half_on = maxf(half_on, pair.offset)
		if pair.offset > 0.0:
			break
	check(half_on == 0.0, "half on the floor, the big player leaves the left platform level: offset up to %.2f" % half_on)
	ride = await _track(left, 180)
	Events.hold_key(KEY_RIGHT, false)
	check(ride.one_way and ride.carried and pair.offset == travel,
		"the big player walks onto the left platform and on into the pit's wall, and it sinks to its stop, one way: offset %.2f, %s" % [pair.offset, ride])
	check(absf(player.position.x - (left.global_position.x + 24.0 - float(player.shape.size.x) / 2.0)) < 0.5,
		"the player presses against the pit's far wall: x %.2f" % player.position.x)
	Events.hold_key(KEY_SHIFT, false)
	level.free()
	await physics(2)

	await _check_exports()


# The pair moves by its own travel and speeds: here a 32 px travel, sinking
# at 30 px/s and returning at 90 px/s. Staged on the left platform.
func _check_exports() -> void:
	level = (load("res://game/levels/platforms.tscn") as PackedScene).instantiate()
	var placed: Node2D = level.get_node("PlatformPair")
	placed.set("travel", 32.0)
	placed.set("sink_speed", 30.0)
	placed.set("return_speed", 90.0)
	root.add_child(level)
	pair = level.pair
	player = level.player
	floor_y = level.FLOOR_Y
	var left: Node2D = pair.left
	var right: Node2D = pair.right
	Events.hold_key(KEY_SHIFT, true)
	await physics(30)
	player.position = left.global_position
	await physics(5)
	var sink := await _steps(20)
	check(absf(sink - 30.0 * STEP) < 0.0001,
		"staged: sink_speed 30 sinks the platform %.4f px a step, 30 px/s" % sink)
	await physics(180)
	check(pair.offset == 32.0 and is_equal_approx(left.global_position.y, floor_y + 32.0) \
			and is_equal_approx(right.global_position.y, floor_y - 32.0),
		"staged: travel 32 stops the left platform 32 px down and the right 32 px up: left %.1f, right %.1f" % [
			left.global_position.y, right.global_position.y])
	Events.hold_key(KEY_SHIFT, false)
	await physics(5)
	var back := -await _steps(5)
	check(absf(back - 90.0 * STEP) < 0.0001,
		"staged: return_speed 90 lifts the platform %.4f px a step, 90 px/s" % back)
	level.free()
	await physics(2)


func _load_level() -> void:
	level = (load("res://game/levels/platforms.tscn") as PackedScene).instantiate()
	root.add_child(level)
	pair = level.pair
	player = level.player
	floor_y = level.FLOOR_Y


# Runs count steps on platform, and reports whether the pair's offset moved one
# way only and whether the player's feet stayed on the platform every step.
func _track(platform: Node2D, count: int) -> Dictionary:
	var start: float = pair.offset
	var last := start
	var one_way := true
	var off := 0
	var direction := 0.0
	for i: int in count:
		await physics(1)
		var moved: float = pair.offset - last
		if moved != 0.0:
			if direction == 0.0:
				direction = signf(moved)
			elif signf(moved) != direction:
				one_way = false
		last = pair.offset
		if not _on(platform):
			off += 1
	return {"one_way": one_way, "carried": off == 0, "steps_off": off, "from": start, "to": last}


# The average offset change over count steps.
func _steps(count: int) -> float:
	var start: float = pair.offset
	await physics(count)
	return (pair.offset - start) / count


# Whether the player stands on platform, with the feet on its top. The feet
# rest a hair above it, at the body's safe margin.
func _on(platform: Node2D) -> bool:
	return player.is_on_floor() and absf(player.position.y - platform.global_position.y) < 0.5 \
			and absf(player.position.x - platform.global_position.x) < 24.0


func physics(count: int) -> void:
	for i: int in count:
		await physics_frame
