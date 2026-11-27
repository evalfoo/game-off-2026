extends CharacterBody2D

# A box with custom physics: it falls with gravity and moves sideways only when
# something pushes it. game/player.gd decides whether the player is heavy
# enough to push it.

@export var mass := 1.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")


# Moves the box sideways by offset_x now, short of anything in the way.
func push(offset_x: float) -> void:
	move_and_collide(Vector2(offset_x, 0))


func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return
	velocity.x = 0.0
	velocity.y += gravity * delta
	# Only a push moves it sideways. Stepping out of a box pressed against it
	# would let a push carry on through to that box.
	var x := position.x
	move_and_slide()
	position.x = x
