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

func build_ai(name: String, target_ov: int, rng: RandomNumberGenerator, rot_i: int = -1, boost: int = 0) -> Dictionary:
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
	# **자리를 카드에 맞춰 배정합니다.** 예전에는 타순대로 포수·1루수·2루수… 를
	# 그냥 붙였는데, 뽑힌 카드가 그 자리 선수인 경우가 드물어서 **AI 팀 아홉 명이
	# 거의 다 자리 이탈** 상태였습니다. `D.OUT_OF_POS` 가 12 이던 시절엔 티가 안
	# 났지만 40 으로 올리자 AI 실점이 4.0 → 5.2 로 뛰었습니다 — 상대가 수비를
	# 못 짜서 생기는 점수는 내 오더의 실력이 아닙니다.
	#
	# **후보를 모아서 뽑습니다.** 무작위로 찔러 보다 맞으면 쓰는 방식은 후보가
	# 적은 자리(포수)에서 자주 실패해 엉뚱한 카드로 흘러가고, 그러면 `target_ov`
	# 가 팀 세기를 못 나타냅니다 — 실제로 종합 차이 4 의 승률(65%)이 차이 8(62%)
	# 보다 높아졌습니다.
	var used := {}
	for i in range(D.LINEUP):
		var want := str(D.POS[i]) if i < D.POS.size() else "지명타자"
		var cand: Array = []
		for j in range(hit.size()):
			if used.has(j):
				continue
			if str((hit[j] as Dictionary).get("pos", "")) == want:
				cand.append(j)
		if cand.is_empty():
			for j in range(hit.size()):
				if used.has(j):
					continue
				var hv := str((hit[j] as Dictionary).get("pos", ""))
				if str(D.POS_GROUP.get(hv, "")) == str(D.POS_GROUP.get(want, "")):
					cand.append(j)
		if cand.is_empty():
			for j in range(hit.size()):
				if not used.has(j):
					cand.append(j)
		if cand.is_empty():
			cand.append(i % hit.size())
		var pick: int = int(cand[rng.randi_range(0, cand.size() - 1)])
		used[pick] = true
		t["lineup"].append(hit[pick])
		t["pos"].append(want)
	for i in range(3):
		t["rot"].append(pit[rng.randi_range(0, pit.size() - 1)])
	for i in range(3):
		t["relief"].append(pit[rng.randi_range(0, pit.size() - 1)])
	t["setup"] = pit[rng.randi_range(0, pit.size() - 1)]
	t["closer"] = pit[rng.randi_range(0, pit.size() - 1)]
	if boost > 0:
		# **AI 의 성장 몫**(`D.TIER_AI_BOOST`). 사람은 유학·스킬블록·로스터 팀컬러를
		# 얹는데 AI 는 카드와 기록 컬러뿐이라, 상위 등급에서 이걸 안 주면 성장을
		# 갖춘 덱에게 60~90% 로 집니다.
		for bk in ["lineup", "bench", "rot", "relief"]:
			var barr: Array = t.get(bk, [])
			for bi in range(barr.size()):
				barr[bi] = _tint(barr[bi], boost, boost)
		for bk2 in ["setup", "closer"]:
			if not (t.get(bk2, {}) as Dictionary).is_empty():
				t[bk2] = _tint(t[bk2], boost, boost)
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

func _new_arm(c: Dictionary, starter: bool = false) -> Dictionary:
	# `p` 는 던진 공, `r` 은 그 투수가 내준 점수입니다. 둘 다 **투수마다** 세므로
	# 교체되면 0 부터 다시 시작합니다(앞 투수의 실점을 뒤 투수가 뒤집어쓰지 않습니다).
	# `starter` 는 완투 판정에만 씁니다 — 중계·셋업이 올라온 뒤에는 8·9회 교체가
	# 원래대로 돌아가야 마무리 칸이 놀지 않습니다.
	return {"card": c, "bf": 0, "p": 0.0, "gas": 0.0, "r": 0, "outs": 0, "starter": starter}

func _gas_max(arm: Dictionary) -> float:
	# **체력의 제곱**입니다. 체력 50 이면 2500, 100 이면 10000 —
	# 일부러 크게 벌려서 "끝까지 가는 투수"와 "한 이닝짜리"가 갈리게 합니다.
	var s := _st(arm["card"], "stamina")
	return maxf(1.0, s * s)

func _gas_left(arm: Dictionary) -> float:
	# 남은 기력 비율. 1 이면 가득, 0 이면 바닥, 음수면 바닥을 지나 계속 던지는 중.
	var m := _gas_max(arm)
	return (m - float(arm["gas"])) / m

