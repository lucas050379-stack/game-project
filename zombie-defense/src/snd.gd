extends Node

## 실시간 합성 사운드. 음원 파일이 하나도 없다 —
## AudioStreamGenerator 에 PCM 을 직접 밀어 넣는다. wav·mp3 를 추가하지 말 것.
##
## 이 게임은 초당 **수백 번** 효과음이 난다(적 300마리가 한꺼번에 죽는다).
##
## **합성은 샘플 단위 GDScript 루프다** — 살아 있는 목소리 수가 그대로 프레임을 먹는다.
## 22개가 계속 차 있으면 초당 22050샘플 × 22 = 프레임당 8천 번의 `_sample()` 호출이고,
## 실측으로 **프레임당 4~8ms** 였다. 적을 800마리까지 늘렸을 때 그리기를 최하 등급으로
## 내려도 35fps 를 못 넘던 진짜 이유가 이것이었다.
##
## 그래서 두 가지를 둔다.
##  1) 목소리 수 상한 (`MAX_VOICES`)
##  2) **자주 나는 소리의 최소 간격** (`MIN_GAP`) — 같은 소리가 1/20초 안에 여러 번 나도
##     귀로는 구분이 안 되므로 첫 것만 낸다. 소리도 오히려 덜 뭉개진다.

const RATE := 22050.0
const MAX_VOICES := 10

## 효과음 이름 -> 최소 간격(초). 없는 이름은 제한 없음.
const MIN_GAP := {
	"shot": 0.055, "kill": 0.070, "pick": 0.055, "boom": 0.060,
	"hurt": 0.110, "zap": 0.055, "laser": 0.055, "fire": 0.070,
	"launch": 0.060, "whoosh": 0.060, "throw": 0.055,
	# 새 스킬들. 회전 참격·연사 화살은 초당 여러 번 나므로 반드시 여기 있어야 한다.
	"slash": 0.060, "bow": 0.055, "cast": 0.055, "block": 0.070,
	# 동전은 자석을 켜면 수십 개가 한꺼번에 들어온다.
	"coin": 0.055, "crate": 0.080,
	# 침 뱉기는 사거리 안의 침 뱉는 좀비가 전부 2.6초마다 쏜다 — 후반엔 수십 마리다.
	"spit": 0.100,
}

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
## 효과음 이름 -> 마지막으로 낸 시각(초). `_gate` 가 본다.
var _last := {}

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

## 같은 소리가 너무 촘촘히 나면 건너뛴다. `MIN_GAP` 에 없는 이름은 항상 통과한다.
func _gate(name: String) -> bool:
	var gap: float = MIN_GAP.get(name, 0.0)
	if gap <= 0.0:
		return true
	var now := float(Time.get_ticks_msec()) * 0.001
	if now - float(_last.get(name, -99.0)) < gap:
		return false
	_last[name] = now
	return true


## 총 한 발 — 짧은 잡음 파열음 + 낮은 몸통. 연사라 아주 짧고 작아야 귀가 안 아프다.
func shot() -> void:
	if not _gate("shot"):
		return
	_play(1800.0, 300.0, 0.045, NOISE, 0.11, 4.2)
	_play(240.0, 90.0, 0.05, SQUARE, 0.07, 3.6)


## 칼을 휘두르는 소리 — 위에서 아래로 훑는 바람. 총소리(파열)와 반대 방향이라 안 겹친다.
func slash() -> void:
	if not _gate("slash"):
		return
	_play(1400.0, 260.0, 0.11, NOISE, 0.10, 3.0)
	_play(520.0, 180.0, 0.09, TRI, 0.07, 3.2)


## 활 — 시위가 튕기는 짧은 저음 + 화살이 가르는 바람
func bow() -> void:
	if not _gate("bow"):
		return
	_play(180.0, 90.0, 0.06, TRI, 0.09, 3.8)
	_play(900.0, 2000.0, 0.05, NOISE, 0.06, 3.4)


## 주문 — 위로 훑는 맑은 소리. 총·활과 달리 **음정이 오른다**.
func cast() -> void:
	if not _gate("cast"):
		return
	_play(420.0, 980.0, 0.13, TRI, 0.11, 2.4)
	_play(840.0, 1960.0, 0.09, SINE, 0.06, 3.0)


## 적 탄이 막히는 소리 — 짧고 단단한 금속음. 이게 있어야 "막았다"가 눈이 아니라 귀로도 온다.
func block() -> void:
	if not _gate("block"):
		return
	_play(1600.0, 900.0, 0.06, SQUARE, 0.09, 3.6)
	_play(320.0, 160.0, 0.05, TRI, 0.06, 3.4)


## 도끼가 도는 소리
func throw_() -> void:
	if not _gate("throw"):
		return
	_play(300.0, 700.0, 0.12, SAW, 0.09, 2.8)


