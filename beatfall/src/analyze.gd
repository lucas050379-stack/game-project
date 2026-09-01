class_name An
extends RefCounted

## 오디오에서 채보를 뽑는다. mp4 를 가져오면 여기를 지난다.
##
##   mp4 --(ffmpeg)--> 22050Hz 모노 16bit wav --(이 파일)--> chart.json
##
## **게임 안에서 돌지 않는다.** `import.bat` 이 헤드리스 Godot 으로 한 번 돌리는
## 도구다. 그래서 3분짜리 곡에 수십 초가 걸려도 괜찮고, 대신 정확도를 우선한다.
##
## 순서:
##   1. wav 를 읽는다 (RIFF 직접 파싱 — 형식은 ffmpeg 로 우리가 정한다)
##   2. 짧은 창으로 FFT 를 걸어 **대역별 스펙트럼 플럭스**를 구한다.
##      플럭스 = 이번 프레임 에너지에서 지난 프레임 에너지를 뺀 양수 부분.
##      소리가 커지는 순간만 남는다 = 사람이 박으로 듣는 지점이다.
##   3. 대역마다 **지역 적응 문턱**으로 봉우리를 딴다. 고정 문턱을 쓰면
##      조용한 구간에서 아무것도 안 잡히고 시끄러운 구간에서 전부 잡힌다.
##   4. 온셋 포락선의 자기상관으로 BPM 과 첫 박 위치를 추정한다.
##   5. 격자에 붙이고, 세기 순으로 잘라 난이도별 밀도를 맞추고,
##      대역으로 레인을 정한 뒤 사람이 못 치는 배치를 걷어낸다.

# ==================== wav 읽기 ====================

