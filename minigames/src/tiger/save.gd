class_name TgSv
extends RefCounted

## 떡 하나 주면 안 잡아먹지 기록 — `user://tiger.cfg`(테스트 빌드는 `tiger_test.cfg`). 라운드마다 별 · 최고점. 기기 안 기록(ADR-0010).
## **읽기 · 쓰기가 실패해도 게임은 처음부터 돈다.** 확인용 실행은 쓰지 않는다(main 의 `no_save`).

static var stars: Array = []   ## 라운드별 별(0~3)
static var best: Array = []    ## 라운드별 최고점
static var plays := 0
static var coins := 0           ## 모은 엽전(강화에 쓴다)
static var up := [0, 0, 0, 0]   ## 강화 단계(TgD.UPGRADES 순서)
static var loaded := false
static var all_open := false     ## 확인용(--tg-open) — 모든 라운드가 열린다


static func _path() -> String:
	return "user://tiger_test.cfg" if OS.has_feature("testbuild") else "user://tiger.cfg"


static func load_() -> void:
	if loaded:
		return
	loaded = true
	stars = []
	best = []
	for k in TgD.ROUNDS.size():
		stars.append(0)
		best.append(0)
	var cfg := ConfigFile.new()
	if cfg.load(_path()) != OK:
		return
	var s = cfg.get_value("rec", "stars", [])
	var b = cfg.get_value("rec", "best", [])
	for k in TgD.ROUNDS.size():
		if s is Array and k < s.size():
			stars[k] = clampi(int(s[k]), 0, 3)
		if b is Array and k < b.size():
			best[k] = maxi(0, int(b[k]))
	plays = int(cfg.get_value("rec", "plays", 0))
	coins = maxi(0, int(cfg.get_value("rec", "coins", 0)))
	var u = cfg.get_value("rec", "up", [])
	for k in 4:
		if u is Array and k < u.size():
			up[k] = clampi(int(u[k]), 0, int(TgD.UPGRADES[k][3]))


static func save_() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("rec", "stars", stars)
	cfg.set_value("rec", "best", best)
	cfg.set_value("rec", "plays", plays)
	cfg.set_value("rec", "coins", coins)
	cfg.set_value("rec", "up", up)
	cfg.save(_path())


## 라운드 k 가 열려 있나 — 첫 라운드거나 앞 라운드를 완주(별 1 이상).
static func unlocked(k: int) -> bool:
	# 테스트 빌드는 전부 열려 있다(사용자 요청 11-10)
	return k == 0 or OS.has_feature("testbuild") or all_open or (k - 1 < stars.size() and int(stars[k - 1]) > 0)


static func cleared() -> int:
	var n := 0
	for s in stars:
		if int(s) > 0:
			n += 1
	return n


static func add(g: TgGame) -> void:
	plays += 1
	coins += g.coins
	var k := g.round_i
	stars[k] = maxi(int(stars[k]), g.stars())
	best[k] = maxi(int(best[k]), g.score())
