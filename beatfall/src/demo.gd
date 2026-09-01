class_name Demo
extends RefCounted

## 내장 데모 곡. 음원 파일 없이 코드로 만든다.
##
## 두 가지 역할이 있다.
##  1. mp4 를 가져오기 전에도 게임이 **오늘 당장** 돌아야 한다.
##  2. `analyze.gd`(자동 채보)의 **정답지**다. 곡과 채보가 같은 표(`_events`)에서
##     나오므로, 이 곡을 wav 로 뽑아 분석기에 넣으면 "원래 노트가 몇 개였고
##     분석기가 몇 개를 맞췄는지"를 정확히 잴 수 있다. 실제 mp4 로는 이 검산이 불가능하다.

const RATE := 22050
const BPM := 128.0
const BARS := 18

enum { KICK, SNARE, HAT, LEAD, BASS, PAD }

## 오음계(A 단조). 반음이 없어서 아무 순서로 늘어놓아도 어긋나 들리지 않는다.
const SCALE := [220.0, 261.63, 293.66, 329.63, 392.00, 440.0, 523.25, 587.33]

static var _cached_stream: AudioStreamWAV = null
static var _cached_bed: AudioStreamWAV = null
static var _cached_keys: AudioStreamWAV = null
## 세 렌더가 같이 쓰는 이득. 전체 믹스에서 한 번 정한다.
static var _gain := 0.0


static func beat() -> float:
	return 60.0 / BPM


## 곡 전체 길이(초).
static func length() -> float:
	return BARS * 4.0 * beat() + 1.2


## 곡을 이루는 소리 하나하나. {t, kind, freq, dur}
## 채보도 오디오도 전부 이 목록에서 나온다 — 그래서 싱크가 원리적으로 안 어긋난다.
static func events() -> Array:
	var b := beat()
	var ev: Array = []
	for bar in BARS:
		var t0 := bar * 4.0 * b
		var full := bar >= 2                      ## 2마디는 인트로
		var lead_on := (bar >= 4 and bar < 8) or bar >= 11
		var root: float = SCALE[[0, 0, 4, 3][bar % 4]] * 0.5
		# --- 킥: 1박·3박, 4마디마다 3박 뒤에 하나 더 ---
		ev.append({"t": t0, "kind": KICK, "freq": 0.0, "dur": 0.20})
		ev.append({"t": t0 + 2.0 * b, "kind": KICK, "freq": 0.0, "dur": 0.20})
		if full and bar % 4 == 3:
			ev.append({"t": t0 + 2.75 * b, "kind": KICK, "freq": 0.0, "dur": 0.20})
		# --- 스네어: 2박·4박 ---
		if full:
			ev.append({"t": t0 + b, "kind": SNARE, "freq": 0.0, "dur": 0.16})
			ev.append({"t": t0 + 3.0 * b, "kind": SNARE, "freq": 0.0, "dur": 0.16})
		# --- 하이햇: 8분음표 ---
		if full:
			for i in 8:
				ev.append({"t": t0 + i * 0.5 * b, "kind": HAT, "freq": 0.0, "dur": 0.06})
		# --- 베이스: 4분음표 ---
		if full:
			for i in 4:
				ev.append({"t": t0 + i * b, "kind": BASS, "freq": root, "dur": b * 0.9})
		# --- 패드: 2박짜리 지속음. 이 곡에서 유일하게 **길게 이어지는** 소리다.
		#     채보에서 롱노트가 되고, 자동 채보기의 지속 판정(_sustain)도 여기서 걸린다.
		if full:
			for i in 2:
				ev.append({"t": t0 + i * 2.0 * b, "kind": PAD,
					"freq": root * 2.0, "dur": b * 1.9})
		# --- 리드: 8분음표 리프 ---
		if lead_on:
			for i in 8:
				var step: int = [0, 2, 4, 2, 5, 4, 2, 3][i]
				if bar % 2 == 1:
					step = [4, 3, 2, 3, 0, 2, 4, 5][i]
				ev.append({"t": t0 + i * 0.5 * b, "kind": LEAD,
					"freq": SCALE[step] * 2.0, "dur": b * 0.42})
	ev.sort_custom(func(a, b2): return a.t < b2.t)
	return ev


