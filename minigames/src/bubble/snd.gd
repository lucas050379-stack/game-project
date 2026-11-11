class_name BbSnd
extends RefCounted

## 물거품처럼 사라져줘 효과음 — 물방울 · 거품 · 작은 방울. 다른 게임과 같은 소리를 쓰지 않는다.
## 목소리는 허브(`Hub.host`)에 붙인다. 음량 · 켜고 끄기는 허브의 효과음 막대(`Snd.volume_db` · `Sv.sfx`)를 따른다.

const RATE := 22050
const VOICES := 8

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
	_bank.shot = _render(0.16, func(t): return sin(TAU * (300.0 + t * 2400.0) * t) * exp(-t * 18.0) * 0.4)   # 뽀
	_bank.jump = _render(0.16, func(t): return sin(TAU * (420.0 + t * 1500.0) * t) * exp(-t * 16.0) * 0.3)
	_bank.trap = _render(0.3, func(t): return sin(TAU * (900.0 - t * 1200.0) * t) * exp(-t * 9.0) * 0.4)   # 꿀렁
	_bank.pop = _render(0.12, func(t): return (sin(TAU * 1400.0 * t) * 0.6 + (randf() * 2.0 - 1.0) * 0.4) * exp(-t * 40.0) * 0.5)   # 톡
	_bank.kill = _render(0.45, func(t): return (_bell(t, 1046.0) + _bell(t - 0.06, 1568.0)) * 0.3)
	_bank.item = _render(0.25, func(t): return _bell(t, 1760.0) * 0.35)
	_bank.power = _render(0.6, func(t): return (_bell(t, 784.0) + _bell(t - 0.08, 1046.0) + _bell(t - 0.16, 1318.0)) * 0.3)
	_bank.letter = _render(0.35, func(t): return (_bell(t, 1318.0) + _bell(t - 0.05, 1976.0)) * 0.3)
	_bank.die = _render(0.9, func(t): return sin(TAU * (600.0 - t * 500.0) * t) * exp(-t * 3.0) * 0.4)
	_bank.hurry = _render(0.5, func(t): return sin(TAU * 880.0 * t) * (1.0 if fmod(t, 0.25) < 0.12 else 0.0) * 0.3)
	_bank.clear = _render(1.4, func(t): return (_bell(t, 784.0) + _bell(t - 0.15, 988.0) + _bell(t - 0.3, 1175.0) + _bell(t - 0.5, 1568.0)) * 0.3)
	_bank.over = _render(1.4, func(t): return (_bell(t, 523.0) + _bell(t - 0.3, 440.0) + _bell(t - 0.6, 349.0)) * 0.3)
	_bank.boss = _render(0.25, func(t): return sin(TAU * 110.0 * t) * exp(-t * 14.0) * 0.7 + (randf() * 2.0 - 1.0) * exp(-t * 30.0) * 0.3)
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
