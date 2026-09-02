extends Node
# 프야매 — 팀컬러. 오토로드(`Col`)입니다.
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
# **단일팀 · 단일연도 · 왕조 · 듀얼팀은 오더 25명을 다 채워야 켜집니다.**
# 예전에는 4·6·8명 계단이었는데, 그러면 아홉 명짜리 타순의 절반만 맞춰도
# 켜져서 "팀컬러를 노리고 모은다"가 아니라 **어쩌다 켜지는 것**이 됐습니다.
# 전부 아니면 아무것도 아니게 두면 목표가 분명해지고, 그만큼 크게 줄 수 있습니다.
#
# 오더 25칸 = 타순 9 + 벤치 5 + 선발 5 + 중계 4 + 셋업 1 + 마무리 1.
# **`D` 의 칸 수에서 계산합니다** — 상수로 박아 두면 오더 구성이 바뀔 때 어긋납니다.
const DUAL_EACH := 12   # 듀얼팀은 두 구단이 이만큼씩 (12 + 12 + 아무나 1)

func roster_size() -> int:
	return D.LINEUP + D.BENCH + D.ROT + D.RELIEF + 2

# [야수 보너스, 투수 보너스]. 어려운 순서대로.
#   듀얼팀 < 단일팀 < 단일연도 < 왕조
# 단일연도가 단일팀보다 위인 이유는 **고를 수 있는 카드가 적기 때문**입니다 —
# 한 구단은 27시즌치가 있지만 한 시즌은 열 구단치뿐입니다.
#
# **제일 약한 왕조가 최강 단일구단·단일연도를 이겨야 합니다.** 그게 이 표를 정하는
# 기준입니다. 왕조는 한 구단 한 시즌 안에서 25명을 채워야 해서 평균 OV 가 15 쯤
# 낮고(롯데 2003 이 57.6 · 단일구단 최강이 72.5), COST 도 상한을 한참 못 씁니다
# (133 대 190). 그 손해를 넘어서려면 팀컬러 격차가 그만큼 커야 합니다 —
# 24/18 대 15/11 이던 시절 롯데 2003 왕조가 단일구단에 **36%**, 단일연도에
# **20%** 였습니다.
#
# **여기를 만졌으면 그 세 덱을 다시 붙여 보세요.** 순서만 맞추고 크기를 안 재면
# 조용히 뒤집힙니다.
#
#   왕조 > 단일연도 > 단일팀 > 듀얼팀 > 시대
const B_DYNASTY := [30, 23]
const B_YEAR := [9, 7]
const B_FRANCHISE := [11, 8]
const B_DUAL := [8, 6]

# 시대는 그대로 계단입니다 — **처음 켜 보는 팀컬러**가 하나는 있어야 이 장치가
# 있다는 걸 알게 됩니다. [필요 인원, 야수, 투수].
const T_ERA := [[8, 3, 2], [12, 5, 4]]

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
	var dk2 = _top(dy)
	if dk2 != null:
		var p := str(dk2).split("|")
		out.append(_row("dyn|%s" % dk2, "%s %s 왕조" % [p[1], lineage_label(p[0])],
			G_ROSTER, int(dy[dk2]), full, B_DYNASTY[0], B_DYNASTY[1]))
	var fk = _top(fr)
	if fk != null:
		out.append(_row("fr|%s" % fk, "%s 단일팀" % lineage_label(str(fk)),
			G_ROSTER, int(fr[fk]), full, B_FRANCHISE[0], B_FRANCHISE[1]))
	var yk = _top(yr)
	if yk != null:
		out.append(_row("yr|%s" % yk, "%s 단일연도" % yk,
			G_ROSTER, int(yr[yk]), full, B_YEAR[0], B_YEAR[1]))
	# 듀얼팀 — 두 구단이 DUAL_EACH 명씩. 25명을 두 구단으로만 채우는 셈이라
	# **단일팀보다 쉽고 시대보다 어렵습니다.** 짝은 인원이 많은 둘로 잡습니다.
	var frk: Array = fr.keys()
	frk.sort_custom(func(a, b): return int(fr[a]) > int(fr[b]))
	if frk.size() >= 2:
		var a := str(frk[0])
		var b := str(frk[1])
		# id 는 순서를 타면 안 됩니다 — 인원이 뒤집히면 저장된 선택이 풀립니다.
		var pair: Array = [a, b]
		pair.sort()
		var lo := mini(int(fr[a]), int(fr[b]))
		out.append(_row("dual|%s|%s" % [pair[0], pair[1]],
			"%s·%s 듀얼팀" % [lineage_label(a), lineage_label(b)],
			G_ROSTER, lo, DUAL_EACH, B_DUAL[0], B_DUAL[1],
			"%d명 + %d명 (각 %d 필요)" % [int(fr[a]), int(fr[b]), DUAL_EACH]))
	var ek = _top(er)
	if ek != null:
		var n := int(er[ek])
		var lv := _step(T_ERA, n)
		# 계단이라 **다음 칸을 목표로** 보여 줍니다 — 이미 켜졌으면 그 칸이 목표입니다.
		var need := int(T_ERA[0][0])
		var hb := int(T_ERA[0][1])
		var pb := int(T_ERA[0][2])
		if not lv.is_empty():
			need = int(lv[0])
			hb = int(lv[1])
			pb = int(lv[2])
		out.append(_row("era|%s" % ek, "%s년대" % ek, G_ERA, n, need, hb, pb))

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
	out.append(_row("rec|big", "거포 군단", G_REC, big, 3, 8, 0, "30홈런 %d / 3명" % big))
	out.append(_row("rec|avg", "교타 군단", G_REC, avg, 4, 8, 0, "3할2푼 %d / 4명" % avg))
	out.append(_row("rec|ace", "철벽 선발진", G_REC, ace, 3, 0, 11, "방어율 3.00 %d / 3명" % ace))
	out.append(_row("rec|win", "다승 듀오", G_REC, win, 2, 0, 8, "15승 %d / 2명" % win))
	out.append(_row("rec|pen", "필승조", G_REC, pen, 3, 0, 8, "세이브+홀드 20 %d / 3명" % pen))
	out.append(_row("rec|horse", "이닝 이터", G_REC, horse, 2, 0, 6, "180이닝 %d / 2명" % horse))
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
	out.append(_row("sh|key", "키스톤 콤비", G_SHAPE, keystone, 2, 6, 3,
		"2루·유격 수비 80 이상 %d / 2명" % keystone))
	out.append(_row("sh|glove", "황금 장갑", G_SHAPE, glove, 5, 8, 5,
		"수비 78 이상 %d / 5명" % glove))
	out.append(_row("sh|ex", "올스타", G_SHAPE, ex, 5, 6, 6, "EX %d / 5장" % ex))
	out.append(_row("sh|elite", "국가대표", G_SHAPE, elite, 5, 6, 6,
		"종합 90 이상 %d / 5명" % elite))
	return out

func picked(list: Array, id: String) -> Dictionary:
	# 고른 팀컬러가 아직 조건을 만족하는지. 아니면 빈 사전 — **조용히 다른 걸로
	# 바꾸지 마세요.** 오더를 고쳤을 때 왜 약해졌는지 알 수 있어야 합니다.
	for e in list:
		if str(e["id"]) == id:
			return e
	return {}
