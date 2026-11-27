extends Camera2D

# Follows the player in a room wider than the view. Camera2D does most of it:
# its drag margins are the camera window, which holds the view still while the
# player walks inside it and scrolls when they push against its edge; position
# smoothing glides toward the target; limits keep the room's edges on screen.
# This script adds the one rule Camera2D lacks: the height follows the player
# only when they stand on a floor, and holds still while they are in the air,
# so a jump doesn't move the view.
#
# The room sets target and the limits before adding it, after the player, so
# each physics step it follows where the player has just moved.

# Half the camera window's width, as a share of half the view's width: 0.2 is
# 32 px either side of the centre.
@export var window_margin := 0.2
# How far above the player's feet the view's centre sits, so standing feet show
# at y 160 of the 180 view, as in the one-screen rooms.
@export var feet_below_centre := 70.0
@export var smoothing_speed := 5.0

var target: CharacterBody2D


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
	position = target.position - Vector2(0, feet_below_centre)
	# Centres the view on the player now. Camera2D's own first update ran as it
	# entered the tree, before this position, so until the next physics step
	# the view would sit at the room's top-left corner.
	align()
	reset_smoothing()
	force_update_scroll()


func _physics_process(_delta: float) -> void:
	position.x = target.position.x
	if target.is_on_floor():
		position.y = target.position.y - feet_below_centre
	else:
		# Holds the height the view shows now, so a jump taken while it is still
		# easing toward the last landing doesn't carry it on.
		position.y = get_screen_center_position().y
	force_update_scroll()
