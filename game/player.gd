extends CharacterBody2D

# Holding Shift eases the player from the small state to the big state: bigger,
# heavier, slower and a lower jump.
# Releasing eases back. The origin sits at the feet, so growth goes upward.
#
# Custom physics: the code moves the player, and its weight is code too. It
# pushes the boxes it walks into (game/box.gd) and weighs down the seesaw plank
# it stands on (game/seesaw_plank.gd).

@export var small_size := Vector2(32, 48)
@export var big_size := Vector2(96, 144)
@export var small_mass := 1.0
@export var big_mass := 10.0
@export var small_speed := 300.0
@export var big_speed := 100.0
@export var transition_time := 0.4
@export var accel := 12.0
@export var small_jump_speed := 500.0
# Half the small jump's height: the height goes with the speed squared.
@export var big_jump_speed := 354.0
# The player pushes boxes up to this many times its mass: small moves BOX A
# (mass 2), big moves BOX B (mass 8).
@export var push_ratio := 3.0

var t := 0.0
var mass := small_mass
var speed := small_speed
var jump_speed := small_jump_speed
var shape := RectangleShape2D.new()
var collision := CollisionShape2D.new()
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")


func _ready() -> void:
	floor_stop_on_slope = true
	collision.shape = shape
	add_child(collision)
	_apply_size()


func _physics_process(delta: float) -> void:
	# The play driver's pause runs zero-length frames.
	if delta <= 0.0:
		return
	var target := 1.0 if Input.is_key_pressed(KEY_SHIFT) else 0.0
	t = move_toward(t, target, delta / transition_time)
	_apply_size()

	var dir := Input.get_axis("ui_left", "ui_right")
	velocity.x = lerpf(velocity.x, dir * speed, clampf(accel * delta, 0.0, 1.0))
	velocity.y += gravity * delta
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = -jump_speed
	_push_ahead(velocity.x * delta)
	move_and_slide()
	_carry()


func _apply_size() -> void:
	var size := small_size.lerp(big_size, t)
	shape.size = size
	collision.position = Vector2(0, -size.y / 2)
	mass = lerpf(small_mass, big_mass, t)
	speed = lerpf(small_speed, big_speed, t)
	jump_speed = lerpf(small_jump_speed, big_jump_speed, t)
	queue_redraw()


# Moves the box in the way first, if the player is heavy enough, so the
# player walks on at full speed in the same step.
func _push_ahead(offset_x: float) -> void:
	var hit := KinematicCollision2D.new()
	if offset_x == 0.0 or not test_move(global_transform, Vector2(offset_x, 0), hit):
		return
	var body := hit.get_collider()
	if body.has_method("push") and float(body.get("mass")) <= mass * push_ratio:
		body.call("push", offset_x)


# Weighs down what the player stands on. It looks for the floor just below,
# because a floor that snapping holds the player to records no slide collision.
func _carry() -> void:
	var hit := KinematicCollision2D.new()
	if not is_on_floor() or not test_move(global_transform, -up_direction * floor_snap_length, hit):
		return
	var body := hit.get_collider()
	if body.has_method("carry"):
		body.call("carry", mass, global_position.x)


func _draw() -> void:
	var size := shape.size
	draw_rect(Rect2(-size.x / 2, -size.y, size.x, size.y), Color.WHITE)
