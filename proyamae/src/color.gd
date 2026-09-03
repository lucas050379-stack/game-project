extends Node
# 푸야매 — 팀컬러. 오토로드(`Col`)입니다.
#
# **한 번에 하나만 켭니다.** 조건을 만족한 것들 중에서 오더 화면에서 직접 고릅니다.
# 여러 개가 겹쳐서 쌓이면 팀컬러 하나로 카드 등급 차이가 통째로 지워지고, 무엇을
# 노리고 모으는지도 흐려집니다. 하나만 켜기 때문에 값을 크게 줄 수 있습니다.
#
# **맞추기 어려울수록 크게 줍니다.** 특히 왕조(같은 구단 + 같은 시즌)가 제일
# 큽니다 — 그 시즌 그 구단 안에서만 골라야 해서 **낮은 코스트 카드를 섞을 수밖에
# 없고**, 그 손해가 큰 보너스와 맞물려 균형이 잡힙니다.
#
# **단일 구단 · 단일 시즌만 두지 마세요.** 그것만 있으면 결국 한 구단 한 시즌을
# 모으는 것 말고 할 게 없습니다. 기록 · 포지션 · 시대 · 등급으로도 열리게 해야
# "이 카드들을 왜 같이 쓰는가"라는 이유가 여러 갈래로 생깁니다.
#
# **전신 · 후신 구단은 한 계보로 셉니다.** 해태 카드는 KIA 컬러를 같이 받습니다 —
# 원작이 그렇고, 안 그러면 2000년 해태 38장이 영영 아무 데도 못 낍니다.

const FRANCHISE := {
	"해태": "KIA", "KIA": "KIA",
	"SK": "SSG", "SSG": "SSG",
	"우리": "키움", "히어로즈": "키움", "넥센": "키움", "키움": "키움",
}
const FRANCHISE_LABEL := {
	"KIA": "해태·KIA", "SSG": "SK·SSG", "키움": "히어로즈 계열",
}

func lineage(team: String) -> String:
	return str(FRANCHISE.get(team, team))

func lineage_label(key: String) -> String:
	return str(FRANCHISE_LABEL.get(key, key))

# ── 단계표 ─────────────────────────────────────────────────────────────────
# **원작처럼 인원 계단입니다 — 10명(C) · 20명(B) · 25명(A).**
# 25명을 다 채워야만 켜지게 뒀던 적이 있는데, 그러면 절반쯤 모은 사람에게는
# 팀컬러가 아예 없는 것과 같아서 무엇을 향해 모으는 중인지가 안 보였습니다.
# 계단이면 10명에서 한 번 켜지고, 거기서부터 목표가 생깁니다.
#
# 오더 25칸 = 타순 9 + 벤치 5 + 선발 5 + 중계 4 + 셋업 1 + 마무리 1.
# **`D` 의 칸 수에서 계산합니다** — 상수로 박아 두면 오더 구성이 바뀔 때 어긋납니다.
const DUAL_EACH := 12   # 듀얼팀은 두 구단이 이만큼씩 (12 + 12 + 아무나 1)

func roster_size() -> int:
	return D.LINEUP + D.BENCH + D.ROT + D.RELIEF + 2

# [필요 인원, 야수 보너스, 투수 보너스]. 어려운 순서대로:
#   듀얼팀 < 단일팀 < 단일연도 < 왕조
# 단일연도가 단일팀보다 위인 이유는 **고를 수 있는 카드가 적기 때문**입니다 —
# 한 구단은 27시즌치가 있지만 한 시즌은 열 구단치뿐입니다.
#
# **A(25명) 값은 원작 수치를 그대로 씁니다** — 왕조 17/12 · 듀얼팀 10/5.
# C·B 는 그 35% · 65% 언저리입니다.
#
# **등급 하나하나가 따로 고르는 팀컬러입니다.** 원작이 그렇습니다 — 왕조 25명을
# 채우면 `왕조 S`(25명)와 `왕조 A`(20명)가 **둘 다** 열리고, 팀컬러 칸 두 개에
# 그 둘을 넣어 **합쳐서 17/12** 를 받습니다. 단일구단은 `A`(25명) + `B`(20명) 로
# **합쳐서 10/5** 입니다.
#
# 그래서 표의 값은 **그 등급 하나의 몫**이고, 실제로 받는 것은 위 두 칸의 합입니다:
#   왕조   S 10/7 + A 7/5 = **17/12**
#   단일구단 A 6/3 + B 4/2 = **10/5**
# **한 등급만 보고 "너무 작다"고 올리지 마세요** — 두 칸을 같이 세야 합니다.
#
# 왕조가 다른 갈래를 이기는 몫은 **딱 이 두 합의 차이(+7/+7)** 입니다. 왕조 덱은
# 단일구단·단일연도 조건도 같이 만족하지만, 그건 상대도 자기 것을 받으므로
# 상쇄됩니다 — **그래서 왕조를 세게 만드는 길은 이 표가 아니라 카드 격차를
# 좁히는 것뿐입니다**(`MEAN_FLOOR`).
#
# [필요 인원, 야수, 투수] — 위에서부터 높은 등급.
const T_DYNASTY := [[25, 10, 7], [20, 7, 5], [10, 4, 3]]
const T_FRANCHISE := [[25, 6, 3], [20, 4, 2], [10, 2, 1]]
const T_YEAR := [[25, 6, 3], [20, 4, 2], [10, 2, 1]]
const T_DUAL := [[12, 5, 3], [9, 3, 2], [5, 2, 1]]
# 등급 이름 — 왕조만 S 부터 시작합니다(원작 표기).
const TIER_DYNASTY := ["S", "A", "B"]
const TIER_OTHER := ["A", "B", "C"]

