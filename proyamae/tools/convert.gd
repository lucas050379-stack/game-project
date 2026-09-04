extends SceneTree
# 푸야매 — 원본 기록 → 카드 6스텟 변환 (헤드리스 전용 도구)
#
#   data/raw/<연도>.json  ──▶  data/players/<연도>.json
#
# 핵심은 **상대평가**입니다. 스텟은 그 시즌 리그 안에서의 위치(z-score)로 매깁니다.
# 2014년 리그 타율은 .289 였고 2006년은 .255 였습니다. 타율 .300 을 같은 값으로
# 환산하면 타고투저 시즌 카드가 통째로 세지는데, 한 덱에 45개 시즌이 섞이는
# 게임이라 바로 티가 납니다.
#
# 그리고 **타석·이닝이 적은 선수는 평균 쪽으로 당깁니다**(reg). 6타수 2안타를
# 그대로 환산하면 교타력 90 짜리 백업이 나옵니다.

# ── 변환 수치 (게임이 아니라 도구의 수치라 여기 둡니다) ─────────────────────

const Z_SCALE := 19.0      # z 1 당 몇 점인가
const Z_MID := 50.0        # 리그 평균이 몇 점인가
# **바닥은 실제 카드에 맞춥니다.** 원작 카드의 제일 낮은 칸이 41~47 입니다
# (이승엽 03 번트 41 · 마해영 03 주력 47 · 오승환 08 체력 46). 20 으로 두면
# 특화(`SPEC_GAIN`)가 약한 칸을 바닥까지 밀어붙여 "번트 20" 같은 카드가 나오고,
# 6칸 합이 통째로 눌려서 COST 까지 같이 내려갑니다.
const ST_MIN := 38
const ST_MAX := 99

# **종합이 좋은 선수는 모든 칸이 같이 올라야 합니다.**
# 스텟을 각 항목의 z 로만 매기면 잘하는 선수도 자기 특기 칸만 높고 나머지는
# 평균이라, 6칸 평균이 씻겨 나가서 COST 1 과 COST 10 이 48.5 대 60.0 밖에
# 차이 나지 않았습니다(한 단계당 +1.3 — 막대로는 안 보입니다).
# 그래서 종합 z 를 각 칸에 나눠 더합니다. 더하는 양은 **그 칸이 종합에서
# 차지하는 비중에 비례**합니다 — 홈런 타자의 번트까지 같이 오르면 곤란하니까요.
# **고코스트 카드의 스텟 격차를 더 벌립니다.** 이 값이 종합 z 를 각 칸에 얼마나
# 실어 주는지를 정합니다 — 키우면 잘하는 선수의 모든 칸이 같이 올라서 COST 가
# 높은 카드가 눈에 띄게 세집니다.
const OVERALL_LIFT := 0.80

# 보직 서열 — 체력은 **선발 > 중계 > 셋업 > 마무리** 로 읽혀야 합니다.
# 기록만으로는 이 순서가 안 나옵니다(등판당 이닝이 셋업 1.31 · 마무리 1.41 로
# 오히려 마무리가 위이고, 바닥 압축까지 걸리면 넷이 55~58 로 뭉칩니다).
#
# **중계에 크게 얹습니다.** 선발이 일찍 강판되면 중계가 여러 이닝을 메워야 하는데,
# 기력이 **체력의 제곱**이라 체력 55(기력 3025)와 75(5625)는 소화 이닝이 1.9배
# 차이입니다. 선발도 같이 올려 서열을 지킵니다.
# **경기에 영향이 없는 조정이 아닙니다** — 여기를 만졌으면 `--simtest` 의
# 완투율과 중계 등판율을 다시 재세요.
# **중계를 올리지 말고 셋업·마무리를 내려 서열을 만듭니다.** 중계를 올리면 선발도
# 같이 올려야 서열이 유지되는데, 기력이 제곱이라 선발이 훨씬 깊게 가서
# **중계가 오히려 덜 나옵니다** — 중계 +20 · 선발 +12 로 잡았더니 중계 등판이
# 0.53 → 0.18회/경기 로 줄고 완투가 13.9% 로 뛰었습니다. 아래로 내리는 쪽이 맞습니다.
# 보직 여유분 — 오더 최소치(선발 5 · 중계 4 · 셋업 1 · 마무리 1)를 채운 뒤
# 한 명씩 더 배정합니다. 목표는 선발 6 · 중계 5 · 셋업 2 · 마무리 2 이고,
# **투수가 15명이 안 되는 구단(242개 중 21개)은 여기까지 못 채웁니다** —
# 그래도 오더 11칸은 항상 채워집니다.
const ROLE_SPARE_ROT := 1
const ROLE_SPARE_SETUP := 1
const ROLE_SPARE_CLOSE := 1
const ROLE_SPARE_RELIEF := 1
# **`D` 를 쓰지 마세요** — 변환기는 `--script` 로 도는데 그 모드에는 오토로드가
# 없어서 `D.ROT` 이 조용히 실패합니다(보직이 옛 방식대로 배정된 채 지나갔습니다).
# 오더 칸 수는 여기에 따로 적습니다. `data.gd` 의 `LINEUP`/`ROT`/`RELIEF` 와 맞추세요.
const ORDER_ROT := 5
const ORDER_RELIEF := 4

const STAM_ROLE := {"선발": 0.0, "중계": -4.0, "셋업": -8.0, "마무리": -11.0}

# 스텟 꼭대기 압축. 종합 보정을 얹으면 상위권이 99 에 몰리므로 여기서 폅니다.
# **꼭대기 압축.** 낮출수록 상위 카드끼리 좁아집니다. 86 이던 시절 COST 7→10 이
# 62.5 → 82.0(3단계에 19.5)으로 벌어져 하위 구간(1→4 가 5.7)과 딴판이었습니다.
const ST_SOFT := 70.0
const ST_SOFT_K := 0.28
# 바닥 압축 — `ST_SOFT` 의 짝입니다. 이 아래는 눌러서 올립니다.
# **0 으로 두면(압축 없음) 약한 구단·시즌의 왕조가 최고 등급에서 통째로 죽습니다.**
# 팀 평균을 리그 평균 쪽으로 당기는 비율. 0.5 면 팀 사이 차이의 절반이 지워집니다 —
# 왕조 덱 COST 폭이 62 → 35 로 줄어듭니다(127~189 → 142~177).
const TEAM_PULL := 0.8

# COST 를 자를 때 **팀 안 등수**를 섞는 비율. 0 이면 전역 등수만 보고, 그러면
# 하위권 구단·시즌에는 높은 COST 카드가 아예 안 생깁니다(242개 왕조 중 63개에
# COST 10 이 없었습니다). 1.0 으로 두지 마세요 — 성적과 COST 의 관계가 끊깁니다.
const TEAM_RANK_MIX := 0.45

# 타자 전체에 얹는 값. 타선이 세지면 선발이 더 자주 강판되어 중계가 살아납니다.
const HIT_LIFT := 3.0

const ST_FLOOR := 48.0
const ST_FLOOR_K := 0.52

# ── 특화 ───────────────────────────────────────────────────────────────────
# **카드 안에서 칸끼리의 차이만 벌리는 손잡이입니다.**
#
# 실제 기록을 시즌 안 z 로 매기면 한 선수의 여섯 칸이 대개 자기 평균 ±0.5σ 안에
# 뭉칩니다. 거기에 `OVERALL_LIFT` 가 여섯 칸을 **같이** 들어 올리고 양 끝을 압축까지
# 하니, 카드 안 최고−최저 폭의 중앙값이 **10** 이었습니다(절반이 폭 10 이하).
# 그러면 수비수든 거포든 막대 여섯 개가 똑같이 생겨서, 어느 카드를 왜 쓰는지가
# COST 숫자 하나로만 읽힙니다.
#
# **그 카드 자신의 평균 둘레로 편차를 곱합니다** — 합이 그대로라 OV·COST 는
# 건드리지 않고 "무엇을 잘하는 선수인가"만 도드라집니다. z 를 통째로 키우는
# (`Z_SCALE`) 쪽은 카드 **사이**의 폭까지 같이 부풀려 COST 사다리가 흔들립니다.
#
# **투수의 체력은 빼고 셉니다.** 체력은 잘하고 못하고가 아니라 보직을 가르는
# 표시라, 평균에 넣으면 마무리(체력 낮음)의 나머지 칸이 통째로 위로 밀립니다.
const SPEC_GAIN := 1.85

