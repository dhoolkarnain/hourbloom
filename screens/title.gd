extends Screen
## Title: two taps to play. The first bloom is reachable in under 60 seconds.


func _ready() -> void:
	add_child(UI.background(maxf(0.35, GameState.bloom_ratio())))

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	UI.place(col, Vector2(0.5, 0.5), Vector2(620, 420))
	add_child(col)

	col.add_child(UI.label("HOURBLOOM", 72, UI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(UI.label("Grow the hours your city forgot, and play them.", 24, UI.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	col.add_child(spacer)

	var play_text := "Continue" if GameState.tutorial_step > 0 else "Begin"
	var play := UI.button(play_text, func(): go("greenhouse"), 30)
	play.custom_minimum_size = Vector2(0, 76)
	col.add_child(play)
	col.add_child(UI.button("Settings", func(): go("settings"), 22, true))

	var ver := UI.label("Prototype v%s" % ProjectSettings.get_setting("application/config/version"), 16, UI.INK_DIM)
	UI.place(ver, Vector2(0, 1), Vector2(300, 30), Vector2(24, -16))
	add_child(ver)