# 시대는 한 줄짜리입니다 — **처음 켜 보는 팀컬러**가 하나는 있어야 이 장치가
# 있다는 걸 알게 됩니다.
const T_ERA := [[12, 2, 2], [8, 1, 1]]

# ── 히든: 알뜰 편성 ────────────────────────────────────────────────────────
# **오더 총 COST 가 낮으면 전 스텟에 조금 붙습니다.** 목록에 안 나오고 고르지도
# 않는 **항상 켜지는** 보너스라 팀컬러 두 칸을 안 먹습니다 — 칸을 차지하게 두면
# 왕조 S·A 보다 작아서 아무도 안 고릅니다.
#
# **상한을 못 쓰는 덱만 골라서 갚아 줍니다.** 왕조는 한 구단 한 시즌에 묶여
# COST 상한(170)에 못 닿는데(138~164, 중앙 150), 단일구단·단일연도는 170 을
# 꽉 채웁니다. 그 손해가 팀컬러 차이(왕조 17/12 대 단일구단 10/5 = +7/+7)보다
# 커서 약한 왕조가 뒤처집니다. 여기가 그 손해를 되돌려 주는 자리입니다.
#
# **계단이라 "일부러 150 에 맞추기"가 생길 수 있습니다.** 지금 값(+1·+2)이면
# 20 COST 를 버리고 얻는 것이 스텟 1~2 뿐이라 손해이므로 왜곡이 없습니다.
# **키울 때는 그 맞바꿈을 다시 세세요** — 20 COST 가 대략 덱 평균 OV 3~4 입니다.
#
# [이 COST 이하면, 야수, 투수]
const BUDGET := [[150, 1, 1], [140, 2, 2]]

func budget_bonus(cost: int) -> Array:
	var hb := 0
	var pb := 0
	for e in BUDGET:
		if cost <= int(e[0]):
			hb = maxi(hb, int(e[1]))
			pb = maxi(pb, int(e[2]))
	return [hb, pb]
# **한 번에 켤 수 있는 개수**(원작과 같이 둘).


# 계단짜리 팀컬러를 **등급마다 한 줄씩** 내놓습니다. 25명을 채웠으면 S 와 A 가
# 둘 다 켜지고, 팀컬러 칸 두 개에 그 둘을 넣어 합을 받습니다.
# 못 켠 등급도 돌려주므로 화면이 "18 / 20명" 처럼 얼마나 남았는지 보여 줍니다.
func _tiers(out: Array, id: String, name: String, group: String, have: int,
		table: Array, names: Array, why: String = "") -> void:
	for i in range(table.size()):
		var e: Array = table[i]
		var need := int(e[0])
		var tg := str(names[mini(i, names.size() - 1)])
		var r := _row("%s|%s" % [id, tg], "%s %s" % [name, tg], group,
			have, need, int(e[1]), int(e[2]), why)
		out.append(r)
const MAX_ACTIVE := 2
func _step(table: Array, n: int) -> Array:
	var best: Array = []
	for e in table:
		if n >= int(e[0]):
			best = e
	return best

func _hit(c: Dictionary) -> bool:
	return str(c.get("kind", "")) != "pitcher"

func _line(c: Dictionary, k: String) -> float:
	return float((c.get("line", {}) as Dictionary).get(k, 0.0))

func _st(c: Dictionary, k: String) -> int:
	return int((c.get("st", {}) as Dictionary).get(k, 0))

# ── 판정 ───────────────────────────────────────────────────────────────────

