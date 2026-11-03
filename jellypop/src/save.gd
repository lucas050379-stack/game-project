class_name Sv
extends RefCounted

## 기록 — 타임 어택 최고 점수, 스테이지마다 별 · 최고 점수.
## 웹에서는 `user://` 가 브라우저 IndexedDB 에 저장된다.
## **실패해도 게임은 돌아야 한다** — 사생활 보호 창에서는 저장이 막힐 수 있다.

const PATH := "user://save.cfg"
## 테스트 빌드는 세이브를 따로 쓴다 — 같은 주소에서 띄우면 브라우저 저장소를 같이 쓰므로,
## 테스트로 깬 기록이 정식 판으로 넘어가면 안 된다.
const PATH_TEST := "user://save_test.cfg"

## 테스트 빌드(`testbuild` 기능 태그) 또는 `--unlock` — 모든 스테이지가 열린다.
## **세이브에 쓰지 않고 `unlocked()` 의 대답만 바꾼다.**
static var all_open := false

## 지도 판본 — 스테이지 지도를 통째로 바꾸면 올린다. 다르면 스테이지 기록(별 · 점수)만 비운다.
## 판 번호가 같아도 지도가 다르면 예전 별이 남의 판에 붙어 있게 된다(손으로 짠 120판 → 생성기 200판).
## 타임 어택 최고 점수는 지도와 상관없으니 남긴다.
const MAP_VER := 2
## 타임 어택 판본 — 판 크기처럼 점수 크기가 바뀌는 것을 고치면 올린다. 다르면 최고 점수만 비운다
## (7×7 → 8×8 에서 점수가 크게 올라 예전 기록과 견줄 수 없었다). 서버(tools/rank.gs 의 TA_VER)도 같이 올린다.
const TA_VER := 2

static var best := 0
static var plays := 0
static var stars := {}     ## 스테이지 id → 별 (0~3)
static var scores := {}    ## 스테이지 id → 최고 점수
static var tries := {}     ## 스테이지 id → 시작한 횟수(기록 보내기에서 "몇 번 만에 깼나")
static var seen := {}      ## 새 장애물 안내를 이미 띄운 장애물 key → true

static var music := true
static var sfx := true

## 순위 · 플레이 기록(Net). uid 는 처음 켤 때 무작위로 만든다 — 계정이 아니라 기기 하나를 가리킨다.
static var uid := ""
static var name := ""
static var named := false        ## 이름을 직접 정했나 — 아니면 처음 켤 때 이름 화면부터
static var seq := 0              ## 보낸 사건 번호. 서버가 이걸로 같은 사건을 두 번 받지 않는다
static var pending: Array = []   ## 아직 못 보낸 사건


static func load_() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_path()) != OK:
		return
	best = maxi(0, int(cfg.get_value("player", "best", 0)))
	if int(cfg.get_value("player", "ta_ver", 1)) != TA_VER:
		best = 0
	plays = maxi(0, int(cfg.get_value("player", "plays", 0)))
	music = bool(cfg.get_value("opt", "music", true))
	sfx = bool(cfg.get_value("opt", "sfx", true))
	uid = String(cfg.get_value("net", "uid", ""))
	name = String(cfg.get_value("net", "name", ""))
	named = bool(cfg.get_value("net", "named", false))
	seq = maxi(0, int(cfg.get_value("net", "seq", 0)))
	var pend = cfg.get_value("net", "pending", [])
	pending = pend if pend is Array else []
	var sn = cfg.get_value("player", "seen", [])
	if sn is Array:
		for k in sn:
			seen[String(k)] = true
	if int(cfg.get_value("player", "maps", 1)) != MAP_VER:
		return
	if cfg.has_section("stage"):
		for k in cfg.get_section_keys("stage"):
			var v: Array = cfg.get_value("stage", k, [0, 0])
			stars[int(k)] = clampi(int(v[0]), 0, 3)
			scores[int(k)] = maxi(0, int(v[1]))
			if v.size() > 2:
				tries[int(k)] = maxi(0, int(v[2]))


static func save_() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "best", best)
	cfg.set_value("player", "ta_ver", TA_VER)
	cfg.set_value("player", "plays", plays)
	cfg.set_value("player", "maps", MAP_VER)
	cfg.set_value("player", "seen", seen.keys())
	cfg.set_value("opt", "music", music)
	cfg.set_value("opt", "sfx", sfx)
	cfg.set_value("net", "uid", uid)
	cfg.set_value("net", "name", name)
	cfg.set_value("net", "named", named)
	cfg.set_value("net", "seq", seq)
	cfg.set_value("net", "pending", pending)
	var ids := {}
	for id in stars:
		ids[id] = true
	for id in tries:
		ids[id] = true
	for id in ids:
		cfg.set_value("stage", str(id), [stars.get(id, 0), scores.get(id, 0), tries.get(id, 0)])
	cfg.save(_path())   # 실패해도 그냥 둔다


static func _path() -> String:
	return PATH_TEST if all_open else PATH


## 깼을 때만 부른다. 별과 점수는 각자 더 좋은 쪽을 남긴다.
static func record(id: int, st: int, score: int) -> void:
	stars[id] = maxi(int(stars.get(id, 0)), st)
	scores[id] = maxi(int(scores.get(id, 0)), score)
	save_()


## 열린 스테이지 수 — 깬 것 중 가장 뒤 + 1.
## 처음 켤 때 한 번. 이름은 정하기 전까지 uid 끝 네 자리로 부른다.
## 점수 기록을 모두 지운다 — 별 · 판 점수 · 시도 횟수 · 타임 어택 최고 · 새 장애물 안내.
## 이름 · 기기 번호 · 소리 설정은 남긴다. 테스트 빌드의 처음 화면 단추만 부른다.
static func wipe_records() -> void:
	stars.clear()
	scores.clear()
	tries.clear()
	seen.clear()
	best = 0
	plays = 0
	save_()


static func ensure_uid() -> void:
	if uid == "":
		uid = Crypto.new().generate_random_bytes(8).hex_encode()
		save_()
	if name == "":
		name = "젤리" + uid.right(4).to_upper()


static func total_stars() -> int:
	var n := 0
	for id in stars:
		n += int(stars[id])
	return n


## 모험 점수 — 판마다 최고 점수의 합. 순위의 "모험" 탭이 이걸로 줄 선다(별은 셋에서 멈춰 변별이 안 된다).
static func total_score() -> int:
	var n := 0
	for id in scores:
		n += int(scores[id])
	return n


static func cleared() -> int:
	var n := 0
	for id in stars:
		if int(stars[id]) > 0:
			n += 1
	return n


static func unlocked() -> int:
	if all_open:
		return 1 << 20
	var n := 1
	for id in stars:
		if int(stars[id]) > 0:
			n = maxi(n, int(id) + 1)
	return n
