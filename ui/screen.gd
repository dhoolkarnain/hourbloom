class_name Screen
extends Control
## Base class for every full-screen view. The Main node swaps screens.

var main: Node
var params: Dictionary = {}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS


func go(screen_name: String, p := {}) -> void:
	if main:
		main.go(screen_name, p)
