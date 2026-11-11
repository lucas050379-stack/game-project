class_name Bgm
extends RefCounted

## 배경 음악 — 음원 파일 없이 합성해 [AudioStreamWAV] 고리로 굳힌다(효과음과 같은 이유).
##
## **곡은 게임마다 따로입니다** — `jelly`(허브 · 젤리팝), `sky`(스카이 어설트), `runner`(월드 러너).
## 원래 젤리팝 한 곡뿐이었는데, 마림바 동요풍이 슈팅과 보드게임에는 안 어울렸습니다.
## 게임 화면은 `_ready` 에서 [method use] 로 자기 곡을 고르고, 허브가 게임을 닫으면 `jelly` 로 돌아옵니다.
##
## **한 번에 다 굽지 않는다.** 17초짜리를 GDScript 로 합성하면 웹(wasm)에서 1초 넘게 걸려 화면이
## 멎는다. `step()` 이 프레임마다 BUDGET_MS 만큼만 음표를 굽고, 다 되면 그때 튼다. 굽는 것은 한 번에
## 한 곡뿐이고(큰 버퍼를 static 으로 들고 빠르게 고치려고), 고른 곡을 먼저, 남는 시간에(허브 화면에서만)
## 나머지 곡을 미리 굽는다 — 게임을 열 때 음악이 몇 초 늦게 시작하지 않게.
## 고리 끝을 넘는 소리 꼬리는 앞으로 감아 붙인다(`% _len`) — 안 그러면 이음매에서 툭 끊긴다.
##
## **큰 버퍼를 함수 인자로 넘기지 마세요** — Packed 배열은 값 타입이라 고친 것이 안 남고 통째로 복사됩니다.
## 그래서 굽는 중인 곡의 버퍼는 static(`_buf`)에 두고 `_note` 가 바로 고칩니다.
##
## 음량은 `Vol` 이 정한다(배경음 막대 → [method set_volume], 테스트 실행은 전체 음소거).

const RATE := 22050
const BUDGET_MS := 6
const VOL_DB := -10.0
const ORDER := ["hub", "jelly", "sky", "runner", "gangho", "arcana", "tiger", "bubble", "burger"]   ## 미리 굽는 순서(급박 변주 "!" 는 게임 안에서 필요할 때)

