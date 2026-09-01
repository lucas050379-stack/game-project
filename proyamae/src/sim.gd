extends Node
# 프야매 — 경기 시뮬레이션. 오토로드(`Sim`)입니다.
#
# 한 타석을 확률로 굴리고, 그 결과로 주자를 돌립니다. 확률은 `D.PA_BASE` 를
# 스텟 차이로 밀어서 만듭니다.
#
# **한 타석의 결과는 반드시 닫혀야 합니다** — 확률 합이 1을 넘으면 아웃이
# 음수가 되어 이닝이 안 끝납니다. `_probs()` 끝에서 반드시 정규화하세요.
#
# **노드를 만들지 마세요.** 팀도 경기 상태도 전부 Dictionary 입니다.

# ── 팀 ─────────────────────────────────────────────────────────────────────
# {name, lineup:[카드×9], pos:[문자열×9], rot:[카드], relief:[카드], setup, closer}

func team_from_save(name: String, rot_i: int = -1) -> Dictionary:
	var t := {"name": name, "lineup": [], "pos": [], "bench": [], "rot": [], "relief": [],
		"setup": {}, "closer": {}, "rot_i": rot_i}
	for i in range(Sv.lineup.size()):
		var c := DB.find(str(Sv.lineup[i]))
		if not c.is_empty():
			t["lineup"].append(c)
			t["pos"].append(str(Sv.lineup_pos[i]))
	# 벤치는 경기에 안 나오지만 **로스터 팀컬러(단일팀 등)에는 들어갑니다** —
	# 그 컬러들이 "오더 25칸을 다 채웠는가"를 묻기 때문입니다.
	for id in Sv.bench:
		var c := DB.find(str(id))
		if not c.is_empty():
			t["bench"].append(c)
	for id in Sv.rot:
		var c := DB.find(str(id))
		if not c.is_empty():
			t["rot"].append(c)
	for id in Sv.relief:
		var c := DB.find(str(id))
		if not c.is_empty():
			t["relief"].append(c)
	t["setup"] = DB.find(Sv.setup)
	t["closer"] = DB.find(Sv.closer)
	apply_color(t, Sv.color_id)
	return t

# ── 팀컬러 ─────────────────────────────────────────────────────────────────
# 판정은 `Col` 이 합니다. 여기서는 **고른 하나**를 팀에 실어 주기만 합니다.
#
# **벤치를 세는 컬러와 안 세는 컬러가 갈립니다.**
# - 로스터 컬러(단일팀 · 단일연도 · 왕조 · 듀얼팀)는 "오더 25칸을 다 채웠는가"를
#   묻는 것이라 **벤치까지** 셉니다. 안 그러면 20명이 상한이라 영영 안 켜집니다.
# - 기록 · 수비 컬러는 **출전하는 자리만** 셉니다. 경기에 안 나오는 자리로 채울 수
#   있으면 벤치 다섯 칸이 그냥 보너스 슬롯이 됩니다.

# 밖에서도 씁니다 — 팀컬러 페이지가 진행도를 보려면 같은 스무 명을 봐야 합니다.
func playing_of(t: Dictionary) -> Array:
	return _playing(t)

func _playing(t: Dictionary) -> Array:
	# 실제로 경기에 나오는 스무 명.
	var out: Array = []
	out.append_array(t["lineup"])
	out.append_array(t["rot"])
	out.append_array(t["relief"])
	if not (t["setup"] as Dictionary).is_empty():
		out.append(t["setup"])
	if not (t["closer"] as Dictionary).is_empty():
		out.append(t["closer"])
	return out

