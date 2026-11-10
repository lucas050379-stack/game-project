class_name BgSv
extends RefCounted

## 버거 한 판 기록 — `user://burger.cfg`(테스트 빌드는 `burger_test.cfg`). 날마다의 별 · 가진 돈 · 열린 재료 · 강화. 기기 안 기록(ADR-0010).
## **읽기 · 쓰기가 실패해도 게임은 처음부터 돈다.** 확인용 실행은 쓰지 않는다(main 의 `no_save`).

static var stars: Array = []     ## 날마다의 별(0~3)
static var best: Array = []      ## 날마다 가장 많이 번 돈
static var money := 0            ## 가진 돈(가게에서 쓴다)
static var unlocked: Array = []  ## 열린 재료 id
static var up := {}              ## 강화 단계
static var loaded := false
static var all_open := false     ## 확인용(--bg-open) — 모든 날이 열린다


static func _path() -> String:
	return "user://burger_test.cfg" if OS.has_feature("testbuild") else "user://burger.cfg"


static func load_() -> void:
	if loaded:
		return
	loaded = true
	stars = []
	best = []
	for k in BgD.DAYS:
		stars.append(0)
		best.append(0)
	unlocked = BgD.starters()
	up = {}
	for row: Array in BgD.UP:
		up[row[0]] = 0
	var cfg := ConfigFile.new()
	if cfg.load(_path()) != OK:
		return
	var s = cfg.get_value("rec", "stars", [])
	var b = cfg.get_value("rec", "best", [])
	for k in BgD.DAYS:
		if s is Array and k < s.size():
			stars[k] = clampi(int(s[k]), 0, 3)
		if b is Array and k < b.size():
			best[k] = maxi(0, int(b[k]))
	money = maxi(0, int(cfg.get_value("rec", "money", 0)))
	var u = cfg.get_value("rec", "unlocked", [])
	if u is Array:
		for id in u:
			if BgD.ING.has(String(id)) and not unlocked.has(String(id)):
				unlocked.append(String(id))
	var lv = cfg.get_value("rec", "up", {})
	if lv is Dictionary:
		for row: Array in BgD.UP:
			up[row[0]] = clampi(int(lv.get(row[0], 0)), 0, (row[3] as Array).size())


static func save_() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("rec", "stars", stars)
	cfg.set_value("rec", "best", best)
	cfg.set_value("rec", "money", money)
	cfg.set_value("rec", "unlocked", unlocked)
	cfg.set_value("rec", "up", up)
	cfg.save(_path())


## d 번째 날이 열려 있나 — 첫날이거나 앞날에 별 하나 이상.
static func open(d: int) -> bool:
	return d == 0 or OS.has_feature("testbuild") or all_open or int(stars[d - 1]) > 0


static func cleared() -> int:
	var n := 0
	for s in stars:
		if int(s) > 0:
			n += 1
	return n


## 하루를 마쳤다 — 번 돈은 별과 상관없이 내 돈이 된다.
static func add(g: BgGame) -> void:
	money += g.money
	stars[g.day] = maxi(int(stars[g.day]), g.stars())
	best[g.day] = maxi(int(best[g.day]), g.money)


## 강화 한 단계의 값(-1 = 다 올렸다).
static func up_cost(key: String) -> int:
	for row: Array in BgD.UP:
		if String(row[0]) == key:
			var lv := int(up[key])
			return int(row[3][lv]) if lv < (row[3] as Array).size() else -1
	return -1
