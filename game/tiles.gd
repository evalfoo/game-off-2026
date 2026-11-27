extends RefCounted

# Builds a room's tiles from res://art/tiles.tres: solid floor from the floor's
# top edge to the bottom of the 320x180 view, and a wall in the column just
# outside each side of it.

const TILE_SET := preload("res://art/tiles.tres")
const TILE := 16
const COLUMNS := 20
# Atlas coordinates in res://art/tiles.png: a solid tile with its top exposed,
# and one with no side exposed.
const TOP := Vector2i(1, 0)
const FILL := Vector2i(1, 1)
const ROWS := 12


static func room(floor_y: float) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = "Tiles"
	layer.tile_set = TILE_SET
	var floor_row := int(floor_y) / TILE
	for row: int in ROWS:
		var columns: Array = range(-1, COLUMNS + 1) if row >= floor_row else [-1, COLUMNS]
		for column: int in columns:
			layer.set_cell(Vector2i(column, row), 0, TOP if row == floor_row else FILL)
	return layer
