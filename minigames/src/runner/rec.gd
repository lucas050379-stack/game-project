class_name WrRec
extends RefCounted

## 월드 러너 기록 — `user://runner.cfg`(테스트 빌드는 `runner_test.cfg`). 처음 화면 "순위" 창이 보여 준다(사용자 요청 11-08).
## 사람이 끼어 있는 판만 센다. **확인용 실행(명령줄 인자가 있는 실행)은 쓰지 않는다.** 읽기 · 쓰기가 실패해도 게임은 돈다.

static var plays := 0
static var wins := 0
static var best_worth := 0      ## 끝날 때 가장 높았던 내 총자산
static var fastest := 0         ## 가장 빨리 이긴 라운드(0 = 아직)
static var loaded := false


static func _path() -> String:
	return "user://runner_test.cfg" if OS.has_feature("testbuild") else "user://runner.cfg"


static func load_() -> void:
	if loaded:
		return
	loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(_path()) != OK:
		return
	plays = int(cfg.get_value("rec", "plays", 0))
	wins = int(cfg.get_value("rec", "wins", 0))
	best_worth = int(cfg.get_value("rec", "best_worth", 0))
	fastest = int(cfg.get_value("rec", "fastest", 0))


static func add(won: bool, worth: int, round_no: int) -> void:
	load_()
	plays += 1
	if won:
		wins += 1
		if fastest == 0 or round_no < fastest:
			fastest = round_no
	best_worth = maxi(best_worth, worth)
	var cfg := ConfigFile.new()
	cfg.set_value("rec", "plays", plays)
	cfg.set_value("rec", "wins", wins)
	cfg.set_value("rec", "best_worth", best_worth)
	cfg.set_value("rec", "fastest", fastest)
	cfg.save(_path())
