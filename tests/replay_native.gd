extends "res://tests/lib/test.gd"

# Replays each recorded session under tests/sessions/ through
# tools/play_driver.gd --replay, which passes when every turn matches. Then
# replays one with a turn edited by hand, which fails at that turn and names
# the field. Each replay runs in its own Godot, through tools/native.sh.

# The folder of the last replay's new turns.
var _last_out := ""

func run() -> void:
	var sessions := ProjectSettings.globalize_path("res://tests/sessions")
	var names := DirAccess.get_directories_at(sessions)
	check(not names.is_empty(), "tests/sessions/ holds a recorded session")
	for name in names:
		var replayed := _replay(sessions.path_join(name))
		check(replayed.code == 0 and "REPLAY OK" in replayed.output, "tests/sessions/%s replays the same" % name)
	if names.is_empty():
		return

	var edited := _copy(sessions.path_join(names[0]))
	var turn: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(edited.path_join("turn-002.json")))
	turn.turn = 99
	var file := FileAccess.open(edited.path_join("turn-002.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(turn, "  ", false))
	file.close()
	var replayed := _replay(edited)
	check(replayed.code == 1, "a replay that differs exits 1")
	check("REPLAY DIFFERS at turn 2" in replayed.output and "turn: 99 -> 2" in replayed.output, "it names the first turn that differs and the field that changed")
	check(not FileAccess.file_exists(_last_out.path_join("turn-003.json")), "it stops at that turn")

	# JSON reads numbers as floats, which would round this seed to ...992.
	var big := _copy(sessions.path_join(names[0]))
	var seed_field := RegEx.create_from_string("(\"seed\": ?)-?\\d+")
	for name in DirAccess.get_files_at(big):
		var text := seed_field.sub(FileAccess.get_file_as_string(big.path_join(name)), "${1}9007199254740993", true)
		file = FileAccess.open(big.path_join(name), FileAccess.WRITE)
		file.store_string(text)
		file.close()
	replayed = _replay(big)
	check(replayed.code == 0 and "\"seed\":9007199254740993," in FileAccess.get_file_as_string(_last_out.path_join("actions.jsonl")), "a replay keeps a seed above 2^53 exact")

# Runs the driver's replay of `old` into a new folder; returns its exit code and output.
func _replay(old: String) -> Dictionary:
	_last_out = _new_folder("replay")
	var output := []
	var args := [OS.get_executable_path(), "--path", ProjectSettings.globalize_path("res://"), "--fixed-fps", "60",
		"--script", "res://tools/play_driver.gd", "--", "--out=" + _last_out, "--replay=" + old]
	var code := OS.execute(ProjectSettings.globalize_path("res://tools/native.sh"), args, output, true)
	var text := "\n".join(output)
	print(text)
	return {"code": code, "output": text}

# Copies a session's files into a new folder, to edit them there.
func _copy(source: String) -> String:
	var copy := _new_folder("edited")
	for name in DirAccess.get_files_at(source):
		DirAccess.copy_absolute(source.path_join(name), copy.path_join(name))
	return copy

func _new_folder(kind: String) -> String:
	var path := ProjectSettings.globalize_path("res://tests/output/replay").path_join("%s-%d-%d" % [kind, OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(path)
	return path