func _tired(arm: Dictionary) -> float:
	# 기력이 줄수록 깎입니다 — **남은 비율의 제곱꼴**이라 앞은 완만하고 끝에서 급합니다.
	var left := _gas_left(arm)
	if left >= 1.0:
		return 0.0
	if left <= 0.0:
		return D.TIRE_FULL + (-left) * D.TIRE_EMPTY
	return D.TIRE_FULL * pow(1.0 - left, D.TIRE_POW)

func _eye(bat: Dictionary) -> float:
	# **선구안** — 교타력에 정신력을 얹은 값. 볼넷·삼진과 투구 수가 **이 함수
	# 하나를 같이 봅니다.** 따로 계산하면 "볼은 잘 고르는데 공은 안 뺏는" 타자가
	# 생겨서, 화면의 같은 스텟이 두 가지 다른 뜻을 갖게 됩니다.
	return _st(bat, "contact") + (_st(bat, "mental") - 50.0) * D.EYE_MENTAL

func _pitches(ev: String, bat: Dictionary, arm: Dictionary, rng: RandomNumberGenerator) -> float:
	# 한 타석에 쓴 공. **제구가 좋으면 아끼고, 선구안이 좋으면 뺏깁니다.**
	#
	# 선구안이 투구 수를 늘리는 것이 실제 야구에서 이 능력이 값을 하는 가장 큰
	# 이유입니다 — 볼넷 몇 개보다 **상대 선발을 한 이닝 일찍 끌어내리는 것**이
	# 큽니다. 기력이 투구 수로 도니까(`_gas_left`) 그대로 이어집니다.
	var n := float(D.PITCH_COST.get(ev, 3.5))
	n *= 1.0 - (_st(arm["card"], "control") - 50.0) * D.PITCH_CTL
	n *= 1.0 + (_eye(bat) - 50.0) * D.PITCH_EYE
	return maxf(1.0, n + rng.randf_range(-D.PITCH_JITTER, D.PITCH_JITTER))

# ── 한 타석 ────────────────────────────────────────────────────────────────

func _legs(bat: Dictionary) -> float:
	# 번트와 주력을 한 축으로 묶은 값(리그 평균이면 0). **둘을 같이 봅니다** —
	# 번트만 높고 발이 느리면 기습 번트가 안 살고, 발만 빠르고 번트를 못 대면
	# 주자를 못 밀어냅니다. 출루(`K_LEGS`)와 밀어내기(`K_PUSH`)가 같이 씁니다.
	return (_st(bat, "bunt") - 50.0) * 0.85 + (_st(bat, "speed") - 50.0) * 0.15

