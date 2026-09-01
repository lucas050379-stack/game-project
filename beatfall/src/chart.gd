class_name Chart
extends RefCounted

## 채보 한 벌. `songs/<곡>/chart.json` 을 읽고 쓴다.
##
## **노트 시각은 박(beat)이 아니라 초(second)다.** 박으로 두면 BPM 이 흔들리는
## 실제 녹음에서 곡 후반이 통째로 밀린다 — mp4 에서 뽑은 곡은 클릭 트랙에 맞춰
## 연주한 것이 아니므로 대부분 흔들린다. BPM 은 격자 표시와 채보 생성기가
## 참고하는 값일 뿐 재생에는 쓰지 않는다.
##
## 파일 모양:
## [codeblock]
## {
##   "title": "곡 이름", "artist": "만든 사람",
##   "audio": "audio.ogg",     # 같은 폴더 안의 상대 경로
##   "bpm": 128.0,             # 표시·격자용. 없으면 0
##   "offset": 0.0,            # 파일 앞 무음(초)
##   "charts": [
##     {"name": "NORMAL", "keys": 4, "level": 7,
##      "notes": [[12.345, 2, 0.0], [12.6, 0, 0.75]]}
##   ]
## }
## [/codeblock]
## 노트 하나는 `[시각, 레인, 길이]` 이고 길이 0 이면 그냥 누르는 노트다.

const VERSION := 1

var title := ""
var artist := ""
var audio := ""          ## chart.json 과 같은 폴더 기준 상대 경로
## 두 층([Keys] 참고). 없으면 `audio` 한 벌로 예전처럼 재생한다.
var bed := ""            ## 저음만 — 계속 흐르고 오디오 시계가 된다
var keys := ""           ## 나머지 — 노트 시각으로 잘려 노트에 붙는다
var bpm := 0.0
var offset := 0.0
var dir := ""            ## 이 채보가 있는 폴더 (곡 파일을 찾을 때 쓴다)

## 난이도별 채보. 각 원소는 {name, keys, level, notes}.
## notes 는 [시각, 레인, 길이] 배열이고 **시각 오름차순으로 정렬되어 있어야 한다** —
## 판정 루프가 앞에서부터 커서를 밀며 도는 구조라 순서가 어긋나면 조용히 노트를 건너뛴다.
var diffs: Array = []


static func load_from(path: String) -> Chart:
	if not FileAccess.file_exists(path):
		return null
	var txt := FileAccess.get_file_as_string(path)
	if txt.is_empty():
		return null
	var j = JSON.parse_string(txt)
	if typeof(j) != TYPE_DICTIONARY:
		push_warning("채보를 읽지 못했습니다: " + path)
		return null
	var c := Chart.new()
	c.dir = path.get_base_dir()
	c.title = str(j.get("title", path.get_base_dir().get_file()))
	c.artist = str(j.get("artist", ""))
	c.audio = str(j.get("audio", ""))
	c.bed = str(j.get("bed", ""))
	c.keys = str(j.get("keys", ""))
	c.bpm = float(j.get("bpm", 0.0))
	c.offset = float(j.get("offset", 0.0))
	for d in j.get("charts", []):
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var notes: Array = []
		for n in d.get("notes", []):
			if typeof(n) != TYPE_ARRAY or n.size() < 2:
				continue
			notes.append([float(n[0]), int(n[1]), float(n[2]) if n.size() > 2 else 0.0])
		notes.sort_custom(func(a, b): return a[0] < b[0])
		c.diffs.append({
			"name": str(d.get("name", "?")),
			"keys": int(d.get("keys", 4)),
			"level": int(d.get("level", 0)),
			"notes": notes,
		})
	if c.diffs.is_empty():
		return null
	return c


func save_to(path: String) -> bool:
	var out := {
		"version": VERSION, "title": title, "artist": artist, "audio": audio,
		"bed": bed, "keys": keys,
		"bpm": bpm, "offset": offset, "charts": [],
	}
	for d in diffs:
		var notes: Array = []
		for n in d.notes:
			# 소수점을 줄여 파일을 작게 만든다. 1ms 아래는 판정창(42ms)에 비해 무의미하다.
			notes.append([snappedf(n[0], 0.001), n[1], snappedf(n[2], 0.001)])
		out.charts.append({"name": d.name, "keys": d.keys, "level": d.level, "notes": notes})
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("채보를 쓰지 못했습니다: " + path)
		return false
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	return true


## 층 파일의 실제 경로. 둘 다 있어야 키음 모드가 켜진다.
func layer_paths() -> Array:
	if bed.is_empty() or keys.is_empty() or dir.is_empty():
		return []
	var b := dir.path_join(bed)
	var k := dir.path_join(keys)
	if not FileAccess.file_exists(b) or not FileAccess.file_exists(k):
		return []
	return [b, k]


## 곡 파일의 실제 경로. 없으면 빈 문자열.
func audio_path() -> String:
	if audio.is_empty():
		return ""
	return dir.path_join(audio)


func last_time(di: int) -> float:
	var n: Array = diffs[di].notes
	if n.is_empty():
		return 0.0
	var e = n[n.size() - 1]
	return e[0] + e[2]


## 초당 노트 수. 레벨 표기와 난이도 정렬에 쓴다.
func nps(di: int) -> float:
	var n: Array = diffs[di].notes
	if n.size() < 2:
		return 0.0
	var span: float = n[n.size() - 1][0] - n[0][0]
	return 0.0 if span <= 0.1 else float(n.size()) / span