# ── 판정 ───────────────────────────────────────────────────────────────────
# **`survey()` 하나가 모든 팀컬러를 만들고, `active()` 는 그중 켜진 것만 거릅니다.**
# 둘을 따로 만들면 화면에 보이는 조건과 실제로 붙는 조건이 조용히 갈라집니다 —
# 그러면 "조건을 맞췄는데 왜 안 켜지지"를 영영 못 잡습니다.
#
# 각 항목: {id, name, group, why, have, need, ok, hit, pit}
#   `have`/`need` 가 진행도입니다 — **못 켠 것도 돌려주므로** 화면이
#   "18 / 25" 처럼 얼마나 남았는지 보여 줄 수 있습니다.
#   `id` 는 저장에 쓰이므로 **바꾸지 마세요.** 바꾸면 저장된 선택이 풀립니다.
const G_ROSTER := "구단 · 시즌"
const G_ERA := "시대"
const G_REC := "기록"
const G_SHAPE := "수비 · 등급"

func _row(id: String, name: String, group: String, have: int, need: int,
		hit: int, pit: int, why: String = "") -> Dictionary:
	return {"id": id, "name": name, "group": group, "have": have, "need": need,
		"ok": have >= need, "hit": hit, "pit": pit,
		"why": why if why != "" else "%d / %d명" % [have, need]}

func survey(members: Array, bench: Array = []) -> Array:
	# 모든 팀컬러를 진행도와 함께. `members` 는 경기에 나오는 스무 명,
	# `bench` 는 벤치 다섯입니다.
	#
	# **로스터 컬러(단일팀·단일연도·왕조·듀얼팀)만 벤치를 셉니다** — "오더 25칸을
	# 다 채웠는가"를 묻는 것이라, 벤치를 빼면 20명이 상한이라 영영 안 켜집니다.
	# 기록·수비 컬러는 출전하는 자리만 셉니다.
	var out: Array = []
	var roster: Array = []
	roster.append_array(members)
	roster.append_array(bench)
	var full := roster_size()

	var fr := {}
	var yr := {}
	var dy := {}
	var er := {}
	for c in roster:
		var f := lineage(str(c.get("team", "")))
		var y := int(c.get("year", 0))
		@warning_ignore("integer_division")
		var e := (y / 10) * 10
		fr[f] = int(fr.get(f, 0)) + 1
		yr[y] = int(yr.get(y, 0)) + 1
		var dk := "%s|%d" % [f, y]
		dy[dk] = int(dy.get(dk, 0)) + 1
		er[e] = int(er.get(e, 0)) + 1

	# **가장 많이 모인 것 하나씩만** 내놓습니다. 열 구단 × 27시즌을 다 늘어놓으면
	# 목록이 수백 줄이 되어 "무엇을 노리는 중인가"가 오히려 안 보입니다.
	# 갈래마다 **등급 세 줄**이 나옵니다 — 두 칸에 골라 담는 것이 이 게임의 성장입니다.
	var dk2 = _top(dy)
	if dk2 != null:
		var p := str(dk2).split("|")
		_tiers(out, "dyn|%s" % dk2, "%s %s 왕조" % [p[1], lineage_label(p[0])],
			G_ROSTER, int(dy[dk2]), T_DYNASTY, TIER_DYNASTY)
	var fk = _top(fr)
	if fk != null:
		_tiers(out, "fr|%s" % fk, "%s 단일구단" % lineage_label(str(fk)),
			G_ROSTER, int(fr[fk]), T_FRANCHISE, TIER_OTHER)
	var yk = _top(yr)
	if yk != null:
		_tiers(out, "yr|%s" % yk, "%s 단일연도" % yk,
			G_ROSTER, int(yr[yk]), T_YEAR, TIER_OTHER)
	# 듀얼팀 — 두 구단이 각각 몇 명씩. 짝은 인원이 많은 둘로 잡습니다.
	var frk: Array = fr.keys()
	frk.sort_custom(func(a, b): return int(fr[a]) > int(fr[b]))
	if frk.size() >= 2:
		var a := str(frk[0])
		var b := str(frk[1])
		# id 는 순서를 타면 안 됩니다 — 인원이 뒤집히면 저장된 선택이 풀립니다.
		var pair: Array = [a, b]
		pair.sort()
		var lo := mini(int(fr[a]), int(fr[b]))
		_tiers(out, "dual|%s|%s" % [pair[0], pair[1]],
			"%s·%s 듀얼팀" % [lineage_label(a), lineage_label(b)],
			G_ROSTER, lo, T_DUAL, TIER_OTHER,
			"%d명 + %d명 (적은 쪽 %d)" % [int(fr[a]), int(fr[b]), lo])
	var ek = _top(er)
	if ek != null:
		_tiers(out, "era|%s" % ek, "%s년대" % ek, G_ERA, int(er[ek]), T_ERA, TIER_OTHER)

	out.append_array(_record_colors(members))
	out.append_array(_shape_colors(members))
	return out

