extends SceneTree

# Base for test scripts. A test extends this file, overrides run() and calls
# check() for each claim; it exits 1 when any check failed. tests/run.sh also
# fails it on a SCRIPT ERROR line, because Godot often exits 0 after one.

const Fixture := preload("res://tests/lib/fixture.gd")
const Events := preload("res://tests/lib/events.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	await run()
	quit(1 if failures > 0 else 0)

func run() -> void:
	pass

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		failures += 1
		printerr("FAIL ", label)

func frames(count: int) -> void:
	for i: int in count:
		await process_frame
