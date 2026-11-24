class_name Screen
extends Control
## Base class for every full-screen view. The Main node swaps screens.
## On phones the UI is kept inside the safe area (notches, home indicator);
## the 3D world still fills the whole screen.

var main: Node
var params: Dictionary = {}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS


func _enter_tree() -> void:
	if not OS.has_feature("mobile"):
		return
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	var vp := get_viewport().get_visible_rect().size
	if screen.x <= 0 or screen.y <= 0:
		return
	var sx := vp.x / screen.x
	var sy := vp.y / screen.y
	offset_left = safe.position.x * sx
	offset_top = safe.position.y * sy
	offset_right = -(screen.x - safe.end.x) * sx
	offset_bottom = -(screen.y - safe.end.y) * sy


func go(screen_name: String, p := {}) -> void:
	if main:
		main.go(screen_name, p)
