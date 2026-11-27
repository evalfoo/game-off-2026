extends CharacterBody2D

# Holding Shift eases the player from the small state to the big state: bigger,
# heavier, slower and a lower jump.
# Releasing eases back. The origin sits at the feet, so growth goes upward.
#
# Custom physics: the code moves the player, and its weight is code too. It
# pushes the boxes it walks into (game/box.gd) and weighs down the seesaw plank
# it stands on (game/seesaw_plank.gd).

@export var small_size := Vector2(10, 16)
@export var big_size := Vector2(30, 48)
@export var small_mass := 1.0
@export var big_mass := 10.0
@export var small_speed := 100.0
@export var big_speed := 100.0 / 3.0
@export var transition_time := 0.4
# Seconds to reach full speed from standing, and to stop or turn from full
# speed.
@export var accel_time := 0.1
@export var decel_time := 0.05
@export var small_jump_speed := 167.0
# Half the small jump's height: the height goes with the speed squared.
@export var big_jump_speed := 118.0
# Falling pulls harder than rising, and rising with jump let go harder still,
# so a short press makes a short jump.
@export var fall_gravity_scale := 2.0
@export var jump_cut_gravity_scale := 3.0
# A jump still works this long after walking off an edge, and a press this
# long before landing jumps on landing. Seconds.
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.1
# The player pushes boxes up to this many times its mass: small moves BOX A
# (mass 2), big moves BOX B (mass 8).
@export var push_ratio := 3.0

var t := 0.0
var mass := small_mass
var speed := small_speed
var jump_speed := small_jump_speed
var shape := RectangleShape2D.new()
var collision := CollisionShape2D.new()
# Drawn at small_size. Growing stretches it.
var sprite := Sprite2D.new()
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _coyote := 0.0
var _jump_buffer := 0.0


func _ready() -> void:
	floor_stop_on_slope = true
	collision.shape = shape
	add_child(collision)
	sprite.texture = preload("res://art/player.png")
	sprite.centered = false
	add_child(sprite)
	_apply_size()


func _physics_process(delta: float) -> void:
	# A jump pressed during a pause still counts once time runs.
	if Input.is_action_just_pressed("ui_accept"):
		_jump_buffer = jump_buffer_time
	# The play driver's pause runs zero-length frames.
	if delta <= 0.0:
		return
	var target := 1.0 if Input.is_key_pressed(KEY_SHIFT) else 0.0
	t = move_toward(t, target, delta / transition_time)
	_apply_size()

	var dir := Input.get_axis("ui_left", "ui_right")
	var stopping := dir == 0.0 or dir * velocity.x < 0.0
	var rate := speed / (decel_time if stopping else accel_time)
	velocity.x = move_toward(velocity.x, dir * speed, rate * delta)

	var jump_held := Input.is_action_pressed("ui_accept")
	var gravity_scale := 1.0
	if velocity.y > 0.0:
		gravity_scale = fall_gravity_scale
	elif not jump_held:
		gravity_scale = jump_cut_gravity_scale
	velocity.y += gravity * gravity_scale * delta

	_coyote = coyote_time if is_on_floor() else _coyote - delta
	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = -jump_speed
		_coyote = 0.0
		_jump_buffer = 0.0
	_jump_buffer -= delta
	_push_ahead(velocity.x * delta)
	move_and_slide()
	_carry()


func _apply_size() -> void:
	var size := small_size.lerp(big_size, t)
	shape.size = size
	collision.position = Vector2(0, -size.y / 2)
	sprite.scale = size / sprite.texture.get_size()
	sprite.position = Vector2(-size.x / 2, -size.y)
	mass = lerpf(small_mass, big_mass, t)
	speed = lerpf(small_speed, big_speed, t)
	jump_speed = lerpf(small_jump_speed, big_jump_speed, t)


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
