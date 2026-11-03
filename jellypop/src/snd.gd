class_name Snd
extends RefCounted

## 효과음 — 음원 파일 없이 **켤 때 한 번 합성해 [AudioStreamWAV] 로 굳혀 둔다.**
## 웹에서 `AudioStreamGenerator` 로 매 프레임 합성하면 스레드가 없어 소리가 끊긴다.
##
## 연쇄 · 콤보가 쌓일수록 `pitch_scale` 을 올린다 — 같은 소리를 다시 굽지 않는다.
## 브라우저는 첫 터치 전에는 소리를 막으므로 시작 화면에서 한 번 눌러야 들린다.

const RATE := 22050
const VOICES := 10
## 초당 여러 번 날 수 있는 소리는 최소 간격을 둔다. 한 프레임에 열 개가 겹치면 그냥 커지기만 한다.
const MIN_GAP := {"pop": 0.035, "tick": 0.2, "box": 0.05, "ice": 0.05, "chain": 0.05, "mon": 0.08}

static var _bank := {}
static var _players: Array[AudioStreamPlayer] = []
static var _next := 0
static var _last := {}
static var volume_db := -4.0


static func init(owner: Node) -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		owner.add_child(p)
		_players.append(p)
	_bank.pop = _render(0.11, func(t, _i): return _tone(t, lerpf(980.0, 520.0, minf(1.0, t / 0.08))) * _env(t, 0.003, 0.1) * 0.6)
	_bank.swap = _render(0.09, func(t, _i): return _noise() * _env(t, 0.02, 0.07) * 0.18 + _tone(t, 300.0 + t * 2000.0) * _env(t, 0.01, 0.08) * 0.2)
	_bank.bad = _render(0.2, func(t, _i): return _square(t, 180.0 if t < 0.09 else 140.0) * _env(fmod(t, 0.1), 0.004, 0.08) * 0.22)
	_bank.line = _render(0.3, func(t, _i): return _saw(t, lerpf(1400.0, 180.0, t / 0.3)) * _env(t, 0.004, 0.28) * 0.28)
	_bank.boom = _render(0.45, func(t, _i): return (_noise() * exp(-t * 9.0) * 0.45 + sin(TAU * lerpf(110.0, 40.0, t / 0.45) * t) * exp(-t * 6.0) * 0.6))
	_bank.rainbow = _render(0.6, func(t, _i): return _arp(t, [523.0, 659.0, 784.0, 1047.0, 1319.0], 0.07) * 0.35)
	_bank.make = _render(0.25, func(t, _i): return _arp(t, [784.0, 1175.0], 0.06) * 0.35)
	_bank.fever = _render(0.9, func(t, _i): return (_tone(t, 300.0 + t * 700.0) * 0.25 + _arp(t, [523.0, 659.0, 784.0, 1047.0], 0.1) * 0.25) * _env(t, 0.01, 0.85))
	_bank.tick = _render(0.04, func(t, _i): return _tone(t, 1600.0) * _env(t, 0.001, 0.035) * 0.3)
	_bank.start = _render(0.35, func(t, _i): return _arp(t, [659.0, 988.0], 0.1) * 0.35)
	_bank.box = _render(0.16, func(t, _i): return (_noise() * 0.5 + sin(TAU * 150.0 * t)) * exp(-t * 28.0) * 0.45)
	_bank.ice = _render(0.18, func(t, _i): return (_noise() * 0.6 + _tone(t, 2400.0 - t * 6000.0) * 0.3) * exp(-t * 22.0) * 0.4)
	_bank.chain = _render(0.2, func(t, _i): return (_tone(t, 1900.0) + _tone(t, 2650.0) * 0.6) * exp(-t * 18.0) * 0.25)
	_bank.mon = _render(0.2, func(t, _i): return _square(t, lerpf(260.0, 120.0, t / 0.2)) * exp(-t * 14.0) * 0.22)
	_bank.fly = _render(0.3, func(t, _i): return _tone(t, 500.0 + t * 2600.0) * _env(t, 0.01, 0.28) * 0.25 + _noise() * exp(-t * 10.0) * 0.08)
	_bank.collect = _render(0.4, func(t, _i): return _arp(t, [880.0, 1175.0, 1568.0], 0.06) * 0.35)
	_bank.curse = _render(0.35, func(t, _i): return _saw(t, lerpf(220.0, 90.0, t / 0.35)) * _env(t, 0.02, 0.32) * 0.18)
	_bank.win = _render(1.2, func(t, _i): return _arp(t, [523.0, 659.0, 784.0, 1047.0, 1319.0, 1568.0], 0.11) * 0.4)
	_bank.lose = _render(0.9, func(t, _i): return _arp(t, [392.0, 349.0, 311.0, 262.0], 0.16) * 0.35)
	_bank.end = _render(1.0, func(t, _i): return _arp(t, [784.0, 659.0, 523.0, 1047.0], 0.16) * 0.35)


static func play(name: String, pitch: float = 1.0, db: float = 0.0) -> void:
	if _players.is_empty() or not _bank.has(name):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if MIN_GAP.has(name) and now - float(_last.get(name, -1.0)) < MIN_GAP[name]:
		return
	_last[name] = now
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _bank[name]
	p.pitch_scale = pitch
	p.volume_db = volume_db + db
	p.play()

# ==================== 합성 ====================

static func _render(sec: float, f: Callable) -> AudioStreamWAV:
	var n := int(sec * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v: float = f.call(float(i) / RATE, i)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


static func _env(t: float, att: float, dec: float) -> float:
	if t < att:
		return t / att
	return maxf(0.0, 1.0 - (t - att) / dec)


## 순간 주파수 f 의 사인. 주파수가 시간에 따라 바뀌어도 크게 거슬리지 않는 짧은 소리만 쓴다.
static func _tone(t: float, f: float) -> float:
	return sin(TAU * f * t)


static func _square(t: float, f: float) -> float:
	return 1.0 if fmod(t * f, 1.0) < 0.5 else -1.0


static func _saw(t: float, f: float) -> float:
	return fmod(t * f, 1.0) * 2.0 - 1.0


static func _noise() -> float:
	return randf() * 2.0 - 1.0


## 종소리 아르페지오 — 음마다 gap 초씩 늦게 들어와 각자 사라진다.
static func _arp(t: float, notes: Array, gap: float) -> float:
	var v := 0.0
	for k in notes.size():
		var tt: float = t - k * gap
		if tt > 0.0:
			v += (sin(TAU * notes[k] * tt) + 0.3 * sin(TAU * notes[k] * 2.0 * tt)) * exp(-tt * 7.0)
	return v / sqrt(notes.size())
