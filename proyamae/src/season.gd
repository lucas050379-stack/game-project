extends Node
# 프야매 — 시즌 운영. 오토로드(`Sea`)입니다.
#
# 리그는 **나 포함 열 팀**입니다. 내가 한 경기를 치를 때 나머지 여덟 팀도 자기들끼리
# 붙어서 순위표가 같이 움직입니다 — 내 승패만 세면 그건 순위가 아니라 그냥 전적입니다.
#
# **상대 팀 로스터를 저장하지 마세요.** 이름·세기·씨앗만 두었다가 필요할 때
# `Sim.build_ai` 로 다시 만듭니다. 같은 씨앗이면 같은 팀이 나오므로 시즌 내내
# 상대가 일관되고, 세이브 파일은 몇 줄로 끝납니다.

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

# ── 시즌 시작 ──────────────────────────────────────────────────────────────

func my_level() -> int:
	# 내 타순 평균 종합. 리그 세기를 정하는 값이 **아닙니다** — 화면에
	# "내 팀이 이 리그에서 어느 정도인가"를 보여줄 때만 씁니다.
	var t := Sim.team_from_save(D.MY_TEAM)
	var lu: Array = t["lineup"]
	if lu.is_empty():
		return 0
	var s := 0
	for c in lu:
		s += int(c.get("ov", 0))
	@warning_ignore("integer_division")
	return s / lu.size()

func start_season() -> void:
	# **리그 세기는 등급이 정합니다.** 내 로스터에 맞춰 따라오게 두면 아무리
	# 카드를 모아도 난이도가 그대로라 올라갈 이유가 없어집니다.
	var lv := D.tier_ov(Sv.tier)
	Sv.season += 1
	Sv.game_no = 0
	Sv.rot_i = 0
	Sv.my_w = 0
	Sv.my_d = 0
	Sv.my_l = 0
	Sv.league = []
	for i in range(D.LEAGUE_NAMES.size()):
		Sv.league.append({
			"name": str(D.LEAGUE_NAMES[i]),
			"ov": clampi(lv + int(D.LEAGUE_SPREAD[i]), 25, 99),
			"seed": rng.randi(),
			"w": 0, "l": 0, "d": 0,
		})
	# 일정 — 아홉 팀을 섞어 되풀이합니다. 한 팀만 계속 만나면 리그가 아닙니다.
	Sv.schedule = []
	var bag: Array = []
	while Sv.schedule.size() < D.SEASON_GAMES:
		if bag.is_empty():
			for i in range(Sv.league.size()):
				bag.append(i)
			_shuffle(bag)
		Sv.schedule.append(bag.pop_back())
	Sv.save_game()

func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

func active() -> bool:
	return Sv.season > 0 and Sv.game_no < D.SEASON_GAMES and not Sv.league.is_empty()

func finished() -> bool:
	return Sv.season > 0 and Sv.game_no >= D.SEASON_GAMES

# ── 팀 만들기 ──────────────────────────────────────────────────────────────

func ai_team(i: int, rot_i: int) -> Dictionary:
	# 씨앗이 같으면 같은 팀이 나옵니다. 로테이션 위치만 경기마다 달라집니다.
	var e: Dictionary = Sv.league[i]
	var r := RandomNumberGenerator.new()
	r.seed = int(e["seed"])
	return Sim.build_ai(str(e["name"]), int(e["ov"]), r, rot_i, D.ai_boost(Sv.tier))

func next_foe() -> Dictionary:
	if not active():
		return {}
	return Sv.league[int(Sv.schedule[Sv.game_no])]

# ── 하루 진행 ──────────────────────────────────────────────────────────────

func play_next() -> Dictionary:
	# 내 경기 한 판 + 나머지 팀들 경기. 결과 요약을 돌려줍니다.
	if not active():
		return {}
	var foe_i := int(Sv.schedule[Sv.game_no])
	var mine := Sim.team_from_save(D.MY_TEAM, Sv.rot_i)
	var err := Sim.team_ok(mine)
	if err != "":
		return {"error": err}
	var foe := ai_team(foe_i, Sv.game_no)
	var g := Sim.play(mine, foe, rng)

	var mine_runs := int(g["score"][0])
	var foe_runs := int(g["score"][1])
	var coin := D.COIN_PER_RUN * mine_runs
	var win := int(g["winner"])
	if win == 0:
		Sv.my_w += 1
		Sv.wins += 1
		(Sv.league[foe_i] as Dictionary)["l"] = int((Sv.league[foe_i] as Dictionary)["l"]) + 1
		coin += D.COIN_WIN
	elif win == 1:
		Sv.my_l += 1
		Sv.losses += 1
		(Sv.league[foe_i] as Dictionary)["w"] = int((Sv.league[foe_i] as Dictionary)["w"]) + 1
		coin += D.COIN_LOSE
	else:
		Sv.my_d += 1
		(Sv.league[foe_i] as Dictionary)["d"] = int((Sv.league[foe_i] as Dictionary).get("d", 0)) + 1
		coin += (D.COIN_WIN + D.COIN_LOSE) / 2

	_sim_others(foe_i)

	# 유학은 **경기 수**로 셉니다. 여기서 하루를 넘겨야 시즌 도중에 보낼지
	# 끝나고 보낼지가 실제 선택이 됩니다.
	var back := Sv.tick_study()
	# 그 경기에 나온 카드들의 출전 수를 올립니다 — 스킬 칸과 구종 등급이 이걸 봅니다.
	Gr.note_game(mine)

	Sv.coins += coin
	Sv.game_no += 1
	Sv.rot_i += 1
	Sv.save_game()
	return {"game": g, "coin": coin, "back": back,
		"foe": str((Sv.league[foe_i] as Dictionary)["name"])}

