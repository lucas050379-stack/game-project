class_name BbSv
extends RefCounted

## 물거품처럼 사라져줘 기록 — `user://bubble.cfg`(테스트 빌드는 `bubble_test.cfg`). 최고 점수 · 가장 멀리 간 판(혼자 · 둘이 따로).
## 읽기 · 쓰기가 실패해도 게임은 처음부터 돈다. 확인용 실행은 쓰지 않는다(main 의 `no_save`).

static var best := [0, 0]      ## 최고 점수(혼자 · 둘이)
static var best_lv := [0, 0]   ## 가장 멀리 간 판(1 부터, 0 = 아직)
static var plays := 0
static var loaded := false


static func _path() -> String:
	return "user://bubble_test.cfg" if OS.has_feature("testbuild") else "user://bubble.cfg"


static func load_() -> void:
	if loaded:
		return
	loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(_path()) != OK:
		return
	for k in 2:
		best[k] = maxi(0, int((cfg.get_value("rec", "best", [0, 0]) as Array)[k]))
		best_lv[k] = maxi(0, int((cfg.get_value("rec", "best_lv", [0, 0]) as Array)[k]))
	plays = int(cfg.get_value("rec", "plays", 0))


static func save_() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("rec", "best", best)
	cfg.set_value("rec", "best_lv", best_lv)
	cfg.set_value("rec", "plays", plays)
	cfg.save(_path())


## 한 판을 넣는다. 돌려주는 값: 새 기록 {score, lv}.
static func add(g: BbGame) -> Dictionary:
	var k := 1 if g.two else 0
	plays += 1
	var fresh := {score = g.total_score() > int(best[k]), lv = g.lv + 1 > int(best_lv[k])}
	best[k] = maxi(int(best[k]), g.total_score())
	best_lv[k] = maxi(int(best_lv[k]), g.lv + 1)
	return fresh