## 악기: 배음 [[배수, 세기], ...] · 감쇠(/초) · 세기 · 길이(초) · 어택(초)
const INST := {
	# 젤리팝 — 마림바 · 둥근 베이스 · 뒷박 화음
	"marimba": [[[1.0, 1.0], [4.0, 0.25]], 5.5, 0.55, 0.9, 0.004],
	"bass": [[[1.0, 1.0], [2.0, 0.3]], 3.0, 0.6, 0.6, 0.004],
	"pad": [[[1.0, 1.0], [2.0, 0.4]], 7.0, 0.16, 0.45, 0.004],
	# 스카이 어설트 — 톱니 리드 · 짧게 끊는 8분 베이스 · 파워 코드
	"saw": [[[1.0, 1.0], [2.0, 0.5], [3.0, 0.33], [4.0, 0.25], [5.0, 0.2], [6.0, 0.16]], 2.4, 0.3, 0.32, 0.006],
	"drive": [[[1.0, 1.0], [2.0, 0.55], [3.0, 0.3]], 7.0, 0.5, 0.2, 0.003],
	"power": [[[1.0, 1.0], [1.5, 0.5], [2.0, 0.45], [3.0, 0.2]], 3.0, 0.11, 0.55, 0.01],
	# 월드 러너 — 글로켄 리드(어긋난 배음) · 튜바 쿵짝 · 뜯는 화음
	"bell": [[[1.0, 1.0], [2.76, 0.35], [5.4, 0.12]], 3.6, 0.42, 1.0, 0.002],
	"tuba": [[[1.0, 1.0], [2.0, 0.6], [3.0, 0.3]], 4.5, 0.55, 0.38, 0.012],
	"pluck": [[[1.0, 1.0], [2.0, 0.5], [3.0, 0.2]], 9.0, 0.17, 0.35, 0.003],
	# 강호일생 — 뜯는 현(고쟁 비슷하게 배음이 길게) · 부드러운 피리 · 낮게 깔린 울림
	"qin": [[[1.0, 1.0], [2.0, 0.45], [3.0, 0.22], [4.0, 0.1]], 2.6, 0.5, 1.8, 0.003],
	"flute": [[[1.0, 1.0], [2.0, 0.12], [3.0, 0.05]], 0.9, 0.22, 1.4, 0.07],
	"drone": [[[1.0, 1.0], [2.0, 0.3], [3.0, 0.1]], 0.35, 0.2, 3.6, 0.4],
	# 아르카나 컬렉션 — 하프(뜯고 길게 울림) · 숨 쉬듯 들어오는 합창 패드. 선율은 월드 러너의 글로켄(bell)을 빌린다
	"harp": [[[1.0, 1.0], [2.0, 0.35], [3.0, 0.12]], 3.2, 0.24, 1.2, 0.003],
	"choir": [[[1.0, 1.0], [2.0, 0.25], [3.0, 0.12], [4.0, 0.05]], 0.5, 0.16, 2.8, 0.5],
	# 허브 — 오락실 칩튠(홀수 배음 사각파 리드 · 낮은 서브 베이스)
	"chip": [[[1.0, 1.0], [3.0, 0.33], [5.0, 0.2], [7.0, 0.14]], 6.0, 0.2, 0.3, 0.003],
	"sub": [[[1.0, 1.0], [2.0, 0.15]], 4.0, 0.6, 0.4, 0.004],
	# 월드 러너(11-09 새 곡) — 아코디언 선율 · 엇박 기타 스트로크. 젤리팝 마림바와 겹쳐 들리지 않게
	"accord": [[[1.0, 1.0], [2.0, 0.6], [3.0, 0.45], [4.0, 0.3], [5.0, 0.2]], 1.4, 0.16, 0.45, 0.025],
	"skank": [[[1.0, 1.0], [2.0, 0.5], [3.0, 0.3]], 14.0, 0.12, 0.14, 0.002],
	# 제국 연대기 — 느린 금관 선율 · 팀파니. 다른 곡과 악기가 겹치지 않게 새로 둠
	"horn": [[[1.0, 1.0], [2.0, 0.5], [3.0, 0.35], [4.0, 0.2]], 1.2, 0.2, 0.9, 0.04],
	"timp": [[[1.0, 1.0], [1.5, 0.3], [2.2, 0.15]], 6.0, 0.6, 0.6, 0.003],
	# 붉은 별 개척단 — 넓게 깔리는 신스 패드 · 맑은 펄스 아르페지오. 다른 곡과 겹치지 않게 새로 둠
	"spad": [[[1.0, 1.0], [1.005, 0.7], [2.0, 0.3], [3.0, 0.1]], 0.4, 0.14, 3.0, 0.6],
	"pulse": [[[1.0, 1.0], [3.0, 0.45], [5.0, 0.25]], 7.0, 0.16, 0.3, 0.003],
	# 11-09 밤(docs/ai-look-overhaul.md #22) — 다른 곡의 악기를 빌려 쓰던 자리에 제 악기를 둔다
	"celesta": [[[1.0, 1.0], [4.0, 0.3], [6.0, 0.08]], 4.5, 0.36, 1.1, 0.002],            # 아르카나 선율(러너의 bell 을 빌렸었다)
	"lute": [[[1.0, 1.0], [2.0, 0.6], [3.0, 0.35], [5.0, 0.12]], 5.0, 0.45, 0.9, 0.002],  # 잿빛 요새 선율(강호의 qin 을 빌렸었다)
	"cello": [[[1.0, 1.0], [2.0, 0.55], [3.0, 0.4], [4.0, 0.2]], 0.5, 0.2, 3.4, 0.25],    # 잿빛 요새 저음(강호의 drone 을 빌렸었다)
	# 호랑이 — 가야금 · 태평소
	"tiger_gaya": [[[1.0, 1.0], [2.0, 0.48], [3.01, 0.24], [4.02, 0.1]], 6.2, 0.25, 0.85, 0.002],
	"tiger_reed": [[[1.0, 0.65], [2.0, 0.7], [3.0, 0.45], [4.0, 0.22], [5.0, 0.12]], 4.0, 0.13, 0.55, 0.018],
	# 물거품 — 물결 · 물방울 · 해초 패드
	"bubble_ripple": [[[1.0, 1.0], [2.01, 0.16], [3.0, 0.05]], 4.8, 0.18, 1.25, 0.008],
	"bubble_pearl": [[[1.0, 1.0], [2.0, 0.07], [4.01, 0.04]], 3.8, 0.28, 1.4, 0.012],
	"bubble_tide": [[[1.0, 1.0], [1.003, 0.35], [2.0, 0.12]], 1.8, 0.11, 3.4, 0.3],
	# 버거왕 — 전자피아노 · 워킹 베이스 · 뮤트 트럼펫
	"burger_keys": [[[1.0, 1.0], [2.003, 0.3], [3.99, 0.14]], 6.0, 0.2, 0.85, 0.004],
	"burger_walk": [[[1.0, 1.0], [2.0, 0.36], [3.0, 0.12]], 4.8, 0.38, 0.55, 0.006],
	"burger_mute": [[[1.0, 0.75], [2.0, 0.5], [3.0, 0.32], [4.0, 0.12]], 5.2, 0.18, 0.48, 0.025],
}

static var _player: AudioStreamPlayer
static var _streams := {}      ## 곡 → 다 구운 AudioStreamWAV
static var _want := "jelly"    ## 지금 틀어야 하는 곡
static var _job := ""          ## 굽는 중인 곡("" = 없음)
static var _buf := PackedFloat32Array()
static var _len := 0
static var _notes: Array = []   ## [시작 샘플, 미디, 악기, 세기]
static var _next := 0
static var _enc := -1           ## 굽기가 끝나고 16비트로 옮기는 중인 위치(-1 = 아직 굽는 중)
static var _data := PackedByteArray()
static var _peak := 0.0


## **상황 음악**(사용자 요청 11-09 — "급할 때도 느긋한 느낌") — 곡마다 급박 변주("<곡>!")를 같이 굽는다: 같은 곡을 TENSE_K 배 빠르게,
## 8분 베이스 · 킥 · 하이햇을 더한 것. 게임은 프레임마다 `Bgm.mood(급한가)` 만 부르면 되고, 바뀔 때는 곡의 같은 마디 자리에서 이어서 튼다.
const TENSE_K := 1.2
## 곡마다 다른 빠르기 — [급박, 더 급박("<곡>!!")]. 없으면 [TENSE_K, TENSE_K]. 물거품은 서둘러요! 1.35배, 상어가 나오면 1.6배(사용자 11-11)
const TENSE_SONG := {"bubble": [1.35, 1.6]}
static var _tense := false     ## 굽는 중인 곡이 급박 변주인가(곡 함수가 본다)
static var _tense_k := 1.0     ## 굽는 중인 곡의 빠르기 배
static var _mood_lv := 0       ## 0 보통 · 1 급박 · 2 더 급박


