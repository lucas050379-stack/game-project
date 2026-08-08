extends Node

## 실시간 신디사이저 — 음원 파일 없이 소리를 전부 코드로 만든다.
##
## AudioStreamGenerator 에 프레임을 직접 밀어 넣는다. C# 판의 winmm waveOut 믹서와 같은 구조다.
## 오토로드로 등록되어 있어 어디서든 Snd.xxx() 로 부른다.

const RATE := 44100.0
const MAX_VOICES := 48

enum Wf { PULSE, SAW, TRI, NOISE, SINE, METAL }

var _player: AudioStreamPlayer
var _pb: AudioStreamGeneratorPlayback
var _voices: Array = []
var muted := false

# ---- 시퀀서 ----
const MAIN := 0
const BATTLE := 1
const VICTORY := 2
var _song := -1
var _step := 0
var _acc := 0.0
var _vol := 1.0
var _vol_target := 1.0
var _songs: Array = []


func _ready() -> void:
	_build_songs()
	_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.09
	_player.stream = gen
	_player.bus = "Master"
	add_child(_player)
	_player.play()
	_pb = _player.get_stream_playback()


func _process(_dt: float) -> void:
	if _pb == null:
		return
	var need := _pb.get_frames_available()
	if need <= 0:
		return
	# 한 번에 밀어 넣되, 시퀀서는 작은 덩어리마다 돌려 박자를 지킨다
	var chunk := 128
	while need > 0:
		var n: int = mini(chunk, need)
		_advance(float(n) / RATE)
		_render(n)
		need -= n


func _render(n: int) -> void:
	var buf := PackedVector2Array()
	buf.resize(n)
	for i in n:
		var l := 0.0
		var r := 0.0
		for v: Dictionary in _voices:
			if v["dead"]:
				continue
			var s := _sample(v)
			l += s * v["pl"]
			r += s * v["pr"]
		if muted:
			l = 0.0
			r = 0.0
		buf[i] = Vector2(_limit(l * 0.85), _limit(r * 0.85))
	_pb.push_buffer(buf)
	for i in range(_voices.size() - 1, -1, -1):
		if _voices[i]["dead"]:
			_voices.remove_at(i)


func _limit(x: float) -> float:
	x = clampf(x, -1.6, 1.6)
	return x - x * x * x / 4.8


func _sample(v: Dictionary) -> float:
	var tt: float = v["t"] - v["delay"]
	var env := 0.0
	if tt < 0.0:
		env = 0.0
	elif tt < v["atk"]:
		env = tt / v["atk"] if v["atk"] > 0.0 else 1.0
	else:
		var d: float = tt - v["atk"]
		if d < v["dec"]:
			env = 1.0 + (v["sus"] - 1.0) * (d / v["dec"] if v["dec"] > 0.0 else 1.0)
		elif v["t"] < v["delay"] + v["dur"]:
			env = v["sus"]
		else:
			var rl: float = v["t"] - v["delay"] - v["dur"]
			if rl >= v["rel"]:
				v["dead"] = true
				return 0.0
			env = v["sus"] * (1.0 - (rl / v["rel"] if v["rel"] > 0.0 else 1.0))

	var f: float = v["f0"]
	if v["f1"] > 0.0:
		var gt: float = clampf(v["t"] / v["glide"], 0.0, 1.0) if v["glide"] > 0.0 else 1.0
		f = v["f0"] + (v["f1"] - v["f0"]) * G2.out_quad(gt)
	if v["vib"] > 0.0:
		f *= 1.0 + v["vib"] * sin(v["t"] * v["vibr"] * TAU)
	f = clampf(f, 8.0, RATE * 0.45)

	v["ph"] += f / RATE
	if v["ph"] >= 1.0:
		v["ph"] -= floorf(v["ph"])

	var s := 0.0
	match v["w"]:
		Wf.PULSE: s = 1.0 if v["ph"] < v["duty"] else -1.0
		Wf.SAW: s = v["ph"] * 2.0 - 1.0
		Wf.TRI: s = (v["ph"] * 4.0 - 1.0) if v["ph"] < 0.5 else (3.0 - v["ph"] * 4.0)
		Wf.SINE: s = sin(v["ph"] * TAU)
		Wf.METAL:
			s = sin(v["ph"] * TAU) * 0.5 + sin(v["ph"] * TAU * 2.41) * 0.3 \
					+ sin(v["ph"] * TAU * 3.83) * 0.2 + (randf() - 0.5) * 0.25
		_: s = randf() * 2.0 - 1.0

	if v["drive"] > 0.0:
		var dr: float = 1.0 + v["drive"] * 6.0
		s = tanh(s * dr) / tanh(dr)
	if v["cut"] > 0.0:
		v["lp"] += (s - v["lp"]) * v["cut"]
		s = v["lp"]

	v["t"] += 1.0 / RATE
	return s * env * v["amp"]