func apply_color(t: Dictionary, color_id: String, auto: bool = false) -> void:
	# **켜지는 팀컬러는 하나뿐입니다.** 조건을 만족한 것들은 `t["colors"]` 에
	# 다 넣어 화면에 보여 주고, 실제로 붙는 것은 고른 하나(`t["color"]`)입니다.
	# 상대 팀(auto)은 고를 사람이 없으니 제일 센 것을 자동으로 켭니다.
	var list := Col.active(_playing(t), t.get("bench", []))
	t["colors"] = list
	var pick := Col.picked(list, color_id)
	if pick.is_empty() and auto and not list.is_empty():
		pick = list[0]   # active() 가 센 것부터 정렬해 둡니다
	t["color"] = pick
	if pick.is_empty():
		return
	var hb := int(pick["hit"])
	var pb := int(pick["pit"])
	# **원본 카드를 고치지 마세요.** `DB.cards` 는 모두가 나눠 보는 배열이라
	# 한 번 고치면 도감과 상대 팀에까지 보너스가 번집니다. 사본으로 갈아 끼웁니다.
	for key in ["lineup", "rot", "relief"]:
		var arr: Array = t[key]
		for i in range(arr.size()):
			arr[i] = _tint(arr[i], hb, pb)
	for key in ["setup", "closer"]:
		if not (t[key] as Dictionary).is_empty():
			t[key] = _tint(t[key], hb, pb)

# 지금 켜 둔 팀컬러가 이 카드에 붙여 주는 값. **작전 화면에서 카드에 적으려고**
# 있습니다 — 경기 계산은 `_tint` 가 팀 전체에 한 번에 겁니다.
func color_bonus(c: Dictionary) -> int:
	if Sv.color_id == "" or c.is_empty():
		return 0
	var t := team_from_save(D.MY_TEAM)
	var pick: Dictionary = t.get("color", {})
	if pick.is_empty():
		return 0
	return int(pick["pit"]) if str(c.get("kind", "")) == "pitcher" else int(pick["hit"])

func _tint(c: Dictionary, hb: int, pb: int) -> Dictionary:
	# 야수와 투수에 붙는 값이 다릅니다.
	var b := pb if str(c.get("kind", "")) == "pitcher" else hb
	if b <= 0:
		return c
	var g := c.duplicate(true)
	var st: Dictionary = g["st"]
	for k in st:
		st[k] = clampi(int(st[k]) + b, 1, D.STAT_MAX)
	g["colorup"] = b
	return g

func team_ok(t: Dictionary) -> String:
	# 경기를 시작할 수 있는지. 빈 문자열이면 괜찮습니다.
	if (t["lineup"] as Array).size() < D.LINEUP:
		return "타순 %d칸을 다 채워야 합니다 (지금 %d명)" % [D.LINEUP, (t["lineup"] as Array).size()]
	if (t["rot"] as Array).is_empty():
		return "선발 투수가 없습니다"
	return ""

var _pool_hit: Array = []
var _pool_pit: Array = []

func _pool(pitcher: bool) -> Array:
	# OV 내림차순 정렬을 캐시합니다. 카드 자료는 실행 중에 안 바뀝니다.
	if _pool_hit.is_empty() and _pool_pit.is_empty():
		for c in DB.cards:
			if str(c.get("kind", "")) == "pitcher":
				_pool_pit.append(c)
			else:
				_pool_hit.append(c)
		var by_ov := func(a, b): return int(a.get("ov", 0)) > int(b.get("ov", 0))
		_pool_hit.sort_custom(by_ov)
		_pool_pit.sort_custom(by_ov)
	return _pool_pit if pitcher else _pool_hit

func _window(sorted_pool: Array, target_ov: int, n: int) -> Array:
	# 목표 OV 가 들어갈 자리를 이분 탐색으로 찾고 그 주변 n 장을 가져옵니다.
	if sorted_pool.is_empty():
		return []
	var lo := 0
	var hi := sorted_pool.size()
	while lo < hi:
		@warning_ignore("integer_division")
		var mid := (lo + hi) / 2
		if int(sorted_pool[mid].get("ov", 0)) > target_ov:
			lo = mid + 1
		else:
			hi = mid
	var start := clampi(lo - n / 2, 0, maxi(0, sorted_pool.size() - n))
	return sorted_pool.slice(start, mini(start + n, sorted_pool.size()))

