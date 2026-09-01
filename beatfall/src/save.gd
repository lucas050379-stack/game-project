extends Node

## `user://save.cfg` 하나. 오프셋 · 배속 · 기록.
## 읽기/쓰기가 실패해도 게임은 기본값으로 돌아야 한다.

const PATH := "user://save.cfg"

## 설정 판. **기본값을 바꾸는 것만으로는 이미 저장된 설정을 못 바꾼다** —
## 예전에 한 번이라도 실행한 사람은 옛 값을 그대로 들고 있고, 그 값이 이긴다.
## 뜻이 바뀐 항목이 생기면 이 숫자를 올리고 [method _migrate] 에 한 줄 더한다.
const VERSION := 2

## 오디오-화면 오프셋(초). 양수면 "내 소리가 화면보다 늦게 들린다"는 뜻이고,
## [Conductor] 가 곡 위치에서 이만큼 뺀다. 캘리브레이션 화면에서 정한다.
var offset := 0.0
var speed := 2.0          ## 배속
var keys := 4             ## 마지막으로 고른 키 수
var vol_music := 0.85
## **타격음은 기본이 0 이다.** 원곡 위에 없는 소리를 얹으면 곡을 방해하고,
## 이 게임은 "잘 치면 원곡이 깨끗하게 들린다"가 곧 보상이다([Warp] 참고).
## 켜고 싶은 사람을 위해 남겨 두었을 뿐이니 기본값을 되돌리지 말 것 —
## 계속 소리가 나면 음이탈과의 대비가 통째로 사라진다.
var vol_hit := 0.0
## 메뉴 소리와 캘리브레이션 메트로놈. 타격음과 따로 둔다 —
## 메트로놈은 판정 보정의 기준이라 **반드시 들려야 한다.**
var vol_ui := 0.7
var autoplay := false     ## 시연/확인용. 켜면 점수가 기록되지 않는다.
## 키음([Keys])을 끄고 예전처럼 곡 전체를 통으로 재생한다. 곡 선택 화면 `K`.
var no_keysound := false

## 곡별 최고 기록. "<곡 폴더>|<난이도 이름>" -> {score, acc, combo, full}
var records := {}


func _ready() -> void:
	load_cfg()


func load_cfg() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		return
	offset = float(c.get_value("play", "offset", offset))
	speed = clampf(float(c.get_value("play", "speed", speed)), D.SPEED_MIN, D.SPEED_MAX)
	keys = int(c.get_value("play", "keys", keys))
	if not D.KEYS.has(keys):
		keys = 4
	vol_music = clampf(float(c.get_value("audio", "music", vol_music)), 0.0, 1.0)
	vol_hit = clampf(float(c.get_value("audio", "hit", vol_hit)), 0.0, 1.0)
	vol_ui = clampf(float(c.get_value("audio", "ui", vol_ui)), 0.0, 1.0)
	no_keysound = bool(c.get_value("play", "no_keysound", no_keysound))
	var r = c.get_value("record", "all", {})
	if typeof(r) == TYPE_DICTIONARY:
		records = r
	_migrate(int(c.get_value("meta", "version", 1)))


## 옛 설정 파일을 지금 규칙으로 끌어올린다. 기록은 건드리지 않는다.
func _migrate(from: int) -> void:
	if from >= VERSION:
		return
	if from < 2:
		# 판 2: 타격음이 기본으로 꺼졌다([Warp] — 틀렸을 때 음악이 무너지는 것과의
		# 대비가 타격음이 없어야 산다). 옛 파일에는 0.75 가 적혀 있어서
		# 기본값을 바꾼 것만으로는 아무 일도 안 일어난다.
		vol_hit = 0.0
	save_cfg()


func save_cfg() -> void:
	var c := ConfigFile.new()
	c.set_value("meta", "version", VERSION)
	c.set_value("play", "offset", offset)
	c.set_value("play", "speed", speed)
	c.set_value("play", "keys", keys)
	c.set_value("play", "no_keysound", no_keysound)
	c.set_value("audio", "music", vol_music)
	c.set_value("audio", "hit", vol_hit)
	c.set_value("audio", "ui", vol_ui)
	c.set_value("record", "all", records)
	c.save(PATH)      # 실패해도 게임은 계속된다


func rec_key(song_id: String, diff_name: String) -> String:
	return song_id + "|" + diff_name


func best(song_id: String, diff_name: String) -> Dictionary:
	var v = records.get(rec_key(song_id, diff_name), null)
	return v if typeof(v) == TYPE_DICTIONARY else {}


## 새 기록이면 저장한다. 점수 기준으로만 갈린다.
func submit(song_id: String, diff_name: String, r: Dictionary) -> bool:
	var b := best(song_id, diff_name)
	if not b.is_empty() and float(b.get("score", 0.0)) >= float(r.get("score", 0.0)):
		return false
	records[rec_key(song_id, diff_name)] = r
	save_cfg()
	return true