static func mood(tense: bool) -> void:
	mood_lv(1 if tense else 0)


## 단계로 — 0 보통, 1 급박("<곡>!"), 2 더 급박("<곡>!!"). 2 는 TENSE_SONG 에 둘째 값이 있는 곡만 다르게 빠르다.
static func mood_lv(lv: int) -> void:
	if lv == _mood_lv or _want == "":
		return
	_mood_lv = lv
	var base := _want.trim_suffix("!").trim_suffix("!")
	_want = base + "!".repeat(lv)
	if _streams.has(_want):
		_swap_to(_want)


## 지금 자리(곡 안 비율)를 지키며 다른 굽힌 곡으로 바꾼다 — 같은 곡의 변주끼리는 마디가 맞는다.
static func _swap_to(id: String) -> void:
	if _player == null or not is_instance_valid(_player) or not _streams.has(id):
		return
	var old := _player.stream as AudioStreamWAV
	var frac := 0.0
	if old != null and _player.playing and old.loop_end > 0:
		frac = fposmod(_player.get_playback_position() * old.mix_rate / float(old.loop_end), 1.0)
	var nw: AudioStreamWAV = _streams[id]
	_player.stream = nw
	if Sv.music:
		_player.play(frac * nw.loop_end / float(nw.mix_rate))


## 급박 변주의 덧층 — 8분 베이스(근음) · 박마다 킥 · 8분 하이햇. 곡 함수가 마디마다 부른다(_tense 일 때만).
static func _drive(b0: float, beat: float, root: int) -> void:
	if not _tense:
		return
	for k in 8:
		_add(b0 + k * 0.5, beat, root - 12 if root >= 48 else root, "drive", 0.8 if k % 2 == 0 else 0.6)
		_add(b0 + k * 0.5, beat, 0, "hat", 1.1 if k % 2 == 1 else 0.7)
	for k in 4:
		_add(b0 + k, beat, 0, "kick", 0.9 if k % 2 == 0 else 0.6)


static func _bpm(v: float) -> float:
	return 60.0 / (v * _tense_k)


## 허브가 한 번만 부른다. 두 번째부터는 아무것도 안 한다.
static func init(owner: Node) -> void:
	if _player != null and is_instance_valid(_player):
		return
	_player = AudioStreamPlayer.new()
	_player.volume_db = VOL_DB
	owner.add_child(_player)


## 이 곡을 튼다(아직 안 구웠으면 다 구운 뒤에).
static func use(id: String) -> void:
	_mood_lv = 0
	if _want == id and _player != null and _player.stream == _streams.get(id):
		apply()
		return
	_want = id
	if _player == null or not is_instance_valid(_player):
		return
	_player.stop()
	if _streams.has(id):
		_player.stream = _streams[id]
		apply()


## 매 프레임(허브가 부른다). `idle` 이면 고른 곡 말고 나머지도 미리 굽는다.
static func step(idle: bool = false) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _job == "":
		if not _streams.has(_want):
			_start(_want)
		elif idle:
			for id: String in ORDER:
				if not _streams.has(id):
					_start(id)
					break
		if _job == "":
			return
	_bake()


## 설정(Sv.music)을 소리에 반영한다. 켜면 처음부터 다시 돈다.
static func apply() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.stream == null:
		if _streams.has(_want):
			_player.stream = _streams[_want]
		else:
			return
	if Sv.music and not _player.playing:
		_player.play()
	elif not Sv.music:
		_player.stop()


## 배경음 막대(0~1). 0 이면 Sv.music 이 꺼져서 apply 가 멈춘다.
static func set_volume(v: float) -> void:
	if _player != null and is_instance_valid(_player) and v > 0.001:
		_player.volume_db = VOL_DB + linear_to_db(v)


static func stop() -> void:
	if _player != null and is_instance_valid(_player):
		_player.stop()


static func loaded() -> bool:
	return _streams.has(_want)

# ==================== 굽기 ====================


static func _start(id: String) -> void:
	_job = id
	_tense = id.ends_with("!")
	var lv := 2 if id.ends_with("!!") else (1 if _tense else 0)
	id = id.trim_suffix("!").trim_suffix("!")
	_tense_k = 1.0 if lv == 0 else float((TENSE_SONG.get(id, [TENSE_K, TENSE_K]) as Array)[lv - 1])
	_notes = []
	_next = 0
	_enc = -1
	_peak = 0.0
	_data = PackedByteArray()
	match id:
		"sky":
			_song_sky()
		"runner":
			_song_runner()
		"gangho":
			_song_gangho()
		"arcana":
			_song_arcana()
		"empire":
			_song_empire()
		"redstar":
			_song_redstar()
		"ashkeep":
			_song_ashkeep()
		"tiger":
			_song_tiger()
		"bubble":
			_song_bubble()
		"burger":
			_song_burger()
		"hub":
			_song_hub()
		_:
			_song_jelly()
	_buf = PackedFloat32Array()
	_buf.resize(_len)


static func _bake() -> void:
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
	_streams[_job] = s
	_buf = PackedFloat32Array()
	_job = ""
	if _player != null and is_instance_valid(_player) and _streams.has(_want) and _player.stream != _streams[_want]:
		if _player.playing:
			_swap_to(_want)   # 기본 곡이 도는 중에 변주가 다 구워졌다 — 같은 자리에서 이어서
		else:
			_player.stream = _streams[_want]
			apply()