# ── 약한 카드의 바닥 ───────────────────────────────────────────────────────
# **카드의 평균만 끌어올리고 칸끼리의 차이는 그대로 둡니다.**
#
# 왕조 덱은 한 구단 한 시즌에 묶여서 약한 카드를 섞을 수밖에 없는데, 그 손해가
# 너무 크면 팀컬러를 아무리 키워도 못 메웁니다 — 실제로 원작 수치(왕조 17/12)를
# 넣었더니 왕조최약이 월드 AI 상대 13% 였습니다. 원작 카드(정현욱 08 평균 78 ·
# 심정수 07 평균 69)를 보면 **값이 전반적으로 높고 바닥이 덜 낮습니다.**
#
# `ST_FLOOR` 는 칸 하나하나를 눌러 올려서 **특화까지 같이 지웁니다**(번트 41 짜리
# 카드가 안 나옵니다). 그래서 이건 칸이 아니라 **카드 평균**에 겁니다 — 약한 카드가
# 통째로 올라가되 "무엇을 잘하는가"는 그대로입니다.
const MEAN_FLOOR := 78.0
const MEAN_FLOOR_K := 0.55

const W_HIT := {"contact": 0.30, "power": 0.28, "speed": 0.14, "bunt": 0.04, "defense": 0.14, "mental": 0.10}
const W_PIT := {"stamina": 0.10, "velo": 0.10, "stuff": 0.24, "breaking": 0.10, "control": 0.22, "mental": 0.24}

const REG_PA := 150.0      # 타자: 이 타석 수에서 절반만 인정
const REG_IP := 40.0       # 투수: 이 이닝에서 절반만 인정
const LEAGUE_MIN_PA := 80  # 리그 평균·편차를 낼 때 이 이상만 셉니다
const LEAGUE_MIN_IP := 20.0

# 포지션 난이도 — 수비력에 더해집니다(수비율만 보면 1루수가 제일 잘합니다).
const POS_HARD := {
	"포수": 1.00, "유격수": 0.92, "2루수": 0.74, "중견수": 0.72,
	"3루수": 0.66, "좌익수": 0.42, "우익수": 0.44, "외야수": 0.50,
	"1루수": 0.20, "지명타자": 0.00, "투수": 0.30,
}

# 등급과 COST 는 종합 능력치에서 나옵니다.
# **등급은 두 가지뿐입니다 — EX 와 NORMAL.** 카드에는 EX 만 표기하고 NORMAL 은
# 아무것도 안 붙입니다. 등급을 다섯 단계로 두면 화면이 등급표가 되어, 정작
# 카드의 세기를 읽는 축(COST 와 스텟)이 묻힙니다.
# **문턱은 OV 분포에 맞춰 잡습니다.** OV 를 확정 스텟의 가중 평균으로 바꾸고
# 바닥 압축(`ST_FLOOR`)을 넣으면서 분포가 통째로 옮겨졌습니다(중앙값 44 → 55).
# 92 를 그대로 두면 EX 가 1만 장 중 28장(0.28%)이 됩니다 — 상위 1.5% 는 OV 86 입니다.
const GRADES := [[82, "EX"], [0, "NORMAL"]]

# 종합을 시즌 안에서 다시 펴는 폭. 스텟(Z_SCALE)보다 크게 잡습니다 —
# 여섯 칸을 평균 내면 값이 가운데로 몰리기 때문입니다.
const OV_SCALE := 16.0
const OV_MID := 52.0
const OV_MIN := 20
const OV_MAX := 99

# 꼭대기는 눌러서 폅니다. 안 그러면 z 가 큰 선수들이 전부 99 에 몰려
# **최상위 카드끼리 구분이 안 됩니다**(107장이 OV99 였습니다).

const OV_SOFT := 84.0
const OV_SOFT_K := 0.45

# 카드로 만들 최소 출장. 이보다 적으면 카드를 안 만듭니다.
const MIN_PA_CARD := 10.0
const MIN_IP_CARD := 10.0

# ── 숫자 읽기 ──────────────────────────────────────────────────────────────

func _num(s) -> float:
	# "-" · "" · null 은 값 없음입니다. NAN 으로 돌려서 평균 계산에서 뺍니다.
	var t := str(s).strip_edges()
	if t == "" or t == "-":
		return NAN
	t = t.replace(",", "")
	if not t.is_valid_float():
		return NAN
	return t.to_float()

func _ip(s) -> float:
	# 이닝은 "129 1/3" · "2/3" · "129" 로 옵니다. 1/3 이닝을 소수로 바꿉니다.
	var t := str(s).strip_edges()
	if t == "" or t == "-":
		return NAN
	var whole := 0.0
	var frac := 0.0
	for part in t.split(" ", false):
		if "/" in part:
			var ab := part.split("/")
			if ab.size() == 2 and str(ab[1]).to_float() != 0.0:
				frac = str(ab[0]).to_float() / str(ab[1]).to_float()
		elif str(part).is_valid_float():
			whole = str(part).to_float()
	return whole + frac

func _fin(v) -> float:
	# JSON 에는 NaN 을 담을 수 없습니다(조용히 null 이 됩니다). 카드에 찍히는
	# 기록 줄은 여기를 통과시켜 0 으로 눌러 둡니다.
	var f := float(v)
	return 0.0 if is_nan(f) or is_inf(f) else f

func _idx(head: Array) -> Dictionary:
	var m := {}
	for i in range(head.size()):
		m[str(head[i])] = i
	return m

func _cell(row: Array, m: Dictionary, key: String) -> String:
	if not m.has(key):
		return ""
	var i: int = m[key]
	return str(row[i]) if i < row.size() else ""

# ── 리그 평균·편차 ─────────────────────────────────────────────────────────

func _stats_of(players: Array, key: String, min_key: String, min_val: float) -> Array:
	# 값이 있고 출장이 충분한 선수만으로 평균과 표준편차를 냅니다.
	var vals: Array = []
	for p in players:
		var v: float = p.get(key, NAN)
		var w: float = p.get(min_key, 0.0)
		if not is_nan(v) and w >= min_val:
			vals.append(v)
	if vals.size() < 5:
		return [0.0, 1.0]
	var sum := 0.0
	for v in vals:
		sum += v
	var mean: float = sum / vals.size()
	var acc := 0.0
	for v in vals:
		acc += (v - mean) * (v - mean)
	var sd: float = sqrt(acc / vals.size())
	if sd < 1e-9:
		sd = 1.0
	return [mean, sd]

func _z(p: Dictionary, key: String, ms: Dictionary, invert: bool = false) -> float:
	var v: float = p.get(key, NAN)
	if is_nan(v):
		return 0.0
	var m: Array = ms[key]
	var z: float = (v - m[0]) / m[1]
	return -z if invert else z

func _rate(p: Dictionary, parts: Array) -> float:
	# parts: [[키, 가중치, 반전여부], ...] 를 섞어 하나의 z 를 만듭니다.
	var z := 0.0
	for e in parts:
		z += float(e[1]) * _z(p, str(e[0]), p["_ms"], bool(e[2]))
	return z

func _to_stat(z: float, reg: float) -> float:
	# **여기서 99 로 자르지 마세요.** 자른 뒤에 종합 보정(lift)을 얹으면 잘하는
	# 선수가 전부 99 에 몰려 최상위끼리 구분이 안 됩니다(테임즈가 교타·장타·주력
	# 모두 99 였습니다). 자르는 것은 `_finish_stat` 한 곳에서만 합니다.
	return Z_MID + Z_SCALE * z * reg


func _pull_team(players: Array) -> void:
	# **팀 평균을 리그 평균 쪽으로 `TEAM_PULL` 만큼 당깁니다.**
	#
	# COST 는 스텟 합의 **백분위(등수)** 라, 스텟을 아무리 눌러도 등수가 그대로여서
	# 왕조 덱의 COST 폭이 안 줄어듭니다(압축을 아무리 세게 해도 62 → 55 가 한계였습니다).
	# 폭을 줄이려면 **팀 사이의 차이 자체**를 줄여야 합니다.
	#
	# **이건 실제 기록에서 벗어나는 조정입니다.** 그 시즌 꼴찌 팀 선수라는 이유로
	# 스텟이 올라갑니다 — 그 대가로 어느 구단·시즌으로 왕조를 맞춰도 쓸 만해집니다.
	# 0 으로 두면 기록 그대로가 되고, 왕조 COST 폭이 127~189 로 돌아갑니다.
	if players.is_empty() or TEAM_PULL <= 0.0:
		return
	var lg := 0.0
	var tm := {}
	for p in players:
		var st: Dictionary = p["st"]
		var s := 0.0
		var c := 0
		for k in st:
			s += float(st[k])
			c += 1
		var m := s / maxf(1.0, float(c))
		lg += m
		var t := str(p.get("team", ""))
		if not tm.has(t):
			tm[t] = [0.0, 0]
		(tm[t] as Array)[0] = float((tm[t] as Array)[0]) + m
		(tm[t] as Array)[1] = int((tm[t] as Array)[1]) + 1
	lg /= float(players.size())
	for p in players:
		var e: Array = tm[str(p.get("team", ""))]
		var adj: float = (lg - float(e[0]) / float(e[1])) * TEAM_PULL
		var st2: Dictionary = p["st"]
		for k in st2:
			st2[k] = clampi(int(round(float(st2[k]) + adj)), ST_MIN, ST_MAX)
