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
	drag_left_margin = window_margin
	drag_right_margin = window_margin
	position_smoothing_enabled = true
	position_smoothing_speed = smoothing_speed
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
# over `length` seconds. A new shake replaces the current one.
func shake(strength: float, length: float) -> void:
	_shake_strength = strength
	_shake_length = length
	_shake_time = 0.0


func _physics_process(delta: float) -> void:
	position.x = _look_ahead_x()
	if target.is_on_floor():
		position.y = _look(target.position.y - feet_below_centre)
	else:
		# Holds the height the view shows now, so a jump taken while it is still
		# easing toward the last landing doesn't carry it on.
		position.y = get_screen_center_position().y - offset.y
	_shake_step(delta)
	force_update_scroll()


# The height `y` moved by Up or Down, but not past the room's edge, where the
# smoothing would carry on behind the limit and hold the view there for a while
# after the key is let go.
func _look(y: float) -> float:
	var looked := y + Input.get_axis("ui_up", "ui_down") * look_distance
	var half := get_viewport_rect().size.y / 2.0 / zoom.y
	return clampf(looked, minf(y, limit_top + half), maxf(y, limit_bottom - half))


# Moves the shake one step on. Zero-length steps, while the play driver stops
# time, leave it and the seed's sequence alone.
func _shake_step(delta: float) -> void:
	if _shake_length <= 0.0 or delta <= 0.0:
		return
	_shake_time += delta
	# Summed frame times can fall a hair short of the length they add up to.
	if _shake_time >= _shake_length - 0.0001:
		_shake_length = 0.0
		offset = Vector2.ZERO
		return
	var fade := 1.0 - _shake_time / _shake_length
	offset = Vector2.from_angle(_rng.randf() * TAU) * _shake_strength * fade


func _look_ahead_x() -> float:
	var x := target.position.x
	if (x - _furthest) * side >= 0.0:
		_furthest = x
	elif (_furthest - x) * side >= flip_distance:
		side = -side
		_furthest = x
	return x + side * lerpf(small_look_ahead, big_look_ahead, target.t)
