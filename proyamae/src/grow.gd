extends Node
# 푸야매 — 카드 성장(스킬블록 · 구종). 오토로드(`Gr`)입니다.
#
# **출전 경기 수 하나로 둘 다 굴립니다**(`Sv.games`). 스킬 칸이 열리는 것도
# 구종 등급이 오르는 것도 같은 값을 보므로, "이 카드를 계속 쓰면 자란다"가
# 한 줄로 읽힙니다. 성장 축을 둘로 나누면 어느 쪽을 키우는 중인지 모르게 됩니다.
#
# **스킬 목록과 구종은 카드마다 고정이고 저장하지 않습니다.** 카드 id 를 씨앗으로
# 그때그때 다시 만듭니다 — 1만 장 분량을 세이브에 넣을 이유가 없고, 같은 카드는
# 언제 봐도 같은 스킬·구종이어야 합니다.

# ── 스킬블록 ───────────────────────────────────────────────────────────────
# **뽑아서 얻고, 카드 뒷면 4×4 판에 끼우는 물건입니다**(원작이 그렇습니다).
# 카드가 스킬을 타고나는 것이 아니라, 블록을 모아서 원하는 카드에 붙입니다.
#
# 칸은 처음에 네 개만 열려 있고 출전할수록 늘어납니다.
# **EX 카드는 처음부터 열여섯 칸이 전부 열려 있습니다.**
const GRID := 4
const CELLS := 16

# 칸이 열리는 차례 — 가운데 2×2 부터 바깥으로 퍼집니다. 격자 번호는 `y*4+x`.
const UNLOCK_ORDER := [5, 6, 9, 10, 4, 7, 8, 11, 1, 2, 13, 14, 0, 3, 12, 15]
# 그 칸이 열리는 데 필요한 출전 경기 수.
const UNLOCK_AT := [0, 0, 0, 0, 8, 8, 16, 16, 26, 26, 38, 38, 52, 68, 86, 110]

# **블록은 전부 네 칸짜리입니다** — 테트로미노 일곱 가지 그대로.
# 크기를 섞으면 "작은 블록을 여러 개" 와 "큰 블록 하나" 중 언제나 전자가
# 유리해서(칸당 값이 같으므로) 모양 맞추기가 아니라 개수 세기가 됩니다.
# 넷으로 통일하면 16칸에 정확히 네 개, **판이 딱 떨어지느냐**가 문제가 됩니다.
const SHAPE_CELLS := 4
# **네 가지뿐입니다 — ㅁ · l · ㄱ · ㄴ.** 예전에는 테트로미노 일곱 가지였는데
# S·Z·T 가 4×4 판에서 유독 안 맞아서, 좋은 블록을 뽑고도 못 끼우는 일이 잦았습니다.
#
# `l`(세로 막대)과 `ㅡ`(가로 막대)는 **같은 조각을 돌린 것**이라 한 종류입니다
# (가운데 버튼으로 돌립니다). 반면 `ㄱ`과 `ㄴ`은 거울상이라 회전으로는 서로
# 바뀌지 않으므로 **다른 종류**입니다.
const SHAPES := {
	"ㅁ": [[0, 0], [1, 0], [0, 1], [1, 1]],
	"l": [[0, 0], [1, 0], [2, 0], [3, 0]],
	"ㄱ": [[0, 0], [1, 0], [2, 0], [2, 1]],
	"ㄴ": [[0, 0], [0, 1], [1, 1], [2, 1]],
}
# 모양마다 놓기 쉬운 정도가 다릅니다. **ㅁ 이 제일 쉽고 꺾인 것이 어렵습니다** —
# 어려운 모양일수록 값이 커야 뽑았을 때 손해로 느껴지지 않습니다.
const SHAPE_MUL := {"ㅁ": 1.00, "l": 1.08, "ㄱ": 1.18, "ㄴ": 1.18}

# 블록 뽑기 — 값은 코인입니다(선수 뽑기와 같은 재화).
# **선수 팩보다 싸게 두세요.** 같은 재화로 두 가지를 사므로, 블록이 비싸면
# 아무도 안 뽑고 싸면 선수 팩을 안 뽑습니다 — 블록 하나가 스텟 +7 안팎이라
# 카드 한 장보다는 확실히 가벼운 값이어야 합니다.
const DRAW_COST := 300
const DRAW_SIZE := 3

