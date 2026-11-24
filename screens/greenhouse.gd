extends Screen
## The Greenhouse (3D): Ira's rooftop hub above Velmora. A "toy" with no fail state,
## next to the "games" (blooms). Plant seeds, graft them, step into the hours they hold.
## Drag a seed card onto a pot, or tap a card then tap a pot.

const POT_POSITIONS := [
	Vector3(-2.4, 0, -0.9), Vector3(0, 0, -0.9), Vector3(2.4, 0, -0.9),
	Vector3(-2.4, 0, 1.3), Vector3(0, 0, 1.3), Vector3(2.4, 0, 1.3),
]
const PICK_RADIUS := 1.0

var world: Node3D
var camera: Camera3D
var sunday: Sunday
var sunday_3d: Node3D
var tray: HBoxContainer
var light_label: Label
var hours_label: Label
var action_panel: PanelContainer
var action_title: Label
var action_meta: Label
var bloom_btn: Button
var selected_seed := ""
var selected_pot := -1
var hover_pot := -1
var cards: Array[SeedCard] = []
var _pot_nodes: Array = []     # {pot, flower, label, ring}
var _t := 0.0


func _ready() -> void:
	world = Stage.setup(self, 0.35 + GameState.bloom_ratio() * 0.65)
	world.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # hub animates per frame
	camera = Camera3D.new()
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # moved per frame
	camera.fov = 52.0
	world.add_child(camera)
	camera.current = true
	_place_camera(0.0)
	var gh := Stage.model("greenhouse")
	world.add_child(gh)
	Stage.city(world, GameState.bloom_ratio(), Vector3(0, 0, -4), 16.0, 48.0, 54, -14.0)
	sunday_3d = Stage.model("sunday")
	sunday_3d.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	sunday_3d.position = Vector3(-3.4, 1.6, 2.6)
	sunday_3d.rotation.y = 0.5
	world.add_child(sunday_3d)
	_build_pots()

	add_child(_drop_layer())
	_build_top_bar()
	_build_tray()
	_build_action_panel()
	sunday = Sunday.new()
	sunday.show_creature = false
	UI.place(sunday, Vector2(0, 1), Vector2(400, 110), Vector2(70, -168))
	add_child(sunday)
	_tutorial_line()
	Sfx.music("hub")


func _place_camera(t: float) -> void:
	camera.position = Vector3(sin(t * 0.15) * 0.4, 5.4, 8.6)
	camera.look_at(Vector3(0, 0.4, 0.2))


# ---------- 3D pots ----------

func _build_pots() -> void:
	for p in _pot_nodes:
		p.root.queue_free()
	_pot_nodes.clear()
	for i in GameState.POT_COUNT:
		var root := Node3D.new()
		root.position = POT_POSITIONS[i]
		world.add_child(root)
		var pot := Stage.model("pot")
		root.add_child(pot)
		if not GameState.shadows_enabled():
			var blob := Stage.blob_shadow(0.75)
			blob.position.y = 0.01
			root.add_child(blob)
		var ring := Stage.box(Vector3(1.5, 0.02, 1.5), UI.TEAL, 1.5, 0.45)
		ring.position.y = 0.02
		ring.visible = false
		root.add_child(ring)
		var id: String = GameState.pots[i]
		var flower: Node3D = null
		var label := Stage.label3d("", 40)
		label.position = Vector3(0, 3.0, 0)
		root.add_child(label)
		if id != "":
			var s := SeedData.get_seed(id)
			var g: Dictionary = SeedData.GENRES[s.genre]
			flower = Stage.model("flower")
			flower.position.y = 0.78
			var grown := GameState.returned.has(id)
			flower.scale = Vector3.ONE * (1.7 if grown else 1.05)
			Stage.tint(flower, "Petals", g.color, 0.35 if grown else 0.1)
			if not grown:
				Stage.set_part_visible(flower, "Center", false)
			root.add_child(flower)
			label.text = "%s\n%s" % [String(s.owner).split(",")[0], UI.stars_text(GameState.stars.get(id, 0))]
		else:
			label.text = "empty"
			label.modulate = Color(1, 1, 1, 0.45)
			label.font_size = 32
			label.position.y = 1.3
		_pot_nodes.append({"root": root, "flower": flower, "label": label, "ring": ring})


