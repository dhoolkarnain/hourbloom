class_name Stage
## 3D helpers shared by every scene: golden-hour sky, sun, fog, models from
## Blender (.glb), tinting, and the Velmora skyline that warms up as hours return.

const MODELS := "res://assets/models/%s.glb"

static var _cache: Dictionary = {}


## Builds sky + light for a scene. bloom 0..1: grey Scheduled city -> warm golden hour.
static func setup(parent: Node, bloom: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Stage"
	parent.add_child(root)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#3b4256").lerp(Color("#2f2552"), bloom)
	sky_mat.sky_horizon_color = Color("#8a93a6").lerp(Color("#ff9e6b"), bloom)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = Color("#2a2a38").lerp(Color("#3a2440"), bloom)
	sky_mat.sun_angle_max = 20.0
	sky_mat.sky_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = sky_mat.sky_horizon_color
	env.fog_density = 0.0035
	env.fog_sun_scatter = 0.25 * bloom
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("#c9d3e6").lerp(Color("#ffc58a"), bloom)
	sun.light_energy = 1.35
	sun.rotation_degrees = Vector3(-28, -35, 0)  # low golden-hour sun
	# Real-time shadows are expensive on phones: off on mobile and in battery saver;
	# blob shadows (below) ground the objects instead.
	sun.shadow_enabled = GameState.shadows_enabled()
	sun.directional_shadow_max_distance = 40.0
	root.add_child(sun)
	return root


static func model(name: String) -> Node3D:
	if not _cache.has(name):
		_cache[name] = load(MODELS % name)
	var scene: PackedScene = _cache[name]
	return scene.instantiate()


static func flat_material(color: Color, emission := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, alpha)
	m.roughness = 0.6
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## Recolours one named part of a Blender model (e.g. a flower's "Petals").
static func tint(node: Node, part: String, color: Color, emission := 0.0) -> void:
	var mi := node.find_child(part, true, false)
	if mi is MeshInstance3D:
		mi.material_override = flat_material(color, emission)


static func set_part_visible(node: Node, part: String, on: bool) -> void:
	var n := node.find_child(part, true, false)
	if n is Node3D:
		n.visible = on


static func box(size: Vector3, color: Color, emission := 0.0, alpha := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = flat_material(color, emission, alpha)
	return mi


static func label3d(text: String, size := 48, color := Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.006
	l.modulate = color
	l.outline_size = 10
	l.outline_modulate = Color(0.1, 0.08, 0.16, 0.85)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	return l


## The Velmora skyline. Towers light their windows as hours return home.
static func city(parent: Node3D, bloom: float, center := Vector3.ZERO, inner := 9.0, outer := 34.0, count := 46, base_y := -0.5) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var towers: Array = []
	var kinds := ["tower_a", "tower_b", "tower_c"]
	for i in count:
		var t := model(kinds[i % 3])
		var ang := rng.randf_range(-PI * 0.95, -PI * 0.05)  # behind the camera's view centre
		var dist := rng.randf_range(inner, outer)
		t.position = center + Vector3(cos(ang) * dist, base_y - rng.randf_range(0.0, 2.5), sin(ang) * dist)
		t.rotation.y = rng.randf_range(0, TAU)
		var s := rng.randf_range(0.7, 1.2)
		t.scale = Vector3(s, s * rng.randf_range(0.8, 1.3), s)
		set_part_visible(t, "Windows", float(i) / count < bloom + 0.08)
		_limit_draw_distance(t, 70.0)
		parent.add_child(t)
		towers.append(t)
	return towers


## Cheap fake shadow: a dark transparent disc on the ground under an object.
static func blob_shadow(radius: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.01
	cyl.radial_segments = 20
	cyl.rings = 1
	mi.mesh = cyl
	var m := flat_material(Color(0.05, 0.03, 0.1), 0.0, 0.35)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Far objects stop drawing beyond `dist` metres (LOD / frustum budget).
static func _limit_draw_distance(node: Node, dist: float) -> void:
	for ch in node.get_children():
		if ch is GeometryInstance3D:
			ch.visibility_range_end = dist
			ch.visibility_range_end_margin = 6.0
			ch.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		_limit_draw_distance(ch, dist)


## Ray from the camera through a screen point, hitting the horizontal plane y = h.
static func screen_to_plane(cam: Camera3D, screen_pos: Vector2, h: float) -> Variant:
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return null
	var t := (h - from.y) / dir.y
	if t < 0.0:
		return null
	return from + dir * t
