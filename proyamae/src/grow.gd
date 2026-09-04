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

# 칸이 열리는 차례는 **카드마다 다릅니다**(`unlock_order`). 시작 네 칸이 블록 모양
# 하나로 모서리에 붙고, 거기서 가까운 칸부터 퍼집니다. 격자 번호는 `y*4+x`.
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
	"ㄴ": [[0, 0], [0, 1], [1, 1], [2, 1]],
	# `___|` — ㄴ 의 거울상입니다. **회전으로는 서로 안 바뀌므로 다른 조각입니다.**
	# 예전에 있던 "ㄱ"은 ㄴ 을 180° 돌린 것이라 사실 같은 조각이었고,
	# 그래서 일곱 가지 중 이 거울상 하나가 통째로 빠져 있었습니다.
	"L": [[2, 0], [0, 1], [1, 1], [2, 1]],
	"ㅗ": [[0, 0], [1, 0], [2, 0], [1, 1]],
	"S": [[1, 0], [2, 0], [0, 1], [1, 1]],
	"Z": [[0, 0], [1, 0], [1, 1], [2, 1]],
}
# 모양마다 놓기 쉬운 정도가 다릅니다. **ㅁ 이 제일 쉽고 꺾인 것이 어렵습니다** —
# 어려운 모양일수록 값이 커야 뽑았을 때 손해로 느껴지지 않습니다.
const SHAPE_MUL := {"ㅁ": 1.00, "l": 1.08, "ㄴ": 1.18, "L": 1.18,
	"ㅗ": 1.24, "S": 1.32, "Z": 1.32}

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
# 구종 등급 — **내 스텟이 오르면 따라 올라갑니다.** 그 구종이 기대는 스텟
# (포심은 구속 · 슬라이더는 변화구 · 체인지업은 제구 …)의 **지금 값**이 곧 등급이라,
# 유학이나 스킬블록으로 그 칸을 올리면 B → A → S → SS 로 승급합니다.
#
# **출전 경기 수는 이제 안 봅니다.** 예전에는 경기 수로만 올랐는데, 그러면 카드를
# 키우는 것과 상관없이 시간만 흘리면 되는 축이 하나 더 생깁니다. 지금은 스텟 하나만
# 보므로 "무엇을 올리면 무엇이 승급하는가"가 화면에서 바로 읽힙니다.
#
# **등급은 스텟을 안 올립니다**(구종 보너스를 걷어냈습니다) — 어디까지 키웠는지
# 보여 주는 표시입니다.
const PITCH_GRADES := ["D", "C", "B", "A", "S", "SS"]
# **요구 스텟은 구종마다 다릅니다** — 표는 아래 `PITCHES` 의 `req` 칸에 있습니다.
# 계단이 12 안팎이라 블록 한 장(+3~4)으로는 대개 안 넘어갑니다. 그래서 화면에
# **다음 등급까지 얼마 남았는지**를 같이 적습니다(`pitch_next_at`).

# 실제 투구 종류 열두 가지. **포심은 누구나 던지므로 항상 첫 자리**이고,
# 나머지는 카드 id 를 씨앗으로 골라 옵니다.
#
# `stat` — 그 공이 기대는 칸. 빠른 공은 구속, 떨어지는 공은 구위,
#          휘는 공은 변화구, 느린 공은 제구입니다.
# `req`  — **등급별 요구 스텟표** `[D, C, B, A, S, SS]`.
#          그 칸이 이 값 이상이면 그 등급입니다.
#
# **재는 값은 작전에서 보이는 최종 스텟입니다** — 유학 · 스킬블록 · 팀컬러를
# 다 얹은 값. 셋 중 하나라도 빠뜨리면 "스텟은 올랐는데 구종은 그대로"가 됩니다.
#
# **SS 줄은 카드 자체의 상한(99)보다 높습니다.** 그래서 SS 는 성장을 실제로
# 부은 카드에서만 열립니다 — 뽑자마자 SS 인 카드는 없습니다.
#
# 던지기 어려운 공일수록 요구가 높습니다: 포심 < 투심·커터·체인지업 <
# 커브·슬라이더·포크·스플리터 < 슬러브·스크루·팜볼·서클.
const PITCHES := [
	{"id": "four", "name": "포심", "stat": "velo", "req": [0, 45, 58, 70, 82, 102]},
	{"id": "two", "name": "투심", "stat": "stuff", "req": [0, 48, 61, 73, 85, 105]},
	{"id": "cutter", "name": "커터", "stat": "breaking", "req": [0, 48, 61, 73, 85, 105]},
	{"id": "change", "name": "체인지업", "stat": "control", "req": [0, 48, 61, 73, 85, 105]},
	{"id": "split", "name": "스플리터", "stat": "stuff", "req": [0, 50, 63, 75, 87, 107]},
	{"id": "fork", "name": "포크", "stat": "stuff", "req": [0, 50, 63, 75, 87, 107]},
	{"id": "curve", "name": "커브", "stat": "breaking", "req": [0, 50, 63, 75, 87, 107]},
	{"id": "slider", "name": "슬라이더", "stat": "breaking", "req": [0, 50, 63, 75, 87, 107]},
	{"id": "slurve", "name": "슬러브", "stat": "breaking", "req": [0, 52, 66, 78, 90, 110]},
	{"id": "screw", "name": "스크루", "stat": "breaking", "req": [0, 52, 66, 78, 90, 110]},
	{"id": "palm", "name": "팜볼", "stat": "control", "req": [0, 52, 66, 78, 90, 110]},
	{"id": "circle", "name": "서클 체인지업", "stat": "control", "req": [0, 52, 66, 78, 90, 110]},
]


