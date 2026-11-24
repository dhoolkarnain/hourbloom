class_name Sunday
extends Control
## Sunday: the first escaped hour. Companion, guide and comic relief.
## Speaks one short line at a time (reduces short-term memory load).

var bubble: PanelContainer
var text_label: Label
var _t := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(380, 110)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble = PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", UI.panel_box(Color("#fff7e8"), 18))
	bubble.position = Vector2(96, 0)
	bubble.custom_minimum_size = Vector2(290, 0)
	bubble.size = Vector2(290, 90)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bubble)
	text_label = UI.wrap_label("", 18, Color("#2b2540"))
	text_label.custom_minimum_size = Vector2(250, 0)
	bubble.add_child(text_label)


func say(line: String) -> void:
	text_label.text = line
	bubble.scale = Vector2(0.9, 0.9)
	bubble.pivot_offset = Vector2(0, 45)
	create_tween().tween_property(bubble, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# A small glowing creature: a living hour.
	var bob := sin(_t * 2.2) * 4.0
	var c := Vector2(44, 52 + bob)
	draw_circle(c, 40, Color(1.0, 0.83, 0.42, 0.18))
	draw_circle(c, 32, Color("#ffd36b"))
	draw_circle(c + Vector2(-6, -8), 14, Color("#fff4cf"))
	var blink := 1.0 if fmod(_t, 3.5) > 0.12 else 0.15
	draw_rect(Rect2(c + Vector2(-12, -4), Vector2(5, 9 * blink)), Color("#2b2540"))
	draw_rect(Rect2(c + Vector2(7, -4), Vector2(5, 9 * blink)), Color("#2b2540"))
	draw_arc(c + Vector2(0, 8), 7, 0.3, PI - 0.3, 10, Color("#2b2540"), 2.5)
	# clock-hand antenna
	draw_line(c + Vector2(0, -32), c + Vector2(6, -46), Color("#ffd36b"), 3)
	draw_circle(c + Vector2(6, -46), 4, Color("#fff4cf"))
