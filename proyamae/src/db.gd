extends Node
# 푸야매 — 카드 자료. 오토로드(`DB`)입니다.
#
# `data/players/<연도>.json` 을 **실행 중에** 읽습니다. 시즌을 더 넣는다고
# 다시 빌드하지 않습니다(비트폴이 `songs/` 를 읽는 방식과 같습니다).
# 빌드된 exe 옆의 `data/players/` 를 먼저 보고, 없으면 프로젝트 안을 봅니다.

var cards: Array = []          # 모든 카드
var by_year: Dictionary = {}   # 연도 → 카드 배열
var years: Array = []          # 있는 연도, 오름차순
var load_note := ""            # 화면에 띄울 한 줄 (자료가 없을 때)

func _ready() -> void:
	_load_all()

func _dirs() -> Array:
	var out: Array = []
	var exe := OS.get_executable_path().get_base_dir()
	out.append(exe.path_join("data/players"))
	out.append("res://data/players")
	return out

func _load_all() -> void:
	cards.clear()
	by_year.clear()
	years.clear()
	for d in _dirs():
		var dir := DirAccess.open(d)
		if dir == null:
			continue
		for fn in dir.get_files():
			if not fn.ends_with(".json"):
				continue
			_load_file(d.path_join(fn))
		if not cards.is_empty():
			break   # 먼저 찾은 폴더만 씁니다. 둘을 섞으면 카드가 두 벌이 됩니다.
	_build_index()
	years = by_year.keys()
	years.sort()
	if cards.is_empty():
		load_note = "선수 자료가 없습니다. fetch.bat 으로 받고 convert.bat 으로 변환하세요."

func _load_file(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY or not d.has("cards"):
		return
	var y := int(d.get("year", 0))
	var list: Array = []
	for c in d["cards"]:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		cards.append(c)
		list.append(c)
	if not list.is_empty():
		by_year[y] = list

# ── 뽑기 ───────────────────────────────────────────────────────────────────

func draw_one(rng: RandomNumberGenerator) -> Dictionary:
	# **종합(OV) 구간을 먼저 굴리고 그 구간 안에서 하나를 고릅니다.**
	# 카드 전체에서 균등하게 뽑으면 8천 장 중 아무거나가 되어 확률표가 뜻이
	# 없어집니다. 등급이 EX·NORMAL 둘뿐이라 등급으로 뽑을 수도 없습니다.
	if cards.is_empty():
		return {}
	var roll := rng.randf()
	var acc := 0.0
	var lo := 0
	var hi := 200
	for i in range(D.PACK_ODDS.size()):
		acc += float(D.PACK_ODDS[i][1])
		if roll <= acc:
			lo = int(D.PACK_ODDS[i][0])
			hi = 200 if i == 0 else int(D.PACK_ODDS[i - 1][0])
			break
	var pool := of_band(lo, hi)
	if pool.is_empty():
		pool = cards
	return pool[rng.randi_range(0, pool.size() - 1)]

var _band_cache: Dictionary = {}

func of_band(lo: int, hi: int) -> Array:
	# lo 이상 hi 미만.
	var key := "%d_%d" % [lo, hi]
	if _band_cache.has(key):
		return _band_cache[key]
	var out: Array = []
	for c in cards:
		var ov := int(c.get("ov", 0))
		if ov >= lo and ov < hi:
			out.append(c)
	_band_cache[key] = out
	return out

# ── 카드 식별 ──────────────────────────────────────────────────────────────

func card_id(c: Dictionary) -> String:
	# 같은 선수라도 시즌이 다르면 다른 카드입니다.
	return "%s|%s|%d|%s" % [c.get("name", ""), c.get("team", ""), int(c.get("year", 0)), c.get("kind", "")]

var _index: Dictionary = {}     # id → 원본 카드
var _grown: Dictionary = {}     # id → 유학 보너스가 붙은 사본

func _build_index() -> void:
	_index.clear()
	for c in cards:
		_index[card_id(c)] = c

func clear_cache() -> void:
	# 유학이 끝나거나 새로 보내면 부릅니다.
	_grown.clear()

func base(id: String) -> Dictionary:
	# 유학 보너스가 **없는** 원본. 강화 화면에서 "지금 → 다녀온 뒤"를 보여줄 때 씁니다.
	return _index.get(id, {})

func find(id: String) -> Dictionary:
	# **선형 탐색을 하지 마세요.** 카드가 1만 장이고 `total_cost()` 하나가
	# 이걸 25번 부릅니다 — 매 프레임 25만 번 비교하게 됩니다.
	var c: Dictionary = _index.get(id, {})
	if c.is_empty():
		return {}
	if _grown.has(id):
		return _grown[id]
	# 유학 · 장착 스킬 · 구종 등급이 다 여기서 얹힙니다. **셋 다 COST 는
	# 건드리지 않습니다** — COST 상한 안에서 팀을 키우는 것이 성장의 요점입니다.
	var up := Sv.study_bonus(id)
	for src in [Gr.skill_bonus(id), Gr.pitch_bonus(c)]:
		for k in (src as Dictionary):
			up[k] = int(up.get(k, 0)) + int(src[k])
	if up.is_empty():
		return c
	# **원본을 고치지 마세요.** `cards` 는 모두가 나눠 보는 배열이라, 한 번 고치면
	# 도감·뽑기·상대 팀에까지 보너스가 번집니다. 사본을 만들어 캐시합니다.
	var g := c.duplicate(true)
	var st: Dictionary = g["st"]
	# **실제로 오른 만큼만 적어 둡니다.** 99 에서 잘린 몫까지 "+N" 이라고 쓰면
	# 카드에 적힌 숫자와 안 맞아서, 보너스가 거짓말이 됩니다.
	var got := {}
	for k in up:
		if not st.has(k):
			continue
		var before := int(st[k])
		st[k] = clampi(before + int(up[k]), 1, D.STAT_MAX)
		if int(st[k]) != before:
			got[k] = int(st[k]) - before
	g["study"] = Sv.study_regions(id).size()
	# 화면이 "어디서 온 보너스인가"를 적을 수 있게 갈래별로도 남깁니다.
	g["up"] = got
	g["up_src"] = {"study": Sv.study_bonus(id), "block": Gr.skill_bonus(id),
		"pitch": Gr.pitch_bonus(c)}
	_grown[id] = g
	return g

func year_tag(c: Dictionary) -> String:
	# 카드에 찍히는 시즌 표기 — 2003 이면 `03'`.
	return "%02d'" % (int(c.get("year", 0)) % 100)
