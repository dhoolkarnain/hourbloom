extends Node
## Procedural audio (autoload "Sfx"). Everything is synthesised at run time, so
## audio costs 0 bytes of storage.
## Mix hierarchy (game-audio guide): SFX -4 dB, UI -8 dB, Music -12 dB.
## Repeated sounds get small pitch variation; music ducks under big moments.

const MIX_RATE := 22050
const VOICES := 10
const BUSES := {"Music": -12.0, "SFX": -4.0, "UI": -8.0}
const UI_SOUNDS := ["tap", "rotate"]

var _sounds: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_cache: Dictionary = {}
var current_track := ""


func _ready() -> void:
	_setup_buses()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music_a = _music_player()
	_music_b = _music_player()
	_sounds["tap"] = _tone(660.0, 0.05, 0.25)
	_sounds["beat"] = _tone(220.0, 0.06, 0.35, true)
	_sounds["beat_soft"] = _tone(330.0, 0.04, 0.15, true)
	_sounds["perfect"] = _chord([880.0, 1320.0], 0.12, 0.25)
	_sounds["good"] = _tone(740.0, 0.08, 0.2)
	_sounds["miss"] = _tone(160.0, 0.12, 0.2)
	_sounds["orb"] = _chord([988.0, 1480.0], 0.1, 0.22)
	_sounds["hit"] = _tone(110.0, 0.18, 0.4, true)
	_sounds["rotate"] = _tone(520.0, 0.04, 0.2)
	_sounds["plant"] = _chord([392.0, 523.0, 659.0], 0.25, 0.25)
	_sounds["graft"] = _chord([523.0, 659.0, 784.0, 1046.0], 0.5, 0.25)
	_sounds["win"] = _arp([523.0, 659.0, 784.0, 1046.0], 0.1, 0.25)
	_sounds["star"] = _chord([1046.0, 1568.0], 0.18, 0.22)
	_sounds["achievement"] = _arp([784.0, 988.0, 1175.0, 1568.0], 0.08, 0.22)


func _setup_buses() -> void:
	for name in BUSES.keys():
		if AudioServer.get_bus_index(name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, name)
			AudioServer.set_bus_send(idx, "Master")
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(name), BUSES[name])


func _music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80.0
	add_child(p)
	return p


func play(name: String, pitch: float = 1.0) -> void:
	if not GameState.settings.get("sound", true) or not _sounds.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _sounds[name]
	p.bus = "UI" if name in UI_SOUNDS else "SFX"
	p.pitch_scale = pitch * randf_range(0.96, 1.04)  # variation: no machine-gun repeats
	p.play()
	if name in ["graft", "win", "achievement", "hit"]:
		duck(0.6)


## Briefly lowers the music so an important sound reads clearly.
func duck(seconds: float) -> void:
	var idx := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(idx, BUSES.Music - 8.0)
	var tw := create_tween()
	tw.tween_interval(seconds)
	tw.tween_method(func(v: float): AudioServer.set_bus_volume_db(idx, v), BUSES.Music - 8.0, BUSES.Music, 0.5)


# ---------------------------------------------------------------- music

## Music states: "hub" (calm), "world:<bpm>" (beat-synced pad), "" (silence).
func music(track: String) -> void:
	if track == current_track:
		return
	current_track = track
	var old := _music_a if _music_a.playing else _music_b
	var new := _music_b if old == _music_a else _music_a
	if track != "" and GameState.settings.get("sound", true):
		new.stream = _get_track(track)
		new.volume_db = -30.0
		new.play()
		create_tween().tween_property(new, "volume_db", 0.0, 1.2)
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -40.0, 1.0)
		tw.tween_callback(old.stop)


func _get_track(track: String) -> AudioStreamWAV:
	if _music_cache.has(track):
		return _music_cache[track]
	var w: AudioStreamWAV
	if track.begins_with("world:"):
		var bpm := float(track.split(":")[1])
		w = _pad([[261.6, 329.6, 392.0], [220.0, 261.6, 329.6], [174.6, 220.0, 261.6], [196.0, 246.9, 293.7]], 60.0 / bpm * 4.0, 0.16)
	else:
		# hub: slow Cmaj7 - Am7 - Fmaj7 - G6, a calm rooftop evening
		w = _pad([[261.6, 329.6, 392.0, 493.9], [220.0, 261.6, 329.6, 392.0], [174.6, 220.0, 261.6, 329.6], [196.0, 246.9, 293.7, 329.6]], 2.6, 0.13)
	_music_cache[track] = w
	return w


## A soft looping chord pad; each chord lasts `chord_len` seconds.
func _pad(chords: Array, chord_len: float, volume: float) -> AudioStreamWAV:
	var per := int(MIX_RATE * chord_len)
	var total := per * chords.size()
	var data := PackedByteArray()
	data.resize(total * 2)
	for c in chords.size():
		var freqs: Array = chords[c]
		for i in per:
			var t := float(c * per + i) / MIX_RATE
			var lt := float(i) / per
			var env := minf(1.0, lt * 6.0) * minf(1.0, (1.0 - lt) * 6.0)
			var v := 0.0
			for f in freqs:
				v += sin(TAU * f * t) * 0.6 + sin(TAU * f * 1.003 * t) * 0.4  # gentle chorus
			v = v / freqs.size() * env * volume
			data.encode_s16((c * per + i) * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var w := _wav(data)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = total
	return w


# ---------------------------------------------------------------- one-shots

func _tone(freq: float, length: float, volume: float, soft_square := false) -> AudioStreamWAV:
	return _chord([freq], length, volume, soft_square)


func _chord(freqs: Array, length: float, volume: float, soft_square := false) -> AudioStreamWAV:
	var n := int(MIX_RATE * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / MIX_RATE
		var env := minf(1.0, t * 200.0) * pow(1.0 - float(i) / n, 2.0)
		var v := 0.0
		for f in freqs:
			var s := sin(TAU * f * t)
			if soft_square:
				s = clampf(s * 2.5, -1.0, 1.0)
			v += s
		v = v / freqs.size() * env * volume
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	return _wav(data)


func _arp(freqs: Array, step: float, volume: float) -> AudioStreamWAV:
	var per := int(MIX_RATE * step)
	var total := per * freqs.size() + int(MIX_RATE * 0.25)
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		var t := float(i) / MIX_RATE
		var v := 0.0
		for k in freqs.size():
			var start := k * per
			if i >= start:
				var lt := float(i - start) / MIX_RATE
				var env := minf(1.0, lt * 200.0) * exp(-lt * 6.0)
				v += sin(TAU * freqs[k] * t) * env
		v = v / 2.0 * volume
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	return _wav(data)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.stereo = false
	w.data = data
	return w
