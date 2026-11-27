extends Camera2D

# Follows the player in a room wider than the view. Camera2D does most of it:
# its drag margins are the camera window, which holds the view still while the
# player walks inside it and scrolls when they push against its edge; position
# smoothing glides toward the target; limits keep the room's edges on screen.
# This script adds the one rule Camera2D lacks: the height follows the player
# only when they stand on a floor, and holds still while they are in the air,
# so a jump doesn't move the view. Standing on a seesaw plank holds it too, so
# the view doesn't bob as the plank tilts. Once the feet drop below the camera
# window's bottom edge, window_bottom below the view's centre, the height
# follows them right away, so a long fall stays on screen. It also follows a look-ahead point in front
# of the player instead of the player, so the view shows more ahead than behind.
# The point changes sides only once the player has walked flip_distance back
# from the furthest point they reached, so a short turn doesn't swing the view.
#
# The room sets target and the limits before adding it, after the player, so
# each physics step it follows where the player has just moved.

const Player := preload("res://game/player.gd")
const Plank := preload("res://game/seesaw_plank.gd")

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
# How far below the view's centre the feet can drop while the height holds, in
# the air or on a plank: 80 px puts them at y 170 of the 180 view, 10 px lower
# than standing feet. Past it, the view follows the feet down at once.
@export var window_bottom := 80.0

var target: Player
# 1 while the look-ahead point is right of the player, -1 while it is left.
var side := 1.0
# The furthest x the player has reached toward side.
var _furthest := 0.0


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
	_furthest = target.position.x
	position = Vector2(_look_ahead_x(), _inside_limits(target.position.y - feet_below_centre))
	# Centres the view on the look-ahead point now. Camera2D's own first update ran as it
	# entered the tree, before this position, so until the next physics step
	# the view would sit at the room's top-left corner.
	align()
	reset_smoothing()
	force_update_scroll()


func _physics_process(delta: float) -> void:
	position.x = _look_ahead_x()
	var centre_y := get_screen_center_position().y
	var share := position_smoothing_speed * delta
	# Checked before the floor, as the step a fall lands can drop the feet
	# well past the line, and easing toward the standing height would trail.
	if target.position.y > centre_y + window_bottom and share > 0.0:
		# Smoothing moves the view `share` of the way to its target each
		# step, so aiming that much further puts the window's bottom edge on the
		# feet this step instead of trailing a fast fall.
		var wanted := _inside_limits(target.position.y - window_bottom)
		position.y = centre_y + (wanted - centre_y) / share
	elif target.is_on_floor() and not _on_plank():
		position.y = _inside_limits(target.position.y - feet_below_centre)
	else:
		# Holds the height the view shows now, so a jump taken while it is still
		# easing toward the last landing doesn't carry it on.
		position.y = centre_y
	force_update_scroll()


# Keeps a height the view eases toward inside the limits. Camera2D clamps only
# the view it shows, so a target past a limit would leave its eased position
# there, and a fall from there would trail by the difference.
func _inside_limits(y: float) -> float:
	var half := get_viewport_rect().size.y / 2.0
	return clampf(y, limit_top + half, limit_bottom - half)


func _on_plank() -> bool:
	var hit := KinematicCollision2D.new()
	return target.test_move(target.global_transform, -target.up_direction * target.floor_snap_length, hit) \
			and hit.get_collider() is Plank


func _look_ahead_x() -> float:
	var x := target.position.x
	if (x - _furthest) * side >= 0.0:
		_furthest = x
	elif (_furthest - x) * side >= flip_distance:
		side = -side
		_furthest = x
	return x + side * lerpf(small_look_ahead, big_look_ahead, target.t)
