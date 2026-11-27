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
# the room away from the world's origin. At zoom 2 the window and the room's
# edges use the smaller view. The pulled target stays inside the room's limits,
# so letting go of Down by the bottom edge moves the view back at once and a
# fall off a ledge by the top edge stays within the fall line. A camera started
# in the air keeps its ordinary height. Every physics frame checks the view
# stays inside the room.

const HALF_VIEW := Vector2(160, 90)
const INNER := 112.0
const OUTER := 192.0
const SHARE := 0.5
# The marker: right of the step, so the player stands on the floor at every
# ring, and six tiles above the floor, so the ring distances mix x and y.
const MARK := Vector2(740, 160)
const FAR := Vector2(-10000, -10000)
const PlayerCamera := preload("res://game/camera.gd")
const Tiles := preload("res://game/tiles.gd")

var room: Node2D
var player: CharacterBody2D
var camera: Camera2D
var marker := Node2D.new()
# Frames whose view showed something outside the room.
var outside := 0
# Where the room's contents sit in the world.
var shift := Vector2.ZERO


func run() -> void:
	room = (load("res://game/rooms/wide.tscn") as PackedScene).instantiate()
	root.add_child(room)
	player = room.player
	camera = room.camera
	marker.position = MARK
	room.view.world.add_child(marker)
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
	shift = Vector2.ZERO
	await physics_frame
	await _check_zoom()
	await physics_frame
	await _check_look_release()
	await physics_frame
	await _check_ledge_fall(5.0)
	await physics_frame
	await _check_ledge_fall(2.0)
	await physics_frame
	await _check_start_in_air()


# The wide room placed one room's width right of the world's origin, with
# the camera's limits moved with it: a marker left of a player resting near the
# right edge pulls the view left, the same as in a room at the origin.
func _check_moved_room() -> void:
	room = (load("res://game/rooms/wide.tscn") as PackedScene).instantiate()
	var size: Vector2 = room.SIZE
	root.add_child(room)
	# The room's world sits in a SubViewport, so moving the room doesn't move
	# it. A node one room's width right of the origin holds it instead.
	var moved := Node2D.new()
	moved.position = Vector2(size.x, 0)
	shift = moved.position
	room.view.world.add_child(moved)
	for node: Node in room.view.world.get_children():
		if node != moved:
			node.reparent(moved, false)
	player = room.player
	camera = room.camera
	camera.limit_left = int(size.x)
	camera.limit_right = int(2.0 * size.x)
	marker = Node2D.new()
	moved.add_child(marker)
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
	var expected := unpulled.lerp(moved.to_global(at), SHARE * weight)
	check(start < 600.0 and _centre().distance_to(expected) < 0.5,
		"in a room at world x %d, a marker left of the player, %.1f px from their feet, pulls the view %.2f of the way, (%.1f, %.1f) -> (%.1f, %.1f), expected (%.1f, %.1f)" % [
			size.x, distance, SHARE * weight, unpulled.x, unpulled.y, _centre().x, _centre().y, expected.x, expected.y])
	check(outside == 0, "in the moved room, the view stays inside the room every frame: %d frames outside" % outside)
	room.free()


# The wide room with the camera at zoom 2, which shows 160 x 90 world pixels:
# after walking right, the view settles the look-ahead less half the narrower
# window ahead of the player. By the right wall, with the view at the room's
# edge, a marker further right holds it there.
func _check_zoom() -> void:
	room = (load("res://game/rooms/wide.tscn") as PackedScene).instantiate()
	root.add_child(room)
	player = room.player
	camera = room.camera
	camera.zoom = Vector2(2, 2)
	marker = Node2D.new()
	marker.position = FAR
	room.view.world.add_child(marker)
	camera.call("pull_toward", marker, INNER, OUTER, SHARE)
	outside = 0
	var size: Vector2 = room.SIZE
	var ahead: float = camera.small_look_ahead
	var half_window: float = camera.small_window_margin * HALF_VIEW.x / 2.0
	player.position.x = 540.0
	await physics(2)
	await _walk(KEY_RIGHT, func() -> bool: return player.position.x >= 600.0)
	await physics(150)
	check(absf(_centre().x - (player.position.x + ahead - half_window)) < 0.5,
		"at zoom 2, walking right, the view settles %.1f px ahead of the player: %.1f" % [ahead - half_window, _centre().x - player.position.x])

	player.position.x = size.x - 45.0
	await physics(150)
	var edge := size.x - HALF_VIEW.x / 2.0
	var resting := _centre().x
	marker.position = Vector2(size.x - 60.0, 186.0)
	await physics(150)
	check(absf(resting - edge) < 0.01 and absf(_centre().x - edge) < 0.01,
		"at zoom 2, by the right wall, a marker further right holds the view at the room's edge, %.1f: %.1f -> %.1f" % [edge, resting, _centre().x])
	check(outside == 0, "at zoom 2, the view stays inside the room every frame: %d frames outside" % outside)
	room.free()


