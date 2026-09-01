extends Node

## 효과음. **오토로드**라 어디서든 `Snd.hit()` 처럼 부른다.
##
## zombie-defense 의 `snd.gd` 는 프레임마다 GDScript 로 샘플을 하나씩 합성한다.
## 그 방식은 살아 있는 목소리 수가 그대로 프레임을 먹는데, **리듬게임은 초당
## 10번 넘게 타격음이 난다** — 그대로 옮기면 제일 바쁜 구간에서 프레임이 떨어지고,
## 프레임이 떨어지면 노트가 떨려 보여서 못 친다. 소리 때문에 게임이 안 되는 셈이다.
##
## 그래서 여기서는 **시작할 때 한 번 렌더**해 [AudioStreamWAV] 로 굳혀 두고,
## 재생은 [AudioStreamPlayer] 풀로만 한다. 합성 비용은 켤 때 한 번뿐이고
## 재생은 엔진(C++)이 한다. 음원 파일은 여전히 없다.

const RATE := 32000
const VOICES := 12        ## 동시 재생 수. 넘치면 가장 오래된 것을 뺏는다.

var _bank := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	_bank["hit"] = _render(_tap.bind(1.0))
	_bank["hit2"] = _render(_tap.bind(1.32))      ## 안쪽 레인 — 음정을 올려 손이 갈린다
	_bank["hold"] = _render(_tap.bind(0.78))
	_bank["miss"] = _render(_miss)
	_bank["click"] = _render(_click)              ## 캘리브레이션 메트로놈
	_bank["ui"] = _render(_ui)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)


## `gate` 는 이 소리를 어느 볼륨 설정에 매달 것인가다. 음수면 타격음 볼륨.
##
## **메뉴 소리와 메트로놈은 타격음과 따로 매달아야 한다.** 타격음 기본값이 0
## 이라서(음이탈 설계, [Warp] 참고) 같이 매달면 캘리브레이션 메트로놈이 안 나고,
## 그러면 판정 보정 화면이 아무것도 못 하는 화면이 된다.
func play(name: String, vol := 1.0, pitch := 1.0, gate := -1.0) -> void:
	var s = _bank.get(name, null)
	var g: float = Sv.vol_hit if gate < 0.0 else gate
	if s == null or g <= 0.001:
		return
	var p := _pool[_next]
	_next = (_next + 1) % VOICES
	p.stream = s
	p.pitch_scale = pitch
	p.volume_db = linear_to_db(clampf(vol * g, 0.0001, 1.0))
	p.play()


## 레인에 맞는 타격음. 바깥/안쪽 레인의 음색이 갈려야 양손이 따로 인식된다.
func hit(lane: int, keys: int) -> void:
	play("hit" if (lane == 0 or lane == keys - 1) else "hit2", 0.9)


func miss() -> void:
	play("miss", 0.8)


func ui() -> void:
	play("ui", 0.55, 1.0, Sv.vol_ui)


func click(accent := false) -> void:
	play("click", 0.9 if accent else 0.5, 1.5 if accent else 1.0, Sv.vol_ui)


# ==================== 합성 ====================

## 콜러블을 받아 PCM 을 굳힌다. cb(t) -> -1..1
func _render(cb: Callable, dur := 0.22) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var v: float = clampf(cb.call(float(i) / RATE), -1.0, 1.0)
		var s := int(v * 32000.0)
		bytes.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w


## 짧고 단단한 타격음. 배음 두 개 + 아주 짧은 노이즈 어택.
## **어택이 없으면 "퉁" 하고 뭉개져서 박자를 못 준다** — 리듬게임 타격음의 핵심은
## 몸통이 아니라 맨 앞 3ms 다.
func _tap(t: float, k: float) -> float:
	var env := exp(-t * 46.0)
	var atk := exp(-t * 900.0)
	var f := 880.0 * k
	var body := sin(TAU * f * t) * 0.55 + sin(TAU * f * 2.0 * t) * 0.22
	return (body * env + _noise(t) * atk * 0.5) * 0.9


func _miss(t: float) -> float:
	var env := exp(-t * 15.0)
	# 음정이 내려간다 — 잘못됐다는 신호는 올라가면 안 된다.
	var f := 320.0 * (1.0 - t * 1.1)
	return sin(TAU * maxf(f, 60.0) * t) * env * 0.45


func _click(t: float) -> float:
	return _noise(t) * exp(-t * 260.0) * 0.7 + sin(TAU * 1600.0 * t) * exp(-t * 120.0) * 0.3


func _ui(t: float) -> float:
	var env := exp(-t * 30.0)
	return (sin(TAU * 660.0 * t) * 0.6 + sin(TAU * 990.0 * t) * 0.3) * env * 0.5


## 결정적 노이즈. randf() 를 쓰면 켤 때마다 소리가 미세하게 달라진다.
func _noise(t: float) -> float:
	var x := sin(t * 12543.7) * 43758.5453
	return (x - floorf(x)) * 2.0 - 1.0
