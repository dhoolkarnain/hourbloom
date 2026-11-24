extends GenreBase
## Racing world: glide through the sky-tram lanes, catch Light orbs, dodge Warden drones.
## Graft mode "beat" (Racing x Rhythm): everything arrives on the beat and the track
## only appears on the beat.
## Controls: tap left/right half, swipe, or arrow keys / A D.

const LANES := 3
const LANE_GAP := 190.0
const PLAYER_Y_FROM_BOTTOM := 150.0

var duration := 40.0
var elapsed := 0.0
var speed := 420.0
var lane := 1
var player_x := 0.0
var objects: Array = []      # {lane, y, kind: "orb"/"drone", hit: bool}
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
var _scroll := 0.0
var _shake := 0.0
var _swipe_start := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _pending_spawns: Array = []  # beat mode: {arrive_t, lane, kind}
var _streak := 0


func intro_hint() -> String:
	if mode == "beat":
		return "Graft! The track only appears on the beat"
	return "Tap left / right to change lanes"


func setup_world() -> void:
	beat_mode = mode == "beat"
	_rng.seed = hash(seed_id)
	duration = 34.0 if assist else 40.0
	speed = 380.0 if assist else 420.0
	beat_len = 60.0 / bpm


func on_start() -> void:
	player_x = _lane_x(lane)


func _lane_x(l: int) -> float:
	return size.x / 2.0 + (l - 1) * LANE_GAP


func _player_y() -> float:
	return size.y - PLAYER_Y_FROM_BOTTOM


func tick(delta: float) -> void:
	elapsed += delta
	var t_ratio := elapsed / duration
	speed = lerpf(380.0 if assist else 420.0, 720.0 * difficulty, t_ratio)
	_scroll = fmod(_scroll + speed * delta, 80.0)
	_shake = maxf(0.0, _shake - delta * 3.0)
	_beat_glow = maxf(0.0, _beat_glow - delta * 2.5)
	player_x = lerpf(player_x, _lane_x(lane), minf(1.0, delta * 14.0))

	if beat_mode:
		var beat := int(floor(elapsed / beat_len))
		if beat != _last_beat:
			_last_beat = beat
			_beat_glow = 1.0
			Sfx.play("beat_soft" if beat % 4 else "beat")
		_spawn_beat_mode()
	else:
		spawn_timer -= delta
		if spawn_timer <= 0.0 and elapsed < duration - 2.0:
			spawn_timer = _rng.randf_range(0.45, 0.8) / difficulty
			_spawn(_rng.randi_range(0, LANES - 1), "orb" if _rng.randf() < 0.55 else "drone", -40.0)

	for o in objects:
		o.y += speed * delta
		if not o.hit and o.lane == lane and absf(o.y - _player_y()) < 42.0:
			o.hit = true
			_collide(o)
	objects = objects.filter(func(o): return o.y < size.y + 60 and not (o.hit and o.kind == "orb"))

	if hearts <= 0:
		finish(0, "Out of hearts at %d%% of the route. Orbs %d/%d" % [int(t_ratio * 100), orbs_caught, orbs_total])
	elif elapsed >= duration:
		_end()


## Beat mode: schedule objects so they reach the player exactly on a beat.
func _spawn_beat_mode() -> void:
	var dist := _player_y() + 40.0
	var travel_t := dist / speed
	var next_beat: float = ceil((elapsed + travel_t) / beat_len)
	var arrive: float = next_beat * beat_len
	if arrive > duration - 1.0:
		return
	if _pending_spawns.has(int(next_beat)):
		return
	_pending_spawns.append(int(next_beat))
	if int(next_beat) % 2 == 0 or _rng.randf() < 0.35 * difficulty:
		var kind := "orb" if _rng.randf() < 0.6 else "drone"
		var y: float = _player_y() - (arrive - elapsed) * speed
		_spawn(_rng.randi_range(0, LANES - 1), kind, y)


func _spawn(l: int, kind: String, y: float) -> void:
	# Fairness: never place a drone where it would block every lane.
	if kind == "orb":
		orbs_total += 1
	objects.append({"lane": l, "y": y, "kind": kind, "hit": false})


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
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_LEFT, KEY_A]:
			move(-1)
		elif event.keycode in [KEY_RIGHT, KEY_D]:
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
	var py := _player_y()
	var danger := {}
	var best_lane := lane
	var best_y := -INF
	for o in objects:
		if o.hit or o.y > py + 30 or o.y < py - 420:
			continue
		if o.kind == "drone":
			danger[o.lane] = true
		elif o.y > best_y:
			best_y = o.y
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
	var off := Vector2(randf_range(-6, 6), randf_range(-6, 6)) * _shake
	var track_alpha := 0.9
	if beat_mode:
		track_alpha = 0.08 + _beat_glow * 0.9  # the track only appears on the beat
	# lanes
	for l in LANES:
		var x := _lane_x(l) + off.x
		draw_rect(Rect2(x - LANE_GAP / 2 + 8, 70, LANE_GAP - 16, size.y - 70), Color(0, 0, 0, 0.16))
		var y := -80.0 + _scroll
		while y < size.y:
			draw_rect(Rect2(x - 3, y + 70, 6, 36), Color(1, 0.95, 0.8, 0.35 * track_alpha))
			y += 80.0
	for l in LANES + 1:
		var bx := size.x / 2.0 + (l - 1.5) * LANE_GAP + off.x
		draw_line(Vector2(bx, 70), Vector2(bx, size.y), Color(UI.GOLD, 0.55 * track_alpha), 3.0)
	# objects
	for o in objects:
		var p := Vector2(_lane_x(o.lane), o.y) + off
		if o.kind == "orb":
			draw_circle(p, 26, Color(UI.GOLD, 0.25))
			draw_circle(p, 16, UI.GOLD)
			draw_circle(p + Vector2(-4, -4), 6, Color(1, 1, 1, 0.7))
		else:
			# Warden drone: polite, round, in the way
			draw_rect(Rect2(p - Vector2(30, 18), Vector2(60, 36)), UI.CORAL)
			draw_circle(p + Vector2(0, -2), 9, Color("#2b2540"))
			draw_circle(p + Vector2(0, -2), 4, Color("#ffeeee"))
			draw_line(p + Vector2(-38, -20), p + Vector2(-22, -20), Color("#ffd0c8"), 3)
			draw_line(p + Vector2(22, -20), p + Vector2(38, -20), Color("#ffd0c8"), 3)
	# Ira on her glider
	var pp := Vector2(player_x, _player_y()) + off
	draw_colored_polygon(PackedVector2Array([pp + Vector2(0, -34), pp + Vector2(30, 22), pp + Vector2(-30, 22)]), Color("#fff7e8"))
	draw_circle(pp + Vector2(0, -6), 10, Color("#2b2540"))
	draw_line(pp + Vector2(4, -10), pp + Vector2(26, 6 + sin(elapsed * 12.0) * 4), Color("#ff8a5c"), 4)
	# HUD
	var hud := "✦ %d   " % orbs_caught
	for i in 3:
		hud += "♥" if i < hearts else "♡"
	draw_string(ThemeDB.fallback_font, Vector2(30, 112), hud, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UI.INK)
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	draw_rect(Rect2(30, 128, 220, 8), Color(1, 1, 1, 0.2))
	draw_rect(Rect2(30, 128, 220 * progress, 8), UI.GOLD)