func _process(delta: float) -> void:
	_t += delta
	_place_camera(_t)
	if sunday_3d:
		sunday_3d.position.y = 1.6 + sin(_t * 2.2) * 0.12
		sunday_3d.rotation.y = 0.5 + sin(_t * 0.7) * 0.3
	for i in _pot_nodes.size():
		var p: Dictionary = _pot_nodes[i]
		p.ring.visible = i == hover_pot or i == selected_pot
		if p.flower:
			p.flower.rotation.z = sin(_t * 1.4 + i) * 0.05


## Which pot is under a screen point (or -1).
func pot_at(screen_pos: Vector2) -> int:
	var hit = Stage.screen_to_plane(camera, screen_pos, 0.7)
	if hit == null:
		return -1
	var best := -1
	var best_d := PICK_RADIUS
	for i in POT_POSITIONS.size():
		var p: Vector3 = POT_POSITIONS[i]
		var d := Vector2(hit.x - p.x, hit.z - p.z).length()
		if d < best_d:
			best_d = d
			best = i
	return best


## Invisible full-screen layer that receives seed drops and taps on the 3D pots.
func _drop_layer() -> Control:
	var layer := DropLayer.new()
	layer.hub = self
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	return layer


class DropLayer extends Control:
	var hub

	func _can_drop_data(at: Vector2, data: Variant) -> bool:
		var ok: bool = data is Dictionary and data.has("seed_id")
		hub.hover_pot = hub.pot_at(at) if ok else -1
		return ok and hub.hover_pot != -1

	func _drop_data(at: Vector2, data: Variant) -> void:
		var i: int = hub.pot_at(at)
		hub.hover_pot = -1
		if i != -1:
			hub._on_seed_dropped(i, String(data.seed_id))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			var i: int = hub.pot_at(event.position)
			if i != -1:
				hub._on_pot_tapped(i)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END and hub:
			hub.hover_pot = -1


# ---------- 2D overlay ----------

func _build_top_bar() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.1, 0.08, 0.18, 0.6)
	shade.set_anchors_preset(Control.PRESET_TOP_WIDE)
	shade.offset_bottom = 76
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
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
	light_label = UI.label("", 24, UI.GOLD)
	bar.add_child(light_label)
	hours_label = UI.label("", 22, UI.INK_SOFT)
	bar.add_child(hours_label)
	bar.add_child(UI.button("Notebook", func(): go("codex"), 20, true))
	bar.add_child(UI.button("⚙", func(): go("settings"), 22, true))
	_refresh_counters()


func _refresh_counters() -> void:
	light_label.text = "✦ %d Light" % GameState.light
	hours_label.text = "Hours home %d/%d" % [GameState.returned_count(), GameState.total_hours()]


func _build_tray() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -158
	panel.offset_left = 16
	panel.offset_right = -16
	panel.offset_bottom = -12
	panel.add_theme_stylebox_override("panel", UI.panel_box(Color(0.12, 0.1, 0.2, 0.82), 22))
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
		tray.add_child(UI.label("All seeds planted. Tap a pot, then ↺ to take one back.", 18, UI.INK_DIM))
	for id in ids:
		var card := SeedCard.new().setup(id)
		card.tapped.connect(_on_card_tapped)
		card.selected = id == selected_seed
		tray.add_child(card)
		cards.append(card)


func _build_action_panel() -> void:
	action_panel = PanelContainer.new()
	UI.place(action_panel, Vector2(1, 1), Vector2(330, 190), Vector2(-24, -176))
	add_child(action_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	action_panel.add_child(col)
	action_title = UI.label("", 24)
	col.add_child(action_title)
	action_meta = UI.wrap_label("", 16, UI.INK_DIM)
	action_meta.custom_minimum_size = Vector2(290, 0)
	col.add_child(action_meta)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	bloom_btn = UI.button("Bloom ▶", func(): _on_bloom(selected_pot), 24)
	bloom_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bloom_btn)
	var undo := UI.button("↺", func(): _on_unplant(selected_pot), 22, true)
	undo.tooltip_text = "Take the seed back"
	undo.custom_minimum_size = Vector2(64, 0)
	row.add_child(undo)
	action_panel.visible = false


