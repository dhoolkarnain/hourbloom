extends GenreBase
## Rhythm world (3D): gem notes glide down four lanes toward the pads.
## Every hit plants a flower along the track, so the world blooms as you play.
## Controls: tap a quarter of the screen, or keys D F J K / arrow keys.

const LANES := 4
const LANE_SPACING := 1.5
const TRACK_LEN := 26.0
const PERFECT := 0.07
const GOOD := 0.15
const LANE_COLORS := [Color("#b07cff"), Color("#4fd1c5"), Color("#ffd36b"), Color("#ff8a5c")]
const LANE_PITCH := [0.8, 1.0, 1.2, 1.5]
const MAX_FLOWERS := 70

var bpm := 100.0
var beat_len := 0.6
var travel := 1.5
var lead_in := 2.0
var song_t := 0.0
var notes: Array = []          # {t, lane, state: 0 waiting / 1 hit / 2 missed, node}
var perfect := 0
var good := 0
var miss := 0
var combo := 0
var best_combo := 0
var _last_beat := -1
var _pulse := 0.0
var _lane_flash := [0.0, 0.0, 0.0, 0.0]
var _judge_text := ""
var _judge_age := 9.0
var _pads: Array[Node3D] = []
var _flowers: Array = []       # {node, age, size}
var _sun: DirectionalLight3D
var _rng := RandomNumberGenerator.new()
var _gem_pools: Array[Pool] = []


func intro_hint() -> String:
	return "Tap the lanes on the beat"


func setup_world() -> void:
	bpm = 96.0 if seed.emotion == "calm" else 104.0
	beat_len = 60.0 / bpm
	travel = 2.1 if assist else 1.5
	_rng.seed = hash(seed_id) + 1
	_make_chart()
	_build_track()
	for i in LANES:
		var color: Color = LANE_COLORS[i]
		var pool := Pool.new("note", world, func(n): Stage.tint(n, "Gem", color, 0.9))
		pool.prewarm(4)
		_gem_pools.append(pool)
	camera.position = Vector3(0, 4.6, 6.2)
	camera.look_at(Vector3(0, 0, -7.0))
	_sun = world.get_node("Sun")


func _lane_x(lane: int) -> float:
	return (lane - (LANES - 1) / 2.0) * LANE_SPACING


func _build_track() -> void:
	var track := Node3D.new()
	world.add_child(track)
	var floor_mesh := Stage.box(Vector3(LANE_SPACING * LANES + 0.6, 0.1, TRACK_LEN + 4), Color("#251f3d"))
	floor_mesh.position = Vector3(0, -0.05, -TRACK_LEN / 2.0 + 1.5)
	track.add_child(floor_mesh)
	for i in LANES:
		var strip := Stage.box(Vector3(LANE_SPACING - 0.12, 0.02, TRACK_LEN + 3), LANE_COLORS[i], 0.15, 0.35)
		strip.position = Vector3(_lane_x(i), 0.02, -TRACK_LEN / 2.0 + 1.5)
		track.add_child(strip)
		var pad := Stage.model("pad")
		pad.position = Vector3(_lane_x(i), 0.03, 0)
		Stage.tint(pad, "Pad", LANE_COLORS[i], 0.6)
		track.add_child(pad)
		_pads.append(pad)
	var hit_line := Stage.box(Vector3(LANE_SPACING * LANES, 0.04, 0.06), Color.WHITE, 1.5)
	hit_line.position = Vector3(0, 0.08, -0.55)
	track.add_child(hit_line)
	# The owner's city in the distance.
	Stage.city(world, GameState.bloom_ratio(), Vector3(0, 0, -6), 14.0, 44.0, 40, -3.0)


func _make_chart() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_id)
	var beats := 32
	var last_lane := -1
	for b in beats:
		var t := lead_in + b * beat_len
		var lane := rng.randi_range(0, LANES - 1)
		if lane == last_lane:
			lane = (lane + 1 + rng.randi_range(0, 1)) % LANES
		last_lane = lane
		notes.append({"t": t, "lane": lane, "state": 0, "node": null})
		if not assist and b >= 12 and rng.randf() < 0.28 * difficulty:
			notes.append({"t": t + beat_len * 0.5, "lane": (lane + 2) % LANES, "state": 0, "node": null})
	notes.sort_custom(func(a, b): return a.t < b.t)


func music_track() -> String:
	return "world:%d" % int(bpm)


func on_start() -> void:
	song_t = 0.0


func tick(delta: float) -> void:
	song_t += delta
	var beat := int(floor((song_t - lead_in) / beat_len))
	if song_t >= lead_in - 0.001 and beat != _last_beat and beat >= 0:
		_last_beat = beat
		_pulse = 1.0
		Sfx.play("beat_soft" if beat % 4 else "beat")
	_pulse = maxf(0.0, _pulse - delta * 3.0)
	_judge_age += delta
	for i in LANES:
		_lane_flash[i] = maxf(0.0, _lane_flash[i] - delta * 4.0)
		var s: float = 1.0 + _lane_flash[i] * 0.25 + _pulse * 0.05
		_pads[i].scale = Vector3(s, 1.0, s)
	if _sun:
		_sun.light_energy = 1.1 + _pulse * 0.35

	for n in notes:
		if n.state == 0 and song_t - n.t > GOOD:
			n.state = 2
			miss += 1
			combo = 0
			_judge("Miss")
		_place_note(n)
	for f in _flowers:
		f.age += delta
		var grow: float = clampf(f.age / 0.35, 0.0, 1.0)
		f.node.scale = Vector3.ONE * f.size * (1.0 - pow(1.0 - grow, 3.0))
	if notes.size() > 0 and song_t > notes[-1].t + 1.2:
		_end()


