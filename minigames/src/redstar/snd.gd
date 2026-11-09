class_name RsSnd
extends RefCounted

## 붉은 별 개척단 효과음 — 관제실의 전자음(네모파 삑 · 맑은 핑 · 압축 공기). 다른 게임과 같은 소리를 쓰지 않는다(docs/ai-look-overhaul.md #25).
## 목소리는 허브(`Hub.host`)에 붙인다. 음량 · 켜고 끄기는 허브의 효과음 막대(`Snd.volume_db` · `Sv.sfx`)를 따른다.

const RATE := 22050
const VOICES := 5

static var _bank := {}
static var _players: Array[AudioStreamPlayer] = []
static var _next := 0


static func init(owner: Node) -> void:
	if not _players.is_empty() and is_instance_valid(_players[0]):
		return
	_players.clear()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		owner.add_child(p)
		_players.append(p)
	if not _bank.is_empty():
		return
	# 카드 — 위로 올라가는 짧은 데이터 음
	_bank.card = _render(0.14, func(t): return sin(TAU * (500.0 + 2600.0 * t) * t) * exp(-t * 26.0) * 0.4)
	_bank.tick = _render(0.05, func(t): return _sq(t, 880.0) * exp(-t * 60.0) * 0.3)
	# 카드 내기 — 확인음 둘(낮은 삑 → 높은 삑)
	_bank.build = _render(0.34, func(t): return (_beep(t, 660.0, 0.1) + _beep(t - 0.11, 990.0, 0.16)) * 0.32)
	_bank.coin = _render(0.3, func(t): return (sin(TAU * 1760.0 * t) + sin(TAU * 2640.0 * t) * 0.4) * exp(-t * 16.0) * 0.4)
	# 타일 놓기 — 낮은 쿵 + 압축 공기
	_bank.drum = _render(0.5, func(t): return sin(TAU * (74.0 - t * 30.0) * t) * exp(-t * 9.0) * 0.8 + (randf() * 2.0 - 1.0) * exp(-t * 11.0) * 0.22)
	# 지표 · 기본 사업 — 올라가는 세 음(세모파)
	_bank.sci = _render(0.6, func(t): return (_tri(t, 523.0) * exp(-t * 9.0) + _tri(t - 0.09, 784.0) * exp(-maxf(0.0, t - 0.09) * 9.0) + _tri(t - 0.18, 1047.0) * exp(-maxf(0.0, t - 0.18) * 9.0)) * 0.3)
	# 목표 · 후원 — 천천히 차오르는 화음
	_bank.wonder = _render(1.6, func(t): return (sin(TAU * 220.0 * t) + sin(TAU * 221.5 * t) + sin(TAU * 330.0 * t) + sin(TAU * 440.0 * t) * 0.6) * minf(1.0, t / 0.25) * exp(-t * 1.8) * 0.2)
	_bank.win = _render(1.8, func(t): return (_beep(t, 523.0, 0.3) + _beep(t - 0.18, 659.0, 0.3) + _beep(t - 0.36, 784.0, 0.3) + _beep(t - 0.54, 1047.0, 0.9)) * 0.26)
	_bank.lose = _render(1.4, func(t): return (_beep(t, 440.0, 0.35) + _beep(t - 0.3, 370.0, 0.35) + _beep(t - 0.6, 294.0, 0.7)) * 0.26)

static func _sq(t: float, f: float) -> float:
	return 1.0 if fmod(t * f, 1.0) < 0.5 else -1.0


static func _tri(t: float, f: float) -> float:
	if t < 0.0:
		return 0.0
	return absf(fmod(t * f, 1.0) * 4.0 - 2.0) - 1.0


## 부드러운 삑 — 네모파와 사인을 섞고 길이 len 에 걸쳐 사라진다.
static func _beep(t: float, f: float, length: float) -> float:
	if t < 0.0 or t > length:
		return 0.0
	return (sin(TAU * f * t) * 0.7 + _sq(t, f) * 0.18) * minf(1.0, t / 0.005) * (1.0 - t / length)

static func play(name: String, pitch: float = 1.0) -> void:
	if _players.is_empty() or not is_instance_valid(_players[0]) or not _bank.has(name) or not Sv.sfx:
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _bank[name]
	p.pitch_scale = pitch
	p.volume_db = Snd.volume_db - 3.0
	p.play()


static func _render(sec: float, f: Callable) -> AudioStreamWAV:
	var n := int(sec * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v: float = f.call(float(i) / RATE)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = data
	return s
