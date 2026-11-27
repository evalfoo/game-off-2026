extends RigidBody2D

# Holding Shift eases the player from the small state to the big state: bigger,
# heavier, slower and a lower jump.
# Releasing eases back. The origin sits at the feet, so growth goes upward.

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

var t := 0.0
var speed := small_speed
var jump_speed := small_jump_speed
var shape := RectangleShape2D.new()
var collision := CollisionShape2D.new()
var jump_requested := false


func _ready() -> void:
	lock_rotation = true
	can_sleep = false
	contact_monitor = true
	max_contacts_reported = 8
	# Movement sets velocity directly, so floor friction would only eat speed.
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.0
	collision.shape = shape
	add_child(collision)
	_apply_size()


func _physics_process(delta: float) -> void:
	var target := 1.0 if Input.is_key_pressed(KEY_SHIFT) else 0.0
	t = move_toward(t, target, delta / transition_time)
	_apply_size()
	if Input.is_action_just_pressed("ui_accept"):
		jump_requested = true


func _apply_size() -> void:
	var size := small_size.lerp(big_size, t)
	shape.size = size
	collision.position = Vector2(0, -size.y / 2)
	mass = lerpf(small_mass, big_mass, t)
	speed = lerpf(small_speed, big_speed, t)
	jump_speed = lerpf(small_jump_speed, big_jump_speed, t)
	queue_redraw()


func _draw() -> void:
	var size := shape.size
	draw_rect(Rect2(-size.x / 2, -size.y, size.x, size.y), Color.WHITE)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var dir := Input.get_axis("ui_left", "ui_right")
	var v := state.linear_velocity
	v.x = lerpf(v.x, dir * speed, clampf(accel * state.step, 0.0, 1.0))
	if jump_requested and _on_floor(state):
		v.y = -jump_speed
	jump_requested = false
	state.linear_velocity = v


func _on_floor(state: PhysicsDirectBodyState2D) -> bool:
	for i: int in state.get_contact_count():
		if state.get_contact_local_normal(i).dot(Vector2.UP) > 0.5:
			return true
	return false
