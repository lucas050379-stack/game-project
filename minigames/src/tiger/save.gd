class_name TgSv
extends RefCounted

## 떡 하나 주면 안 잡아먹지 기록 — `user://tiger.cfg`(테스트 빌드는 `tiger_test.cfg`). 기기 안 기록(ADR-0010).
## **이어 달리기**(11-10): 최고 점수 · 가장 멀리 간 거리(m) · 가장 멀리 닿은 구간. 예전 라운드별 별 · 최고점(stars · best)은 읽지 않는다.
## **읽기 · 쓰기가 실패해도 게임은 처음부터 돈다.** 확인용 실행은 쓰지 않는다(main 의 `no_save`).

static var best_score := 0
static var best_m := 0
static var best_zone := -1      ## 가장 멀리 닿은 구간(0 부터, 아직 안 달렸으면 -1)
static var plays := 0
static var coins := 0           ## 모은 엽전(강화에 쓴다)
static var up := [0, 0, 0, 0]   ## 강화 단계(TgD.UPGRADES 순서)
static var loaded := false


static func _path() -> String:
	return "user://tiger_test.cfg" if OS.has_feature("testbuild") else "user://tiger.cfg"


static func load_() -> void:
	if loaded:
		return
	loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(_path()) != OK:
		return
	best_score = maxi(0, int(cfg.get_value("run", "best_score", 0)))
	best_m = maxi(0, int(cfg.get_value("run", "best_m", 0)))
	best_zone = int(cfg.get_value("run", "best_zone", -1))
	plays = int(cfg.get_value("rec", "plays", 0))
	coins = maxi(0, int(cfg.get_value("rec", "coins", 0)))
	var u = cfg.get_value("rec", "up", [])
	for k in 4:
		if u is Array and k < u.size():
			up[k] = clampi(int(u[k]), 0, int(TgD.UPGRADES[k][3]))


static func save_() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("run", "best_score", best_score)
	cfg.set_value("run", "best_m", best_m)
	cfg.set_value("run", "best_zone", best_zone)
	cfg.set_value("rec", "plays", plays)
	cfg.set_value("rec", "coins", coins)
	cfg.set_value("rec", "up", up)
	cfg.save(_path())


## 한 판을 넣는다. 돌려주는 값: 새 기록이 된 것들 {score, m, zone}.
static func add(g: TgGame) -> Dictionary:
	plays += 1
	coins += g.coins
	var fresh := {score = g.score() > best_score, m = g.meters() > best_m, zone = g.zone > best_zone}
	best_score = maxi(best_score, g.score())
	best_m = maxi(best_m, g.meters())
	best_zone = maxi(best_zone, g.zone)
	return fresh
