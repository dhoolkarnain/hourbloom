class_name GenreBase
extends Screen
## Shared frame for every bloom (genre world): owner + wish header, short intro,
## pause menu, assist mode, hit-stop, music, and finishing into results.
## Gameplay runs in tick() on the fixed 60 Hz physics step; rendering is
## smoothed by Godot's physics interpolation (fixed timestep principle).

var seed: Dictionary
var seed_id := ""
var mode := ""
var assist := false
var difficulty := 1.0
var running := false
var finished := false
var paused := false
var intro_time := 1.4
var tint := Color.WHITE

var world: Node3D      # 3D stage: sky, sun, models
var camera: Camera3D
var _header: Label
var _center_msg: Label
var _pause_panel: PanelContainer


func _ready() -> void:
	seed_id = params.get("seed_id", "")
	mode = params.get("mode", "")
	seed = SeedData.get_seed(seed_id)
	# Assist can come from settings or from the results screen's gentler offer.
	assist = bool(params.get("assist", GameState.settings.get("assist", false)))
	var emo: Dictionary = SeedData.EMOTIONS.get(seed.get("emotion", "joy"), SeedData.EMOTIONS.joy)
	difficulty = float(emo.difficulty) * (0.8 if assist else 1.0)
	tint = emo.tint
	world = Stage.setup(self, 0.45 + GameState.bloom_ratio() * 0.55)
	camera = Camera3D.new()
	camera.fov = 60.0
	world.add_child(camera)
	camera.current = true
	setup_world()
	_build_frame()
	_show_intro()
	Sfx.music(music_track())


## Override: build the genre's nodes.
func setup_world() -> void:
	pass


## Override: fixed-step game logic while running (delta is always 1/60 s).
func tick(_delta: float) -> void:
	pass


## Override: per-frame visuals that don't affect gameplay.
func animate(_delta: float) -> void:
	pass


## Override: which music state this world uses.
func music_track() -> String:
	return "hub"


func _build_frame() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.1, 0.08, 0.18, 0.5)
	shade.set_anchors_preset(Control.PRESET_TOP_WIDE)
	shade.offset_bottom = 72
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 20
	bar.offset_right = -20
	bar.offset_top = 12
	add_child(bar)
	var g: Dictionary = SeedData.GENRES[seed.genre]
	var who := "%s  %s — %s" % [g.icon, String(seed.owner).split(",")[0], seed.wish]
	if assist:
		who += "   (Assist)"
	_header = UI.label(who, 22, UI.INK)
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.clip_text = true
	bar.add_child(_header)
	var pause_btn := UI.button("II", func(): set_paused(true), 22, true)
	pause_btn.custom_minimum_size = Vector2(64, 56)
	pause_btn.tooltip_text = "Pause"
	bar.add_child(pause_btn)

	_center_msg = UI.label("", 44, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	UI.place(_center_msg, Vector2(0.5, 0.42), Vector2(1000, 80))
	_center_msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center_msg)

	_pause_panel = PanelContainer.new()
	UI.place(_pause_panel, Vector2(0.5, 0.5), Vector2(420, 300))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_pause_panel.add_child(col)
	col.add_child(UI.label("Paused", 36, UI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	var resume := UI.button("Resume", func(): set_paused(false), 24)
	col.add_child(resume)
	col.add_child(UI.button("Restart", func(): main.play_seed(seed_id, {"assist": assist}), 22, true))
	col.add_child(UI.button("Back to Greenhouse", func(): go("greenhouse"), 22, true))
	_pause_panel.visible = false
	add_child(_pause_panel)


func _show_intro() -> void:
	var g: Dictionary = SeedData.GENRES[seed.genre]
	flash("%s  %s" % [g.icon, intro_hint()], intro_time)
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


func _physics_process(delta: float) -> void:
	if running and not finished and not paused:
		tick(delta)


func _process(delta: float) -> void:
	if not paused:
		animate(delta)
	queue_redraw()


## Game feel: freeze for a few frames on a big impact.
func hit_stop(seconds := 0.07) -> void:
	if not is_inside_tree():
		return
	Engine.time_scale = 0.05
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0


func set_paused(on: bool) -> void:
	if finished:
		return
	paused = on
	_pause_panel.visible = on
	if on:
		_pause_panel.get_child(0).get_child(1).grab_focus()


func finish(stars: int, detail: String) -> void:
	if finished:
		return
	finished = true
	running = false
	Engine.time_scale = 1.0
	if not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(func(): go("results", {"seed_id": seed_id, "stars": stars, "detail": detail, "assist": assist}))


func _notification(what: int) -> void:
	# Pause and keep progress when the app goes to the background (calls, notifications).
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and running and not paused:
		set_paused(true)
		GameState.save_game()
	elif what == NOTIFICATION_EXIT_TREE:
		Engine.time_scale = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if Controls.pressed(event, "pause"):
		set_paused(not paused)
		get_viewport().set_input_as_handled()
