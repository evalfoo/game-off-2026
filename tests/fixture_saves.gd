extends "res://tests/lib/test.gd"

# tests/lib/fixture.gd gives the game its save folder before _ready(), and
# never the player's user folder, and its random seed: 0 unless given.

func run() -> void:
	var given := Fixture.launch(root, "/tmp/fixture-saves")
	check(given.save_directory == "/tmp/fixture-saves", "the game gets the folder it is given")
	var first := Fixture.launch(root)
	var second := Fixture.launch(root)
	var saves := ProjectSettings.globalize_path("res://tests/output/saves/")
	check(first.save_directory.begins_with(saves), "without one, it gets a folder under tests/output/saves/")
	check(first.save_directory != second.save_directory, "each launch gets its own folder")
	check(first.rng_seed == 0 and Fixture.launch(root, "", 7).rng_seed == 7, "the game gets seed 0, or the seed it is given")
