extends Control
## Screen manager: fades between screens, shows achievement toasts and an
## optional FPS / frame-time overlay (profile before optimising).

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
var current_name := ""
var _fade: ColorRect
var _toast: PanelContainer
var _toast_label: Label
var _fps: Label


func _ready() -> void:
	# Symbols (✦ ♪ ◇ ⚙ ★ ♥ ↺) come from a tiny bundled font, so they render on the web
	# and on phones that lack them, in 2D UI and 3D labels alike.
	var symbols: Font = load("res://assets/fonts/symbols.ttf")
	var base: Font = ThemeDB.fallback_font
	if symbols and base and not base.fallbacks.has(symbols):
		var fb := base.fallbacks.duplicate()
		fb.append(symbols)
		base.fallbacks = fb
	theme = UI.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade = ColorRect.new()
	_fade.color = Color("#1d1830")
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	add_child(_fade)
	_build_toast()
	_fps = UI.label("", 16, UI.INK)
	UI.place(_fps, Vector2(1, 1), Vector2(240, 24), Vector2(-12, -4))
	_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fps)
	Platform.achievement_unlocked.connect(_on_achievement)
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
	move_child(_toast, -1)
	move_child(_fps, -1)
	current = s
	current_name = screen_name
	_fade.modulate.a = 1.0
	create_tween().tween_property(_fade, "modulate:a", 0.0, 0.25)


## Starts the bloom for a seed: the wish decides the genre.
func play_seed(seed_id: String, extra := {}) -> void:
	var seed := SeedData.get_seed(seed_id)
	if seed.is_empty():
		return
	var target: Array = GENRE_SCREENS.get(seed.genre, ["puzzle", ""])
	var p := {"seed_id": seed_id, "mode": target[1]}
	p.merge(extra)
	go(target[0], p)


func _process(_delta: float) -> void:
	_fps.visible = GameState.settings.get("show_fps", false)
	if _fps.visible:
		_fps.text = "%d fps  %.1f ms" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0]


func _unhandled_input(event: InputEvent) -> void:
	if Controls.pressed(event, "debug_fps"):
		GameState.settings.show_fps = not GameState.settings.get("show_fps", false)


func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", UI.panel_box(Color("#fff7e8"), 18, UI.GOLD, 3))
	UI.place(_toast, Vector2(0.5, 0), Vector2(520, 70), Vector2(0, 18))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = UI.label("", 22, Color("#2b2540"), HORIZONTAL_ALIGNMENT_CENTER)
	_toast.add_child(_toast_label)
	_toast.modulate.a = 0.0
	add_child(_toast)


func _on_achievement(_id: String, title: String) -> void:
	_toast_label.text = "★  Achievement: " + title
	Sfx.play("achievement")
	GameState.haptic(40)
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.4)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
