extends SceneTree

# Base for clip scenarios recorded by tools/clips/record.sh, and for shot
# scripts run by tools/clips/stills.sh. A scenario extends this file, overrides
# run(), and ends with finish(). See scenarios/clicks.gd.
#
# record.sh copies this file and the scenario into each recorded worktree, so
# the helpers only use what the game has had for a while. The helpers print
# lines that record.sh reads from the log:
#
#   CLIP_START <frame>        start_clip(): frames before it are dropped
#   STRIP <frame> <step> ...  strip(): first strip frame, frames between shots, note
#   MARK <frame> <event>      mark(): timeline events listed in the clip README
#   FIXTURE <text>            fixture(): how the game was set up

const Fixture := preload("res://tests/lib/fixture.gd")
const Events := preload("res://tests/lib/events.gd")
const FPS := 30

var frame := 0
var game: Node
# record.sh and stills.sh pass --saves=<folder> and remove that folder on every
# exit. Run directly, saves go to user:// and only finish() removes them.
var directory := _arg("--saves=", "user://clip_recording_%d" % Time.get_ticks_usec())

func _initialize() -> void:
	call_deferred("_start")

func _process(_delta: float) -> bool:
	frame += 1
	return false

func _arg(prefix: String, default: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return default

func _start() -> void:
	game = Fixture.launch(root, directory)
	await hold(0.3)
	await run()

# Overridden by each scenario. The game scene is already running, with saves in
# an isolated folder that finish() removes.
func run() -> void:
	finish()

# Removes the test saves and quits. Every scenario must end with it, or Godot
# keeps recording until record.sh times out.
func finish() -> void:
	var absolute := ProjectSettings.globalize_path(directory)
	if DirAccess.dir_exists_absolute(absolute):
		for file: String in DirAccess.get_files_at(absolute):
			DirAccess.remove_absolute(absolute.path_join(file))
		DirAccess.remove_absolute(absolute)
	quit(0)

func fixture(text: String) -> void:
	print("FIXTURE ", text)

func start_clip() -> void:
	print("CLIP_START %d" % frame)

# The 8-frame strip takes every step-th frame. It starts one frame back,
# because input sent now already shows in this frame.
func strip(step: int = 3, note: String = "") -> void:
	print("STRIP %d %d %s" % [frame - 1, step, note])

func mark(event: String) -> void:
	print("MARK %d %s" % [frame, event])

func hold(seconds: float) -> void:
	for i: int in roundi(seconds * FPS):
		await process_frame

# Saves the window as <name>.png into the folder stills.sh passes as --out=<dir>.
func shot(name: String) -> void:
	var out := _arg("--out=", "res://tests/output/shots")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("SHOT ", out.path_join(name + ".png"))