func _finish_stat(v: float) -> int:
	# 꼭대기를 눌러 폅니다 — 상위권이 99 에 몰려 최상위끼리 구분이 안 되는 것을 막습니다.
	if v > ST_SOFT:
		v = ST_SOFT + (v - ST_SOFT) * ST_SOFT_K
	# **바닥도 눌러 올립니다.** 안 그러면 그 시즌 하위권 구단의 카드가 통째로
	# 밑바닥에 깔려서, 그 구단·시즌으로 왕조를 맞춰도 리그에서 아무것도 못 합니다 —
	# 롯데 2003 왕조가 성장을 다 부어도 월드 시리즈 **9.7등**이었습니다.
	# 위(`ST_SOFT`)와 짝입니다: 양 끝을 눌러야 카드 사이의 폭이 한쪽으로 안 쏠립니다.
	if v < ST_FLOOR:
		v = ST_FLOOR - (ST_FLOOR - v) * ST_FLOOR_K
	return clampi(int(round(v)), ST_MIN, ST_MAX)

# ── 타자 ───────────────────────────────────────────────────────────────────

func _build_hitters(tb: Dictionary, year: int) -> Array:
	var by := {}   # 이름/팀 → 선수

	var h1 = tb.get("hit1", null)
	if h1 == null:
		return []
	var m1 := _idx(h1["head"])
	for r in h1["rows"]:
		var key := "%s/%s" % [_cell(r, m1, "선수명"), _cell(r, m1, "팀명")]
		var pa := _num(_cell(r, m1, "PA"))
		var ab := _num(_cell(r, m1, "AB"))
		var g := _num(_cell(r, m1, "G"))
		if is_nan(pa) or pa <= 0:
			continue
		# **순장타율은 hit1 의 루타(TB)로 냅니다.** hit2 의 SLG 로 내면 구형
		# 시즌(BasicOld)에는 그 열이 없어 장타력이 통째로 평균이 됩니다.
		# 그런데 2001년 이전에는 `Basic1` 마저 구형 표라 루타도 없습니다 —
		# 안타·2루타·3루타·홈런으로 직접 냅니다(TB = H + 2B + 2×3B + 3×HR).
		var tb_ := _num(_cell(r, m1, "TB"))
		if is_nan(tb_):
			var _h := _num(_cell(r, m1, "H"))
			var _d2 := _num(_cell(r, m1, "2B"))
			var _d3 := _num(_cell(r, m1, "3B"))
			var _hr := _num(_cell(r, m1, "HR"))
			if not (is_nan(_h) or is_nan(_d2) or is_nan(_d3) or is_nan(_hr)):
				tb_ = _h + _d2 + 2.0 * _d3 + 3.0 * _hr
		var avg := _num(_cell(r, m1, "AVG"))
		var slg: float = tb_ / ab if (ab > 0 and not is_nan(tb_)) else NAN
		by[key] = {
			"name": _cell(r, m1, "선수명"), "team": _cell(r, m1, "팀명"),
			"pa": pa, "ab": ab, "g": max(g, 1.0),
			"avg": avg, "slg": slg, "h": _num(_cell(r, m1, "H")), "sf": _num(_cell(r, m1, "SF")),
			"iso": slg - avg if not (is_nan(slg) or is_nan(avg)) else NAN,
			"hr_pa": _num(_cell(r, m1, "HR")) / pa,
			"tri_pa": _num(_cell(r, m1, "3B")) / pa,
			"sac_g": _num(_cell(r, m1, "SAC")) / max(g, 1.0),
		}

	var h2 = tb.get("hit2", null)
	if h2 != null:
		var m2 := _idx(h2["head"])
		for r in h2["rows"]:
			var key := "%s/%s" % [_cell(r, m2, "선수명"), _cell(r, m2, "팀명")]
			if not by.has(key):
				continue
			var p: Dictionary = by[key]
			var avg: float = p["avg"]
			var bb := _num(_cell(r, m2, "BB"))
			var hbp := _num(_cell(r, m2, "HBP"))
			p["so_pa"] = _num(_cell(r, m2, "SO")) / p["pa"]
			p["bb_pa"] = bb / p["pa"]
			# OPS 는 표에 있으면 그대로 쓰고, 없으면(구형 BasicOld) 직접 냅니다.
			var ops := _num(_cell(r, m2, "OPS"))
			if is_nan(ops):
				# 구형 표에는 희생플라이가 없습니다 — 분모에서 빼고 냅니다.
				var sf: float = float(p["sf"])
				if is_nan(sf):
					sf = 0.0
				var denom: float = float(p["ab"]) + bb + hbp + sf
				if denom > 0 and not is_nan(bb) and not is_nan(hbp) and not is_nan(float(p["slg"])):
					ops = (float(p["h"]) + bb + hbp) / denom + float(p["slg"])
			p["ops"] = ops
			# 정신력의 뼈대 — 득점권에서 얼마나 더 치는가.
			# **구형 표에는 득점권 타율이 없습니다.** 그러면 정신력은 OPS 만으로
			# 나고, 그 시즌 선수들은 이 칸의 폭이 좁아집니다(README 에 적어 뒀습니다).
			var risp := _num(_cell(r, m2, "RISP"))
			p["clutch"] = risp - avg if not (is_nan(risp) or is_nan(avg)) else NAN
			# 구형 표에는 도루·실책이 여기 붙어 있습니다 — 주루/수비 표가 없는
			# 2000 시즌은 이걸로 주력과 수비력을 냅니다.
			var sb := _num(_cell(r, m2, "SB"))
			if not is_nan(sb):
				p["sb_g"] = sb / float(p["g"])
				var cs := _num(_cell(r, m2, "CS"))
				var att := sb + cs
				if att > 0:
					p["sb_pct"] = (sb / att * 100.0) * (att / (att + 8.0))
			var err := _num(_cell(r, m2, "E"))
			if not is_nan(err):
				p["err_g"] = err / float(p["g"])

	var rn = tb.get("run", null)
	if rn != null:
		var mr := _idx(rn["head"])
		for r in rn["rows"]:
			var key := "%s/%s" % [_cell(r, mr, "선수명"), _cell(r, mr, "팀명")]
			if not by.has(key):
				continue
			var p: Dictionary = by[key]
			var g: float = p["g"]
			p["sb_g"] = _num(_cell(r, mr, "SB")) / g
			var sba := _num(_cell(r, mr, "SBA"))
			# 시도가 적으면 성공률은 뜻이 없습니다 — 시도 수로 눌러 둡니다.
			var pct := _num(_cell(r, mr, "SB%"))
			p["sb_pct"] = pct * (sba / (sba + 8.0)) if not (is_nan(pct) or is_nan(sba)) else NAN

	var df = tb.get("def", null)
	if df != null:
		var md := _idx(df["head"])
		for r in df["rows"]:
			var key := "%s/%s" % [_cell(r, md, "선수명"), _cell(r, md, "팀명")]
			if not by.has(key):
				continue
			var p: Dictionary = by[key]
			var inn := _ip(_cell(r, md, "IP"))
			if is_nan(inn) or inn <= 0:
				continue
			# **투수 줄은 건너뜁니다.** 야수 카드의 수비 위치를 정하는 자리라,
			# 점수 차가 벌어져 한 이닝 던진 야수까지 투수가 되면 안 됩니다.
			if _cell(r, md, "POS") == "투수" or _cell(r, md, "POS") == "P":
				continue
			# 한 선수가 여러 포지션에 나옵니다. **가장 오래 선 자리**를 주 포지션으로 씁니다.
			if inn <= p.get("def_ip", 0.0):
				continue
			p["def_ip"] = inn
			p["pos"] = _cell(r, md, "POS")
			p["fpct"] = _num(_cell(r, md, "FPCT"))
			p["range"] = (_num(_cell(r, md, "PO")) + _num(_cell(r, md, "A"))) / inn * 9.0
			p["pos_hard"] = float(POS_HARD.get(p["pos"], 0.4))

	# 수비 표가 없는 시즌은 **다른 데서 그 선수가 주로 섰던 자리**를 빌립니다.
	# 포지션이 없으면 전원이 지명타자가 되어 오더를 짤 수가 없습니다.
	#
	# **그 해 것을 먼저 봅니다.** 전 시즌을 합친 표는 동명이인이 한 칸에 뭉치므로
	# 마지막 수단으로만 씁니다.
	for k in by:
		var p: Dictionary = by[k]
		if p.has("pos"):
			continue
		var ky := "%d|%s|%s" % [year, str(p.get("team", "")), str(p["name"])]
		var got := str(pos_map_y.get(ky, ""))
		if got == "":
			got = str(pos_map.get(str(p["name"]), ""))
		# **야수 카드는 투수도 지명타자도 될 수 없습니다.**
		# 투수는 야수 카드의 자리가 아니고, **지명타자는 "수비를 안 한다"는 뜻이라
		# 카드의 포지션이 아니라 타순의 한 자리**입니다 — 지명타자 카드라는 것은
		# 없습니다. 수비 기록을 한 시즌도 못 찾은 선수는 **1루수**로 둡니다.
		# 수비 부담(`POS_HARD`)이 제일 낮은 자리라 "수비 기록이 없다"와 가장 가깝습니다.
		if got == "" or got == "투수" or got == "P" or got == "지명타자":
			got = "1루수"
		p["pos"] = got

	var out: Array = []
	for k in by:
		out.append(by[k])
	return out

