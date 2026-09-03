extends Node
# 푸야매 — 선수 사진. 오토로드(`Spr`)입니다.
#
# `data/photos/<선수번호>_<연도>.jpg` 를 실행 중에 읽습니다.
# **사진 폴더가 비어 있어도 게임은 돌아야 합니다** — 없으면 카드가 벡터 그림으로
# 그려집니다(`Art._figure`). `photos.bat` 은 한 번만 돌리면 되는 도구입니다.
#
# **사진은 2016년부터만 있습니다.** 옛 시즌 카드는 같은 선수의 나중 사진을
# 빌려 씁니다 — 얼굴은 같은 사람이니까요. `index.json` 이 선수번호마다
# "몇 년 사진을 쓰면 되는지"를 들고 있습니다.

const CACHE_MAX := 400   # 이만큼 차면 통째로 비웁니다. 도감은 1만 장이라
                         # 캐시를 안 비우면 텍스처가 수백 MB 로 불어납니다.

var _dir := ""
var _index: Dictionary = {}    # 선수번호 → 대표 사진 연도
var _cache: Dictionary = {}    # "번호_연도" → ImageTexture (없으면 null 을 넣어 재시도를 막습니다)
var loaded := false

func _ready() -> void:
	for d in [OS.get_executable_path().get_base_dir().path_join("data/photos"), "res://data/photos"]:
		if FileAccess.file_exists(d.path_join("index.json")):
			_dir = d
			break
	if _dir == "":
		return
	var f := FileAccess.open(_dir.path_join("index.json"), FileAccess.READ)
	if f == null:
		return
	var j = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(j) == TYPE_DICTIONARY:
		_index = j
		loaded = true

func has_photos() -> bool:
	return loaded

func tex(c: Dictionary):
	# 카드에 쓸 사진. 없으면 null — 부르는 쪽이 벡터로 넘어갑니다.
	if not loaded or c.is_empty():
		return null
	var pid := str(c.get("pid", ""))
	if pid == "":
		return null
	# 그 시즌 사진이 있으면 그것을, 없으면 그 선수의 대표 사진을 씁니다.
	var y := int(c.get("year", 0))
	var key := "%s_%d" % [pid, y]
	if not FileAccess.file_exists(_dir.path_join(key + ".jpg")):
		if not _index.has(pid):
			return null
		key = "%s_%d" % [pid, int(_index[pid])]
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > CACHE_MAX:
		_cache.clear()
	var t = _load(key)
	_cache[key] = t
	return t

func _load(key: String):
	var f := FileAccess.open(_dir.path_join(key + ".jpg"), FileAccess.READ)
	if f == null:
		return null
	var buf := f.get_buffer(f.get_length())
	f.close()
	var img := Image.new()
	if img.load_jpg_from_buffer(buf) != OK:
		return null
	return ImageTexture.create_from_image(img)
