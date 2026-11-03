class_name Bgm
extends RefCounted

## 배경 음악 — 음원 파일 없이 켤 때 한 번 합성해 [AudioStreamWAV] 고리로 굳힌다(효과음과 같은 이유).
##
## **한 번에 다 굽지 않는다.** 17초짜리를 GDScript 로 합성하면 웹(wasm)에서 1초 넘게 걸려 첫 화면이
## 멎는다. `step()` 이 프레임마다 BUDGET_MS 만큼만 음표를 굽고, 다 되면 그때 튼다.
## 고리 끝을 넘는 소리 꼬리는 앞으로 감아 붙인다(`% _len`) — 안 그러면 이음매에서 툭 끊긴다.
##
## 곡은 C 장조 C-Am-F-G 여덟 마디. 마림바 선율 + 베이스 + 뒷박 화음 + 작은 하이햇.

const RATE := 22050
const BPM := 112.0
const BUDGET_MS := 6
const VOL_DB := -10.0

## 8분음표 칸마다 미디 번호(-1 = 쉼). 한 마디 8칸.
const MELODY := [
	76, -1, 79, -1, 81, 79, 76, -1,
	72, -1, 76, -1, 74, 72, 69, -1,
	72, -1, 74, 76, -1, 77, 76, 74,
	74, -1, -1, -1, 71, 72, 74, -1,
	76, -1, 79, -1, 84, -1, 81, 79,
	81, -1, 79, 76, -1, 74, 76, -1,
	77, 76, 74, 72, -1, 74, -1, 76,
	74, -1, 71, -1, 67, -1, -1, -1,
]
const CHORDS := [[60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62]]
const ROOTS := [36, 45, 41, 43]

## 악기: [배음 배수, 배음 세기, 감쇠(/초), 세기, 길이(초)]
const INST := {
	"lead": [4.0, 0.25, 5.5, 0.55, 0.9],
	"bass": [2.0, 0.3, 3.0, 0.6, 0.6],
	"pad": [2.0, 0.4, 7.0, 0.16, 0.45],
}

static var _player: AudioStreamPlayer
static var _buf := PackedFloat32Array()
static var _len := 0
static var _notes: Array = []   ## [시작 샘플, 미디, 악기]
static var _next := 0
static var _enc := -1           ## 굽기가 끝나고 16비트로 옮기는 중인 위치(-1 = 아직 굽는 중)
static var _data := PackedByteArray()
static var _peak := 0.0


static func init(owner: Node) -> void:
	_player = AudioStreamPlayer.new()
	_player.volume_db = VOL_DB
	owner.add_child(_player)
	var beat := 60.0 / BPM
	_len = int(beat * 32.0 * RATE)
	_buf.resize(_len)
	for bar in 8:
		var c := bar % 4
		var b0 := bar * 4.0 * beat
		_notes.append([int(b0 * RATE), ROOTS[c], "bass"])
		_notes.append([int((b0 + 2.0 * beat) * RATE), ROOTS[c], "bass"])
		_notes.append([int((b0 + 3.5 * beat) * RATE), ROOTS[c] + 12, "bass"])
		for k in 4:
			if k % 2 == 1:
				for m in CHORDS[c]:
					_notes.append([int((b0 + k * beat) * RATE), m, "pad"])
			for h in 2:
				_notes.append([int((b0 + (k + h * 0.5) * beat) * RATE), 0, "hat"])
		for k in 8:
			var m: int = MELODY[bar * 8 + k]
			if m >= 0:
				_notes.append([int((b0 + k * 0.5 * beat) * RATE), m, "lead"])


## 매 프레임. 다 구워졌으면 아무것도 안 한다.
static func step() -> void:
	if _player == null or _player.stream != null:
		return
	var t0 := Time.get_ticks_msec()
	while _next < _notes.size() and Time.get_ticks_msec() - t0 < BUDGET_MS:
		_note(_notes[_next])
		_next += 1
	if _next < _notes.size():
		return
	if _enc < 0:
		for v in _buf:
			_peak = maxf(_peak, absf(v))
		_data.resize(_len * 2)
		_enc = 0
	var k := 0.9 / maxf(_peak, 0.001)
	var end := mini(_len, _enc + 60000)
	for i in range(_enc, end):
		_data.encode_s16(i * 2, int(clampf(_buf[i] * k, -1.0, 1.0) * 32000.0))
	_enc = end
	if _enc < _len:
		return
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = _data
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = _len
	_player.stream = s
	_buf = PackedFloat32Array()
	apply()


## 설정(Sv.music)을 소리에 반영한다. 켜면 처음부터 다시 돈다.
static func apply() -> void:
	if _player == null or _player.stream == null:
		return
	if Sv.music and not _player.playing:
		_player.play()
	elif not Sv.music:
		_player.stop()


static func loaded() -> bool:
	return _player != null and _player.stream != null


## 음표 하나를 _buf 에 더한다. 큰 버퍼라 인자로 넘기지 않고 static 을 바로 쓴다
## (Packed 배열은 값 타입이라 함수로 넘기면 고친 것이 안 남고 통째로 복사된다).
static func _note(n: Array) -> void:
	var start: int = n[0]
	if n[2] == "hat":
		var hn := int(0.04 * RATE)
		var he := 1.0
		var hk := exp(-90.0 / RATE)
		for j in hn:
			_buf[(start + j) % _len] += (randf() * 2.0 - 1.0) * he * 0.05
			he *= hk
		return
	var p: Array = INST[n[2]]
	var w := TAU * 440.0 * pow(2.0, (int(n[1]) - 69) / 12.0) / RATE
	var cnt := int(float(p[4]) * RATE)
	var mul: float = p[0]
	var hg: float = p[1]
	var dk := exp(-float(p[2]) / RATE)
	var g: float = p[3]
	var att := 0.004 * RATE
	var env := 1.0
	for j in cnt:
		var ph := w * j
		var a := minf(1.0, j / att)
		_buf[(start + j) % _len] += (sin(ph) + hg * sin(ph * mul)) * env * a * g
		env *= dk
