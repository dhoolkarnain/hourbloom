extends Control
## Screen manager with a short fade between screens.

const SCREENS := {
	"title": preload("res://screens/title.gd"),
	"greenhouse": preload("res://screens/greenhouse.gd"),
	"results": preload("res://screens/results.gd"),
	"codex": preload("res://screens/codex.gd"),
	"settings": preload("res://screens/settings.gd"),
	"rhythm": preload("res://genres/rhythm.gd"),
	"racing": preload("res://genres/racing.gd"),
	"puzzle": preload("res://genres/puzzle.gd"),
}

## Genre id -> screen + mode.
const GENRE_SCREENS := {
	"rhythm": ["rhythm", ""],
	"racing": ["racing", ""],
	"puzzle": ["puzzle", ""],
	"graft_racing_rhythm": ["racing", "beat"],
}

var current: Control
var _fade: ColorRect
var current_name := ""


func _ready() -> void:
	theme = UI.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade = ColorRect.new()
	_fade.color = Color("#1d1830")
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	add_child(_fade)
	go("title")


func go(screen_name: String, p := {}) -> void:
	if not SCREENS.has(screen_name):
		push_error("Unknown screen: " + screen_name)
		return
	if current:
		current.queue_free()
	var s: Control = SCREENS[screen_name].new()
	s.main = self
	s.params = p
	add_child(s)
	move_child(_fade, -1)
	current = s
	current_name = screen_name
	_fade.modulate.a = 1.0
	create_tween().tween_property(_fade, "modulate:a", 0.0, 0.25)


## Starts the bloom for a seed: the wish decides the genre.
func play_seed(seed_id: String) -> void:
	var seed := SeedData.get_seed(seed_id)
	if seed.is_empty():
		return
	var target: Array = GENRE_SCREENS.get(seed.genre, ["puzzle", ""])
	go(target[0], {"seed_id": seed_id, "mode": target[1]})
