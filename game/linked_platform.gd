extends StaticBody2D

# One platform of a linked pair (game/platform_pair.gd), which moves it with
# move_to(). It carries what stands on it.
#
# The player moves after it in the same step, so it must already be in its new
# place then, or the player trails it by a step. Hence a StaticBody2D, which
# the physics server moves at once, where it moves a kinematic body such as an
# AnimatableBody2D only at the end of the step, and force_update_transform(), as
# Godot otherwise passes a new position on only after every node's step.

# Whether the fully big player stood on it in the last step. The pair reads
# and clears it each step.
var big := false


# Called each step by what stands on it: game/player.gd, with its t.
func carry(t: float) -> void:
	if t >= 1.0:
		big = true


# Moves the platform's top to y now. Its constant_linear_velocity is this
# step's move, which a CharacterBody2D standing on it moves along with.
func move_to(y: float, delta: float) -> void:
	constant_linear_velocity = Vector2(0, (y - position.y) / delta)
	position.y = y
	force_update_transform()
