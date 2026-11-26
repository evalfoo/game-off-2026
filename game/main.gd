extends Control

# TODO(template): replace with the game. Tests, clips and shots launch this
# scene through tests/lib/fixture.gd.

# The folder every save goes under. tests/lib/fixture.gd sets it before
# _ready() for tests, clips, stills and agent play sessions, so they never touch
# the player's saves. The folder may not exist yet; the game creates it.
# TODO(template): keep every save file under it.
var save_directory := "user://"

# The seed of the game's randomness. tests/lib/fixture.gd sets it before
# _ready() for tests, clips, stills and agent play sessions, so a run with
# --fixed-fps replays the same. A player's game gets a new one each launch.
# TODO(template): seed the game's RandomNumberGenerator from it.
var rng_seed := randi()

var clicks := 0

@onready var button: Button = %Button
@onready var label: Label = %Label

func _ready() -> void:
	button.pressed.connect(_on_pressed)
	_refresh()

func _on_pressed() -> void:
	clicks += 1
	_refresh()

func _refresh() -> void:
	label.text = "Clicks: %d" % clicks