# ==================== 보이스 ====================

func play(w: int, f0: float, f1: float, glide: float, amp: float, pan: float,
		atk: float, dec: float, sus: float, rel: float, dur: float,
		drive: float = 0.0, cut: float = 0.0, duty: float = 0.5,
		delay: float = 0.0, vib: float = 0.0, vibr: float = 5.5) -> void:
	if _voices.size() >= MAX_VOICES:
		return
	_voices.append({
		"w": w, "f0": f0, "f1": f1, "glide": glide, "amp": amp,
		"pl": sqrt(maxf(0.0, (1.0 - pan) * 0.5)), "pr": sqrt(maxf(0.0, (1.0 + pan) * 0.5)),
		"atk": atk, "dec": dec, "sus": sus, "rel": rel, "dur": dur,
		"drive": drive, "cut": cut, "duty": duty, "delay": delay,
		"vib": vib, "vibr": vibr, "t": 0.0, "ph": 0.0, "lp": 0.0, "dead": false,
	})


func noise(dur: float, amp: float, pan: float, dec: float, cut: float) -> void:
	play(Wf.NOISE, 8000.0, -1.0, 0.0, amp, pan, 0.001, dec, 0.02, dur * 0.5, dur, 0.0, cut)

# ==================== 효과음 ====================

func click() -> void:
	play(Wf.PULSE, 900, 1350, 0.03, 0.10, 0, 0.001, 0.02, 0.3, 0.05, 0.045)


func bet(dir: int) -> void:
	var f := 620.0 if dir >= 0 else 480.0
	play(Wf.PULSE, f, f * (1.5 if dir >= 0 else 0.7), 0.05, 0.11, 0, 0.001, 0.03, 0.4, 0.06, 0.06)


func deny() -> void:
	play(Wf.SAW, 180, 110, 0.12, 0.13, 0, 0.002, 0.05, 0.5, 0.10, 0.16, 0.3)


func lever() -> void:
	noise(0.09, 0.30, 0, 0.05, 0.5)
	play(Wf.SAW, 340, 120, 0.14, 0.16, 0, 0.002, 0.05, 0.55, 0.10, 0.16, 0.4)
	play(Wf.METAL, 640, 520, 0.2, 0.09, 0, 0.002, 0.10, 0.35, 0.25, 0.20)


## 릴이 멈출 때마다 화음이 한 음씩 쌓여 올라간다 (C E G B D)
const STOP_CHORD := [523.25, 659.26, 783.99, 987.77, 1174.66]


func reel_stop(i: int, hot: bool) -> void:
	var pan := (i - 2) * 0.30
	var f: float = STOP_CHORD[i % STOP_CHORD.size()]
	# 묵직한 착지음
	play(Wf.SINE, f * 0.5, f * 0.25, 0.05, 0.30, pan, 0.001, 0.03, 0.35, 0.09, 0.07, 0.25)
	noise(0.045, 0.22, pan, 0.030, 0.65)
	# 밝은 종소리 — 이게 있어야 "똑딱"으로 끝나지 않는다
	play(Wf.PULSE, f, -1, 0, 0.13, pan, 0.002, 0.10, 0.35, 0.28, 0.14, 0, 0, 0.30)
	play(Wf.SINE, f * 2.0, -1, 0, 0.06, pan, 0.002, 0.08, 0.3, 0.22, 0.10)
	if hot:
		play(Wf.METAL, 1180 + i * 90, -1, 0, 0.13, 0, 0.002, 0.16, 0.3, 0.32, 0.22)


## 회전 중 굴러가는 소리. step 이 늘수록 5음계를 훑고, rise 로 전체가 올라간다.
const ROLL_SCALE := [0, 3, 5, 7, 10]


func reel_tick(pan: float, step: int, rise: float) -> void:
	var deg: int = ROLL_SCALE[step % ROLL_SCALE.size()] + 12 * ((step / ROLL_SCALE.size()) % 2)
	var f: float = 330.0 * pow(2.0, (deg + rise * 12.0) / 12.0)
	play(Wf.PULSE, f, -1, 0, 0.050, pan, 0.002, 0.028, 0.22, 0.05, 0.028, 0, 0, 0.32)
	noise(0.010, 0.028, pan, 0.008, 0.92)


