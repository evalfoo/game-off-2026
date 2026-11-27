extends RefCounted

# Builds a room's tiles from res://art/tiles.tres: solid floor from the floor's
# top edge to the room's bottom, and a wall in the column just outside each
# side of it. A room is one 320x180 view unless it gives its own columns and
# rows.

const TILE_SET := preload("res://art/tiles.tres")
const TILE := 16
const COLUMNS := 20
# Atlas coordinates in res://art/tiles.png: a solid tile with its top exposed,
# and one with no side exposed.
const TOP := Vector2i(1, 0)
const FILL := Vector2i(1, 1)
# A one-tile-thick platform's left end, middle and right end.
const PLATFORM_LEFT := Vector2i(0, 3)
const PLATFORM_MIDDLE := Vector2i(1, 3)
const PLATFORM_RIGHT := Vector2i(2, 3)
const ROWS := 12


static func room(floor_y: float, columns: int = COLUMNS, rows: int = ROWS) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = "Tiles"
	layer.tile_set = TILE_SET
	var floor_row := int(floor_y) / TILE
	for row: int in rows:
		var row_columns: Array = range(-1, columns + 1) if row >= floor_row else [-1, columns]
		for column: int in row_columns:
			layer.set_cell(Vector2i(column, row), 0, TOP if row == floor_row else FILL)
	return layer


# A one-tile-thick platform in `row`, from column `first` to `last`.
static func platform(layer: TileMapLayer, row: int, first: int, last: int) -> void:
	for column: int in range(first, last + 1):
		var tile := PLATFORM_MIDDLE
		if column == first:
			tile = PLATFORM_LEFT
		elif column == last:
			tile = PLATFORM_RIGHT
		layer.set_cell(Vector2i(column, row), 0, tile)
