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

var target: Player
# 1 while the look-ahead point is right of the player, -1 while it is left.
var side := 1.0
# The furthest x the player has reached toward side.
var _furthest := 0.0


func _ready() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	drag_horizontal_enabled = true
	position_smoothing_enabled = true
	_apply_size()
	# Camera2D updates the view in its own physics step, which runs before this
	# script's, so the view would always trail the target set here by a step.
	# _physics_process updates it instead, once, after setting the target.
	set_physics_process_internal(false)
	_furthest = target.position.x
	position = Vector2(_look_ahead_x(), target.position.y - feet_below_centre)
	# Centres the view on the look-ahead point now. Camera2D's own first update ran as it
	# entered the tree, before this position, so until the next physics step
	# the view would sit at the room's top-left corner.
	align()
	reset_smoothing()
	force_update_scroll()


func _physics_process(_delta: float) -> void:
	_apply_size()
	position.x = _look_ahead_x()
	if target.is_on_floor():
		position.y = target.position.y - feet_below_centre
	else:
		# Holds the height the view shows now, so a jump taken while it is still
		# easing toward the last landing doesn't carry it on.
		position.y = get_screen_center_position().y
	force_update_scroll()


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
