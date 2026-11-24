extends GenreBase
## Rhythm world: tap the 4 lanes as notes reach the line. The music builds itself as you play.
## Controls: tap a lane pad (thumb zone) or keys D F J K / arrow keys.

const LANES := 4
const LANE_W := 150.0
const PERFECT := 0.07
const GOOD := 0.15
const LANE_COLORS := [Color("#b07cff"), Color("#4fd1c5"), Color("#ffd36b"), Color("#ff8a5c")]
const LANE_PITCH := [0.8, 1.0, 1.2, 1.5]

var bpm := 100.0
var beat_len := 0.6
var travel := 1.5
var lead_in := 2.0
var song_t := -0.0
var notes: Array = []          # {t, lane, state: 0 waiting / 1 hit / 2 missed}
var perfect := 0
var good := 0
var miss := 0
var combo := 0
var best_combo := 0
var _last_beat := -1
var _pulse := 0.0
var _blooms: Array = []        # visual flowers {pos, age, color}
var _lane_flash := [0.0, 0.0, 0.0, 0.0]
var _judge_text := ""
var _judge_age := 9.0


func intro_hint() -> String:
	return "Tap the lanes on the beat"


func setup_world() -> void:
	bpm = 96.0 if seed.emotion == "calm" else 104.0
	beat_len = 60.0 / bpm
	travel = 2.1 if assist else 1.5
	song_t = -intro_time
	_make_chart()


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
		notes.append({"t": t, "lane": lane, "state": 0})
		# off-beat notes appear in the second half, more for harder emotions
		if not assist and b >= 12 and rng.randf() < 0.28 * difficulty:
			notes.append({"t": t + beat_len * 0.5, "lane": (lane + 2) % LANES, "state": 0})
	notes.sort_custom(func(a, b): return a.t < b.t)


func _lanes_left() -> float:
	return size.x / 2.0 - LANE_W * LANES / 2.0


func _hit_y() -> float:
	return size.y - 150.0


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
	for b in _blooms:
		b.age += delta
	_blooms = _blooms.filter(func(b): return b.age < 1.2)

	for n in notes:
		if n.state == 0 and song_t - n.t > GOOD:
			n.state = 2
			miss += 1
			combo = 0
			_judge("Miss", UI.CORAL)
	if notes.size() > 0 and song_t > notes[-1].t + 1.2:
		_end()


func on_start() -> void:
	song_t = 0.0


func _input(event: InputEvent) -> void:
	if not running or finished:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var map := {KEY_D: 0, KEY_F: 1, KEY_J: 2, KEY_K: 3, KEY_LEFT: 0, KEY_DOWN: 1, KEY_UP: 2, KEY_RIGHT: 3}
		if map.has(event.keycode):
			press_lane(map[event.keycode])
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.position.y < 80:
			return  # header area
		var lane := int(floor((event.position.x - _lanes_left()) / LANE_W))
		if lane >= 0 and lane < LANES:
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
	combo += 1
	best_combo = maxi(best_combo, combo)
	if best_dt <= PERFECT:
		perfect += 1
		_judge("Perfect", UI.GOLD)
		Sfx.play("perfect", LANE_PITCH[lane])
	else:
		good += 1
		_judge("Good", UI.TEAL)
		Sfx.play("good", LANE_PITCH[lane])
	GameState.haptic(12)
	var x := _lanes_left() + LANE_W * (lane + 0.5)
	_blooms.append({"pos": Vector2(x + randf_range(-60, 60), _hit_y() - randf_range(60, 300)), "age": 0.0, "color": LANE_COLORS[lane]})


func _judge(text: String, _c: Color) -> void:
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
	var left := _lanes_left()
	var hy := _hit_y()
	# glow that pulses on the beat
	draw_rect(Rect2(left - 20, 70, LANE_W * LANES + 40, size.y - 70), Color(1, 0.85, 0.5, 0.05 + _pulse * 0.07))
	for i in LANES:
		var x := left + LANE_W * i
		draw_rect(Rect2(x + 4, 70, LANE_W - 8, size.y - 70), Color(0, 0, 0, 0.18))
		draw_rect(Rect2(x + 4, 70, LANE_W - 8, size.y - 70), Color(LANE_COLORS[i], 0.12 * _lane_flash[i]))
	# blooms grown by the player's hits
	for b in _blooms:
		var a: float = 1.0 - b.age / 1.2
		var r: float = 10.0 + b.age * 40.0
		for k in 5:
			var ang: float = TAU * k / 5.0 + b.age
			draw_circle(b.pos + Vector2(cos(ang), sin(ang)) * r * 0.6, r * 0.45, Color(b.color, 0.35 * a))
		draw_circle(b.pos, r * 0.3, Color(1, 0.96, 0.8, 0.6 * a))
	# hit line and pads (thumb zone)
	draw_line(Vector2(left, hy), Vector2(left + LANE_W * LANES, hy), Color(1, 1, 1, 0.6 + _pulse * 0.4), 3.0)
	var keys := ["D", "F", "J", "K"]
	for i in LANES:
		var cx := left + LANE_W * (i + 0.5)
		var pad_c: Color = LANE_COLORS[i]
		draw_circle(Vector2(cx, hy + 70), 44, Color(pad_c, 0.25 + _lane_flash[i] * 0.5))
		draw_arc(Vector2(cx, hy + 70), 44, 0, TAU, 32, pad_c, 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(cx - 7, hy + 78), keys[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.7))
	# notes
	for n in notes:
		if n.state != 0:
			continue
		var dt: float = n.t - song_t
		if dt > travel or dt < -GOOD:
			continue
		var y := hy - dt / travel * (hy - 80.0)
		var cx: float = left + LANE_W * (n.lane + 0.5)
		var c: Color = LANE_COLORS[n.lane]
		draw_circle(Vector2(cx, y), 30, Color(c, 0.3))
		draw_circle(Vector2(cx, y), 22, c)
		draw_circle(Vector2(cx - 6, y - 6), 7, Color(1, 1, 1, 0.6))
	# judgement + combo
	if _judge_age < 0.6:
		var col := UI.GOLD if _judge_text == "Perfect" else (UI.TEAL if _judge_text == "Good" else UI.CORAL)
		draw_string(ThemeDB.fallback_font, Vector2(left + LANE_W * LANES + 30, hy - 40), _judge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(col, 1.0 - _judge_age / 0.6))
	if combo >= 3:
		draw_string(ThemeDB.fallback_font, Vector2(left + LANE_W * LANES + 30, hy - 90), "%d combo" % combo, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UI.INK)
	var progress := clampf(song_t / maxf(1.0, notes[-1].t + 1.2), 0.0, 1.0) if notes.size() > 0 else 0.0
	draw_rect(Rect2(left, 72, LANE_W * LANES, 6), Color(1, 1, 1, 0.15))
	draw_rect(Rect2(left, 72, LANE_W * LANES * progress, 6), UI.GOLD)