func zap() -> void:
	if not _gate("zap"):
		return
	_play(1500.0, 400.0, 0.13, SQUARE, 0.12, 2.6)
	_play(3200.0, 900.0, 0.07, NOISE, 0.09, 3.4)


func laser() -> void:
	if not _gate("laser"):
		return
	_play(260.0, 1500.0, 0.16, SAW, 0.13, 2.0)


func boom() -> void:
	if not _gate("boom"):
		return
	_play(180.0, 44.0, 0.30, NOISE, 0.24, 2.0)
	_play(120.0, 40.0, 0.24, SINE, 0.20, 2.2)


func fire() -> void:
	if not _gate("fire"):
		return
	_play(420.0, 160.0, 0.22, NOISE, 0.12, 2.4)


func launch() -> void:
	if not _gate("launch"):
		return
	_play(300.0, 900.0, 0.14, SAW, 0.11, 2.4)


func whoosh() -> void:
	if not _gate("whoosh"):
		return
	_play(160.0, 520.0, 0.16, TRI, 0.13, 2.2)


## 적이 침을 뱉는 소리 — 위로 훑는 쉭 소리. 아군 총소리(짧은 파열음)와 안 겹쳐야
## "내가 쏜 게 아니라 맞을 것이 날아온다"로 들린다. 목소리 하나만 쓴다.
func spit() -> void:
	if not _gate("spit"):
		return
	_play(320.0, 1150.0, 0.13, NOISE, 0.10, 2.6)


func kill() -> void:
	if not _gate("kill"):
		return
	_play(520.0, 180.0, 0.06, SQUARE, 0.055, 3.6)


func hurt() -> void:
	if not _gate("hurt"):
		return
	_play(240.0, 70.0, 0.22, SAW, 0.26, 2.0)


func pick() -> void:
	if not _gate("pick"):
		return
	_play(880.0, 1320.0, 0.05, SINE, 0.07, 3.0)


## 자석을 주웠다 — 위로 쭉 훑는 소리. **젬 줍는 소리(`pick`)와 확실히 달라야** 한다.
## 그 뒤로 수십 개가 한꺼번에 들어오면서 `pick` 이 연달아 나므로, 시작을 알리는 소리가
## 그 무리에 묻히면 무엇 때문에 벌어진 일인지 알 수 없다. 최소 간격은 두지 않는다 —
## 한 라운드에 한두 번뿐이라 반드시 들려야 한다.
func magnet() -> void:
	_play(300.0, 1800.0, 0.34, TRI, 0.20, 1.8)
	_play(150.0, 900.0, 0.34, SINE, 0.16, 2.0)


## 구급 상자를 주웠다 — 부드럽게 올라가는 두 음. 자석(`magnet`, 길게 훑는 소리)과
## 음색·길이를 다르게 둬서 무엇을 주웠는지 소리만으로도 갈린다.
func heal() -> void:
	_play(520.0, 784.0, 0.20, SINE, 0.17, 2.2)
	_play(784.0, 1175.0, 0.28, TRI, 0.11, 2.6)


## 동전 — 아주 짧은 딸랑. 초당 여러 번 나므로 최소 간격이 반드시 필요하다.
func coin() -> void:
	if not _gate("coin"):
		return
	_play(1320.0, 1760.0, 0.05, TRI, 0.07, 3.2)


## 통이 부서지는 소리
func crate() -> void:
	if not _gate("crate"):
		return
	_play(300.0, 90.0, 0.14, NOISE, 0.13, 2.8)


## 보물상자를 열었다 — **판에서 제일 좋은 순간**이라 길고 화려하게 낸다.
func chest() -> void:
	for i in 5:
		_play(_note(i * 4), _note(i * 4 + 12), 0.34 + i * 0.06, TRI, 0.17, 2.0)
	_play(90.0, 700.0, 0.5, SINE, 0.16, 1.9)


## 아르카나를 골랐다 — 낮게 깔리는 울림. 되돌릴 수 없는 선택이라 무겁게.
func arcana() -> void:
	_play(120.0, 60.0, 0.7, SINE, 0.26, 1.6)
	_play(360.0, 240.0, 0.6, TRI, 0.14, 1.9)


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


## 보스가 스킬을 준비한다 — **화면을 안 보고 있어도 들려야 한다.** 올라가는 으르렁 소리라
## 등장음(`boss`, 내려가는 소리)과 방향이 반대다.
func boss_cast() -> void:
	_play(60.0, 150.0, 0.55, SAW, 0.24, 1.8)
	_play(180.0, 300.0, 0.40, SQUARE, 0.10, 2.2)


## 돌진 — 짧고 세게 훑는다
func boss_dash() -> void:
	_play(220.0, 60.0, 0.30, NOISE, 0.20, 2.0)
	_play(110.0, 55.0, 0.26, SAW, 0.16, 2.2)


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