func build_ai(name: String, target_ov: int, rng: RandomNumberGenerator, rot_i: int = -1) -> Dictionary:
	# 상대 팀은 목표 종합 근처의 카드로 꾸립니다. 무작위로 뽑으면 NORMAL 만
	# 나와서 어느 오더를 짜도 이깁니다.
	# **후보를 "목표 ±n" 으로 자르지 마세요.** 시즌을 한둘만 넣어 두면 그 폭에
	# 아홉 명이 안 잡히고, 그러면 전체에서 무작위로 뽑는 쪽으로 빠져 상대 팀이
	# 늘 평균이 됩니다 — 종합 85 팀이 종합 55 팀에게 51% 밖에 못 이겼습니다.
	# 목표에 가까운 순으로 정렬해서 앞에서 가져오면 자료가 적어도 성립합니다.
	#
	# **매번 1만 장을 정렬하지 마세요.** 시즌 하루에 팀을 열 번 만드는데 그때마다
	# 전체 정렬을 돌리면 화면이 멎습니다. OV 내림차순으로 **한 번만** 정렬해 두고
	# 목표 근처 창만 잘라 씁니다.
	var hit := _window(_pool(false), target_ov, maxi(D.LINEUP * 2, 18))
	var pit := _window(_pool(true), target_ov, 10)
	if hit.is_empty() or pit.is_empty():
		return {"name": name, "lineup": [], "pos": [], "rot": [], "relief": [], "setup": {}, "closer": {}, "rot_i": rot_i}
	var t := {"name": name, "lineup": [], "pos": [], "rot": [], "relief": [], "setup": {}, "closer": {}, "rot_i": rot_i}
	for i in range(D.LINEUP):
		t["lineup"].append(hit[rng.randi_range(0, hit.size() - 1)])
		t["pos"].append(D.POS[i] if i < D.POS.size() else "지명타자")
	for i in range(3):
		t["rot"].append(pit[rng.randi_range(0, pit.size() - 1)])
	for i in range(3):
		t["relief"].append(pit[rng.randi_range(0, pit.size() - 1)])
	t["setup"] = pit[rng.randi_range(0, pit.size() - 1)]
	t["closer"] = pit[rng.randi_range(0, pit.size() - 1)]
	apply_color(t, "", true)
	return t

# ── 스텟 읽기 ──────────────────────────────────────────────────────────────

func _st(c: Dictionary, k: String) -> float:
	return float((c.get("st", {}) as Dictionary).get(k, 50))

func _def_of(t: Dictionary) -> float:
	# 팀 수비력 평균. 자기 자리가 아닌 곳에 서면 깎입니다 —
	# 포지션 드롭다운이 장식이 아니게 하는 유일한 장치입니다.
	var lu: Array = t["lineup"]
	var ps: Array = t["pos"]
	if lu.is_empty():
		return 50.0
	var s := 0.0
	for i in range(lu.size()):
		var c: Dictionary = lu[i]
		var v := _st(c, "defense")
		var want := str(ps[i]) if i < ps.size() else "지명타자"
		var have := str(c.get("pos", ""))
		if want != "지명타자" and want != have:
			var g1 := str(D.POS_GROUP.get(want, ""))
			var g2 := str(D.POS_GROUP.get(have, ""))
			v -= float(D.OUT_OF_POS_NEAR if g1 == g2 else D.OUT_OF_POS)
		s += v
	return s / float(lu.size())

# ── 투수 상태 ──────────────────────────────────────────────────────────────

func _new_arm(c: Dictionary) -> Dictionary:
	return {"card": c, "bf": 0, "r": 0, "outs": 0}

func _tired(arm: Dictionary) -> float:
	# 한계 타자 수를 넘으면 그때부터 스텟이 깎입니다.
	var limit := D.STAM_BASE + _st(arm["card"], "stamina") * D.STAM_PER
	var over := float(arm["bf"]) - limit
	return 0.0 if over <= 0.0 else over * D.TIRE_PER_BF

# ── 한 타석 ────────────────────────────────────────────────────────────────

