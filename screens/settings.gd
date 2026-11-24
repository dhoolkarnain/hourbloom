extends Screen
## Settings: assist mode, sound, haptics, and a save reset that asks first.

var _confirm_reset := false
var _reset_btn: Button


func _ready() -> void:
	add_child(UI.background(GameState.bloom_ratio()))
	var panel := PanelContainer.new()
	UI.place(panel, Vector2(0.5, 0.5), Vector2(620, 440))
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)
	col.add_child(UI.label("Settings", 36))
	col.add_child(_toggle("Assist mode (slower notes, gentler worlds)", "assist"))
	col.add_child(_toggle("Sound", "sound"))
	col.add_child(_toggle("Vibration", "haptics"))
	_reset_btn = UI.button("Reset progress", _on_reset, 20, true)
	col.add_child(_reset_btn)
	col.add_child(UI.button("Back", func(): go("title"), 24))


func _toggle(text: String, key: String) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = bool(GameState.settings.get(key, false))
	c.custom_minimum_size = Vector2(0, UI.MIN_TAP)
	c.add_theme_font_size_override("font_size", 20)
	c.toggled.connect(func(on: bool):
		GameState.settings[key] = on
		GameState.save_game()
		Sfx.play("tap"))
	return c


func _on_reset() -> void:
	if not _confirm_reset:
		_confirm_reset = true
		_reset_btn.text = "Tap again to erase all progress"
		return
	GameState.wipe_save()
	go("title")