# 스킬 종류. `up` 은 **모양 배수를 곱하기 전** 기준값입니다.
# `kind` 는 그 블록을 끼울 수 있는 카드 종류입니다.
# **값은 예전의 절반입니다.** 판이 꽉 차면 블록 넷이 붙는데, 예전 값이면 그것만으로
# 스텟이 30 가까이 올라 유학·팀컬러와 합쳐 카드 자체의 세기를 덮었습니다.
# 홀수는 내림으로 잘랐습니다(7 → 3).
const SKILLS := [
	{"id": "eye", "name": "선구안", "kind": "hitter", "up": {"contact": 3}},
	{"id": "pull", "name": "당겨치기", "kind": "hitter", "up": {"power": 3}},
	{"id": "gap", "name": "밀어치기", "kind": "hitter", "up": {"contact": 2, "power": 1}},
	{"id": "dash", "name": "주루 센스", "kind": "hitter", "up": {"speed": 3}},
	{"id": "slide", "name": "슬라이딩", "kind": "hitter", "up": {"speed": 2, "bunt": 1}},
	{"id": "catch", "name": "나이스 캐치", "kind": "hitter", "up": {"defense": 3}},
	{"id": "toss", "name": "백 토스", "kind": "hitter", "up": {"defense": 2, "mental": 1}},
	{"id": "clutch", "name": "집중력", "kind": "hitter", "up": {"mental": 3, "contact": 1}},
	{"id": "sac", "name": "희생 번트", "kind": "hitter", "up": {"bunt": 4}},

	{"id": "grip", "name": "그립 연습", "kind": "pitcher", "up": {"breaking": 3}},
	{"id": "hone", "name": "변화구 연마", "kind": "pitcher", "up": {"breaking": 2, "stuff": 1}},
	{"id": "aim", "name": "제구 훈련", "kind": "pitcher", "up": {"control": 3}},
	{"id": "heat", "name": "강속구", "kind": "pitcher", "up": {"velo": 3}},
	{"id": "heavy", "name": "묵직한 공", "kind": "pitcher", "up": {"stuff": 3}},
	{"id": "stam", "name": "지구력", "kind": "pitcher", "up": {"stamina": 4}},
	{"id": "cool", "name": "긁히는 날", "kind": "pitcher", "up": {"mental": 3, "control": 1}},
	{"id": "quick", "name": "퀵 모션", "kind": "pitcher", "up": {"control": 2, "stuff": 1}},
]
# ── 구종 ───────────────────────────────────────────────────────────────────
# 직구는 누구나 갖고, 나머지는 카드마다 다릅니다.
# **등급은 출전으로 오릅니다** — 기본 등급에서 시작해 경기 수만큼 올라갑니다.
const PITCH_GRADES := ["D", "C", "B", "A", "S"]
const PITCH_UP_GAMES := [0, 15, 40, 80, 140]   # 몇 경기에 한 단계씩 오르는가

const PITCHES := [
	{"id": "four", "name": "포심", "stat": "velo"},
	{"id": "two", "name": "투심", "stat": "stuff"},
	{"id": "slider", "name": "슬라이더", "stat": "breaking"},
	{"id": "curve", "name": "커브", "stat": "breaking"},
	{"id": "change", "name": "체인지업", "stat": "control"},
	{"id": "fork", "name": "포크", "stat": "stuff"},
	{"id": "sinker", "name": "싱커", "stat": "control"},
	{"id": "cutter", "name": "커터", "stat": "breaking"},
]

# 구종 등급이 붙여 주는 값. 등급이 오르면 구위·변화구가 같이 오릅니다.
const PITCH_BONUS := [0, 1, 3, 5, 8]

# ── 공통 ───────────────────────────────────────────────────────────────────

func games(id: String) -> int:
	return int(Sv.games.get(id, 0))

func _seed(id: String) -> int:
	return abs(id.hash())

func _st(c: Dictionary, k: String) -> int:
	return int((c.get("st", {}) as Dictionary).get(k, 50))