func tension(level: int) -> void:
	var f: float = 260.0 * pow(1.32, level)
	play(Wf.SAW, f, f * 2.2, 0.42, 0.10 + level * 0.022, 0, 0.06, 0.20, 0.85, 0.16, 0.44, 0.35)
	play(Wf.SINE, f * 0.5, f * 1.1, 0.42, 0.12, 0, 0.05, 0.2, 0.9, 0.2, 0.45)


func near() -> void:
	play(Wf.PULSE, 420, 300, 0.16, 0.11, 0, 0.004, 0.07, 0.5, 0.14, 0.20)


func coin(i: int) -> void:
	var f := 1180.0 + (i % 12) * 55.0
	play(Wf.SINE, f, f * 1.5, 0.02, 0.085, sin(i * 1.7) * 0.4, 0.001, 0.025, 0.25, 0.07, 0.035)


func win_small() -> void:
	var ns := [784.0, 988.0, 1175.0]
	for i in ns.size():
		play(Wf.PULSE, ns[i], -1, 0, 0.10, 0, 0.004, 0.045, 0.6, 0.065, 0.13, 0, 0, 0.5, i * 0.065)


func win_big() -> void:
	var ns := [523.0, 659.0, 784.0, 1047.0, 1319.0]
	for i in ns.size():
		play(Wf.PULSE, ns[i], -1, 0, 0.11, 0, 0.004, 0.077, 0.6, 0.11, 0.22, 0, 0, 0.5, i * 0.075)
	play(Wf.SINE, 131, -1, 0, 0.16, 0, 0.004, 0.175, 0.6, 0.25, 0.5)


func scatter(n: int) -> void:
	var f: float = 330.0 * pow(1.26, n)
	play(Wf.METAL, f, f * 1.6, 0.18, 0.20, 0, 0.002, 0.09, 0.5, 0.30, 0.26)
	play(Wf.SINE, 90, 55, 0.16, 0.34, 0, 0.001, 0.04, 0.7, 0.18, 0.18, 0.4)
	noise(0.10, 0.24, 0, 0.06, 0.4)


func charge() -> void:
	play(Wf.SAW, 200, 1600, 0.55, 0.13, 0, 0.02, 0.3, 0.85, 0.2, 0.58, 0.35)


func horn() -> void:
	play(Wf.SAW, 174, 233, 0.35, 0.24, 0, 0.05, 0.25, 0.8, 0.5, 1.05, 0.5, 0.24, 0.5, 0.0, 0.012, 5.0)
	play(Wf.SAW, 261, 349, 0.35, 0.13, 0.3, 0.08, 0.25, 0.75, 0.5, 1.05, 0.0, 0.3)


func drum(pan: float, amp: float) -> void:
	play(Wf.SINE, 230, 62, 0.13, 0.5 * amp, pan, 0.001, 0.04, 0.7, 0.20, 0.20, 0.45)
	noise(0.06, 0.20 * amp, pan, 0.035, 0.3)


## 칼을 휘두르기 시작할 때의 바람소리 (타격보다 먼저 난다)
func swoosh(i: int) -> void:
	var p := sin(i * 2.3) * 0.55
	play(Wf.NOISE, 9000, -1, 0, 0.10, p, 0.02, 0.06, 0.5, 0.05, 0.09, 0.0, 0.20)


func slash(i: int) -> void:
	var p := sin(i * 2.3) * 0.55
	play(Wf.NOISE, 9000, -1, 0, 0.24, p, 0.001, 0.045, 0.06, 0.07, 0.05)
	play(Wf.METAL, 2300 + (i % 5) * 180, 900, 0.10, 0.15, p, 0.001, 0.05, 0.3, 0.16, 0.10)


## 연타 — 누를수록 음이 올라가 신이 난다
func mash(n: int) -> void:
	var deg: int = ROLL_SCALE[n % ROLL_SCALE.size()] + 12 * mini(2, n / 40)
	var f: float = 523.0 * pow(2.0, deg / 12.0)
	play(Wf.PULSE, f, f * 1.5, 0.02, 0.10, 0, 0.001, 0.03, 0.25, 0.07, 0.04, 0, 0, 0.35)
	noise(0.02, 0.07, 0, 0.012, 0.9)


