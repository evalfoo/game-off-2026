extends Node2D

# Two platforms joined by a rope: a pulley wheel sits above each, and a rope
# across the top joins the wheels. While the fully big player (t = 1) stands on
# one platform, it sinks to its stop, travel below level, and the other rises
# as far. Otherwise both slide back to level. The small player moves nothing.
#
# Place game/platform_pair.tscn in a room. Left and Right are level where the
# scene puts them. The wheels and ropes are placeholder art and don't collide;
# each rope runs from its wheel's centre to its platform, wherever the wheels
# are placed.

const LinkedPlatform := preload("res://game/linked_platform.gd")

# How far each platform moves from level to its stop, in px.
@export var travel := 48.0
# How fast a platform sinks under the big player, and the other rises, in px
# per second. Placeholder.
@export var sink_speed := 60.0
# How fast both slide back to level once the big player leaves or shrinks, in
# px per second. Placeholder.
@export var return_speed := 40.0

# How far Left sits below level. Right sits as far above it.
var offset := 0.0

@onready var left: LinkedPlatform = $Left
@onready var right: LinkedPlatform = $Right
@onready var _left_rope: Line2D = $LeftRope
@onready var _right_rope: Line2D = $RightRope
@onready var _left_wheel: Node2D = $LeftWheel
@onready var _right_wheel: Node2D = $RightWheel
var _left_level := 0.0
var _right_level := 0.0


func _ready() -> void:
	_left_level = left.position.y
	_right_level = right.position.y
	_update_ropes()


func _physics_process(delta: float) -> void:
	# The play driver's pause runs zero-length frames.
	if delta <= 0.0:
		return
	# The player reports standing on a platform after it moves, so these hold
	# what it stood on in the last step.
	var aim := 0.0
	if left.big:
		aim = travel
	elif right.big:
		aim = -travel
	left.big = false
	right.big = false
	var speed := return_speed if aim == 0.0 else sink_speed
	offset = move_toward(offset, aim, speed * delta)
	left.move_to(_left_level + offset, delta)
	right.move_to(_right_level - offset, delta)
	_update_ropes()


func _update_ropes() -> void:
	_left_rope.points = PackedVector2Array([_left_wheel.position, left.position])
	_right_rope.points = PackedVector2Array([_right_wheel.position, right.position])
