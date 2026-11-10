class_name AkSnd
extends RefCounted

## 잿빛 요새의 용병단 효과음 — 쇠 · 가죽 · 둔탁한 타격(쨍 · 쿵 · 낮은 뿔나팔). 다른 게임과 같은 소리를 쓰지 않는다(docs/ai-look-overhaul.md #25).
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
	# 카드 — 가죽 스치는 소리
	_bank.card = _render(0.2, func(t): return (randf() * 2.0 - 1.0) * sin(minf(1.0, t / 0.2) * PI) * 0.3)
	_bank.tick = _render(0.07, func(t): return sin(TAU * 420.0 * t) * exp(-t * 80.0) * 0.6)
	# 처치 — 쇠 부딪는 쨍(어긋난 배음)
	_bank.build = _render(0.6, func(t): return _clang(t, 520.0) * 0.4)
	_bank.coin = _render(0.35, func(t): return (_clang(t, 1900.0) + _clang(t - 0.06, 2300.0)) * 0.2)
	# 맞음 — 둔탁한 쿵 + 짧은 갈라짐
	_bank.drum = _render(0.4, func(t): return sin(TAU * (64.0 - t * 40.0) * t) * exp(-t * 12.0) * 0.9 + (randf() * 2.0 - 1.0) * exp(-t * 40.0) * 0.35)
	# 회복 · 원소 — 낮고 부드러운 울림 둘
	_bank.sci = _render(0.9, func(t): return (sin(TAU * 440.0 * t) * exp(-t * 4.0) + _late(t, 0.12, 660.0) * 0.8) * minf(1.0, t / 0.01) * 0.3)
	# 낮은 뿔나팔
	_bank.wonder = _render(1.4, func(t): return _horn(t, 110.0) * 0.3)
	_bank.win = _render(2.2, func(t): return (_horn(t, 147.0) + _horn(t - 0.4, 220.0)) * 0.26)
	# 실패 — 낮은 조종 하나
	_bank.lose = _render(2.2, func(t): return (sin(TAU * 98.0 * t) + sin(TAU * 98.0 * 2.76 * t) * 0.35 + sin(TAU * 98.0 * 5.4 * t) * 0.12) * exp(-t * 1.6) * 0.45)

static func _clang(t: float, f: float) -> float:
	if t < 0.0:
		return 0.0
	return (sin(TAU * f * t) + sin(TAU * f * 2.41 * t) * 0.6 + sin(TAU * f * 3.89 * t) * 0.35 + sin(TAU * f * 5.3 * t) * 0.2) * exp(-t * 9.0)


static func _late(t: float, delay: float, f: float) -> float:
	if t < delay:
		return 0.0
	return sin(TAU * f * (t - delay)) * exp(-(t - delay) * 4.0)


static func _horn(t: float, f: float) -> float:
	if t < 0.0:
		return 0.0
	var env := minf(1.0, t / 0.12) * exp(-t * 1.5)
	return (sin(TAU * f * t) + sin(TAU * f * 2.0 * t) * 0.55 + sin(TAU * f * 3.0 * t) * 0.4 + sin(TAU * f * 4.0 * t) * 0.2) * env

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
