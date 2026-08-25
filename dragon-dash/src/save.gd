class_name Sv
extends RefCounted

## 판이 끝나도 남는 것 — 금화, 금화로 산 강화, 최고 기록.
##
## `user://save.cfg` 한 파일에 넣는다. 이건 **배포 리소스가 아니라 플레이어가 만드는 기록**
## 이라 "리소스 0개 · 파일 하나로 배포" 원칙과 어긋나지 않는다. APK 는 그대로 하나고,
## 저장 파일은 처음 실행할 때 앱 전용 폴더에 생긴다.
##
## **실패해도 게임은 돌아야 한다.** 읽기/쓰기 오류는 조용히 무시하고 기본값을 쓴다 —
## 폰에서는 저장소 권한이나 용량 때문에 실제로 실패할 수 있고, 그때 게임이 안 켜지면 안 된다.

const PATH := "user://save.cfg"

static var gold := 0
static var best := 0              ## 최고 거리(m)
static var runs := 0
static var dragon := 0            ## 마지막에 고른 드래곤
## 상점 항목 id -> 산 레벨
static var lv := {}

static var _loaded := false


static func load_() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	gold = maxi(0, int(cfg.get_value("player", "gold", 0)))
	best = maxi(0, int(cfg.get_value("player", "best", 0)))
	runs = maxi(0, int(cfg.get_value("player", "runs", 0)))
	dragon = clampi(int(cfg.get_value("player", "dragon", 0)), 0, D.DRAGON.size() - 1)
	for s in D.SHOP:
		var id := String(s.id)
		lv[id] = clampi(int(cfg.get_value("upgrade", id, 0)), 0, int(s.max))


static func save_() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "gold", gold)
	cfg.set_value("player", "best", best)
	cfg.set_value("player", "runs", runs)
	cfg.set_value("player", "dragon", dragon)
	for s in D.SHOP:
		cfg.set_value("upgrade", String(s.id), level(String(s.id)))
	cfg.save(PATH)   # 실패해도 그냥 둔다


static func level(id: String) -> int:
	return int(lv.get(id, 0))


static func cost(id: String) -> int:
	return D.cost(id, level(id))


## 살 수 있으면 사고 true. 금화가 모자라거나 만렙이면 false.
static func buy(id: String) -> bool:
	var s := D.shop(id)
	if s.is_empty():
		return false
	var l := level(id)
	if l >= int(s.max):
		return false
	var c := D.cost(id, l)
	if gold < c:
		return false
	gold -= c
	lv[id] = l + 1
	save_()
	return true


## 한 판이 끝났을 때. **최고 기록과 금화를 여기 한 곳에서만 건드린다** —
## 여러 곳에서 더하면 죽는 경로가 늘 때마다 조용히 두 번 세어진다.
static func finish_run(dist_m: int, earned: int) -> bool:
	runs += 1
	gold += maxi(0, earned)
	var rec := dist_m > best
	if rec:
		best = dist_m
	save_()
	return rec


## 개발용. 저장을 지우고 처음 상태로.
static func wipe() -> void:
	gold = 0
	best = 0
	runs = 0
	dragon = 0
	lv.clear()
	save_()
