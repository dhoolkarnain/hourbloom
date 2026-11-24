extends Node
## Tiny procedural sound kit (autoload "Sfx").
## All sounds are generated at start-up, so they cost 0 bytes of storage.

const MIX_RATE := 22050
const VOICES := 8

var _sounds: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
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


func play(name: String, pitch: float = 1.0) -> void:
	if not GameState.settings.get("sound", true):
		return
	if not _sounds.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _sounds[name]
	p.pitch_scale = pitch
	p.play()


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
