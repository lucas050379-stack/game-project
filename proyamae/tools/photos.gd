extends SceneTree
# 푸야매 — 선수 사진 받기 (헤드리스 전용 도구, 게임 안에서 돌지 않습니다)
#
#   photos.bat
#
# KBO 가 선수 사진을 CDN 에 올려 둡니다:
#   KBO_IMAGE/person/middle/<연도>/<선수번호>.jpg   (94×118 JPEG, 약 13KB)
# 선수번호는 `ids.bat` 이 받아 둔 `data/ids/<연도>.json` 에서 카드로 들어갑니다.
#
# **사진은 2016년부터만 있습니다.** 그 전 시즌은 아무리 찾아도 없습니다.
# 그래서 2016+ 카드의 사진을 받아 두고, 옛 시즌 카드는 **같은 선수의 2016+ 사진을
# 빌려 씁니다**(얼굴은 같은 사람이니까요). 2016 이후로 한 번도 등록된 적이 없는
# 선수(심정수·양준혁 같은)는 사진이 아예 없고, 그 카드는 벡터 그림으로 갑니다.
#
# **없는 연도를 찾아 헤매지 마세요.** 카드 자료에 있는 (선수번호, 연도) 조합만
# 시도합니다. 은퇴 선수마다 열한 해를 두드리면 요청이 수만 건이 됩니다.
#
# **내려받기는 curl 이 합니다.** Godot 헤드리스는 `--script` 모드에서 TLS 를
# 초기화하지 못해("SSL module failed to initialize") HTTPS 를 못 씁니다.
# 그래서 이 스크립트는 **목록을 만들고**(기본) **색인을 세우는**(--index) 일만
# 하고, 사이에서 `photos.bat` 이 curl 을 돌립니다. curl 은 윈도우 10 에 기본으로
# 들어 있습니다.

const BASE := "https://6ptotvmi5753.edge.naverncp.com/KBO_IMAGE/person/middle"
const FIRST_PHOTO_YEAR := 2016
const MIN_BYTES := 500     # 이보다 작으면 404 본문입니다 — 사진이 아닙니다.

func _cards() -> Array:
	var dir := DirAccess.open("res://data/players")
	if dir == null:
		return []
	var out: Array = []
	for fn in dir.get_files():
		if not fn.ends_with(".json"):
			continue
		var f := FileAccess.open("res://data/players/" + fn, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		f.close()
		if typeof(d) == TYPE_DICTIONARY:
			out.append_array(d.get("cards", []))
	return out

func _wanted() -> Array:
	# [[선수번호, 연도], ...] — 2016 이상이고 번호가 있는 것만, 중복 없이.
	var seen := {}
	var out: Array = []
	for c in _cards():
		var pid := str(c.get("pid", ""))
		var y := int(c.get("year", 0))
		if pid == "" or y < FIRST_PHOTO_YEAR:
			continue
		var key := "%s_%d" % [pid, y]
		if seen.has(key):
			continue
		seen[key] = true
		out.append([pid, y])
	return out

func _make_list() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/photos")
	var want := _wanted()
	if want.is_empty():
		print("받을 것이 없습니다. ids.bat → convert.bat 을 먼저 돌리세요.")
		quit(1)
		return
	var root := ProjectSettings.globalize_path("res://data/photos")
	var lines := PackedStringArray()
	var n := 0
	for e in want:
		var pid: String = e[0]
		var y: int = e[1]
		var out := "%s/%s_%d.jpg" % [root, pid, y]
		if FileAccess.file_exists(out):
			continue   # 이미 받은 것은 건너뜁니다 — 다시 돌려도 싸게 끝납니다.
		lines.append('url = "%s/%d/%s.jpg"' % [BASE, y, pid])
		lines.append('output = "%s"' % out)
		n += 1
	var f := FileAccess.open("res://data/photos/_urls.txt", FileAccess.WRITE)
	if f == null:
		print("목록 파일을 못 만들었습니다.")
		quit(1)
		return
	f.store_string("\n".join(lines))
	f.close()
	print("받을 사진 %d장 (전체 %d 중 나머지는 이미 있음)" % [n, want.size()])
	quit(0)

func _make_index() -> void:
	# 404 본문으로 남은 빈 파일을 지우고, **선수번호 → 대표 사진 연도** 표를 씁니다.
	# 옛 시즌 카드는 이 표를 보고 같은 선수의 나중 사진을 빌려 씁니다.
	var dir := DirAccess.open("res://data/photos")
	if dir == null:
		print("data/photos 가 없습니다.")
		quit(1)
		return
	var junk := 0
	for fn in dir.get_files():
		if not fn.ends_with(".jpg"):
			continue
		var f := FileAccess.open("res://data/photos/" + fn, FileAccess.READ)
		if f == null:
			continue
		var sz := f.get_length()
		f.close()
		if sz < MIN_BYTES:
			dir.remove(fn)
			junk += 1

	var best := {}
	var kept := 0
	for c in _cards():
		var pid := str(c.get("pid", ""))
		var y := int(c.get("year", 0))
		if pid == "" or y < FIRST_PHOTO_YEAR:
			continue
		if not FileAccess.file_exists("res://data/photos/%s_%d.jpg" % [pid, y]):
			continue
		kept += 1
		# 가장 최근 연도를 대표로 둡니다.
		if not best.has(pid) or y > int(best[pid]):
			best[pid] = y
	var idx := FileAccess.open("res://data/photos/index.json", FileAccess.WRITE)
	if idx != null:
		idx.store_string(JSON.stringify(best))
		idx.close()
	if FileAccess.file_exists("res://data/photos/_urls.txt"):
		dir.remove("_urls.txt")
	print("사진 정리 — 빈 파일 %d개 삭제 · 사진 있는 선수 %d명" % [junk, best.size()])
	quit(0)

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if str(a) == "--index":
			_make_index()
			return
	_make_list()
