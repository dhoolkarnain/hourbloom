extends GenreBase
## Racing world (3D): Ira's glider flies three sky lanes above Velmora.
## Catch Light orbs, dodge Warden drones.
## Graft mode "beat" (Racing x Rhythm): everything arrives on the beat and the
## golden track only appears on the beat.
## Controls: tap left/right half, swipe, or arrow keys / A D.

const LANES := 3
const LANE_GAP := 2.3
const SPAWN_Z := -70.0
const HIT_RANGE := 0.9

var duration := 40.0
var elapsed := 0.0
var speed := 18.0
var lane := 1
var objects: Array = []      # {lane, z, kind: "orb"/"drone", hit, node}
var spawn_timer := 0.0
var orbs_total := 0
var orbs_caught := 0
var hearts := 3
var hits := 0
var beat_mode := false
var bpm := 110.0
var beat_len := 0.545
var _last_beat := -1
var _beat_glow := 0.0
var _shake := 0.0
var _swipe_start := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _scheduled: Dictionary = {}  # beat mode: beats already given an object
var _streak := 0
var _glider: Node3D
var _rails: Array[MeshInstance3D] = []
var _rail_mats: Array[StandardMaterial3D] = []
var _dashes: Array[Node3D] = []
var _scenery: Array[Node3D] = []
var _cam_base := Vector3(0, 2.7, 5.6)
var _orb_pool: Pool
var _drone_pool: Pool
var _glider_shadow: MeshInstance3D


func intro_hint() -> String:
	if mode == "beat":
		return "Graft! The track only appears on the beat"
	return "Tap left / right to change lanes"


func setup_world() -> void:
	beat_mode = mode == "beat"
	_rng.seed = hash(seed_id)
	duration = 34.0 if assist else 40.0
	speed = _base_speed()
	beat_len = 60.0 / bpm
	_build_sky_road()
	_orb_pool = Pool.new("orb", world)
	_drone_pool = Pool.new("drone", world, func(n): n.rotation.y = PI)
	_orb_pool.prewarm(8)
	_drone_pool.prewarm(6)
	camera.position = _cam_base
	camera.look_at(Vector3(0, 0.4, -8))


func _base_speed() -> float:
	return 15.0 if assist else 18.0


func music_track() -> String:
	return "world:%d" % int(bpm if mode == "beat" else 90)


func _lane_x(l: int) -> float:
	return (l - 1) * LANE_GAP


func _build_sky_road() -> void:
	# Golden rails between the lanes.
	for i in LANES + 1:
		var x := (i - 1.5) * LANE_GAP
		var rail := Stage.box(Vector3(0.08, 0.05, 90.0), UI.GOLD, 2.0)
		rail.position = Vector3(x, -0.4, -40.0)
		world.add_child(rail)
		_rails.append(rail)
		_rail_mats.append(rail.material_override)
	# Moving lane dashes give a sense of speed.
	for i in 30:
		var d := Stage.box(Vector3(0.12, 0.03, 1.2), Color("#fff4cf"), 1.2)
		d.position = Vector3(_lane_x(i % LANES), -0.42, -i * 3.0)
		world.add_child(d)
		_dashes.append(d)
	# The city far below, scrolling past.
	var kinds := ["tower_a", "tower_b", "tower_c"]
	for i in 26:
		var t := Stage.model(kinds[i % 3])
		var side := -1.0 if i % 2 == 0 else 1.0
		t.position = Vector3(side * _rng.randf_range(7.0, 18.0), -14.0 + _rng.randf_range(-2, 3), -i * 4.0)
		t.scale = Vector3.ONE * _rng.randf_range(1.0, 1.8)
		Stage.set_part_visible(t, "Windows", _rng.randf() < 0.3 + GameState.bloom_ratio())
		world.add_child(t)
		_scenery.append(t)
	_glider = Stage.model("glider")
	_glider.position = Vector3(_lane_x(lane), 0, 0)
	_glider.rotation.y = PI  # face down the road (-Z)
	world.add_child(_glider)
	_glider_shadow = Stage.blob_shadow(0.7)
	_glider_shadow.position = Vector3(_lane_x(lane), -0.41, 0)
	world.add_child(_glider_shadow)


