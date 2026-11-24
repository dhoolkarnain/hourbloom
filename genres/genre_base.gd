class_name GenreBase
extends Screen
## Shared frame for every bloom (genre world): owner + wish header, short intro,
## exit, assist mode, and finishing into the results screen.

var seed: Dictionary
var seed_id := ""
var mode := ""
var assist := false
var difficulty := 1.0
var running := false
var finished := false
var intro_time := 1.4
var tint := Color.WHITE

var _header: Label
var _center_msg: Label


func _ready() -> void:
	seed_id = params.get("seed_id", "")
	mode = params.get("mode", "")
	seed = SeedData.get_seed(seed_id)
	assist = bool(GameState.settings.get("assist", false))
	var emo: Dictionary = SeedData.EMOTIONS.get(seed.get("emotion", "joy"), SeedData.EMOTIONS.joy)
	difficulty = float(emo.difficulty) * (0.8 if assist else 1.0)
	tint = emo.tint
	add_child(UI.background(0.4 + GameState.bloom_ratio() * 0.6))
	setup_world()
	_build_frame()
	_show_intro()


## Override: build the genre's nodes.
func setup_world() -> void:
	pass


## Override: per-frame game logic while running.
func tick(_delta: float) -> void:
	pass


func _build_frame() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 20
	bar.offset_right = -20
	bar.offset_top = 12
	add_child(bar)
	var g: Dictionary = SeedData.GENRES[seed.genre]
	_header = UI.label("%s  %s — %s" % [g.icon, String(seed.owner).split(",")[0], seed.wish], 22, UI.INK)
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.clip_text = true
	bar.add_child(_header)
	var exit := UI.button("✕", func(): go("greenhouse"), 22, true)
	exit.custom_minimum_size = Vector2(64, 56)
	exit.tooltip_text = "Back to the Greenhouse"
	bar.add_child(exit)

	_center_msg = UI.label("", 44, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	UI.place(_center_msg, Vector2(0.5, 0.42), Vector2(1000, 80))
	_center_msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center_msg)


func _show_intro() -> void:
	var g: Dictionary = SeedData.GENRES[seed.genre]
	var line := intro_hint()
	flash("%s  %s" % [g.icon, line], intro_time)
	var tw := create_tween()
	tw.tween_interval(intro_time)
	tw.tween_callback(func(): running = true; on_start())


## Override: one-line control hint shown at start.
func intro_hint() -> String:
	return "Get ready"


## Override: called when play begins.
func on_start() -> void:
	pass


func flash(text: String, hold := 0.6) -> void:
	if _center_msg == null or not is_inside_tree():
		return
	_center_msg.text = text
	_center_msg.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(hold)
	tw.tween_property(_center_msg, "modulate:a", 0.0, 0.3)


func _process(delta: float) -> void:
	if running and not finished:
		tick(delta)
	queue_redraw()


func finish(stars: int, detail: String) -> void:
	if finished:
		return
	finished = true
	running = false
	if not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(func(): go("results", {"seed_id": seed_id, "stars": stars, "detail": detail}))


func _notification(what: int) -> void:
	# Pause when the app goes to the background (phone call, notification).
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and running:
		running = false
		flash("Paused — tap to continue", 999.0)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and not running and not finished and _center_msg and _center_msg.text.begins_with("Paused"):
		pass


func _unhandled_input(event: InputEvent) -> void:
	if not running and not finished and _center_msg and _center_msg.text.begins_with("Paused"):
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed):
			_center_msg.modulate.a = 0.0
			_center_msg.text = ""
			running = true
			get_viewport().set_input_as_handled()
