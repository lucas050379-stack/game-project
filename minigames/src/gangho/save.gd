class_name GhSv
extends RefCounted

## 강호일생 기록 — 지난 인생들과 모은 칭호. `user://gangho.cfg` 하나(테스트 빌드는 `gangho_test.cfg`).
## 젤리팝의 Sv 와 파일을 나눴다 — 한 파일에 섞으면 한쪽 형식을 바꿀 때 다른 쪽 기록이 같이 날아간다.
## **읽기 · 쓰기가 실패해도 게임은 빈 기록으로 돈다.**

const KEEP := 40

static var lives: Array = []      ## 최근 것부터 {name, cls, region, sex, age, year, title, realm, cause, one_in}
static var titles := {}           ## 칭호 → 받은 횟수
static var births := 0
static var best_realm := 0
static var born := {}            ## 출생 도감 — 집안 열쇠(cls 또는 세가 id) → {n, best(가세), heir(장자로 난 적)}
static var hall := {}             ## 명예의 전당 — 갈래 → [{v, name, house, title}, ...] 위에서 다섯
static var tips := {}             ## 처음 하는 사람 안내 — 본 것
const HALL_N := 5
static var loaded := false


static func _path() -> String:
	return "user://gangho_test.cfg" if OS.has_feature("testbuild") else "user://gangho.cfg"


static func load_() -> void:
	if loaded:
		return
	loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(_path()) != OK:
		return
	var l = cfg.get_value("rec", "lives", [])
	lives = l if l is Array else []
	var t = cfg.get_value("rec", "titles", {})
	titles = t if t is Dictionary else {}
	births = int(cfg.get_value("rec", "births", 0))
	best_realm = int(cfg.get_value("rec", "best_realm", 0))
	var b = cfg.get_value("rec", "born", {})
	born = b if b is Dictionary else {}
	var h = cfg.get_value("rec", "hall", {})
	hall = h if h is Dictionary else {}
	var tp = cfg.get_value("rec", "tips", {})
	tips = tp if tp is Dictionary else {}


static func save_() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("rec", "lives", lives)
	cfg.set_value("rec", "titles", titles)
	cfg.set_value("rec", "births", births)
	cfg.set_value("rec", "best_realm", best_realm)
	cfg.set_value("rec", "born", born)
	cfg.set_value("rec", "hall", hall)
	cfg.set_value("rec", "tips", tips)
	cfg.save(_path())


## 한 인생이 끝났을 때. 처음 받은 칭호면 true.
static func add(l: GhLife, persist: bool = true) -> bool:
	var t := l.title()
	var fresh := not titles.has(t)
	titles[t] = int(titles.get(t, 0)) + 1
	births += 1
	best_realm = maxi(best_realm, l.realm)
	lives.push_front({name = l.name, cls = l.house_name(), region = l.region_name(), sex = l.sex, label = l.child_label(), age = l.age,
			year = l.birth_year, title = t, realm = l.realm, cause = l.cause, one_in = l.one_in()})
	# 출생 도감
	var bk := l.clan_id if l.cls == "clan" else l.cls
	var e: Dictionary = born.get(bk, {n = 0, best = 0, heir = false})
	e.n = int(e.n) + 1
	e.best = maxi(int(e.best), l.wealth)
	e.heir = bool(e.heir) or l.heir
	born[bk] = e
	# 명예의 전당
	var me := {name = l.display_name(), house = "%s %s" % [l.region_name(), l.house_name()], title = t}
	_hall("realm", l.realm * 10000 + int(l.xp), me, l.realm_name() if l.martial else "")
	_hall("wealth", l.gold + l.assets_value(), me, "%d냥" % (l.gold + l.assets_value()))
	_hall("age", l.age, me, "향년 %d세" % l.age)
	_hall("fame", l.fame, me, "명성 %d" % l.fame)
	if lives.size() > KEEP:
		lives.resize(KEEP)
	if persist:
		save_()
	return fresh


static func _hall(k: String, v: int, who: Dictionary, label: String) -> void:
	if label == "" or v <= 0:
		return
	var arr: Array = hall.get(k, [])
	var e := who.duplicate()
	e["v"] = v
	e["label"] = label
	arr.append(e)
	arr.sort_custom(func(a, b): return int(a.v) > int(b.v))
	if arr.size() > HALL_N:
		arr.resize(HALL_N)
	hall[k] = arr


## 처음 하는 사람 안내 — 한 번 본 것은 다시 안 띄운다. 처음 보면 true.
static func tip(id: String) -> bool:
	if tips.has(id):
		return false
	tips[id] = true
	save_()
	return true