# ==================== 오디오 ====================
##
## 곡을 **두 층**으로 낸다([Keys] 참고).
##   - 바닥층(bed): 저음 악기. 노트와 무관하게 계속 흐르고 [Conductor] 의 시계가 된다.
##   - 키음층(keys): 나머지. 노트 시각으로 잘려 노트에 붙는다 — 쳐야 소리가 난다.
##
## **데모는 여기서 진짜 스템 분리가 된다.** 곡이 이벤트 표에서 나오므로 악기를
## 골라 따로 렌더하면 그만이다. 실제 곡(mp4)에서는 이게 불가능해서 주파수로
## 가르는 수밖에 없다 — 그래서 데모가 키음 구조를 시험하기에 제일 좋은 곡이다.

## 바닥층에 남길 악기. 킥과 베이스만 — 리듬의 뼈대이고, 이것까지 노트에 매달면
## 한 번 틀렸을 때 곡이 통째로 끊긴다.
const BED_KINDS := [KICK, BASS]


## 곡 전체. 확인용·자동 채보 검사용이다.
static func stream() -> AudioStreamWAV:
	if _cached_stream == null:
		_cached_stream = _render([], false, true)
	return _cached_stream


static func stream_bed() -> AudioStreamWAV:
	if _cached_bed == null:
		_ensure_gain()
		_cached_bed = _render(BED_KINDS, true, false)
	return _cached_bed


static func stream_keys() -> AudioStreamWAV:
	if _cached_keys == null:
		_ensure_gain()
		_cached_keys = _render(BED_KINDS, false, false)
	return _cached_keys


## **두 층의 이득은 반드시 같아야 한다.** 층마다 따로 정규화하면 저음만 있는
## 바닥층이 통째로 커져서, 다 맞혔을 때 두 층의 합이 원곡과 다른 곡이 된다.
## 그래서 이득은 전체 믹스에서 한 번 정하고 세 렌더가 같이 쓴다.
static func _ensure_gain() -> void:
	if _gain <= 0.0:
		stream()


