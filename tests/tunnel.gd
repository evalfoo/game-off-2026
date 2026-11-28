extends "res://tests/lib/test.gd"

# The tunnel level (game/levels/tunnel.tscn): a wall with a 1-tile-tall tunnel
# at floor level. The player grows only where big fits, where it stands.
#
# Played: the big player can't enter the tunnel, and touching the wall it still
# fits where it stands. The small one walks through
# at full speed. Holding Shift in the tunnel, under its low ceiling, keeps it
# small and in place, and with Shift still held it grows once it walks out far
# enough for big to fit. Beside the level's left wall, Shift keeps it small and
# it doesn't slide away from the wall to make room.
#
# Staged, with a ceiling painted over the start: big fits under a 3-tile
# ceiling, and a 2-tile ceiling keeps the player small.

const Tiles := preload("res://game/tiles.gd")

var level: Node2D
var player: CharacterBody2D
var floor_y := 0.0


func run() -> void:
	_load_level()
	var wall_left: float = level.WALL_FIRST * Tiles.TILE
	var wall_right: float = (level.WALL_LAST + 1) * Tiles.TILE
	var half_big: float = player.big_size.x / 2.0
	var step: float = player.small_speed / 60.0

	# Big walks into the wall and stops at it.
	Events.hold_key(KEY_SHIFT, true)
	await physics(60)
	check(player.t == 1.0, "away from the wall, holding Shift makes the player big: t %.2f" % player.t)
	Events.hold_key(KEY_RIGHT, true)
	await physics(240)
	check(player.t == 1.0 and player.position.x < wall_left - half_big + 0.5,
		"the big player is blocked by the wall: x %.2f, wall at %.0f" % [player.position.x, wall_left])

	# Touching the wall, big still fits: a short let-go and Shift again grow it back.
	Events.hold_key(KEY_RIGHT, false)
	await physics(10)
	var x := player.position.x
	Events.hold_key(KEY_SHIFT, false)
	await physics(5)
	var shrunk: float = player.t
	Events.hold_key(KEY_SHIFT, true)
	await physics(30)
	check(shrunk < 1.0 and player.t == 1.0 and absf(player.position.x - x) < 0.01,
		"touching the wall, the player grows back to big where it stands: t %.2f -> %.2f, x %.2f -> %.2f" % [
			shrunk, player.t, x, player.position.x])

	# Small walks in at full speed, from a run-up.
	Events.hold_key(KEY_SHIFT, false)
	await physics(30)
	Events.hold_key(KEY_LEFT, true)
	await physics(30)
	Events.hold_key(KEY_LEFT, false)
	Events.hold_key(KEY_RIGHT, true)
	var stalled := 0
	var last := player.position.x
	for i: int in 240:
		await physics(1)
		if player.t == 0.0 and player.position.x > wall_left - 8.0 and player.position.x - last < step - 0.01:
			stalled += 1
		last = player.position.x
		if player.position.x >= (wall_left + wall_right) / 2.0:
			break
	Events.hold_key(KEY_RIGHT, false)
	check(player.t == 0.0 and player.position.x >= (wall_left + wall_right) / 2.0 and stalled == 0,
		"the small player walks into the tunnel at full speed: x %.2f, %d slow steps" % [player.position.x, stalled])
	await physics(30)
	check(absf(player.position.y - floor_y) < 0.1 and player.is_on_floor(),
		"in the tunnel the small player stands on the floor: y %.2f" % player.position.y)

	# Shift under the tunnel's ceiling keeps it small and in place.
	x = player.position.x
	Events.hold_key(KEY_SHIFT, true)
	await physics(60)
	check(player.t == 0.0 and player.size == player.small_size and player.position.x == x,
		"holding Shift in the tunnel keeps the player small and in place: t %.2f, x %.2f -> %.2f" % [
			player.t, x, player.position.x])

	# Walking out with Shift held, it grows as soon as big fits.
	var grew_at := -1.0
	var jump := 0.0
	last = player.position.x
	Events.hold_key(KEY_RIGHT, true)
	for i: int in 240:
		await physics(1)
		# Where it stood when the step began, as it checks the fit then.
		if player.t > 0.0 and grew_at < 0.0:
			grew_at = last
		jump = maxf(jump, absf(player.position.x - last))
		last = player.position.x
		if player.t == 1.0:
			break
	Events.hold_key(KEY_RIGHT, false)
	await physics(30)
	var fits_at := wall_right + half_big
	check(grew_at >= fits_at - 0.5 and grew_at < fits_at + step + 0.5,
		"with Shift held, it starts growing once big fits beyond the wall: at x %.2f, fits from %.0f" % [grew_at, fits_at])
	check(jump <= step + 0.01, "it doesn't slide sideways as it grows: largest step %.2f px" % jump)
	check(player.t == 1.0 and player.is_on_floor() and absf(player.position.y - floor_y) < 0.1,
		"it ends big on the floor: t %.2f, y %.2f" % [player.t, player.position.y])
	Events.hold_key(KEY_SHIFT, false)
	level.free()
	await physics(2)

	# Beside the left wall, Shift keeps it small and it doesn't slide.
	_load_level()
	await physics(10)
	Events.hold_key(KEY_LEFT, true)
	await physics(120)
	Events.hold_key(KEY_LEFT, false)
	await physics(10)
	x = player.position.x
	check(x < half_big - 1.0, "the small player walks to the level's left wall: x %.2f" % x)
	Events.hold_key(KEY_SHIFT, true)
	await physics(60)
	check(player.t == 0.0 and player.position.x == x,
		"holding Shift beside the wall keeps the player small and in place: t %.2f, x %.2f -> %.2f" % [
			player.t, x, player.position.x])
	Events.hold_key(KEY_SHIFT, false)
	level.free()
	await physics(2)

	# Staged: ceilings painted over the start, 3 and 2 tiles above the floor.
	for rows: int in [3, 2]:
		_load_level(rows)
		await physics(10)
		Events.hold_key(KEY_SHIFT, true)
		await physics(60)
		if rows == 3:
			check(player.t == 1.0 and player.is_on_floor() and absf(player.position.y - floor_y) < 0.1,
				"staged: under a 3-tile ceiling the player grows big and stands on the floor: t %.2f, y %.2f" % [
					player.t, player.position.y])
		else:
			check(player.t == 0.0, "staged: under a 2-tile ceiling it stays small: t %.2f" % player.t)
		Events.hold_key(KEY_SHIFT, false)
		level.free()
		await physics(2)


# Loads the level; with ceiling_rows, paints a ceiling that many tiles above
# the floor, over the columns left of the wall.
func _load_level(ceiling_rows: int = 0) -> void:
	level = (load("res://game/levels/tunnel.tscn") as PackedScene).instantiate()
	if ceiling_rows > 0:
		var tiles: TileMapLayer = level.get_node("Tiles")
		var row: int = int(level.FLOOR_Y) / Tiles.TILE - ceiling_rows - 1
		for column: int in level.WALL_FIRST:
			tiles.set_cell(Vector2i(column, row), 0, Tiles.FILL)
	root.add_child(level)
	player = level.player
	floor_y = level.FLOOR_Y


func physics(count: int) -> void:
	for i: int in count:
		await physics_frame
