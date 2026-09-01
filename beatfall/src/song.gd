class_name Song
extends RefCounted

## 곡 목록. **런타임에 폴더를 읽는다** — 이 게임은 플레이어가 나중에 자기 곡을
## 넣는 것이 전제라 빌드 때 묶을 수가 없다. (저장소의 "리소스 0개" 규칙은 없앴다.)
##
## 찾는 곳은 세 군데다.
##   1. 내장 데모 — 코드로 합성한다([Demo]).
##   2. exe 옆 `songs/` — `import.bat` 이 mp4 를 여기에 풀어 놓는다.
##   3. `user://songs/` — 설치 폴더에 못 쓰는 환경(Program Files 등)의 대비책.
##
## 곡 폴더 하나는 `chart.json` + 오디오 파일 하나다. 폴더째 복사하면 그대로 옮겨진다.

var id := ""              ## 기록 저장용 열쇠. 폴더 이름(내장은 "demo")
var chart: Chart = null
var builtin := false


static func scan() -> Array:
	var out: Array = []
	var d := Song.new()
	d.id = "demo"
	d.builtin = true
	d.chart = Demo.chart()
	out.append(d)
	for root in _roots():
		out.append_array(_scan_dir(root))
	return out


## 곡 폴더를 찾을 위치들. 앞의 것이 먼저다.
static func _roots() -> Array:
	var r: Array = []
	if OS.has_feature("editor"):
		r.append(ProjectSettings.globalize_path("res://songs"))
	else:
		r.append(OS.get_executable_path().get_base_dir().path_join("songs"))
	r.append(ProjectSettings.globalize_path("user://songs"))
	return r


static func _scan_dir(root: String) -> Array:
	var out: Array = []
	var da := DirAccess.open(root)
	if da == null:
		return out
	for name in da.get_directories():
		var path := root.path_join(name)
		var c := Chart.load_from(path.path_join("chart.json"))
		if c == null:
			continue
		var s := Song.new()
		s.id = name
		s.chart = c
		out.append(s)
	return out


## exe 옆에 곡을 놓을 폴더. `import.bat` 이 여기에 쓴다.
static func songs_dir() -> String:
	return _roots()[0]


func title() -> String:
	return chart.title


func artist() -> String:
	return chart.artist


## 재생할 오디오 스트림. 내장 곡은 합성하고, 나머지는 파일에서 읽는다.
## 읽기에 실패하면 null 을 돌려주고, 부르는 쪽이 곡을 건너뛴다.
func stream() -> AudioStream:
	if builtin:
		return Demo.stream()
	return _load(chart.audio_path())


## 두 층([Keys] 참고). `[바닥층, 키음층]` 이고, 이 곡이 키음을 못 쓰면 빈 배열.
##
## **두 층이 다 있어야 켜진다.** 하나만 있으면 소리가 반쪽이 나므로 아예 안 쓰고
## `stream()` 한 벌로 예전처럼 재생한다. 옛 곡 폴더가 그대로 돌아야 한다.
func layers() -> Array:
	if builtin:
		return [Demo.stream_bed(), Demo.stream_keys()]
	var p := chart.layer_paths()
	if p.is_empty():
		return []
	var bed := _load(p[0])
	var keys := _load(p[1])
	return [] if bed == null or keys == null else [bed, keys]


func _load(p: String) -> AudioStream:
	if p.is_empty() or not FileAccess.file_exists(p):
		push_warning("곡 파일이 없습니다: " + p)
		return null
	match p.get_extension().to_lower():
		"ogg":
			return AudioStreamOggVorbis.load_from_file(p)
		"mp3":
			var b := FileAccess.get_file_as_bytes(p)
			return null if b.is_empty() else AudioStreamMP3.load_from_buffer(b)
		"wav":
			return AudioStreamWAV.load_from_file(p)
	push_warning("모르는 오디오 형식입니다: " + p)
	return null
