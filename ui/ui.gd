class_name UI
## Shared look: "painted golden hour". Consistent colours act as memory hooks:
## gold = reward, coral = danger, teal = interactive.

const INK := Color("#fff7e8")
const INK_SOFT := Color("#e9dcc6")
const INK_DIM := Color("#b6a8c9")
const GOLD := Color("#ffd36b")
const CORAL := Color("#ff7a6b")
const TEAL := Color("#4fd1c5")
const PANEL := Color("#2e2648")
const PANEL_LIGHT := Color("#3d3360")
const SKY_GREY_TOP := Color("#3b4256")
const SKY_GREY_BOTTOM := Color("#6b7489")
const SKY_GOLD_TOP := Color("#3a2f5c")
const SKY_GOLD_BOTTOM := Color("#f0a35e")

const MIN_TAP := 64.0  # big tap targets in the thumb zone


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 22
	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "Button", Color("#2b2540"))
	t.set_color("font_hover_color", "Button", Color("#2b2540"))
	t.set_color("font_pressed_color", "Button", Color("#2b2540"))
	t.set_color("font_focus_color", "Button", Color("#2b2540"))
	t.set_color("font_disabled_color", "Button", Color("#6b6280"))
	t.set_stylebox("normal", "Button", _box(GOLD, 18))
	t.set_stylebox("hover", "Button", _box(GOLD.lightened(0.15), 18))
	t.set_stylebox("pressed", "Button", _box(GOLD.darkened(0.15), 18))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), 18, TEAL, 3))
	t.set_stylebox("disabled", "Button", _box(Color("#4a4166"), 18))
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, 20))
	t.set_stylebox("panel", "Panel", _box(PANEL, 20))
	t.set_color("font_color", "CheckButton", INK)
	return t


static func _box(color: Color, radius: int, border := Color(0, 0, 0, 0), border_w := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	return s


static func panel_box(color: Color = PANEL, radius := 20, border := Color(0, 0, 0, 0), border_w := 0) -> StyleBoxFlat:
	return _box(color, radius, border, border_w)


static func label(text: String, size := 22, color := INK, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l


static func wrap_label(text: String, size := 20, color := INK) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, callback: Callable, size := 24, secondary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, MIN_TAP)
	b.add_theme_font_size_override("font_size", size)
	if secondary:
		b.add_theme_stylebox_override("normal", _box(PANEL_LIGHT, 18))
		b.add_theme_stylebox_override("hover", _box(PANEL_LIGHT.lightened(0.1), 18))
		b.add_theme_stylebox_override("pressed", _box(PANEL_LIGHT.darkened(0.1), 18))
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, INK)
	b.pressed.connect(func():
		Sfx.play("tap")
		GameState.haptic(15)
		callback.call())
	return b


static func sky_gradient(ratio: float) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, SKY_GREY_TOP.lerp(SKY_GOLD_TOP, ratio))
	g.set_color(1, SKY_GREY_BOTTOM.lerp(SKY_GOLD_BOTTOM, ratio))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 256
	return tex


static func background(ratio: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = sky_gradient(ratio)
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.show_behind_parent = true  # so a screen's own _draw() appears on top of the sky
	return r


## Places a control by anchor point (0..1 of the parent) with a fixed size and offset.
static func place(c: Control, anchor: Vector2, size: Vector2, offset := Vector2.ZERO) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = -size.x * anchor.x + offset.x
	c.offset_right = c.offset_left + size.x
	c.offset_top = -size.y * anchor.y + offset.y
	c.offset_bottom = c.offset_top + size.y


static func stars_text(n: int) -> String:
	var s := ""
	for i in 3:
		s += "★" if i < n else "☆"
	return s
