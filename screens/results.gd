extends Screen
## Results: stars, then the citizen's story (closure), then "try again" up front.
## PlayTimeLine target thought: "I can do better, let me try again."

var _star_labels: Array[Label] = []


func _ready() -> void:
	var seed_id: String = params.get("seed_id", "")
	var earned: int = params.get("stars", 0)
	var seed := SeedData.get_seed(seed_id)
	var assisted: bool = params.get("assist", false)
	var summary := GameState.record_result(seed_id, earned, assisted)

	add_child(UI.background(GameState.bloom_ratio()))
	var panel := PanelContainer.new()
	UI.place(panel, Vector2(0.5, 0.5), Vector2(760, 560))
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)

	var head := "Hour returned!" if earned > 0 else "The hour slipped away..."
	col.add_child(UI.label(head, 40, UI.GOLD if earned > 0 else UI.CORAL, HORIZONTAL_ALIGNMENT_CENTER))

	var star_row := HBoxContainer.new()
	star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	star_row.add_theme_constant_override("separation", 18)
	col.add_child(star_row)
	for i in 3:
		var l := UI.label("☆", 64, UI.INK_DIM)
		l.pivot_offset = Vector2(24, 36)
		star_row.add_child(l)
		_star_labels.append(l)

	col.add_child(UI.label(String(params.get("detail", "")), 20, UI.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	var light_line := "+%d Light" % summary.light_gained
	if summary.first_return:
		light_line += "   (first return bonus +25)"
	elif summary.improved:
		light_line += "   New best!"
	col.add_child(UI.label(light_line, 22, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	var story_text: String = seed.get("after", "") if earned > 0 else "Not yet. %s is still waiting for this hour." % String(seed.get("owner", "Someone")).split(",")[0]
	var story := UI.wrap_label(story_text, 21, UI.INK)
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story.custom_minimum_size = Vector2(680, 0)
	col.add_child(story)

	var hint := ""
	if earned < 3:
		hint = "Best %s. I can do better..." % UI.stars_text(summary.best)
	var hint_label := UI.label(hint, 18, UI.INK_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(hint_label)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 16)
	col.add_child(btns)
	var retry := UI.button("Try again ↻", func(): main.play_seed(seed_id, {"assist": assisted}), 26)
	retry.custom_minimum_size = Vector2(240, 72)
	btns.add_child(retry)
	# Dynamic difficulty: after two failed tries in a row, offer a gentler version.
	if earned == 0 and summary.fails_in_a_row >= 2 and not assisted:
		var gentle := UI.button("Try a gentler version", func(): main.play_seed(seed_id, {"assist": true}), 22, true)
		gentle.custom_minimum_size = Vector2(260, 72)
		btns.add_child(gentle)
		hint_label.text = "No rush. A gentler version keeps the same story."
	var back := UI.button("Greenhouse", func(): go("greenhouse"), 24, true)
	back.custom_minimum_size = Vector2(220, 72)
	btns.add_child(back)
	retry.grab_focus()
	Sfx.music("hub")

	_animate_stars(earned)


func _animate_stars(n: int) -> void:
	var tw := create_tween()
	tw.tween_interval(0.3)
	for i in n:
		var l := _star_labels[i]
		tw.tween_callback(func():
			l.text = "★"
			l.add_theme_color_override("font_color", UI.GOLD)
			l.scale = Vector2(1.6, 1.6)
			Sfx.play("star", 1.0 + i * 0.12)
			GameState.haptic(30))
		tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	if n > 0:
		tw.tween_callback(func(): Sfx.play("win"))
