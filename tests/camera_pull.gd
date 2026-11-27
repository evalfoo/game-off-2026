extends "res://tests/lib/test.gd"

# The camera's pull toward a marked object (pull_toward in game/camera.gd), in
# the wide room with a staged marker above the floor: the room marks nothing
# itself. With the player standing outside the outer ring, at it, midway, at
# the inner ring and inside it, the settled view is compared with the view
# when the marker is moved far away: no pull outside or at the outer ring,
# half the share midway, the full share at the inner ring and inside, from
# both walk directions. A jump inside the inner ring keeps the view's height,
# and a marker by the right wall doesn't take the view out of the room. Every
# physics frame checks the view stays inside the room.

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

	# A marker by the right wall: the pull stops at the room's edge.
	var size: Vector2 = room.SIZE
	marker.position = Vector2(size.x - 20.0, MARK.y)
	player.position.x = size.x - 60.0
	await physics(180)
	check(absf(_centre().x - (size.x - HALF_VIEW.x)) < 0.01,
		"a marker by the right wall leaves the view at the room's edge: %.1f" % _centre().x)

	check(outside == 0, "the view stays inside the room every frame: %d frames outside" % outside)
	room.free()


# Stands the player at x, then compares the settled view with the marker in
# place against the settled view with it far away.
func _check_at(x: float, label: String) -> void:
	player.position.x = x
	marker.position = FAR
	await physics(150)
	var unpulled := _centre()
	marker.position = MARK
	await physics(150)
	var pulled := _centre()
	var distance := player.position.distance_to(MARK)
	var weight := clampf((OUTER - distance) / (OUTER - INNER), 0.0, 1.0)
	var expected := unpulled.lerp(MARK, SHARE * weight)
	check(pulled.distance_to(expected) < 0.5,
		"%s, %.1f px from the marker: the view moves %.2f of the way toward it, (%.1f, %.1f) -> (%.1f, %.1f), expected (%.1f, %.1f)" % [
			label, distance, SHARE * weight, unpulled.x, unpulled.y, pulled.x, pulled.y, expected.x, expected.y])


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
		var c := _centre()
		var room_size: Vector2 = room.SIZE
		if c.x < HALF_VIEW.x - 0.01 or c.x > room_size.x - HALF_VIEW.x + 0.01 \
				or c.y < HALF_VIEW.y - 0.01 or c.y > room_size.y - HALF_VIEW.y + 0.01:
			outside += 1