# 이름 → 그 선수가 가장 오래 선 자리. 모든 시즌의 수비 표를 합쳐서 만듭니다.
var pos_map: Dictionary = {}      # 이름 → 자리 (전 시즌 합산, 마지막 수단)
var pos_map_y: Dictionary = {}    # "연도|구단|이름" → 자리 (그 해 것 — 이쪽이 먼저)

func _build_pos_map(years: Array) -> void:
	# 수비 표에서 "그 선수가 주로 섰던 자리"를 뽑습니다. **두 갈래로 만듭니다** —
	# 그 해 것(`pos_map_y`)을 먼저 보고, 그 해 수비 표가 없으면 전 시즌을 합친
	# 것(`pos_map`)으로 넘어갑니다.
	#
	# **이름만으로 묶으면 안 됩니다.** 동명이인이 27시즌에 걸쳐 한 칸에 합쳐지는데,
	# 투수는 어느 야수보다도 이닝이 많아서 **합치면 언제나 투수가 이깁니다** —
	# 2000년 스미스(35홈런 타자)가 투수로 들어가 있던 것이 이것입니다.
	var acc := {}
	var acc_y := {}
	for y in years:
		var path := "res://data/raw/%d.json" % int(y)
		if not FileAccess.file_exists(path):
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		f.close()
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var t = (d.get("tables", {}) as Dictionary).get("def", null)
		if t == null:
			continue
		var m := _idx(t["head"])
		for r in t["rows"]:
			var nm := _cell(r, m, "선수명")
			var ps := _cell(r, m, "POS")
			var inn := _ip(_cell(r, m, "IP"))
			if nm == "" or ps == "" or is_nan(inn):
				continue
			# **투수는 세지 않습니다.** 이 표는 야수 카드의 수비 위치를 정하는
			# 데만 쓰이고, 투수 카드는 등판 기록에서 따로 역할을 받습니다.
			if ps == "투수" or ps == "P":
				continue
			# 그 해 것은 **이름 + 구단**으로 묶습니다 — 한 시즌 안에서도 같은
			# 이름이 두 구단에 있을 수 있습니다.
			var tm := _cell(r, m, "팀명")
			var ky := "%d|%s|%s" % [int(y), tm, nm]
			if not acc_y.has(ky):
				acc_y[ky] = {}
			acc_y[ky][ps] = float((acc_y[ky] as Dictionary).get(ps, 0.0)) + inn
			if not acc.has(nm):
				acc[nm] = {}
			acc[nm][ps] = float((acc[nm] as Dictionary).get(ps, 0.0)) + inn
	pos_map.clear()
	pos_map_y.clear()
	for nm in acc:
		var b := _most(acc[nm])
		if b != "":
			pos_map[nm] = b
	for ky in acc_y:
		var b2 := _most(acc_y[ky])
		if b2 != "":
			pos_map_y[ky] = b2

func _most(d: Dictionary) -> String:
	var best := ""
	var bi := -1.0
	for k in d:
		if float(d[k]) > bi:
			bi = float(d[k])
			best = str(k)
	return best

func _rate_hitters(players: Array) -> void:
	var keys := ["avg", "so_pa", "iso", "hr_pa", "sb_g", "sb_pct", "tri_pa",
		"sac_g", "fpct", "range", "clutch", "ops", "err_g"]
	var ms := {}
	for k in keys:
		ms[k] = _stats_of(players, k, "pa", float(LEAGUE_MIN_PA))
	for p in players:
		p["_ms"] = ms
		var reg: float = p["pa"] / (p["pa"] + REG_PA)
		var st := {
			"contact": _to_stat(_rate(p, [["avg", 0.65, false], ["so_pa", 0.35, true]]), reg),
			"power": _to_stat(_rate(p, [["iso", 0.60, false], ["hr_pa", 0.40, false]]), reg),
			"speed": _to_stat(_rate(p, [["sb_g", 0.55, false], ["sb_pct", 0.25, false], ["tri_pa", 0.20, false]]), reg),
			"bunt": _to_stat(_rate(p, [["sac_g", 1.0, false]]), reg),
			# 수비는 타석이 아니라 수비 이닝으로 눌러야 합니다.
			"defense": 0,
			"mental": _to_stat(_rate(p, [["clutch", 0.60, false], ["ops", 0.40, false]]), reg),
		}
		var dip: float = p.get("def_ip", 0.0)
		if dip > 0.0:
			var dreg: float = dip / (dip + 200.0)
			var dz := _rate(p, [["fpct", 0.45, false], ["range", 0.35, false]]) + 0.9 * float(p.get("pos_hard", 0.4))
			st["defense"] = _to_stat(dz, dreg)
		elif not is_nan(float(p.get("err_g", NAN))):
			# 수비 표가 없는 시즌(2000)은 구형 표의 실책만으로 냅니다.
			# 자리 난이도를 못 보므로 폭이 좁습니다 — 그래도 전원 최저점보다는 낫습니다.
			var greg: float = float(p["g"]) / (float(p["g"]) + 40.0)
			st["defense"] = _to_stat(_rate(p, [["err_g", 1.0, true]]), greg)
		else:
			st["defense"] = float(ST_MIN)
		p["st"] = st
		p.erase("_ms")

# ── 투수 ───────────────────────────────────────────────────────────────────

func _build_pitchers(tb: Dictionary) -> Array:
	var by := {}
	var p1 = tb.get("pit1", null)
	if p1 == null:
		return []
	var m1 := _idx(p1["head"])
	for r in p1["rows"]:
		var key := "%s/%s" % [_cell(r, m1, "선수명"), _cell(r, m1, "팀명")]
		var inn := _ip(_cell(r, m1, "IP"))
		var g := maxf(_num(_cell(r, m1, "G")), 1.0)
		if is_nan(inn) or inn <= 0:
			continue
		by[key] = {
			"name": _cell(r, m1, "선수명"), "team": _cell(r, m1, "팀명"),
			"ip": inn, "g": g, "ip_g": inn / g,
			"w": _num(_cell(r, m1, "W")), "l": _num(_cell(r, m1, "L")),
			"sv": _num(_cell(r, m1, "SV")), "hld": _num(_cell(r, m1, "HLD")),
			"era": _num(_cell(r, m1, "ERA")),
			"whip": _num(_cell(r, m1, "WHIP")),
			"k9": _num(_cell(r, m1, "SO")) / inn * 9.0,
			"bb9": _num(_cell(r, m1, "BB")) / inn * 9.0,
			"hr9": _num(_cell(r, m1, "HR")) / inn * 9.0,
		}
		var bb := _num(_cell(r, m1, "BB"))
		by[key]["kbb"] = _num(_cell(r, m1, "SO")) / max(bb, 1.0)
		# 구형 표에는 WHIP 이 없습니다 — (피안타+볼넷) ÷ 이닝 으로 냅니다.
		if is_nan(by[key]["whip"]):
			var hh := _num(_cell(r, m1, "H"))
			if not (is_nan(hh) or is_nan(bb)):
				by[key]["whip"] = (hh + bb) / inn
		by[key]["h_allowed"] = _num(_cell(r, m1, "H"))
		by[key]["bb_allowed"] = bb
		by[key]["hbp_allowed"] = _num(_cell(r, m1, "HBP"))
		by[key]["tbf1"] = _num(_cell(r, m1, "TBF"))

	var p2 = tb.get("pit2", null)
	if p2 != null:
		var m2 := _idx(p2["head"])
		for r in p2["rows"]:
			var key := "%s/%s" % [_cell(r, m2, "선수명"), _cell(r, m2, "팀명")]
			if not by.has(key):
				continue
			var p: Dictionary = by[key]
			# 구형 표에는 피안타율이 없습니다 — 상대한 타자 수에서 볼넷·사구를
			# 빼고 피안타로 나누면 거의 같은 값이 나옵니다.
			var oavg := _num(_cell(r, m2, "AVG"))
			if is_nan(oavg):
				var tbf: float = float(p.get("tbf1", NAN))
				var denom: float = tbf - float(p.get("bb_allowed", 0.0)) - float(p.get("hbp_allowed", 0.0))
				if not is_nan(denom) and denom > 0:
					oavg = float(p.get("h_allowed", 0.0)) / denom
			p["oavg"] = oavg
			p["cg"] = _num(_cell(r, m2, "CG")) + _num(_cell(r, m2, "SHO"))
			p["qs_g"] = _num(_cell(r, m2, "QS")) / p["g"]
			# 폭투가 많다 = 각이 크다. 변화구의 보조 신호로만 씁니다.
			p["wp9"] = _num(_cell(r, m2, "WP")) / p["ip"] * 9.0

	var out: Array = []
	for k in by:
		out.append(by[k])
	# **보직은 카드로 살아남는 투수에게만 배정합니다.** 여기서 미리 나누면
	# `MIN_IP_CARD` 로 걸러진 뒤 정원이 깨집니다 — 18명에게 나눠 놓고 12명만
	# 카드가 되면 선발 6·중계 3 처럼 오더를 못 채우는 조합이 남습니다.
	var keep: Array = []
	for p in out:
		if float((p as Dictionary)["ip"]) >= MIN_IP_CARD:
			keep.append(p)
	_assign_roles(keep)
	for p in out:
		if not (p as Dictionary).has("role"):
			(p as Dictionary)["role"] = "중계"
	return out

