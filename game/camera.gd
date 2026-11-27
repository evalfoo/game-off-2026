extends Camera2D

# Follows the player in a room wider than the view. Camera2D does part of it:
# position smoothing glides toward the target; limits keep the room's edges on
# screen. The script keeps the camera window, which holds the view still while
# the player walks inside it and scrolls when they push against its edge. It
# keeps it rather than using Camera2D's drag margins, so a pull moves the view
# by its full amount instead of first crossing the window. The height follows the player
# only when they stand on a floor, and holds still while they are in the air,
# so a jump doesn't move the view. Once the feet drop below the camera
# window's bottom edge, window_bottom below the view's centre, the height
# follows them right away, so a long fall stays on screen. It also follows a look-ahead point in front
# of the player instead of the player, so the view shows more ahead than behind.
# The point changes sides only once the player has walked flip_distance back
# from the furthest point they reached, so a short turn doesn't swing the view.
# Holding Up or Down looks that way by look_distance, eased by the same
# smoothing, while the player stands on a floor. shake() shakes the view
# through Camera2D's offset, which the follow rules ignore.
# Objects the room marks with pull_toward draw the view partway toward them
# while the player is near.
#
# The room sets target and the limits before adding it, after the player, so
# each physics step it follows where the player has just moved.

const Player := preload("res://game/player.gd")
const FALL_TOLERANCE := 0.01
# How far below its standing height the player can be and still count as on
# that floor. A fall's first step drops it about 0.27 px.
const STAND_TOLERANCE := 0.1

# The camera window, smoothing and look-ahead each have a small and a big
# value, and blend between them as the player grows, by the player's t.
#
# Half the camera window's width, as a share of half the view's width: 0.2 is
# 32 px either side of the centre.
@export var small_window_margin := 0.2
@export var big_window_margin := 0.2
# How far above the player's feet the view's centre sits, so standing feet show
# at y 160 of the 180 view, as in the one-screen rooms.
@export var feet_below_centre := 70.0
@export var small_smoothing_speed := 5.0
@export var big_smoothing_speed := 5.0
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
# How far below the view's centre the feet can drop while the height holds in
# the air: 80 px puts them at y 170 of the 180 view, 10 px lower than standing
# feet. Past it, the view follows the feet down at once.
@export var window_bottom := 80.0
# How far Up or Down moves the view.
@export var look_distance := 48.0

var target: Player
# 1 while the look-ahead point is right of the player, -1 while it is left.
var side := 1.0
# The furthest x the player has reached toward side.
var _furthest := 0.0
# The camera window's centre x. It follows the look-ahead point only when that
# point reaches the window's edge.
var _window_x := 0.0
var _pulls: Array[Pull] = []
# How far above the standing height the view was on the last floor, and the
# feet's height there; see _physics_process.
var _lift := 0.0
var _stand_y := 0.0
# Seeds the shake's directions, so a run replays the same. The room sets it
# before adding the camera; the wide room keeps 0.
var rng_seed := 0
var _rng := RandomNumberGenerator.new()
# The current shake: its strength in px, its length in seconds and how long it
# has run.
var _shake_strength := 0.0
var _shake_length := 0.0
var _shake_time := 0.0


class Pull:
	var node: Node2D
	var inner_radius: float
	var outer_radius: float
	var share: float


func _ready() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	_apply_size()
	# Camera2D updates the view in its own physics step, which runs before this
	# script's, so the view would always trail the target set here by a step.
	# _physics_process updates it instead, once, after setting the target.
	set_physics_process_internal(false)
	_rng.seed = rng_seed
	_furthest = target.position.x
	_window_x = _look_ahead_x()
	var start := Vector2(_window_x, _inside_limits(target.position.y - feet_below_centre))
	position = _pulled(start)
	# A pull moves the height only on a floor, as in _physics_process, so a
	# start in the air keeps the ordinary height.
	if not target.is_on_floor():
		position.y = start.y
	# Centres the view on the look-ahead point now. Camera2D's own first update ran as it
	# entered the tree, before this position, so until the next physics step
	# the view would sit at the room's top-left corner.
	align()
	reset_smoothing()
	force_update_scroll()


# Shakes the view up to `strength` px from where it would be, fading to none
# over `length` seconds. A new shake replaces the current one; a length of 0
# stops it.
func shake(strength: float, length: float) -> void:
	_shake_strength = strength
	_shake_length = maxf(length, 0.0)
	_shake_time = 0.0