# 가장 많이 모인 열쇠. 비었으면 null.
# **열쇠를 문자열로 바꾸면 안 됩니다** — 시즌·시대 사전은 정수로 키를 잡고 있어서,
# 문자열로 돌려주면 되돌아온 값으로 조회가 깨집니다(실제로 그랬습니다).
func _top(d: Dictionary):
	var best = null
	var bi := -1
	for k in d:
		if int(d[k]) > bi:
			bi = int(d[k])
			best = k
	return best

func active(members: Array, bench: Array = []) -> Array:
	# 조건을 만족한 것만, **센 것부터**.
	var out: Array = []
	if members.is_empty():
		return out
	for e in survey(members, bench):
		if bool((e as Dictionary)["ok"]):
			out.append(e)
	out.sort_custom(func(a, b): return int(a["hit"]) + int(a["pit"]) > int(b["hit"]) + int(b["pit"]))
	return out

func _record_colors(members: Array) -> Array:
	# 기록으로 열리는 것들 — 구단도 시즌도 안 봅니다. 시대를 넘어 모으는 재미입니다.
	var out: Array = []
	var big := 0
	var avg := 0
	var ace := 0
	var win := 0
	var pen := 0
	var horse := 0
	for c in members:
		if _hit(c):
			if _line(c, "hr") >= 30.0:
				big += 1
			if _line(c, "avg") >= 0.320:
				avg += 1
		else:
			if _line(c, "era") > 0.0 and _line(c, "era") <= 3.00 and _line(c, "ip") >= 100.0:
				ace += 1
			if _line(c, "w") >= 15.0:
				win += 1
			if _line(c, "sv") + _line(c, "hld") >= 20.0:
				pen += 1
			if _line(c, "ip") >= 180.0:
				horse += 1
	# **못 채운 것도 돌려줍니다** — 화면이 "몇 명 남았나"를 보여 줘야 하니까요.
	out.append(_row("rec|big", "거포 군단", G_REC, big, 3, 3, 0, "30홈런 %d / 3명" % big))
	out.append(_row("rec|avg", "교타 군단", G_REC, avg, 4, 3, 0, "3할2푼 %d / 4명" % avg))
	out.append(_row("rec|ace", "철벽 선발진", G_REC, ace, 3, 0, 3, "방어율 3.00 %d / 3명" % ace))
	out.append(_row("rec|win", "다승 듀오", G_REC, win, 2, 0, 3, "15승 %d / 2명" % win))
	out.append(_row("rec|pen", "필승조", G_REC, pen, 3, 0, 3, "세이브+홀드 20 %d / 3명" % pen))
	out.append(_row("rec|horse", "이닝 이터", G_REC, horse, 2, 0, 2, "180이닝 %d / 2명" % horse))
	return out

func _shape_colors(members: Array) -> Array:
	var out: Array = []
	var ex := 0
	var elite := 0
	var glove := 0
	var keystone := 0
	for c in members:
		if str(c.get("grade", "")) == D.GRADE_EX:
			ex += 1
		if int(c.get("ov", 0)) >= 90:
			elite += 1
		if _hit(c):
			if _st(c, "defense") >= 78:
				glove += 1
			if str(c.get("pos", "")) in ["2루수", "유격수"] and _st(c, "defense") >= 80:
				keystone += 1
	out.append(_row("sh|key", "키스톤 콤비", G_SHAPE, keystone, 2, 2, 1,
		"2루·유격 수비 80 이상 %d / 2명" % keystone))
	out.append(_row("sh|glove", "황금 장갑", G_SHAPE, glove, 5, 2, 1,
		"수비 78 이상 %d / 5명" % glove))
	out.append(_row("sh|ex", "올스타", G_SHAPE, ex, 5, 2, 2, "EX %d / 5장" % ex))
	out.append(_row("sh|elite", "국가대표", G_SHAPE, elite, 5, 2, 2,
		"종합 90 이상 %d / 5명" % elite))
	return out

func picked(list: Array, id: String) -> Dictionary:
	# 고른 팀컬러가 아직 조건을 만족하는지. 아니면 빈 사전 — **조용히 다른 걸로
	# 바꾸지 마세요.** 오더를 고쳤을 때 왜 약해졌는지 알 수 있어야 합니다.
	for e in list:
		if str(e["id"]) == id:
			return e
	return {}

# 고른 것들 중 **아직 조건을 만족하는 것만**, 최대 `MAX_ACTIVE` 개.
func picked_many(list: Array, ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		var e := picked(list, str(id))
		if not e.is_empty():
			out.append(e)
		if out.size() >= MAX_ACTIVE:
			break
	return out