## Creates, moves or removes the 3D gem for a note.
func _place_note(n: Dictionary) -> void:
	var dt: float = n.t - song_t
	var visible_now: bool = n.state == 0 and dt <= travel and dt >= -GOOD
	if visible_now and n.node == null:
		n.node = _gem_pools[n.lane].acquire()
		n.node.position = Vector3(_lane_x(n.lane), 0.45, -TRACK_LEN)
		Pool.teleported(n.node)
	if n.node != null:
		if not visible_now:
			_gem_pools[n.lane].release(n.node)
			n.node = null
			return
		var z: float = -dt / travel * TRACK_LEN
		n.node.position = Vector3(_lane_x(n.lane), 0.45, z)
		n.node.rotation.y = song_t * 2.0


func _input(event: InputEvent) -> void:
	if not running or finished:
		return
	for i in LANES:
		if Controls.pressed(event, "lane_%d" % (i + 1)):
			press_lane(i)
			return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.position.y < 80:
			return  # header area
		# Big thumb-friendly targets: each quarter of the screen is one lane.
		var lane := clampi(int(event.position.x / (size.x / LANES)), 0, LANES - 1)
		press_lane(lane)


func press_lane(lane: int) -> void:
	_lane_flash[lane] = 1.0
	var best: Dictionary = {}
	var best_dt := 99.0
	for n in notes:
		if n.state == 0 and n.lane == lane:
			var dt: float = absf(n.t - song_t)
			if dt < best_dt:
				best_dt = dt
				best = n
	if best.is_empty() or best_dt > GOOD:
		return  # tapping empty air is never punished
	best.state = 1
	if best.node:
		_gem_pools[lane].release(best.node)
		best.node = null
	combo += 1
	best_combo = maxi(best_combo, combo)
	if best_dt <= PERFECT:
		perfect += 1
		_judge("Perfect")
		Sfx.play("perfect", LANE_PITCH[lane])
	else:
		good += 1
		_judge("Good")
		Sfx.play("good", LANE_PITCH[lane])
	GameState.haptic(12)
	_plant_flower(lane)


## The world blooms: a flower grows beside the track for every hit.
func _plant_flower(lane: int) -> void:
	var f := Stage.model("flower")
	Stage.tint(f, "Petals", LANE_COLORS[lane], 0.25)
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var x := side * _rng.randf_range(LANE_SPACING * 2.6, LANE_SPACING * 2.6 + 3.5)
	f.position = Vector3(x, 0, _rng.randf_range(-TRACK_LEN, 1.0))
	f.rotation.y = _rng.randf_range(0, TAU)
	f.scale = Vector3.ONE * 0.01
	world.add_child(f)
	_flowers.append({"node": f, "age": 0.0, "size": _rng.randf_range(0.9, 1.6)})
	if _flowers.size() > MAX_FLOWERS:
		_flowers.pop_front().node.queue_free()


func _judge(text: String) -> void:
	_judge_text = text
	_judge_age = 0.0


func _end() -> void:
	var total := notes.size()
	var acc := (perfect + good * 0.6) / float(max(1, total))
	var s := 0
	if acc >= 0.9:
		s = 3
	elif acc >= 0.7:
		s = 2
	elif acc >= 0.4:
		s = 1
	finish(s, "Perfect %d · Good %d · Miss %d · Best combo %d" % [perfect, good, miss, best_combo])


## Test hook: auto-play perfectly (used by automated tests).
func autoplay_step() -> void:
	for n in notes:
		if n.state == 0 and absf(n.t - song_t) <= PERFECT:
			press_lane(n.lane)


func _draw() -> void:
	# 2D HUD over the 3D world.
	if _judge_age < 0.6:
		var col := UI.GOLD if _judge_text == "Perfect" else (UI.TEAL if _judge_text == "Good" else UI.CORAL)
		var w := 300.0
		draw_string(ThemeDB.fallback_font, Vector2(size.x / 2.0 - w / 2.0, size.y * 0.33), _judge_text, HORIZONTAL_ALIGNMENT_CENTER, w, 40, Color(col, 1.0 - _judge_age / 0.6))
	if combo >= 3:
		draw_string(ThemeDB.fallback_font, Vector2(size.x - 230, 120), "%d combo" % combo, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UI.INK)
	var progress := clampf(song_t / maxf(1.0, notes[-1].t + 1.2), 0.0, 1.0) if notes.size() > 0 else 0.0
	draw_rect(Rect2(30, 96, 260, 8), Color(1, 1, 1, 0.2))
	draw_rect(Rect2(30, 96, 260 * progress, 8), UI.GOLD)
	var keys := ["D", "F", "J", "K"]
	for i in LANES:
		var x := size.x / LANES * (i + 0.5)
		draw_string(ThemeDB.fallback_font, Vector2(x - 10, size.y - 24), keys[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.55))