func _sim_others(skip: int) -> void:
	# 오늘 내가 안 만난 팀들끼리 붙입니다. **결과만 세고 경기 기록은 버립니다** —
	# 여덟 팀의 이닝별 기록까지 들고 있을 이유가 없습니다.
	var idx: Array = []
	for i in range(Sv.league.size()):
		if i != skip:
			idx.append(i)
	_shuffle(idx)
	var k := 0
	while k + 1 < idx.size():
		var a := int(idx[k])
		var b := int(idx[k + 1])
		var g := Sim.play(ai_team(a, Sv.game_no), ai_team(b, Sv.game_no), rng)
		var w := int(g["winner"])
		if w == 0:
			(Sv.league[a] as Dictionary)["w"] = int((Sv.league[a] as Dictionary)["w"]) + 1
			(Sv.league[b] as Dictionary)["l"] = int((Sv.league[b] as Dictionary)["l"]) + 1
		elif w == 1:
			(Sv.league[b] as Dictionary)["w"] = int((Sv.league[b] as Dictionary)["w"]) + 1
			(Sv.league[a] as Dictionary)["l"] = int((Sv.league[a] as Dictionary)["l"]) + 1
		else:
			(Sv.league[a] as Dictionary)["d"] = int((Sv.league[a] as Dictionary).get("d", 0)) + 1
			(Sv.league[b] as Dictionary)["d"] = int((Sv.league[b] as Dictionary).get("d", 0)) + 1
		k += 2

# ── 순위표 ─────────────────────────────────────────────────────────────────

func standings() -> Array:
	# [{name, w, l, pct, gb, mine}] — 승률 내림차순. 1위와의 게임차까지 냅니다.
	var rows: Array = [{"name": D.MY_TEAM, "w": Sv.my_w, "l": Sv.my_l, "d": Sv.my_d, "mine": true}]
	for e in Sv.league:
		rows.append({"name": str(e["name"]), "w": int(e["w"]), "l": int(e["l"]), "d": int(e.get("d", 0)), "mine": false})
	for r in rows:
		var n: int = int(r["w"]) + int(r["l"])
		r["pct"] = 0.0 if n == 0 else float(r["w"]) / float(n)
	rows.sort_custom(func(a, b):
		if not is_equal_approx(float(a["pct"]), float(b["pct"])):
			return float(a["pct"]) > float(b["pct"])
		return int(a["w"]) > int(b["w"]))
	# 게임차 = ((1위 승 − 내 승) + (내 패 − 1위 패)) ÷ 2
	var top: Dictionary = rows[0]
	for r in rows:
		r["gb"] = ((int(top["w"]) - int(r["w"])) + (int(r["l"]) - int(top["l"]))) * 0.5
	return rows

func my_rank() -> int:
	var rows := standings()
	for i in range(rows.size()):
		if bool(rows[i]["mine"]):
			return i + 1
	return rows.size()

func finish_season() -> Dictionary:
	# 순위 보상 + 승격/강등. **위 등급일수록 보상이 큽니다** — 올라갈 이유가
	# 난이도만 오르는 것이면 아무도 안 올라갑니다.
	var rank := my_rank()
	var mult := 1.0 + float(Sv.tier) * 0.7
	var bonus := int(D.RANK_BONUS[clampi(rank - 1, 0, D.RANK_BONUS.size() - 1)] * mult)
	Sv.coins += bonus

	var total := D.TIERS.size()
	var moved := 0                     # +1 승격 · -1 강등 · 0 잔류
	if rank <= D.PROMOTE_TOP and Sv.tier < total - 1:
		Sv.tier += 1
		moved = 1
	elif rank > D.LEAGUE_NAMES.size() + 1 - D.RELEGATE_BOTTOM and Sv.tier > 0:
		Sv.tier -= 1
		moved = -1

	var out := {"rank": rank, "bonus": bonus, "w": Sv.my_w, "l": Sv.my_l,
		"season": Sv.season, "moved": moved, "tier": Sv.tier}
	Sv.save_game()
	return out
