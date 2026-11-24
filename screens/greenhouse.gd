extends Screen
## The Greenhouse: Ira's rooftop hub. A "toy" with no fail state, next to the "games" (blooms).
## Plant seeds, graft them, and step into the hours they hold.

var sunday: Sunday
var grid: GridContainer
var tray: HBoxContainer
var light_label: Label
var hours_label: Label
var selected_seed := ""
var pots: Array[Pot] = []
var cards: Array[SeedCard] = []


func _ready() -> void:
	add_child(UI.background(GameState.bloom_ratio()))
	_build_city()
	_build_top_bar()
	_build_pots()
	_build_tray()
	sunday = Sunday.new()
	UI.place(sunday, Vector2(0, 1), Vector2(400, 110), Vector2(20, -168))
	add_child(sunday)
	_tutorial_line()


# ---------- Layout ----------

func _build_city() -> void:
	# Distant skyline: grey towers turn warm as hours return home.
	var city := Control.new()
	city.set_anchors_preset(Control.PRESET_FULL_RECT)
	city.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ratio := GameState.bloom_ratio()
	city.draw.connect(func():
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var w := city.size.x
		var h := city.size.y
		var x := 0.0
		var i := 0
		while x < w:
			var bw := rng.randf_range(50, 110)
			var bh := rng.randf_range(140, 330)
			var lit := float(i % 6) / 6.0 < ratio
			var col := Color("#4b4a63") if not lit else Color("#6a4f7a")
			city.draw_rect(Rect2(x, h - bh, bw - 6, bh), Color(col, 0.55))
			if lit:
				for wy in range(int(h - bh + 16), int(h - 20), 28):
					city.draw_rect(Rect2(x + 10, wy, 8, 10), Color("#ffd36b", 0.7))
					city.draw_rect(Rect2(x + bw - 26, wy, 8, 10), Color("#ffd36b", 0.5))
			x += bw
			i += 1)
	add_child(city)


func _build_top_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 24
	bar.offset_right = -24
	bar.offset_top = 14
	bar.add_theme_constant_override("separation", 14)
	add_child(bar)
	var title := UI.label("Ira's Greenhouse", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	light_label = UI.label("✦ %d Light" % GameState.light, 24, UI.GOLD)
	bar.add_child(light_label)
	hours_label = UI.label("Hours home %d/%d" % [GameState.returned_count(), GameState.total_hours()], 22, UI.INK_SOFT)
	bar.add_child(hours_label)
	bar.add_child(UI.button("Notebook", func(): go("codex"), 20, true))
	bar.add_child(UI.button("⚙", func(): go("settings"), 22, true))


func _build_pots() -> void:
	grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	center.offset_top = 76
	center.offset_bottom = 400
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	center.add_child(grid)
	add_child(center)
	_refresh_pots()


func _refresh_pots() -> void:
	for c in grid.get_children():
		c.queue_free()
	pots.clear()
	for i in GameState.POT_COUNT:
		var p := Pot.new().setup(i, GameState.pots[i])
		p.seed_dropped.connect(_on_seed_dropped)
		p.tapped.connect(_on_pot_tapped)
		p.bloom_pressed.connect(_on_bloom)
		p.unplant_pressed.connect(_on_unplant)
		grid.add_child(p)
		pots.append(p)


func _build_tray() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -158
	panel.offset_left = 16
	panel.offset_right = -16
	panel.offset_bottom = -12
	panel.add_theme_stylebox_override("panel", UI.panel_box(Color(0.12, 0.1, 0.2, 0.78), 22))
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var label := UI.label("Seeds\nfrom the\nSilo", 18, UI.INK_DIM)
	label.custom_minimum_size = Vector2(84, 0)
	row.add_child(label)
	tray = HBoxContainer.new()
	tray.add_theme_constant_override("separation", 12)
	row.add_child(tray)
	_refresh_tray()


func _refresh_tray() -> void:
	for c in tray.get_children():
		c.queue_free()
	cards.clear()
	var ids := GameState.tray_seeds()
	if ids.is_empty():
		tray.add_child(UI.label("All seeds planted. Tap ↺ on a pot to take one back.", 18, UI.INK_DIM))
	for id in ids:
		var card := SeedCard.new().setup(id)
		card.tapped.connect(_on_card_tapped)
		card.selected = id == selected_seed
		tray.add_child(card)
		cards.append(card)


func _refresh_all() -> void:
	light_label.text = "✦ %d Light" % GameState.light
	hours_label.text = "Hours home %d/%d" % [GameState.returned_count(), GameState.total_hours()]
	_refresh_pots()
	_refresh_tray()


# ---------- Interaction ----------

func _on_card_tapped(id: String) -> void:
	selected_seed = "" if selected_seed == id else id
	for c in cards:
		c.selected = c.seed_id == selected_seed
	if selected_seed != "":
		var s := SeedData.get_seed(id)
		sunday.say("%s\nTap a pot to plant it." % s.before)


func _on_pot_tapped(index: int) -> void:
	if selected_seed == "":
		return
	var id := selected_seed
	selected_seed = ""
	_on_seed_dropped(index, id)


func _on_seed_dropped(index: int, id: String) -> void:
	if GameState.pots[index] == "":
		if GameState.plant(id, index):
			Sfx.play("plant")
			GameState.haptic(30)
			_refresh_all()
			sunday.say("Planted %s's hour. Tap Bloom ▶ to step inside it." % String(SeedData.get_seed(id).owner).split(",")[0])
		return
	var graft := GameState.try_graft(id, index)
	if graft.is_empty():
		Sfx.play("miss")
		sunday.say("Those two hours don't fit together yet. Try a Racing seed on a Rhythm pot.")
		return
	Sfx.play("graft")
	GameState.haptic(60)
	_refresh_all()
	sunday.say("WOW. A graft! %s: %s Nobody has ever played this hour before." % [graft.title, graft.rule])


func _on_bloom(index: int) -> void:
	var id: String = GameState.pots[index]
	if id != "":
		main.play_seed(id)


func _on_unplant(index: int) -> void:
	GameState.unplant(index)
	_refresh_all()
	sunday.say("Seed back in the tray. Nothing is ever lost here.")


func _tutorial_line() -> void:
	if GameState.should_nudge_break():
		sunday.say("You've played for 90 minutes. Real hours matter too: stretch, drink water. Come back tomorrow for a bonus seed!")
		return
	match GameState.tutorial_step:
		0:
			sunday.say("Hi! I'm Sunday, an hour that escaped. Drag a seed from the tray into a pot to plant it.")
		1:
			sunday.say("It's sprouting! Tap Bloom ▶ to step inside that hour and play it.")
		2:
			sunday.say("You gave an hour back! Secret: drop a Racing seed onto a Rhythm pot and see what grows.")
		_:
			var tips := [
				"Every hour you return makes the city a little warmer. Look at the towers!",
				"Beat your best stars to earn more Light.",
				"Check Ira's Notebook to see whose hours are still waiting.",
				"Grafted worlds play by two sets of rules at once.",
			]
			sunday.say(tips[randi() % tips.size()])
