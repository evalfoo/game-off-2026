extends "res://tests/lib/test.gd"

# The camera's pull toward a marked object (pull_toward in game/camera.gd), in
# the wide room with a staged marker above the floor: the room marks nothing
# itself. With the player standing outside the outer ring, at it, midway, at
# the inner ring and inside it, the settled view is compared with the view
# when the marker is moved far away: no pull outside or at the outer ring,
# half the share midway, the full share at the inner ring and inside, from
# both walk directions. A jump inside the inner ring keeps the view's height,
# a marker by the right wall pulls the view only to the room's edge, and a
# marker inside the room pulls a view resting at that edge back in, also with
# the room away from the world's origin. Every physics frame checks the view
# stays inside the room.

const HALF_VIEW := Vector2(160, 90)
const INNER := 112.0
const OUTER := 192.0
const SHARE := 0.5
# The marker: right of the step, so the player stands on the floor at every
# ring, and six tiles above the floor, so the ring distances mix x and y.
const MARK := Vector2(740, 160)
const FAR := Vector2(-10000, -10000)

var room: Node2D
var player: CharacterBody2D
var camera: Camera2D
var marker := Node2D.new()
# Frames whose view showed something outside the room.
var outside := 0


func run() -> void:
	room = (load("res://game/rooms/wide.tscn") as PackedScene).instantiate()
	root.add_child(room)
	player = room.player
	camera = room.camera
	marker.position = MARK
	room.add_child(marker)
	camera.call("pull_toward", marker, INNER, OUTER, SHARE)
	await physics(1)
	var floor_y: float = room.FLOOR_Y
	var dy := floor_y - MARK.y

	# From the left: past the step, the look-ahead point still right of the
	# player, where it starts.
	player.position.x = 520.0
	await physics(2)
	check(camera.side == 1.0, "from the left, the look-ahead point is right of the player")
	for distance: float in [OUTER + 40.0, OUTER, (INNER + OUTER) / 2.0, INNER, dy + 4.0]:
		await _check_at(MARK.x - sqrt(distance * distance - dy * dy), "from the left")

	# From the right, walking left.
	player.position.x = 900.0
	await physics(2)
	await _walk(KEY_LEFT, func() -> bool: return player.position.x <= MARK.x + 90.0)
	check(camera.side == -1.0, "walking left, the look-ahead point is left of the player")
	for distance: float in [INNER, dy + 4.0]:
		await _check_at(MARK.x + sqrt(distance * distance - dy * dy), "from the right")

	# A jump in place inside the inner ring: the view's height holds in the air.
	var view_y := _centre().y
	Events.hold_key(KEY_SPACE, true)
	var top := player.position.y
	var moved := 0.0
	var left := false
	for i: int in 300:
		await physics(1)
		top = minf(top, player.position.y)
		if player.is_on_floor():
			if left:
				break
			continue
		left = true
		moved = maxf(moved, absf(_centre().y - view_y))
	Events.hold_key(KEY_SPACE, false)
	check(floor_y - top > 15.0 and moved < 0.5,
		"a jump inside the inner ring rises %.1f px and moves the view %.1f px in the air" % [floor_y - top, moved])

	# A marker by the right wall: with the look-ahead point left, the view
	# stops short of the room's edge without the pull, and the pull takes it
	# only as far as the edge.
	var size: Vector2 = room.SIZE
	marker.position = FAR
	player.position.x = size.x - 60.0
	await physics(2)
	await _walk(KEY_LEFT, func() -> bool: return player.position.x <= size.x - 120.0)
	await physics(180)
	var unpulled := _centre().x
	marker.position = Vector2(size.x - 20.0, MARK.y)
	await physics(180)
	check(camera.side == -1.0 and unpulled < size.x - HALF_VIEW.x - 4.0 \
			and absf(_centre().x - (size.x - HALF_VIEW.x)) < 0.01,
		"a marker by the right wall pulls the view from %.1f to the room's edge, %.1f" % [unpulled, _centre().x])

	# With the look-ahead point right and the view resting at the right edge, a
	# marker inside the room pulls the view back in by the full blend, from
	# the edge rather than from the point past it.
	player.position.x = size.x - 200.0
	await physics(2)
	await _walk(KEY_RIGHT, func() -> bool: return player.position.x >= size.x - 130.0)
	var resting := await _check_at(player.position.x, "at the right edge, pulling back into the room",
			Vector2(size.x - 205.0, floor_y - 70.0))
	check(camera.side == 1.0 and absf(resting.x - (size.x - HALF_VIEW.x)) < 0.01,
		"before that pull, the view rests at the room's right edge: %.1f" % resting.x)

	check(outside == 0, "the view stays inside the room every frame: %d frames outside" % outside)
	room.free()
	await physics_frame
	await _check_moved_room()