func _probs(bat: Dictionary, arm: Dictionary, def_lv: float, risp: bool) -> Dictionary:
	var tire := _tired(arm)
	var pc: Dictionary = arm["card"]
	var stuff := _st(pc, "stuff") - tire
	var ctl := _st(pc, "control") - tire
	var brk := _st(pc, "breaking") - tire
	var vel := _st(pc, "velo") - tire

	var con := _st(bat, "contact")
	var pw := _st(bat, "power")
	# 정신력은 **주자가 있을 때만** 붙습니다. 늘 붙이면 그냥 교타력 한 칸이 됩니다.
	if risp:
		con += (_st(bat, "mental") - 50.0) * D.K_MENTAL * 100.0 * 0.12
		pw += (_st(bat, "mental") - 50.0) * D.K_MENTAL * 100.0 * 0.08

	var p := {}
	p["so"] = D.PA_BASE["so"] * (1.0 + ((vel + brk) * 0.5 - con) * D.K_EYE)
	p["bb"] = D.PA_BASE["bb"] * (1.0 + (con - ctl) * D.K_EYE)
	# 인플레이 안타는 상대 수비가 깎습니다.
	var hitmul := 1.0 + (con - (stuff + ctl) * 0.5) * D.K_CONTACT - (def_lv - 50.0) * D.K_DEF
	var powmul := 1.0 + (pw - stuff) * D.K_POWER
	p["hr"] = D.PA_BASE["hr"] * powmul
	p["h3"] = D.PA_BASE["h3"] * hitmul * (1.0 + (_st(bat, "speed") - 50.0) * D.K_SPEED)
	p["h2"] = D.PA_BASE["h2"] * hitmul * (1.0 + (powmul - 1.0) * 0.5)
	p["h1"] = D.PA_BASE["h1"] * hitmul

	var sum := 0.0
	for k in p:
		p[k] = maxf(float(p[k]), 0.002)
		sum += float(p[k])
	# **여기서 닫습니다.** 합이 커지면 전부 눌러서 아웃 자리를 남깁니다.
	if sum > 0.90:
		var k2 := 0.90 / sum
		for k in p:
			p[k] = float(p[k]) * k2
		sum = 0.90
	p["out"] = 1.0 - sum
	return p

func _roll(p: Dictionary, rng: RandomNumberGenerator) -> String:
	var r := rng.randf()
	var acc := 0.0
	for k in ["so", "bb", "hr", "h3", "h2", "h1"]:
		acc += float(p[k])
		if r < acc:
			return k
	return "out"

# ── 주자 ───────────────────────────────────────────────────────────────────

func _advance(bases: Array, ev: String, speed: float, rng: RandomNumberGenerator) -> int:
	# 돌아온 주자 수를 돌려줍니다. bases 는 [1루, 2루, 3루] 의 있고없음입니다.
	var runs := 0
	var extra := 1 if rng.randf() < clampf((speed - 50.0) * D.K_SPEED, 0.0, 0.35) else 0
	match ev:
		"bb":
			# 밀어내기 — 앞이 다 차 있을 때만 주자가 옵니다.
			if bases[0]:
				if bases[1]:
					if bases[2]:
						runs += 1
					else:
						bases[2] = true
				else:
					bases[1] = true
			bases[0] = true
		"h1":
			var n := 1 + extra
			runs += _push(bases, n)
			bases[0] = true
		"h2":
			runs += _push(bases, 2 + extra)
			bases[1] = true
		"h3":
			runs += _push(bases, 3)
			bases[2] = true
		"hr":
			runs += _push(bases, 4)
			runs += 1
	return runs

func _push(bases: Array, n: int) -> int:
	# 주자를 n 베이스씩 밀어냅니다. 홈을 넘어가면 득점입니다.
	var runs := 0
	for i in [2, 1, 0]:
		if not bases[i]:
			continue
		bases[i] = false
		if i + n >= 3:
			runs += 1
		else:
			bases[i + n] = true
	return runs

# ── 경기 ───────────────────────────────────────────────────────────────────

