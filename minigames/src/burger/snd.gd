class_name BgSnd
extends RefCounted

## 버거왕 효과음 — 폭신한 빵 · 지글거리는 철판 · 계산대 종. 다른 게임과 같은 소리를 쓰지 않는다.
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
	# 얹기 — 폭신한 "폭"(높이는 play 의 pitch 로 재료마다 다르게)
	_bank.add = _render(0.14, func(t): return sin(TAU * (220.0 - t * 500.0) * t) * exp(-t * 26.0) * 0.6)
	# 치즈 · 소스 — 찰싹
	_bank.slap = _render(0.12, func(t): return (randf() * 2.0 - 1.0) * exp(-t * 45.0) * 0.4 + sin(TAU * 320.0 * t) * exp(-t * 40.0) * 0.3)
	# 철판 — 지글
	_bank.sizzle = _render(0.7, func(t): return (randf() * 2.0 - 1.0) * (0.25 + 0.2 * sin(t * 70.0)) * exp(-t * 3.5) * 0.5)
	# 다 익었다 — 작은 종
	_bank.ding = _render(0.4, func(t): return _bell(t, 1568.0) * 0.4)
	# 탄다 — 낮은 치익
	_bank.burn = _render(0.6, func(t): return (randf() * 2.0 - 1.0) * exp(-t * 5.0) * 0.4 + sin(TAU * 80.0 * t) * exp(-t * 6.0) * 0.4)
	# 계산대 — 종 두 번 + 동전
	_bank.cash = _render(0.7, func(t): return (_bell(t, 1318.0) + _bell(t - 0.09, 1760.0) + _bell(t - 0.2, 2093.0) * 0.6) * 0.3)
	# 틀림 — 낮은 부저
	_bank.wrong = _render(0.3, func(t): return signf(sin(TAU * 150.0 * t)) * exp(-t * 9.0) * 0.3)
	# 손님이 화나서 감 — 내려가는 두 음
	_bank.lost = _render(0.6, func(t): return (sin(TAU * 392.0 * t) * exp(-t * 8.0) + (sin(TAU * 294.0 * (t - 0.2)) * exp(-(t - 0.2) * 8.0) if t > 0.2 else 0.0)) * 0.4)
	# 손님 등장 — 문 종
	_bank.come = _render(0.3, func(t): return _bell(t, 988.0) * 0.25)
	# 버리기 — 통
	_bank.trash = _render(0.2, func(t): return sin(TAU * 110.0 * t) * exp(-t * 20.0) * 0.5 + (randf() * 2.0 - 1.0) * exp(-t * 60.0) * 0.2)
	# 영업 끝 — 셔터 + 종 상행
	_bank.close = _render(1.4, func(t): return (_bell(t, 784.0) + _bell(t - 0.15, 988.0) + _bell(t - 0.3, 1175.0) + _bell(t - 0.5, 1568.0)) * 0.3)
	_bank.buy = _render(0.5, func(t): return (_bell(t, 1046.0) + _bell(t - 0.1, 1568.0)) * 0.35)
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
		data.encode_s16(i * 2, int(v * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w
