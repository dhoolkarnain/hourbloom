class_name Pot
extends PanelContainer
## A pot in the Greenhouse. Accepts dropped seeds; planted pots can Bloom (play).

signal seed_dropped(index: int, seed_id: String)
signal tapped(index: int)
signal bloom_pressed(index: int)
signal unplant_pressed(index: int)

var index := 0
var seed_id := ""
var highlight := false:
	set(v):
		highlight = v
		queue_redraw()
var _t := 0.0
var _sprout: Control


func setup(i: int, id: String) -> Pot:
	index = i
	seed_id = id
	custom_minimum_size = Vector2(260, 152)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := UI.panel_box(Color(0.18, 0.15, 0.27, 0.72), 22, Color(1, 1, 1, 0.12), 2)
	box.content_margin_left = 14
	box.content_margin_right = 14
	add_theme_stylebox_override("panel", box)
	_build()
	return self


func _build() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_sprout = Control.new()
	_sprout.custom_minimum_size = Vector2(84, 120)
	_sprout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprout.draw.connect(_draw_sprout)
	row.add_child(_sprout)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)

	if seed_id == "":
		var hint := UI.wrap_label("Empty pot\nDrop a seed here", 18, UI.INK_DIM)
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(hint)
		return

	var s := SeedData.get_seed(seed_id)
	var g: Dictionary = SeedData.GENRES[s.genre]
	var name_l := UI.label(String(s.owner).split(",")[0], 20, UI.INK)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_l)
	var meta := UI.label("%s %s   %s" % [g.icon, g.name, UI.stars_text(GameState.stars.get(seed_id, 0))], 15, g.color)
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(meta)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	col.add_child(btns)
	var bloom_text := "Replay ▶" if GameState.returned.has(seed_id) else "Bloom ▶"
	var bloom := UI.button(bloom_text, func(): bloom_pressed.emit(index), 18)
	bloom.custom_minimum_size = Vector2(104, 52)
	btns.add_child(bloom)
	var undo := UI.button("↺", func(): unplant_pressed.emit(index), 18, true)
	undo.tooltip_text = "Take the seed back"
	undo.custom_minimum_size = Vector2(52, 52)
	btns.add_child(undo)


func _process(delta: float) -> void:
	_t += delta
	if _sprout:
		_sprout.queue_redraw()


func _draw() -> void:
	if highlight:
		draw_rect(Rect2(Vector2.ZERO, size).grow(4), UI.TEAL, false, 3.0)


func _draw_sprout() -> void:
	var w := _sprout.size.x
	var h := _sprout.size.y
	var base := Vector2(w / 2, h - 18)
	# the pot
	var pot_pts := PackedVector2Array([base + Vector2(-30, -6), base + Vector2(30, -6), base + Vector2(22, 18), base + Vector2(-22, 18)])
	_sprout.draw_colored_polygon(pot_pts, Color("#c9705a"))
	_sprout.draw_rect(Rect2(base + Vector2(-34, -12), Vector2(68, 10)), Color("#d98a72"))
	if seed_id == "":
		_sprout.draw_circle(base + Vector2(0, -16), 5, Color(1, 1, 1, 0.15))
		return
	var s := SeedData.get_seed(seed_id)
	var color: Color = SeedData.GENRES[s.genre].color
	var grown := GameState.returned.has(seed_id)
	var sway := sin(_t * 1.6 + index) * 3.0
	var top := base + Vector2(sway, -60 if grown else -38)
	_sprout.draw_line(base + Vector2(0, -12), top, Color("#5fbf8f"), 4.0)
	_sprout.draw_circle(base + Vector2(-10, -30), 7, Color("#5fbf8f"))
	_sprout.draw_circle(base + Vector2(10, -38), 7, Color("#5fbf8f"))
	var r := 18.0 if grown else 10.0
	_sprout.draw_circle(top, r + 8 + sin(_t * 3.0) * 2.0, Color(color, 0.22))
	_sprout.draw_circle(top, r, color)
	_sprout.draw_circle(top, r * 0.45, Color("#fff4cf"))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		tapped.emit(index)


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	var ok: bool = data is Dictionary and data.has("seed_id")
	highlight = ok
	return ok


func _drop_data(_at: Vector2, data: Variant) -> void:
	highlight = false
	seed_dropped.emit(index, String(data.seed_id))


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_DRAG_END:
		highlight = false
