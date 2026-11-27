extends Camera2D

# Follows the player in a room wider than the view. Camera2D does part of it:
# position smoothing glides toward the target; limits keep the room's edges on
# screen. The script keeps the camera window, which holds the view still while
# the player walks inside it and scrolls when they push against its edge. It
# keeps it rather than using Camera2D's drag margins, so a pull moves
# the view by its full amount instead of first crossing the window.
# The view's height follows the player
# only when they stand on a floor, and holds still while they are in the air,
# so a jump doesn't move the view. The window follows a look-ahead point in front
# of the player instead of the player, so the view shows more ahead than behind.
# The point changes sides only once the player has walked flip_distance back
# from the furthest point they reached, so a short turn doesn't swing the view.
# Objects the room marks with pull_toward draw the view partway toward them
# while the player is near.
#
# The room sets target and the limits before adding it, after the player, so
# each physics step it follows where the player has just moved.

const Player := preload("res://game/player.gd")

# Half the camera window's width, as a share of half the view's width: 0.2 is
# 32 px either side of the centre.
@export var window_margin := 0.2
# How far above the player's feet the view's centre sits, so standing feet show
# at y 160 of the 180 view, as in the one-screen rooms.
@export var feet_below_centre := 70.0
@export var smoothing_speed := 5.0
# How far in front of the player the look-ahead point sits: a quarter of the
# view's width when small, less when big, as the big player walks slower. Less
# the window's half width, it is how far ahead of the player the view's centre
# settles once they stop after walking: 48 px small, 16 px big.
@export var small_look_ahead := 80.0
@export var big_look_ahead := 48.0
# How far the player walks back from the furthest point they reached before
# the look-ahead point changes sides. A shorter turn keeps the point on its
# side.
@export var flip_distance := 32.0

var target: Player
# 1 while the look-ahead point is right of the player, -1 while it is left.
var side := 1.0
# The furthest x the player has reached toward side.
var _furthest := 0.0
# The camera window's centre x. It follows the look-ahead point only when that
# point reaches the window's edge.
var _window_x := 0.0
var _pulls: Array[Pull] = []


class Pull:
	var node: Node2D
	var inner_radius: float
	var outer_radius: float
	var share: float


func _ready() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	position_smoothing_enabled = true
	position_smoothing_speed = smoothing_speed
	# Camera2D updates the view in its own physics step, which runs before this
	# script's, so the view would always trail the target set here by a step.
	# _physics_process updates it instead, once, after setting the target.
	set_physics_process_internal(false)
	_furthest = target.position.x
	_window_x = _look_ahead_x()
	position = _pulled(Vector2(_window_x, target.position.y - feet_below_centre))
	# Centres the view on the look-ahead point now. Camera2D's own first update ran as it
	# entered the tree, before this position, so until the next physics step
	# the view would sit at the room's top-left corner.
	align()
	reset_smoothing()
	force_update_scroll()


func _physics_process(_delta: float) -> void:
	# Zoom 2 shows half as many world pixels, so the window is half as wide.
	var half_window := window_margin * get_viewport_rect().size.x * 0.5 / zoom.x
	var ahead := _look_ahead_x()
	_window_x = clampf(_window_x, ahead - half_window, ahead + half_window)
	var pulled := _pulled(Vector2(_window_x, target.position.y - feet_below_centre))
	position.x = pulled.x
	if target.is_on_floor():
		position.y = pulled.y
	else:
		# Holds the height the view shows now, so a jump taken while it is still
		# easing toward the last landing doesn't carry it on.
		position.y = get_screen_center_position().y
	force_update_scroll()


func _look_ahead_x() -> float:
	var x := target.position.x
	if (x - _furthest) * side >= 0.0:
		_furthest = x
	elif (_furthest - x) * side >= flip_distance:
		side = -side
		_furthest = x
	return x + side * lerpf(small_look_ahead, big_look_ahead, target.t)


# Marks node as pulling the view toward it. While the player's feet are
# outer_radius or more from it, it doesn't pull; at inner_radius or closer, the
# view's target moves share of the way from where it would be to the node;
# between the two the pull blends in with the distance. inner_radius must be
# less than outer_radius. Where pulls overlap, the strongest one counts.
func pull_toward(node: Node2D, inner_radius: float, outer_radius: float, share: float) -> void:
	var pull := Pull.new()
	pull.node = node
	pull.inner_radius = inner_radius
	pull.outer_radius = outer_radius
	pull.share = share
	_pulls.append(pull)


# Moves point toward the strongest pull at the player's distance from it. The
# move starts from where the room's limits let the view rest, not from point,
# which can lie past a room edge. From there, a pull back into the room could
# end short of the edge and not move the view at all.
func _pulled(point: Vector2) -> Vector2:
	var toward := point
	var amount := 0.0
	for pull: Pull in _pulls:
		if not is_instance_valid(pull.node):
			continue
		var at := (get_parent() as Node2D).to_local(pull.node.global_position)
		var blend := inverse_lerp(pull.outer_radius, pull.inner_radius, target.position.distance_to(at))
		var strength := pull.share * clampf(blend, 0.0, 1.0)
		if strength > amount:
			amount = strength
			toward = at
	if amount == 0.0:
		return point
	# The limits are in world space, and point is in the parent's.
	var parent := get_parent() as Node2D
	var world := parent.to_global(point)
	var half_view := get_viewport_rect().size * 0.5 / zoom
	var resting := parent.to_local(Vector2(
		clampf(world.x, limit_left + half_view.x, limit_right - half_view.x),
		clampf(world.y, limit_top + half_view.y, limit_bottom - half_view.y)))
	return resting.lerp(toward, amount)