func _probs(bat: Dictionary, arm: Dictionary, def_lv: float, risp: bool) -> Dictionary:
	var tire := _tired(arm)
	var pc: Dictionary = arm["card"]
	var stuff := _st(pc, "stuff") - tire
	var ctl := _st(pc, "control") - tire
	var brk := _st(pc, "breaking") - tire
	var vel := _st(pc, "velo") - tire

	var con := _st(bat, "contact")
	var pw := _st(bat, "power")
	# 정신력은 **주자가 있을 때만**, 그리고 **한 통로로만** 붙습니다.
	#
	# 예전에는 두 갈래였습니다 — `K_MENTAL` 이 교타·장타에 몇 점 얹고, `K_CLUTCH`
	# 가 승부처 안타를 눌렀습니다. 그런데 `K_MENTAL` 쪽은 +35점을 줘도 교타가
	# 1.5점 오르는 정도라 **실측에서 득점이 안 움직였습니다**(타자 정신력 50→85 가
	# −0.01점, 투수 50→90 이 0.02점). 종합에는 0.10 이 들어가는데 경기에서는
	# 아무 일도 안 하니, 정신력이 높아서 종합이 높은 카드는 같은 COST 의 다른
	# 카드보다 실제로 약했습니다. 그래서 통로를 `K_CLUTCH` 하나로 합쳤습니다.
	#
	# **맞대결입니다** — 타자 정신력이 올리고 투수 정신력이 내립니다. 한쪽만 보면
	# 그 반대쪽 카드는 종합에만 있고 경기에는 없는 스텟을 갖게 됩니다.
	var clutch := 1.0
	if risp:
		clutch = clampf(1.0 + (_st(bat, "mental") - _st(pc, "mental")) * D.K_CLUTCH,
			0.55, 1.45)
	var p := {}
	# **선구안** — 볼넷과 삼진은 교타력에 **정신력**을 얹어서 봅니다. 침착한 타자가
	# 볼을 골라내는 축이라, 정신력이 득점권에만 붙으면 "승부처 전용 스텟"이 되어
	# 평소 타석에서는 없는 것과 같습니다. 여기는 **상시**, 아래 `clutch` 는
	# **득점권 한정** — 통로가 둘이지만 하는 일이 다릅니다.
	var eye := _eye(bat)
	p["so"] = D.PA_BASE["so"] * (1.0 + ((vel + brk) * 0.5 - eye) * D.K_EYE)
	p["bb"] = D.PA_BASE["bb"] * (1.0 + (eye - ctl) * D.K_EYE)
	# 인플레이 안타는 상대 수비가 깎습니다.
	# **맞아도 약하게 맞는 정도** — 구위가 축이고 제구·구속·변화구가 거듭니다.
	#
	# 예전에는 `(stuff + ctl) * 0.5` 라 구속·변화구가 **삼진 확률 한 곳에만** 닿았는데,
	# 삼진이 늘면 인플레이 아웃이 그만큼 줄어 **아웃 총량이 안 변합니다**(`p["out"]`
	# 이 나머지라서요). 밀어내기를 막는 이득과 병살을 놓치는 손해가 상쇄되어
	# 실측 −0.03점(노이즈)이었습니다 — 종합에는 둘이 0.20 이나 들어가는데 경기에서는
	# 없는 셈이었습니다. 현실에서 구속·변화구가 값을 하는 이유도 삼진 그 자체가
	# 아니라 **맞아도 약하게 맞기 때문**이라, 여기 넣는 것이 맞습니다.
	var supp := stuff * D.SUP_STUFF + ctl * D.SUP_CTL + vel * D.SUP_VELO + brk * D.SUP_BRK
	var hitmul := (1.0 + (con - supp) * D.K_CONTACT - (def_lv - 50.0) * D.K_DEF) * clutch
	var powmul := (1.0 + (pw - stuff) * D.K_POWER) * clutch
	p["hr"] = D.PA_BASE["hr"] * powmul
	p["h3"] = D.PA_BASE["h3"] * hitmul * (1.0 + (_st(bat, "speed") - 50.0) * D.K_SPEED)
	p["h2"] = D.PA_BASE["h2"] * hitmul * (1.0 + (powmul - 1.0) * 0.5)
	# **발과 번트로 살아 나갑니다.** 번트·주력이 높으면 기습 번트와 내야 안타가
	# 늘어납니다 — 인플레이 아웃에서 떼어 오는 것이라 `out` 이 그만큼 줄어듭니다
	# (합은 아래에서 다시 닫습니다). 장타에는 안 붙습니다: 발로 만드는 것은
	# 언제나 단타입니다.
	p["h1"] = D.PA_BASE["h1"] * hitmul * (1.0 + _legs(bat) * D.K_LEGS)

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
	# 돌아온 주자 수를 돌려줍니다.
	#
	# **`bases` 는 있고없음이 아니라 그 주자의 주력입니다**(-1 = 빈 루). 예전에는
	# `[bool, bool, bool]` 이었고 몇 베이스를 더 가느냐를 **타자의** 주력 하나로
	# 정했습니다 — 그래서 1루에 선 주자가 이종범이든 포수든 똑같이 갔고,
	# **빠른 선수를 1·2번에 두는 것이 구조적으로 아무 의미가 없었습니다.**
	# 지금은 주자마다 자기 발로 한 베이스를 더 노립니다.
	var runs := 0
	match ev:
		"bb":
			# 볼넷은 밀어내기뿐입니다 — 발이 빨라도 더 못 갑니다.
			if bases[0] >= 0.0:
				if bases[1] >= 0.0:
					if bases[2] >= 0.0:
						runs += 1
					else:
						bases[2] = bases[1]
				bases[1] = bases[0]
			bases[0] = speed
		"h1":
			runs += _push(bases, 1, rng)
			bases[0] = speed
		"h2":
			runs += _push(bases, 2, rng)
			bases[1] = speed
		"h3":
			runs += _push(bases, 3, rng)
			bases[2] = speed
		"hr":
			runs += _push(bases, 4, rng)
			runs += 1
	return runs

