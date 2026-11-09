class_name EmSv
extends RefCounted

## 제국 연대기 기록 — `user://empire.cfg` 하나(테스트 빌드는 `empire_test.cfg`).
## **읽기 · 쓰기가 실패해도 게임은 빈 기록으로 돈다.** 확인용 실행(`--em-*` · `--shot`)은 쓰지 않는다(main 의 `no_save`).

static var plays := {}        ## 난이도("0" · "1" · "2") → 판 수
static var wins := {}         ## 난이도 → 이긴 판
static var by_kind := {}      ## 이긴 방식("mil" · "sci" · "civ") → 횟수
static var best := 0          ## 가장 높은 문명 점수
static var level := 1         ## 마지막으로 고른 난이도
static var rules_seen := false   ## 첫 판에 규칙서를 띄웠나
static var loaded := false


static func _path() -> String:
	return "user://empire_test.cfg" if OS.has_feature("testbuild") else "user://empire.cfg"


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
	var k = cfg.get_value("rec", "by_kind", {})
	by_kind = k if k is Dictionary else {}
	best = int(cfg.get_value("rec", "best", 0))
	level = clampi(int(cfg.get_value("rec", "level", 1)), 0, 2)
	rules_seen = bool(cfg.get_value("rec", "rules_seen", false))


static func save_() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("rec", "plays", plays)
	cfg.set_value("rec", "wins", wins)
	cfg.set_value("rec", "by_kind", by_kind)
	cfg.set_value("rec", "best", best)
	cfg.set_value("rec", "level", level)
	cfg.set_value("rec", "rules_seen", rules_seen)
	cfg.save(_path())


## 한 판이 끝났을 때(사람 = 0번 자리).
static func add(g: EmGame, lv: int) -> void:
	var key := str(lv)
	plays[key] = int(plays.get(key, 0)) + 1
	if g.winner == 0:
		wins[key] = int(wins.get(key, 0)) + 1
		by_kind[g.win_kind] = int(by_kind.get(g.win_kind, 0)) + 1
	if g.win_kind == "civ":
		best = maxi(best, g.points(0))
	save_()