func tick(delta: float) -> void:
	elapsed += delta
	var t_ratio := elapsed / duration
	speed = lerpf(_base_speed(), 30.0 * difficulty, t_ratio)
	_shake = maxf(0.0, _shake - delta * 3.0)
	_beat_glow = maxf(0.0, _beat_glow - delta * 2.5)

	# glider: slide between lanes, bank into the turn, bob gently
	var target_x := _lane_x(lane)
	var dx := target_x - _glider.position.x
	_glider.position.x += dx * minf(1.0, delta * 12.0)
	_glider.position.y = sin(elapsed * 3.0) * 0.08
	_glider.rotation.z = clampf(dx * 0.35, -0.6, 0.6)
	_glider_shadow.position.x = _glider.position.x
	# Camera feel: FOV widens with speed.
	camera.fov = lerpf(60.0, 74.0, clampf((speed - _base_speed()) / 14.0, 0.0, 1.0))
	camera.position = _cam_base + Vector3(_glider.position.x * 0.35, 0, 0) + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.12 * _shake

	for d in _dashes:
		d.position.z += speed * delta
		if d.position.z > 6.0:
			d.position.z -= 90.0
	for s in _scenery:
		s.position.z += speed * 0.35 * delta
		if s.position.z > 12.0:
			s.position.z -= 104.0

	if beat_mode:
		var beat := int(floor(elapsed / beat_len))
		if beat != _last_beat:
			_last_beat = beat
			_beat_glow = 1.0
			Sfx.play("beat_soft" if beat % 4 else "beat")
		_spawn_beat_mode()
		for m in _rail_mats:
			m.albedo_color.a = 0.05 + _beat_glow * 0.95  # the track only appears on the beat
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.emission_energy_multiplier = 0.2 + _beat_glow * 3.0
		for d in _dashes:
			d.visible = _beat_glow > 0.35
	else:
		spawn_timer -= delta
		if spawn_timer <= 0.0 and elapsed < duration - 2.0:
			spawn_timer = _rng.randf_range(0.45, 0.8) / difficulty
			_spawn(_rng.randi_range(0, LANES - 1), "orb" if _rng.randf() < 0.55 else "drone", SPAWN_Z)

	for o in objects:
		o.z += speed * delta
		o.node.position.z = o.z
		if o.kind == "orb":
			o.node.rotation.y += delta * 3.0
		else:
			o.node.position.y = 0.2 + sin(elapsed * 4.0 + o.z) * 0.15
		if not o.hit and o.lane == lane and absf(o.z) < HIT_RANGE:
			o.hit = true
			_collide(o)
	for o in objects:
		if o.z > 8.0 or (o.hit and o.kind == "orb"):
			(_orb_pool if o.kind == "orb" else _drone_pool).release(o.node)
	objects = objects.filter(func(o): return o.z <= 8.0 and not (o.hit and o.kind == "orb"))

	if hearts <= 0:
		finish(0, "Out of hearts at %d%% of the route. Orbs %d/%d" % [int(t_ratio * 100), orbs_caught, orbs_total])
	elif elapsed >= duration:
		_end()


## Beat mode: schedule objects so they reach the glider exactly on a beat.
func _spawn_beat_mode() -> void:
	var travel_t := -SPAWN_Z / speed
	var next_beat := int(ceil((elapsed + travel_t) / beat_len))
	var arrive: float = next_beat * beat_len
	if arrive > duration - 1.0 or _scheduled.has(next_beat):
		return
	_scheduled[next_beat] = true
	if next_beat % 2 == 0 or _rng.randf() < 0.35 * difficulty:
		var kind := "orb" if _rng.randf() < 0.6 else "drone"
		var z: float = -(arrive - elapsed) * speed
		_spawn(_rng.randi_range(0, LANES - 1), kind, z)


func _spawn(l: int, kind: String, z: float) -> void:
	if kind == "orb":
		orbs_total += 1
	var node := (_orb_pool if kind == "orb" else _drone_pool).acquire()
	node.position = Vector3(_lane_x(l), 0.3 if kind == "orb" else 0.2, z)
	if kind == "drone":
		node.rotation.y = PI  # look at the player
	Pool.teleported(node)
	objects.append({"lane": l, "z": z, "kind": kind, "hit": false, "node": node})


func _collide(o: Dictionary) -> void:
	if o.kind == "orb":
		orbs_caught += 1
		_streak += 1
		Sfx.play("orb", 1.0 + minf(_streak, 8) * 0.04)
		GameState.haptic(10)
		if beat_mode and _streak % 4 == 0:
			flash("On beat ×%d!" % _streak, 0.3)
	else:
		hearts -= 1
		hits += 1
		_streak = 0
		_shake = 1.0
		Sfx.play("hit")
		GameState.haptic(80)
		hit_stop(0.08)
		var tw := create_tween()
		tw.tween_property(o.node, "scale", Vector3.ONE * 0.01, 0.25)


func _end() -> void:
	var r := float(orbs_caught) / float(max(1, orbs_total))
	var score := r - hits * 0.12
	var s := 1
	if score >= 0.75:
		s = 3
	elif score >= 0.5:
		s = 2
	finish(s, "Orbs %d/%d · Hits %d" % [orbs_caught, orbs_total, hits])


func move(dir: int) -> void:
	var nl := clampi(lane + dir, 0, LANES - 1)
	if nl != lane:
		lane = nl
		Sfx.play("tap", 1.2)


func _input(event: InputEvent) -> void:
	if not running or finished:
		return
	if Controls.pressed(event, "move_left"):
		move(-1)
	elif Controls.pressed(event, "move_right"):
		move(1)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.position.y < 80:
			return
		if event.pressed:
			_swipe_start = event.position
		else:
			var d: Vector2 = event.position - _swipe_start
			if absf(d.x) > 40.0:
				move(1 if d.x > 0 else -1)
			else:
				move(1 if event.position.x > size.x / 2.0 else -1)


## Test hook: steer toward the nearest orb and away from drones.
func autoplay_step() -> void:
	var danger := {}
	var best_lane := lane
	var best_z := -INF
	for o in objects:
		if o.hit or o.z > 1.0 or o.z < -16.0:
			continue
		if o.kind == "drone":
			danger[o.lane] = true
		elif o.z > best_z:
			best_z = o.z
			best_lane = o.lane
	var target := best_lane
	if danger.has(target):
		for l in LANES:
			if not danger.has(l):
				target = l
				break
	if target != lane:
		move(signi(target - lane))


func _draw() -> void:
	var hud := "✦ %d   " % orbs_caught
	for i in 3:
		hud += "♥" if i < hearts else "♡"
	draw_string(ThemeDB.fallback_font, Vector2(30, 112), hud, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UI.INK)
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	draw_rect(Rect2(30, 128, 220, 8), Color(1, 1, 1, 0.2))
	draw_rect(Rect2(30, 128, 220 * progress, 8), UI.GOLD)