func _assign_roles(players: Array) -> void:
	# **보직은 구단 안에서 기록 순위로 나눕니다.**
	#
	# 예전에는 절대 문턱이었습니다 — 등판당 3.5이닝이면 선발, 세이브 5면 마무리,
	# 홀드 5면 셋업, 나머지는 중계. 그러면 **한 구단에 그 보직이 통째로 없는 일이
	# 생깁니다**: 2000년대 초반은 홀드 기록이 드물어 셋업이 0명이고 중계가 15명인
	# 팀이 나왔고(SK 2000 은 선발이 1명), 왕조를 짤 수 있는 242개 구단·시즌 중
	# **74개(31%)가 오더의 투수 11칸을 못 채웠습니다.**
	#
	# 순서가 중요합니다 — **오더 최소치를 먼저 채우고**(선발 5 · 중계 4 · 셋업 1 ·
	# 마무리 1 = 11칸) 남는 인원으로 여유분까지 채웁니다. 반대로 하면 투수가
	# 12명뿐인 구단에서 선발만 6명이 되고 중계가 2명이 되어 오더가 안 짜집니다.
	var by_team := {}
	for p in players:
		var t := str(p.get("team", ""))
		if not by_team.has(t):
			by_team[t] = []
		(by_team[t] as Array).append(p)
	for t in by_team:
		var arr: Array = by_team[t]
		var left := arr.duplicate()
		# **중계 정원을 먼저 떼어 둡니다.** 안 그러면 투수가 12명뿐인 구단에서
		# 선발을 6명 채우느라 중계가 3명이 되어 오더의 4칸을 못 메웁니다
		# (실제로 242개 중 8개가 그렇게 나왔습니다).
		var take := func(key: String, n: int, role: String, keep: int) -> void:
			if n <= 0 or left.is_empty():
				return
			var room: int = left.size() - keep
			var cnt: int = mini(n, room)
			if cnt <= 0:
				return
			left.sort_custom(func(a, b): return float(a.get(key, 0.0)) > float(b.get(key, 0.0)))
			for i in range(cnt):
				(left[i] as Dictionary)["role"] = role
			for i in range(cnt):
				left.remove_at(0)
		# 1) 오더 최소치 — 중계 칸은 남겨 둡니다.
		take.call("ip_g", ORDER_ROT, "선발", ORDER_RELIEF)
		take.call("sv", 1, "마무리", ORDER_RELIEF)
		take.call("hld", 1, "셋업", ORDER_RELIEF)
		# 2) 여유분 — 중계도 목표치(D.RELIEF + 여유)만큼 남기고 가져갑니다.
		var keep2: int = ORDER_RELIEF + ROLE_SPARE_RELIEF
		take.call("ip_g", ROLE_SPARE_ROT, "선발", keep2)
		take.call("sv", ROLE_SPARE_CLOSE, "마무리", keep2)
		take.call("hld", ROLE_SPARE_SETUP, "셋업", keep2)
		# 3) 나머지는 전부 중계
		for p in left:
			(p as Dictionary)["role"] = "중계"


# 투수 정신력의 가중치. **퀄리티스타트는 선발만의 기록입니다** — 20% 를 그대로
# 두면 불펜은 그 몫을 통째로 0 으로 받아 조용히 깎입니다. 실제로 정우영 22'
# (35홀드 · ERA 2.64)가 C5, ERA 3.00 이하로 45경기 이상 던진 중계의 59% 가
# C7 미만이었습니다.
#
# 그래서 **선발로 나온 만큼만** QS 를 보고, 나머지는 방어율·WHIP 으로 채웁니다.
# 등판당 이닝(`ip_g`)이 1.5 이하면 순수 불펜(0), 4.0 이상이면 순수 선발(1)입니다.
# 세 가중치의 합은 어느 쪽이든 1.0 입니다.
func _mental_parts(p: Dictionary) -> Array:
	var sp := clampf((float(p.get("ip_g", 0.0)) - 1.5) / 2.5, 0.0, 1.0)
	return [
		["era", 0.50 + 0.125 * (1.0 - sp), true],
		["whip", 0.30 + 0.075 * (1.0 - sp), true],
		["qs_g", 0.20 * sp, false],
	]

func _rate_pitchers(players: Array) -> void:
	var keys := ["ip_g", "ip", "cg", "k9", "oavg", "hr9", "wp9", "bb9", "kbb",
		"era", "whip", "qs_g"]
	var ms := {}
	for k in keys:
		ms[k] = _stats_of(players, k, "ip", LEAGUE_MIN_IP)
	for p in players:
		p["_ms"] = ms
		var reg: float = p["ip"] / (p["ip"] + REG_IP)
		p["st"] = {
			# 체력 = **등판당 이닝**이 거의 전부입니다. 총 이닝을 크게 보면 60경기에
			# 나온 마무리가 롱릴리프보다 체력이 높게 나와서, 선발 > 중계 > 셋업 >
			# 마무리 라는 보직 서열이 뒤집힙니다(실제로 중계가 제일 낮았습니다).
			# 한 번 올라가 몇 이닝을 던지느냐가 곧 이 스텟의 뜻입니다.
			"stamina": _to_stat(_rate(p, [["ip_g", 0.80, false], ["cg", 0.12, false], ["ip", 0.08, false]]), reg),
			# 구속은 실측이 없어 K/9 로 대용합니다. README 에 명시돼 있습니다.
			"velo": _to_stat(_rate(p, [["k9", 1.0, false]]), reg),
			"stuff": _to_stat(_rate(p, [["oavg", 0.50, true], ["hr9", 0.50, true]]), reg),
			"breaking": _to_stat(_rate(p, [["k9", 0.70, false], ["wp9", 0.30, false]]), reg),
			"control": _to_stat(_rate(p, [["bb9", 0.60, true], ["kbb", 0.40, false]]), reg),
			"mental": _to_stat(_rate(p, _mental_parts(p)), reg),
		}
		p.erase("_ms")

# ── 종합·등급 ──────────────────────────────────────────────────────────────

func _overall(st: Dictionary, kind: String) -> int:
	# 번트와 정신력은 종합에서 가볍게 봅니다 — 카드 세기를 정하는 건
	# 결국 치고 달리고 막는 것입니다.
	var w: Dictionary = W_HIT if kind == "hitter" else W_PIT
	var s := 0.0
	for k in w:
		s += float(st[k]) * float(w[k])
	return int(round(s))

func _grade(ov: int) -> String:
	for g in GRADES:
		if ov >= int(g[0]):
			return str(g[1])
	return "NORMAL"

# ── COST 재배정 ────────────────────────────────────────────────────────────
# **COST 는 OV 를 선형으로 자르지 않고 백분위로 나눕니다.**
#
# OV 분포는 40~44 에 몰린 산 모양이라, `(ov-45)/5` 같은 선형 식으로 자르면
# **절반이 COST 1** 이 됩니다(실측 5354장 / 10014장). 그러면 COST 상한 180 이
# 아무것도 제약하지 않아서, 왕조·단일팀처럼 **좁은 풀에서 골라야 하는 덱의
# 손해가 사라집니다** — 낮은 코스트를 섞어도 아프지 않으니까요.
#
# 아래 몫대로 잘라 **가운데가 두꺼운 종 모양**으로 만듭니다. 합은 100 입니다.
# 위쪽을 조금 얇게 둔 것은 고코스트 카드가 여전히 귀해야 하기 때문입니다.
# **7코 이상을 30%% → 25%% 로 줄였습니다**(12+9+6+3 → 10+7+5+3). 줄인 5%% 는
# 가운데로 돌려서 종 모양이 더 뾰족해집니다 — 좋은 카드가 귀할수록 COST 상한
# 안에서 무엇을 넣을지가 더 어려운 선택이 됩니다.
# **COST 6 을 넓게 잡되 5·7 과 나눠 가집니다.** 구간이 넓으면 그 평균이 아래로 끌려
# 6 과 7 사이에 계단이 생기는데, 30%를 몰아 두면 카드의 3분의 1 이 COST 6 이 되어
# 목록이 단조로워집니다. 지금 6칸 평균은
#   48.6 51.0 52.5 53.6 54.7 58.1 │ 64.0 67.2 70.2 75.0
# 이고 계단은 2.4 1.5 1.1 1.1 3.4 │**5.9**│ 3.2 3.0 4.8 — 6→7 이 제일 큽니다.
# **맨 위 구간은 열려 있어 9→10 이 저절로 커집니다**(그래서 `ST_SOFT` 로 꼭대기를
# 눌러 4.8 까지 내렸습니다). 둘은 같이 움직이니 한쪽만 만지지 마세요.
const COST_SHARE := [4, 7, 12, 21, 21, 15, 9, 5, 4, 2]

