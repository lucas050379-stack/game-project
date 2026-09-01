class_name Keys
extends RefCounted

## 키음. **노트를 친 그 순간에 그 자리의 음이 난다.**
##
## 비트매니아·BMS 의 구조를 믹스된 곡에서 흉내 낸 것이다. 원리는 하나다 —
## **곡을 노트 시각으로 잘라 조각을 만들고, 각 조각을 그 노트에 붙인다.**
##
##   PERFECT  조각이 제자리에서 나온다 → 원곡 그대로
##   GOOD     조각이 120ms 밀려 나온다 → 실제로 박자가 흐트러져 들린다
##   MISS     조각이 아예 안 난다 → 음이 빈다
##
## ## 진짜 BMS 와 다른 점
##
## BMS 는 작곡가가 악기별 트랙을 따로 만들어 둬서 **한 악기만** 빠진다.
## 믹스를 자르면 그 구간의 **모든 악기가 같이** 빠진다 — 이미 섞인 소리를 다시
## 나눌 수는 없기 때문이다. 그래서 두 층으로 나눈다.
##
##   - **바닥층(bed)** — 저음만 남긴 것(베이스·킥). 노트와 무관하게 계속 흐른다.
##   - **키음층(keys)** — 나머지 전부. 조각으로 잘려 노트에 붙는다.
##
## 한 번 틀려도 리듬이 완전히 끊기지 않고, 무엇보다 **바닥층이 오디오 시계
## 역할을 한다.** 곡 전체를 노트에 매달면 음이 빌 때 [Conductor] 가 볼 시계가
## 같이 사라진다 — 판정의 기준이 없어지는 것이라 그건 게임이 안 된다.
##
## ## 왜 조각을 미리 잘라 두지 않는가
##
## 조각마다 [AudioStreamWAV] 를 만들면 곡 하나가 메모리에 여러 벌 올라간다
## (4분짜리면 노트가 2천 개다). 여기서는 **스트림 하나를 여럿이 나눠 쓰고**
## 재생할 때 `play(시작 위치)` 로 그 자리부터 틀 뿐이다. 조각은 (시작, 끝) 한 쌍이다.

## 동시에 울릴 수 있는 조각 수. 늦게 치면 앞 조각이 아직 울리는 중에 다음이 나므로
## 하나로는 모자란다. 많이 둘 필요는 없다 — 어차피 겹치는 건 잠깐이다.
const VOICES := 4

var stream: AudioStream = null
var active := false

## 조각. {start, end, auto} — `auto` 는 노트가 없는 자리(곡 시작 전, 사이 빈 곳)라
## 정해진 시각에 저절로 난다.
var slices: Array = []
## 노트 색인 -> 조각 색인. 같은 시각의 노트(동시치기)는 같은 조각을 가리킨다.
var of_note := PackedInt32Array()

var _pool: Array[AudioStreamPlayer] = []
var _stop_at := PackedFloat32Array()   ## 각 목소리가 멈출 곡 시각. 음수면 놀고 있음
var _next := 0
var _fired := []                       ## 조각별로 이미 울렸는가
var _auto_cursor := 0
var _vol := 1.0


## 노트 목록에서 조각표를 만든다. `notes` 는 [Play] 의 것(시각 오름차순).
## `vol` 을 인자로 받는 이유: **오토로드(`Sv`)를 참조하면 이 파일이 `--script`
## 모드에서 컴파일되지 않는다.** 헤드리스 도구는 오토로드 없이 도는데, 조각표를
## 검사하려면 이 클래스를 거기서 만들 수 있어야 한다.
func setup(parent: Node, s: AudioStream, notes: Array, length: float, vol := 1.0) -> void:
	stream = s
	active = s != null
	_vol = clampf(vol, 0.0001, 1.0)
	slices.clear()
	_fired.clear()
	of_note = PackedInt32Array()
	of_note.resize(notes.size())
	_auto_cursor = 0
	if not active:
		return
	# 같은 시각의 노트는 조각 하나를 같이 쓴다. 동시치기 세 개에 조각 세 개를 주면
	# 길이 0 짜리 조각이 둘 생겨 아무 소리도 안 난다.
	var times := PackedFloat32Array()
	for i in notes.size():
		var t: float = notes[i].t
		if times.is_empty() or t - times[times.size() - 1] > 0.001:
			times.append(t)
		of_note[i] = times.size() - 1
	# 첫 노트 앞의 소리는 주인이 없다 — 저절로 나야 한다.
	var head := 0.0 if times.is_empty() else times[0]
	if head > 0.01:
		slices.append({"start": 0.0, "end": head, "auto": true})
		for i in of_note.size():
			of_note[i] += 1
	for i in times.size():
		var st: float = times[i]
		var en: float = length if i + 1 >= times.size() else times[i + 1]
		slices.append({"start": st, "end": maxf(en, st + 0.02), "auto": false})
	_fired.resize(slices.size())
	_fired.fill(false)
	if _pool.is_empty():
		for i in VOICES:
			var p := AudioStreamPlayer.new()
			p.bus = Warp.BUS          # 바닥층과 같은 버스라 음이탈이 같이 걸린다
			parent.add_child(p)
			_pool.append(p)
		_stop_at.resize(VOICES)
	for p in _pool:
		p.stop()
		p.stream = stream
	_stop_at.fill(-1.0)


## 노트를 쳤다. `note_idx` 는 [Play] 의 노트 색인, `now` 는 곡 시각.
##
## **조각은 자기 자리(`start`)부터 튼다.** 늦게 쳤으면 그만큼 늦게 시작해서
## 짧게 끝난다 — 소리가 밀렸다가 제자리로 따라붙는 것처럼 들린다.
## 시작 위치까지 같이 밀면 그냥 곡이 느려진 것처럼 들려서 "틀렸다"가 안 읽힌다.
func hit(note_idx: int, now: float) -> void:
	if not active or note_idx < 0 or note_idx >= of_note.size():
		return
	_play(of_note[note_idx], now)


## 매 프레임. 주인 없는 조각을 제때 울리고, 끝난 조각을 멈춘다.
func step(now: float) -> void:
	if not active:
		return
	while _auto_cursor < slices.size():
		var s: Dictionary = slices[_auto_cursor]
		if float(s.start) > now:
			break
		if s.auto and not _fired[_auto_cursor]:
			_play(_auto_cursor, now)
		_auto_cursor += 1
	for i in _pool.size():
		if _stop_at[i] >= 0.0 and now >= _stop_at[i]:
			_pool[i].stop()
			_stop_at[i] = -1.0


func stop() -> void:
	for p in _pool:
		p.stop()
	_stop_at.fill(-1.0)
	active = false


func _play(si: int, now: float) -> void:
	if si < 0 or si >= slices.size() or _fired[si]:
		return
	_fired[si] = true
	var s: Dictionary = slices[si]
	var end: float = s.end
	if now >= end:
		return                      # 조각이 이미 지나갔다. 지금 틀면 박자만 어긋난다
	var i := _next
	_next = (_next + 1) % _pool.size()
	var p := _pool[i]
	p.volume_db = linear_to_db(_vol)
	p.play(float(s.start))
	_stop_at[i] = end