## 모노 float 샘플로 돌려준다. 실패하면 빈 사전.
static func read_wav(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		printerr("wav 를 열지 못했습니다: ", path)
		return {}
	if f.get_buffer(4).get_string_from_ascii() != "RIFF":
		printerr("RIFF 가 아닙니다: ", path)
		return {}
	f.get_32()                                  # 파일 크기
	if f.get_buffer(4).get_string_from_ascii() != "WAVE":
		printerr("WAVE 가 아닙니다: ", path)
		return {}
	var ch := 1
	var rate := D.AN_RATE
	var bits := 16
	var data := PackedFloat32Array()
	while f.get_position() < f.get_length() - 8:
		var id := f.get_buffer(4).get_string_from_ascii()
		var sz := int(f.get_32())
		var next := f.get_position() + sz + (sz & 1)
		if id == "fmt ":
			f.get_16()                          # 포맷 태그
			ch = f.get_16()
			rate = int(f.get_32())
			f.get_32()                          # 초당 바이트
			f.get_16()                          # 블록 정렬
			bits = f.get_16()
		elif id == "data":
			if bits != 16:
				printerr("16비트 PCM 만 읽습니다. 지금은 %d비트입니다." % bits)
				return {}
			var n := sz / 2 / maxi(ch, 1)
			data.resize(n)
			var raw := f.get_buffer(sz)
			for i in n:
				# 채널이 여럿이면 섞는다. 리듬은 좌우로 갈리지 않는다.
				var acc := 0.0
				for c in ch:
					acc += float(raw.decode_s16((i * ch + c) * 2)) / 32768.0
				data[i] = acc / ch
		f.seek(next)
	f.close()
	if data.is_empty():
		printerr("data 청크가 없습니다: ", path)
		return {}
	return {"data": data, "rate": rate}


# ==================== FFT + 대역별 플럭스 ====================
##
## 라딕스-2 쿨리-투키. 트위들과 비트반전 순열은 창 크기마다 한 번만 만든다 —
## 프레임마다 다시 만들면 그게 곧 전체 비용이 된다.
##
## **FFT 를 따로 함수로 빼지 않고 [method spectral] 안에 펼쳐 두었다.** GDScript 의
## `Packed*Array` 는 값 타입(copy-on-write)이라 함수 인자로 넘겨서 안에서 고치면
## **호출한 쪽에는 반영되지 않는다.** `_fft(re, im, n)` 처럼 쓰면 조용히 원래
## 신호가 그대로 남아 스펙트럼이 아니라 파형을 대역으로 나눈 값이 나온다.
## 게다가 매 호출마다 배열이 통째로 복사되어 곡 하나에 수백 MB 를 옮긴다.
## 정적 변수로 빼도 조회 비용이 안쪽 루프에서 그대로 쌓이므로, 전부 지역 변수로 둔다.

static var _tw_cos := PackedFloat32Array()
static var _tw_sin := PackedFloat32Array()
static var _rev := PackedInt32Array()
static var _fft_n := 0


static func _fft_init(n: int) -> void:
	if _fft_n == n:
		return
	_fft_n = n
	_tw_cos.resize(n / 2)
	_tw_sin.resize(n / 2)
	for i in n / 2:
		var a := -TAU * i / n
		_tw_cos[i] = cos(a)
		_tw_sin[i] = sin(a)
	_rev.resize(n)
	var bits := int(round(log(n) / log(2.0)))
	for i in n:
		var r := 0
		var x := i
		for b in bits:
			r = (r << 1) | (x & 1)
			x >>= 1
		_rev[i] = r


## 대역 경계(Hz). 로그 간격 — 사람 귀가 그렇게 듣고, 악기도 그렇게 나뉜다.
## 낮은 대역은 킥과 베이스, 높은 대역은 하이햇과 심벌이다.
const BAND_HZ := [0.0, 110.0, 260.0, 620.0, 1500.0, 3600.0, 11025.0]


## 대역별 에너지와 플럭스.
## 돌려주는 것: {mag, flux, frames, spf, rate}
static func spectral(data: PackedFloat32Array, rate: int, on_progress: Callable) -> Dictionary:
	var n := D.AN_WIN
	var hop := D.AN_HOP
	_fft_init(n)
	# 정적 테이블을 지역으로 한 번만 옮긴다. 안쪽 루프에서 정적 변수를 조회하면
	# 그 비용이 프레임당 5천 번씩 쌓인다.
	var tw_cos := _tw_cos
	var tw_sin := _tw_sin
	var rev := _rev
	var frames := maxi(1, (data.size() - n) / hop)
	var nb := D.AN_BANDS
	# 해닝 창. 안 걸면 창 경계에서 생기는 가짜 고역 성분이 하이햇 대역에
	# 그대로 온셋으로 잡힌다.
	var win := PackedFloat32Array()
	win.resize(n)
	for i in n:
		win[i] = 0.5 - 0.5 * cos(TAU * i / (n - 1))
	var lo := PackedInt32Array()
	var hi := PackedInt32Array()
	lo.resize(nb)
	hi.resize(nb)
	for b in nb:
		lo[b] = clampi(int(float(BAND_HZ[b]) * n / rate), 1, n / 2 - 1)
		hi[b] = clampi(int(float(BAND_HZ[b + 1]) * n / rate), lo[b] + 1, n / 2)
	var mag: Array = []
	var flux: Array = []
	for b in nb:
		var m := PackedFloat32Array()
		m.resize(frames)
		mag.append(m)
		var fl := PackedFloat32Array()
		fl.resize(frames)
		flux.append(fl)
	var re := PackedFloat32Array()
	var im := PackedFloat32Array()
	re.resize(n)
	im.resize(n)
	var prev := PackedFloat32Array()
	prev.resize(nb)
	for fi in frames:
		var off := fi * hop
		# --- 창을 걸면서 비트반전 자리에 바로 넣는다 (한 번의 순회로 끝난다) ---
		for i in n:
			re[rev[i]] = data[off + i] * win[i]
			im[i] = 0.0
		# --- 버터플라이 ---
		var size := 2
		while size <= n:
			var half := size >> 1
			var step := n / size
			var i0 := 0
			while i0 < n:
				var k := 0
				for j in half:
					var cr := tw_cos[k]
					var ci := tw_sin[k]
					var a := i0 + j
					var b2 := a + half
					var xr := re[b2] * cr - im[b2] * ci
					var xi := re[b2] * ci + im[b2] * cr
					re[b2] = re[a] - xr
					im[b2] = im[a] - xi
					re[a] += xr
					im[a] += xi
					k += step
				i0 += size
			size <<= 1
		# --- 대역별 크기와 플럭스 ---
		for b in nb:
			var acc := 0.0
			for k2 in range(lo[b], hi[b]):
				acc += sqrt(re[k2] * re[k2] + im[k2] * im[k2])
			# 로그로 누른다. 선형이면 큰 소리 한 방이 곡 전체의 문턱을 올려 버린다.
			var v := log(1.0 + acc * 12.0)
			mag[b][fi] = v
			flux[b][fi] = 0.0 if fi == 0 else maxf(0.0, v - prev[b])
			prev[b] = v
		if on_progress.is_valid() and fi % 500 == 0:
			on_progress.call(float(fi) / frames)
	return {"mag": mag, "flux": flux, "frames": frames, "t_off": float(n) * 0.5 / rate,
		"spf": float(hop) / rate, "rate": rate}


# ==================== 온셋 ====================

## 대역마다 봉우리를 딴다. {t, band, strength, dur} 배열.
##
## 지역 평균과 표준편차는 **누적합으로** 구한다. 온셋마다 앞뒤 12프레임을 다시
## 더하면 프레임 수 x 창 크기가 되어 곡 하나에 수백만 번이 된다.
static func onsets(sp: Dictionary, mul := D.AN_THRESH_MUL, sdw := D.AN_THRESH_SD) -> Array:
	var out: Array = []
	var frames: int = sp.frames
	var spf: float = sp.spf
	# **창의 시작이 아니라 가운데를 온셋 시각으로 쓴다.** 창이 46ms 라 소리는 그 안
	# 어디에서든 날 수 있고, 시작으로 잡으면 채보가 곡보다 평균 20ms 빨라진다.
	# 판정창 PERFECT 가 ±42ms 이므로 그대로 두면 정확히 친 사람이 GREAT 를 받는다.
	var t_off: float = sp.t_off
	var L := D.AN_LOCAL
	for b in D.AN_BANDS:
		var fl: PackedFloat32Array = sp.flux[b]
		# 누적합 c1[i] = fl[0..i-1] 의 합, c2 는 제곱합.
		var c1 := PackedFloat64Array()
		var c2 := PackedFloat64Array()
		c1.resize(frames + 1)
		c2.resize(frames + 1)
		for i in frames:
			c1[i + 1] = c1[i] + fl[i]
			c2[i + 1] = c2[i] + fl[i] * fl[i]
		# 봉우리를 먼저 다 모은다. 길이는 그 다음에 잰다 —
		# **한 소리는 같은 대역의 다음 소리가 시작될 때 끝난다.** 그 경계를 알려면
		# 다음 봉우리가 어디인지 먼저 알아야 한다.
		var peaks := PackedInt32Array()
		var strengths := PackedFloat32Array()
		var last_t := -99.0
		for i in range(1, frames - 1):
			var v := fl[i]
			if v <= 0.0 or v < fl[i - 1] or v < fl[i + 1]:
				continue                       # 지역 최대만
			var a := maxi(0, i - L)
			var z := mini(frames, i + L + 1)
			var cnt := float(z - a)
			var mean := float(c1[z] - c1[a]) / cnt
			var sd := sqrt(maxf(0.0, float(c2[z] - c2[a]) / cnt - mean * mean))
			if mean <= 0.00001:
				continue
			if v < mean * mul or v < mean + sd * sdw:
				continue
			var t := i * spf + t_off
			if t - last_t < D.AN_MIN_GAP:
				continue
			last_t = t
			peaks.append(i)
			strengths.append(v / mean)
		for pi in peaks.size():
			var i := peaks[pi]
			var stop := frames if pi + 1 >= peaks.size() else peaks[pi + 1]
			out.append({"t": i * spf + t_off, "band": b, "strength": strengths[pi],
				"dur": _sustain(sp, b, i, stop)})
	out.sort_custom(func(x, y): return x.t < y.t)
	return out


## 이 온셋이 얼마나 이어지는지(초). 롱노트로 바꿀지 정하는 값이다.
##
## **절대값으로 재면 안 된다.** `mag` 는 로그 에너지라 음악이 흐르는 동안 계속
## 높게 유지된다 — "봉우리의 55% 위에 머무는 동안"으로 재면 곡이 끝날 때까지
## 참이어서 **거의 모든 노트가 롱노트가 된다**(실제로 552개 중 488개였다).
##
## 그래서 **온셋 직전 수준(base) 대비**로 잰다. 이 소리가 올려놓은 몫(rise)의
## 절반 아래로 떨어지면 끝난 것으로 본다. 짧은 타악기는 곧바로 base 로 돌아오고,
## 패드나 긴 음은 한동안 남는다 — 사람이 "이어진다"고 느끼는 것과 같은 기준이다.
## `stop` 은 같은 대역의 다음 온셋 프레임이다. 거기서 반드시 끊는다 —
## **되풀이되는 패턴에서는 에너지가 기준선으로 돌아오기 전에 다음 소리가 또
## 올려놓기 때문에**, 경계가 없으면 하이햇 한 대가 곡 끝까지 이어진 것으로 잡힌다
## (실제로 노트의 82~94%가 롱노트가 됐다).
static func _sustain(sp: Dictionary, b: int, i: int, stop: int) -> float:
	var mag: PackedFloat32Array = sp.mag[b]
	var frames: int = sp.frames
	# **바로 앞 프레임을 기준선으로 쓰면 안 된다.** 창이 1024, 홉이 512라 프레임이
	# 50% 겹치고, `mag[i-1]` 의 창에는 이미 타격음의 앞부분이 들어 있다. 그러면
	# 기준선이 부풀려져 `rise` 가 작아지고, 문턱이 기준선 바로 위에 앉아서
	# 소리의 꼬리가 그 위에 한참 머문다 — 킥의 지속 시간이 패드와 똑같이
	# 한 박(0.46초)으로 잡혔다.
	# 앞쪽 여섯 프레임의 **최소값**을 기준선으로, 뒤쪽 세 프레임의 **최대값**을
	# 봉우리로 잡는다.
	var base := mag[maxi(i - 1, 0)]
	for k0 in range(maxi(i - 6, 0), i):
		base = minf(base, mag[k0])
	var peak := mag[i]
	for k1 in range(i, mini(i + 3, frames)):
		peak = maxf(peak, mag[k1])
	var rise := peak - base
	if rise <= 0.0001:
		return 0.0
	# **"얼마나 오래 버티나"가 아니라 "얼마나 빨리 꺼지나"로 잰다.**
	# 문턱을 기준선 가까이(rise 의 40%) 두면 타악기의 긴 꼬리까지 세어서 킥이
	# 패드와 똑같이 한 박짜리 롱노트가 된다. 봉우리 가까이(75%) 두면 킥은
	# 곧바로 아래로 떨어지고 지속음만 남는다.
	var floor_v := base + rise * D.AN_SUSTAIN_FRAC
	var k := i + 2
	# 상한이 둘이다.
	#  - `stop`: 같은 대역의 다음 온셋. 한 소리는 다음 소리가 시작될 때 끝난다.
	#  - 6초: 페이드아웃처럼 천천히 빠지는 소리에서 롱노트가 30초짜리가 되면
	#    그 레인이 곡 내내 잠긴다.
	var cap := mini(mini(stop, frames), i + int(6.0 / float(sp.spf)))
	while k < cap and mag[k] >= floor_v:
		k += 1
	return (k - i) * float(sp.spf)


# ==================== BPM ====================

## 온셋 포락선의 자기상관으로 BPM 과 첫 박(초)을 추정한다.
static func tempo(sp: Dictionary, ons: Array) -> Dictionary:
	var frames: int = sp.frames
	var spf: float = sp.spf
	if frames < 64 or ons.is_empty():
		return {"bpm": 0.0, "phase": 0.0}
	var env := PackedFloat32Array()
	env.resize(frames)
	for o in ons:
		var i := int(float(o.t) / spf)
		if i >= 0 and i < frames:
			env[i] += float(o.strength)
	var lag_min := maxi(2, int(60.0 / D.AN_BPM_MAX / spf))
	var lag_max := mini(frames / 2, int(60.0 / D.AN_BPM_MIN / spf))
	var best := 0.0
	var best_lag := lag_min
	for lag in range(lag_min, lag_max + 1):
		var acc := 0.0
		for i in range(0, frames - lag):
			acc += env[i] * env[i + lag]
		# 긴 lag 일수록 항이 적어 불리하다. 개수로 나눠 공평하게 만든다.
		acc /= float(frames - lag)
		if acc > best:
			best = acc
			best_lag = lag
	var bpm := 60.0 / (best_lag * spf)
	# 범위 밖이면 절반이나 두 배로 접는다. 자기상관은 두 박 주기에서도 잘 맞는다.
	while bpm < D.AN_BPM_MIN:
		bpm *= 2.0
	while bpm > D.AN_BPM_MAX:
		bpm *= 0.5
	# 첫 박 위치: 박 간격으로 접은 히스토그램의 봉우리.
	var beat := 60.0 / bpm
	var bins := 48
	var hist := PackedFloat32Array()
	hist.resize(bins)
	for o in ons:
		var ph := fmod(float(o.t), beat) / beat
		hist[clampi(int(ph * bins), 0, bins - 1)] += float(o.strength)
	var bi := 0
	for i in bins:
		if hist[i] > hist[bi]:
			bi = i
	return {"bpm": bpm, "phase": (bi + 0.5) / bins * beat}


# ==================== 채보 만들기 ====================

static func build(ons: Array, tp: Dictionary, dur: float, title: String,
		artist: String, audio: String) -> Chart:
	var c := Chart.new()
	c.title = title
	c.artist = artist
	c.audio = audio
	c.bpm = snappedf(float(tp.bpm), 0.01)
	c.offset = 0.0
	var snapped := quantize(ons, tp)
	for spec in D.AN_DIFF:
		var keys: int = spec.keys
		var want := int(float(spec.nps) * dur)
		var picked := pick(snapped, want)
		var notes := lanes(picked, keys)
		if notes.is_empty():
			continue
		var span: float = notes[notes.size() - 1][0] - notes[0][0]
		var nps := float(notes.size()) / maxf(span, 1.0)
		c.diffs.append({"name": spec.name, "keys": keys,
			"level": D.level_of(nps, keys), "notes": notes})
	return c


## 격자에 붙인다. 가까우면 붙이고 멀면 원래 시각을 그대로 둔다 —
## 억지로 붙이면 리듬이 아니라 다른 곡이 된다.
static func quantize(ons: Array, tp: Dictionary) -> Array:
	var bpm := float(tp.bpm)
	if bpm <= 1.0:
		return ons.duplicate()
	var beat := 60.0 / bpm
	var step := beat * D.AN_QUANT
	var phase := float(tp.phase)
	var out: Array = []
	for o in ons:
		var d: Dictionary = o.duplicate()
		var k := roundf((float(o.t) - phase) / step)
		var g := phase + k * step
		if absf(g - float(o.t)) <= D.AN_SNAP_MAX * beat:
			d.t = maxf(0.0, g)
		out.append(d)
	out.sort_custom(func(x, y): return x.t < y.t)
	return out


## 세기 순으로 잘라 목표 개수를 맞춘다.
##
## **그냥 위에서 n 개를 자르면 안 된다.** 곡에서 제일 센 부분(후렴)에 전부 몰리고
## 조용한 구간이 통째로 비어서, 노트가 아예 없는 30초가 생긴다. 그래서 곡을
## 짧은 구간으로 나눠 구간마다 자기 몫을 배정하고 그 안에서 세기 순으로 고른다.
static func pick(ons: Array, want: int) -> Array:
	if ons.size() <= want or want <= 0:
		return ons.duplicate()
	var t0 := float(ons[0].t)
	var t1 := float(ons[ons.size() - 1].t)
	var span := maxf(t1 - t0, 1.0)
	var seg := 4.0                              ## 구간 길이(초)
	var nseg := maxi(1, int(ceil(span / seg)))
	var buckets: Array = []
	for i in nseg:
		buckets.append([])
	for o in ons:
		var i := clampi(int((float(o.t) - t0) / seg), 0, nseg - 1)
		buckets[i].append(o)
	var out: Array = []
	var quota := float(want) / nseg
	var carry := 0.0
	for b in buckets:
		var take := int(floorf(quota + carry))
		carry += quota - take
		if take <= 0:
			continue
		b.sort_custom(func(x, y): return x.strength > y.strength)
		for i in mini(take, b.size()):
			out.append(b[i])
	out.sort_custom(func(x, y): return x.t < y.t)
	return out


## 대역에서 레인을 정한다. 낮은 소리는 왼쪽, 높은 소리는 오른쪽.
## 그러면 킥과 스네어가 손에 익은 자리에 계속 오고 리프만 사이를 오간다.
static func lanes(ons: Array, keys: int) -> Array:
	var notes: Array = []
	var busy := PackedFloat32Array()
	busy.resize(keys)
	busy.fill(-99.0)
	var last_lane := -1
	var last_t := -99.0
	for o in ons:
		var t := float(o.t)
		var want := clampi(int(float(o.band) * keys / D.AN_BANDS), 0, keys - 1)
		# 같은 대역이 연달아 오면 손을 번갈아 쓰게 한 칸 민다.
		if want == last_lane and t - last_t < 0.20:
			want = (want + 1) % keys
		var lane := _place(want, t, keys, busy)
		if lane < 0:
			continue
		var dur := 0.0
		if float(o.dur) >= D.AN_HOLD_MIN:
			dur = minf(float(o.dur), 4.0)
		# **롱노트는 누르고 있는 동안 그 레인을 통째로 차지한다.** 끝나는 시각을
		# 넣어 둬야 그 위에 다른 노트가 얹히지 않는다 — 얹히면 손이 하나 모자란다.
		busy[lane] = t + dur
		last_lane = lane
		last_t = t
		notes.append([t, lane, dur])
	notes.sort_custom(func(a, b): return a[0] < b[0])
	return notes


static func _place(want: int, t: float, keys: int, busy: PackedFloat32Array) -> int:
	for d in keys:
		for s in [1, -1]:
			var lane: int = want + d * s
			if lane < 0 or lane >= keys:
				continue
			if t - busy[lane] >= D.AN_SAME_LANE_GAP:
				return lane
			if d == 0:
				break
	return -1
