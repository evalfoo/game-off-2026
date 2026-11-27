extends Camera2D

# Follows the player in a room wider than the view. Camera2D does most of it:
# its drag margins are the camera window, which holds the view still while the
# player walks inside it and scrolls when they push against its edge; position
# smoothing glides toward the target; limits keep the room's edges on screen.
# This script adds the one rule Camera2D lacks: the height follows the player
# only when they stand on a floor, and holds still while they are in the air,
# so a jump doesn't move the view. It also follows a look-ahead point in front
# of the player instead of the player, so the view shows more ahead than behind.
# The point changes sides only once the player has walked flip_distance back
# from the furthest point they reached, so a short turn doesn't swing the view.
# Holding Up or Down looks that way by look_distance, eased by the same
# smoothing, while the player stands on a floor. shake() shakes the view
# through Camera2D's offset, which the follow rules ignore.
#
# The room sets target and the limits before adding it, after the player, so
# each physics step it follows where the player has just moved.

const Player := preload("res://game/player.gd")

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
# How far Up or Down moves the view.
@export var look_distance := 48.0

var target: Player
# 1 while the look-ahead point is right of the player, -1 while it is left.
var side := 1.0
# The furthest x the player has reached toward side.
var _furthest := 0.0
# Seeds the shake's directions, so a run replays the same. The room sets it
# before adding the camera; the wide room keeps 0.
var rng_seed := 0
var _rng := RandomNumberGenerator.new()
# The current shake: its strength in px, its length in seconds and how long it
# has run.
var _shake_strength := 0.0
var _shake_length := 0.0
var _shake_time := 0.0


func _ready() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	drag_horizontal_enabled = true
	position_smoothing_enabled = true
	_apply_size()
	# Camera2D updates the view in its own physics step, which runs before this
	# script's, so the view would always trail the target set here by a step.
	# _physics_process updates it instead, once, after setting the target.
	set_physics_process_internal(false)
	_rng.seed = rng_seed
	_furthest = target.position.x
	position = Vector2(_look_ahead_x(), target.position.y - feet_below_centre)
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
	position.x = _look_ahead_x()
	if target.is_on_floor():
		position.y = _look(target.position.y - feet_below_centre)
	else:
		# Holds the height the view shows now, so a jump taken while it is still
		# easing toward the last landing doesn't carry it on.
		position.y = get_screen_center_position().y - offset.y
	force_update_scroll()
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
	drag_left_margin = margin
	drag_right_margin = margin
	position_smoothing_speed = lerpf(small_smoothing_speed, big_smoothing_speed, target.t)
	# Setting the smoothing speed turns Camera2D's own physics update back on;
	# _physics_process updates the view instead (see _ready).
	set_physics_process_internal(false)


func _look_ahead_x() -> float:
	var x := target.position.x
	if (x - _furthest) * side >= 0.0:
		_furthest = x
	elif (_furthest - x) * side >= flip_distance:
		side = -side
		_furthest = x
	return x + side * lerpf(small_look_ahead, big_look_ahead, target.t)
