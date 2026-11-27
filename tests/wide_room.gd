extends "res://tests/lib/test.gd"

# The wide room's level comes from its scene (game/rooms/wide.tscn): the
# painted tiles end up in the pixel view's world at View/World/Tiles, the
# player starts at PlayerStart and stands on the floor, and the camera's limits
# are the tiles' bounds less the wall column on each side, which match the
# room's SIZE. Staged: edits to the scene before it starts show up in the
# game. A moved marker and a wall painted further right give a new start and
# right limit, and the layer and marker moved together, or mirrored, keep the
# limits on the room.

const Tiles := preload("res://game/tiles.gd")


func run() -> void:
	var room: Node2D = (load("res://game/rooms/wide.tscn") as PackedScene).instantiate()
	var marked := (room.get_node("PlayerStart") as Marker2D).position
	root.add_child(room)
	var player: CharacterBody2D = room.player
	check(player.position == marked, "the player starts at PlayerStart: %s" % player.position)
	await physics(10)
	var camera: Camera2D = room.camera
	var size: Vector2 = room.SIZE
	var tiles := room.get_node_or_null("View/World/Tiles") as TileMapLayer
	check(tiles != null and room.get_node_or_null("Tiles") == null,
		"the painted tiles move into the pixel view's world, at View/World/Tiles")
	check(player.is_on_floor() and absf(player.position.y - room.FLOOR_Y) < 0.01,
		"the player stands on the floor at FLOOR_Y: %s" % player.position)
	var limits := Rect2i(camera.limit_left, camera.limit_top,
			camera.limit_right - camera.limit_left, camera.limit_bottom - camera.limit_top)
	check(limits == Rect2i(Vector2i.ZERO, Vector2i(size)),
		"the camera's limits are the painted room less its walls, the room's SIZE: %s" % limits)
	var step_row: int = room.STEP_ROW
	var step_last: int = room.STEP_LAST
	check(tiles != null and tiles.get_cell_source_id(Vector2i(step_last, step_row)) != -1 \
			and tiles.get_cell_source_id(Vector2i(step_last + 1, step_row)) == -1,
		"the step is painted in row STEP_ROW and ends at column STEP_LAST")
	room.free()
	await physics(2)

	# Staged: the scene edited before it starts.
	room = (load("res://game/rooms/wide.tscn") as PackedScene).instantiate()
	var start := Vector2(200, 128)
	(room.get_node("PlayerStart") as Marker2D).position = start
	var painted: TileMapLayer = room.get_node("Tiles")
	var wall := int(size.x) / Tiles.TILE
	for row: int in int(size.y) / Tiles.TILE:
		painted.set_cell(Vector2i(wall + 4, row), 0, Tiles.FILL)
	root.add_child(room)
	player = room.player
	camera = room.camera
	check(player.position == start, "a moved PlayerStart moves where the player starts: %s" % player.position)
	check(camera.limit_right == int(size.x) + 4 * Tiles.TILE and camera.limit_left == 0,
		"a wall painted four columns further right moves the right limit with it: %d" % camera.limit_right)
	room.free()
	await physics(2)

	# Staged: the layer and the marker moved together, by (64, 16).
	room = (load("res://game/rooms/wide.tscn") as PackedScene).instantiate()
	var shift := Vector2(64, 16)
	(room.get_node("Tiles") as Node2D).position += shift
	(room.get_node("PlayerStart") as Node2D).position += shift
	root.add_child(room)
	player = room.player
	camera = room.camera
	var limits_moved := Rect2i(camera.limit_left, camera.limit_top,
			camera.limit_right - camera.limit_left, camera.limit_bottom - camera.limit_top)
	check(limits_moved == Rect2i(Vector2i(shift), Vector2i(size)),
		"moving the layer moves the camera's limits with it: %s" % limits_moved)
	await physics(10)
	check(player.is_on_floor() and absf(player.position.y - (room.FLOOR_Y + shift.y)) < 0.01,
		"the player starts on the moved floor: %s" % player.position)
	room.free()
	await physics(2)

	# Staged: the layer mirrored left to right in place, the marker with it.
	room = (load("res://game/rooms/wide.tscn") as PackedScene).instantiate()
	var flipped := room.get_node("Tiles") as Node2D
	flipped.scale = Vector2(-1, 1)
	flipped.position = Vector2(size.x, 0)
	var start_node := room.get_node("PlayerStart") as Node2D
	start_node.position.x = size.x - start_node.position.x
	root.add_child(room)
	player = room.player
	camera = room.camera
	var limits_flipped := Rect2i(camera.limit_left, camera.limit_top,
			camera.limit_right - camera.limit_left, camera.limit_bottom - camera.limit_top)
	check(limits_flipped == Rect2i(Vector2i.ZERO, Vector2i(size)),
		"mirroring the layer keeps the camera's limits on the room: %s" % limits_flipped)
	await physics(10)
	check(player.is_on_floor(), "the player starts on the mirrored floor: %s" % player.position)
	room.free()


func physics(count: int) -> void:
	for i: int in count:
		await physics_frame
