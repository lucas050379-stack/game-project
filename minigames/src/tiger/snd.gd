class_name TgSnd
extends RefCounted

## 떡 하나 주면 안 잡아먹지 효과음 — 포장지 · 톡 터지는 사탕 · 작은 방울. 다른 게임과 같은 소리를 쓰지 않는다.
## 목소리는 허브(`Hub.host`)에 붙인다. 음량 · 켜고 끄기는 허브의 효과음 막대(`Snd.volume_db` · `Sv.sfx`)를 따른다.

const RATE := 22050
const VOICES := 6

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
	# 점프 — 짧게 올라가는 휘파람
	_bank.jump = _render(0.18, func(t): return sin(TAU * (520.0 + t * 1800.0) * t) * exp(-t * 14.0) * 0.4)
	# 착지 — 둔한 톡
	_bank.land = _render(0.12, func(t): return sin(TAU * 140.0 * t) * exp(-t * 40.0) * 0.5)
	# 슬라이드 — 종이 스치는 소리
	_bank.slide = _render(0.22, func(t): return (randf() * 2.0 - 1.0) * exp(-t * 12.0) * 0.25)
	# 떡 — 작은 방울(음 높이는 play 의 pitch 로 올린다)
	_bank.ember = _render(0.25, func(t): return (sin(TAU * 1760.0 * t) + sin(TAU * 1760.0 * 2.5 * t) * 0.3) * exp(-t * 18.0) * 0.35)
	# 꿀떡 꼬치 — 방울 셋이 이어서
	_bank.lantern = _render(0.6, func(t): return (_bell(t, 1046.0) + _bell(t - 0.1, 1318.0) + _bell(t - 0.2, 1568.0)) * 0.3)
	# 부딪힘 — 사탕 깨지는 탁 + 낮은 쿵
	_bank.hit = _render(0.35, func(t): return (randf() * 2.0 - 1.0) * exp(-t * 50.0) * 0.6 + sin(TAU * 90.0 * t) * exp(-t * 12.0) * 0.6)
	# 호랑이 기운 — 바람이 차오르는 소리 + 북
	_bank.awaken = _render(1.2, func(t): return (randf() * 2.0 - 1.0) * minf(1.0, t / 1.0) * 0.25 + sin(TAU * 55.0 * t) * exp(-t * 3.0) * 0.5)
	# 질주 끝 충격파
	_bank.boom = _render(0.7, func(t): return sin(TAU * (70.0 - t * 40.0) * t) * exp(-t * 6.0) * 0.9 + (randf() * 2.0 - 1.0) * exp(-t * 20.0) * 0.3)
	# 완주 — 방울 상행
	_bank.win = _render(1.6, func(t): return (_bell(t, 784.0) + _bell(t - 0.15, 988.0) + _bell(t - 0.3, 1175.0) + _bell(t - 0.5, 1568.0)) * 0.3)
	# 힘 빠짐 — 훅 하는 바람 뒤 정적
	_bank.lose = _render(1.2, func(t): return (randf() * 2.0 - 1.0) * exp(-t * 4.0) * 0.35 + sin(TAU * 110.0 * t) * exp(-t * 2.5) * 0.3)
	_bank.tick = _render(0.07, func(t): return sin(TAU * 900.0 * t) * exp(-t * 80.0) * 0.5)


static func _bell(t: float, f: float) -> float:
	if t < 0.0:
		return 0.0
	return (sin(TAU * f * t) + sin(TAU * f * 2.5 * t) * 0.3) * exp(-t * 9.0)


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
		var v: float = clampf(f.call(float(i) / RATE), -1.0, 1.0)
		var s := int(v * 32767.0)
		data.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w
