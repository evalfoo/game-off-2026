extends RefCounted

# Launches the main scene for a test, clip or shot script. The game keeps its
# saves under its save_directory (game/main.gd), which this sets to `directory`
# before add_child(), so _ready() never reads the player's saves. Without a
# directory, each launch gets a new folder under the git-ignored tests/output/
# saves/. user:// would not do: on macOS Godot ignores the XDG_DATA_HOME the
# mise test tasks set, so user:// is the player's folder there.
# It also sets the game's rng_seed, so a run replays the same (CODING_STANDARDS.md).
static func launch(root: Node, directory: String = "", rng_seed: int = 0) -> Node:
	var game := (load("res://game/main.tscn") as PackedScene).instantiate()
	if directory.is_empty():
		directory = ProjectSettings.globalize_path("res://tests/output/saves").path_join(
			"%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	assert("save_directory" in game, "The main scene needs a save_directory variable; see Persistence in docs/implementation.md")
	game.set("save_directory", directory)
	assert("rng_seed" in game, "The main scene needs an rng_seed variable; see game/main.gd")
	game.set("rng_seed", rng_seed)
	root.add_child(game)
	return game
