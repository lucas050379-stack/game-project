class_name RsSnd
extends RefCounted

## 붉은 별 개척단 효과음 — 제국 연대기 EmSnd 와 같은 방식(켤 때 한 번 합성해 [AudioStreamWAV] 로 굳힌다).
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
	# 카드 집기 — 종이 스치는 짧은 소리
	_bank.card = _render(0.16, func(t): return (randf() * 2.0 - 1.0) * exp(-t * 30.0) * 0.35 + sin(TAU * 900.0 * t) * exp(-t * 50.0) * 0.2)
	_bank.tick = _render(0.08, func(t): return sin(TAU * 1300.0 * t) * exp(-t * 70.0) * 0.6)
	# 짓기 — 망치 둘
	_bank.build = _render(0.5, func(t): return _knock(t, 220.0) + _knock(t - 0.14, 260.0))
	# 돈 — 동전
	_bank.coin = _render(0.35, func(t): return (sin(TAU * 2600.0 * t) * 0.5 + sin(TAU * 3900.0 * t) * 0.3) * exp(-t * 14.0))
	# 군사 — 북
	_bank.drum = _render(0.6, func(t): return sin(TAU * (90.0 - t * 40.0) * t) * exp(-t * 7.0) * 0.8 + (randf() * 2.0 - 1.0) * exp(-t * 25.0) * 0.2)
	# 과학 — 맑은 종 둘
	_bank.sci = _render(0.9, func(t): return (_bell(t, 1047.0) + _bell(t - 0.1, 1319.0)) * 0.3)
	# 불가사의 — 금관 화음
	_bank.wonder = _render(1.6, func(t): return (_brass(t, 262.0) + _brass(t, 330.0) + _brass(t, 392.0) + _brass(t - 0.3, 523.0)) * 0.22)
	_bank.win = _render(2.4, func(t): return (_bell(t, 523.0) + _bell(t - 0.25, 784.0) + _bell(t - 0.5, 1047.0)) * 0.3)
	_bank.lose = _render(1.8, func(t): return (_bell(t, 392.0) + _bell(t - 0.3, 330.0) + _bell(t - 0.6, 262.0)) * 0.3)


static func _knock(t: float, f: float) -> float:
	if t < 0.0:
		return 0.0
	return (sin(TAU * f * t) * 0.7 + (randf() * 2.0 - 1.0) * 0.3) * exp(-t * 30.0)


static func _bell(t: float, f: float) -> float:
	if t < 0.0:
		return 0.0
	return (sin(TAU * f * t) + sin(TAU * f * 2.76 * t) * 0.3 + sin(TAU * f * 5.4 * t) * 0.1) * exp(-t * 2.2) * minf(1.0, t / 0.003)


static func _brass(t: float, f: float) -> float:
	if t < 0.0:
		return 0.0
	var env := minf(1.0, t / 0.05) * exp(-t * 1.6)
	return (sin(TAU * f * t) + sin(TAU * f * 2.0 * t) * 0.5 + sin(TAU * f * 3.0 * t) * 0.3) * env


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