func kill(combo: int) -> void:
	var f: float = 520.0 * pow(1.0595, mini(28, combo))
	play(Wf.PULSE, f, f * 1.5, 0.03, 0.115, sin(combo * 1.31) * 0.5,
			0.001, 0.035, 0.28, 0.09, 0.045)
	noise(0.05, 0.10, sin(combo * 1.31) * 0.5, 0.03, 0.5)


func cannon(pan: float) -> void:
	play(Wf.SINE, 180, 38, 0.16, 0.55, pan, 0.001, 0.05, 0.6, 0.26, 0.22, 0.6)
	noise(0.30, 0.34, pan, 0.16, 0.30)


func boom(pan: float, size: float) -> void:
	play(Wf.SINE, 140 * (2.0 - size), 30, 0.22, 0.48 * size, pan, 0.001, 0.06, 0.55, 0.35, 0.30, 0.7)
	noise(0.45 * size, 0.38 * size, pan, 0.22, 0.22)


func level_up(tier: int) -> void:
	var b: float = 392.0 * pow(1.1892, tier)
	for i in 4:
		play(Wf.PULSE, b * pow(1.26, i), -1, 0, 0.13, 0, 0.004, 0.07, 0.6, 0.10, 0.20,
				0, 0, 0.5, i * 0.06)
	drum(0, 1.2)
	play(Wf.METAL, 900 + tier * 160, -1, 0, 0.17, 0, 0.002, 0.2, 0.4, 0.6, 0.4)


func fanfare(tier: int) -> void:
	var ns := [523.0, 659.0, 784.0, 1047.0, 1319.0, 1568.0]
	var c: int = mini(ns.size(), 3 + tier)
	for i in c:
		play(Wf.PULSE, ns[i], -1, 0, 0.125, 0, 0.004, 0.105, 0.6, 0.15, 0.30,
				0, 0, 0.5, i * 0.085)
	play(Wf.SINE, 131, -1, 0, 0.20, 0, 0.004, 0.28, 0.6, 0.4, 0.8)
	play(Wf.METAL, 1046, -1, 0, 0.14, 0, 0.004, 0.385, 0.6, 0.55, 1.1, 0, 0, 0.5, 0.02)


func bankrupt() -> void:
	var ns := [440.0, 392.0, 330.0, 262.0, 196.0]
	for i in ns.size():
		play(Wf.SAW, ns[i], -1, 0, 0.14, 0, 0.004, 0.105, 0.55, 0.15, 0.30,
				0.2, 0, 0.5, i * 0.16)

# ==================== 시퀀서 ====================

func music(song: int, from_start: bool) -> void:
	if _song != song or from_start:
		_step = 0
		_acc = 0.0
	_song = song


func stop_music() -> void:
	_song = -1


func duck(v: float) -> void:
	_vol_target = v


func _advance(dt: float) -> void:
	_vol += (_vol_target - _vol) * minf(1.0, dt * 6.0)
	if _song < 0 or _song >= _songs.size():
		return
	var s: Dictionary = _songs[_song]
	var step_dur: float = 60.0 / s["bpm"] / 4.0
	_acc += dt
	var guard := 0
	while _acc >= step_dur and guard < 16:
		guard += 1
		_acc -= step_dur
		_fire(s, _step, step_dur)
		_step += 1
		if _step >= s["steps"]:
			_step = 0


func _fire(s: Dictionary, st: int, step_dur: float) -> void:
	for tr: Dictionary in s["tracks"]:
		var ev: Array = tr["ev"]
		if st >= ev.size():
			continue
		var e = ev[st]
		if e == null:
			continue
		if tr["drums"]:
			_drum_hit(e["d"], tr["amp"] * _vol, tr["pan"])
		else:
			play(tr["w"], e["f"], -1.0, 0.0, tr["amp"] * _vol, tr["pan"],
					tr["atk"], tr["dec"], tr["sus"], tr["rel"],
					maxf(0.02, e["len"] * step_dur * tr["gate"]),
					tr["drive"], tr["cut"], tr["duty"], 0.0, tr["vib"])