func _push(bases: Array, n: int, rng: RandomNumberGenerator) -> int:
	# 주자를 n 베이스씩 밀어내되, **주자마다 자기 주력으로 한 베이스를 더** 노립니다.
	# 앞 주자부터(3루 → 1루) 처리하고 **앞 주자를 추월하지 못하게** 막습니다 —
	# 안 그러면 발 빠른 뒷주자가 느린 앞주자를 지나가는 장면이 나옵니다.
	var runs := 0
	var out := [-1.0, -1.0, -1.0]
	var limit := 3   # 앞 주자가 선 루. 3 이면 앞이 비어 있다는 뜻입니다.
	for i in [2, 1, 0]:
		var sp := float(bases[i])
		if sp < 0.0:
			continue
		var step: int = n
		if rng.randf() < clampf((sp - 50.0) * D.K_SPEED, 0.0, 0.35):
			step += 1
		var dest: int = int(i) + step
		if dest >= 3:
			runs += 1
			continue
		if dest >= limit:
			dest = limit - 1
		if dest < i:
			dest = i
		out[dest] = sp
		limit = dest
	for i in range(3):
		bases[i] = out[i]
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
		"used": [[], []],    # 이미 등판한 카드 — 다시 올리면 기력이 회복돼 버립니다
		"cg": [false, false], # 완투 여부 — 선발이 끝까지 남아 있었나
	}
	# 선발도 등판 이력에 넣습니다 — 안 넣으면 불펜이 다 소진됐을 때
	# `_next_arm` 이 선발을 다시 올려 기력이 가득 찬 채로 돌아옵니다.
	for s in range(2):
		((state["used"] as Array)[s] as Array).append((state["arms"][s] as Dictionary)["card"])
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
	# 완투 — 선발이 한 번도 안 갈리고 마운드에 남아 있으면 완투입니다.
	for s in range(2):
		var a2: Dictionary = state["arms"][s]
		if not bool(a2.get("starter", false)):
			continue
		(state["cg"] as Array)[s] = true
		var t2: Dictionary = state["away"] if s == 0 else state["home"]
		(state["log"] as Array).append("%s %s 완투 (%.0f구 %d실점)" % [t2["name"],
			str((a2["card"] as Dictionary).get("name", "")), float(a2["p"]), int(a2["r"])])
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
	return _new_arm(rot[i % rot.size()], true)

func _cg_limit(arm: Dictionary) -> float:
	# 감독이 8·9회를 더 맡기는 투구 수 상한. **체력에 선형입니다** — 기력(체력의
	# 제곱)으로 가르면 문턱 근처에서 체력 두 점 차이가 완투율을 0%%에서 18%%로
	# 바꿉니다.
	return D.CG_PITCH_BASE + _st(arm["card"], "stamina") * D.CG_PITCH_PER

func _next_arm(state: Dictionary, t: Dictionary, side: int) -> Dictionary:
	# 지정된 사람(8회 셋업 · 9회 마무리)을 못 쓸 때 **중계 → 셋업 → 마무리** 순으로
	# 아직 안 던진 사람을 찾습니다.
	#
	# **이미 던진 사람은 건너뜁니다.** `_new_arm` 이 기력을 0 부터 다시 세기 때문에
	# 같은 투수를 다시 올리면 **기력이 통째로 회복됩니다** — 연장에서 두 명을
	# 번갈아 쓰면 아무도 안 지치는 상태가 됩니다.
	var used: Array = (state["used"] as Array)[side]
	var pool: Array = []
	for c in (t["relief"] as Array):
		pool.append(c)
	if not (t["setup"] as Dictionary).is_empty():
		pool.append(t["setup"])
	if not (t["closer"] as Dictionary).is_empty():
		pool.append(t["closer"])
	for c in pool:
		if (c as Dictionary).is_empty() or used.has(c):
			continue
		return c
	# 아무도 안 남았습니다 — 지친 투수가 그대로 끌고 갑니다(그게 대가입니다).
	return {}

