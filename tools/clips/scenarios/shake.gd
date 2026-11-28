extends "res://tools/clips/scenario.gd"

# Screen shake in the wide level: a 4 px shake for 0.5 s while the player
# stands, then a 6 px shake for 1 s while they walk right and jump, then a 4 px
# shake while Down holds the view at the level's bottom edge. Nothing in
# the game shakes yet, so the scenario calls the camera's shake(). On a ref
# without shake() the player moves the same and the view doesn't shake, so
# record both:
#
#   tools/clips/record.sh tools/clips/scenarios/shake.gd

func run() -> void:
	game.free()
	game = (load("res://game/levels/wide.tscn") as PackedScene).instantiate()
	root.add_child(game)
	fixture("the wide level, small player; the scenario calls camera.shake()")
	var camera: Camera2D = game.get("camera")
	start_clip()
	await hold(0.3)
	strip(18, "a 4 px shake standing, a 6 px shake walking and jumping, a 4 px shake at the level's bottom edge")
	mark("shake 4 px for 0.5 s")
	_shake(camera, 4.0, 0.5)
	await hold(1.0)
	mark("shake 6 px for 1 s, walk right and jump")
	_shake(camera, 6.0, 1.0)
	Events.hold_key(KEY_RIGHT, true)
	Events.hold_key(KEY_SPACE, true)
	await hold(0.3)
	Events.hold_key(KEY_SPACE, false)
	await hold(1.0)
	Events.hold_key(KEY_RIGHT, false)
	await hold(0.5)
	mark("hold Down to the level's bottom edge")
	Events.hold_key(KEY_DOWN, true)
	await hold(1.0)
	mark("shake 4 px for 0.5 s at the edge")
	_shake(camera, 4.0, 0.5)
	await hold(0.8)
	Events.hold_key(KEY_DOWN, false)
	finish()


func _shake(camera: Camera2D, strength: float, length: float) -> void:
	if camera.has_method("shake"):
		camera.call("shake", strength, length)