static func _add(beat_pos: float, beat: float, midi: int, inst: String, vel: float = 1.0) -> void:
	_notes.append([int(beat_pos * beat * RATE), midi, inst, vel])

# ==================== 곡 ====================


## 젤리팝 — C 장조 열여섯 마디, 112 BPM. 마림바 선율 + 베이스 + 뒷박 화음 + 작은 하이햇.
## 화음은 C-F-Dm-G / C(E 베이스)-Am-F-G — 예전의 C-Am-F-G 네 마디 되풀이(교과서 진행)를 버렸다(#22). 선율은 그대로 얹힌다.
## 뒤 여덟 마디는 같은 화음 위에서 선율을 한 옥타브 내려 정박만 치고, 엇박에 화음을 뜯는다(되풀이가 덜 들리게).
const JELLY_MELODY := [
	76, -1, 79, -1, 81, 79, 76, -1,
	72, -1, 76, -1, 74, 72, 69, -1,
	72, -1, 74, 76, -1, 77, 76, 74,
	74, -1, -1, -1, 71, 72, 74, -1,
	76, -1, 79, -1, 84, -1, 81, 79,
	81, -1, 79, 76, -1, 74, 76, -1,
	77, 76, 74, 72, -1, 74, -1, 76,
	74, -1, 71, -1, 67, -1, -1, -1,
]


static func _song_jelly() -> void:
	var beat := _bpm(112.0)
	_len = int(beat * 64.0 * RATE)
	var chords := [[60, 64, 67], [53, 57, 60], [50, 53, 57], [55, 59, 62], [52, 55, 60], [57, 60, 64], [53, 57, 60], [55, 59, 62]]
	var roots := [36, 41, 38, 43, 40, 45, 41, 43]
	for bar in 16:
		var c := bar % 8
		var b0 := bar * 4.0
		_drive(b0, beat, roots[c])
		_add(b0, beat, roots[c], "bass")
		_add(b0 + 2.0, beat, roots[c], "bass")
		_add(b0 + 3.5, beat, roots[c] + 12, "bass")
		for k in 4:
			if k % 2 == 1:
				for m in chords[c]:
					_add(b0 + k, beat, m, "pad")
			for h in 2:
				_add(b0 + k + h * 0.5, beat, 0, "hat", 1.0 if bar < 8 else 0.6)
		for k in 8:
			var m: int = JELLY_MELODY[c * 8 + k]
			if bar < 8:
				if m >= 0:
					_add(b0 + k * 0.5, beat, m, "marimba")
			elif k % 2 == 0:
				if m >= 0:
					_add(b0 + k * 0.5, beat, m - 12, "marimba", 0.8)
			else:
				_add(b0 + k * 0.5, beat, int(chords[c][(k / 2) % 3]) + 12, "marimba", 0.35)


## 스카이 어설트 — A 단조 Am-F-C-G / Am-F-G-E, 150 BPM. 8분음표로 몰아치는 베이스, 2 · 4박 스네어,
## 마디 첫 박 파워 코드, 톱니 리드. 마지막 마디의 E 장화음(G#)이 고리 처음 Am 으로 끌어당긴다.
const SKY_MELODY := [
	69, -1, 72, -1, 76, 74, 72, 71,
	72, -1, 69, -1, 65, -1, 69, 72,
	76, -1, 79, -1, 77, 76, 74, 72,
	74, -1, -1, 71, 74, -1, 79, -1,
	81, -1, 79, 76, -1, 76, 77, 79,
	77, -1, 76, 72, -1, 72, 74, 76,
	74, 72, 71, -1, 67, -1, 71, 74,
	80, -1, 76, -1, 71, -1, 68, -1,
]


static func _song_sky() -> void:
	var beat := _bpm(150.0)
	_len = int(beat * 32.0 * RATE)
	var chords := [[57, 60, 64], [53, 57, 60], [55, 60, 64], [55, 59, 62], [57, 60, 64], [53, 57, 60], [55, 59, 62], [56, 59, 64]]
	var roots := [45, 41, 48, 43, 45, 41, 43, 40]
	for bar in 8:
		var b0 := bar * 4.0
		var r: int = roots[bar]
		_drive(b0, beat, r)
		for k in 8:
			_add(b0 + k * 0.5, beat, r + (12 if k % 4 == 2 else 0), "drive", 0.9 if k % 2 == 0 else 0.7)
			_add(b0 + k * 0.5, beat, 0, "hat", 1.3 if k % 2 == 1 else 0.8)
		for k in [0, 2]:
			_add(b0 + k, beat, 0, "kick")
		_add(b0 + 2.5, beat, 0, "kick", 0.7)
		for k in [1, 3]:
			_add(b0 + k, beat, 0, "snare")
		for m in chords[bar]:
			_add(b0, beat, m, "power")
			_add(b0 + 2.0, beat, m, "power", 0.6)
		for k in 8:
			var m: int = SKY_MELODY[bar * 8 + k]
			if m >= 0:
				_add(b0 + k * 0.5, beat, m, "saw")


