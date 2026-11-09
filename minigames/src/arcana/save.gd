class_name AcSv
extends RefCounted

## 아르카나 컬렉션 기록 — `user://arcana.cfg` 하나(테스트 빌드는 `arcana_test.cfg`). 젤리팝 Sv 와 파일을 나눴다.
## **읽기 · 쓰기가 실패해도 게임은 빈 기록으로 돈다.** 확인용 실행(`--ac-*`)은 쓰지 않는다(main 의 `no_save`).

static var plays := {}        ## 상대 수("1" · "2" · "3") → 판 수
static var wins := {}         ## 상대 수 → 이긴 판
static var best := 0          ## 가장 높은 점수
static var fastest := 0       ## 가장 빨리 이긴 라운드(0 = 아직)
static var opp := 1           ## 마지막으로 고른 상대 수
static var rules_seen := false   ## 첫 판에 규칙서를 띄웠나
static var loaded := false


static func _path() -> String:
	return "user://arcana_test.cfg" if OS.has_feature("testbuild") else "user://arcana.cfg"


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
	opp = clampi(int(cfg.get_value("rec", "opp", 1)), 1, 3)
	rules_seen = bool(cfg.get_value("rec", "rules_seen", false))


static func save_() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("rec", "plays", plays)
	cfg.set_value("rec", "wins", wins)
	cfg.set_value("rec", "best", best)
	cfg.set_value("rec", "fastest", fastest)
	cfg.set_value("rec", "opp", opp)
	cfg.set_value("rec", "rules_seen", rules_seen)
	cfg.save(_path())


## 한 판이 끝났을 때(사람 = 0번 자리).
static func add(g: AcGame) -> void:
	var key := str(g.n - 1)
	plays[key] = int(plays.get(key, 0)) + 1
	if g.winner == 0:
		wins[key] = int(wins.get(key, 0)) + 1
		if fastest == 0 or g.round_no < fastest:
			fastest = g.round_no
	best = maxi(best, g.points(0))
	save_()