## `only` 가 비어 있으면 전부 섞는다. 아니면 `want` 에 따라 `only` 에 든 것만
## 넣거나(바닥층) `only` 에 없는 것만 넣는다(키음층).
static func _render(only: Array, want: bool, set_gain: bool) -> AudioStreamWAV:
	var n := int(length() * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	# **섞는 루프를 함수로 빼지 말 것.** GDScript 의 `Packed*Array` 는 값 타입이라
	# 버퍼를 인자로 넘기면 함수 안의 수정이 호출한 쪽에 반영되지 않고, 게다가 호출마다
	# 배열이 통째로 복사된다. 소리 400개면 70만 칸짜리 배열을 400번 복사하는 셈이라
	# 실제로 곡 하나 만드는 데 몇 분이 걸렸다.
	for e in events():
		if not only.is_empty() and only.has(e.kind) != want:
			continue
		var i0 := int(float(e.t) * RATE)
		var cnt := int(float(e.dur) * RATE)
		var kind: int = e.kind
		var freq: float = e.freq
		var dur: float = e.dur
		for i in cnt:
			var idx := i0 + i
			if idx < 0 or idx >= n:
				continue
			buf[idx] += _sample(kind, float(i) / RATE, freq, dur)
	if set_gain:
		# 클리핑 방지. 소리를 다 더한 뒤에 한 번만 누른다 —
		# 소리마다 미리 줄이면 혼자 나는 구간이 너무 작아진다.
		var peak := 0.0
		for v in buf:
			peak = maxf(peak, absf(v))
		_gain = 0.92 / maxf(peak, 0.001)
	var g := _gain if _gain > 0.0 else 1.0
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(buf[i] * g, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w


static func _sample(kind: int, t: float, f: float, dur: float) -> float:
	match kind:
		KICK:
			# 음정이 내려가는 사인. 킥은 "쿵" 하는 몸통보다 맨 앞의 뚝 소리가 박자를 준다.
			var ff := 45.0 + 95.0 * exp(-t * 34.0)
			return sin(TAU * ff * t) * exp(-t * 13.0) * 0.95
		SNARE:
			return (_noise(t) * 0.75 + sin(TAU * 190.0 * t) * 0.25) * exp(-t * 26.0) * 0.6
		HAT:
			return _noise(t * 3.1) * exp(-t * 150.0) * 0.22
		LEAD:
			var env := minf(t * 220.0, 1.0) * exp(-t * 7.5)
			return (_square(f, t) * 0.5 + sin(TAU * f * t) * 0.35) * env * 0.30
		BASS:
			var env2 := minf(t * 120.0, 1.0) * (1.0 - smoothstep(dur * 0.6, dur, t))
			return _saw(f, t) * env2 * 0.34
		PAD:
			# 천천히 붙고 천천히 빠진다. 어택이 무디어야 "이어지는 소리"로 들린다 —
			# 킥처럼 뚝 시작하면 길어도 타악기로 들린다.
			var env3 := minf(t * 14.0, 1.0) * (1.0 - smoothstep(dur * 0.75, dur, t))
			# 5도를 겹쳐 화음으로 만든다. 단음은 지속음이라도 얇게 들린다.
			return (_saw(f, t) * 0.5 + _saw(f * 1.5, t) * 0.3) * env3 * 0.16
	return 0.0


static func _square(f: float, t: float) -> float:
	return 1.0 if fmod(f * t, 1.0) < 0.5 else -1.0


static func _saw(f: float, t: float) -> float:
	return fmod(f * t, 1.0) * 2.0 - 1.0


static func _noise(t: float) -> float:
	var x := sin(t * 12543.7) * 43758.5453
	return (x - floorf(x)) * 2.0 - 1.0


# ==================== 채보 ====================

## 난이도마다 어떤 소리를 노트로 삼을지. 이게 곧 난이도다 —
## 밀도를 곱으로 조절하지 않고 **어떤 악기를 치느냐**로 나눈다.
const PICK := {
	"EASY": [KICK, SNARE],
	"NORMAL": [KICK, SNARE, LEAD, PAD],
	"HARD": [KICK, SNARE, LEAD, HAT, PAD],
}

## 악기별 기본 레인. 킥은 왼쪽 끝, 스네어는 오른쪽 끝 — 양손이 갈린다.
const HOME := {KICK: 0, SNARE: 3, LEAD: 1, HAT: 2, BASS: 1, PAD: 2}

## 이 악기는 롱노트가 된다. 소리가 실제로 이어지는 만큼 눌러야 한다.
const HOLD_KINDS := [PAD]


static func chart() -> Chart:
	var c := Chart.new()
	c.title = "비트폴 데모"
	c.artist = "코드로 합성"
	c.bpm = BPM
	c.offset = 0.0
	c.dir = ""
	var ev := events()
	for name in ["EASY", "NORMAL", "HARD"]:
		var keys := 4
		var kinds: Array = PICK[name]
		var notes: Array = []
		## 같은 시각·같은 레인에 두 개가 겹치지 않게 자리를 옮긴다.
		var busy := {}
		for e in ev:
			if not kinds.has(e.kind):
				continue
			var lane := _place(int(HOME[e.kind]), e.t, keys, busy)
			if lane < 0:
				continue
			var dur := float(e.dur) if HOLD_KINDS.has(e.kind) else 0.0
			# **롱노트는 누르고 있는 동안 그 레인을 통째로 차지한다.** 끝나는 시각을
			# 넣어 둬야 그 위에 다른 노트가 얹히지 않는다 — 얹히면 손이 하나 모자란다.
			busy[lane] = float(e.t) + dur
			notes.append([e.t, lane, dur])
		notes.sort_custom(func(a, b): return a[0] < b[0])
		var span: float = notes[notes.size() - 1][0] - notes[0][0]
		var nps := float(notes.size()) / maxf(span, 0.1)
		c.diffs.append({"name": name, "keys": keys,
			"level": D.level_of(nps, keys), "notes": notes})
	return c


## 원하는 레인이 방금 눌렸으면 가까운 빈 레인으로 옮긴다.
## 사람이 못 치는 배치(같은 손가락으로 20ms 안에 두 번)를 애초에 안 만든다.
static func _place(want: int, t: float, keys: int, busy: Dictionary) -> int:
	for d in keys:
		for s in [1, -1]:
			var lane: int = want + d * s
			if lane < 0 or lane >= keys:
				continue
			if t - float(busy.get(lane, -99.0)) >= D.AN_SAME_LANE_GAP:
				return lane
			if d == 0:
				break
	return -1