## 월드 러너 — G 장조 G-C-D-G / Em-C-D-G, 132 BPM(11-09 새 곡 — 젤리팝과 비슷하게 들린다는 지적). 튜바가 1 · 3박에 쿵(근음) · 짝(5도),
## 엇박마다 기타 스트로크(skank), 아코디언 선율, 8분 셰이커 — 여행 떠나는 축제 느낌. 젤리팝(마림바 · 112 · 2 · 4박 패드)과 악기 · 박이 다르다.
const RUNNER_MELODY := [
	74, -1, 79, -1, 83, -1, 81, 79,
	76, -1, 79, 81, 84, -1, 83, -1,
	81, -1, 78, -1, 74, -1, 78, 81,
	79, -1, -1, 74, 79, -1, -1, -1,
	76, -1, 79, -1, 83, 81, 79, 76,
	72, -1, 76, -1, 79, -1, 84, 83,
	81, -1, 83, 81, 78, -1, 74, 78,
	79, -1, 74, -1, 67, -1, -1, -1,
]


static func _song_runner() -> void:
	var beat := _bpm(132.0)
	_len = int(beat * 32.0 * RATE)
	var chords := [[55, 59, 62], [48, 52, 55], [50, 54, 57], [55, 59, 62], [52, 55, 59], [48, 52, 55], [50, 54, 57], [55, 59, 62]]
	var roots := [43, 36, 38, 43, 40, 36, 38, 43]
	for bar in 8:
		var b0 := bar * 4.0
		var r: int = roots[bar]
		_drive(b0, beat, r + 12)
		_add(b0, beat, r, "tuba")
		_add(b0 + 2.0, beat, r + 7, "tuba", 0.85)
		for k in 4:
			for m in chords[bar]:
				_add(b0 + k + 0.5, beat, int(m) + 12, "skank", 0.9)
			_add(b0 + k, beat, 0, "hat", 0.5)
			_add(b0 + k + 0.5, beat, 0, "hat", 0.8)
		for k in 8:
			var m: int = RUNNER_MELODY[bar * 8 + k]
			if m >= 0:
				_add(b0 + k * 0.5, beat, m - 12, "accord", 0.9)

## 강호일생 — D 단조 5음계(레 파 솔 라 도), 68 BPM 여덟 마디. 뜯는 현이 선율, 피리가 긴 음을 받치고
## 낮은 울림이 마디마다 깔린다. 글을 읽는 게임이라 박이 앞에 나서지 않게 북이 없다.
const GANGHO_MELODY := [
	62, -1, 65, 67, 69, -1, -1, -1,
	72, -1, 69, -1, 67, 65, -1, -1,
	62, -1, 65, -1, 67, -1, 69, 72,
	74, -1, -1, -1, 72, -1, -1, -1,
	69, -1, 72, 74, 77, -1, 74, -1,
	72, -1, 69, 67, 65, -1, -1, -1,
	67, -1, 65, -1, 62, -1, 60, -1,
	62, -1, -1, -1, -1, -1, -1, -1,
]


## 아르카나 컬렉션 — A 단조 Am-F-C-G / Am-F-E-Am 여덟 마디, 92 BPM. 하프 아르페지오 + 글로켄 선율 + 낮은 합창 패드.
## 판을 오래 보며 생각하는 게임이라 박자를 세게 두드리지 않는다(북 없음).
const ARCANA_MELODY := [
	76, -1, -1, 74, 72, -1, 71, -1,
	69, -1, -1, -1, 72, -1, -1, -1,
	67, -1, 72, -1, 76, -1, 74, 72,
	74, -1, -1, -1, -1, -1, 71, -1,
	72, -1, -1, 71, 69, -1, 72, -1,
	77, -1, 76, -1, 74, -1, 72, -1,
	71, -1, 68, -1, 71, -1, 74, -1,
	69, -1, -1, -1, -1, -1, -1, -1,
]


static func _song_arcana() -> void:
	var beat := _bpm(92.0)
	_len = int(beat * 32.0 * RATE)
	# 마디마다 화음 [근음, 3음, 5음](미디)
	var chords := [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62],
			[57, 60, 64], [53, 57, 60], [52, 56, 59], [57, 60, 64]]
	for bar in 8:
		var b0 := bar * 4.0
		var ch: Array = chords[bar]
		_drive(b0, beat, int(ch[0]))
		_add(b0, beat, int(ch[0]) - 12, "choir", 0.9)
		_add(b0, beat, int(ch[1]), "choir", 0.45)
		# 하프 — 근음 5음 옥타브 3음 을 8분으로 오르내림
		var arp := [ch[0], ch[2], int(ch[0]) + 12, int(ch[1]) + 12, int(ch[2]) + 12, int(ch[1]) + 12, int(ch[0]) + 12, ch[2]]
		for k in 8:
			_add(b0 + k * 0.5, beat, int(arp[k]), "harp", 0.75 if k % 2 == 0 else 0.55)
		for k in 8:
			var m: int = ARCANA_MELODY[bar * 8 + k]
			if m >= 0:
				_add(b0 + k * 0.5, beat, m + 12, "celesta", 0.6)


