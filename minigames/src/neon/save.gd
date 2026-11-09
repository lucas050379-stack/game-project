class_name NvSv
extends RefCounted

## 판이 끝나도 남는 것 — 코인, 코인으로 산 기본 스텟 강화, 최고 라운드.
##
## `user://save.cfg` 한 파일에 넣는다. 이건 **배포 리소스가 아니라 플레이어가 만드는 기록**이라
## "리소스 0개 · 단일 exe" 원칙과 어긋나지 않는다 — exe 는 그대로 하나고, 저장 파일은
## 처음 실행할 때 사용자 폴더에 생긴다. 없으면 전부 0 으로 시작한다.
##
## 실패해도 게임은 돌아야 한다. 읽기/쓰기 오류는 조용히 무시하고 기본값을 쓴다.

const PATH := "user://neon.cfg"   # 젤리팝 save.cfg 와 겹치지 않게(미니게임 모음, 11-09)
const PATH_TEST := "user://neon_test.cfg"


static func _path() -> String:
	return PATH_TEST if OS.has_feature("testbuild") else PATH

static var coins := 0
static var best_round := 1
## 상점 항목 번호 -> 산 레벨
static var upgrades := {}

## 캐릭터 해금 조건이 보는 누적 기록. **한 번 올라가면 안 내려간다** —
## 해금은 되돌아가면 안 되기 때문이다(`NvD.char_locked`).
static var total_kills := 0
static var total_coins := 0
## 한 판에 진화시킨 최고 개수
static var best_evo := 0

## 고른 난이도([D].DIFFICULTY 색인). **아무 때나 바꿀 수 있다** — 잠금도 조건도 없다.
static var difficulty := NvD.DIFF_DEFAULT

static var _loaded := false


static func load_() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(_path()) != OK:
		return
	coins = int(cfg.get_value("player", "coins", 0))
	best_round = maxi(1, int(cfg.get_value("player", "best_round", 1)))
	total_kills = int(cfg.get_value("player", "total_kills", 0))
	total_coins = int(cfg.get_value("player", "total_coins", 0))
	best_evo = int(cfg.get_value("player", "best_evo", 0))
	difficulty = clampi(int(cfg.get_value("player", "difficulty", NvD.DIFF_DEFAULT)),
		0, NvD.DIFFICULTY.size() - 1)
	for i in NvD.SHOP.size():
		var lv := int(cfg.get_value("upgrade", String(NvD.SHOP[i]["kind"]), 0))
		upgrades[i] = clampi(lv, 0, int(NvD.SHOP[i]["max"]))


## 확인용 실행(명령줄 인자)은 기록하지 않는다(ADR-0009). main._ready 가 정한다.
static var no_save := false


static func save_() -> void:
	if no_save:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("player", "coins", coins)
	cfg.set_value("player", "best_round", best_round)
	cfg.set_value("player", "total_kills", total_kills)
	cfg.set_value("player", "total_coins", total_coins)
	cfg.set_value("player", "best_evo", best_evo)
	cfg.set_value("player", "difficulty", difficulty)
	for i in NvD.SHOP.size():
		cfg.set_value("upgrade", String(NvD.SHOP[i]["kind"]), level(i))
	cfg.save(_path())


## 누적 기록 갱신 — 해금 조건이 이걸 본다. 라운드가 끝날 때 한 번만 부른다
## (매 처치마다 저장하면 초당 수백 번 파일을 쓴다).
static func record(kills: int, evo: int) -> void:
	total_kills += maxi(0, kills)
	best_evo = maxi(best_evo, evo)
	save_()


static func level(idx: int) -> int:
	return int(upgrades.get(idx, 0))


## 강화 종류 kind 가 쌓아 준 값 (레벨 × 레벨당 값)
static func bonus(kind: String) -> float:
	for i in NvD.SHOP.size():
		if String(NvD.SHOP[i]["kind"]) == kind:
			return level(i) * float(NvD.SHOP[i]["val"])
	return 0.0


static func maxed(idx: int) -> bool:
	return level(idx) >= int(NvD.SHOP[idx]["max"])


static func cost(idx: int) -> int:
	return NvD.shop_cost(idx, level(idx))


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
	total_coins += maxi(0, n)
	save_()


## 판 안에서 주운 동전. **저장하지 않는다** — 초당 여러 번 들어오므로 파일을 쓸 수 없다.
## 라운드가 끝날 때 `add_coins` 가 한 번에 저장한다.
static func pick_coins(n: int) -> void:
	coins += n
	total_coins += maxi(0, n)


static func reach(round_no: int) -> void:
	if round_no > best_round:
		best_round = round_no
		save_()


## 개발/테스트용 — 기록을 통째로 지운다. 어디서도 부르지 않는다.
static func wipe() -> void:
	coins = 0
	best_round = 1
	total_kills = 0
	total_coins = 0
	best_evo = 0
	difficulty = NvD.DIFF_DEFAULT
	upgrades.clear()
	save_()


## 판당 몇 번 쓸 수 있는가 (`reroll`·`skip`·`banish`). 기본값 + 산 단계.
static func uses(kind: String, base: int) -> int:
	return base + int(round(bonus(kind)))