# Opens the wide room with a marker at `at` pulling with the given rings and
# share.
func _open(at: Vector2, inner: float, outer: float, share: float) -> void:
	room = (load("res://game/rooms/wide.tscn") as PackedScene).instantiate()
	root.add_child(room)
	player = room.player
	camera = room.camera
	marker = Node2D.new()
	marker.position = at
	room.view.world.add_child(marker)
	camera.call("pull_toward", marker, inner, outer, share)
	outside = 0


# Looking down by the room's bottom edge with a marker below the view: the
# pulled target stays inside the limit, so letting go of Down starts the view
# back up on the next step instead of waiting behind the limit.
func _check_look_release() -> void:
	await _open(Vector2(660, 206), INNER, OUTER, SHARE)
	player.position.x = 640.0
	await physics(150)
	var bottom: float = room.SIZE.y - HALF_VIEW.y
	var past := 0
	Events.hold_key(KEY_DOWN, true)
	for i: int in 150:
		await physics(1)
		if camera.position.y > bottom + 0.01:
			past += 1
	var held := _centre().y
	Events.hold_key(KEY_DOWN, false)
	var waited := 0
	for i: int in 30:
		await physics(1)
		if _centre().y < held - 0.01:
			break
		waited += 1
	await physics(150)
	check(past == 0 and absf(held - bottom) < 0.01 and waited <= 1,
		"looking down by the bottom edge with a marker below, the target passes the limit on %d frames, the view holds at %.1f, and after letting go it waits %d steps and settles at %.1f" % [
			past, held, waited, _centre().y])
	check(outside == 0, "looking down with a marker, the view stays inside the room every frame: %d frames outside" % outside)
	room.free()


# Walking off a ledge by the room's top edge, with a marker above the view
# pulling at 0.75: the target stays inside the limit, so the fall line keeps
# the feet within window_bottom of the view's centre.
func _check_ledge_fall(smoothing: float) -> void:
	await _open(Vector2(720, 32), 192.0, 256.0, 0.75)
	camera.small_smoothing_speed = smoothing
	camera.big_smoothing_speed = smoothing
	for node: Node in room.view.world.get_children():
		if node is TileMapLayer:
			Tiles.platform(node as TileMapLayer, 10, 40, 45)
	player.position = Vector2(700, 160)
	await physics(150)
	var on_ledge := player.is_on_floor() and absf(player.position.y - 160.0) < 0.5
	var lowest := -INF
	var left := false
	Events.hold_key(KEY_RIGHT, true)
	for i: int in 300:
		await physics(1)
		if not player.is_on_floor():
			left = true
			lowest = maxf(lowest, player.position.y - _centre().y)
		elif left:
			break
	Events.hold_key(KEY_RIGHT, false)
	var line: float = camera.window_bottom
	check(on_ledge and left and lowest <= line + 0.01,
		"smoothing speed %.0f: walking off a ledge under a marker by the top edge, the feet fall at most %.2f px below the view's centre, the fall line %.0f" % [
			smoothing, lowest, line])
	check(outside == 0, "falling off the ledge, the view stays inside the room every frame: %d frames outside" % outside)
	room.free()


# A camera added while the player is in the air, with a marker above already
# pulling: its first view keeps the ordinary height, and the fall keeps the
# feet within window_bottom of the view's centre.
func _check_start_in_air() -> void:
	room = (load("res://game/rooms/wide.tscn") as PackedScene).instantiate()
	root.add_child(room)
	player = room.player
	room.camera.free()
	player.position = Vector2(600, 226)
	marker = Node2D.new()
	marker.position = Vector2(600, 90)
	room.view.world.add_child(marker)
	var size: Vector2 = room.SIZE
	camera = PlayerCamera.new()
	camera.target = player
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(size.x)
	camera.limit_bottom = int(size.y)
	camera.call("pull_toward", marker, 144.0, 192.0, SHARE)
	room.view.world.add_child(camera)
	outside = 0
	var first := player.position.y - _centre().y
	var lowest := first
	for i: int in 120:
		await physics(1)
		lowest = maxf(lowest, player.position.y - _centre().y)
		if player.is_on_floor():
			break
	var line: float = camera.window_bottom
	check(first <= line and lowest <= line + 0.5,
		"starting in the air under a pulling marker, the first view puts the feet %.2f px below its centre, and the fall at most %.2f, the fall line %.0f" % [
			first, lowest, line])
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
		var c := _centre() - shift
		var room_size: Vector2 = room.SIZE
		var half := HALF_VIEW / camera.zoom
		if c.x < half.x - 0.01 or c.x > room_size.x - half.x + 0.01 \
				or c.y < half.y - 0.01 or c.y > room_size.y - half.y + 0.01:
			outside += 1