## 제국 연대기 — 라단조 행진. 금관 선율(2분음표) · 팀파니 둘째 · 넷째 박 · 낮은 금관 화음.
## 열두 마디 — 여덟 마디 뒤에 뒤 네 마디를 한 옥타브 올려 다시(모든 곡이 여덟 마디 고리였다, #22).
static func _song_empire() -> void:
	var beat := _bpm(80.0)
	_len = int(beat * 48.0 * RATE)
	var chords := [[50, 53, 57], [46, 50, 53], [53, 57, 60], [48, 52, 55],
			[50, 53, 57], [55, 58, 62], [57, 61, 64], [50, 53, 57]]
	var mel := [[62, 65], [62, 58], [60, 65], [64, 60], [62, 69], [67, 70], [69, 64], [62, -1]]
	for bar in 12:
		var b0 := bar * 4.0
		var src := bar if bar < 8 else bar - 4
		var ch: Array = chords[src]
		_drive(b0, beat, int(ch[0]))
		_add(b0, beat, int(ch[0]) - 12, "horn", 0.7)
		_add(b0 + 2.0, beat, int(ch[2]) - 12, "horn", 0.55)
		_add(b0, beat, int(ch[1]), "horn", 0.35)
		for k in 4:
			_add(b0 + k, beat, int(ch[0]) - 24, "timp", 0.9 if k % 2 == 0 else 0.55)
		for k in 2:
			var m: int = mel[src][k]
			if m >= 0:
				_add(b0 + k * 2.0, beat, m + (12 if bar >= 8 else 0), "horn", 0.6 if bar < 8 else 0.5)


## 잿빛 요새의 용병단 — 낮은 드론과 팀파니 위로 뜯는 현의 단조 선율(던전 · 행군), 70 BPM. 악기는 기존 것을 다른 조합으로.
static func _song_ashkeep() -> void:
	var beat := _bpm(70.0)
	_len = int(beat * 32.0 * RATE)
	var roots := [45, 45, 41, 43, 45, 48, 43, 45]
	var mel := [[69, 72, 71, 69], [67, 69, -1, 64], [65, 69, 67, 65], [64, -1, 62, 64],
			[69, 72, 76, 74], [72, -1, 71, 72], [71, 67, 69, 71], [69, -1, -1, -1]]
	for bar in 8:
		var b0 := bar * 4.0
		var root: int = roots[bar]
		_drive(b0, beat, root)
		_add(b0, beat, root - 12, "cello", 0.9)
		_add(b0, beat, root - 24, "timp", 0.8)
		_add(b0 + 2.0, beat, root - 24, "timp", 0.5)
		for k in 4:
			var m: int = mel[bar][k]
			if m >= 0:
				_add(b0 + k, beat, m, "lute", 0.6)


## 아래 세 곡은 11-11 코덱스(GPT)가 지었다(사용자 요청 — 다른 AI 의 다른 뼈대).
## 떡 하나 주면 안 잡아먹지 — 솔 중심 오음계, 점4분음표 128 BPM·12/8, 가야금·태평소·장구의 자진모리풍.
static func _song_tiger() -> void:
	var beat := _bpm(128.0)
	_len = int(beat * 32.0 * RATE)
	var mel := [
		[79, -1, 81, 84, -1, 81, 79, 76, 74, 76, -1, 79],
		[81, -1, 84, 86, -1, 84, 81, 79, 76, 74, -1, -1],
		[76, -1, 79, 81, 79, 76, 74, -1, 72, 74, -1, 76],
		[79, -1, -1, 76, -1, 74, 72, 74, 76, 79, -1, -1],
		[84, -1, 86, 88, -1, 86, 84, 81, 79, 81, -1, 84],
		[86, 84, 81, 84, -1, 81, 79, -1, 76, 74, -1, 76],
		[79, 81, 84, 81, 79, 76, 74, -1, 72, 74, 76, 74],
		[79, -1, -1, 74, -1, 76, 79, -1, -1, -1, -1, 74],
	]
	var strings := [
		[55, 62, 67, 74], [55, 64, 69, 76],
		[48, 55, 60, 67], [50, 57, 62, 69],
		[55, 62, 67, 74], [60, 67, 72, 79],
		[50, 57, 62, 69], [55, 62, 67, 74],
	]
	var strokes := [0, 2, 3, 5, 6, 7, 9, 10, 11]
	for bar in 8:
		var b0 := bar * 4.0
		var ch: Array = strings[bar]
		_drive(b0, beat, int(ch[0]))
		for s: int in strokes:
			var deep := s == 0 or s == 6
			_add(b0 + s / 3.0, beat, 0,
					"tiger_kung" if deep else "tiger_deok",
					0.9 if deep else (0.7 if s % 3 == 0 else 0.42))
		for k in 4:
			_add(b0 + k, beat, int(ch[k]), "tiger_gaya", 0.8)
			if k == 1 or k == 3:
				_add(b0 + k + 2.0 / 3.0, beat, int(ch[k]) + 12, "tiger_gaya", 0.45)
		for k in 12:
			var m: int = mel[bar][k]
			if m >= 0:
				_add(b0 + k / 3.0, beat, m, "tiger_reed", 0.78 if k % 3 == 0 else 0.58)


## 물거품처럼 사라져줘 — D 장조, 96 BPM·3/4 여덟 마디, 물방울 선율·물결 분산화음·해초 패드의 둥실거림.
static func _song_bubble() -> void:
	var beat := _bpm(96.0)
	_len = int(beat * 24.0 * RATE)
	var chords := [
		[50, 57, 61, 66], [49, 57, 61, 64],
		[47, 54, 57, 62], [45, 52, 57, 61],
		[43, 54, 57, 62], [42, 52, 57, 62],
		[40, 55, 59, 64], [45, 55, 59, 61],
	]
	var mel := [
		[78, -1, 81, 85, -1, 81],
		[80, -1, 76, -1, 73, -1],
		[78, -1, 81, 83, 81, 78],
		[76, -1, -1, 73, -1, -1],
		[78, -1, 81, 86, -1, 85],
		[81, -1, 78, 76, -1, 74],
		[79, -1, 83, 81, 79, 76],
		[73, -1, 76, 78, -1, -1],
	]
	var arp := [1, 2, 3, 2, 1, 2]
	for bar in 8:
		var b0 := bar * 3.0
		var ch: Array = chords[bar]
		# 네 마디의 열두 박에 급박 덧층을 맞춘다.
		if bar % 4 == 0:
			for k in 3:
				_drive(b0 + k * 4.0, beat, int(ch[0]))
		for k in [0, 2, 3]:
			_add(b0, beat, int(ch[k]), "bubble_tide", 0.65 if k == 0 else 0.4)
		for k in 6:
			_add(b0 + k * 0.5, beat, int(ch[arp[k]]) + 12,
					"bubble_ripple", 0.55 if k % 3 == 0 else 0.36)
			var m: int = mel[bar][k]
			if m >= 0:
				_add(b0 + k * 0.5, beat, m, "bubble_pearl", 0.75)
		if bar % 2 == 1:
			_add(b0 + 2.5, beat, 0, "bubble_pop", 0.65)