# ── 주전과 나머지 ──────────────────────────────────────────────────────────
# **왕조 덱은 팀 하나의 위에서부터 25명을 그대로 데려갑니다**(야수 14 · 투수 11).
# 그래서 COST 를 백분위로만 자르면 덱에 싼 카드가 **한 장도** 안 들어옵니다 —
# 덱이 늘 위에서부터 채우기 때문입니다(실측: 왕조 242개 중 싼 야수 5명을 가진
# 곳이 0개, 중앙값 0명). 구단마다 야수가 15~33명으로 제각각이라 "아래 몇 %"
# 로도 못 맞춥니다: 61% 를 싸게 두면 야수 15명인 팀은 덱의 8명이 싸지고
# 33명인 팀은 1명이 싸집니다.
#
# **그래서 비율이 아니라 머릿수로 가릅니다.** 구단마다 야수 위 `CORE_HIT` 명과
# 투수 위 `CORE_PIT` 명이 주전이고 여기서만 높은 COST 가 나옵니다. 야수 14칸 중
# 9칸이 주전이니 **나머지 5칸은 어느 구단에서나 반드시 싼 카드**입니다.
# 투수는 11칸을 다 주전으로 둡니다 — 5선발이 `COST_ROT_MIN` 이상이어야 하고,
# 덱에 싼 카드가 열 장 들어가면 총 COST 가 목표(160~180)에 한참 못 미칩니다.
# `false` 로 두면 머릿수 갈래를 끄고 `COST_SHARE` 하나로 자릅니다 — 사다리는
# 매끄러워지지만 왕조 덱에 싼 야수가 안 들어옵니다. 맞바꿈은 README 를 보세요.
const USE_CORE_SPLIT := false
const CORE_HIT := 9
const CORE_PIT := 11
# 5선발의 COST 바닥. 선발은 기록(등판당 이닝) 순으로 뽑히므로 스텟 합 순서와
# 어긋날 수 있어, 주전 안에서도 아래쪽에 앉는 일이 생깁니다.
const COST_ROT_MIN := 4
# 주전은 COST 4~10, 나머지는 1~3 을 나눠 씁니다. 각각 그 무리 **안에서의**
# 백분위로 자릅니다. 주전 평균이 8 근처여야 덱 25칸이 160~180 에 듭니다
# (주전 20칸 × 8 + 나머지 5칸 × 2 = 170).
const CORE_SHARE := [4, 7, 11, 17, 22, 22, 17]      # C4 … C10
const FRINGE_SHARE := [30, 40, 30]                  # C1 … C3

# COST 를 가르는 자. **6칸 합이 아니라 종합(OV)입니다** — 합으로 자르면 교타·장타가
# 아무리 높아도 수비·주력·번트가 낮은 카드가 싸집니다. 실제 프야매에서 양준혁 03 은
# ★10 인데(교85 장86) 우리는 합으로 잘라 C5 였습니다. 실제 성적과 COST 가 어느 정도
# 맞아야 하므로 OV 로 자릅니다.
#
# **맞바꿈**: 같은 COST 안에서 6칸 합이 벌어집니다 — OV 는 가중합인데(교타 0.30 ·
# 번트 0.04) 화면의 막대 여섯 개는 균등하기 때문입니다. 되돌리려면 `_mix_score` 에서
# `_ov_of` 대신 `_stat_sum` 을 넣으세요.
# 풀타임으로 치는 기준. 이 아래로 내려갈수록 COST 가 깎입니다.
const PLAY_FULL_PA := 450.0   # 타자: 이 타석이면 온전히 인정
const PLAY_FULL_IP := 120.0   # 선발: 이 이닝이면 온전히 인정
# **불펜은 이닝으로 재면 안 됩니다.** 마무리는 아무리 잘해도 50~75이닝이라
# 120 을 자로 쓰면 통째로 깎입니다 — 실제로 30세이브 이상 59명 중 50명이
# COST 7 미만이 됐습니다. 그래서 **등판 경기 수**를 같이 보고 둘 중 큰 쪽을 씁니다.
const PLAY_FULL_G := 50.0     # 불펜: 이 등판이면 온전히 인정
const PLAY_DROP := 16.0       # 거의 안 나온 선수가 잃는 OV

func _play_frac(c: Dictionary) -> float:
	# 출장량 0~1. **`reg`(평균 쪽으로 당기기)와 다른 일을 합니다** — `reg` 는 적은
	# 표본을 못 믿어서 스텟을 가운데로 당기는 것이고, 이건 "덜 나온 선수는 카드로도
	# 덜 값어치 있다" 를 COST 에 적는 것입니다. `reg` 만 있으면 30타석 백업이
	# 여섯 칸 모두 평균이라 **중간 COST** 를 받습니다.
	var ln: Dictionary = c.get("line", {})
	if str(c.get("kind", "")) == "pitcher":
		return clampf(maxf(float(ln.get("ip", 0.0)) / PLAY_FULL_IP,
			float(ln.get("g", 0.0)) / PLAY_FULL_G), 0.0, 1.0)
	return clampf(float(ln.get("pa", 0.0)) / PLAY_FULL_PA, 0.0, 1.0)

func _ov_of(c: Dictionary) -> float:
	# **성적은 올리고, 덜 나온 선수는 내립니다.**
	return float(c.get("ov", 0)) - PLAY_DROP * (1.0 - _play_frac(c))

func _stat_sum(c: Dictionary) -> int:
	# 6칸 합. **COST 를 가르는 자입니다.**
	var s := 0
	var st: Dictionary = c.get("st", {})
	for k in st:
		s += int(st[k])
	return s

func _pct_map(vals: Array) -> Dictionary:
	# 값 → 백분위(0~1). **같은 값은 같은 백분위**입니다 — 등수로 매기면 스텟이
	# 똑같은 두 카드가 다른 COST 를 받습니다.
	var s := vals.duplicate()
	s.sort()
	var m := {}
	for i in range(s.size()):
		if not m.has(s[i]):
			m[s[i]] = float(i) / float(maxi(1, s.size()))
	return m

