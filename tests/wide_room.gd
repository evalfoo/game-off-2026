extends "res://tests/lib/test.gd"

# The wide room's level comes from its scene (game/rooms/wide.tscn): the
# painted tiles end up in the pixel view's world at View/World/Tiles, the
# player starts at PlayerStart and stands on the floor, and the camera's limits
# are the tiles' bounds less the wall column on each side, which match the
# room's SIZE. Staged: an edit to the scene before it starts, the marker moved
# and a wall painted further right, shows up as a new start and right limit.

const Tiles := preload("res://game/tiles.gd")


func run() -> void:
	var room: Node2D = (load("res://game/rooms/wide.tscn") as PackedScene).instantiate()
	root.add_child(room)
	await physics(10)
	var player: CharacterBody2D = room.player
	var camera: Camera2D = room.camera
	var size: Vector2 = room.SIZE
	var tiles := room.get_node_or_null("View/World/Tiles") as TileMapLayer
	check(tiles != null and room.get_node_or_null("Tiles") == null,
		"the painted tiles move into the pixel view's world, at View/World/Tiles")
	check(player.is_on_floor() and player.position == Vector2(120, room.FLOOR_Y),
		"the player starts at PlayerStart, standing on the floor: %s" % player.position)
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


func physics(count: int) -> void:
	for i: int in count:
		await physics_frame
