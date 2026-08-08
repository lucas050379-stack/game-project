extends Node

## 실시간 합성 사운드. 음원 파일이 하나도 없다 —
## AudioStreamGenerator 에 PCM 을 직접 밀어 넣는다. wav·mp3 를 추가하지 말 것.
##
## 이 게임은 초당 수십 번 효과음이 난다. 그래서 목소리(voice) 수에 상한을 두고
## 같은 소리가 몰리면 오래된 것부터 버린다. 안 그러면 소리가 뭉개지고 CPU 도 먹는다.

const RATE := 22050.0
const MAX_VOICES := 22

const SINE := 0
const SQUARE := 1
const SAW := 2
const NOISE := 3
const TRI := 4

var muted := false

var _player: AudioStreamPlayer
var _pb: AudioStreamGeneratorPlayback
var _voices: Array = []
var _phase := 0.0

# --- BGM 시퀀서 ---
var _bgm_on := false
var _bgm_t := 0.0
var _bgm_step := 0
const BPM := 138.0
## 단조 5음계 — 좀비물에 어울리게 어둡게
const BASS := [0, 0, 3, 0, 5, 3, 0, -2]
const LEAD := [12, 15, 19, 15, 17, 15, 12, 10]


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.09
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	_player.volume_db = -6.0
	add_child(_player)
	_player.play()
	_pb = _player.get_stream_playback()


func _process(_dt: float) -> void:
	if _pb == null:
		return
	var n := _pb.get_frames_available()
	if n <= 0:
		return
	var dt := 1.0 / RATE
	for i in n:
		if _bgm_on:
			_tick_bgm(dt)
		var s := 0.0
		for vi in range(_voices.size() - 1, -1, -1):
			var v: Dictionary = _voices[vi]
			var t: float = v["t"]
			if t >= float(v["dur"]):
				_voices.remove_at(vi)
				continue
			s += _sample(v, t)
			v["t"] = t + dt
		s = clampf(s * (0.0 if muted else 1.0), -1.0, 1.0)
		# 살짝 부드럽게 — 딱딱한 사각파의 모서리를 깎는다
		_phase += (s - _phase) * 0.55
		_pb.push_frame(Vector2(_phase, _phase))


func _sample(v: Dictionary, t: float) -> float:
	var dur: float = v["dur"]
	var u := t / dur
	var f: float = lerpf(float(v["f0"]), float(v["f1"]), u)
	var env: float = pow(1.0 - u, float(v["decay"]))
	# 아주 짧은 어택 — 클릭 잡음 방지
	env *= clampf(t / 0.004, 0.0, 1.0)
	var ph := t * f
	var w := 0.0
	match int(v["wave"]):
		SINE: w = sin(ph * TAU)
		SQUARE: w = 1.0 if fposmod(ph, 1.0) < 0.5 else -1.0
		SAW: w = fposmod(ph, 1.0) * 2.0 - 1.0
		TRI: w = absf(fposmod(ph, 1.0) * 4.0 - 2.0) - 1.0
		NOISE: w = randf() * 2.0 - 1.0
	return w * env * float(v["vol"])


func _play(f0: float, f1: float, dur: float, wave: int, vol: float, decay: float = 2.0) -> void:
	if muted:
		return
	while _voices.size() >= MAX_VOICES:
		_voices.pop_front()
	_voices.append({
		"f0": f0, "f1": f1, "dur": dur, "wave": wave,
		"vol": vol, "decay": decay, "t": 0.0,
	})

# ==================== BGM ====================

func music(on: bool) -> void:
	_bgm_on = on
	if not on:
		_bgm_step = 0
		_bgm_t = 0.0


func _tick_bgm(dt: float) -> void:
	_bgm_t += dt
	var step_len := 60.0 / BPM / 4.0
	if _bgm_t < step_len:
		return
	_bgm_t -= step_len
	var s := _bgm_step % 16
	_bgm_step += 1
	if s % 2 == 0:
		var n: int = BASS[(s / 2) % BASS.size()]
		_play(_note(n - 24), _note(n - 24), 0.16, SQUARE, 0.16, 2.6)
	if s % 4 == 2:
		_play(240.0, 190.0, 0.05, NOISE, 0.07, 3.0)      # 하이햇
	if s == 0 or s == 8:
		_play(70.0, 42.0, 0.13, SINE, 0.30, 2.2)         # 킥
	if s % 8 == 6:
		var m: int = LEAD[(s / 2) % LEAD.size()]
		_play(_note(m - 12), _note(m - 12), 0.11, TRI, 0.10, 3.0)


static func _note(semi: int) -> float:
	return 220.0 * pow(2.0, semi / 12.0)

# ==================== 효과음 ====================

func throw_() -> void:
	_play(720.0, 340.0, 0.07, SAW, 0.10, 3.2)


func zap() -> void:
	_play(1500.0, 400.0, 0.13, SQUARE, 0.12, 2.6)
	_play(3200.0, 900.0, 0.07, NOISE, 0.09, 3.4)


func laser() -> void:
	_play(260.0, 1500.0, 0.16, SAW, 0.13, 2.0)


func boom() -> void:
	_play(180.0, 44.0, 0.30, NOISE, 0.24, 2.0)
	_play(120.0, 40.0, 0.24, SINE, 0.20, 2.2)


func fire() -> void:
	_play(420.0, 160.0, 0.22, NOISE, 0.12, 2.4)


func launch() -> void:
	_play(300.0, 900.0, 0.14, SAW, 0.11, 2.4)


func whoosh() -> void:
	_play(160.0, 520.0, 0.16, TRI, 0.13, 2.2)


func kill() -> void:
	_play(520.0, 180.0, 0.06, SQUARE, 0.055, 3.6)


func hurt() -> void:
	_play(240.0, 70.0, 0.22, SAW, 0.26, 2.0)


func pick() -> void:
	_play(880.0, 1320.0, 0.05, SINE, 0.07, 3.0)


func levelup() -> void:
	for i in 4:
		_play(_note(i * 4), _note(i * 4 + 7), 0.16 + i * 0.03, TRI, 0.16, 2.4)


func ui() -> void:
	_play(660.0, 990.0, 0.06, SQUARE, 0.10, 3.0)


func revive() -> void:
	_play(180.0, 1400.0, 0.55, SAW, 0.22, 1.6)
	_play(90.0, 700.0, 0.55, SINE, 0.20, 1.8)


func boss() -> void:
	_play(70.0, 46.0, 0.75, SAW, 0.30, 1.5)
	_play(140.0, 92.0, 0.75, SQUARE, 0.16, 1.7)


func boss_die() -> void:
	_play(500.0, 60.0, 0.85, NOISE, 0.28, 1.6)
	for i in 3:
		_play(_note(12 + i * 5), _note(24 + i * 5), 0.45, TRI, 0.16, 2.0)


func gameover() -> void:
	music(false)
	for i in 4:
		_play(_note(6 - i * 4), _note(2 - i * 4), 0.5 + i * 0.12, SAW, 0.18, 2.0)


func clear_() -> void:
	music(false)
	for i in 5:
		_play(_note(i * 4), _note(i * 4 + 12), 0.4 + i * 0.08, TRI, 0.18, 2.2)
