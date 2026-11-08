class_name SaRec
extends RefCounted

## 스카이 어설트 최고 기록 — `user://sky.cfg`(테스트 빌드는 `sky_test.cfg`). 위에서 열 개.
## 처음 화면 오른쪽 "최고 기록" 판이 위 다섯을 보여 줍니다(사용자 요청 11-08 "점수 랭킹이랑 키 설명이 있으면").
## **확인용 실행(명령줄 인자가 있는 실행)은 쓰지 않습니다** — 자동 주행 점수가 기록을 더럽힌다. 읽기 · 쓰기가 실패해도 게임은 돈다.

const KEEP := 10

static var list: Array = []     ## [{score, craft, round, diff, clear}] 점수 높은 순
static var loaded := false


static func _path() -> String:
	return "user://sky_test.cfg" if OS.has_feature("testbuild") else "user://sky.cfg"


static func load_() -> void:
	if loaded:
		return
	loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(_path()) != OK:
		return
	var l = cfg.get_value("rec", "list", [])
	list = l if l is Array else []


## 한 판 기록을 넣는다. 몇 등에 들었는지(0 부터, 못 들면 -1).
static func add(score: int, craft: int, round_i: int, diff: int, clear: bool) -> int:
	load_()
	var e := {score = score, craft = craft, round = round_i, diff = diff, clear = clear}
	var at := list.size()
	for i in list.size():
		if score > int(list[i].score):
			at = i
			break
	if at >= KEEP:
		return -1
	list.insert(at, e)
	if list.size() > KEEP:
		list.resize(KEEP)
	var cfg := ConfigFile.new()
	cfg.set_value("rec", "list", list)
	cfg.save(_path())
	return at
