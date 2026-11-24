extends Screen
## Title (3D): the camera drifts around Ira's rooftop at golden hour.
## Two taps to play: the first bloom is reachable in under 60 seconds.

var camera: Camera3D
var _t := 0.0


func _ready() -> void:
	var world := Stage.setup(self, maxf(0.55, GameState.bloom_ratio()))
	world.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # hub animates per frame
	camera = Camera3D.new()
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # moved per frame
	camera.fov = 55.0
	world.add_child(camera)
	camera.current = true
	world.add_child(Stage.model("greenhouse"))
	Stage.city(world, maxf(0.5, GameState.bloom_ratio()), Vector3(0, 0, -4), 16.0, 48.0, 54, -14.0)
	var colors := [Color("#b07cff"), Color("#ff8a5c"), Color("#4fd1c5")]
	for i in 3:
		var pot := Stage.model("pot")
		pot.position = Vector3(-2.4 + i * 2.4, 0, -0.9)
		world.add_child(pot)
		var f := Stage.model("flower")
		f.position = pot.position + Vector3(0, 0.78, 0)
		f.scale = Vector3.ONE * 1.7
		Stage.tint(f, "Petals", colors[i], 0.35)
		world.add_child(f)
	var sunday := Stage.model("sunday")
	sunday.position = Vector3(0, 2.2, 1.4)
	sunday.name = "Sunday3D"
	sunday.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	world.add_child(sunday)
	_update_camera()
	Sfx.music("hub")

	# Dark band so the title reads clearly over the 3D scene.
	var shade := ColorRect.new()
	shade.color = Color(0.1, 0.08, 0.18, 0.45)
	UI.place(shade, Vector2(0.5, 0.5), Vector2(4000, 470))
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	UI.place(col, Vector2(0.5, 0.5), Vector2(620, 420))
	add_child(col)
	col.add_child(UI.label("HOURBLOOM", 76, UI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(UI.label("Grow the hours your city forgot, and play them.", 24, UI.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	col.add_child(spacer)
	var play_text := "Continue" if GameState.tutorial_step > 0 else "Begin"
	var play := UI.button(play_text, func(): go("greenhouse"), 30)
	play.custom_minimum_size = Vector2(0, 76)
	col.add_child(play)
	col.add_child(UI.button("Settings", func(): go("settings"), 22, true))

	var ver := UI.label("Prototype v%s" % ProjectSettings.get_setting("application/config/version"), 16, UI.INK_DIM)
	UI.place(ver, Vector2(0, 1), Vector2(300, 30), Vector2(24, -16))
	add_child(ver)


func _process(delta: float) -> void:
	_t += delta
	_update_camera()
	var s := find_child("Sunday3D", true, false)
	if s:
		s.position.y = 2.2 + sin(_t * 2.0) * 0.15
		s.rotation.y = _t * 0.6


func _update_camera() -> void:
	var a := -0.35 + sin(_t * 0.08) * 0.45
	camera.position = Vector3(sin(a) * 10.5, 4.2, cos(a) * 10.5)
	camera.look_at(Vector3(0, 1.2, 0))