# ── 스킬블록 ───────────────────────────────────────────────────────────────

func open_cells(c: Dictionary) -> Array:
	# 열린 칸 번호 목록(0~15). EX 는 처음부터 열여섯 칸 전부입니다.
	if str(c.get("grade", "")) == D.GRADE_EX:
		return UNLOCK_ORDER.duplicate()
	var g := games(DB.card_id(c))
	var out: Array = []
	for i in range(CELLS):
		if g >= int(UNLOCK_AT[i]):
			out.append(int(UNLOCK_ORDER[i]))
	return out

func next_cell_at(c: Dictionary) -> int:
	# 다음 칸이 열리는 경기 수. 다 열렸으면 -1.
	if str(c.get("grade", "")) == D.GRADE_EX:
		return -1
	var g := games(DB.card_id(c))
	for i in range(CELLS):
		if g < int(UNLOCK_AT[i]):
			return int(UNLOCK_AT[i])
	return -1

func skill(sid: String) -> Dictionary:
	for s in SKILLS:
		if str(s["id"]) == sid:
			return s
	return {}

func shape_cells(shape: String, rot: int) -> Array:
	# 그 모양을 rot 번 돌린 [x, y] 목록. 돌린 뒤에는 왼쪽 위로 당겨 놓습니다.
	var cur: Array = SHAPES.get(shape, SHAPES["ㅁ"])
	for _i in range(posmod(rot, 4)):
		var nx: Array = []
		var mx := 0
		for p in cur:
			mx = maxi(mx, int(p[1]))
		for p in cur:
			nx.append([mx - int(p[1]), int(p[0])])
		cur = nx
	return cur

# ── 블록 보유 ──────────────────────────────────────────────────────────────

func block(uid: int) -> Dictionary:
	for b in Sv.blocks:
		if int(b.get("uid", 0)) == uid:
			return b
	return {}

func block_value(b: Dictionary) -> Dictionary:
	# 그 블록이 실제로 올려 주는 값. **모양이 어려울수록 큽니다.**
	var s := skill(str(b.get("sid", "")))
	if s.is_empty():
		return {}
	var mul: float = SHAPE_MUL.get(str(b.get("shape", "ㅁ")), 1.0)
	var out := {}
	for k in (s["up"] as Dictionary):
		out[k] = maxi(1, int(round(float(s["up"][k]) * mul)))
	return out

func block_name(b: Dictionary) -> String:
	var s := skill(str(b.get("sid", "")))
	return "%s·%s형" % [str(s.get("name", "?")), str(b.get("shape", "ㅁ"))]

func draw_blocks(n: int) -> Array:
	# 블록 뽑기. 돌려주는 것은 새로 얻은 블록들입니다.
	var got: Array = []
	for _i in range(n):
		var s: Dictionary = SKILLS[randi() % SKILLS.size()]
		var shapes: Array = SHAPES.keys()
		var b := {"uid": Sv.block_uid, "sid": str(s["id"]),
			"shape": str(shapes[randi() % shapes.size()]), "rot": 0}
		Sv.block_uid += 1
		Sv.blocks.append(b)
		got.append(b)
	Sv.save_game()
	return got

func free_blocks(kind: String) -> Array:
	# 아직 아무 카드에도 안 낀 블록 중 그 종류에 맞는 것.
	var used := {}
	for cid in Sv.block_at:
		for u in (Sv.block_at[cid] as Dictionary):
			used[int(u)] = true
	var out: Array = []
	for b in Sv.blocks:
		if used.has(int(b.get("uid", 0))):
			continue
		if str(skill(str(b.get("sid", ""))).get("kind", "")) != kind:
			continue
		out.append(b)
	return out

func card_of_block(uid: int) -> String:
	for cid in Sv.block_at:
		if (Sv.block_at[cid] as Dictionary).has(str(uid)):
			return str(cid)
	return ""

# ── 판에 끼우기 ────────────────────────────────────────────────────────────

func placed(id: String) -> Dictionary:
	# {uid(int) → 왼쪽 위 칸 번호}
	var v = Sv.block_at.get(id, {})
	var out := {}
	if typeof(v) == TYPE_DICTIONARY:
		for u in v:
			out[int(u)] = int(v[u])
	return out

