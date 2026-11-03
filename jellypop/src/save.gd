class_name Sv
extends RefCounted

## 기록 — 타임 어택 최고 점수, 스테이지마다 별 · 최고 점수.
## 웹에서는 `user://` 가 브라우저 IndexedDB 에 저장된다.
## **실패해도 게임은 돌아야 한다** — 사생활 보호 창에서는 저장이 막힐 수 있다.

const PATH := "user://save.cfg"
## 테스트 빌드는 세이브를 따로 쓴다 — 같은 주소에서 띄우면 브라우저 저장소를 같이 쓰므로,
## 테스트로 깬 기록이 정식 판으로 넘어가면 안 된다.
const PATH_TEST := "user://save_test.cfg"

## 테스트 빌드(`testbuild` 기능 태그) 또는 `--unlock` — 모든 스테이지가 열린다.
## **세이브에 쓰지 않고 `unlocked()` 의 대답만 바꾼다.**
static var all_open := false

## 지도 판본 — 스테이지 지도를 통째로 바꾸면 올린다. 다르면 스테이지 기록(별 · 점수)만 비운다.
## 판 번호가 같아도 지도가 다르면 예전 별이 남의 판에 붙어 있게 된다(손으로 짠 120판 → 생성기 200판).
## 타임 어택 최고 점수는 지도와 상관없으니 남긴다.
const MAP_VER := 2

static var best := 0
static var plays := 0
static var stars := {}     ## 스테이지 id → 별 (0~3)
static var scores := {}    ## 스테이지 id → 최고 점수


static func load_() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_path()) != OK:
		return
	best = maxi(0, int(cfg.get_value("player", "best", 0)))
	plays = maxi(0, int(cfg.get_value("player", "plays", 0)))
	if int(cfg.get_value("player", "maps", 1)) != MAP_VER:
		return
	if cfg.has_section("stage"):
		for k in cfg.get_section_keys("stage"):
			var v: Array = cfg.get_value("stage", k, [0, 0])
			stars[int(k)] = clampi(int(v[0]), 0, 3)
			scores[int(k)] = maxi(0, int(v[1]))


static func save_() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "best", best)
	cfg.set_value("player", "plays", plays)
	cfg.set_value("player", "maps", MAP_VER)
	for id in stars:
		cfg.set_value("stage", str(id), [stars[id], scores.get(id, 0)])
	cfg.save(_path())   # 실패해도 그냥 둔다


static func _path() -> String:
	return PATH_TEST if all_open else PATH


## 깼을 때만 부른다. 별과 점수는 각자 더 좋은 쪽을 남긴다.
static func record(id: int, st: int, score: int) -> void:
	stars[id] = maxi(int(stars.get(id, 0)), st)
	scores[id] = maxi(int(scores.get(id, 0)), score)
	save_()


## 열린 스테이지 수 — 깬 것 중 가장 뒤 + 1.
static func unlocked() -> int:
	if all_open:
		return 1 << 20
	var n := 1
	for id in stars:
		if int(stars[id]) > 0:
			n = maxi(n, int(id) + 1)
	return n