# The wide room placed one room's width right of the world's origin, with
# the camera's limits moved with it: a marker left of a player resting near the
# right edge pulls the view left, the same as in a room at the origin.
func _check_moved_room() -> void:
	room = (load("res://game/rooms/wide.tscn") as PackedScene).instantiate()
	var size: Vector2 = room.SIZE
	room.position = Vector2(size.x, 0)
	root.add_child(room)
	player = room.player
	camera = room.camera
	camera.limit_left = int(size.x)
	camera.limit_right = int(2.0 * size.x)
	marker = Node2D.new()
	room.add_child(marker)
	camera.call("pull_toward", marker, INNER, OUTER, SHARE)
	outside = 0
	var at := Vector2(540, 186)
	var start: float = player.position.x
	player.position.x = 600.0
	marker.position = FAR
	await physics(180)
	var unpulled := _centre()
	marker.position = at
	await physics(180)
	var distance := player.position.distance_to(at)
	var weight := clampf((OUTER - distance) / (OUTER - INNER), 0.0, 1.0)
	var expected := unpulled.lerp(room.to_global(at), SHARE * weight)
	check(start < 600.0 and _centre().distance_to(expected) < 0.5,
		"in a room at world x %d, a marker %.1f px left of the player pulls the view %.2f of the way, (%.1f, %.1f) -> (%.1f, %.1f), expected (%.1f, %.1f)" % [
			size.x, distance, SHARE * weight, unpulled.x, unpulled.y, _centre().x, _centre().y, expected.x, expected.y])
	check(outside == 0, "in the moved room, the view stays inside the room every frame: %d frames outside" % outside)
	room.free()


# Stands the player at x, then compares the settled view with the marker at
# `at` against the settled view with it far away. Returns the view without
# the pull.
func _check_at(x: float, label: String, at := MARK) -> Vector2:
	player.position.x = x
	marker.position = FAR
	await physics(150)
	var unpulled := _centre()
	marker.position = at
	await physics(150)
	var pulled := _centre()
	var distance := player.position.distance_to(at)
	var weight := clampf((OUTER - distance) / (OUTER - INNER), 0.0, 1.0)
	var expected := unpulled.lerp(at, SHARE * weight)
	check(pulled.distance_to(expected) < 0.5,
		"%s, %.1f px from the marker: the view moves %.2f of the way toward it, (%.1f, %.1f) -> (%.1f, %.1f), expected (%.1f, %.1f)" % [
			label, distance, SHARE * weight, unpulled.x, unpulled.y, pulled.x, pulled.y, expected.x, expected.y])
	return unpulled


func _centre() -> Vector2:
	return camera.get_screen_center_position()


# Holds `key` until `done` returns true, up to 20 seconds, then lets go and
# waits for the player to stop.
func _walk(key: Key, done: Callable) -> void:
	Events.hold_key(key, true)
	for i: int in 1200:
		await physics(1)
		if done.call():
			break
	Events.hold_key(key, false)
	await physics(10)


func physics(count: int) -> void:
	for i: int in count:
		await physics_frame
		var c := _centre() - room.position
		var room_size: Vector2 = room.SIZE
		if c.x < HALF_VIEW.x - 0.01 or c.x > room_size.x - HALF_VIEW.x + 0.01 \
				or c.y < HALF_VIEW.y - 0.01 or c.y > room_size.y - HALF_VIEW.y + 0.01:
			outside += 1
