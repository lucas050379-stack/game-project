class_name Warp
extends RefCounted

## 음이탈. **틀리면 음악 자체가 무너진다.**
##
## 이 게임에는 노트를 칠 때 나는 타격음이 없다(기본값). 리듬게임의 타격음은
## 원곡 위에 없는 소리를 얹는 것이라 곡을 방해하는데, 이 게임은 원곡을 그대로
## 들려주는 것이 목적이기 때문이다. 대신 **잘 치는 것에 대한 보상이 "원곡이
## 깨끗하게 들리는 것" 자체**이고, 틀리면 그 원곡이 망가진다.
##
## ## 왜 진짜 키음이 아닌가
##
## 비트매니아·BMS 는 곡을 노트 하나당 음원 하나로 쪼개 두고 **친 노트의 음원만**
## 재생한다. 다 맞히면 원곡이 완성되고 놓치면 그 소리가 통째로 빠진다.
## 그건 작곡가가 트랙을 따로 만들어 뒀기 때문에 되는 것이고, **이미 믹스가 끝난
## mp4 에서는 소리를 다시 분리할 수 없다.** 그래서 반대로 만든다 —
## 원곡을 계속 틀되 틀린 만큼 망가뜨린다.
##
## ## 왜 음정 이동(AudioEffectPitchShift)을 안 쓰는가
##
## "음이탈" 이라면 음정을 내리는 게 제일 곧이곧대로지만 두 가지가 걸린다.
##   1. FFT 기반이라 **버스에 얹는 것만으로 항상 지연이 생긴다.** 그 지연은
##      `AudioServer.get_output_latency()` 에 안 잡히므로 [Conductor] 가 모른다.
##      상수라서 캘리브레이션으로 흡수되긴 하지만, 판정의 기준선을 흔드는 값을
##      효과 하나 때문에 들여올 이유가 없다.
##   2. `pitch_scale = 1.0` 이어도 그래뉼러 처리가 원음을 미세하게 상하게 한다.
##      **"100% 치면 원곡 그대로"가 이 기능의 전제**인데 그게 깨진다.
##
## 여기 쓰는 셋은 중립값에서 **수학적으로 통과**다 — 로우패스는 차단 주파수를
## 가청 대역 밖에 두고, 코러스는 `wet = 0`(마른 소리만), 볼륨은 0dB.
## 그래서 다 맞히는 동안에는 효과가 하나도 안 걸린 것과 같다.
##
## 음정은 코러스의 **깊은 흔들림**(`depth_ms`)으로 낸다. 늘어진 테이프처럼
## 음이 위아래로 출렁이는 소리이고, 로우패스가 먹먹하게 덮고 볼륨이 주저앉는다.

const BUS := "Music"

var idx := -1
var _lp: AudioEffectLowPassFilter
var _ch: AudioEffectChorus
var _last := -1.0


## 버스와 효과를 만든다. 이미 있으면 그대로 쓴다.
func setup() -> void:
	idx = AudioServer.get_bus_index(BUS)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS)
		AudioServer.set_bus_send(idx, "Master")
	# 이미 얹혀 있으면 다시 얹지 않는다(창 크기 변경 등으로 다시 불릴 수 있다).
	for i in AudioServer.get_bus_effect_count(idx):
		var e := AudioServer.get_bus_effect(idx, i)
		if e is AudioEffectLowPassFilter:
			_lp = e
		elif e is AudioEffectChorus:
			_ch = e
	if _lp == null:
		_lp = AudioEffectLowPassFilter.new()
		# 기본값이 2000Hz 라 그냥 얹으면 멀쩡한 곡이 먹먹해진다. 반드시 올려 둔다.
		_lp.cutoff_hz = 20000.0
		_lp.resonance = 0.5
		AudioServer.add_bus_effect(idx, _lp)
	if _ch == null:
		_ch = AudioEffectChorus.new()
		_ch.voice_count = 2
		_ch.dry = 1.0
		_ch.wet = 0.0          ## 중립 — 마른 소리만 지난다
		# 두 목소리를 서로 다른 속도로 흔들어야 "늘어진 테이프"가 된다.
		# 같은 속도면 그냥 코러스로 들려서 오히려 듣기 좋아진다.
		_ch.set("voice/1/delay_ms", 14.0)
		_ch.set("voice/1/rate_hz", 0.9)
		_ch.set("voice/1/cutoff_hz", 9000.0)
		_ch.set("voice/1/pan", -0.35)
		_ch.set("voice/2/delay_ms", 21.0)
		_ch.set("voice/2/rate_hz", 1.5)
		_ch.set("voice/2/cutoff_hz", 9000.0)
		_ch.set("voice/2/pan", 0.35)
		AudioServer.add_bus_effect(idx, _ch)
	apply(0.0)


## 0 = 원곡 그대로, 1 = 완전히 무너진 소리.
func apply(w: float) -> void:
	if idx < 0:
		return
	w = clampf(w, 0.0, 1.0)
	if absf(w - _last) < 0.002:
		return                  # 값이 안 바뀌면 건드리지 않는다
	_last = w
	# 차단 주파수는 로그로 내린다. 선형으로 내리면 앞의 절반이 아무 소리도 안 난다 —
	# 사람 귀는 주파수를 비율로 듣는다.
	_lp.cutoff_hz = 20000.0 * pow(D.WARP_CUTOFF_LO / 20000.0, w)
	_ch.wet = w * D.WARP_WET
	# 많이 틀릴수록 더 깊고 더 빠르게 흔들린다.
	_ch.set("voice/1/depth_ms", lerpf(2.0, D.WARP_DEPTH, w))
	_ch.set("voice/2/depth_ms", lerpf(3.0, D.WARP_DEPTH * 1.3, w))
	_ch.set("voice/1/rate_hz", lerpf(0.9, 2.1, w))
	_ch.set("voice/2/rate_hz", lerpf(1.5, 3.2, w))
	AudioServer.set_bus_volume_db(idx, D.WARP_DUCK_DB * w)


## 곡을 나갈 때. 다음 판이 망가진 소리로 시작하지 않게 되돌린다.
func reset() -> void:
	apply(0.0)
