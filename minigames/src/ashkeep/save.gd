class_name AkSv
extends RefCounted

## 잿빛 요새의 용병단 진척 — `user://ashkeep.cfg` 하나(테스트 빌드는 `ashkeep_test.cfg`).
## 깬 시나리오 수 · 영웅별 경험치 · 난이도. **읽기 · 쓰기가 실패해도 게임은 처음부터 돈다.** 확인용 실행은 쓰지 않는다(main 의 `no_save`).

const XP_PER_LEVEL := 12
const MAX_LEVEL := 5

static var cleared := 0        ## 깬 시나리오 수(다음 시나리오 = cleared, 0부터)
static var best_clear := {}    ## 시나리오 번호 → 깬 라운드(가장 빠른)
static var xp := [0, 0, 0, 0]
static var diff := 0           ## -1 쉬움 · 0 보통 · 1 어려움
static var plays := 0
static var wins := 0
static var loaded := false


static func _path() -> String:
	return "user://ashkeep_test.cfg" if OS.has_feature("testbuild") else "user://ashkeep.cfg"


static func level(h: int) -> int:
	return mini(MAX_LEVEL, 1 + int(xp[h]) / XP_PER_LEVEL)


static func load_() -> void:
	if loaded:
		return
	loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(_path()) != OK:
		return
	cleared = clampi(int(cfg.get_value("rec", "cleared", 0)), 0, AkD.SCENARIOS.size())
	var b = cfg.get_value("rec", "best_clear", {})
	best_clear = b if b is Dictionary else {}
	var x = cfg.get_value("rec", "xp", [0, 0, 0, 0])
	if x is Array and x.size() == 4:
		xp = x
	diff = clampi(int(cfg.get_value("rec", "diff", 0)), -1, 1)
	plays = int(cfg.get_value("rec", "plays", 0))
	wins = int(cfg.get_value("rec", "wins", 0))


static func save_() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("rec", "cleared", cleared)
	cfg.set_value("rec", "best_clear", best_clear)
	cfg.set_value("rec", "xp", xp)
	cfg.set_value("rec", "diff", diff)
	cfg.set_value("rec", "plays", plays)
	cfg.set_value("rec", "wins", wins)
	cfg.save(_path())


## 시나리오 하나가 끝났을 때 — 영웅마다 카드 경험치 + 시나리오 경험치(이기면 3, 지면 1).
static func add(g: AkGame, kinds: Array) -> void:
	plays += 1
	for i in kinds.size():
		xp[int(kinds[i])] = int(xp[int(kinds[i])]) + int(g.heroes[i].xp) + (3 if g.win else 1)
	if g.win:
		wins += 1
		if g.scen >= cleared:
			cleared = mini(AkD.SCENARIOS.size(), g.scen + 1)
		var key := str(g.scen)
		if not best_clear.has(key) or g.round_no < int(best_clear[key]):
			best_clear[key] = g.round_no
	save_()