# ── 공통 ───────────────────────────────────────────────────────────────────

func games(id: String) -> int:
	return int(Sv.games.get(id, 0))

func _seed(id: String) -> int:
	return abs(id.hash())

func _st(c: Dictionary, k: String) -> int:
	return int((c.get("st", {}) as Dictionary).get(k, 50))

# ── 스킬블록 ───────────────────────────────────────────────────────────────

# 카드마다 **처음 열려 있는 네 칸의 모양이 다릅니다.** 전에는 모두 가운데 2×2 라
# 어느 카드를 열어도 판이 똑같았고, 그래서 "이 카드는 어떤 블록이 맞나"라는
# 물음이 생기지 않았습니다. 지금은 블록 모양 하나를 골라 **모서리에** 붙입니다.
#
# **저장하지 않습니다** — 구종과 같이 카드 id 를 씨앗으로 그때그때 다시 만듭니다.
# 같은 카드는 언제 봐도 같은 판이어야 하므로 난수를 쓰지 않습니다.
func start_cells(id: String) -> Array:
	var names: Array = SHAPES.keys()
	names.sort()                      # 사전 순서에 기대지 않게 못 박습니다
	var h: int = absi(hash(id))
	var shape := str(names[h % names.size()])
	@warning_ignore("integer_division")
	var rot: int = (h / 7) % 4
	@warning_ignore("integer_division")
	var corner: int = (h / 31) % 4
	# 네 모서리를 다 시도해서 **판 안에 들어가는 자리**를 씁니다. 회전에 따라
	# 어떤 모서리에는 안 들어가므로, 못 들어가면 다음 모서리로 넘어갑니다.
	var b := {"shape": shape, "rot": rot}
	for i in range(4):
		var k: int = (corner + i) % 4
		var cells := _corner_fit(b, k)
		if not cells.is_empty():
			return cells
	return [5, 6, 9, 10]              # 어디에도 못 넣으면 가운데 2×2

func _corner_fit(b: Dictionary, corner: int) -> Array:
	# 모양의 크기를 재서 그 모서리에 딱 붙는 origin 을 구합니다.
	var w := 1
	var hgt := 1
	for p in shape_cells(str(b["shape"]), int(b["rot"])):
		w = maxi(w, int(p[0]) + 1)
		hgt = maxi(hgt, int(p[1]) + 1)
	var ox := 0 if corner % 2 == 0 else GRID - w
	@warning_ignore("integer_division")
	var oy := 0 if corner / 2 == 0 else GRID - hgt
	if ox < 0 or oy < 0:
		return []
	return cells_of(b, oy * GRID + ox)

# 그 카드의 칸이 열리는 차례. 시작 네 칸 다음은 **거기서 가까운 칸부터** 퍼집니다.
func unlock_order(id: String) -> Array:
	var out: Array = start_cells(id)
	var cx := 0.0
	var cy := 0.0
	for k in out:
		cx += float(int(k) % GRID)
		@warning_ignore("integer_division")
		cy += float(int(k) / GRID)
	cx /= float(out.size())
	cy /= float(out.size())
	var rest: Array = []
	for i in range(CELLS):
		if not out.has(i):
			rest.append(i)
	rest.sort_custom(func(a, b):
		@warning_ignore("integer_division")
		var da := absf(float(a % GRID) - cx) + absf(float(a / GRID) - cy)
		@warning_ignore("integer_division")
		var db := absf(float(b % GRID) - cx) + absf(float(b / GRID) - cy)
		return da < db if da != db else a < b)
	out.append_array(rest)
	return out