func _recost() -> void:
	# **모든 시즌 파일을 다 쓴 뒤에 한 번** 돕니다. 한 해만 변환해도 전체를
	# 다시 읽어 같은 자를 씁니다 — 시즌마다 다른 기준으로 자르면 같은 실력의
	# 선수가 해마다 다른 COST 를 받습니다.
	#
	# **자르는 기준은 전역 백분위와 팀 안 백분위를 섞은 값입니다**(`TEAM_RANK_MIX`).
	# 전역 백분위만 쓰면 그 시즌 하위권 구단에는 **높은 COST 카드가 아예 안 생깁니다** —
	# 왕조를 짤 수 있는 242개 구단·시즌 중 63개에 COST 10 이 없고, 8개는 9·10 이
	# 둘 다 없었습니다(롯데 2003 은 최고가 COST 7). 그러면 그 왕조는 COST 상한을
	# 50 넘게 못 쓰고 시작합니다.
	#
	# **팀 안 백분위를 절반 섞어도 카드 순서는 거의 안 바뀝니다** — 2단계 이상
	# 움직이는 카드가 1만 장 중 3장이고, 최고 카드는 그대로 COST 10, 최저는 COST 1
	# 입니다. 약한 팀의 상위 카드만 한 단계 올라갑니다. **1.0 으로 두지 마세요**:
	# 팀 안 등수만 보면 성적과 COST 의 관계가 통째로 끊깁니다.
	var dir := ProjectSettings.globalize_path("res://data/players")
	var d := DirAccess.open(dir)
	if d == null:
		return
	var files: Array = []
	var sums: Array = []
	var by_team := {}
	for fn in d.get_files():
		if not fn.ends_with(".json"):
			continue
		var f := FileAccess.open(dir + "/" + fn, FileAccess.READ)
		var j = JSON.parse_string(f.get_as_text())
		f.close()
		if typeof(j) != TYPE_DICTIONARY:
			continue
		files.append([fn, j])
		for c in (j.get("cards", []) as Array):
			var s := _ov_of(c)
			sums.append(s)
			var k := "%s|%d" % [str(c.get("team", "")), int(c.get("year", 0))]
			if not by_team.has(k):
				by_team[k] = []
			(by_team[k] as Array).append(s)
	if sums.is_empty():
		return
	var gpct := _pct_map(sums)
	var tpct := {}
	for k in by_team:
		tpct[k] = _pct_map(by_team[k])

	# ── 구단·시즌마다 주전을 가릅니다 ──
	# 야수는 스텟 합 위에서 `CORE_HIT` 명, 투수는 `CORE_PIT` 명입니다.
	# **선발은 무조건 주전에 넣습니다** — 선발은 등판당 이닝으로 뽑히므로 스텟 합
	# 순서와 어긋날 수 있는데, 밀려나면 5선발이 싼 카드가 되어 버립니다.
	var groups := {}      # 구단|시즌 → {"hitter": [카드], "pitcher": [카드]}
	for e in files:
		for c in ((e[1] as Dictionary).get("cards", []) as Array):
			var gk := "%s|%d" % [str(c.get("team", "")), int(c.get("year", 0))]
			if not groups.has(gk):
				groups[gk] = {"hitter": [], "pitcher": []}
			var kk := "pitcher" if str(c.get("kind", "")) == "pitcher" else "hitter"
			((groups[gk] as Dictionary)[kk] as Array).append(c)
	for gk in groups:
		var g: Dictionary = groups[gk]
		for kk in g:
			var arr: Array = g[kk]
			arr.sort_custom(func(a, b): return _ov_of(a) > _ov_of(b))
			var want: int = CORE_PIT if kk == "pitcher" else CORE_HIT
			for i in range(arr.size()):
				(arr[i] as Dictionary)["_core"] = i < want
			if kk != "pitcher":
				continue
			# 선발을 끌어올립니다. 자리가 모자라면 주전 중 스텟 합이 가장 낮은
			# 비선발을 대신 내립니다 — 주전 머릿수는 그대로 지킵니다.
			for c in arr:
				if str((c as Dictionary).get("pos", "")) != "선발" or bool(c["_core"]):
					continue
				for i in range(arr.size() - 1, -1, -1):
					var o: Dictionary = arr[i]
					if bool(o["_core"]) and str(o.get("pos", "")) != "선발":
						o["_core"] = false
						c["_core"] = true
						break

	# ── 무리 안에서만 자릅니다 ──
	# 주전은 COST 4~10, 나머지는 1~3. 자르는 자는 무리 **안에서의** 백분위이므로
	# 어느 구단이든 주전은 반드시 4 이상, 나머지는 반드시 3 이하가 됩니다.
	var core_s: Array = []
	var frin_s: Array = []
	for e in files:
		for c in ((e[1] as Dictionary).get("cards", []) as Array):
			var v := _mix_score(c, gpct, tpct)
			if bool((c as Dictionary).get("_core", false)) or not USE_CORE_SPLIT:
				core_s.append(v)
			else:
				frin_s.append(v)
	var core_cut := _cuts(core_s, COST_SHARE if not USE_CORE_SPLIT else CORE_SHARE)
	var frin_cut := _cuts(frin_s, FRINGE_SHARE)

	for e in files:
		var fn: String = e[0]
		var j: Dictionary = e[1]
		for c in (j.get("cards", []) as Array):
			var v := _mix_score(c, gpct, tpct)
			if not USE_CORE_SPLIT:
				c["cost"] = _cost_of_f(v, core_cut)
			elif bool((c as Dictionary).get("_core", false)):
				c["cost"] = 3 + _cost_of_f(v, core_cut)
			else:
				c["cost"] = _cost_of_f(v, frin_cut)
			(c as Dictionary).erase("_core")
		# 5선발 바닥. **구단마다** 봅니다 — 시즌 파일에는 열 구단이 함께 들어
		# 있어서, 파일째로 묶으면 그 시즌 전체에서 다섯 명만 올라갑니다.
		var rot := {}
		for c in (j.get("cards", []) as Array):
			if str((c as Dictionary).get("pos", "")) != "선발":
				continue
			var tk := str((c as Dictionary).get("team", ""))
			if not rot.has(tk):
				rot[tk] = []
			(rot[tk] as Array).append(c)
		for tk in rot:
			var arr2: Array = rot[tk]
			arr2.sort_custom(func(a, b): return int(a["cost"]) > int(b["cost"]))
			for i in range(mini(ORDER_ROT, arr2.size())):
				var c2: Dictionary = arr2[i]
				if int(c2["cost"]) < COST_ROT_MIN:
					c2["cost"] = COST_ROT_MIN
		var out := FileAccess.open(dir + "/" + fn, FileAccess.WRITE)
		if out == null:
			continue
		out.store_string(JSON.stringify(j))
		out.close()
	print("COST 문턱 — 주전 %s / 나머지 %s" % [str(core_cut), str(frin_cut)])

func _cuts(scores: Array, share: Array) -> Array:
	# 몫대로 자른 문턱. 같은 값이 겹치면 뒤로 밀어 순증하게 만듭니다.
	scores.sort()
	var total := 0
	for s in share:
		total += int(s)
	var cut: Array = []
	var acc := 0
	for i in range(share.size() - 1):
		acc += int(share[i])
		var at := clampi(int(round(float(scores.size()) * float(acc) / float(total))), 0,
			maxi(scores.size() - 1, 0))
		cut.append(float(scores[at]) if scores.size() > 0 else 0.0)
	for i in range(1, cut.size()):
		if float(cut[i]) <= float(cut[i - 1]):
			cut[i] = float(cut[i - 1]) + 0.000001
	return cut

func _mix_score(c: Dictionary, gpct: Dictionary, tpct: Dictionary) -> float:
	var s := _ov_of(c)
	var k := "%s|%d" % [str(c.get("team", "")), int(c.get("year", 0))]
	var g: float = float(gpct.get(s, 0.5))
	var t: float = float((tpct.get(k, {}) as Dictionary).get(s, 0.5))
	return (1.0 - TEAM_RANK_MIX) * g + TEAM_RANK_MIX * t

func _cost_of_f(v: float, cut: Array) -> int:
	for i in range(cut.size()):
		if v < float(cut[i]):
			return i + 1
	return cut.size() + 1

func _cost_of(v: int, cut: Array) -> int:
	for i in range(cut.size()):
		if v < int(cut[i]):
			return i + 1
	return cut.size() + 1

func _report() -> void:
	# COST 별 6스텟 평균과 최고 칸. **COST 가 올라도 막대가 안 움직이면**
	# 카드가 다 비슷해 보이므로, 수치를 만졌으면 여기를 보고 맞춥니다.
	var sum := {}
	var top := {}
	var cnt := {}
	# **globalize_path 로 실제 경로를 씁니다.** `--script` 모드에서 res:// 로 연
	# DirAccess 는 방금 쓴 파일을 못 보는 일이 있습니다(임포트를 안 거친 파일).
	var dir := ProjectSettings.globalize_path("res://data/players")
	var d := DirAccess.open(dir)
	if d == null:
		return
	for fn in d.get_files():
		if not fn.ends_with(".json"):
			continue
		var f := FileAccess.open(dir + "/" + fn, FileAccess.READ)
		var j = JSON.parse_string(f.get_as_text())
		f.close()
		if typeof(j) != TYPE_DICTIONARY:
			continue
		for c in (j.get("cards", []) as Array):
			var co := int(c.get("cost", 1))
			var st: Dictionary = c.get("st", {})
			var s := 0.0
			var t := 0.0
			for k in st:
				s += float(st[k])
				t = maxf(t, float(st[k]))
			if st.is_empty():
				continue
			sum[co] = float(sum.get(co, 0.0)) + s / float(st.size())
			top[co] = float(top.get(co, 0.0)) + t
			cnt[co] = int(cnt.get(co, 0)) + 1
	print("COST | 장수 | 6칸 평균 | 최고 칸")
	for co in range(1, 11):
		if not cnt.has(co):
			continue
		print("  %2d | %5d |    %5.1f |   %5.1f" % [co, int(cnt[co]),
			float(sum[co]) / float(cnt[co]), float(top[co]) / float(cnt[co])])


func _cost(ov: int) -> int:
	# **임시값입니다.** 진짜 COST 는 모든 시즌을 쓴 뒤 `_recost()` 가 백분위로
	# 다시 매깁니다 — 여기서 정하면 시즌마다 다른 자를 쓰게 됩니다.
	return clampi(int(round((ov - 45) / 5.0)) + 1, 1, 10)

