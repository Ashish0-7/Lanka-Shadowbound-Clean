extends Node
## Procedurally synthesised sound effects and chiptune music loops.

const RATE := 22050
const MRATE := 16000
var _sfx := {}
var _songs := {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var current_song := ""
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 99
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new(); add_child(_music)
	_music_b = AudioStreamPlayer.new(); add_child(_music_b)
	_build_sfx()

func play(name: String, pitch := 1.0, vol_db := 0.0) -> void:
	if not _sfx.has(name):
		return
	for p in _players:
		if not p.playing:
			p.stream = _sfx[name]
			p.pitch_scale = pitch * _rng.randf_range(0.96, 1.04)
			p.volume_db = vol_db
			p.play()
			return

# ------------------------------------------------------------------ synthesis helpers
func _wav(samples: PackedFloat32Array, rate := RATE, loop := false) -> AudioStreamWAV:
	var b := PackedByteArray()
	b.resize(samples.size() * 2)
	for i in samples.size():
		b.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = b
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s

func _tone(f0: float, f1: float, dur: float, wave := "square", vol := 0.4, noise_mix := 0.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array(); out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		ph += f / RATE
		var v := 0.0
		match wave:
			"square": v = 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
			"tri": v = 4.0 * absf(fmod(ph, 1.0) - 0.5) - 1.0
			"sine": v = sin(ph * TAU)
			"saw": v = fmod(ph, 1.0) * 2.0 - 1.0
		if noise_mix > 0.0:
			v = lerpf(v, _rng.randf_range(-1, 1), noise_mix)
		var env := minf(1.0, i / 60.0) * pow(1.0 - t, 1.6)
		out[i] = v * vol * env
	return out

func _cat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parts:
		out.append_array(p)
	return out

func _noise(dur: float, vol := 0.4, lowpass := 0.5, decay := 2.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array(); out.resize(n)
	var last := 0.0
	for i in n:
		var t := float(i) / n
		last = lerpf(last, _rng.randf_range(-1, 1), lowpass)
		out[i] = last * vol * pow(1.0 - t, decay)
	return out

func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var n := maxi(a.size(), b.size())
	var out := PackedFloat32Array(); out.resize(n)
	for i in n:
		out[i] = (a[i] if i < a.size() else 0.0) + (b[i] if i < b.size() else 0.0)
	return out

func _build_sfx() -> void:
	_sfx["blip"] = _wav(_tone(880, 880, 0.05, "square", 0.25))
	_sfx["select"] = _wav(_cat([_tone(660, 660, 0.05, "square", 0.25), _tone(990, 990, 0.08, "square", 0.25)]))
	_sfx["cancel"] = _wav(_tone(500, 300, 0.09, "square", 0.25))
	_sfx["text"] = _wav(_tone(1200, 1200, 0.018, "square", 0.08))
	_sfx["swing"] = _wav(_noise(0.12, 0.35, 0.25, 1.5))
	_sfx["swing2"] = _wav(_mix(_noise(0.16, 0.35, 0.18, 1.2), _tone(300, 140, 0.16, "saw", 0.12)))
	_sfx["hit"] = _wav(_mix(_noise(0.1, 0.5, 0.7, 2.5), _tone(220, 90, 0.1, "square", 0.25)))
	_sfx["crit"] = _wav(_mix(_noise(0.16, 0.6, 0.8, 2.0), _tone(520, 120, 0.16, "square", 0.3)))
	_sfx["hurt"] = _wav(_mix(_tone(300, 100, 0.2, "saw", 0.35), _noise(0.2, 0.2, 0.5)))
	_sfx["dash"] = _wav(_noise(0.15, 0.3, 0.12, 1.0))
	_sfx["coin"] = _wav(_cat([_tone(988, 988, 0.05, "square", 0.2), _tone(1319, 1319, 0.12, "square", 0.2)]))
	_sfx["pickup"] = _wav(_cat([_tone(523, 523, 0.06, "square", 0.2), _tone(659, 659, 0.06, "square", 0.2), _tone(784, 784, 0.12, "square", 0.2)]))
	_sfx["heal"] = _wav(_cat([_tone(392, 392, 0.07, "tri", 0.4), _tone(523, 523, 0.07, "tri", 0.4), _tone(784, 784, 0.2, "tri", 0.4)]))
	_sfx["levelup"] = _wav(_cat([_tone(523, 523, 0.09, "square", 0.22), _tone(659, 659, 0.09, "square", 0.22), _tone(784, 784, 0.09, "square", 0.22), _tone(1047, 1047, 0.35, "square", 0.22)]))
	_sfx["bolt"] = _wav(_tone(900, 300, 0.18, "saw", 0.22, 0.2))
	_sfx["whirl"] = _wav(_mix(_noise(0.35, 0.3, 0.15, 0.8), _tone(200, 500, 0.35, "saw", 0.1)))
	_sfx["radiant"] = _wav(_mix(_tone(200, 1400, 0.6, "sine", 0.4), _noise(0.6, 0.25, 0.3, 1.5)))
	_sfx["enemy_die"] = _wav(_mix(_tone(400, 60, 0.3, "square", 0.25), _noise(0.3, 0.3, 0.4, 1.2)))
	_sfx["shoot"] = _wav(_tone(400, 200, 0.12, "tri", 0.3))
	_sfx["windup"] = _wav(_tone(200, 420, 0.2, "tri", 0.18))
	_sfx["slam"] = _wav(_mix(_noise(0.35, 0.7, 0.3, 1.8), _tone(120, 40, 0.35, "square", 0.4)))
	_sfx["roar"] = _wav(_mix(_noise(0.9, 0.5, 0.08, 0.8), _tone(90, 50, 0.9, "saw", 0.4)))
	_sfx["door"] = _wav(_mix(_noise(0.3, 0.3, 0.1, 1.0), _tone(120, 80, 0.3, "square", 0.2)))
	_sfx["dig"] = _wav(_noise(0.18, 0.5, 0.35, 2.5))
	_sfx["chest"] = _wav(_cat([_tone(392, 392, 0.08, "square", 0.2), _tone(494, 494, 0.08, "square", 0.2), _tone(587, 587, 0.08, "square", 0.2), _tone(784, 784, 0.3, "square", 0.2)]))
	_sfx["menu"] = _wav(_tone(1100, 1500, 0.06, "square", 0.2))
	_sfx["step"] = _wav(_noise(0.04, 0.12, 0.3, 3.0))
	_sfx["portal"] = _wav(_tone(150, 900, 0.7, "sine", 0.35, 0.1))
	_sfx["shard"] = _wav(_cat([_tone(784, 784, 0.12, "tri", 0.35), _tone(988, 988, 0.12, "tri", 0.35), _tone(1175, 1175, 0.12, "tri", 0.35), _tone(1568, 1568, 0.5, "tri", 0.35)]))

# ------------------------------------------------------------------ music
const SCALES := {
	"major_pent": [0, 2, 4, 7, 9],
	"minor_pent": [0, 3, 5, 7, 10],
	"dorian": [0, 2, 3, 5, 7, 9, 10],
	"phryg": [0, 1, 3, 5, 7, 8, 10],
}

func play_music(name: String) -> void:
	if name == current_song:
		return
	current_song = name
	if name == "":
		_fade_out(_music)
		return
	if not _songs.has(name):
		_songs[name] = _compose(name)
	var old := _music
	_music = _music_b
	_music_b = old
	_fade_out(_music_b)
	_music.stream = _songs[name]
	_music.volume_db = -40
	_music.play()
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -9.0, 1.2)

func _fade_out(p: AudioStreamPlayer) -> void:
	if not p.playing:
		return
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -50.0, 0.8)
	tw.tween_callback(p.stop)

func _midi(n: int) -> float:
	return 440.0 * pow(2.0, (n - 69) / 12.0)

func _compose(name: String) -> AudioStreamWAV:
	var cfg := {
		"title": {"bpm": 76, "root": 57, "scale": "dorian", "bars": 8, "seed": 7, "lead": "tri", "density": 0.45, "drums": false, "pad": true},
		"overworld": {"bpm": 104, "root": 60, "scale": "major_pent", "bars": 8, "seed": 21, "lead": "square", "density": 0.6, "drums": true, "pad": false},
		"jungle": {"bpm": 96, "root": 57, "scale": "minor_pent", "bars": 8, "seed": 33, "lead": "tri", "density": 0.55, "drums": true, "pad": false},
		"dungeon": {"bpm": 84, "root": 50, "scale": "phryg", "bars": 8, "seed": 5, "lead": "tri", "density": 0.35, "drums": false, "pad": true},
		"boss": {"bpm": 150, "root": 52, "scale": "phryg", "bars": 8, "seed": 13, "lead": "square", "density": 0.8, "drums": true, "pad": false},
		"village": {"bpm": 88, "root": 62, "scale": "dorian", "bars": 8, "seed": 44, "lead": "tri", "density": 0.45, "drums": false, "pad": true},
		"ending": {"bpm": 80, "root": 60, "scale": "major_pent", "bars": 8, "seed": 3, "lead": "tri", "density": 0.5, "drums": false, "pad": true},
	}
	var c: Dictionary = cfg.get(name, cfg["overworld"])
	var rng := RandomNumberGenerator.new()
	rng.seed = c["seed"]
	var spb: float = 60.0 / float(c["bpm"])
	var step: float = spb / 2.0  # eighth notes
	var steps: int = c["bars"] * 8
	var total := int(steps * step * MRATE)
	var buf := PackedFloat32Array(); buf.resize(total)
	var sc: Array = SCALES[c["scale"]]
	var chords := [0, 5, 3, 4] if c["scale"] != "phryg" else [0, 1, 0, 6]
	var root: int = c["root"]
	# melody: random walk on scale degrees, phrase repeats with variation
	var phrase := []
	var deg := 0
	for i in 16:
		if rng.randf() < c["density"]:
			deg = clampi(deg + rng.randi_range(-2, 2), -2, sc.size() + 3)
			phrase.append(deg)
		else:
			phrase.append(null)
	for s in steps:
		var t0 := int(s * step * MRATE)
		var bar := s / 8
		var chord_deg: int = chords[bar % chords.size()]
		var chord_root := root - 12 + _deg_to_semi(sc, chord_deg)
		# bass on quarter notes
		if s % 2 == 0:
			var bn := chord_root - 12 + (7 if (s % 8) == 4 else 0)
			_add_note(buf, t0, step * 1.8, _midi(bn), "tri", 0.28)
		# pad: chord tones, long
		if c["pad"] and s % 8 == 0:
			for k in [0, 2, 4]:
				_add_note(buf, t0, step * 8.0, _midi(chord_root + 12 + _deg_to_semi(sc, k)), "sine", 0.07, true)
		# lead
		var pd = phrase[s % 16]
		if pd != null:
			var variation := 0 if bar % 2 == 0 else (2 if s % 16 > 11 else 0)
			var note: int = root + _deg_to_semi(sc, int(pd) + variation + chord_deg % 2)
			_add_note(buf, t0, step * 0.9, _midi(note), c["lead"], 0.12)
		# drums
		if c["drums"]:
			if s % 4 == 0:
				_add_kick(buf, t0)
			if s % 4 == 2:
				_add_hat(buf, t0, 0.12, 0.06)
			elif rng.randf() < 0.5:
				_add_hat(buf, t0, 0.04, 0.025)
	return _wav_m(buf)

func _wav_m(buf: PackedFloat32Array) -> AudioStreamWAV:
	return _wav(buf, MRATE, true)

func _deg_to_semi(sc: Array, d: int) -> int:
	var n := sc.size()
	var octv := floori(float(d) / n)
	var idx := d - octv * n
	return int(sc[idx]) + 12 * octv

func _add_note(buf: PackedFloat32Array, t0: int, dur: float, f: float, wave: String, vol: float, soft := false) -> void:
	var n := int(dur * MRATE)
	var ph := 0.0
	var inc := f / MRATE
	var sz := buf.size()
	for i in n:
		var idx := (t0 + i) % sz
		ph += inc
		var p := ph - floorf(ph)
		var v := 0.0
		if wave == "square":
			v = 0.6 if p < 0.5 else -0.6
		elif wave == "tri":
			v = 4.0 * absf(p - 0.5) - 1.0
		else:
			v = sin(p * TAU)
		var t := float(i) / n
		var env := 0.0
		if soft:
			env = sin(t * PI)
		else:
			env = minf(1.0, i / 80.0) * (1.0 - t) * (1.0 - t * 0.3)
		buf[idx] += v * vol * env

func _add_kick(buf: PackedFloat32Array, t0: int) -> void:
	var n := int(0.12 * MRATE)
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		ph += lerpf(140.0, 40.0, t) / MRATE
		buf[(t0 + i) % buf.size()] += sin(ph * TAU) * 0.35 * (1.0 - t)

func _add_hat(buf: PackedFloat32Array, t0: int, vol: float, dur: float) -> void:
	var n := int(dur * MRATE)
	for i in n:
		var t := float(i) / n
		buf[(t0 + i) % buf.size()] += _rng.randf_range(-1, 1) * vol * (1.0 - t) * (1.0 - t)