func _relieve(state: Dictionary, side: int, inn: int) -> void:
	# **남은 기력과 실점으로 갈립니다.**
	#
	# 8회 셋업 · 9회 마무리는 무조건이 아닙니다 — 선발의 투구 수가 상한(체력에
	# 선형) 안이고
	# 남았고 `D.CG_RUNS` 이하로 막고 있으면 그대로 둡니다. 그게 완투가 나오는
	# 통로입니다. **이 예외는 선발에게만 줍니다**(`starter`) — 중계·셋업이 이미
	# 올라온 뒤에도 같은 예외를 주면 마무리가 영영 안 올라옵니다.
	var t: Dictionary = state["away"] if side == 0 else state["home"]
	var arm: Dictionary = state["arms"][side]
	var used: Array = (state["used"] as Array)[side]
	var left := _gas_left(arm)
	var runs := int(arm["r"])
	var spent: bool = left <= D.PULL_LEFT or runs >= D.PULL_RUNS
	var want := {}
	if inn >= D.INNINGS - 1:
		var keep_going: bool = bool(arm.get("starter", false)) and float(arm["p"]) <= _cg_limit(arm) and runs <= D.CG_RUNS
		if not keep_going:
			var pick: Dictionary = t["closer"] if inn >= D.INNINGS else t["setup"]
			if not pick.is_empty() and not used.has(pick):
				want = pick
			elif spent:
				# 마무리가 이미 올라와 있는데 기력이 바닥났습니다(연장).
				# **남은 중계·셋업으로 넘깁니다** — 안 그러면 빈 탱크로 계속 던져
				# 12회쯤엔 구위·제구가 40점 넘게 깎입니다.
				# **`spent` 검사를 빼지 마세요** — 지정된 사람은 이미 `used` 에
				# 있으므로, 이 조건이 없으면 멀쩡한 마무리를 연장마다 갈아 버립니다.
				want = _next_arm(state, t, side)
	elif spent:
		want = _next_arm(state, t, side)
	if want.is_empty() or want == arm["card"]:
		return
	state["arms"][side] = _new_arm(want)
	used.append(want)
	(state["log"] as Array).append("%d회 %s 투수 교체 → %s (%.0f구%s)" % [inn, t["name"],
		str(want.get("name", "")), float(arm["p"]), (" %d실점" % runs) if runs > 0 else ""])

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
	# -1 = 빈 루, 그 외에는 그 루에 선 주자의 주력입니다.
	var bases := [-1.0, -1.0, -1.0]
	var runs := 0
	var guard := 0
	while outs < 3 and guard < 60:
		guard += 1
		# **도루** — 1루에 주자가 있고 2루가 비었으면 발로 한 베이스를 훔칩니다.
		# 이것이 "빠른 선수를 1·2번에 두는" 이유의 절반입니다. 도루가 없으면
		# 단타로 나간 발 빠른 주자와 느린 주자가 똑같아서, 타순을 어떻게 짜도
		# 득점이 같습니다(실측: 정석 3.407 대 거꾸로 3.421 — 차이 없음).
		if bases[0] >= 0.0 and bases[1] < 0.0:
			var sp := float(bases[0])
			if rng.randf() < D.STEAL_TRY + (sp - 50.0) * D.K_STEAL_TRY:
				bases[0] = -1.0
				if rng.randf() < D.STEAL_OK + (sp - 50.0) * D.K_STEAL_OK:
					bases[1] = sp
				else:
					outs += 1
					if outs >= 3:
						break
		var bi := int(state["bi"][side])
		var bat: Dictionary = lu[bi % lu.size()]
		state["bi"][side] = bi + 1
		var risp: bool = bases[1] >= 0.0 or bases[2] >= 0.0
		var ev := _roll(_probs(bat, arm, def_lv, risp), rng)
		arm["bf"] = int(arm["bf"]) + 1
		var np := _pitches(ev, bat, arm, rng)
		arm["p"] = float(arm["p"]) + np
		arm["gas"] = float(arm["gas"]) + np * D.GAS_PER_PITCH
		if ev == "so" or ev == "out":
			outs += 1
			var scored := false
			# **밀어내기** — 주자 3루에서 아웃이 나면 주자가 들어옵니다.
			# 세 사람이 같이 정합니다: 타자가 잘 밀어내고(번트·주력),
			# **3루 주자가 발이 빠르고**, 투수가 승부처에 강할수록 막습니다.
			# 3루 주자의 발을 빼면 "빠른 주자를 3루에 두는 것"이 아무 뜻이 없어집니다.
			if ev == "out" and outs < 3 and bases[2] >= 0.0:
				var push := D.PUSH_BASE + _legs(bat) * D.K_PUSH \
					+ (float(bases[2]) - 50.0) * D.K_PUSH * 0.4 \
					- (_st(arm["card"], "mental") - 50.0) * D.K_PUSH * 0.5
				if rng.randf() < clampf(push, 0.05, 0.70):
					bases[2] = -1.0
					runs += 1
					scored = true
			# **병살타** — 1루에 느린 주자가 있으면 한 방에 둘이 죽습니다.
			# 나머지 절반의 이유가 이것입니다: 발 느린 거포를 연달아 세우면
			# 이닝이 병살로 끊깁니다. 뜬공으로 점수를 냈으면(위) 땅볼이 아니므로
			# 같이 일어나지 않습니다.
			if ev == "out" and not scored and outs < 3 and bases[0] >= 0.0:
				var dp := D.DP_BASE - (float(bases[0]) - 50.0) * D.K_DP
				if rng.randf() < clampf(dp, 0.02, 0.40):
					bases[0] = -1.0
					outs += 1
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
	# 이 반이닝의 실점은 마운드에 있던 투수 몫입니다(교체는 이닝 사이에만 일어납니다).
	arm["r"] = int(arm["r"]) + runs
	return runs