func board(c: Dictionary) -> Dictionary:
	# 판의 현재 모습. {"cell": {칸 → uid}, "uids": [놓인 순서]}
	var id := DB.card_id(c)
	var cell := {}
	var uids: Array = []
	for uid in placed(id):
		var b := block(int(uid))
		if b.is_empty():
			continue
		for k in cells_of(b, int(placed(id)[uid])):
			cell[k] = int(uid)
		uids.append(int(uid))
	return {"cell": cell, "uids": uids}

func cells_of(b: Dictionary, origin: int) -> Array:
	# 그 블록을 origin 칸(왼쪽 위)에 놓았을 때 덮는 칸 번호들.
	# 판 밖으로 나가면 **빈 배열**을 돌려줍니다 — 부르는 쪽이 그걸로 판정합니다.
	var ox := origin % GRID
	var oy := origin / GRID
	var out: Array = []
	for p in shape_cells(str(b.get("shape", "ㅁ")), int(b.get("rot", 0))):
		var x := ox + int(p[0])
		var y := oy + int(p[1])
		if x < 0 or x >= GRID or y < 0 or y >= GRID:
			return []
		out.append(y * GRID + x)
	return out

func can_put(c: Dictionary, uid: int, origin: int) -> String:
	# 빈 문자열이면 놓을 수 있습니다. 아니면 안 되는 이유.
	var b := block(uid)
	if b.is_empty():
		return "없는 블록입니다"
	var kind := "pitcher" if str(c.get("kind", "")) == "pitcher" else "hitter"
	if str(skill(str(b.get("sid", ""))).get("kind", "")) != kind:
		return "야수 블록은 투수에 못 낍니다" if kind == "pitcher" else "투수 블록은 야수에 못 낍니다"
	var at := cells_of(b, origin)
	if at.is_empty():
		return "판 밖으로 나갑니다"
	var open: Array = open_cells(c)
	var bd := board(c)
	var cell: Dictionary = bd["cell"]
	for k in at:
		if not open.has(int(k)):
			return "아직 안 열린 칸입니다"
		if cell.has(int(k)) and int(cell[int(k)]) != uid:
			return "다른 블록이 있습니다"
	# 다른 카드에 끼워져 있으면 거기서 빼고 옮깁니다.
	return ""

func put(c: Dictionary, uid: int, origin: int) -> String:
	var err := can_put(c, uid, origin)
	if err != "":
		return err
	take(uid)   # 어디에 있었든 먼저 뺍니다
	var id := DB.card_id(c)
	var cur: Dictionary = Sv.block_at.get(id, {})
	cur[str(uid)] = origin
	Sv.block_at[id] = cur
	DB.clear_cache()
	Sv.save_game()
	return ""

func take(uid: int) -> void:
	for cid in Sv.block_at.keys():
		var m: Dictionary = Sv.block_at[cid]
		if m.has(str(uid)):
			m.erase(str(uid))
			if m.is_empty():
				Sv.block_at.erase(cid)
			else:
				Sv.block_at[cid] = m
	DB.clear_cache()
	Sv.save_game()

func rotate_block(uid: int) -> void:
	var b := block(uid)
	if b.is_empty():
		return
	# 판에 놓여 있으면 돌린 뒤에도 들어가는지 봅니다. 안 들어가면 그대로 둡니다.
	var cid := card_of_block(uid)
	var old := int(b.get("rot", 0))
	b["rot"] = posmod(old + 1, 4)
	if cid != "":
		var c := DB.find(cid)
		var origin := int(placed(cid).get(uid, 0))
		take(uid)
		if put(c, uid, origin) != "":
			b["rot"] = old
			put(c, uid, origin)
			Sv.save_game()
			return
	Sv.save_game()

func auto_fill(c: Dictionary) -> int:
	# 남은 블록을 들어가는 자리에 알아서 채웁니다. 판이 넓어졌을 때 하나씩
	# 끌어다 놓는 것이 일이라 손으로 하는 길과 **나란히** 둡니다.
	var kind := "pitcher" if str(c.get("kind", "")) == "pitcher" else "hitter"
	var n := 0
	for b in free_blocks(kind):
		var uid := int(b["uid"])
		var done := false
		for r in range(4):
			for o in range(CELLS):
				if can_put(c, uid, o) == "":
					put(c, uid, o)
					done = true
					break
			if done:
				break
			rotate_block(uid)
		if done:
			n += 1
	return n

