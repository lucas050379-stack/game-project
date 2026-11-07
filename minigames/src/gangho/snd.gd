class_name GhSnd
extends RefCounted

## 강호일생 효과음 — 젤리팝 Snd 와 같은 방식(켤 때 한 번 합성해 [AudioStreamWAV] 로 굳힌다).
## 목소리는 허브(`Hub.host`)에 붙인다 — 게임 화면을 닫고 다시 열어도 지운 노드를 가리키지 않게.
## 음량 · 켜고 끄기는 허브의 효과음 막대(`Snd.volume_db` · `Sv.sfx`)를 그대로 따른다.
##
## 이 게임은 글을 읽는 게임이라 소리를 작게 · 드물게 둔다 — 줄마다 소리를 내면 금세 시끄럽다.
## 새 줄은 "큰일" 일 때만 울린다(GhMain 이 고른다).

const RATE := 22050
const VOICES := 4

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
	# 뜯는 소리(고쟁 비슷하게) — 배음 몇 개가 빨리 사라진다
	_bank.pluck = _render(0.9, func(t): return _pl(t, 392.0) * 0.5)
	_bank.pick = _render(0.25, func(t): return (sin(TAU * 900.0 * t) * 0.4 + (randf() * 2.0 - 1.0) * 0.3) * exp(-t * 30.0))
	_bank.gong = _render(2.2, func(t): return (sin(TAU * 110.0 * t) + sin(TAU * 167.0 * t) * 0.6 + sin(TAU * 293.0 * t) * 0.3) * exp(-t * 1.6) * minf(1.0, t / 0.01) * 0.4)
	_bank.bell = _render(3.0, func(t): return (sin(TAU * 220.0 * t) + sin(TAU * 523.0 * t) * 0.4 + sin(TAU * 847.0 * t) * 0.15) * exp(-t * 1.1) * minf(1.0, t / 0.005) * 0.4)
	_bank.drum = _render(0.5, func(t): return sin(TAU * lerpf(90.0, 50.0, minf(1.0, t / 0.2)) * t) * exp(-t * 9.0) * 0.7)
	_bank.birth = _render(1.6, func(t): return (_pl(t, 523.0) + _pl(t - 0.14, 587.0) + _pl(t - 0.28, 659.0) + _pl(t - 0.42, 784.0)) * 0.3)


static func _pl(t: float, f: float) -> float:
	if t < 0.0:
		return 0.0
	return (sin(TAU * f * t) + sin(TAU * f * 2.0 * t) * 0.45 * exp(-t * 6.0) + sin(TAU * f * 3.0 * t) * 0.2 * exp(-t * 9.0)) \
			* exp(-t * 3.2) * minf(1.0, t / 0.003)


static func play(name: String, pitch: float = 1.0) -> void:
	if _players.is_empty() or not is_instance_valid(_players[0]) or not _bank.has(name) or not Sv.sfx:
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _bank[name]
	p.pitch_scale = pitch
	p.volume_db = Snd.volume_db - 2.0
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
