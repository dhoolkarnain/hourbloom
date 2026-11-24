extends Screen
## Codex: Ira's notebook. Remembers every hour and graft so the player doesn't have to.


func _ready() -> void:
	add_child(UI.background(GameState.bloom_ratio()))
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 80
	panel.offset_right = -80
	panel.offset_top = 40
	panel.offset_bottom = -40
	panel.add_theme_stylebox_override("panel", UI.panel_box(Color("#f4ead5"), 22))
	add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := UI.label("Ira's Notebook", 34, Color("#2b2540"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UI.button("Close", func(): go("greenhouse"), 20))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	list.add_child(UI.label("Hours returned  %d / %d" % [GameState.returned_count(), GameState.total_hours()], 22, Color("#5a4b7a")))
	for s in SeedData.SEEDS:
		var done: bool = GameState.returned.has(s.id)
		var g: Dictionary = SeedData.GENRES[s.genre]
		var line := "%s  %s — %s   %s" % [g.icon, s.owner, s.wish, UI.stars_text(GameState.stars.get(s.id, 0))]
		var l := UI.wrap_label(line if done else "%s  ??? — an hour still waiting" % g.icon, 19, Color("#2b2540") if done else Color("#8a7fa0"))
		list.add_child(l)

	list.add_child(UI.label(" ", 10))
	list.add_child(UI.label("Grafts discovered  %d / %d" % [GameState.codex.size(), SeedData.GRAFTS.size()], 22, Color("#5a4b7a")))
	for key in SeedData.GRAFTS.keys():
		var gr: Dictionary = SeedData.GRAFTS[key]
		var found: bool = GameState.codex.has(gr.id)
		var txt := "%s — %s" % [gr.title, gr.rule] if found else "??? — try planting one seed onto another"
		list.add_child(UI.wrap_label(txt, 19, Color("#2b2540") if found else Color("#8a7fa0")))
	list.add_child(UI.wrap_label("More grafts arrive with new genres: 28 in the full game.", 16, Color("#8a7fa0")))