func _show_action(i: int) -> void:
	selected_pot = i
	var id: String = GameState.pots[i] if i >= 0 else ""
	if id == "":
		action_panel.visible = false
		selected_pot = -1
		return
	var s := SeedData.get_seed(id)
	var g: Dictionary = SeedData.GENRES[s.genre]
	action_title.text = "%s  %s" % [g.icon, String(s.owner).split(",")[0]]
	action_meta.text = "%s\n%s  ·  best %s" % [s.wish, g.name, UI.stars_text(GameState.stars.get(id, 0))]
	bloom_btn.text = "Replay ▶" if GameState.returned.has(id) else "Bloom ▶"
	action_panel.visible = true


func _refresh_all() -> void:
	_refresh_counters()
	_build_pots()
	_refresh_tray()
	_show_action(selected_pot)


# ---------- Interaction ----------

func _on_card_tapped(id: String) -> void:
	selected_seed = "" if selected_seed == id else id
	for c in cards:
		c.selected = c.seed_id == selected_seed
	if selected_seed != "":
		var s := SeedData.get_seed(id)
		sunday.say("%s\nTap a pot to plant it." % s.before)


func _on_pot_tapped(index: int) -> void:
	if selected_seed != "":
		var id := selected_seed
		selected_seed = ""
		_on_seed_dropped(index, id)
		return
	Sfx.play("tap")
	_show_action(index if GameState.pots[index] != "" else -1)


func _on_seed_dropped(index: int, id: String) -> void:
	if GameState.pots[index] == "":
		if GameState.plant(id, index):
			Sfx.play("plant")
			GameState.haptic(30)
			selected_pot = index
			_refresh_all()
			_pop_pot(index)
			sunday.say("Planted %s's hour. Tap Bloom ▶ to step inside it." % String(SeedData.get_seed(id).owner).split(",")[0])
		return
	var graft := GameState.try_graft(id, index)
	if graft.is_empty():
		Sfx.play("miss")
		sunday.say("Those two hours don't fit together yet. Try a Racing seed on a Rhythm pot.")
		return
	Sfx.play("graft")
	GameState.haptic(60)
	selected_pot = index
	_refresh_all()
	_pop_pot(index)
	sunday.say("WOW. A graft! %s: %s Nobody has ever played this hour before." % [graft.title, graft.rule])


func _pop_pot(index: int) -> void:
	var f: Node3D = _pot_nodes[index].flower
	if f:
		var final := f.scale
		f.scale = Vector3.ONE * 0.05
		create_tween().tween_property(f, "scale", final, 0.45).set_trans(Tween.TRANS_BACK)


func _on_bloom(index: int) -> void:
	if index < 0:
		return
	var id: String = GameState.pots[index]
	if id != "":
		main.play_seed(id)


func _on_unplant(index: int) -> void:
	if index < 0:
		return
	GameState.unplant(index)
	selected_pot = -1
	_refresh_all()
	sunday.say("Seed back in the tray. Nothing is ever lost here.")


func _tutorial_line() -> void:
	if GameState.should_nudge_break():
		sunday.say("You've played for 90 minutes. Real hours matter too: stretch, drink water. Come back tomorrow for a bonus seed!")
		return
	match GameState.tutorial_step:
		0:
			sunday.say("Hi! I'm Sunday, an hour that escaped. Drag a seed from the tray onto a pot to plant it.")
		1:
			sunday.say("It's sprouting! Tap the pot, then Bloom ▶ to step inside that hour.")
		2:
			sunday.say("You gave an hour back! Secret: drop a Racing seed onto a Rhythm pot and see what grows.")
		_:
			var tips := [
				"Every hour you return lights more windows in the city. Look!",
				"Beat your best stars to earn more Light.",
				"Check Ira's Notebook to see whose hours are still waiting.",
				"Grafted worlds play by two sets of rules at once.",
			]
			sunday.say(tips[randi() % tips.size()])
