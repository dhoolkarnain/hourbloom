extends Node
## Input as actions, not keys (autoload "Controls").
## Gameplay code reads only these action names, so keyboard, gamepad and touch
## all work, and bindings can be changed in one place (data-driven).

const BINDINGS := {
	# Rhythm lanes
	"lane_1": {"keys": [KEY_D, KEY_LEFT], "buttons": [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_DPAD_LEFT]},
	"lane_2": {"keys": [KEY_F, KEY_DOWN], "buttons": [JOY_BUTTON_X, JOY_BUTTON_DPAD_DOWN]},
	"lane_3": {"keys": [KEY_J, KEY_UP], "buttons": [JOY_BUTTON_B, JOY_BUTTON_DPAD_UP]},
	"lane_4": {"keys": [KEY_K, KEY_RIGHT], "buttons": [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_RIGHT]},
	# Movement (racing, puzzle cursor)
	"move_left": {"keys": [KEY_LEFT, KEY_A], "buttons": [JOY_BUTTON_DPAD_LEFT], "axis": [JOY_AXIS_LEFT_X, -1.0]},
	"move_right": {"keys": [KEY_RIGHT, KEY_D], "buttons": [JOY_BUTTON_DPAD_RIGHT], "axis": [JOY_AXIS_LEFT_X, 1.0]},
	"move_up": {"keys": [KEY_UP, KEY_W], "buttons": [JOY_BUTTON_DPAD_UP], "axis": [JOY_AXIS_LEFT_Y, -1.0]},
	"move_down": {"keys": [KEY_DOWN, KEY_S], "buttons": [JOY_BUTTON_DPAD_DOWN], "axis": [JOY_AXIS_LEFT_Y, 1.0]},
	"confirm": {"keys": [KEY_SPACE, KEY_ENTER], "buttons": [JOY_BUTTON_A]},
	"hint": {"keys": [KEY_H], "buttons": [JOY_BUTTON_Y]},
	"pause": {"keys": [KEY_ESCAPE, KEY_P], "buttons": [JOY_BUTTON_START]},
	"debug_fps": {"keys": [KEY_F3], "buttons": []},
}


func _ready() -> void:
	for action in BINDINGS.keys():
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, 0.4)
		var b: Dictionary = BINDINGS[action]
		for k in b.get("keys", []):
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
		for btn in b.get("buttons", []):
			var jb := InputEventJoypadButton.new()
			jb.button_index = btn
			InputMap.action_add_event(action, jb)
		if b.has("axis"):
			var jm := InputEventJoypadMotion.new()
			jm.axis = b.axis[0]
			jm.axis_value = b.axis[1]
			InputMap.action_add_event(action, jm)


## True if the event is a fresh press of the action (no key repeat).
static func pressed(event: InputEvent, action: String) -> bool:
	return event.is_action_pressed(action, false, true) and not event.is_echo()
