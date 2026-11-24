class_name SeedCard
extends PanelContainer
## A seed in the tray. Drag it onto a pot (drag-and-drop), or tap to select.
## Affordance: shadow + gentle wobble says "you can pick me up".

signal tapped(seed_id: String)

var seed_id := ""
var selected := false:
	set(v):
		selected = v
		_restyle()
var _t := randf() * TAU


func setup(id: String) -> SeedCard:
	seed_id = id
	var s := SeedData.get_seed(id)
	var g: Dictionary = SeedData.GENRES[s.genre]
	custom_minimum_size = Vector2(176, 112)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 2)
	add_child(col)
	var top := UI.label("%s  %s" % [g.icon, g.name], 18, g.color)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var who := UI.label(String(s.owner).split(",")[0], 22, UI.INK)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(who)
	var wish := UI.wrap_label(s.wish, 14, UI.INK_DIM)
	wish.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wish.custom_minimum_size = Vector2(140, 0)
	col.add_child(wish)
	_restyle()
	return self


func _restyle() -> void:
	var s := SeedData.get_seed(seed_id)
	if s.is_empty():
		return
	var g: Dictionary = SeedData.GENRES[s.genre]
	var box := UI.panel_box(UI.PANEL_LIGHT, 16, g.color if selected else g.color.darkened(0.35), 4 if selected else 2)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, 4)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	add_theme_stylebox_override("panel", box)


func _process(delta: float) -> void:
	_t += delta
	rotation = sin(_t * 1.7) * 0.012
	pivot_offset = size / 2


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		tapped.emit(seed_id)


func _get_drag_data(_at: Vector2) -> Variant:
	var s := SeedData.get_seed(seed_id)
	var g: Dictionary = SeedData.GENRES[s.genre]
	var preview := Label.new()
	preview.text = "  %s  " % g.icon
	preview.add_theme_font_size_override("font_size", 40)
	var box := UI.panel_box(g.color, 40)
	var wrap := PanelContainer.new()
	wrap.add_theme_stylebox_override("panel", box)
	wrap.add_child(preview)
	set_drag_preview(wrap)
	Sfx.play("tap", 1.3)
	return {"seed_id": seed_id}
