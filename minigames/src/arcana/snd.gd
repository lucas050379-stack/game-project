class_name AcSnd
extends RefCounted

## 아르카나 컬렉션 효과음 — 젤리팝 Snd 와 같은 방식(켤 때 한 번 합성해 [AudioStreamWAV] 로 굳힌다).
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
	# 토큰 — 유리구슬이 부딪는 짧은 소리
	_bank.chip = _render(0.18, func(t): return (sin(TAU * 2100.0 * t) * 0.5 + sin(TAU * 3170.0 * t) * 0.3) * exp(-t * 38.0))
	# 고르기 — 작은 딸깍
	_bank.tick = _render(0.08, func(t): return sin(TAU * 1300.0 * t) * exp(-t * 70.0) * 0.6)
	# 성물 갖추기 — 올라가는 하프 셋
	_bank.buy = _render(0.9, func(t): return (_harp(t, 659.0) + _harp(t - 0.07, 784.0) + _harp(t - 0.14, 988.0)) * 0.34)
	# 봉인 — 낮은 종 + 쉬익
	_bank.seal = _render(0.8, func(t): return (sin(TAU * 330.0 * t) + sin(TAU * 495.0 * t) * 0.4) * exp(-t * 5.0) * 0.4 + (randf() * 2.0 - 1.0) * exp(-t * 18.0) * 0.12)
	# 영웅이 찾아옴 — 짧은 팡파르
	_bank.hero = _render(1.4, func(t): return (_harp(t, 523.0) + _harp(t - 0.12, 659.0) + _harp(t - 0.24, 784.0) + _harp(t - 0.36, 1047.0) * 1.2) * 0.3)
	# 끝 — 종 둘
	_bank.win = _render(2.4, func(t): return (_bell(t, 523.0) + _bell(t - 0.25, 784.0) + _bell(t - 0.5, 1047.0)) * 0.3)
	_bank.lose = _render(1.8, func(t): return (_bell(t, 392.0) + _bell(t - 0.3, 330.0) + _bell(t - 0.6, 262.0)) * 0.3)


static func _harp(t: float, f: float) -> float:
	if t < 0.0:
		return 0.0
	return (sin(TAU * f * t) + sin(TAU * f * 2.0 * t) * 0.3 * exp(-t * 8.0)) * exp(-t * 4.5) * minf(1.0, t / 0.003)


static func _bell(t: float, f: float) -> float:
	if t < 0.0:
		return 0.0
	return (sin(TAU * f * t) + sin(TAU * f * 2.76 * t) * 0.3 + sin(TAU * f * 5.4 * t) * 0.1) * exp(-t * 2.2) * minf(1.0, t / 0.003)


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