func _drum_hit(d: String, amp: float, pan: float) -> void:
	match d:
		"k": play(Wf.SINE, 150, 44, 0.09, amp * 1.5, pan, 0.001, 0.02, 0.9, 0.06, 0.10, 0.35)
		"b":
			play(Wf.SINE, 210, 72, 0.10, amp * 1.6, pan, 0.001, 0.03, 0.7, 0.16, 0.16, 0.4)
			noise(0.05, amp * 0.5, pan, 0.03, 0.25)
		"s":
			noise(0.11, amp * 0.85, pan, 0.16, 0.55)
			play(Wf.TRI, 320, 180, 0.05, amp * 0.5, pan, 0.001, 0.04, 0.3, 0.05, 0.06)
		"h": noise(0.028, amp * 0.34, pan, 0.02, 0.95)
		"o": noise(0.16, amp * 0.30, pan, 0.10, 0.95)
		"c": noise(0.7, amp * 0.42, pan, 0.55, 0.85)
		"g": play(Wf.METAL, 190, 172, 0.9, amp * 1.1, pan, 0.002, 0.25, 0.45, 1.2, 0.9, 0.0, 0.5)

# ==================== 악보 ====================

const NOTE_NAMES := ["c", "c#", "d", "d#", "e", "f", "f#", "g", "g#", "a", "a#", "b"]


static func _freq(tok: String) -> float:
	if tok.is_empty():
		return 0.0
	var s := tok.to_lower().replace("s", "#")
	var oct := int(s.substr(s.length() - 1))
	var name := s.substr(0, s.length() - 1)
	var semi := NOTE_NAMES.find(name)
	if semi < 0:
		return 0.0
	return 440.0 * pow(2.0, ((oct + 1) * 12 + semi - 69) / 12.0)


func _track(w: int, duty: float, amp: float, pan: float, pat: Array, drums := false) -> Dictionary:
	var toks: Array = []
	for line: String in pat:
		for tk in line.split(" ", false):
			toks.append(tk)
	var ev: Array = []
	ev.resize(toks.size())
	for i in toks.size():
		var tk: String = toks[i]
		if tk == "." or tk == "-":
			continue
		var length := 1
		var j := i + 1
		while j < toks.size() and toks[j] == "-":
			length += 1
			j += 1
		if drums:
			ev[i] = {"d": tk, "len": length}
		else:
			var f := _freq(tk)
			if f > 0.0:
				ev[i] = {"f": f, "len": length}
	return {
		"w": w, "duty": duty, "amp": amp, "pan": pan, "drums": drums, "ev": ev,
		"atk": 0.004, "dec": 0.05, "sus": 0.75, "rel": 0.08, "gate": 0.92,
		"drive": 0.0, "cut": 0.0, "vib": 0.0,
	}


func _song_of(bpm: float, tracks: Array) -> Dictionary:
	var steps := 0
	for tr: Dictionary in tracks:
		steps = maxi(steps, tr["ev"].size())
	return {"bpm": bpm, "tracks": tracks, "steps": steps}


