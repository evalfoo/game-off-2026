extends "res://tools/clips/scenario.gd"

# The camera's pull in the wide room. A staged marker, a 16 px square six tiles
# above the floor left of the step, pulls the view half the way toward it with
# rings of 112 and 192 px; the room marks nothing itself. The player walks right
# into the step's side, waits, then walks back left out of the rings. The ref
# without pull_toward shows the same walk with the marker but no lean, so
# record both:
#
#   tools/clips/record.sh tools/clips/scenarios/camera_pull.gd

func run() -> void:
	game.free()
	game = (load("res://game/rooms/wide.tscn") as PackedScene).instantiate()
	root.add_child(game)
	var marker := ColorRect.new()
	marker.color = Color(0.9, 0.3, 0.3)
	marker.size = Vector2(16, 16)
	marker.position = Vector2(-8, -8)
	var spot := Node2D.new()
	spot.position = Vector2(330, 160)
	spot.add_child(marker)
	# The pixel view's rooms keep their world in game.view.world; the old base
	# keeps it in the room.
	var world: Node = game.view.world if "view" in game else game
	world.add_child(spot)
	var camera: Camera2D = game.get("camera")
	if camera.has_method("pull_toward"):
		camera.call("pull_toward", spot, 112.0, 192.0, 0.5)
	fixture("the wide room, small player, a staged pulling marker at (330, 160)")
	start_clip()
	await hold(0.3)
	strip(roundi(7.6 * FPS / 8.0), "walk right toward the marker, wait, walk back left")
	await _walk(KEY_RIGHT, 2.8, "walk right into the rings")
	mark("wait inside the inner ring")
	await hold(1.5)
	await _walk(KEY_LEFT, 2.4, "walk back left out of the rings")
	await hold(1.5)
	finish()


func _walk(key: Key, seconds: float, event: String) -> void:
	mark(event)
	Events.hold_key(key, true)
	await hold(seconds)
	Events.hold_key(key, false)