## 버거왕 — F 블루스, 144 BPM·4/4 열두 마디, 전자피아노·워킹 베이스·뮤트 트럼펫의 바쁜 셔플.
static func _song_burger() -> void:
	var beat := _bpm(144.0)
	_len = int(beat * 48.0 * RATE)
	var walking := [
		[41, 45, 48, 47], [46, 50, 53, 52],
		[41, 45, 48, 50], [41, 43, 44, 45],
		[46, 50, 53, 52], [46, 48, 49, 50],
		[41, 45, 48, 47], [38, 42, 45, 44],
		[43, 46, 50, 49], [48, 52, 55, 54],
		[41, 45, 38, 42], [43, 47, 48, 40],
	]
	var voicings := [
		[57, 63, 67], [56, 62, 65],
		[57, 63, 67], [57, 63, 69],
		[56, 62, 65], [56, 62, 67],
		[57, 63, 67], [54, 60, 64],
		[58, 62, 65], [58, 64, 69],
		[57, 63, 67], [58, 64, 67],
	]
	var mel := [
		[72, -1, 75, 76, 77, -1, 81, -1],
		[80, -1, 77, -1, 74, 72, -1, -1],
		[72, 75, 76, 77, -1, 81, 79, -1],
		[77, -1, 75, 72, -1, -1, 69, -1],
		[74, -1, 77, 80, 79, -1, 77, -1],
		[74, 72, -1, 74, 77, -1, 80, -1],
		[81, -1, 79, 77, -1, 75, 72, -1],
		[78, -1, 76, 74, -1, 72, 69, -1],
		[70, -1, 74, 77, 79, -1, 77, -1],
		[76, -1, 79, 82, 81, -1, 79, -1],
		[77, -1, 75, 72, 74, -1, 78, -1],
		[79, -1, 76, -1, 72, -1, -1, 71],
	]
	for bar in 12:
		var b0 := bar * 4.0
		_drive(b0, beat, int(walking[bar][0]))
		for k in 4:
			_add(b0 + k, beat, int(walking[bar][k]), "burger_walk", 0.85)
			_add(b0 + k + 2.0 / 3.0, beat, 0, "hat", 0.32)
		var comp := [0.0, 2.0 + 2.0 / 3.0] if bar % 2 == 0 else [1.0 + 2.0 / 3.0, 3.0]
		for pos: float in comp:
			for m: int in voicings[bar]:
				_add(b0 + pos, beat, m, "burger_keys", 0.65)
		_add(b0 + 1.0, beat, 0, "snare", 0.22)
		_add(b0 + 3.0, beat, 0, "snare", 0.3)
		for k in 8:
			var m: int = mel[bar][k]
			if m >= 0:
				var pos := floorf(k / 2.0) + (2.0 / 3.0 if k % 2 == 1 else 0.0)
				_add(b0 + pos, beat, m, "burger_mute", 0.75 if k % 2 == 0 else 0.6)


## 붉은 별 개척단 — 느린 단조 패드 위로 8분 펄스 아르페지오(우주 · 개척 느낌), 76 BPM.
static func _song_redstar() -> void:
	var beat := _bpm(76.0)
	_len = int(beat * 32.0 * RATE)
	var chords := [[52, 55, 59], [48, 52, 55], [50, 53, 57], [47, 50, 54],
			[52, 55, 59], [45, 48, 52], [47, 50, 54], [52, 55, 59]]
	for bar in 8:
		var b0 := bar * 4.0
		var ch: Array = chords[bar]
		_drive(b0, beat, int(ch[0]))
		_add(b0, beat, int(ch[0]) - 12, "spad", 0.9)
		_add(b0, beat, int(ch[2]), "spad", 0.5)
		var arp := [ch[0], ch[1], ch[2], int(ch[0]) + 12, int(ch[2]) + 12, int(ch[1]) + 12, ch[2], ch[1]]
		for k in 8:
			_add(b0 + k * 0.5, beat, int(arp[k]) + 12, "pulse", 0.7 if k % 2 == 0 else 0.5)


static func _song_gangho() -> void:
	var beat := _bpm(68.0)
	_len = int(beat * 32.0 * RATE)
	var roots := [38, 38, 43, 45, 41, 41, 36, 38]
	var flute := [69, 72, 67, 74, 77, 72, 67, 62]
	for bar in 8:
		var b0 := bar * 4.0
		var r: int = roots[bar]
		_drive(b0, beat, r)
		_add(b0, beat, r, "drone", 0.9)
		_add(b0 + 2.0, beat, r + 7, "qin", 0.35)
		if bar % 2 == 1:
			_add(b0 + 0.5, beat, flute[bar], "flute", 0.8)
		for k in 8:
			var m: int = GANGHO_MELODY[bar * 8 + k]
			if m >= 0:
				_add(b0 + k * 0.5, beat, m, "qin", 0.95 if k % 2 == 0 else 0.7)