func open_cells(c: Dictionary) -> Array:
	# 열린 칸 번호 목록(0~15). EX 는 처음부터 열여섯 칸 전부입니다.
	var id := DB.card_id(c)
	var order := unlock_order(id)
	if str(c.get("grade", "")) == D.GRADE_EX:
		return order
	var g := games(id)
	var out: Array = []
	for i in range(CELLS):
		if g >= int(UNLOCK_AT[i]):
			out.append(int(order[i]))
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

func pitches_of(c: Dictionary, extra: int = 0) -> Array:
	# [{id, name, stat, grade}] — 포심은 항상 있고 나머지는 카드마다 다릅니다.
	#
	# `extra` 는 **팀컬러 몫**입니다. 팀컬러는 카드가 아니라 팀에 붙으므로
	# `DB.find` 가 안 얹습니다 — 그래서 그냥 두면 작전에서 스텟이 올라도 구종
	# 등급이 그대로입니다(실제로 그랬습니다). 화면이 그 몫을 넘겨 줍니다.
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
	# 구종 수 — 변화구가 좋은 투수일수록 많습니다. 열두 가지 중에서 고르므로
	# 카드마다 조합이 다릅니다.
	#
	# **높은 COST 는 바닥을 깝니다**(`D.COST_HIGH` 이상이면 3개). 변화구 한 칸만
	# 보면 파워피처가 고코스트일수록 구종이 **줄어듭니다** — 실측으로 C1 이 3.0개,
	# C9 가 2.2개였습니다. 좋은 투수가 던질 줄 아는 공이 더 적은 셈이라 거꾸로입니다.
	# 실제 카드에는 여덟 가지를 던지는 투수도 있습니다(선동렬 — 투심·슬라이더·
	# 슬러브·스크루·커브·SFF·고속/종속 슬라이더). 변화구가 좋을수록 늘어납니다.
	var n := 1 + int(clampf((_st(c, "breaking") - 40.0) / 8.5, 1.0, 7.0))
	if int(c.get("cost", 1)) >= D.COST_HIGH:
		n = maxi(n, 3)
	var out: Array = [PITCHES[0]]
	out.append_array(rest.slice(0, n - 1))
	var res: Array = []
	for p in out:
		res.append({"id": p["id"], "name": p["name"], "stat": p["stat"], "req": p["req"],
			"grade": _pitch_grade(p, c, extra), "need": pitch_next_at(p, c, extra)})
	return res

func _pitch_grade(p: Dictionary, c: Dictionary, extra: int) -> int:
	# **그 구종이 기대는 칸의 최종 값을 요구표에 대고 잽니다.** 그게 전부입니다 —
	# 종합을 섞거나 주무기에 한 단계 얹는 보정을 두지 마세요. 그런 보정이 있으면
	# "구속을 얼마 올려야 SS 인가"를 화면에서 셀 수 없고, 실제로 포심(항상 첫
	# 구종)이 보정 상한에 걸려 **무슨 짓을 해도 SS 가 안 되는** 일이 있었습니다.
	var v := mini(_st(c, str(p["stat"])) + extra, D.STAT_MAX)
	var req: Array = p["req"]
	var lv := 0
	for i in range(req.size()):
		if v >= int(req[i]):
			lv = i
	return clampi(lv, 0, PITCH_GRADES.size() - 1)

# 다음 등급까지 그 칸을 얼마나 더 올려야 하는가. 꼭대기면 -1.
# **이게 없으면 블록을 껴도 아무 일도 안 일어난 것처럼 보입니다** — 계단이
# 스텟 12 안팎이라 한 장(+3~4)으로는 대개 안 넘어갑니다.
func pitch_next_at(p: Dictionary, c: Dictionary, extra: int = 0) -> int:
	var lv := _pitch_grade(p, c, extra)
	var req: Array = p["req"]
	if lv + 1 >= req.size():
		return -1
	return maxi(int(req[lv + 1]) - mini(_st(c, str(p["stat"])) + extra, D.STAT_MAX), 0)

func pitch_grade_name(g: int) -> String:
	return str(PITCH_GRADES[clampi(g, 0, PITCH_GRADES.size() - 1)])


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