func play(away: Dictionary, home: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var state := {
		"away": away, "home": home,
		"score": [0, 0],
		"line": [[], []],       # 이닝별 득점
		"log": [],              # 볼 만한 장면
		"bi": [0, 0],           # 타순 위치
		"arms": [_pick_starter(away, rng), _pick_starter(home, rng)],
		"hits": [0, 0],
	}
	for inn in range(1, D.INNINGS + 1):
		for side in range(2):
			# 9회말은 홈이 이기고 있으면 안 합니다.
			if inn >= D.INNINGS and side == 1 and state["score"][1] > state["score"][0]:
				(state["line"][1] as Array).append(-1)
				continue
			var r := _half(state, side, inn, rng)
			(state["line"][side] as Array).append(r)
	# 연장 — 최대 3이닝까지만 봅니다. 무한 루프를 만들지 마세요.
	var extra := 0
	while state["score"][0] == state["score"][1] and extra < 3:
		extra += 1
		for side in range(2):
			var r := _half(state, side, D.INNINGS + extra, rng)
			(state["line"][side] as Array).append(r)
			if side == 1 and state["score"][1] > state["score"][0]:
				break
	state["winner"] = 0 if state["score"][0] > state["score"][1] else (1 if state["score"][1] > state["score"][0] else -1)
	return state

func _pick_starter(t: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	# **로테이션은 순서대로 돕니다.** 무작위로 고르면 선발 5칸이 그냥 "아무나 한 명"이
	# 되어, 오더에서 1선발과 5선발을 나눠 놓을 이유가 없어집니다. 시즌은 경기마다
	# `rot_i` 를 올려 넘겨 줍니다(단판이면 없으니 무작위로 갑니다).
	var rot: Array = t["rot"]
	if rot.is_empty():
		return _new_arm({"name": "무명", "st": {}})
	var i := int(t.get("rot_i", -1))
	if i < 0:
		i = rng.randi_range(0, rot.size() - 1)
	return _new_arm(rot[i % rot.size()])

func _relieve(state: Dictionary, side: int, inn: int) -> void:
	# 지치면 바꿉니다. 8회는 셋업, 9회는 마무리 — 프야매의 그 칸입니다.
	var t: Dictionary = state["away"] if side == 0 else state["home"]
	var arm: Dictionary = state["arms"][side]
	var want := {}
	if inn >= D.INNINGS and not (t["closer"] as Dictionary).is_empty():
		want = t["closer"]
	elif inn >= D.INNINGS - 1 and not (t["setup"] as Dictionary).is_empty():
		want = t["setup"]
	elif _tired(arm) > 12.0:
		var rel: Array = t["relief"]
		if not rel.is_empty():
			want = rel[mini(int(arm["bf"]) % rel.size(), rel.size() - 1)]
	if want.is_empty() or want == arm["card"]:
		return
	state["arms"][side] = _new_arm(want)
	(state["log"] as Array).append("%d회 %s 투수 교체 → %s" % [inn, t["name"], str(want.get("name", ""))])

func _half(state: Dictionary, side: int, inn: int, rng: RandomNumberGenerator) -> int:
	var bat_team: Dictionary = state["away"] if side == 0 else state["home"]
	var fld := 1 - side
	_relieve(state, fld, inn)
	var arm: Dictionary = state["arms"][fld]
	var def_lv := _def_of(state["away"] if fld == 0 else state["home"])
	var lu: Array = bat_team["lineup"]
	if lu.is_empty():
		return 0

	var outs := 0
	var bases := [false, false, false]
	var runs := 0
	var guard := 0
	while outs < 3 and guard < 60:
		guard += 1
		var bi := int(state["bi"][side])
		var bat: Dictionary = lu[bi % lu.size()]
		state["bi"][side] = bi + 1
		var risp: bool = bases[1] or bases[2]
		var ev := _roll(_probs(bat, arm, def_lv, risp), rng)
		arm["bf"] = int(arm["bf"]) + 1
		if ev == "so" or ev == "out":
			outs += 1
			# 주자가 있고 아웃이면 가끔 진루타가 됩니다.
			if ev == "out" and outs < 3 and bases[2] and rng.randf() < 0.28:
				bases[2] = false
				runs += 1
		else:
			if ev != "bb":
				state["hits"][side] = int(state["hits"][side]) + 1
			var got := _advance(bases, ev, _st(bat, "speed"), rng)
			runs += got
			if ev == "hr":
				var many := got
				(state["log"] as Array).append("%d회 %s %s %s" % [inn, bat_team["name"],
					str(bat.get("name", "")), ("만루 홈런" if many >= 4 else ("%d점 홈런" % many))])
	state["score"][side] = int(state["score"][side]) + runs
	return runs
