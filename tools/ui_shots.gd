extends "res://tools/clips/scenario.gd"

# The default shot script for tools/clips/stills.sh: the screens a UI change
# usually touches, on a fixed fixture.
#
#   mise exec -- tools/native.sh godot --path . --resolution 1440x900 --script tools/ui_shots.gd -- --out=<folder>
#
# TODO(template): add a shot for each main screen as the game grows.

func run() -> void:
	await hold(0.2)
	await shot("main")
	finish()
