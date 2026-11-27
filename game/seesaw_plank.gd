extends AnimatableBody2D

# A seesaw plank with custom physics, turning on its origin. Each step it turns
# toward the side with the larger mass x distance from the pivot, counting its
# fixed counterweight and whatever stood on it the step before, until an end
# rests on the floor at max_angle.

@export var max_angle := 0.2
# Radians per second.
@export var turn_speed := 1.0
# Mass and plank-local x of the weight fixed to the plank.
@export var counterweight_mass := 0.0
@export var counterweight_x := 0.0

var _load := 0.0


# Called each step by what stands on the plank, such as the player.
func carry(mass: float, global_x: float) -> void:
	_load += mass * (global_x - global_position.x)


func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return
	var torque := counterweight_mass * counterweight_x + _load
	_load = 0.0
	if torque != 0.0:
		rotation = move_toward(rotation, signf(torque) * max_angle, turn_speed * delta)