func _spread(players: Array, kind: String, min_key: String, min_val: float) -> void:
	# 6스텟 합성값을 그 시즌 안에서 다시 z 로 펴서 종합(ov)을 냅니다.
	# 평균·편차는 **출장이 충분한 선수만으로** 냅니다 — 평균 50 으로 눌러 둔
	# 백업이 표본에 섞이면 편차가 쪼그라들어 별이 안 나옵니다.
	for p in players:
		p["_raw"] = float(_overall(p["st"], kind))
	var ms := _stats_of(players, "_raw", min_key, min_val)
	var w: Dictionary = W_HIT if kind == "hitter" else W_PIT
	var wmax := 0.0
	for k in w:
		wmax = maxf(wmax, float(w[k]))
	for p in players:
		var z: float = (float(p["_raw"]) - ms[0]) / ms[1]
		# OV 는 아래에서 확정 스텟으로 냅니다.
		# 종합을 각 칸에 나눠 실어 줍니다(비중에 비례). 이걸 안 하면 COST 가
		# 올라도 막대가 거의 안 움직입니다.
		var st: Dictionary = p["st"]
		# 먼저 종합을 실어 **자르지 않은 값**으로 모아 둡니다. 여기서 바로
		# `_finish_stat` 을 부르면 압축이 걸린 뒤라 아래 특화가 먹을 폭이 없습니다.
		var raw := {}
		for k in st:
			# **체력에는 종합을 싣지 않습니다.** 체력은 잘하고 못하고가 아니라
			# 보직을 가르는 표시입니다(README 의 오래된 원칙). 종합을 실으면
			# 좋은 마무리가 허드렛일 중계보다 체력이 높게 나와서
			# 선발 > 중계 > 셋업 > 마무리 서열이 통째로 뒤집힙니다.
			var lw: float = float(w.get(k, 0.0))
			if kind == "pitcher" and k == "stamina":
				lw = 0.0
			var lift: float = OVERALL_LIFT * Z_SCALE * z * (lw / wmax)
			# 타자에게 `HIT_LIFT` 를 얹습니다 — 타선이 세지면 선발이 실점으로 더 자주
			# 강판되고(`D.PULL_RUNS`), 그만큼 중계 칸이 실제로 쓰입니다.
			raw[k] = float(st[k]) + lift + (HIT_LIFT if kind == "hitter" else 0.0)
		# **특화** — 그 카드 자신의 평균 둘레로 편차를 벌립니다(`SPEC_GAIN`).
		# 평균을 그대로 두므로 합·OV·COST 는 움직이지 않고, 잘하는 칸과 못하는
		# 칸의 거리만 멀어집니다.
		var keys: Array = []
		for k in raw:
			if kind == "pitcher" and k == "stamina":
				continue
			keys.append(k)
		var mid := 0.0
		for k in keys:
			mid += float(raw[k])
		mid /= float(keys.size())
		for k in keys:
			raw[k] = mid + (float(raw[k]) - mid) * SPEC_GAIN
		# **약한 카드는 평균을 끌어올립니다**(`MEAN_FLOOR`). 편차는 위에서 이미
		# 벌려 뒀고 여기서는 통째로 옮기기만 하므로 특화가 그대로 남습니다.
		if mid < MEAN_FLOOR:
			var up := (MEAN_FLOOR - mid) * MEAN_FLOOR_K
			for k in keys:
				raw[k] = float(raw[k]) + up
		for k in raw:
			st[k] = _finish_stat(float(raw[k]))
		# 보직 서열은 **lift 다음에** 얹습니다 — 앞에 두면 종합 보정에 묻힙니다.
		if kind == "pitcher":
			var ro: float = float(STAM_ROLE.get(str(p.get("role", "")), 0.0))
			if ro != 0.0:
				st["stamina"] = _finish_stat(float(st["stamina"]) + ro)
		p.erase("_raw")
	_pull_team(players)
	# **종합(OV)은 확정된 스텟의 가중 평균입니다.**
	#
	# 예전에는 lift 를 얹기 **전**의 스텟으로 z 를 내서 OV 를 정했습니다. 그러면
	# 카드에 찍힌 여섯 칸과 OV 가 다른 것을 보게 되고, 무엇보다 `_finish_stat` 의
	# 바닥 압축(`ST_FLOOR`)이 OV 에 **하나도 반영되지 않습니다** — 약한 카드를
	# 끌어올려 놓고 OV 는 그대로 바닥인 상태가 됩니다.
	#
	# **여기서 다시 z 를 내면 안 됩니다.** z 는 척도를 정규화하므로 바닥 압축을
	# 그대로 되돌립니다. 스텟이 이미 시즌 안에서 상대평가된 값이라(`_to_stat`),
	# 그 가중 평균이 곧 시즌끼리 비교 가능한 종합입니다.
	for p in players:
		var fs: Dictionary = p["st"]
		var s := 0.0
		for k in w:
			s += float(fs[k]) * float(w[k])
		p["ov"] = clampi(int(round(s)), OV_MIN, OV_MAX)

# ── 본체 ───────────────────────────────────────────────────────────────────

func _convert(year: int) -> bool:
	var src := "res://data/raw/%d.json" % year
	if not FileAccess.file_exists(src):
		return false
	var f := FileAccess.open(src, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY or not d.has("tables"):
		print("%d — 원본이 비어 있습니다" % year)
		return false
	var tb: Dictionary = d["tables"]

	# 선수번호 — `ids.bat` 이 따로 받아 둔 것입니다. 사진 주소가 이 번호를 씁니다.
	# 없으면 그냥 비워 둡니다(사진 없이도 게임은 돌아야 합니다).
	var pid := {}
	var idp := "res://data/ids/%d.json" % year
	if FileAccess.file_exists(idp):
		var f2 := FileAccess.open(idp, FileAccess.READ)
		var d2 = JSON.parse_string(f2.get_as_text())
		f2.close()
		if typeof(d2) == TYPE_DICTIONARY and d2.has("ids"):
			pid = d2["ids"]

	var hitters := _build_hitters(tb, year)
	_rate_hitters(hitters)
	var pitchers := _build_pitchers(tb)
	_rate_pitchers(pitchers)

	# 종합도 **시즌 안에서 다시 재야** 합니다. 6스텟 평균을 그대로 쓰면
	# 한두 개가 특출한 선수도 나머지가 평균이라 종합이 안 오릅니다 —
	# 2003 최고가 이승엽 OV70(56홈런) 이라 EX·LEGENDS 가 한 장도 안 나왔습니다.
	# 그래서 합성값을 다시 그 시즌 안의 z 로 펴 줍니다. 타자와 투수는 서로
	# 비교하지 않고 **따로** 폅니다(안 그러면 한쪽에서만 별이 나옵니다).
	_spread(hitters, "hitter", "pa", float(LEAGUE_MIN_PA))
	_spread(pitchers, "pitcher", "ip", LEAGUE_MIN_IP)

	var cards: Array = []
	for p in hitters:
		if float(p["pa"]) < MIN_PA_CARD:
			continue
		var ov: int = p["ov"]
		cards.append({
			"name": p["name"], "team": p["team"], "year": year, "kind": "hitter",
			"pos": p.get("pos", "지명타자"), "st": p["st"],
			"pid": str(pid.get("%s|%s" % [p["name"], p["team"]], "")),
			"ov": ov, "grade": _grade(ov), "cost": _cost(ov),
			"line": {"avg": _fin(p.get("avg", 0.0)), "hr": int(round(_fin(p.get("hr_pa", 0.0)) * p["pa"])),
				"pa": int(p["pa"]), "g": int(p["g"]), "ops": _fin(p.get("ops", 0.0))},
		})
	for p in pitchers:
		# 야수가 대패한 경기에 한 이닝 던진 기록까지 카드로 만들면 "선발 장민석
		# 2/3이닝" 같은 것이 나옵니다. 최소 이닝으로 걸러냅니다.
		if float(p["ip"]) < MIN_IP_CARD:
			continue
		var ov: int = p["ov"]
		cards.append({
			"name": p["name"], "team": p["team"], "year": year, "kind": "pitcher",
			"pos": p["role"], "st": p["st"],
			"pid": str(pid.get("%s|%s" % [p["name"], p["team"]], "")),
			"ov": ov, "grade": _grade(ov), "cost": _cost(ov),
			"line": {"era": _fin(p.get("era", 0.0)), "w": int(_fin(p.get("w", 0))), "l": int(_fin(p.get("l", 0))),
				"sv": int(_fin(p.get("sv", 0))), "hld": int(_fin(p.get("hld", 0))), "ip": _fin(p["ip"]), "g": int(p["g"])},
		})

	DirAccess.make_dir_recursive_absolute("res://data/players")
	var out := FileAccess.open("res://data/players/%d.json" % year, FileAccess.WRITE)
	if out == null:
		print("%d — 저장 실패" % year)
		return false
	out.store_string(JSON.stringify({"year": year, "cards": cards}))
	out.close()
	print("%d — 타자 %d · 투수 %d = 카드 %d장" % [year, hitters.size(), pitchers.size(), cards.size()])
	return true

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var years: Array = []
	if args.size() >= 1 and str(args[0]).is_valid_int():
		var y0 := int(args[0])
		var y1 := y0
		if args.size() >= 2 and str(args[1]).is_valid_int():
			y1 = int(args[1])
		for y in range(y0, y1 + 1):
			years.append(y)
	else:
		var dir := DirAccess.open("res://data/raw")
		if dir != null:
			for fn in dir.get_files():
				if fn.ends_with(".json"):
					years.append(int(fn.get_basename()))
			years.sort()
	# 포지션 표는 **모든 시즌을 합쳐서** 먼저 만듭니다. 한 해만 변환할 때도
	# 그 해에 수비 표가 없으면 다른 해에서 자리를 빌려 와야 합니다.
	var all_years: Array = []
	var d2 := DirAccess.open("res://data/raw")
	if d2 != null:
		for fn in d2.get_files():
			if fn.ends_with(".json"):
				all_years.append(int(fn.get_basename()))
	_build_pos_map(all_years)
	for y in years:
		_convert(int(y))
	print("변환 끝.")
	_recost()
	_report()
	quit(0)
