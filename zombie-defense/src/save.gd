class_name Sv
extends RefCounted

## 판이 끝나도 남는 것 — 코인, 코인으로 산 기본 스텟 강화, 최고 라운드.
##
## `user://save.cfg` 한 파일에 넣는다. 이건 **배포 리소스가 아니라 플레이어가 만드는 기록**이라
## "리소스 0개 · 단일 exe" 원칙과 어긋나지 않는다 — exe 는 그대로 하나고, 저장 파일은
## 처음 실행할 때 사용자 폴더에 생긴다. 없으면 전부 0 으로 시작한다.
##
## 실패해도 게임은 돌아야 한다. 읽기/쓰기 오류는 조용히 무시하고 기본값을 쓴다.

const PATH := "user://save.cfg"

static var coins := 0
static var best_round := 1
## 상점 항목 번호 -> 산 레벨
static var upgrades := {}

static var _loaded := false


static func load_() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	coins = int(cfg.get_value("player", "coins", 0))
	best_round = maxi(1, int(cfg.get_value("player", "best_round", 1)))
	for i in D.SHOP.size():
		var lv := int(cfg.get_value("upgrade", String(D.SHOP[i]["kind"]), 0))
		upgrades[i] = clampi(lv, 0, int(D.SHOP[i]["max"]))


static func save_() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "coins", coins)
	cfg.set_value("player", "best_round", best_round)
	for i in D.SHOP.size():
		cfg.set_value("upgrade", String(D.SHOP[i]["kind"]), level(i))
	cfg.save(PATH)


static func level(idx: int) -> int:
	return int(upgrades.get(idx, 0))


## 강화 종류 kind 가 쌓아 준 값 (레벨 × 레벨당 값)
static func bonus(kind: String) -> float:
	for i in D.SHOP.size():
		if String(D.SHOP[i]["kind"]) == kind:
			return level(i) * float(D.SHOP[i]["val"])
	return 0.0


static func maxed(idx: int) -> bool:
	return level(idx) >= int(D.SHOP[idx]["max"])


static func cost(idx: int) -> int:
	return D.shop_cost(idx, level(idx))


## 살 수 있으면 사고 true. 코인이 모자라거나 만렙이면 아무 일도 안 일어난다.
static func buy(idx: int) -> bool:
	if maxed(idx) or coins < cost(idx):
		return false
	coins -= cost(idx)
	upgrades[idx] = level(idx) + 1
	save_()
	return true


static func add_coins(n: int) -> void:
	coins += n
	save_()


static func reach(round_no: int) -> void:
	if round_no > best_round:
		best_round = round_no
		save_()


## 개발/테스트용 — 기록을 통째로 지운다. 어디서도 부르지 않는다.
static func wipe() -> void:
	coins = 0
	best_round = 1
	upgrades.clear()
	save_()