func _build_songs() -> void:
	# ---- 메인 : A단 5음계, 140 BPM ----
	var m_lead := _track(Wf.PULSE, 0.5, 0.135, -0.16, [
		"e4 -  -  .  g4 -  .  a4 -  -  .  e4 -  .  d4 - ",
		"c4 -  -  .  d4 -  .  e4 -  -  -  .  a3 -  -  - ",
		"f4 -  -  .  a4 -  .  c5 -  -  .  a4 -  .  g4 - ",
		"g4 -  -  .  d4 -  .  e4 -  -  -  -  .  .  .  . ",
	])
	m_lead["dec"] = 0.06; m_lead["sus"] = 0.62; m_lead["vib"] = 0.006
	var m_harm := _track(Wf.PULSE, 0.25, 0.062, 0.20, [
		"a3 -  -  .  b3 -  .  c4 -  -  .  a3 -  .  a3 - ",
		"a3 -  -  .  a3 -  .  b3 -  -  -  .  e3 -  -  - ",
		"c4 -  -  .  c4 -  .  e4 -  -  .  e4 -  .  d4 - ",
		"b3 -  -  .  b3 -  .  c4 -  -  -  -  .  .  .  . ",
	])
	var m_bass := _track(Wf.TRI, 0.5, 0.24, 0.0, [
		"a2 -  .  a2 .  a2 -  .  a2 -  .  a2 .  a2 .  . ",
		"a2 -  .  a2 .  a2 -  .  e2 -  .  e2 .  g2 .  . ",
		"f2 -  .  f2 .  f2 -  .  f2 -  .  f2 .  c3 .  . ",
		"g2 -  .  g2 .  g2 -  .  g2 -  .  d3 .  d3 .  . ",
	])
	m_bass["drive"] = 0.30; m_bass["sus"] = 0.85
	var m_drum := _track(Wf.NOISE, 0.5, 0.32, 0.0, [
		"g h  h h  s h  h k  h h  h k  s h  h h ",
		"k h  h h  s h  h k  h h  h k  s h  h o ",
		"k h  h h  s h  h k  h h  k h  s h  h h ",
		"k h  h b  s h  b k  h h  h k  s b  h o ",
	], true)
	_songs.append(_song_of(152.0, [m_bass, m_harm, m_lead, m_drum]))

	# ---- 해전 : D단, 172 BPM ----
	var b_lead := _track(Wf.PULSE, 0.5, 0.135, -0.14, [
		"d5 .  d5 .  f5 .  d5 .  a5 -  .  g5 .  f5 -  . ",
		"e5 .  e5 .  g5 .  e5 .  c6 -  .  a5 .  g5 -  . ",
		"f5 .  f5 .  a5 .  f5 .  d6 -  -  .  c6 -  a5 - ",
		"g5 -  .  a5 -  .  a#5 -  .  a5 -  .  g5 -  .  . ",
	])
	b_lead["dec"] = 0.04; b_lead["sus"] = 0.7; b_lead["vib"] = 0.008
	var b_harm := _track(Wf.SAW, 0.5, 0.058, 0.22, [
		"d4 -  -  -  f4 -  -  -  a4 -  -  -  a4 -  -  - ",
		"e4 -  -  -  g4 -  -  -  c5 -  -  -  c5 -  -  - ",
		"f4 -  -  -  a4 -  -  -  d5 -  -  -  d5 -  -  - ",
		"g4 -  -  -  a#4 -  -  -  a4 -  -  -  a4 -  -  - ",
	])
	b_harm["cut"] = 0.30; b_harm["sus"] = 0.55
	var b_bass := _track(Wf.SAW, 0.5, 0.235, 0.0, [
		"d2 d2 .  d2 d2 .  d2 .  d2 d2 .  d2 .  d2 .  d2",
		"d2 d2 .  d2 d2 .  d2 .  a1 a1 .  a1 .  a1 .  a1",
		"f2 f2 .  f2 f2 .  f2 .  f2 f2 .  f2 .  c3 .  c3",
		"g2 g2 .  g2 g2 .  a#2 . a#2 a#2 . a#2 .  a2 .  a2",
	])
	b_bass["cut"] = 0.42; b_bass["drive"] = 0.45; b_bass["gate"] = 0.75
	var b_drum := _track(Wf.NOISE, 0.5, 0.34, 0.0, [
		"c b  h b  s h  b h  k b  h b  s h  b b ",
		"k b  h b  s h  b h  k b  h b  s b  b o ",
		"k b  h b  s h  b h  k b  h b  s h  b b ",
		"k b  b b  s b  b b  k b  b b  s b  b c ",
	], true)
	_songs.append(_song_of(172.0, [b_bass, b_harm, b_lead, b_drum]))

	# ---- 개선 행진 ----
	var v_lead := _track(Wf.PULSE, 0.5, 0.14, 0.0, [
		"a4 -  .  a4 .  c5 -  .  d5 -  -  -  .  .  .  . ",
		"e5 -  .  e5 .  d5 -  .  c5 -  -  -  .  .  .  . ",
		"d5 -  .  c5 .  a4 -  .  g4 -  -  -  .  .  .  . ",
		"a4 -  -  -  -  -  -  -  -  -  .  .  .  .  .  . ",
	])
	v_lead["sus"] = 0.7; v_lead["rel"] = 0.2
	var v_bass := _track(Wf.TRI, 0.5, 0.22, 0.0, [
		"a2 .  a2 .  f2 .  f2 .  d2 .  d2 .  e2 .  e2 . ",
		"a2 .  a2 .  g2 .  g2 .  c3 .  c3 .  e2 .  e2 . ",
		"f2 .  f2 .  d2 .  d2 .  g2 .  g2 .  e2 .  e2 . ",
		"a2 -  -  -  -  -  .  .  a2 .  a2 .  a2 .  a2 . ",
	])
	v_bass["drive"] = 0.25
	var v_drum := _track(Wf.NOISE, 0.5, 0.32, 0.0, [
		"g .  b .  s .  b .  k .  b .  s .  b b ",
		"k .  b .  s .  b .  k .  b .  s .  b b ",
		"k .  b .  s .  b .  k .  b .  s .  b b ",
		"c .  b b  s b  b b  k b  b b  s b  b c ",
	], true)
	_songs.append(_song_of(150.0, [v_bass, v_lead, v_drum]))