## 허브(게임 고르기) — B♭ 장조 B♭-Gm-E♭-F, 120 BPM 칩튠(11-09 — "처음 화면 소리가 젤리팝과 같다"). 사각파 리드가 8분으로 화음을 타고,
## 서브 베이스 · 가벼운 킥 · 하이햇. 오락실 대기 화면 느낌 — 어느 게임의 곡도 아니다.
const HUB_MELODY := [
	70, 74, 77, 74, 82, -1, 81, 77,
	67, 70, 74, 70, 79, -1, 77, 74,
	75, 79, 82, 79, 87, -1, 86, 82,
	77, 81, 84, 81, 89, -1, 87, 84,
	82, -1, 81, 79, 77, -1, 74, 77,
	79, -1, 77, 74, 70, -1, 74, 79,
	75, -1, 79, 82, 84, -1, 82, 79,
	77, -1, 81, -1, 84, -1, -1, -1,
]


static func _song_hub() -> void:
	var beat := _bpm(120.0)
	_len = int(beat * 32.0 * RATE)
	var roots := [34, 31, 39, 41, 34, 31, 39, 41]
	for bar in 8:
		var b0 := bar * 4.0
		var r: int = roots[bar]
		_drive(b0, beat, r + 12)
		for k in 4:
			_add(b0 + k, beat, r + (12 if k % 2 == 1 else 0), "sub", 0.9)
			_add(b0 + k + 0.5, beat, 0, "hat", 0.6)
		_add(b0, beat, 0, "kick", 0.6)
		_add(b0 + 2.0, beat, 0, "kick", 0.45)
		for k in 8:
			var m: int = HUB_MELODY[bar * 8 + k]
			if m >= 0:
				_add(b0 + k * 0.5, beat, m - 12, "chip", 0.85)

# ==================== 음표 하나 ====================


## 음표 하나를 _buf 에 더한다. 큰 버퍼라 인자로 넘기지 않고 static 을 바로 쓴다.
static func _note(n: Array) -> void:
	var start: int = n[0]
	var vel: float = n[3]
	match String(n[2]):
		"tiger_kung":
			var cnt := int(0.32 * RATE)
			for j in cnt:
				var t := float(j) / RATE
				var body := sin(TAU * 92.0 * t) + 0.4 * sin(TAU * 147.0 * t)
				var skin := (randf() * 2.0 - 1.0) * exp(-t * 85.0)
				_buf[(start + j) % _len] += (body * exp(-t * 19.0) * 0.38 + skin * 0.08) * vel
			return
		"tiger_deok":
			var cnt := int(0.17 * RATE)
			for j in cnt:
				var t := float(j) / RATE
				var skin := sin(TAU * 310.0 * t) + 0.45 * sin(TAU * 493.0 * t)
				var snap := (randf() * 2.0 - 1.0) * exp(-t * 65.0)
				_buf[(start + j) % _len] += (skin * exp(-t * 34.0) * 0.22 + snap * 0.17) * vel
			return
		"bubble_pop":
			var cnt := int(0.14 * RATE)
			var phase := 0.0
			for j in cnt:
				var t := float(j) / RATE
				phase += TAU * (420.0 + 1350.0 * exp(-t * 42.0)) / RATE
				var env := minf(1.0, t / 0.003) * exp(-t * 48.0)
				_buf[(start + j) % _len] += sin(phase) * env * 0.18 * vel
			return
		"hat":
			var hn := int(0.04 * RATE)
			var he := 1.0
			var hk := exp(-90.0 / RATE)
			for j in hn:
				_buf[(start + j) % _len] += (randf() * 2.0 - 1.0) * he * 0.05 * vel
				he *= hk
			return
		"kick":
			var kn := int(0.25 * RATE)
			var ph := 0.0
			for j in kn:
				var t := float(j) / RATE
				ph += TAU * lerpf(120.0, 42.0, minf(1.0, t / 0.12)) / RATE
				_buf[(start + j) % _len] += sin(ph) * exp(-t * 16.0) * 0.85 * vel
			return
		"snare":
			var sn := int(0.18 * RATE)
			for j in sn:
				var t := float(j) / RATE
				_buf[(start + j) % _len] += ((randf() * 2.0 - 1.0) * exp(-t * 20.0) * 0.32
						+ sin(TAU * 190.0 * t) * exp(-t * 30.0) * 0.3) * vel
			return
	var p: Array = INST[n[2]]
	var harm: Array = p[0]
	var w := TAU * 440.0 * pow(2.0, (int(n[1]) - 69) / 12.0) / RATE
	var cnt := int(float(p[3]) * RATE)
	var dk := exp(-float(p[1]) / RATE)
	var g: float = p[2] * vel
	var att: float = float(p[4]) * RATE
	var env := 1.0
	var hm := PackedFloat32Array()
	var ha := PackedFloat32Array()
	for h: Array in harm:
		hm.append(h[0])
		ha.append(h[1])
	var hn := hm.size()
	for j in cnt:
		var ph := w * j
		var a := minf(1.0, j / att)
		var v := 0.0
		for i in hn:
			v += ha[i] * sin(ph * hm[i])
		_buf[(start + j) % _len] += v * env * a * g
		env *= dk