func _physics_process(delta: float) -> void:
	_apply_size()
	# Zoom 2 shows half as many world pixels, so the window is half as wide.
	var half_window := drag_right_margin * get_viewport_rect().size.x * 0.5 / zoom.x
	var ahead := _look_ahead_x()
	_window_x = clampf(_window_x, ahead - half_window, ahead + half_window)
	# The height a pull moves from: the look and the room's limits first.
	var floor_y := _inside_limits(target.position.y - feet_below_centre)
	var pulled := _pulled(Vector2(_window_x, floor_y))
	position.x = pulled.x
	# Where the view sits without the shake, which doesn't move where it goes.
	var centre_y := get_screen_center_position().y - offset.y
	var share := position_smoothing_speed * delta if position_smoothing_enabled else 1.0
	var standing := target.is_on_floor()
	# Looking up on a floor puts the feet below the view's centre by that much
	# more on purpose, and a jump holds the view there. Any drop below the
	# standing height is a fall, not looking, so it gets no such room. Both come
	# from the step before, as a landing's step finds the view far from the floor.
	var looked_up := _lift if target.position.y <= _stand_y + STAND_TOLERANCE else 0.0
	# Checked before the floor, as the step a fall lands can drop the feet
	# well past the line, and easing toward the standing height would trail.
	# The view's position can come back a hair off the line after a fall, and
	# FALL_TOLERANCE keeps that from counting as falling on.
	if target.position.y > centre_y + window_bottom + looked_up + FALL_TOLERANCE and share > 0.0:
		# Smoothing moves the view `share` of the way to its target each
		# step, so aiming that much further puts the window's bottom edge on the
		# feet this step instead of trailing a fast fall.
		var wanted := _inside_limits(target.position.y - window_bottom)
		position.y = centre_y + (wanted - centre_y) / share
	elif standing:
		# Clamped after the look, so a look from a floor near the room's edge
		# doesn't move the view off the edge.
		position.y = _pulled(Vector2(_window_x, _inside_limits(_look(target.position.y - feet_below_centre)))).y
	else:
		# Holds the height the view shows now, so a jump taken while it is still
		# easing toward the last landing doesn't carry it on.
		position.y = centre_y
	force_update_scroll()
	# Measured from where this step put the view, so the next step's fall check
	# allows for the look it made.
	if standing:
		_lift = maxf(floor_y - (get_screen_center_position().y - offset.y), 0.0)
		_stand_y = target.position.y
	# Zero-length steps, while the play driver stops time, leave the shake and
	# the seed's sequence alone.
	if delta > 0.0 and (_shake_length > 0.0 or offset != Vector2.ZERO):
		_shake_step(delta)


# The height `y` moved by Up or Down, but not past the room's edge, where the
# smoothing would carry on behind the limit and hold the view there for a while
# after the key is let go.
func _look(y: float) -> float:
	var looked := y + Input.get_axis("ui_up", "ui_down") * look_distance
	var half := get_viewport_rect().size.y / 2.0 / zoom.y
	return clampf(looked, minf(y, limit_top + half), maxf(y, limit_bottom - half))


# Moves the shake one step on, from where the view sits without it. Each step
# shows the shake at the time it starts, so even a one-step shake moves the
# view, and it ends on the first step at or past its length.
func _shake_step(delta: float) -> void:
	var shaken := Vector2.ZERO
	# Summed frame times can fall a hair short of the length they add up to.
	if _shake_time < _shake_length - 0.0001:
		var fade := 1.0 - _shake_time / _shake_length
		shaken = Vector2.from_angle(_rng.randf() * TAU) * _shake_strength * fade
		_shake_time += delta
	else:
		_shake_length = 0.0
	# Camera2D adds offset after its limits, so the shake is kept inside them
	# here: each axis gives up what would pass the room's edge.
	var base := get_screen_center_position() - offset
	var half := get_viewport_rect().size / 2.0 / zoom
	var low := Vector2(limit_left, limit_top) + half
	var high := Vector2(limit_right, limit_bottom) - half
	var centre := (base + shaken).clamp(low.min(base), high.max(base))
	# Shows the new offset without a second smoothing step: Camera2D's update
	# eases position_smoothing_speed × delta of the way on each call. Setting
	# the speed turns Camera2D's own physics update back on, which _ready()
	# turned off.
	var speed := position_smoothing_speed
	position_smoothing_speed = 0.0
	offset = centre - base
	force_update_scroll()
	position_smoothing_speed = speed
	set_physics_process_internal(false)


# Sets the camera window and smoothing for the player's size.
func _apply_size() -> void:
	var margin := lerpf(small_window_margin, big_window_margin, target.t)
	# Camera2D's drag margins hold the window's size for the script's own
	# window; drag_horizontal_enabled stays off, so Camera2D doesn't use them.
	drag_left_margin = margin
	drag_right_margin = margin
	var speed := lerpf(small_smoothing_speed, big_smoothing_speed, target.t)
	# A speed of 0 turns smoothing off; Camera2D would otherwise never move.
	position_smoothing_enabled = speed > 0.0
	position_smoothing_speed = speed
	# Setting the smoothing speed turns Camera2D's own physics update back on;
	# _physics_process updates the view instead (see _ready).
	set_physics_process_internal(false)


# Keeps a height the view eases toward inside the limits. Camera2D clamps only
# the view it shows, so a target past a limit would leave its eased position
# there, and a fall from there would trail by the difference.
func _inside_limits(y: float) -> float:
	var half := get_viewport_rect().size.y / 2.0
	return clampf(y, limit_top + half, limit_bottom - half)


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
	# The parent's place in the world. A room's world sits in a SubViewport,
	# which isn't a Node2D and puts the camera at the world's origin.
	var parent := get_parent() as Node2D
	var frame := parent.global_transform if parent else Transform2D.IDENTITY
	for pull: Pull in _pulls:
		if not is_instance_valid(pull.node):
			continue
		var at := frame.affine_inverse() * pull.node.global_position
		var blend := inverse_lerp(pull.outer_radius, pull.inner_radius, target.position.distance_to(at))
		var strength := pull.share * clampf(blend, 0.0, 1.0)
		if strength > amount:
			amount = strength
			toward = at
	if amount == 0.0:
		return point
	# The limits are in world space, and point is in the parent's. The pulled
	# point stays inside them too: Camera2D clamps only the view it shows, so a
	# target past a limit would leave the eased position there, and the view
	# would wait at the edge after the pull or a fall moves it away.
	var half_view := get_viewport_rect().size * 0.5 / zoom
	var low := Vector2(limit_left, limit_top) + half_view
	var high := Vector2(limit_right, limit_bottom) - half_view
	var resting := frame.affine_inverse() * (frame * point).clamp(low, high)
	return frame.affine_inverse() * (frame * resting.lerp(toward, amount)).clamp(low, high)
