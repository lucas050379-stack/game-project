class_name RsSv
extends RefCounted

## 붉은 별 개척단 기록 — `user://redstar.cfg` 하나(테스트 빌드는 `redstar_test.cfg`).
## **읽기 · 쓰기가 실패해도 게임은 빈 기록으로 돈다.** 확인용 실행(명령줄 인자)은 쓰지 않는다(main 의 `no_save`).

static var plays := {}        ## 난이도("0" · "1" · "2") → 판 수
static var wins := {}         ## 난이도 → 이긴 판
static var best := 0          ## 가장 높은 점수
static var fastest := 0       ## 가장 빨리 개조를 끝낸 세대(0 = 아직)
static var level := 1
static var loaded := false


static func _path() -> String:
	return "user://redstar_test.cfg" if OS.has_feature("testbuild") else "user://redstar.cfg"


static func load_() -> void:
	if loaded:
		return
	loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(_path()) != OK:
		return
	var p = cfg.get_value("rec", "plays", {})
	plays = p if p is Dictionary else {}
	var w = cfg.get_value("rec", "wins", {})
	wins = w if w is Dictionary else {}
	best = int(cfg.get_value("rec", "best", 0))
	fastest = int(cfg.get_value("rec", "fastest", 0))
	level = clampi(int(cfg.get_value("rec", "level", 1)), 0, 2)


static func save_() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("rec", "plays", plays)
	cfg.set_value("rec", "wins", wins)
	cfg.set_value("rec", "best", best)
	cfg.set_value("rec", "fastest", fastest)
	cfg.set_value("rec", "level", level)
	cfg.save(_path())


static func add(g: RsGame, lv: int) -> void:
	var key := str(lv)
	plays[key] = int(plays.get(key, 0)) + 1
	if g.winner == 0:
		wins[key] = int(wins.get(key, 0)) + 1
	best = maxi(best, g.points(0))
	if g.maxed() and (fastest == 0 or g.gen < fastest):
		fastest = g.gen
	save_()