func clear_board(c: Dictionary) -> void:
	var id := DB.card_id(c)
	Sv.block_at.erase(id)
	DB.clear_cache()
	Sv.save_game()

func skill_bonus(id: String) -> Dictionary:
	# 판에 낀 블록들의 상승치 합. **COST 는 안 건드립니다.**
	var out := {}
	for uid in placed(id):
		var b := block(int(uid))
		if b.is_empty():
			continue
		for k in block_value(b):
			out[k] = int(out.get(k, 0)) + int(block_value(b)[k])
	return out

# ── 구종 ───────────────────────────────────────────────────────────────────

func pitches_of(c: Dictionary) -> Array:
	# [{id, name, stat, grade}] — 포심은 항상 있고 나머지는 카드마다 다릅니다.
	if str(c.get("kind", "")) != "pitcher":
		return []
	var id := DB.card_id(c)
	var sd := _seed(id)
	var rest: Array = []
	for p in PITCHES:
		if str(p["id"]) == "four":
			continue
		rest.append(p)
	rest.sort_custom(func(a, b):
		return ((str(a["id"]).hash() ^ sd) & 0xffff) < ((str(b["id"]).hash() ^ sd) & 0xffff))
	# 변화구가 좋은 투수일수록 구종이 많습니다.
	var n := 1 + int(clampf((_st(c, "breaking") - 40.0) / 15.0, 1.0, 4.0))
	var out: Array = [PITCHES[0]]
	out.append_array(rest.slice(0, n - 1))
	var g := games(id)
	var res: Array = []
	for i in range(out.size()):
		var p: Dictionary = out[i]
		res.append({"id": p["id"], "name": p["name"], "stat": p["stat"],
			"grade": _pitch_grade(c, str(p["stat"]), i, g)})
	return res

func _pitch_grade(c: Dictionary, stat: String, idx: int, g: int) -> int:
	# 기본 등급은 그 구종이 기대는 스텟에서, 거기에 출전 수만큼 올라갑니다.
	# 주무기(첫 구종)가 한 단계 높게 시작합니다.
	var base := 0
	var v := _st(c, stat)
	if v >= 78:
		base = 2
	elif v >= 64:
		base = 1
	if idx == 0:
		base += 1
	var up := 0
	for need in PITCH_UP_GAMES:
		if g >= int(need):
			up += 1
	return clampi(base + up - 1, 0, PITCH_GRADES.size() - 1)

func pitch_grade_name(g: int) -> String:
	return str(PITCH_GRADES[clampi(g, 0, PITCH_GRADES.size() - 1)])

func pitch_bonus(c: Dictionary) -> Dictionary:
	# 구종 등급이 구위·변화구에 붙여 주는 값. 등급 합의 평균으로 냅니다 —
	# 구종 수가 많다고 그냥 세지면 변화구 높은 카드가 두 번 이득을 봅니다.
	var ps := pitches_of(c)
	if ps.is_empty():
		return {}
	var s := 0
	for p in ps:
		s += int(PITCH_BONUS[clampi(int(p["grade"]), 0, PITCH_BONUS.size() - 1)])
	@warning_ignore("integer_division")
	var avg := s / ps.size()
	if avg <= 0:
		return {}
	return {"stuff": avg, "breaking": avg}

# ── 출전 기록 ──────────────────────────────────────────────────────────────

func note_game(t: Dictionary) -> void:
	# 경기 하나가 끝나면 **그 경기에 나온 카드들**의 출전 수를 올립니다.
	# 벤치는 안 셉니다 — 앉아 있던 카드가 자라면 스킬 칸이 그냥 시간 보상이 됩니다.
	var seen := {}
	for c in Sim._members(t):
		var id := DB.card_id(c)
		if seen.has(id):
			continue
		seen[id] = true
		Sv.games[id] = games(id) + 1
	DB.clear_cache()
