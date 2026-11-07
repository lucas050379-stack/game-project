class_name GhLife
extends RefCounted

## 한 사람의 일생. **그리기 · 소리 · 저장 · 오토로드를 모릅니다** — 헤드리스 검산
## (tools/gangho_check.gd)이 `--script` 로 수천 명을 태어나게 해서 분포를 봅니다.
##
## 한 해는 [method step] 한 번입니다: 나이 +1 → 세상 소식 → 수련 → 건강 · 재산 → 자연사 →
## 갈림길이 생기는 일(세상 일 또는 사건 표). 갈림길이 생기면 `pending` 이 차고, 고를 때까지
## 다음 해로 넘어가지 않습니다([method choose]). 동년배는 [method auto_index] 로 곧바로 고릅니다.
##
## 난수는 사람마다 따로입니다(`rng`) — 씨앗이 같으면 같은 일생이 나옵니다.

var rng := RandomNumberGenerator.new()
var world: GhWorld
var is_player := false
var peers: Array = []          ## 같은 해 태어난 다른 사람들(GhLife) — 서로 마주치는 사건에 쓴다

# 태어난 것
var name := ""
var sex := "m"
var region := ""
var cls := ""
var birth_year := 0
var birth_region := ""           ## 태어난 땅(이사해도 그대로 — 출생 도감 · 검산이 본다)
var clan_id := ""               ## 태어난 세가 — 다른 문파로 옮겨도 집안 이름은 그대로
var birth_p := 0.0             ## 이렇게 태어날 확률(땅 × 집안 × 성별)
var p_reg := 0.0                ## 천하 사람 중 이 땅 사람의 비율
var p_cls := 0.0                ## 이 땅 사람 중 이 집안의 비율
var destined := false          ## 집안이 무림 쪽이라 어릴 때 저절로 입문한다
var destined_side := ""

# 지금
var age := 0
var alive := true
var cause := ""
var gol := 50                  ## 근골(1~100)
var wis := 50                  ## 오성(1~100)
var cha := 50                  ## 매력(1~100) — 사람을 끄는 힘. 혼인 · 기녀 · 악사 · 점소이 · 인연
var dex := 50                  ## 손재주(1~100) — 만드는 손. 대장장이 · 화공 · 기관사 · 암기 · 의원
var wit := 50                  ## 수완(1~100) — 셈과 말재주. 상인 · 객주 · 정보상 · 책사 · 도박
var luck := 5                  ## 운(화면에 안 나온다)
var hp := 70.0                 ## 건강
var good := 0                  ## 심성(-100 사 ~ 100 정)
var fame := 0
var gold := 0
var xp := 0.0
var realm := 0
var neigong := 0.0             ## 내공(년)
var martial := false
var sect_id := ""
var side := ""
var master := ""
var art := ""
var manual := 0
var office := 0
var flags := {}
var spouse := ""
var kids := 0
var kids_lost := 0
var foe := ""
var foe_realm := 1
var lover := ""
var seen := {}                 ## 사건 → 마지막으로 나온 나이
var lines: Array = []            ## {age, txt, kind}
var big: Array = []            ## 묘비에 남길 큰일
var pending := {}              ## 고를 갈림길 {ev, title, opts}
var met := {}                  ## 마주친 동년배

const OFFICE := ["", "현승", "현령", "지부", "시랑", "상서", "재상"]
const REALM_UP := ["", "삼류 무사가 되었다.", "이류 무사로 불리게 되었다.", "일류 고수의 반열에 올랐다.",
		"절정의 경지에 들어섰다.", "벽을 넘어 초절정에 이르렀다.", "화경에 들었다. 검기가 꽃처럼 피어난다.",
		"현경에 들었다. 몸이 가벼워져 바람을 탄다.", "생사경. 천하에 적수가 없다."]
const MANUALS := ["청풍비록", "무명심법", "철골공", "유운보", "선천공", "현천지", "구양진기", "벽력수"]
const FOE_TAG := ["낭인", "검객", "도객", "살수", "마두", "독객"]


# ==================== 태어나기 ====================

static func born(w: GhWorld, seed_: int, player: bool) -> GhLife:
	var l := GhLife.new()
	l.world = w
	l.is_player = player
	l.birth_year = w.start
	l.rng.seed = seed_
	l._roll()
	return l


func _roll() -> void:
	# 땅
	var rw := 0.0
	for r in GhD.REGIONS:
		rw += r.w
	var pick := rng.randf() * rw
	var reg: Dictionary = GhD.REGIONS[0]
	for r in GhD.REGIONS:
		pick -= r.w
		if pick <= 0.0:
			reg = r
			break
	region = reg.id
	birth_region = region
	# 집안 — 그 땅에 있을 수 있는 것만
	var ok: Array = []
	var cw := 0.0
	for c in GhD.CLASSES:
		if c.has("only") and not (c.only as Array).has(region):
			continue
		if c.has("nreg") and (c.nreg as Array).has(region):
			continue
		if c.get("sea", false) and not reg.get("sea", false):
			continue
		ok.append(c)
		cw += _cw(c, reg)
	pick = rng.randf() * cw
	var cl: Dictionary = ok[0]
	for c in ok:
		pick -= _cw(c, reg)
		if pick <= 0.0:
			cl = c
			break
	cls = cl.id
	sex = "m" if rng.randf() < 0.5 else "f"
	birth_p = (reg.w / rw) * (_cw(cl, reg) / cw) * 0.5
	p_reg = reg.w / rw
	p_cls = _cw(cl, reg) / cw
	# 타고난 것 — 대개 4~7, 드물게 9~10
	gol = _talent()
	wis = _talent()
	cha = _talent()
	dex = _talent()
	wit = _talent()
	luck = clampi(roundi(rng.randfn(5.2, 1.6)), 1, 9)
	hp = clampf(72.0 + float(cl.hp) + rng.randf_range(-8.0, 8.0), 30.0, 95.0)
	gold = int(cl.gold)
	good = rng.randi_range(-10, 10)
	destined = rng.randf() < float(cl.mart)
	destined_side = String(cl.get("side", ""))
	# 이름 — 세가는 성이 정해져 있다
	var sur: String = GhD.SURNAMES[rng.randi() % GhD.SURNAMES.size()]
	if cls == "clan":
		# 세가는 본거지에서만 — 그 땅의 세가 중 하나(하북은 모용 · 팽가 둘)
		var clans: Array = GhD.CLAN_AT.get(region, ["namgung"])
		var cid: String = clans[rng.randi() % clans.size()]
		sur = String(GhD.CLAN_SUR[cid])
		sect_id = cid   # 아직 입문 전 — 입문할 때 이 세가로 간다
		clan_id = cid
		birth_p /= clans.size()
	name = sur + _given(sex)
	_roll_house()
	_roll_cons()
	_parents()
	_siblings_at_birth()
	lines.append({age = 0, kind = "birth", txt = _birth_line()})


## 변방(초원 · 서역)은 집안 비중이 다르다 — 거기 사는 사람은 대개 유목민이다. `wf` 가 없으면 중원 비중의 0.3배.
static func _cw(c: Dictionary, reg: Dictionary) -> float:
	if reg.get("frontier", false):
		return float(c.get("wf", float(c.w) * 0.3))
	return float(c.w)


## 근골 · 오성(1~100). 대개 35~65, 백에 하나쯤 90 을 넘는 기재가 난다.
func _talent() -> int:
	if rng.randf() < 0.012:
		return rng.randi_range(88, 100)
	return clampi(roundi(rng.randfn(50.0, 14.0)), 5, 86)


func _given(sx: String) -> String:
	var pool: Array = GhD.NAME_M if sx == "m" else GhD.NAME_F
	var a: String = pool[rng.randi() % pool.size()]
	var b: String = pool[rng.randi() % pool.size()]
	while b == a:
		b = pool[rng.randi() % pool.size()]
	return a + b


func _birth_line() -> String:
	return "천하력 %d년, %s의 %s에서 %s로 태어났다." % [birth_year, region_name(), house_name(), child_label()]


func region_name() -> String:
	return String(GhD.region(region).name)


func cls_name() -> String:
	return String(GhD.cls(cls).name)


func sect_name() -> String:
	var s := GhD.sect(sect_id)
	return String(s.get("name", "")) if martial else ""


func realm_name() -> String:
	return String(GhD.REALMS[realm])


## 천하 사람 몇 명 중 하나로 이렇게 태어나나
func one_in() -> int:
	return maxi(1, roundi(1.0 / maxf(birth_p, 1e-9)))


# ==================== 한 해 ====================

func step() -> void:
	if not alive or not pending.is_empty():
		return
	age += 1
	var y := birth_year + age
	var ks: Array = world.at(y)
	for k in ks:
		var h := GhWorld.headline(k)
		if h != "" and k != "war":
			_log(h, "world")
	_destiny()
	_train()
	_body()
	_year_influence()
	_world_fx(ks)
	if not alive:
		return
	_wuxia_year()
	_natural_death()
	if not alive:
		return
	# 폐관 중에는 세상 일 · 인연 · 사건이 닿지 않는다
	if _seclusion_year():
		return
	if pending.is_empty():
		_peer_meet()
		if age >= 8 and rels.size() > 0 and rng.randf() < 0.13 * maxf(1.0, mul("meet") * 0.6):
			_rel_event()
	if pending.is_empty():
		_pick_event()
	if alive and pending.is_empty() and not _logged_this_year():
		var f := _flavor()
		if f != "":
			_log(f, "flavor")


func _logged_this_year() -> bool:
	for i in range(lines.size() - 1, -1, -1):
		var e: Dictionary = lines[i]
		if int(e.age) != age:
			return false
		if e.kind != "world":
			return true
	return false


func _log(t: String, kind := "life") -> void:
	if t == "":
		return
	lines.append({age = age, txt = t, kind = kind})


func _big(t: String) -> void:
	big.append("%d세  %s" % [age, t])


## 집안이 무림 쪽이면 어릴 때 저절로 입문한다.
func _destiny() -> void:
	if not destined or martial:
		return
	var at := {"정": 7, "세가": 5, "사": 11, "마": 7, "새외": 9, "관군": 15, "표국": 12, "소림": 5, "독학": 10}
	if age != int(at.get(destined_side, 8)):
		return
	match destined_side:
		"정":
			_join_side("정")
			_log("집안 어른들 손에 이끌려 %s에 입문했다. 사부는 %s." % [sect_name(), master], "big")
		"세가":
			_join(clan_id if clan_id != "" else "namgung")
			_log("가문의 무공 %s의 기초를 배우기 시작했다." % art, "big")
		"사":
			_join("nokrim")
			_log("산채의 어른들에게 칼 쓰는 법을 배웠다.", "big")
		"마":
			_join("cult")
			if cls == "cult_heir":
				_log("교주의 핏줄로 태어나 천마신공의 기초를 익히기 시작했다. 교도들이 무릎을 꿇었다.", "big")
			elif cls == "cult_elder":
				_log("장로인 아버지 밑에서 신교의 무공을 배우기 시작했다.", "big")
			else:
				_log("신교의 아이로 길러졌다. 붉은 등불 아래서 첫 초식을 배웠다.", "big")
		"새외":
			_join_side("새외")
			_log("%s의 사람들이 아이를 데려가 무공을 가르쳤다. 사부는 %s." % [sect_name(), master], "big")
		"관군":
			if sex == "f":
				return
			_join("army")
			_log("아버지를 따라 군적에 이름을 올렸다.", "big")
		"표국":
			_join("escort")
			_log("표국의 표사들에게 무예를 배우기 시작했다.", "big")
		"소림":
			_join("shaolin" if sex == "m" else "emei")
			_log("절의 스님들이 무공의 기초를 가르치기 시작했다.", "big")
		_:
			_learn()
			_log("아버지에게 활과 칼 쓰는 법을 배웠다.", "big")
	_big("%s 입문" % (sect_name() if sect_name() != "" else "무공"))


# ==================== 수련 ====================

func _train() -> void:
	if not martial or age < 5 or flags.has("retired") or flags.has("quit"):
		return
	var k := GhD.SOLO_K
	if sect_id != "" and GhD.sect(sect_id).has("k"):
		k = float(GhD.sect(sect_id).k)
	var agef := 0.5 if age < 10 else (1.0 if age <= 30 else (0.8 if age <= 45 else (0.55 if age <= 60 else 0.35)))
	var g := k * (0.2 + float(gol + wis) / 140.0) * agef * rng.randf_range(0.7, 1.3)
	g *= 1.0 + 0.35 * mini(manual, 2)
	g *= mul("train")
	if flags.has("crippled"):
		g *= 0.5
	_gain(g)
	neigong += agef * k * (0.8 + float(gol) / 100.0)


func _gain(g: float) -> void:
	xp += g
	while realm < GhD.REALMS.size() - 1 and xp >= GhD.REALM_XP[realm + 1]:
		if realm >= GhD.WALL_FROM:
			# 벽 — 수련치만으로는 못 넘는다. 해마다 오성으로 깨달음을 굴린다
			var ch := 0.06 + wis * 0.0015 + (0.06 if flags.has("hermit") or flags.has("cave") else 0.0)
			if rng.randf() >= ch:
				xp = minf(xp, GhD.REALM_XP[realm + 1] * 1.25)
				return
			_log("깨달음이 왔다. 막혀 있던 벽 하나가 무너졌다.", "realm")
		realm += 1
		_log(REALM_UP[realm], "realm")
		_body_milestone(realm)
		if martial:
			_learn_art()
			if realm >= 6:
				_learn_secret()
		if realm >= 3:
			_moment("gh_m_realm", "%s의 경지" % GhD.REALMS[realm], REALM_UP[realm])
		if realm >= 3:
			_big(REALM_UP[realm])


# ==================== 몸 · 재산 ====================

func _body() -> void:
	if age < 12:
		hp += 1.0
	elif age <= 40:
		if hp < 75.0:
			hp += 1.5
	elif age > 50:
		var d := 1.2 + (age - 50) * 0.04
		if realm >= 4:
			d *= 0.5
		hp -= d
	if gold < 3 and age >= 14:
		hp -= 1.5
	hp = clampf(hp, 3.0, 100.0)
	# 벌이
	if age >= 15:
		var inc := {"farm": 3, "tenant": 1, "fisher": 2, "hunter": 2, "craft": 6, "merchant": 15, "clerk": 8, "scholar": 4,
				"soldier": 2, "escort": 4, "beggar": 0, "bandit": 3, "sectfam": 4, "clan": 30, "cult": 2, "nomad": 4,
				"noble": 80, "royal": 400, "temple": 0}
		var base_inc := int(GhD.JOBS[job].inc) if job != "" and GhD.JOBS.has(job) else int(inc.get(cls, 2))
		# 직업 단이 벌이를 곱한다(무림인이 집안의 일을 안 할 때는 집안 벌이만 그대로)
		# 해마다 벌이가 출렁인다 — 같은 일을 해도 좋은 해 · 나쁜 해가 있다
		gold += int(base_inc * (work_mul() if not martial or job != "" or flags.has("quit") else 1.0) * rng.randf_range(0.55, 1.45))
		if office > 0:
			gold += office * 25
		if side == "표국":
			gold += 6
		if martial and not flags.has("quit") and not flags.has("retired"):
			gold += int(GhD.MART_PAY[realm] * float(GhD.MART_PAY_K.get(side, 1.0)))
		if flags.has("dojo"):
			gold += 20 + realm * 12
		if job == "officer":
			gold += realm * 6
		gold = maxi(gold, 0)
		_living_year()
		_shock_year()


func _natural_death() -> void:
	var p := GhD.mortality(age) / 100.0
	if items.has("herbs"):
		p *= 0.85
	if flags.has("youth"):
		p *= 0.4
	if cons == "천음절맥":
		p *= 1.6
	p *= GhD.REALM_LIFE[realm]
	p *= clampf(1.0 + (55.0 - hp) / 40.0, 0.5, 3.0)
	# 겹친 보정으로 확률이 0 에 붙어 끝없이 사는 일을 막는다 — 반로환동한 생사경도 백오십은 못 넘긴다
	if age >= 100:
		p = maxf(p, 0.04 * float(age - 99))
	if rng.randf() < p:
		var pool: Array = GhD.CAUSE_CHILD if age < 6 else (GhD.CAUSE_ADULT if age < 58 else GhD.CAUSE_OLD)
		die(String(pool[rng.randi() % pool.size()]))


## 사인 → 연대기 마지막 줄. 표에 없으면 "OO으로 세상을 떠났다".
const DEATH_LINE := {"익사": "물에 빠져 세상을 떠났다.", "풍랑": "풍랑에 휩쓸려 돌아오지 못했다.",
		"호랑이": "호랑이에게 물려 세상을 떠났다.", "산짐승": "산짐승에게 물려 세상을 떠났다.",
		"잠들듯이": "잠들듯이 조용히 세상을 떠났다.", "노환": "노환으로 자리에 누웠다가 일어나지 못했다.",
		"사약": "역모에 엮여 사약을 받았다.", "화살": "화살을 맞고 끝내 일어나지 못했다.",
		"주화입마": "기혈이 터져 주화입마로 숨을 거두었다.", "독": "독이 퍼져 숨을 거두었다."}


func die(c: String, how: String = "") -> void:
	if not alive:
		return
	if immortal:
		return
	alive = false
	cause = c
	pending = {}
	if how == "":
		how = DEATH_LINE.get(c, "%s%s 세상을 떠났다." % [c, josa(c, "로")])
	_log("%d세, %s" % [age, how], "death")


# ==================== 세상 일 ====================

func _world_fx(ks: Array) -> void:
	for k in ks:
		if not alive:
			return
		match k:
			"famine":
				if gold >= 300 and age >= 18:
					_offer({id = "granary", txt = "흉년에 곳간 앞으로 굶주린 사람들이 몰려왔다.",
							ch = [{l = "곳간을 연다", txt = "죽을 쑤어 나눴다. 사람들이 은인이라 불렀다.", fx = {gold = -int(gold * 0.4), good = 20, fame = 12}, g = 1},
								{l = "곡식을 비싸게 판다", txt = "곡식값이 올라 재산이 불었다. 원망을 샀다.", fx = {gold = 200, good = -15}, g = -1}]})
				else:
					var poor := cls in ["tenant", "beggar"] or gold < 10
					hp -= 14.0 if poor else 6.0
					var r := (0.05 if poor else 0.015) * (1.6 if age < 5 or age > 65 else 1.0)
					if rng.randf() < r:
						die("굶주림")
			"plague":
				hp -= 8.0
				var r := 0.03 + (0.04 if age < 5 or age > 60 else 0.0)
				if realm >= 4:
					r *= 0.3
				if rng.randf() < r:
					die("돌림병")
			"harvest":
				if cls in ["farm", "tenant"]:
					gold += 6
			"war_start":
				if martial and age >= 15 and age <= 70 and not flags.has("retired") and not flags.has("quit"):
					var dark := side == "마"
					_offer({id = "war_join", txt = "신교의 대군이 움직였다. 강호의 모든 문파가 칼을 뽑았다." if not dark
							else "교주가 중원 정벌을 명했다.",
							ch = [{l = "중원으로 내려간다" if dark else "정파 연합에 가담한다", txt = "깃발 아래 섰다.", fx = {flag = "at_war"}},
								{l = "싸움을 피해 숨는다", txt = "깊은 산으로 들어가 전쟁이 끝나기를 기다렸다.", fx = {fame = -5}}]})
				elif age >= 6:
					if rng.randf() < 0.3:
						_log("피난 행렬에 섞여 고향을 떠났다가 이듬해 돌아왔다.")
						gold = maxi(0, gold - 10)
			"war":
				if flags.has("at_war"):
					var r := maxf(0.03, 0.2 - realm * 0.025)
					if rng.randf() < r:
						die("전사", "정마대전의 격전 속에서 쓰러졌다.")
					else:
						_log("격전을 치렀다. 피 냄새가 옷에 배었다.", "life")
						fame += 8
						_gain(12.0)
						_war_peer()
			"war_end":
				if flags.has("at_war"):
					flags.erase("at_war")
					flags["veteran"] = true
					fame += 20
					_log("살아남았다. 전우들의 무덤에 술을 뿌렸다.", "big")
					_big("정마대전에서 살아남음")
			"rebel":
				if not martial and sex == "m" and age >= 16 and age <= 45 and cls in ["farm", "tenant", "craft"]:
					if rng.randf() < 0.15:
						_log("반군에 휩쓸려 창을 들었다.")
						if rng.randf() < 0.12:
							die("난리", "난리 통에 목숨을 잃었다.")
				elif age >= 10:
					gold = maxi(0, gold - 5)
			"alliance":
				if martial and side in ["정", "세가", "개방"] and age >= 18:
					fame += 3 + realm * 2
					_log("무림맹의 일원으로 이름이 올랐다.")
			"cult_split":
				if martial and side == "마" and age >= 15:
					_offer({id = "cult_split", txt = "교 안이 둘로 갈렸다. 어느 쪽에 설 것인가.",
							ch = [{l = "교주 편에 선다", p = ["luck", 0.5], txt = "교주가 이겼다. 공을 인정받았다.", fx = {fame = 10, xp = 8},
									ftxt = "피의 숙청에 휘말렸다.", ffx = {hp = -20, do = "risk:0.15:숙청"}},
								{l = "반란 쪽에 선다", p = ["luck", 0.4], txt = "새 교주를 세웠다. 높은 자리를 얻었다.", fx = {fame = 20, xp = 10},
									ftxt = "반란이 꺾였다. 쫓겨 달아났다.", ffx = {do = ["quit", "move"], hp = -10}},
								{l = "교를 떠난다", txt = "피 냄새가 싫었다. 교를 등졌다.", fx = {do = "quit", good = 10}, g = 1}]})
			"invasion":
				if region in ["north", "west", "hebei", "shaanxi"]:
					hp -= 6.0
					if not martial and rng.randf() < 0.04:
						die("침입", "오랑캐의 말발굽에 고을이 짓밟혔다.")
					elif martial and age >= 16 and age <= 60 and rng.randf() < 0.5:
						_log("변방 방어에 나섰다.")
						_do("duel")
						fame += 5
			"pirates":
				if GhD.region(region).get("sea", false):
					if martial and age >= 16 and rng.randf() < 0.4:
						_log("해적을 막으러 나섰다.")
						_do("duel_easy")
					else:
						gold = maxi(0, gold - 20)
						if rng.randf() < 0.02:
							die("해적", "해적의 칼에 목숨을 잃었다.")
			"tourney":
				if martial and realm >= 2 and age >= 16 and age <= 60 and not flags.has("retired") and not flags.has("quit"):
					_offer({id = "tourney", txt = "천하의 고수들이 비무대회장에 모였다.",
							ch = [{l = "출전한다", txt = "", fx = {do = "tourney"}},
								{l = "구경만 한다", txt = "고수들의 겨룸을 보며 많은 것을 배웠다.", fx = {xp = 3}}]})


func _war_peer() -> void:
	for p: GhLife in peers:
		if p.alive and p.flags.has("at_war") and (p.side == "마") != (side == "마") and not met.has("war" + p.name):
			if rng.randf() < 0.3:
				met["war" + p.name] = true
				_log("전장에서 같은 해 태어난 %s%s 칼을 맞댔다. 서로 살아서 물러났다." % [p.name, josa(p.name, "와")], "peer")


# ==================== 사건 ====================

const QUIET_W := 2.2


func _pick_event() -> void:
	var chance := 0.6 if age < 4 else 0.9
	if rng.randf() > chance:
		return
	var pool: Array = []
	# "아무 일도 없음" 몫 — 이게 없으면 한 번만 나오는 일들이 다 지나간 뒤 남은 드문 일(입문 · 기연)이
	# 해마다 거의 확실히 뽑힌다. 처음엔 이 몫이 없어서 무공을 배운 사람이 70% 였다.
	var tw := QUIET_W
	for ev: Dictionary in GhEv.all():
		if _ok(ev):
			pool.append(ev)
			tw += _w(ev)
	if pool.is_empty():
		return
	var pick := rng.randf() * tw
	for ev: Dictionary in pool:
		pick -= _w(ev)
		if pick <= 0.0:
			_fire(ev)
			return


func _ok(ev: Dictionary) -> bool:
	var a: Array = ev.a
	if age < int(a[0]) or age > int(a[1]):
		return false
	if seen.has(ev.id):
		if not ev.has("cd") or age - int(seen[ev.id]) < int(ev.cd):
			return false
	if ev.has("cls") and not (ev.cls as Array).has(cls):
		return false
	if ev.has("ncls") and (ev.ncls as Array).has(cls):
		return false
	if ev.has("reg") and not (ev.reg as Array).has(region):
		return false
	if ev.has("mart") and bool(ev.mart) != martial:
		return false
	if ev.has("sect") and bool(ev.sect) != (sect_id != "" and martial and not flags.has("quit")):
		return false
	if ev.has("side") and not (ev.side as Array).has(side):
		return false
	if ev.has("rmin") and realm < int(ev.rmin):
		return false
	if ev.has("rmax") and realm > int(ev.rmax):
		return false
	if ev.has("sex") and ev.sex != sex:
		return false
	if ev.has("job") and not (ev.job as Array).has(job):
		return false
	if ev.has("anywork") and (work_key() == "" or (martial and job == "" and not flags.has("quit"))):
		return false
	if ev.has("fmin") and fame < int(ev.fmin):
		return false
	if ev.has("gmin") and good < int(ev.gmin):
		return false
	if ev.has("gmax") and good > int(ev.gmax):
		return false
	if ev.has("sid") and not (martial and (ev.sid as Array).has(sect_id)):
		return false
	if ev.has("cons") and cons != ev.cons:
		return false
	if ev.has("jrank") and work_rank_now() < int(ev.jrank):
		return false
	if ev.has("work") and not (ev.work as Array).has(work_key()):
		return false
	if ev.has("gold") and gold < int(ev.gold):
		return false
	if ev.has("hasbiz") and biz.is_empty():
		return false
	if ev.has("nodebt") and debt > 0:
		return false
	if ev.has("hpmax") and hp > float(ev.hpmax):
		return false
	if ev.has("pr") and rng.randf() >= minf(0.95, float(ev.pr) * mul(String(ev.get("tag", "")))):
		return false
	if ev.has("min"):
		for s in ev.min:
			if _stat(s) < int(ev.min[s]):
				return false
	for f in ev.get("need", []):
		if not flags.has(f):
			return false
	for f in ev.get("nf", []):
		if flags.has(f):
			return false
	if martial and flags.has("quit") and ev.get("mart", null) == true and ev.id != "retire":
		return false
	return true


func _stat(s: String) -> int:
	match s:
		"gol":
			return gol
		"wis":
			return wis
		"luck":
			return luck
		"cha":
			return cha
		"dex":
			return dex
		"wit":
			return wit
	return 0


func _fire(ev: Dictionary) -> void:
	seen[ev.id] = age
	if ev.has("ch"):
		_offer(ev)
		return
	if String(ev.get("txt", "")) != "":
		_log(fmt(ev.txt))
	_fx(ev.get("fx", {}))


## 갈림길을 연다. 플레이어는 [method choose] 를 기다리고, 동년배는 바로 고른다.
func _offer(ev: Dictionary) -> void:
	if ev.id == "love" and lover == "":
		# 정든 사람이 같은 해 태어난 이일 때가 있다 — 그러면 그 사람의 삶이 남의 일이 아니게 된다
		for p: GhLife in peers:
			if p.alive and p.sex != sex and not p.flags.has("married") and (p.region == region or met.has(p.name)) and rng.randf() < 0.5:
				lover = p.name
				break
	if ev.id == "love" and lover == "":
		lover = _stranger(sex == "f")
	_log(fmt(ev.txt), "choice")
	var opts: Array = []
	for c in ev.ch:
		opts.append(fmt(c.l))
	pending = {ev = ev, title = fmt(ev.txt), opts = opts}
	if not is_player:
		choose(auto_index())


## 성향대로 고른다 — 착하면 착한 쪽, 악하면 악한 쪽으로 기운다. 자동 선택과 동년배가 쓴다.
func auto_index() -> int:
	if pending.is_empty():
		return 0
	var ch: Array = pending.ev.ch
	var ws: Array = []
	var tw := 0.0
	for c in ch:
		var w := maxf(0.15, 1.0 + float(c.get("g", 0)) * good / 60.0)
		ws.append(w)
		tw += w
	var pick := rng.randf() * tw
	for i in ws.size():
		pick -= ws[i]
		if pick <= 0.0:
			return i
	return 0


func choose(i: int) -> void:
	if pending.is_empty():
		return
	var ev: Dictionary = pending.ev
	pending = {}
	var c: Dictionary = ev.ch[clampi(i, 0, ev.ch.size() - 1)]
	_log("> " + fmt(c.l), "pick")
	if c.has("p"):
		var p: Array = c.p
		var st := String(p[0])
		var dev := (_stat(st) - 50) * 0.006 if st in ["gol", "wis", "cha", "dex", "wit"] else (_stat(st) - 5) * 0.06
		var chance := clampf(float(p[1]) + dev, 0.05, 0.95)
		if rng.randf() >= chance:
			_log(fmt(String(c.get("ftxt", ""))))
			_fx(c.get("ffx", {}))
			return
	_log(fmt(String(c.get("txt", ""))))
	_fx(c.get("fx", {}))


# ==================== 효과 ====================

func _fx(fx: Dictionary) -> void:
	for k in fx:
		var v = fx[k]
		match k:
			"gol":
				gol = clampi(gol + int(v), 1, 100)
			"wis":
				wis = clampi(wis + int(v), 1, 100)
			"cha":
				cha = clampi(cha + int(v), 1, 100)
			"dex":
				dex = clampi(dex + int(v), 1, 100)
			"wit":
				wit = clampi(wit + int(v), 1, 100)
			"luck":
				luck = clampi(luck + int(v), 1, 10)
			"hp":
				hp = clampf(hp + float(v), 3.0, 100.0)
			"fame":
				fame = maxi(0, fame + int(v))
			"gold":
				gold = maxi(0, gold + int(v))
			"good":
				good = clampi(good + int(v), -100, 100)
				if martial and int(v) < 0:
					infamy += -int(v) / 2
			"infamy":
				infamy = maxi(0, infamy + int(v))
			"gov":
				gov = maxi(0, gov + int(v))
			"xp":
				if martial:
					_gain(float(v))
			"neigong":
				neigong += float(v)
			"feat":
				var wk := work_key()
				if wk != "":
					feats[wk] = int(feats.get(wk, 0)) + int(v)
			"flag":
				for f in (v if v is Array else [v]):
					flags[f] = true
					if f == "leader" and not _contest_leader():
						flags.erase("leader")
						continue
					if f in ["leader", "house_head"]:
						_learn_secret()
					if f == "leader":
						_log("%s의 장문인이 되었다." % sect_name(), "big")
						_moment("gh_m_leader", "장문인", "%s의 장문인이 되었다." % sect_name())
					elif f == "at_war":
						_moment("gh_m_war", "참전", "정마대전의 깃발 아래 섰다.")
			"unflag":
				for f in (v if v is Array else [v]):
					flags.erase(f)
	if fx.has("do"):
		var d = fx.do
		for one in (d if d is Array else [d]):
			if alive:
				_do(String(one))


func _do(d: String) -> void:
	if _rel_do(d):
		return
	if _wuxia_do(d):
		return
	if _job_do(d):
		return
	if _life_do(d):
		return
	if d.begins_with("become:"):
		cls = d.substr(7)
		_big("%s이 됨" % cls_name() if cls_name().ends_with("인") else "%s 일을 시작함" % cls_name())
		return
	if d.begins_with("risk:"):
		var parts := d.split(":")
		if parts[2] == "독" and flags.has("poison_immune"):
			_log("독이 몸에 들었지만 아무 일도 없었다. 만독불침이었다.")
			return
		if rng.randf() < float(parts[1]) * mul("danger"):
			die(parts[2])
		return
	match d:
		"learn":
			_learn()
		"join_jeong":
			_join_side("정")
			_log("%s의 제자가 되었다. 사부는 %s." % [sect_name(), master], "big")
			_big("%s 입문" % sect_name())
		"join_sa":
			_join_side("사")
			_log("%s에 몸을 담았다." % sect_name(), "big")
			_big("%s에 투신" % sect_name())
		"join_ma":
			_join("cult")
			_log("천마신교의 일원이 되었다.", "big")
			_big("천마신교 입교")
		"join_saeoe":
			_join_side("새외")
			_log("%s의 제자가 되었다. 사부는 %s." % [sect_name(), master], "big")
			_big("%s 입문" % sect_name())
		"join_beggars":
			_join("beggars")
			_big("개방 입문")
		"join_army":
			_join("army")
			_big("관군 입대")
		"join_escort":
			_join("escort")
			_big("표국 입문")
		"quit":
			flags["quit"] = true
		"manual":
			manual += 1
			var m: String = MANUALS[rng.randi() % MANUALS.size()]
			_log("비급 %s%s 익혔다." % [m, josa(m, "을")], "realm")
			_big("비급 %s 습득" % m)
			if martial:
				_gain(10.0)
		"cave":
			manual += 1
			_moment("gh_m_cave", "기연", "절벽 아래 동굴에서 옛 고수의 유해와 비급을 찾았다.")
			if sect_id != "" and not flags.has("quit"):
				_learn_secret()
			flags["cave"] = true
			luck = mini(10, luck + 1)
			neigong += 25.0
			_big("절벽 아래 동굴에서 기연을 얻음")
			_gain(40.0)
		"qi_dev":
			var r := rng.randf()
			if r < 0.3:
				die("주화입마")
			elif r < 0.75:
				realm = maxi(0, realm - 2)
				xp = GhD.REALM_XP[realm]
				hp -= 25.0
				flags["crippled"] = true
				_moment("gh_m_deviation", "주화입마", "기혈이 터져 쌓은 무공의 절반을 잃었다.")
				_log("단전이 상해 쌓은 무공의 절반을 잃었다.", "realm")
				_big("주화입마로 무공을 잃음")
			else:
				hp -= 20.0
				_log("피를 토하고 쓰러졌다가 겨우 목숨을 건졌다.")
		"office":
			office = mini(office + 1, OFFICE.size() - 1)
			flags["official"] = true
			if office == 1:
				_moment("gh_m_office", "급제", "%s 벼슬에 올랐다. 고향에 잔치가 열렸다." % OFFICE[office])
			_log("%s 벼슬에 올랐다." % OFFICE[office], "big")
			if office >= 2:
				_big("%s 벼슬" % OFFICE[office])
		"marry":
			_marry("")
		"marry_lover":
			_marry(lover)
		"child":
			kids += 1
			_child_rel()
			flags["kids"] = true
		"child_die":
			kids = maxi(0, kids - 1)
			for r: Dictionary in rels:
				if r.kind == "자식" and r.alive:
					r.alive = false
					break
			kids_lost += 1
			if kids == 0:
				flags.erase("kids")
		"widow":
			flags.erase("married")
			flags["widowed"] = true
			_log("%s%s 먼저 세상을 떠났다." % [spouse, josa(spouse, "이")])
		"move":
			var cands: Array = []
			for r in GhD.REGIONS:
				if r.id != region and not r.get("frontier", false):
					cands.append(r.id)
			region = cands[rng.randi() % cands.size()]
			_log("살던 고을을 떠나 %s%s 옮겨 갔다." % [region_name(), josa(region_name(), "로")])
		"enemy":
			foe = _stranger(false)
			foe_realm = clampi(realm + rng.randi_range(-1, 1), 1, 8)
			flags["enemy"] = true
		"duel":
			_duel(clampi(realm + rng.randi_range(-1, 1), 1, 8), 0.07, "")
		"duel_easy":
			_duel(maxi(1, realm - 1 - rng.randi_range(0, 1)), 0.03, "산적들을 쫓아냈다.")
		"duel_strong":
			_duel(mini(8, realm + 1 + (1 if rng.randf() < 0.3 else 0)), 0.3, "")
		"duel_enemy":
			_duel_enemy()
		"escort_run":
			if rng.randf() < 0.55 + gol * 0.003:
				gold += 50
				fame += 3
				_log("무사히 표물을 전했다.")
			else:
				_log("표물을 노린 녹림도들이 길을 막았다.")
				_duel(clampi(realm + rng.randi_range(-1, 0), 1, 8), 0.1, "녹림도들을 물리쳤다.")
		"tourney":
			_tourney()


func _learn() -> void:
	if martial:
		return
	martial = true
	side = "독학"
	sect_id = ""
	_learn_art()
	_big("무공을 배우기 시작함")


func _join_side(sd: String) -> void:
	var ws: Array = []
	var tw := 0.0
	var cands: Array = []
	for s in GhD.SECTS:
		if s.side != sd:
			continue
		if sex == "f" and not s.get("women", true):
			continue
		if sex == "m" and not s.get("men", true):
			continue
		var w := 6.0 if s.reg == region else 1.0
		cands.append(s.id)
		ws.append(w)
		tw += w
	if cands.is_empty():
		_learn()
		return
	var pick := rng.randf() * tw
	for i in cands.size():
		pick -= ws[i]
		if pick <= 0.0:
			_join(cands[i])
			return
	_join(cands[0])


func _join(id: String) -> void:
	var s := GhD.sect(id)
	if s.is_empty():
		_learn()
		return
	martial = true
	flags.erase("quit")
	sect_id = id
	side = String(s.side)
	art = String(s.art)
	master = _master_name(id)
	_learn_art()
	_moment("gh_m_join", "%s 입문" % sect_name(), "%s의 문을 들어섰다. 사부는 %s." % [sect_name(), master])
	_add_rel(master, "사부", "warrior", 45)
	_gain(2.0)


func _master_name(id: String) -> String:
	if id == "shaolin":
		return "%s%s 대사" % ["혜", GhD.NAME_M[rng.randi() % GhD.NAME_M.size()]]
	if id == "emei":
		return "%s%s 사태" % ["정", GhD.NAME_F[rng.randi() % GhD.NAME_F.size()]]
	if id == "beggars":
		return "%s 장로" % _stranger(false)
	if id == "army":
		return "%s 교위" % _stranger(false)
	if id == "escort":
		return "%s 표두" % _stranger(false)
	if id == "cult":
		return "%s 호법" % _stranger(false)
	return "%s 장로" % _stranger(false)


func _stranger(female: bool) -> String:
	var sur: String = GhD.SURNAMES[rng.randi() % GhD.SURNAMES.size()]
	return sur + _given("f" if female else "m")


func _marry(who: String) -> void:
	# 같은 해 태어난 이와 맺어지기도 한다 — 동년배 칸이 남의 일생이 아니게 된다
	if who == "":
		for p: GhLife in peers:
			if p.alive and p.sex != sex and not p.flags.has("married") and p.age >= 16 and rng.randf() < 0.12:
				who = p.name
				p.flags["married"] = true
				p.spouse = name
				p._add_rel_spouse(name, _rand_trait())
				p._log("같은 해 태어난 %s%s 혼인했다." % [name, josa(name, "와")], "big")
				p._big("%s%s 혼인" % [name, josa(name, "와")])
				_log("같은 해 태어난 %s%s 혼인했다." % [who, josa(who, "와")], "big")
				break
		if who == "":
			who = _stranger(sex == "m")
			_log("%s%s 혼인했다." % [who, josa(who, "와")], "big")
	else:
		_log("%s%s 혼인했다." % [who, josa(who, "와")], "big")
	spouse = who
	flags["married"] = true
	_add_rel_spouse(who, _rand_trait())
	_big("%s%s 혼인" % [who, josa(who, "와")])
	_moment("gh_m_marry", "혼인", "%s%s 혼례를 올렸다." % [who, josa(who, "와")])


func _power(r: int) -> float:
	return r + rng.randf_range(-0.7, 0.7)


func _duel(opp: int, deadly: float, win_txt: String) -> bool:
	var mine := _art_power() + realm + clampf((xp - GhD.REALM_XP[realm]) / maxf(1.0, GhD.REALM_XP[mini(realm + 1, 8)] - GhD.REALM_XP[realm]), 0.0, 0.9) \
			+ gol * 0.004 + rng.randf_range(-0.7, 0.7)
	var theirs := opp + rng.randf() * 0.8 + rng.randf_range(-0.7, 0.7)
	if mine >= theirs:
		fame += 2 + opp * 2
		_gain(2.0 + opp)
		_log(win_txt if win_txt != "" else "%s 상대를 꺾었다." % GhD.REALMS[opp] + ("" if opp <= realm else " 이름이 조금 알려졌다."))
		return true
	else:
		hp -= rng.randf_range(12.0, 30.0)
		if rng.randf() < deadly * (0.5 if cons == "금강지체" else 1.0):
			die("결투", "결투에서 패해 숨을 거두었다.")
		else:
			_log("%s 상대에게 패해 크게 다쳤다." % GhD.REALMS[opp])
	return false


func _duel_enemy() -> void:
	var mine := _art_power() + realm + gol * 0.004 + rng.randf_range(-0.8, 0.8)
	var theirs := foe_realm + rng.randf_range(-0.8, 0.8)
	if mine >= theirs:
		_log("원수 %s%s 베었다. 오랜 원한이 끝났다." % [foe, josa(foe, "을")], "big")
		_big("원수 %s%s 벰" % [foe, josa(foe, "을")])
		fame += 12
		flags.erase("enemy")
		flags.erase("revenge")
		flags["avenged"] = true
		_moment("gh_m_avenge", "복수", "원수 %s%s 베었다." % [foe, josa(foe, "을")])
	else:
		hp -= rng.randf_range(15.0, 35.0)
		if rng.randf() < 0.35:
			die("원수의 칼", "원수 %s의 칼에 쓰러졌다." % foe)
		else:
			_log("원수 %s에게 패해 겨우 목숨만 건졌다." % foe)
			foe_realm = mini(8, foe_realm + (1 if rng.randf() < 0.3 else 0))


func _tourney() -> void:
	var wins := 0
	for opp in [realm - 1, realm, realm + 1]:
		var o := clampi(opp, 1, 8)
		var mine := _art_power() + realm + gol * 0.004 + rng.randf_range(-0.8, 0.8)
		if mine >= o + rng.randf_range(-0.8, 0.8):
			wins += 1
		else:
			break
	match wins:
		3:
			fame += 40
			flags["champion"] = true
			_gain(10.0)
			_log("우승했다! 천하에 이름을 떨쳤다.", "big")
			_moment("gh_m_champion", "비무대회 우승", "천하의 고수들을 꺾고 우승했다.")
			_big("무림 비무대회 우승")
		2:
			fame += 15
			_log("사강까지 올랐다. 이름이 널리 알려졌다.")
		1:
			fame += 5
			_log("한 판을 이기고 다음 판에서 졌다.")
		_:
			fame += 1
			_log("첫 판에서 떨어졌다.")


# ==================== 동년배 ====================

func _peer_meet() -> void:
	_rival_year()
	for p: GhLife in peers:
		if not p.alive or met.has(p.name):
			continue
		if martial and p.martial and sect_id != "" and sect_id == p.sect_id and not flags.has("quit"):
			met[p.name] = true
			_log("같은 해 태어난 %s%s 같은 %s에서 수련하고 있었다." % [p.name, josa(p.name, "이"), sect_name()], "peer")
			return
		if age >= 15 and p.region == region and rng.randf() < 0.025 * mul("meet"):
			met[p.name] = true
			_log("장터에서 동갑내기 %s%s 마주쳐 술잔을 나눴다." % [p.name, josa(p.name, "와")], "peer")
			return


# ==================== 글 ====================

func _flavor() -> String:
	var key := ""
	if age < 4:
		key = "baby"
	elif age < 13:
		key = "child"
	elif flags.has("retired") or (flags.has("quit") and martial):
		key = "retired"
	elif age >= 62:
		key = "old"
	elif martial:
		key = "cult" if side == "마" and rng.randf() < 0.4 else "mart"
	elif flags.has("official"):
		key = "official"
	else:
		key = {"farm": "farm", "tenant": "farm", "fisher": "fisher", "craft": "craft", "merchant": "merchant",
				"scholar": "scholar", "clerk": "official", "beggar": "beggar", "nomad": "nomad", "noble": "noble",
				"royal": "noble", "hunter": "farm"}.get(cls, "farm")
	if job != "" and GhD.JOBS.has(job) and key not in ["baby", "child", "old", "retired"] and rng.randf() < 0.7:
		var jp: Array = GhD.JOBS[job].flavor
		return String(jp[rng.randi() % jp.size()])
	if rng.randf() < 0.35:
		return ""
	var pool: Array = GhEv.FLAVOR[key]
	return fmt(String(pool[rng.randi() % pool.size()]))


func near_sect() -> String:
	for s in GhD.SECTS:
		if s.side == "정" and s.reg == region:
			if sex == "f" and not s.get("women", true):
				continue
			if sex == "m" and not s.get("men", true):
				continue
			return String(s.name)
	return "화산파" if sex == "m" else "아미파"


## 글자 자리 채우기 — `{n}` 은 값, `{n|을}` 은 그 값에 맞는 조사만.
func fmt(s: String) -> String:
	if s.find("{") < 0:
		return s
	var vals := {"n": name, "s": GhD.sect(sect_id).get("name", "문파"), "m": master, "art": art if art != "" else "무공",
			"sp": spouse, "foe": foe, "wt": work_title(), "r": region_name(), "rs": near_sect(), "lover": lover}
	var out := ""
	var i := 0
	while i < s.length():
		var c := s[i]
		if c == "{":
			var e := s.find("}", i)
			if e > i:
				var tok := s.substr(i + 1, e - i - 1)
				var bar := tok.find("|")
				if bar >= 0:
					out += josa(String(vals.get(tok.substr(0, bar), "")), tok.substr(bar + 1))
				else:
					out += String(vals.get(tok, ""))
				i = e + 1
				continue
		out += c
		i += 1
	return out


## 받침에 맞는 조사. j 는 짝 중 아무거나(은/는 · 이/가 · 을/를 · 과/와 · 으로/로 · 아/야).
static func josa(word: String, j: String) -> String:
	var last := word.unicode_at(word.length() - 1) if word.length() > 0 else 0
	var bat := -1
	if last >= 0xAC00 and last <= 0xD7A3:
		bat = (last - 0xAC00) % 28
	var has := bat > 0
	match j:
		"은", "는":
			return "은" if has else "는"
		"이", "가":
			return "이" if has else "가"
		"을", "를":
			return "을" if has else "를"
		"과", "와":
			return "과" if has else "와"
		"으로", "로":
			return "으로" if has and bat != 8 else "로"
		"아", "야":
			return "아" if has else "야"
	return j


# ==================== 묘비 ====================

func title() -> String:
	if age < 5:
		return "이름도 다 불리지 못한 아이"
	if realm >= 8:
		return "천하제일인"
	if flags.has("cult_lord"):
		return "천마"
	if flags.has("mengju"):
		return "무림맹주"
	if realm >= 6:
		return "%s의 전설" % sect_name() if sect_name() != "" else "이름 없는 절대고수"
	if flags.has("demon") and flags.has("hunted"):
		return "피에 물든 마두"
	if cause == "주화입마":
		return "주화입마에 쓰러진 무인"
	if flags.has("champion"):
		return "비무대회의 우승자"
	if flags.has("leader"):
		return "%s의 장문인" % sect_name()
	if flags.has("cult_elder_seat"):
		return "천마신교의 장로"
	if flags.has("house_head"):
		return "%s의 가주" % house_name()
	if office >= 5:
		return "조정의 대신"
	if cause == "전사":
		return "정마대전에 스러진 무인"
	if flags.has("avenged") and flags.has("vow"):
		return "원수를 갚은 복수귀"
	if realm >= 4:
		return "절정에 이른 고수"
	if flags.has("monk"):
		return "칼을 내려놓은 승려"
	if office >= 2:
		return "고을의 목민관"
	if job != "" and not job in ["monk", "laborer"] and GhD.JOBS.has(job):
		return _work_epithet()
	if gold >= 2000 and cls in ["merchant", "craft"]:
		return "%s의 거상" % region_name()
	if fame >= 60 and good >= 40:
		return "이름난 협객"
	if good <= -60:
		return "악명 높은 %s" % ("무인" if martial else "사람")
	if realm >= 2:
		return "강호를 떠돈 무인"
	if work_key() != "" and work_rank_now() >= 2:
		return _work_epithet()
	if age >= 80:
		return "천수를 누린 %s 사람" % region_name()
	if realm == 1:
		return "이름 없는 삼류 무사"
	return "%s %s의 일생" % [region_name(), cls_name()]


# ==================== 진로를 기울이는 것: 할 일 · 물건 · 인연 ====================
#
# 사건 꼬리표(tag)마다 배수를 곱한다 — [method mul]. 할 일 하나 × 산 물건들 × 살아 있는 인연들.
# 인연은 **정(bond)이 깊을수록** 그 사람의 성향 쪽으로 끌어당긴다(GhD.TRAITS). 정은 인연 갈림길에서 오르내린다.
# 원작에서 친구 · 가족 · 배우자의 영향을 받는 것과 같은 자리다(사용자 요청 11-06).

var focus := "home"
var items := {}
var habits := {}               ## 켜 둔 "매년 하는 일"
var acted := {}                ## 즉흥 행동 → 마지막으로 한 나이(한 해에 한 번)
var debt := 0                  ## 전장(돈집)에 진 빚 — 해마다 1할씩 불어난다
var rels: Array = []           ## {name, kind, tt(성향), bond, alive, born}
var ai_plan := false           ## 플레이어 자리도 할 일을 스스로 고른다(자동 · 검산)
var _rel_i := -1               ## 지금 갈림길에 걸린 인연
var _good_acc := 0.0


func mul(tag: String) -> float:
	if tag == "":
		return 1.0
	var m := float(GhD.focus(focus).mul.get(tag, 1.0))
	for id in items:
		m *= float(GhD.item(id).get("mul", {}).get(tag, 1.0))
	for id in habits:
		m *= float(GhD.habit(id).get("mul", {}).get(tag, 1.0))
	# 무공 갈래 — 경공은 위험을 비키고, 진법은 싸움을 덜 위험하게, 내공 심법은 수련을 빠르게
	if tag == "danger":
		m *= maxf(0.75, pow(0.9, _cat_count("경공"))) * pow(0.95, _cat_count("진법"))
	elif tag == "train":
		m *= minf(1.2, 1.0 + 0.05 * _cat_count("내공"))
	if tag == "luck" and flags.has("pet"):
		m *= 1.2
	var er := world.era(birth_year + age)
	if er != "":
		m *= float(GhWorld.ERA_MUL[er].get(tag, 1.0))
	if job != "" and GhD.JOBS.has(job):
		m *= float(GhD.JOBS[job].mul.get(tag, 1.0))
	if quals.has("academy") and tag == "civil":
		m *= 2.0
	for r: Dictionary in rels:
		if not r.alive:
			continue
		var k := float(GhD.trait_of(r.tt).mul.get(tag, 0.0))
		if k != 0.0:
			m *= 1.0 + k * float(r.bond) / 100.0 * (0.4 if r.kind == "자식" else 1.0)
	# 한쪽으로 끝없이 쌓이지 않게 — 할 일 · 물건 · 인연이 다 같은 쪽이어도 6배까지
	return clampf(m, 0.2, 6.0)


func _w(ev: Dictionary) -> float:
	return float(ev.w) * mul(String(ev.get("tag", "")))


func _rand_trait() -> String:
	return String(GhD.TRAITS[rng.randi() % GhD.TRAITS.size()].id)


func _add_rel(who: String, kind: String, tr: String, bond: int) -> int:
	rels.append({name = who, kind = kind, tt = tr, bond = clampi(bond, 0, 100), alive = true, born = age})
	return rels.size() - 1


## 배우자 — 이미 친구 · 의형제로 아는 사이면 그 줄을 배우자로 바꾼다(같은 사람이 두 줄로 남지 않게).
func _add_rel_spouse(who: String, tr: String) -> void:
	for r: Dictionary in rels:
		if r.name == who and r.alive:
			r.kind = "배우자"
			r.bond = maxi(int(r.bond), 65)
			return
	_add_rel(who, "배우자", tr, rng.randi_range(55, 80))


func rel_of(kind: String) -> int:
	for i in rels.size():
		if rels[i].kind == kind and rels[i].alive:
			return i
	return -1


const TWO_SUR := ["남궁", "제갈", "모용", "사마", "구양", "독고", "상관", "공손", "황보"]


## 태어날 때 — 부모. 집안 성향을 닮기 쉽다.
func _parents() -> void:
	var sur := name.substr(0, 2) if TWO_SUR.has(name.substr(0, 2)) else name.substr(0, 1)
	for kind in ["아버지", "어머니"]:
		var tr := String(GhD.CLASS_TRAIT.get(cls, "")) if rng.randf() < 0.6 else ""
		if tr == "":
			tr = _rand_trait()
		var nm := (sur + _given("m")) if kind == "아버지" else _stranger(true)
		_add_rel(nm, kind, tr, rng.randi_range(55, 90))


## 해마다 — 할 일의 효과 · 인연의 심성 끌림 · 부모의 노쇠 · 자식의 성장.
func _year_influence() -> void:
	# 동년배 · 자동은 여유가 생기면 빚을 갚는다(플레이어는 직접 — "지금 하기" 의 빚 갚기)
	if (not is_player or ai_plan) and debt > 0 and gold > 0:
		var pay := mini(gold, debt)
		gold -= pay
		debt -= pay
	if (not is_player or ai_plan) and age in [6, 12, 16, 20, 30, 45, 60]:
		_ai_focus()
	var f := GhD.focus(focus)
	if age < int(f.a[0]) or age > int(f.a[1]) or (f.get("mart", false) and not martial):
		focus = "home" if age >= 6 else "rest"
		f = GhD.focus(focus)
	if age >= 6:
		for k in f.fx:
			var v := float(f.fx[k])
			match k:
				"gol", "wis", "cha", "dex", "wit":
					_grow_stat(k, v)
				"hp":
					hp = clampf(hp + v, 3.0, 100.0)
				"gold":
					if age >= 12:
						gold = maxi(0, gold + int(v))
	_habits_year()
	_course_year()
	_economy_year()
	_work_year()
	_inherit_check()
	if pending.is_empty():
		_heir_events()
	for i in rels.size():
		var r: Dictionary = rels[i]
		if not r.alive:
			continue
		_good_acc += float(GhD.trait_of(r.tt).get("good", 0)) * float(r.bond) / 100.0 * 0.15
		if r.kind in ["아버지", "어머니"]:
			if rng.randf() < GhD.mortality(age + 27) / 100.0 * 1.2:
				r.alive = false
				if not (r.kind == "아버지" and flags.has("fatherless")):
					_log("%s께서 세상을 떠나셨다." % r.kind, "big")
					hp -= 3.0
		elif r.kind == "자식":
			var ca := age - int(r.born)
			if ca == 16:
				_child_grows(r)
			elif ca > 0 and rng.randf() < GhD.mortality(ca) / 100.0 * 0.6:
				r.alive = false
				_log("자식 %s%s 먼저 세상을 떠났다." % [r.name, josa(String(r.name), "이")], "big")
				kids = maxi(0, kids - 1)
				kids_lost += 1
		elif r.kind == "배우자" and age > 30 and rng.randf() < GhD.mortality(age) / 100.0 * 0.5:
			r.alive = false
			flags.erase("married")
			flags["widowed"] = true
			_log("%s%s 먼저 세상을 떠났다." % [r.name, josa(String(r.name), "이")], "big")
		elif r.kind in ["친구", "의형제"]:
			for p: GhLife in peers:
				if p.name == r.name and not p.alive:
					r.alive = false
	if absf(_good_acc) >= 1.0:
		good = clampi(good + int(_good_acc), -100, 100)
		_good_acc -= float(int(_good_acc))


## 높을수록 덜 오른다 — 100 에 가까우면 거의 안 오른다. 소수점 몫은 굴려서 정수로.
func _grow(v: float, cur: int) -> int:
	var g := v * maxf(0.0, 1.0 - cur / 110.0)
	var n := int(g)
	if rng.randf() < g - n:
		n += 1
	return n


func _ai_focus() -> void:
	var ws := {}
	var tr := ""
	var fi := rel_of("아버지")
	if fi >= 0:
		tr = rels[fi].tt
	for f in GhD.FOCUS:
		if age < int(f.a[0]) or age > int(f.a[1]) or (f.get("mart", false) and not martial):
			continue
		var w := 1.0
		match String(f.id):
			"home":
				w = 4.0
			"body":
				w = 4.0 if martial else 0.8 + (2.0 if tr == "warrior" or destined else 0.0)
			"study":
				w = 0.8 + (2.5 if cls in ["scholar", "noble", "clerk"] or tr == "scholar" else 0.0)
			"trade":
				w = 0.6 + (2.5 if cls in ["merchant", "craft"] or tr == "trader" else 0.0)
			"travel":
				w = 0.3 + (1.0 if tr == "wander" else 0.0)
			"rest":
				w = 0.3 + (3.0 if age >= 55 or hp < 40 else 0.0)
		ws[f.id] = w
	var tw := 0.0
	for k in ws:
		tw += ws[k]
	var pick := rng.randf() * tw
	for k in ws:
		pick -= ws[k]
		if pick <= 0.0:
			focus = k
			return


## 플레이어가 올해 할 일을 바꾼다.
func set_focus(id: String) -> void:
	if id == focus:
		return
	focus = id
	_log("올해부터 %s에 힘쓰기로 했다." % GhD.focus(id).name, "pick")


func focus_ok(id: String) -> bool:
	var f := GhD.focus(id)
	return age >= int(f.a[0]) and age <= int(f.a[1]) and not (f.get("mart", false) and not martial)


func can_buy(id: String) -> bool:
	var it := GhD.item(id)
	if it.is_empty() or items.has(id) or gold < int(it.cost):
		return false
	if age < int(it.a[0]) or age > int(it.a[1]):
		return false
	if it.get("mart", false) and not martial:
		return false
	return true


func buy(id: String) -> void:
	if not can_buy(id):
		return
	var it := GhD.item(id)
	gold -= int(it.cost)
	items[id] = true
	_log("%s%s 샀다. (%d냥)" % [it.name, josa(String(it.name), "을"), int(it.cost)], "pick")
	_fx(it.get("fx", {}))


func _child_rel() -> void:
	var son := rng.randf() < 0.5
	var nm := _given("m" if son else "f")
	# 자식은 부모의 길을 닮는다 — 무림인이면 무예, 관리면 글, 장사꾼이면 장사
	var tr := _rand_trait()
	if martial and rng.randf() < 0.6:
		tr = "warrior"
	elif flags.has("official") and rng.randf() < 0.6:
		tr = "scholar"
	elif cls == "merchant" and rng.randf() < 0.6:
		tr = "trader"
	var i := _add_rel(nm, "자식", tr, rng.randi_range(60, 95))
	if kids == 1 and kids_lost == 0:
		_moment("gh_m_child", "첫아이", "%s 태어났다. 이름은 %s." % ["아들이" if son else "딸이", nm])
	rels[i]["son"] = son
	_log("%s 태어났다. 이름을 %s%s 지었다." % ["아들이" if son else "딸이", nm, josa(nm, "로")])


func _child_grows(r: Dictionary) -> void:
	var nm := String(r.name)
	match String(r.tt):
		"warrior":
			_log("자식 %s%s 칼을 잡았다. 제법 매서웠다." % [nm, josa(nm, "이")], "big")
			fame += 3
		"scholar":
			_log("자식 %s%s 글을 읽는다. 훈장이 칭찬했다." % [nm, josa(nm, "이")])
		"trader":
			_log("자식 %s%s 장터에서 셈이 빠르다는 소문이 났다." % [nm, josa(nm, "이")])
			gold += 10
		"gambler":
			_log("자식 %s%s 노름판을 기웃거린다. 속이 탔다." % [nm, josa(nm, "이")])
			gold = maxi(0, gold - 15)
		"rough":
			_log("자식 %s%s 저잣거리에서 주먹을 휘두르고 다닌다." % [nm, josa(nm, "이")])
		_:
			_log("자식 %s%s 어엿한 어른이 되었다." % [nm, josa(nm, "이")])


func _make_friend(sworn: bool) -> void:
	var nm := ""
	var peer := false
	for p: GhLife in peers:
		if p.alive and p.region == region and not met.has(p.name) and rng.randf() < 0.5:
			nm = p.name
			peer = true
			met[p.name] = true
			break
	if nm == "":
		nm = _stranger(rng.randf() < 0.4)
	var tr := _rand_trait()
	for p: GhLife in peers:
		if p.name == nm:
			if p.martial:
				tr = "warrior"
			elif p.flags.has("study") or p.flags.has("official"):
				tr = "scholar"
	if sworn:
		_add_rel(nm, "의형제", "warrior", rng.randi_range(70, 90))
		_log("%s%s 의형제를 맺었다. 같은 날 죽기를 맹세했다." % [nm, josa(nm, "과")], "big")
		_big("%s%s 의형제" % [nm, josa(nm, "과")])
	else:
		_add_rel(nm, "친구", tr, rng.randi_range(45, 75))
		_log("%s%s 단짝이 되었다.%s" % [nm, josa(nm, "과"), " 같은 해 태어난 동갑내기다." if peer else ""], "peer" if peer else "life")


func _bond(d: int) -> void:
	if _rel_i >= 0 and _rel_i < rels.size():
		rels[_rel_i].bond = clampi(int(rels[_rel_i].bond) + d, 0, 100)


## 인연에서 생기는 갈림길 — 그 사람의 성향대로 권하고, 따르면 정이 깊어지고 안 따르면 멀어진다.
func _rel_event() -> void:
	var cands: Array = []
	for i in rels.size():
		var r: Dictionary = rels[i]
		if not r.alive or r.kind == "자식" or r.kind == "헤어진 배우자":
			continue
		if r.kind == "사부" and (not martial or flags.has("quit")):
			continue
		if r.kind in ["아버지", "어머니"] and (age < 10 or age > 26):
			continue
		if age - int(r.get("last", -9)) < 5:
			continue
		cands.append(i)
	if cands.is_empty():
		return
	_rel_i = cands[rng.randi() % cands.size()]
	var r: Dictionary = rels[_rel_i]
	r["last"] = age
	if r.kind in ["아버지", "어머니"]:
		_parent_advice(r)
		return
	var who := String(r.kind) if r.kind in ["아버지", "어머니"] else "%s %s" % [r.kind, r.name]
	var wj := who + josa(who, "이")
	var ev := {}
	match String(r.tt):
		"warrior":
			if r.kind == "사부":
				ev = {id = "r_master", txt = "%s 비전 초식을 전해 주겠다며 밤에 따로 불렀다." % wj,
						ch = [{l = "간다", p = ["wis", 0.45], txt = "한 초식을 온전히 받아 냈다.", fx = {xp = 15, do = "bond:10"},
								ftxt = "끝내 깨닫지 못했다. 사부가 한숨을 쉬었다.", ffx = {do = "bond:-5"}},
							{l = "몸이 고단해 쉰다", txt = "사부의 눈빛이 식었다.", fx = {do = "bond:-15"}}]}
			elif martial:
				ev = {id = "r_spar", txt = "%s 한 수 겨뤄 보자고 했다." % wj,
						ch = [{l = "겨룬다", txt = "땀을 흘리며 웃었다.", fx = {xp = 5, do = "bond:8"}},
							{l = "사양한다", txt = "다음으로 미뤘다.", fx = {do = "bond:-4"}}]}
			else:
				ev = {id = "r_dojo", txt = "%s 고을 무관에 같이 다니자고 했다." % wj,
						ch = [{l = "따라간다", p = ["gol", 0.18], txt = "칼 쓰는 법을 배우기 시작했다.", fx = {do = ["learn", "bond:10", "focus:body"]},
								ftxt = "무관 사범이 재목이 아니라며 돌려보냈다. 몸은 단단해졌다.", ffx = {gol = 4, do = "bond:5"}},
							{l = "내 일이 바쁘다", txt = "고개를 저었다.", fx = {do = "bond:-6"}}]}
		"scholar":
			ev = {id = "r_study", txt = "%s 같이 글을 읽자며 책을 건넸다." % wj,
					ch = [{l = "글을 배운다", txt = "밤마다 등잔 밑에 앉았다.", fx = {wis = 4, flag = "study", do = ["bond:8", "focus:study"]}},
						{l = "책을 덮는다", txt = "글은 나와 맞지 않았다.", fx = {do = "bond:-5"}}]}
		"trader":
			ev = {id = "r_trade", txt = "%s 같이 장사를 해 보자고 했다." % wj,
					ch = [{l = "돈을 보탠다", p = ["luck", 0.5], txt = "장사가 잘되어 이문을 나눴다.", fx = {gold = 70, do = ["bond:8", "focus:trade"]},
							ftxt = "장사가 망했다. 그래도 같이 망해서 정은 남았다.", ffx = {gold = -35, do = "bond:3"}},
						{l = "거절한다", txt = "돈 얘기에 서운한 기색이었다.", fx = {do = "bond:-6"}}]}
		"wander":
			ev = {id = "r_travel", txt = "%s 넓은 세상을 함께 보러 가자고 했다." % wj,
					ch = [{l = "따라나선다", txt = "짐을 꾸려 길을 떠났다.", fx = {do = ["bond:10", "focus:travel", "move"]}},
						{l = "고향에 남는다", txt = "멀어지는 뒷모습을 오래 보았다.", fx = {do = "bond:-8"}}]}
		"gambler":
			ev = {id = "r_vice", txt = "%s 노름판에 같이 가자고 졸랐다." % wj,
					ch = [{l = "따라간다", p = ["luck", 0.35], txt = "운이 좋았다. 둘이 술을 샀다.", fx = {gold = 40, good = -3, do = "bond:6"},
							ftxt = "가진 돈을 다 잃었다.", ffx = {gold = -50, good = -4, do = "bond:3"}, g = -1},
						{l = "말린다", txt = "말리다가 크게 다퉜다.", fx = {good = 4, do = "bond:-12"}, g = 1}]}
		"kind":
			ev = {id = "r_kind", txt = "%s 어려운 이웃을 함께 돕자고 했다." % wj,
					ch = [{l = "돕는다", txt = "쌀 두 말을 나눴다. 마음이 따뜻했다.", fx = {gold = -10, good = 8, fame = 2, do = "bond:8"}, g = 1},
						{l = "우리 살기도 바쁘다", txt = "말없이 고개를 돌렸다.", fx = {do = "bond:-6"}, g = -1}]}
		"rough":
			ev = {id = "r_rough", txt = "%s 패싸움에 끼자고 했다." % wj,
					ch = [{l = "같이 간다", p = ["gol", 0.45], txt = "이겼다. 둘이 어깨동무를 했다.", fx = {good = -5, gol = 2, do = "bond:10"},
							ftxt = "흠씬 맞고 돌아왔다.", ffx = {hp = -12, good = -5, do = "bond:5"}, g = -1},
						{l = "빠진다", txt = "겁쟁이라는 소리를 들었다.", fx = {do = "bond:-10"}, g = 1}]}
		"pious":
			ev = {id = "r_temple", txt = "%s 산사에 함께 기도하러 가자고 했다." % wj,
					ch = [{l = "따라간다", txt = "향 냄새 속에서 마음이 고요해졌다.", fx = {good = 4, luck = 1, do = "bond:6"}, g = 1},
						{l = "가지 않는다", txt = "다음에 가자고 했다.", fx = {do = "bond:-4"}}]}
	# 배우자와는 다투기도 한다 — 정이 낮으면 헤어진다
	if r.kind == "배우자" and rng.randf() < 0.35:
		ev = {id = "r_quarrel", txt = "배우자 %s%s 크게 다퉜다." % [r.name, josa(String(r.name), "와")],
				ch = [{l = "먼저 사과한다", txt = "밤새 이야기를 나누고 풀었다.", fx = {do = "bond:8"}, g = 1},
					{l = "고집을 부린다", txt = "집 안에 찬바람이 돌았다.", fx = {do = ["bond:-18", "split"]}}]}
	if ev.is_empty():
		return
	_offer(ev)


func _rel_do(d: String) -> bool:
	if d.begins_with("bond:"):
		_bond(int(d.substr(5)))
		return true
	if d.begins_with("focus:"):
		var f := d.substr(6)
		if focus != f and focus_ok(f):
			focus = f
			_log("그 뒤로 %s에 힘썼다." % GhD.focus(f).name)
		return true
	match d:
		"sibling":
			var son := rng.randf() < 0.5
			var nm := (name.substr(0, 2) if TWO_SUR.has(name.substr(0, 2)) else name.substr(0, 1)) + _given("m" if son else "f")
			_add_rel(nm, "남동생" if son else "여동생", _rand_trait(), rng.randi_range(50, 85))
			_log("%s 태어났다. 이름은 %s." % ["남동생이" if son else "여동생이", nm])
			return true
		"father_dies":
			var i := rel_of("아버지")
			if i >= 0:
				rels[i].alive = false
			return true
		"friend":
			_make_friend(false)
			return true
		"sworn":
			_make_friend(true)
			return true
		"split":
			var i := rel_of("배우자")
			if i >= 0 and int(rels[i].bond) < 25:
				rels[i].alive = false
				rels[i].kind = "헤어진 배우자"
				flags.erase("married")
				_log("끝내 %s%s 갈라섰다." % [rels[i].name, josa(String(rels[i].name), "와")], "big")
			return true
	return false


## 부모의 당부 — 같이 하자가 아니라 "이렇게 살아라". 따르면 그 길로 기울고 정이 깊어진다.
func _parent_advice(r: Dictionary) -> void:
	var who := String(r.kind)
	var wj := who + josa(who, "이")
	var ev := {}
	match String(r.tt):
		"warrior":
			ev = {id = "p_body", txt = "%s 사내든 계집이든 몸이 단단해야 산다며 단련을 시키셨다." % wj,
					ch = [{l = "따른다", txt = "새벽마다 뒷산을 뛰었다.", fx = {gol = 4, do = ["bond:8", "focus:body"]}},
						{l = "내 뜻대로 한다", txt = "고개를 저었다.", fx = {do = "bond:-6"}}]}
		"scholar":
			ev = {id = "p_study", txt = "%s 글을 알아야 사람 구실을 한다며 책을 쥐여 주셨다." % wj,
					ch = [{l = "따른다", txt = "서당에 다니기 시작했다.", fx = {wis = 4, flag = "study", do = ["bond:8", "focus:study"]}},
						{l = "내 뜻대로 한다", txt = "책은 구석에 밀어 두었다.", fx = {do = "bond:-6"}}]}
		"trader":
			ev = {id = "p_trade", txt = "%s 셈을 배워 장사를 이으라 하셨다." % wj,
					ch = [{l = "따른다", txt = "장부 보는 법을 배웠다.", fx = {do = ["bond:8", "focus:trade"]}},
						{l = "내 뜻대로 한다", txt = "장터 일은 지겨웠다.", fx = {do = "bond:-6"}}]}
		"wander":
			ev = {id = "p_travel", txt = "%s 넓은 세상을 보고 오라 하셨다." % wj,
					ch = [{l = "길을 떠난다", txt = "봇짐 하나 메고 고향을 떠났다.", fx = {do = ["bond:6", "focus:travel", "move"]}},
						{l = "고향에 남는다", txt = "집이 좋았다.", fx = {do = "bond:-3"}}]}
		"gambler":
			ev = {id = "p_debt", txt = "%s 노름빚을 지고 돌아오셨다." % wj,
					ch = [{l = "대신 갚는다", txt = "모은 돈을 털어 빚을 갚았다.", fx = {gold = -40, good = 3, do = "bond:10"}, g = 1},
						{l = "모른 척한다", txt = "빚쟁이들이 집을 들쑤셨다.", fx = {hp = -4, do = "bond:-12"}}]}
		"rough":
			ev = {id = "p_rough", txt = "%s 술에 취해 매를 드셨다." % wj,
					ch = [{l = "참는다", txt = "멍든 자리를 감추었다.", fx = {hp = -5, good = 2}, g = 1},
						{l = "집을 나간다", txt = "그 길로 집을 나왔다.", fx = {do = ["bond:-25", "move"]}}]}
		"pious":
			ev = {id = "p_temple", txt = "%s 정성껏 기도하는 법을 가르쳐 주셨다." % wj,
					ch = [{l = "따른다", txt = "마음이 고요해졌다.", fx = {good = 4, luck = 1, do = "bond:6"}, g = 1},
						{l = "흘려듣는다", txt = "", fx = {do = "bond:-3"}}]}
		_:
			ev = {id = "p_kind", txt = "%s 남을 해치지 말고 살라 하셨다." % wj,
					ch = [{l = "가슴에 새긴다", txt = "그 말씀을 오래 기억했다.", fx = {good = 8, do = "bond:6"}, g = 1},
						{l = "흘려듣는다", txt = "세상은 그리 착하지 않았다.", fx = {good = -2, do = "bond:-3"}}]}
	_offer(ev)


# ==================== 매년 하는 일 · 지금 하기 ====================
# 원작의 "해마다 가족 여행 · 헬스장 · 식사 · 용돈" 과 "즉흥으로 여행 · 식사 · 용돈" 자리(사용자 설명 11-07).
# 가족 · 벗에게 쓰는 것은 인연의 정을 올리고, 정이 오르면 그 사람의 성향 쪽으로 삶이 더 기운다(mul).

const FAMILY := ["아버지", "어머니", "형", "오빠", "누나", "언니", "남동생", "여동생", "배우자", "자식"]
const FRIENDS := ["친구", "의형제"]


func habit_ok(id: String) -> bool:
	var h := GhD.habit(id)
	if h.is_empty() or age < int(h.a[0]) or age > int(h.a[1]):
		return false
	if h.has("kids") and kids <= 0:
		return false
	if h.has("parents") and rel_of("아버지") < 0 and rel_of("어머니") < 0:
		return false
	if h.has("friends") and not rels.any(func(r): return r.alive and FRIENDS.has(r.kind)):
		return false
	return true


func habit_cost(id: String) -> int:
	var h := GhD.habit(id)
	return int(h.get("cost", 0)) + int(h.get("cost_kid", 0)) * kids


func toggle_habit(id: String) -> void:
	if habits.has(id):
		habits.erase(id)
		_log("%s%s 그만두기로 했다." % [GhD.habit(id).name, josa(String(GhD.habit(id).name), "을")], "pick")
	elif habit_ok(id):
		habits[id] = true
		_log("올해부터 %s%s 하기로 했다." % [GhD.habit(id).name, josa(String(GhD.habit(id).name), "을")], "pick")


func _bond_kind(kinds: Array, d: int) -> void:
	for r: Dictionary in rels:
		if r.alive and kinds.has(r.kind):
			r.bond = clampi(int(r.bond) + d, 0, 100)


func _habits_year() -> void:
	var skipped: Array = []
	for id in habits.keys():
		if not habit_ok(id):
			continue
		var h := GhD.habit(id)
		var c := habit_cost(id)
		if gold < c:
			skipped.append(String(h.name))
			continue
		gold -= c
		for k in h.get("fx", {}):
			var v := float(h.fx[k])
			match k:
				"gol", "wis", "cha", "dex", "wit":
					_grow_stat(k, v)
				"hp":
					hp = clampf(hp + v, 3.0, 100.0)
		if h.has("fam"):
			_bond_kind(FAMILY, int(h.fam))
		if h.has("kids"):
			_bond_kind(["자식"], int(h.kids))
		if h.has("parents"):
			_bond_kind(["아버지", "어머니"], int(h.parents))
		if h.has("friends"):
			_bond_kind(FRIENDS, int(h.friends))
		if h.has("good"):
			_good_acc += float(h.good) * 0.6
		if h.has("flag"):
			flags[h.flag] = true
	_debt_year()
	if not skipped.is_empty() and is_player:
		_log("형편이 어려워 올해는 %s%s 걸렀다." % [", ".join(skipped), josa(String(skipped.back()), "을")])


## 지금 하기 — 한 해에 한 번씩. 안 되는 이유가 있으면 "" 이 아닌 글을 돌려준다(화면에 그대로 적는다).
func act_block(id: String) -> String:
	var a := GhD.action(id)
	if a.is_empty():
		return "없음"
	if not alive:
		return "세상을 떠남"
	if int(acted.get(id, -9)) == age:
		return "올해는 했다"
	if gold < int(a.cost):
		return "재물 부족"
	if id == "loan":
		if age < 16:
			return "열여섯부터"
		if loan_size() < 10:
			return "신용이 모자란다" if debt == 0 else "신용 한도에 닿았다"
	if id == "repay" and (debt <= 0 or gold <= 0):
		return "갚을 빚이 없다" if debt <= 0 else "가진 돈이 없다"
	match id:
		"trip", "feast":
			if age < 16:
				return "열여섯부터"
		"pocket":
			if kids <= 0:
				return "자식이 없다"
		"gift":
			if rel_of("아버지") < 0 and rel_of("어머니") < 0:
				return "부모님이 안 계신다"
			if age < 10:
				return "열 살부터"
		"drink":
			if age < 16:
				return "열여섯부터"
			if not rels.any(func(r): return r.alive and FRIENDS.has(r.kind)):
				return "벗이 없다"
		"sect":
			if martial and not flags.has("quit"):
				return "이미 무림인"
			if age < 8 or age > 30:
				return "여덟에서 서른까지"
			if sect_tries >= 3:
				return "세 번 거절당했다"
		"exam":
			if flags.has("official"):
				return "이미 벼슬"
			if age < 17 or age > 55:
				return "열일곱부터"
			if not (flags.has("study") or cls in ["scholar", "noble", "clerk"]):
				return "글을 배운 적이 없다"
		"match":
			if flags.has("married"):
				return "이미 혼인"
			if age < 16 or age > 45:
				return "열여섯에서 마흔다섯"
		"duel":
			if not martial or flags.has("quit") or age < 16 or age > 70:
				return "무림인만"
		"market":
			if age < 15:
				return "열다섯부터"
		"buyoffice":
			if flags.has("official"):
				return "이미 벼슬"
			if fame < 30 or age < 20:
				return "명성 30 이상"
		"charity":
			if age < 18:
				return "열여덟부터"
		"seclusion":
			if not martial or flags.has("quit") or age < 16 or age > 80:
				return "무림인만"
			if secluded > 0:
				return "폐관 중"
			if int(acted.get("seclusion", -99)) + 8 > age:
				return "여덟 해에 한 번"
		"guard":
			if not martial or flags.has("quit") or age < 16 or age > 70:
				return "무림인만"
		"dojo":
			if not martial or realm < 3:
				return "일류부터"
			if flags.has("dojo"):
				return "이미 차렸다"
	return ""


func act(id: String) -> void:
	if act_block(id) != "":
		return
	var a := GhD.action(id)
	acted[id] = age
	gold -= int(a.cost)
	_log("> " + String(a.name), "pick")
	match id:
		"trip":
			var r: Dictionary = GhD.REGIONS[rng.randi() % GhD.REGIONS.size()]
			_log("가족과 함께 %s%s 여행을 다녀왔다. 오래 기억에 남았다." % [r.name, josa(String(r.name), "로")])
			_bond_kind(FAMILY, 8)
			hp = minf(100.0, hp + 3.0)
			# 길 위에서는 뜻밖의 일이 생긴다 — 기연 · 만남 꼬리표가 붙은 일 하나를 굴린다
			if rng.randf() < 0.35:
				var pool: Array = GhEv.all().filter(func(e): return String(e.get("tag", "")) in ["luck", "meet"] and _ok_loose(e))
				if not pool.is_empty():
					_fire(pool[rng.randi() % pool.size()])
		"feast":
			_log("가족에게 고기와 술을 넉넉히 차려 냈다. 웃음소리가 담을 넘었다.")
			_bond_kind(FAMILY, 6)
		"pocket":
			_log("자식들에게 용돈을 쥐여 주었다. 아이들 얼굴이 환해졌다.")
			_bond_kind(["자식"], 10)
		"gift":
			_log("부모님께 비단 한 필을 선물했다. 어머니가 눈시울을 붉혔다.")
			_bond_kind(["아버지", "어머니"], 10)
			good = clampi(good + 2, -100, 100)
		"doctor":
			_log("이름난 의원에게 진맥을 받고 약을 지었다. 몸이 한결 가벼워졌다.")
			hp = minf(100.0, hp + 12.0)
		"drink":
			_log("벗과 밤새 술잔을 기울이며 지난 이야기를 했다.")
			_bond_kind(FRIENDS, 7)
		"sect":
			# 평생 세 번 — 해마다 두드릴 수 있으면 결국 붙어서 "누구로 태어났나" 가 사라진다(재 보니 무공이 46% 였다)
			sect_tries += 1
			var chance := clampf(0.1 + (gol - 50) * 0.006, 0.03, 0.7) * minf(2.0, mul("entry"))
			if rng.randf() < chance:
				_do("join_jeong")
			else:
				_log("%s의 문지기가 골격을 보더니 고개를 저었다." % near_sect())
		"exam":
			var chance := clampf(0.06 + (wis - 50) * 0.006 + (0.06 if cls in ["scholar", "noble"] else 0.0), 0.02, 0.7) * minf(2.0, mul("civil"))
			if rng.randf() < chance:
				_log("급제했다! 이름이 방에 붙었다.", "big")
				fame += 12
				_do("office")
			else:
				_log("낙방했다. 붓을 다시 잡았다.")
		"match":
			if rng.randf() < 0.5:
				_marry("")
			else:
				_log("혼처를 알아보았지만 마땅한 자리가 없었다.")
		"duel":
			_do("duel")
		"seclusion":
			secluded = 2
			_log("문을 걸어 잠그고 폐관에 들었다.", "big")
		"guard":
			var pay := 30 + realm * 20
			if rng.randf() < 0.3:
				_log("호위하던 길에 습격을 받았다.")
				_do("duel")
			if alive:
				gold += pay
				_log("호위를 마치고 %d냥을 받았다." % pay)
		"dojo":
			flags["dojo"] = true
			_log("고을에 무관을 차렸다. 제자들이 모여들었다.", "big")
			_big("무관을 차림")
			fame += 5
		"buyoffice":
			_log("뒷돈을 써서 벼슬자리를 샀다.", "big")
			good = clampi(good - 10, -100, 100)
			flags["corrupt"] = true
			_do("office")
		"charity":
			_log("고을에 의연금을 내어 굶주린 이들을 먹였다. 사람들이 이름을 칭송했다.")
			fame += 15
			good = clampi(good + 10, -100, 100)
		"loan":
			var amt := loan_size()
			debt += amt
			gold += amt
			_log("전장에서 신용으로 %d냥을 빌렸다. 빚이 %d냥이 되었다." % [amt, debt])
		"repay":
			var pay := mini(gold, debt)
			gold -= pay
			debt -= pay
			if debt == 0:
				repaid += 1
			_log("빚 %d냥을 갚았다." % pay + (" 빚을 다 갚았다!" if debt == 0 else " 아직 %d냥이 남았다." % debt))
		"market":
			if rng.randf() < clampf(0.35 + (luck - 5) * 0.06, 0.1, 0.8) * minf(1.5, mul("trade")):
				gold += 50
				_log("싼값에 사들인 물건이 금값이 되었다.")
			else:
				gold = maxi(0, gold - 20)
				_log("물건을 비싸게 떠안고 말았다.")


## 여행 중 뜻밖의 일 — 나이 · 깃발만 보고(그해 이미 나왔는지, pr 굴림은 건너뛴다).
func _ok_loose(ev: Dictionary) -> bool:
	if ev.has("ch") == false and String(ev.get("txt", "")) == "":
		return false
	var a: Array = ev.a
	if age < int(a[0]) or age > int(a[1]):
		return false
	if seen.has(ev.id) and not ev.has("cd"):
		return false
	if ev.has("mart") and bool(ev.mart) != martial:
		return false
	for f in ev.get("need", []):
		if not flags.has(f):
			return false
	return true




## 빚 — 해마다 이자 1할. 갚을 힘이 없으면 독촉이 오고, 너무 불어나면 야반도주한다.
func _debt_year() -> void:
	if debt <= 0:
		return
	debt += maxi(1, ceili(debt * 0.1))
	if gold >= debt * 0.1 or rng.randf() > 0.35:
		return
	if debt >= 1000:
		_log("빚이 %d냥까지 불었다. 빚쟁이에 쫓겨 야반도주했다." % debt, "big")
		_big("빚에 쫓겨 야반도주")
		defaults += 2
		fame = maxi(0, fame - 10)
		_bond_kind(FAMILY, -10)
		debt = int(debt * 0.5)
		_do("move")
		return
	defaults += 1
	var take := gold / 2
	gold -= take
	hp = maxf(3.0, hp - 5.0)
	_bond_kind(FAMILY, -3)
	_log("전장 사람들이 빚을 독촉하러 와서 집을 뒤졌다.%s" % (" %d냥을 빼앗겼다." % take if take > 0 else ""))


# ==================== 익힌 무공 · 전환점 · 신용 ====================

var arts_known: Array = []     ## 익힌 무공 이름(익힌 차례)
var moments: Array = []        ## 화면이 삽화로 띄울 전환점 {key, title, txt} — 플레이어만 쌓는다
var immortal := false           ## 확인용(클릭 검사) — 씨앗에 기대면 사건이 늘 때마다 아이가 일찍 죽어 검사가 엉뚱하게 깨졌다
var repaid := 0                ## 빚을 다 갚은 횟수(신용 +)
var defaults := 0              ## 빚을 떼먹은 횟수(신용 -)
var sect_tries := 0             ## 문파 찾아가 입문을 청한 횟수(평생 세 번)


## 지금 문파(또는 독학)의 다음 무공을 익힌다. 입문할 때 하나, 경지가 오를 때마다 하나.
func _learn_art() -> void:
	var pool: Array = GhD.SOLO_ARTS
	var s := GhD.sect(sect_id)
	if sect_id != "" and s.has("arts"):
		pool = s.arts
	for a in pool:
		if not arts_known.has(a):
			arts_known.append(a)
			art = String(a)
			if age > 0:
				_log("%s%s 익혔다." % [a, josa(String(a), "을")], "realm")
			return


func _moment(key: String, title: String, txt: String) -> void:
	if is_player:
		moments.append({key = key, title = title, txt = txt, age = age})


## 신용 — 집안 · 명성 · 벼슬 · 재물 · 심성 · 갚은 이력. 빌릴 수 있는 돈과 빚 한도가 여기서 나온다.
const CREDIT_BASE := {"royal": 3000, "cult_heir": 3000, "cult_elder": 600, "noble": 800, "clan": 600, "merchant": 300, "scholar": 200, "clerk": 200,
		"escort": 150, "craft": 120, "sectfam": 100, "farm": 60, "soldier": 60, "fisher": 50, "hunter": 40, "cult": 40,
		"nomad": 40, "tenant": 30, "bandit": 20, "temple": 10, "beggar": 0}


func credit() -> int:
	var c := int(CREDIT_BASE.get(cls, 50)) + credit_bonus + fame * 3 + office * 150 + gold / 2 + maxi(good, 0) + repaid * 40 - defaults * 150
	return maxi(0, c)


## 한 번에 빌릴 수 있는 돈 — 신용의 4할(10냥 단위, 1000냥까지). 빚까지 합쳐 신용을 넘을 수 없다.
func loan_size() -> int:
	var room := credit() - debt
	return clampi(int(minf(credit() * 0.4, room) / 10.0) * 10, 0, 1000)


# ==================== 배움 · 직업 ====================

var job := ""                  ## 배움으로 바꾼 직업("" 이면 태어난 집안의 일)
var course := ""               ## 지금 배우는 것
var course_prog := 0.0
var quals := {}                ## 다 마친 배움


func job_name() -> String:
	if job != "" and GhD.JOBS.has(job):
		return String(GhD.JOBS[job].name)
	return ""


## 배움을 시작할 수 없는 이유("" 이면 된다). 화면이 그대로 적는다.
func course_block(id: String) -> String:
	var c := GhD.course(id)
	if c.is_empty():
		return "없음"
	if quals.has(id):
		return "다 배웠다"
	if course == id:
		return ""
	if course != "":
		return "다른 것을 배우는 중"
	if age < int(c.a[0]) or age > int(c.a[1]):
		return "%d세에서 %d세" % [int(c.a[0]), int(c.a[1])]
	if c.get("mart", false) and (not martial or flags.has("quit")):
		return "무림인만"
	if c.get("nmart", false) and martial:
		return "이미 무림인"
	if c.has("job") and job == String(c.job):
		return "이미 그 일을 한다"
	if gold < int(c.cost):
		return "재물 부족"
	return ""


func start_course(id: String) -> void:
	if course == id:
		_log("%s%s 그만두었다. (%d해 배움)" % [GhD.course(id).name, josa(String(GhD.course(id).name), "을"), int(course_prog)], "pick")
		course = ""
		course_prog = 0.0
		return
	if course_block(id) != "":
		return
	course = id
	course_prog = 0.0
	_log("%s%s 시작했다." % [GhD.course(id).name, josa(String(GhD.course(id).name), "을")], "pick")


func _course_year() -> void:
	if course == "":
		if (not is_player or ai_plan) and age >= 14 and age <= 45 and rng.randf() < 0.035:
			_ai_course()
		return
	var c := GhD.course(course)
	if gold < int(c.cost):
		if is_player:
			_log("배울 돈이 없어 올해는 %s%s 쉬었다." % [c.name, josa(String(c.name), "을")])
		return
	gold -= int(c.cost)
	course_prog += 0.6 + _stat(String(c.stat)) / 100.0
	if course_prog < float(c.years):
		return
	# 다 마쳤다
	var id := course
	course = ""
	course_prog = 0.0
	quals[id] = true
	_log("%s%s 마쳤다." % [c.name, josa(String(c.name), "을")], "big")
	_big("%s 마침" % c.name)
	_moment("gh_m_qual", "배움을 마침", "%s%s 마쳤다." % [c.name, josa(String(c.name), "을")])
	if c.has("flag"):
		flags[c.flag] = true
	match id:
		"inner":
			_gain(40.0)
			_learn_art()
		"escort":
			_do(String(c.join))
			_log("표사가 되었다.", "big")
		"military":
			# 무과 — 근골로 굴린다
			if rng.randf() < clampf(0.35 + (gol - 50) * 0.008, 0.1, 0.9):
				_log("무과에 급제했다!", "big")
				flags["mil_pass"] = true
				fame += 10
				_join("army")
				_offer_job("officer")
			else:
				_log("무과에서 떨어졌다. 익힌 병법은 남았다.")
				gol = mini(100, gol + 3)
		_:
			if c.has("job"):
				_offer_job(String(c.job))


## 전직 갈림길 — 새 일로 갈지, 하던 일을 계속할지.
func _offer_job(j: String) -> void:
	var nm := "상인" if j == "merchant" else String(GhD.JOBS[j].name)
	_offer({id = "job_" + j, txt = "%s의 길이 열렸다. 하던 일을 그만두고 %s%s 될까?" % [nm, nm, josa(nm, "이")],
			ch = [{l = "%s%s 된다" % [nm, josa(nm, "이")], txt = "", fx = {do = "job:" + j}},
				{l = "하던 일을 계속한다", txt = "배운 것은 가슴에 묻어 두었다."}]})


func _job_do(d: String) -> bool:
	if not d.begins_with("job:"):
		return false
	var j := d.substr(4)
	if j == "merchant":
		cls = "merchant"
		job = ""
		_log("상인이 되었다.", "big")
		_big("상인으로 전직")
		return true
	job = j
	_log("%s%s 되었다." % [GhD.JOBS[j].name, josa(String(GhD.JOBS[j].name), "이")], "big")
	_big("%s%s 됨" % [GhD.JOBS[j].name, josa(String(GhD.JOBS[j].name), "이")])
	if j == "monk":
		flags["monk"] = true
		good = clampi(good + 10, -100, 100)
		if martial:
			flags["quit"] = true
	return true


## 동년배 · 자동이 고르는 배움 — 집안 · 아버지 성향에 맞는 것 쪽으로. 무작위로 고르면 표국 견습 · 무과 ·
## 출가가 너무 잦아 무공 비율이 60% 로 튀고 승려가 넘쳤다.
func _ai_course() -> void:
	var tr := ""
	var fi := rel_of("아버지")
	if fi >= 0:
		tr = rels[fi].tt
	var ws := {}
	var tw := 0.0
	for c in GhD.COURSES:
		if course_block(c.id) != "":
			continue
		var w := 1.0
		match String(c.id):
			"medicine", "herbal":
				w = 1.2
			"academy":
				w = 2.5 if cls in ["scholar", "clerk", "noble"] or tr == "scholar" else 0.4
			"commerce":
				w = 2.0 if cls in ["craft", "merchant"] or tr == "trader" else 0.8
			"smith":
				w = 1.5 if cls == "craft" else 0.6
			"escort", "military":
				w = 1.2 if tr == "warrior" or cls == "soldier" else 0.15
			"monk":
				w = 1.0 if tr == "pious" else 0.1
			"inner":
				w = 3.0
		ws[c.id] = w
		tw += w
	var pick := rng.randf() * tw
	for k in ws:
		pick -= ws[k]
		if pick <= 0.0:
			course = k
			course_prog = 0.0
			return


# ==================== 직업 고르기 · 재산 · 사업 ====================

var job_set_age := -9
var land := 1.0                ## 땅값(1 = 보통). 해마다 출렁이고 흉년 · 전쟁에 떨어진다
var houses := {}
var holdings := {}             ## 투자 → 지금 값(냥)
var biz := {}                  ## 사업 → 단(1~3)
var biz_profit := 0            ## 지난해 사업 벌이(화면 표시)


func job_block(j: String) -> String:
	if j == job:
		return "지금 하는 일"
	if age < 14:
		return "열넷부터"
	if job_set_age == age:
		return "올해는 바꿨다"
	if j == "":
		return ""
	var n: Dictionary = GhD.JOB_NEED.get(j, {})
	# qual 은 any_flag · cls_any 중 하나로 대신할 수 있다(글을 배웠으면 서원을 안 나와도 훈장 · 문사)
	var alt := (n.has("any_flag") and (n.any_flag as Array).any(func(f): return flags.has(f))) \
			or (n.has("cls_any") and (n.cls_any as Array).has(cls))
	if n.has("qual") and not quals.has(n.qual) and not alt:
		return "%s%s 마쳐야" % [GhD.course(String(n.qual)).name, josa(String(GhD.course(String(n.qual)).name), "을")]
	if not n.has("qual") and n.has("any_flag") and not alt:
		return "글을 배워야"
	if n.has("flag") and not flags.has(n.flag):
		return "무과 급제가 필요"
	if n.has("martial") and (not martial or (sect_id != "" and not flags.has("quit") and side != "독학")):
		return "문파 없는 무림인"
	if n.has("realm") and (not martial or realm < int(n.realm)):
		return "%s 이상 무림인" % GhD.REALMS[int(n.realm)]
	if n.has("good_max") and good > int(n.good_max):
		return "심성이 너무 곱다"
	if n.has("gol") and gol < int(n.gol):
		return "근골 %d 이상" % int(n.gol)
	if n.has("wis") and wis < int(n.wis):
		return "오성 %d 이상" % int(n.wis)
	if n.has("luck") and luck < int(n.luck):
		return "운이 따라야"
	for k in ["cha", "dex", "wit"]:
		if n.has(k) and _stat(k) < int(n[k]):
			return "%s %d 이상" % [{"cha": "매력", "dex": "손재주", "wit": "수완"}[k], int(n[k])]
	if n.has("sex") and sex != n.sex:
		return "여인만" if n.sex == "f" else "사내만"
	if n.has("gold") and gold < int(n.gold):
		return "밑천 %d냥" % int(n.gold)
	if n.has("biz") and not biz.has(n.biz):
		return "%s%s 차려야" % [GhD.biz(String(n.biz)).name, josa(String(GhD.biz(String(n.biz)).name), "을")]
	if n.has("sides") and not (martial and (n.sides as Array).has(side)):
		return "정파 무림인만"
	return ""


func set_job(j: String) -> void:
	if job_block(j) != "":
		return
	job_set_age = age
	if j == "":
		job = ""
		_log("집안의 일(%s)로 돌아갔다." % cls_name(), "pick")
		return
	_do("job:" + j)


func house_cost(id: String) -> int:
	return int(float(GhD.house(id).cost) * land)


func house_block(id: String) -> String:
	if houses.has(id):
		return ""
	if age < 18:
		return "열여덟부터"
	if gold < house_cost(id):
		return "재물 부족"
	return ""


## 집 — 없으면 사고, 있으면 판다(그때 땅값의 8할).
func house_click(id: String) -> void:
	var h := GhD.house(id)
	if houses.has(id):
		var v := int(house_cost(id) * 0.8)
		houses.erase(id)
		gold += v
		_log("%s%s %d냥에 팔았다." % [h.name, josa(String(h.name), "을")], "pick")
		return
	if house_block(id) != "":
		return
	gold -= house_cost(id)
	houses[id] = true
	fame += int(h.get("fame", 0))
	_log("%s%s %d냥에 샀다." % [h.name, josa(String(h.name), "을"), house_cost(id)], "big")
	_big("%s 장만" % h.name)


func invest(id: String, amount: int) -> void:
	if age < 16 or gold < amount:
		return
	gold -= amount
	holdings[id] = float(holdings.get(id, 0.0)) + amount
	_log("%s에 %d냥을 넣었다." % [GhD.inv(id).name, amount], "pick")


func divest(id: String) -> void:
	if not holdings.has(id):
		return
	var v := int(holdings[id])
	holdings.erase(id)
	gold += v
	_log("%s%s 모두 팔아 %d냥을 거두었다." % [GhD.inv(id).name, josa(String(GhD.inv(id).name), "을"), v], "pick")


func biz_block(id: String) -> String:
	var b := GhD.biz(id)
	var lv := int(biz.get(id, 0))
	if lv >= 3:
		return "다 키웠다"
	if age < 18:
		return "열여덟부터"
	var n: Dictionary = b.need
	if lv == 0:
		if n.has("trade") and not (cls == "merchant" or quals.has("commerce")):
			return "상인이거나 상단 견습"
		if n.has("quals") and not (n.quals as Array).any(func(q): return quals.has(q)):
			return "배움이 필요"
		if n.has("realm") and (not martial or realm < int(n.realm)):
			return "일류 이상 무림인"
		if n.has("fame") and fame < int(n.fame):
			return "명성 %d 이상" % int(n.fame)
	if gold < biz_cost(id):
		return "재물 부족"
	return ""


func biz_cost(id: String) -> int:
	var lv := int(biz.get(id, 0))
	return int(GhD.biz(id).cost) if lv == 0 else int(int(GhD.biz(id).cost) * lv * 1.5)


## 사업 — 없으면 차리고, 있으면 한 단 키운다.
func biz_click(id: String) -> void:
	if biz_block(id) != "":
		return
	var b := GhD.biz(id)
	var lv := int(biz.get(id, 0))
	gold -= biz_cost(id)
	biz[id] = lv + 1
	if lv == 0:
		_log("%s%s 차렸다." % [b.name, josa(String(b.name), "을")], "big")
		_big("%s 차림" % b.name)
		_moment("gh_m_biz", "사업", "%s%s 차렸다." % [b.name, josa(String(b.name), "을")])
	else:
		_log("%s%s 넓혔다. (%d단)" % [b.name, josa(String(b.name), "을"), lv + 1], "pick")


func biz_close(id: String) -> void:
	if not biz.has(id):
		return
	var b := GhD.biz(id)
	var back := int(int(b.cost) * int(biz[id]) * 0.4)
	biz.erase(id)
	gold += back
	_log("%s%s 접고 %d냥을 건졌다." % [b.name, josa(String(b.name), "을"), back], "pick")


func assets_value() -> int:
	var v := 0
	for id in houses:
		v += int(house_cost(id) * 0.8)
	for id in holdings:
		v += int(holdings[id])
	for id in biz:
		v += int(int(GhD.biz(id).cost) * int(biz[id]) * 0.4)
	return v


func _economy_year() -> void:
	var y := birth_year + age
	var war := world.has(y, "war") or world.has(y, "war_start") or world.has(y, "rebel")
	var famine := world.has(y, "famine")
	# 땅값
	land *= 1.0 + rng.randf_range(-0.05, 0.07)
	if famine:
		land *= 0.85
	if war:
		land *= 0.88
	if world.has(y, "harvest"):
		land *= 1.04
	land = clampf(land, 0.4, 3.0)
	# 집
	for id in houses:
		var h := GhD.house(id)
		gold += int(h.get("inc", 0) * (0.5 if famine or war else 1.0))
		hp = clampf(hp + float(h.get("hp", 0)), 3.0, 100.0)
		if h.has("fam"):
			_bond_kind(FAMILY, int(h.fam))
	# 투자
	for id in holdings.keys():
		var inv := GhD.inv(id)
		if inv.has("bust") and rng.randf() < float(inv.bust):
			_log("%s%s 망했다. 넣은 돈 %d냥이 날아갔다." % [inv.name, josa(String(inv.name), "이"), int(holdings[id])], "big")
			holdings.erase(id)
			continue
		var r := float(inv.mu) + rng.randfn(0.0, float(inv.sd))
		if id == "caravan" and (war or famine):
			r -= 0.3
		holdings[id] = maxf(0.0, float(holdings[id]) * (1.0 + r))
	# 사업
	biz_profit = 0
	var broke: Array = []
	for id in biz:
		var b := GhD.biz(id)
		var lv := int(biz[id])
		var p := float(b.base) * lv * rng.randf_range(0.4, 1.6) * (1.0 + fame / 300.0)
		if war:
			p *= 0.5
		if rng.randf() < 0.12:
			p = -float(b.base) * lv * rng.randf_range(0.4, 1.2)
			if is_player:
				_log(["%s에 도적이 들어 큰 손해를 봤다.", "%s에 손님이 끊겨 적자가 났다.", "%s의 물건이 상해 다 버렸다."][rng.randi() % 3] % b.name)
		biz_profit += int(p)
		# 망하기 — 키울수록 위험도 커진다. 운이 좋으면 덜 망한다
		if rng.randf() < 0.035 + 0.02 * lv - luck * 0.003 + (0.05 if war else 0.0):
			broke.append(id)
	gold = maxi(0, gold + biz_profit)
	for id in broke:
		var bb := GhD.biz(id)
		var loss := int(int(bb.cost) * int(biz[id]) * 0.3)
		biz.erase(id)
		gold = maxi(0, gold - loss)
		_log("%s%s 망했다. 빚잔치를 하고 문을 닫았다." % [bb.name, josa(String(bb.name), "이")], "big")
		_big("%s 파산" % bb.name)
		_moment("gh_m_ruin", "파산", "%s%s 망했다. 쌓아 온 것이 하루아침에 무너졌다." % [bb.name, josa(String(bb.name), "이")])
	if job == "gambler":
		gold = maxi(0, gold + rng.randi_range(-60, 80))
	if biz_profit > 0:
		fame += 1


# ==================== 직업 단계 ====================

var work_xp := {}              ## 일 열쇠 → 경력
var work_rank := {}            ## 일 열쇠 → 단(0부터)
var feats := {}                ## 일 열쇠 → 공적(그 일의 큰일을 해낸 횟수)


## 지금 하는 일의 열쇠 — 직업이 있으면 직업, 없으면 집안의 일(단이 없는 집안이면 "")
func work_key() -> String:
	if job != "":
		return job if GhD.JOB_RANKS.has(job) else ""
	var k := "cls:" + cls
	return k if GhD.JOB_RANKS.has(k) else ""


func work_rank_now() -> int:
	return int(work_rank.get(work_key(), 0))


## 지금 단의 이름(예: 명의). 단이 없는 일이면 직업 이름 또는 집안 이름
func work_title() -> String:
	var k := work_key()
	if k == "":
		return job_name() if job != "" else cls_name()
	var rs: Array = GhD.JOB_RANKS[k].ranks
	return String(rs[mini(work_rank_now(), rs.size() - 1)])


func work_max() -> int:
	var k := work_key()
	return 0 if k == "" else (GhD.JOB_RANKS[k].ranks as Array).size() - 1


func work_mul() -> float:
	return float(GhD.RANK_MUL[mini(work_rank_now(), GhD.RANK_MUL.size() - 1)])


func _work_year() -> void:
	var k := work_key()
	if k == "" or age < 15 or (martial and job == "" and not flags.has("quit")):
		return
	var info: Dictionary = GhD.JOB_RANKS[k]
	var st := _stat(String(info.stat))
	var sp := 0.6 + (st / 100.0 if String(info.stat) != "luck" else st / 10.0)
	if focus == "home":
		sp *= 1.4
	if age > 60:
		sp *= 0.5
	work_xp[k] = float(work_xp.get(k, 0.0)) + sp
	var r := int(work_rank.get(k, 0))
	var top := (info.ranks as Array).size() - 1
	if r >= top or float(work_xp[k]) < float(GhD.JOB_XP[mini(r + 1, GhD.JOB_XP.size() - 1)]):
		return
	if r >= GhD.JOB_WALL_FROM or r + 1 == top:
		# 벽 — 공적이 없으면 못 넘는다. 공적이 많을수록 잘 넘는다. **꼭대기 한 단은 언제나 벽**이다
		# (3단짜리 직업은 벽이 없어서 가만히 살아도 절반이 십장 · 서원 학장이었다)
		# 공적 하나에 시도 한 번 — 해마다 다시 굴리면 공적 하나로 결국 넘어 버려서 가만히 살아도 넷째 단이 흔했다
		var f := int(feats.get(k, 0))
		if f <= 0:
			work_xp[k] = minf(float(work_xp[k]), float(GhD.JOB_XP[r + 1]) * 1.3)
			return
		feats[k] = f - 1
		var ok := rng.randf() < 0.18 + (st / 100.0 if String(info.stat) != "luck" else st / 10.0) * 0.25
		if not ok:
			if is_player:
				_log("%s의 다음 자리를 넘보았지만 아직 모자랐다." % nm_now())
			return
	work_rank[k] = r + 1
	var nm := String(info.ranks[r + 1])
	_log("%s%s 되었다." % [nm, josa(nm, "이")] if r + 1 < top else "%s. 그 길의 끝에 올랐다." % nm, "big")
	if r + 1 >= 2:
		_big("%s에 오름" % nm)
		_moment("gh_m_rank", nm, "%s의 길에서 %s%s 되었다." % [job_name() if job != "" else cls_name(), nm, josa(nm, "이")])
	fame += 3 * (r + 1)


## 직업 칭호 — 꼭대기 단이면 "천하의 OO", 높은 단이면 "OO의 OO", 아니면 "이름난 OO"(명성) / "OO의 OO"
func _work_epithet() -> String:
	var t := work_title()
	if work_key() != "" and work_rank_now() >= work_max() and work_max() >= 2:
		return t if t.begins_with("천하") else "천하의 %s" % t
	if fame >= 40 and work_rank_now() < 2:
		return "이름난 %s" % t
	return "%s의 %s" % [region_name(), t]


func nm_now() -> String:
	return work_title()


# ==================== 가세 · 몇째 · 가산 · 후계 ====================

var wealth := 1                ## GhD.WEALTH 번호(0 빈한 ~ 4 거부)
var order := "first"           ## only · first · second · last
var heir := true               ## 가산 · 가주 자리를 잇는 자리인가
var estate := 0                ## 집안 재산(가산) — 부모가 떠날 때 잇는 사람에게 간다
var inherited := false
var credit_bonus := 0


func _roll_house() -> void:
	var tw := 0.0
	for w in GhD.WEALTH:
		tw += float(w.w)
	var pick := rng.randf() * tw
	for i in GhD.WEALTH.size():
		pick -= float(GhD.WEALTH[i].w)
		if pick <= 0.0:
			wealth = i
			break
	# 거지 · 소작 · 절에 버려진 아이는 부유할 수 없다 — 집안이 곧 가세다
	if cls in ["beggar", "temple"]:
		wealth = 0
	elif cls == "tenant":
		wealth = mini(wealth, 1)
	var wd: Dictionary = GhD.WEALTH[wealth]
	birth_p *= float(wd.w) / tw if not cls in ["beggar", "temple", "tenant"] else 1.0
	var base := int(GhD.cls(cls).gold)
	gold = int(base * float(wd.k) * 0.3)
	estate = int(base * float(wd.k) * 4.0)
	credit_bonus = int(wd.credit)
	hp = clampf(hp + float(wd.hp), 30.0, 98.0)
	# 몇째
	var ow := 0.0
	for o in GhD.ORDER:
		ow += float(o.w)
	pick = rng.randf() * ow
	for o in GhD.ORDER:
		pick -= float(o.w)
		if pick <= 0.0:
			order = String(o.id)
			heir = bool(o.heir)
			birth_p *= float(o.w) / ow
			break
	if order == "only":
		flags["only_child"] = true
	elif order == "last":
		flags["youngest"] = true


## 장남 · 차녀 · 막내아들 · 외동딸 …
func child_label() -> String:
	var son := sex == "m"
	match order:
		"only":
			return "외동아들" if son else "외동딸"
		"first":
			return "장남" if son else "장녀"
		"second":
			return "차남" if son else "차녀"
	return "막내아들" if son else "막내딸"


## 태어난 집안을 부르는 이름 — "사천당가" · "부유한 상인 집안" · "빈한한 농가"
func house_name() -> String:
	if cls == "clan" and GhD.CLAN_NAME.has(clan_id):
		return String(GhD.CLAN_NAME[clan_id])
	var w := String(GhD.WEALTH[wealth].name)
	return (w + " " + cls_name()) if w != "" else cls_name()


## 둘째 · 막내는 손위 형제가 있다. 외동은 동생도 안 생긴다(sibling 사건이 깃발을 본다).
func _siblings_at_birth() -> void:
	if order in ["second", "last"]:
		var n := 1 if order == "second" else rng.randi_range(1, 3)
		var sur := name.substr(0, 2) if TWO_SUR.has(name.substr(0, 2)) else name.substr(0, 1)
		for i in n:
			var male := rng.randf() < 0.5
			var kind := ("형" if sex == "m" else "오빠") if male else ("누나" if sex == "m" else "언니")
			_add_rel(sur + _given("m" if male else "f"), kind, _rand_trait(), rng.randi_range(45, 85))


## 부모가 모두 떠나면 가산을 나눈다 — 잇는 자리(장자 · 외동)는 전부, 나머지는 3할.
func _inherit_check() -> void:
	if inherited or age < 1:
		return
	if rel_of("아버지") >= 0 or rel_of("어머니") >= 0:
		return
	inherited = true
	if estate <= 0:
		return
	if heir:
		gold += estate
		var hk: String = GhD.WEALTH_HOUSE[wealth]
		var got: Array = ["%s냥" % estate]
		if hk != "" and not houses.has(hk):
			houses[hk] = true
			got.append(String(GhD.house(hk).name))
		if wealth >= 3 and cls == "merchant" and not biz.has("silk"):
			biz["silk"] = 1
			got.append("비단 가게")
		_log("부모님의 가산을 물려받았다. (%s)" % ", ".join(got), "big")
		_big("가산을 물려받음")
		if wealth >= 3:
			_moment("gh_m_inherit", "가산 상속", "집안의 재산을 모두 물려받았다. (%s)" % ", ".join(got))
	else:
		var share := int(estate * 0.3)
		gold += share
		_log("가산은 맏이에게 돌아가고 %d냥을 나눠 받았다." % share)


## 세가 · 문파 속가의 장자 — 후계 지목, 동생과의 다툼, 가주 승계. 장자가 아니면 집을 떠날 자유가 있다.
func _heir_events() -> void:
	if cls in ["cult_elder", "cult_heir"]:
		_cult_heir_events()
		return
	if not cls in ["clan", "sectfam"] or not martial:
		return
	var house := house_name() if cls == "clan" else "%s의 속가" % sect_name()
	if heir:
		if age >= 16 and age <= 25 and not flags.has("heir_named") and rng.randf() < 0.25:
			flags["heir_named"] = true
			_log("%s의 다음 가주로 지목되었다." % house, "big")
			_big("%s의 후계자" % house)
			_moment("gh_m_heir", "후계자", "%s의 다음 가주로 지목되었다." % house)
			# 동생이 있으면 자리를 노리기도 한다
			if rels.any(func(r): return r.alive and r.kind in ["남동생", "여동생"]):
				for r: Dictionary in rels:
					if r.alive and r.kind in ["남동생", "여동생"] and String(GhD.trait_of(r.tt).id) in ["rough", "gambler", "warrior"]:
						_rel_i = rels.find(r)
						_offer({id = "heir_rival", txt = "%s %s%s 가주 자리를 탐내 원로들을 모았다." % [r.kind, r.name, josa(String(r.name), "이")],
								ch = [{l = "실력으로 누른다", p = ["gol", 0.5], txt = "비무로 꺾고 자리를 지켰다. 동생은 고개를 숙였다.", fx = {fame = 8, do = "bond:-15"},
										ftxt = "비무에서 졌다. 후계 자리를 동생에게 빼앗겼다.", ffx = {unflag = "heir_named", do = "bond:-25"}},
									{l = "동생에게 양보한다", txt = "자리를 내주고 강호로 나섰다.", fx = {unflag = "heir_named", good = 10, do = "bond:20", flag = "free"}, g = 1}]})
						return
		if flags.has("heir_named") and not flags.has("house_head") and age >= 38 and rng.randf() < 0.2:
			flags["house_head"] = true
			_learn_secret()
			fame += 30
			gold += estate
			_log("%s의 가주가 되었다." % house, "big")
			_big("%s의 가주" % house)
			_moment("gh_m_heir", "가주", "%s의 가주 자리에 올랐다." % house)
	elif age >= 17 and age <= 30 and not flags.has("free") and rng.randf() < 0.12:
		flags["free"] = true
		_offer({id = "leave_house", txt = "장자가 아닌 몸이라 집안에 매일 까닭이 없었다.",
				ch = [{l = "집을 떠나 강호로 나선다", txt = "검 한 자루를 메고 집을 나섰다.", fx = {flag = "journey", do = "focus:travel"}},
					{l = "가문을 돕는다", txt = "형님의 오른팔이 되었다.", fx = {good = 4, fame = 3}}]})


## 절세 무공 — 그 문파의 비전 하나. 익히면 비무에서 한 단 위의 힘에 가깝다.
func _learn_secret() -> void:
	if not martial or sect_id == "" or not GhD.SECRET.has(sect_id):
		return
	var s: String = GhD.SECRET[sect_id]
	if arts_known.has(s):
		return
	arts_known.append(s)
	secret = s
	_log("%s의 비전 %s%s 전해 받았다." % [sect_name(), s, josa(s, "을")], "realm")
	_big("절세 무공 %s" % s)
	_moment("gh_m_secret", "절세 무공", "%s의 비전 %s%s 익혔다." % [sect_name(), s, josa(s, "을")])


var secret := ""


## 익힌 무공의 힘 — 가짓수(하나에 0.05, 0.4 까지) + 절세 무공 0.35
func _art_power() -> float:
	var p := minf(0.4, arts_known.size() * 0.05) + (0.35 if secret != "" else 0.0)
	return p + minf(0.15, _cat_count("암기 · 독") * 0.05) + (0.1 if flags.has("sonic") else 0.0)


# ==================== 동년배 라이벌 ====================

var rival := ""                ## 숙적이 된 동년배


func _power_now() -> float:
	return _art_power() + realm + clampf((xp - GhD.REALM_XP[realm]) / maxf(1.0, GhD.REALM_XP[mini(realm + 1, 8)] - GhD.REALM_XP[realm]), 0.0, 0.9) + gol * 0.004


## 장문인 자리 — 같은 문파의 동년배가 살아 있으면 겨룬다. 지면 그 사람이 장문인이 된다. 이기면 true.
func _contest_leader() -> bool:
	for p: GhLife in peers:
		if p.alive and p.martial and p.sect_id == sect_id and not p.flags.has("quit") and not p.flags.has("leader") and p.realm >= realm - 1:
			_log("같은 해 태어나 함께 수련한 %s%s 장문인 자리를 두고 나섰다." % [p.name, josa(p.name, "이")], "peer")
			var mine := _power_now() + fame / 200.0 + rng.randf_range(-0.7, 0.7)
			var theirs := p._power_now() + p.fame / 200.0 + rng.randf_range(-0.7, 0.7)
			if mine >= theirs:
				_log("비무 끝에 %s%s 꺾었다. 장문인 자리는 내 것이 되었다." % [p.name, josa(p.name, "을")], "big")
				p._log("장문인 자리를 두고 같은 해 태어난 %s에게 졌다." % name, "peer")
				return true
			_log("%s에게 졌다. 장문인 자리는 그에게 돌아갔다." % p.name, "big")
			p.flags["leader"] = true
			p.fame += 40
			p._log("장문인 자리를 두고 같은 해 태어난 %s%s 꺾었다. %s의 장문인이 되었다." % [name, josa(name, "을"), sect_name()], "big")
			p._big("%s의 장문인" % sect_name())
			p._learn_secret()
			return false
	return true


static func _bright(sd: String) -> bool:
	return sd in ["정", "세가", "개방"]


## 숙적 — 정 · 사(마)로 갈린 같은 해 태어난 무림인. 한 번 엮이면 몇 해마다 다시 맞붙는다.
func _rival_year() -> void:
	if not martial or flags.has("quit") or age < 18 or age > 65:
		return
	if rival == "":
		for p: GhLife in peers:
			if p.alive and p.martial and not p.flags.has("quit") and p.rival == "" and p.age >= 18 \
					and _bright(side) != _bright(p.side) and side != "관군" and p.side != "관군" and rng.randf() < 0.04:
				rival = p.name
				p.rival = name
				_add_rel(p.name, "숙적", "rough", 10)
				p._add_rel(name, "숙적", "rough", 10)
				_log("같은 해 태어난 %s%s 처음 칼을 맞댔다. 이 사람과는 끝을 보게 될 것 같았다." % [p.name, josa(p.name, "과")], "peer")
				p._log("같은 해 태어난 %s%s 처음 칼을 맞댔다. 끝을 보게 될 것 같았다." % [name, josa(name, "과")], "peer")
				_moment("gh_m_rival", "숙적", "%s%s 평생의 숙적이 되었다." % [p.name, josa(p.name, "과")])
				return
		return
	var p: GhLife = null
	for q: GhLife in peers:
		if q.name == rival:
			p = q
	if p == null or not p.alive or rng.randf() > 0.12:
		return
	var mine := _power_now() + rng.randf_range(-0.8, 0.8)
	var theirs := p._power_now() + rng.randf_range(-0.8, 0.8)
	var win := mine >= theirs
	var w: GhLife = self if win else p
	var l: GhLife = p if win else self
	w.fame += 10
	l.hp -= rng.randf_range(15.0, 30.0)
	_log("숙적 %s%s 다시 맞섰다. %s" % [p.name, josa(p.name, "과"), "이겼다." if win else "졌다. 크게 다쳤다."], "peer")
	p._log("숙적 %s%s 다시 맞섰다. %s" % [name, josa(name, "과"), "졌다. 크게 다쳤다." if win else "이겼다."], "peer")
	if rng.randf() < 0.08:
		if win:
			p.die("숙적의 칼", "숙적 %s의 칼에 쓰러졌다." % name)
			_log("숙적 %s%s 마침내 쓰러뜨렸다." % [p.name, josa(p.name, "을")], "big")
			_big("숙적 %s%s 쓰러뜨림" % [p.name, josa(p.name, "을")])
		else:
			die("숙적의 칼", "숙적 %s의 칼에 쓰러졌다." % p.name)


# ==================== 살림 · 뜻밖의 지출 ====================
#
# **돈은 벌기만 하는 게 아니다**(사용자 지적 11-07 — "원하는 루트를 가면 대부분 말년에 부자가 된다").
# 원작처럼 생활비 · 병원비 · 사고 · 사업 실패로 쪼들리는 인생이 나와야 "누구로 태어나 어떻게 살았나" 가 갈린다.
# ① 생활비 — 식구 수 × 사는 수준. 부자일수록 씀씀이가 커진다(체면 · 식객 · 하인). 부모 밑에 있을 때(열여덟 전,
#    부모 생존)는 안 낸다. ② 뜻밖의 지출 — 해마다 몇 %. 크기는 가진 돈에 비례하는 몫이 있어 부자도 크게 잃는다.
# ③ 사업은 해마다 망할 수 있다(_economy_year). 돈이 모자라면 굶고(건강 -), 전장에 빌릴 수 있다.

## 사는 수준(지금 가진 돈으로 정함) → 한 해 기본 생활비 · 가진 돈에서 나가는 몫
const LIVING := [[0, 3, 0.0], [40, 8, 0.02], [300, 22, 0.03], [1500, 70, 0.04], [6000, 220, 0.05]]
const LIVING_NAME := ["빈궁", "소박", "넉넉", "부유", "호화"]


func living_tier() -> int:
	var t := 0
	for i in LIVING.size():
		if gold + assets_value() >= int(LIVING[i][0]):
			t = i
	return t


func living_cost() -> int:
	var t := living_tier()
	var L: Array = LIVING[t]
	var mouths := 1 + (1 if flags.has("married") else 0) + kids
	return int(float(L[1]) * (0.6 + 0.4 * mouths) + gold * float(L[2]))


func _living_year() -> void:
	# 부모 그늘 — 열여덟 전이고 부모가 살아 있으면 집안이 먹여 살린다
	if age < 18 and (rel_of("아버지") >= 0 or rel_of("어머니") >= 0):
		return
	if flags.has("monk"):
		return
	var cost := living_cost()
	if gold >= cost:
		gold -= cost
		return
	var short := cost - gold
	gold = 0
	hp -= minf(12.0, 2.0 + short * 0.4)
	flags["poor_years"] = int(flags.get("poor_years", 0)) + 1
	if is_player and rng.randf() < 0.5:
		_log(["살림이 쪼들려 끼니를 거르는 날이 많았다.", "쌀독이 비었다. 가족이 굶주렸다.", "빚쟁이를 피해 다녔다."][rng.randi() % 3])
	_bond_kind(["배우자", "자식"], -2)


## 뜻밖의 지출 — 해마다 한 번 굴린다. 가진 것이 많을수록 잃는 것도 크다.
func _shock_year() -> void:
	if age < 18 or rng.randf() > 0.13 * mul("danger") ** 0.5:
		return
	var r := rng.randf()
	var lost := 0
	var txt := ""
	if r < 0.32:
		# 병 — 병원비. 못 내면 몸이 더 상한다
		var bill := 15 + int(gold * rng.randf_range(0.08, 0.25))
		hp -= 8.0
		if gold >= bill:
			lost = bill
			txt = "큰 병을 앓아 의원비로 %d냥이 들었다." % bill
		else:
			lost = gold
			hp -= 12.0
			txt = "큰 병을 앓았지만 의원비가 없어 앓아누운 채 버텼다."
	elif r < 0.5:
		lost = int(gold * rng.randf_range(0.1, 0.3))
		txt = "도둑이 들어 %d냥을 털렸다." % lost
	elif r < 0.62:
		lost = int(gold * rng.randf_range(0.15, 0.4)) + 20
		txt = "불이 나서 살림이 타 버렸다. (%d냥)" % lost
		if houses.has("hut") and rng.randf() < 0.4:
			houses.erase("hut")
			txt += " 초가집도 잃었다."
	elif r < 0.76:
		if gold < 150:
			return
		if rng.randf() < 0.25 + luck * 0.04:
			txt = "사기꾼이 그럴듯한 장사를 권했지만 눈치채고 물리쳤다."
		else:
			lost = int(gold * rng.randf_range(0.2, 0.5))
			txt = "그럴듯한 말에 넘어가 사기를 당했다. %d냥을 날렸다." % lost
	elif r < 0.88:
		# 빚보증 — 친척 · 벗의 빚을 떠안는다
		var who := "벗" if rels.any(func(x): return x.alive and FRIENDS.has(x.kind)) else "친척"
		var amount := rng.randi_range(30, 90) + int(gold * rng.randf_range(0.1, 0.4))
		txt = "%s의 빚보증을 섰다가 %d냥을 떠안았다." % [who, amount]
		if gold >= amount:
			lost = amount
		else:
			lost = gold
			debt += amount - gold
			txt += " 모자란 돈은 빚이 되었다."
	else:
		lost = int(gold * rng.randf_range(0.1, 0.25)) + 15
		txt = "송사에 휘말려 관아에 %d냥을 바쳤다." % lost
	lost = clampi(lost, 0, gold)
	gold -= lost
	if txt != "":
		_log(txt, "big" if lost >= 300 else "life")
		if lost >= 1000:
			_big("%d냥을 잃음" % lost)


## 천마신교의 핵심 혈통 — 장로가의 장자는 장로 자리를, 교주 혈통의 장자(소교주)는 교주 자리를 잇는다.
## 소교주는 이복형제의 암투와 정파 자객에 시달리고, 살아남아 절정을 넘기면 천마로 즉위한다.
## 교주 혈통의 장자가 아니면(서출) 적통에게 반기를 들 수 있다 — 이기면 그가 후계가 된다.
func _cult_heir_events() -> void:
	if not martial or side != "마" or flags.has("quit"):
		return
	if cls == "cult_elder":
		if heir and age >= 38 and not flags.has("cult_elder_seat") and rng.randf() < 0.2:
			flags["cult_elder_seat"] = true
			fame += 30
			gold += estate
			_log("아버지의 뒤를 이어 천마신교의 장로가 되었다.", "big")
			_big("천마신교의 장로")
			_moment("gh_m_cult", "신교 장로", "천마신교의 장로 자리에 올랐다.")
		return
	# 교주 혈통
	var heir_now := heir or flags.has("usurp")
	if heir_now:
		if age >= 15 and age <= 32 and not flags.has("cult_rivalry") and rng.randf() < 0.18:
			flags["cult_rivalry"] = true
			_offer({id = "cult_rival", txt = "이복형제들이 소교주 자리를 노려 장로들과 손을 잡았다.",
					ch = [{l = "먼저 친다", p = ["gol", 0.5], txt = "밤사이 이복형제의 무리를 쓸어 버렸다. 아무도 다시 고개를 들지 못했다.", fx = {good = -15, fame = 10},
							ftxt = "역습을 당해 크게 다쳤다. 겨우 자리를 지켰다.", ffx = {hp = -25, do = "risk:0.15:암살"}, g = -1},
						{l = "장로들을 회유한다", p = ["wis", 0.45], txt = "장로들이 등을 돌리지 않았다. 형제들의 음모는 흐지부지되었다.", fx = {fame = 5},
							ftxt = "회유가 먹히지 않았다. 독이 든 술잔을 받았다.", ffx = {hp = -20, do = "risk:0.2:독"}, g = 1}]})
			return
		if age >= 18 and age <= 50 and rng.randf() < 0.07:
			_log("정파가 보낸 자객이 침소에 들었다.")
			_do("duel_strong")
			return
		if age >= 32 and age <= 60 and realm >= 4 and not flags.has("cult_lord") and rng.randf() < 0.22:
			flags["cult_lord"] = true
			fame += 80
			gold += estate
			_learn_secret()
			_log("천마신교의 교주로 즉위했다. 서역의 모든 교도가 천마를 외쳤다.", "big")
			_big("천마로 즉위")
			_moment("gh_m_cult", "천마 즉위", "천마신교의 교주가 되었다.")
		return
	if age >= 16 and age <= 35 and not flags.has("cult_defy") and rng.randf() < 0.12:
		flags["cult_defy"] = true
		_offer({id = "cult_defy", txt = "서출이라는 이유로 교에서 늘 뒷자리였다. 적통인 형이 교주 자리를 이을 것이다.",
				ch = [{l = "반기를 든다", p = ["luck", 0.3], txt = "형을 몰아내고 소교주 자리를 빼앗았다.", fx = {flag = "usurp", fame = 20, good = -10},
						ftxt = "반란이 꺾였다. 교에서 쫓겨났다.", ffx = {do = ["quit", "move"], hp = -15}, g = -1},
					{l = "고개를 숙인다", txt = "형의 그늘 아래서 조용히 살기로 했다."},
					{l = "교를 떠난다", txt = "피의 계승에서 벗어나 중원으로 떠났다.", fx = {do = ["quit", "move"], good = 10}, g = 1}]})


## 근골 · 오성 · 매력 · 손재주 · 수완을 높을수록 덜 오르게 키운다(방침 · 매년 하는 일).
func _grow_stat(k: String, v: float) -> void:
	match k:
		"gol":
			gol = clampi(gol + _grow(v, gol), 1, 100)
		"wis":
			wis = clampi(wis + _grow(v, wis), 1, 100)
		"cha":
			cha = clampi(cha + _grow(v, cha), 1, 100)
		"dex":
			dex = clampi(dex + _grow(v, dex), 1, 100)
		"wit":
			wit = clampi(wit + _grow(v, wit), 1, 100)


## 직업 적성 — 그 직업이 기대는 스텟(GhD.JOB_RANKS 의 stat). 0~1. 화면은 높음 · 보통 · 낮음으로 보여 준다.
func aptitude(j: String) -> float:
	var k := j if j != "" else "cls:" + cls
	if not GhD.JOB_RANKS.has(k):
		return 0.5
	var st := String(GhD.JOB_RANKS[k].stat)
	return clampf((_stat(st) / 10.0 if st == "luck" else _stat(st) / 100.0), 0.0, 1.0)


## 타고난 것으로 보아 어울리는 길 — 적성이 가장 높은 직업 셋(조건은 안 본다: 어울림일 뿐 지금 될 수 있다는 뜻이 아니다)
func suited_jobs(n: int = 3) -> Array:
	var ks: Array = GhD.JOBS.keys()
	ks.sort_custom(func(a, b): return aptitude(a) > aptitude(b))
	return ks.slice(0, n)


# ==================== 무협의 결: 체질 · 별호 · 몸이 바뀌는 순간 · 무공 갈래 · 폐관 · 세 갈래 명성 ====================
# 무협 조사(11-07) 뒤 더한 것들. 경지 숫자 사이에 "몸이 바뀌는 사건" 을 끼우고, 무공에 갈래를 주고,
# 강호에 이름이 나면 별호가 붙는다.

var cons := ""                 ## 타고난 체질("" · 천골지체 · 금강지체 · 만독불침지체 · 천음절맥)
var alias := ""                ## 별호 — 강호에 이름이 나면 붙는다
var infamy := 0                ## 악명(사파 · 마교 쪽의 이름)
var gov := 0                   ## 관부 신망
var secluded := 0              ## 폐관 중 남은 해

## 체질 — 아주 드물게 타고난다. [이름, 확률]
const CONS := [["천골지체", 0.006], ["금강지체", 0.005], ["만독불침지체", 0.004], ["천음절맥", 0.003]]


func _roll_cons() -> void:
	var r := rng.randf()
	for c in CONS:
		r -= float(c[1])
		if r < 0.0:
			cons = String(c[0])
			break
	match cons:
		"천골지체":
			gol = mini(100, gol + 25)
		"금강지체":
			hp = minf(100.0, hp + 8.0)
		"만독불침지체":
			flags["poison_immune"] = true
		"천음절맥":
			wis = mini(100, wis + 25)
			gol = mini(100, gol + 10)


## 사람을 부를 때 — 별호가 있으면 앞에 붙인다(묘비 · 동년배 칸)
func display_name() -> String:
	return ("%s %s" % [alias, name]) if alias != "" else name


## 무공의 갈래 — 이름의 글자로 가른다. 갈래마다 하는 일이 다르다(_art_power · mul).
static func art_cat(a: String) -> String:
	for k in ["사자후", "천음", "음공"]:
		if a.find(k) >= 0:
			return "음공"
	for k in ["독", "화우", "침", "비도", "비수", "추혼표", "암기", "천라지망", "혈영조"]:
		if a.find(k) >= 0:
			return "암기 · 독"
	for k in ["진", "팔괘", "기문", "제갈"]:
		if a.find(k) >= 0:
			return "진법"
	for k in ["보", "신법", "표묘", "운룡", "표풍", "무영", "비호", "두전성이", "소요"]:
		if a.find(k) >= 0:
			return "경공"
	for k in ["검", "검강", "검결"]:
		if a.find(k) >= 0:
			return "검"
	for k in ["도", "부법"]:
		if a.find(k) >= 0:
			return "도"
	for k in ["권", "장", "지", "수인", "조", "인", "박투"]:
		if a.find(k) >= 0:
			return "권장"
	return "내공"


func _cat_count(c: String) -> int:
	var n := 0
	for a in arts_known:
		if art_cat(String(a)) == c:
			n += 1
	return n


## 주 무기 — 가장 많이 익힌 갈래(검 · 도 · 권장). 검기 · 도기 같은 글에 쓴다.
func weapon() -> String:
	var best := "권장"
	var bn := -1
	for c in ["검", "도", "권장"]:
		var n := _cat_count(c)
		if n > bn:
			bn = n
			best = c
	return best


## 경지가 오를 때 몸이 바뀌는 순간 — 연대기 한 줄 + 삽화
func _body_milestone(r: int) -> void:
	var w := weapon()
	var qi: String = {"검": "검기", "도": "도기", "권장": "권기"}[w]
	var gang: String = {"검": "검강", "도": "도강", "권장": "권강"}[w]
	match r:
		3:
			_log("처음으로 %s에 %s%s 서렸다. 한 자 앞의 나뭇잎이 갈라졌다." % [w if w != "권장" else "주먹", qi, josa(qi, "이")], "realm")
		4:
			_log("임독양맥이 뚫렸다. 내공이 막힘없이 온몸을 돌기 시작했다.", "realm")
			_moment("gh_m_realm", "임독양맥 타통", "막혀 있던 두 맥이 뚫렸다.")
		5:
			_log("생사현관이 열렸다. %s%s 맺혔다." % [gang, josa(gang, "이")], "realm")
			_moment("gh_m_realm", "생사현관", "생사의 관문이 열리고 %s%s 맺혔다." % [gang, josa(gang, "이")])
		6:
			_log("뜻만으로 칼이 허공을 날았다. 이기어검의 경지였다." if w == "검" else "기운이 몸을 떠나 형체를 이루었다.", "realm")


## 별호 — 강호에 이름(또는 악명)이 나면 붙는다. 무공 갈래 · 심성 · 쪽으로 짓는다.
const ALIAS_PRE := {"검": ["청운", "추풍", "낙화", "일섬", "유수", "비룡", "월영", "한설", "무정", "쾌"],
		"도": ["광풍", "혈", "폭풍", "단혼", "벽산", "패왕", "흑풍"], "권장": ["철", "벽력", "금강", "파산", "패천", "열화", "흑수"],
		"경공": ["무영", "표풍", "비연", "유령", "천리"], "암기 · 독": ["천수", "비천", "만독", "독수", "혈우"],
		"음공": ["천음", "옥소", "적룡"], "진법": ["팔진", "기문", "천기"], "내공": ["태허", "현천", "청허", "자하"]}
## 무림인이 아닌 이의 별호 — 직업 · 집안의 일로 짓는다(한 사람에 하나를 고른다)
const ALIAS_JOB := {"doctor": ["활인신의", "백수신의", "편작"], "alchemist": ["단약선생", "연단진인"], "painter": ["묵선", "화선"],
		"munsa": ["문곡성", "시선"], "gambler": ["도신", "귀수"], "cook": ["식신", "철수"], "strategist": ["와룡선생", "신산자"],
		"gisaeng": ["해어화", "월하선"], "musician": ["옥소선", "악선"], "mechanist": ["천기자", "귀공자"], "poisoner": ["만독자", "독수"],
		"assassin": ["무영살", "혈수"], "bounty": ["추혼귀", "철포"], "pokwae": ["철포두", "신포"], "geumui": ["금의귀", "비단칼"],
		"merchant": ["만금상", "황금손"], "innkeeper": ["객잔대인"], "diviner": ["신산", "철구"], "smith": ["신장", "철수공"]}


func _alias_check() -> void:
	if alias != "" or age < 18:
		return
	var known := maxi(fame, infamy)
	if martial and not flags.has("quit"):
		if known < 60 or realm < 2:
			return
		var cats: Array = []
		for a in arts_known:
			cats.append(art_cat(String(a)))
		var w := weapon()
		var main := w
		if cats.count("경공") >= 2:
			main = "경공"
		elif cats.count("암기 · 독") >= 2:
			main = "암기 · 독"
		elif flags.has("sonic"):
			main = "음공"
		var core: String = {"검": "검", "도": "도", "권장": "권"}[w]
		var pre_pool: Array = ALIAS_PRE.get(main, ALIAS_PRE["내공"]).filter(func(p): return not String(p).ends_with(core))
		var pre := String(pre_pool[rng.randi() % pre_pool.size()])
		var tail := ""
		if realm >= 6:
			tail = core + ["선", "왕", "신"][rng.randi() % 3]
		elif good <= -30 or side in ["마", "사"] or infamy > fame:
			tail = core + (["마", "귀"][rng.randi() % 2] if side == "마" else "귀")
		elif good >= 30:
			tail = core + "협"
		elif realm >= 4:
			tail = core + ["성", "객"][rng.randi() % 2]
		else:
			tail = core + "객"
		# 이름이 크게 나면 땅을 붙인 "제일" 별호가 되기도 한다
		if fame >= 150 and rng.randf() < 0.4:
			alias = "%s제일%s" % [region_name().substr(0, 2), core]
		else:
			alias = pre + tail
	else:
		var j := job if job != "" else cls
		if known < 90 or not ALIAS_JOB.has(j):
			return
		var pool: Array = ALIAS_JOB[j]
		alias = String(pool[rng.randi() % pool.size()])
	_log("강호 사람들이 %s%s 부르기 시작했다." % [alias, josa(alias, "로")] if infamy <= fame else "사람들이 두려움에 %s%s 불렀다." % [alias, josa(alias, "이라")], "big")
	_big("별호 %s" % alias)
	_moment("gh_m_alias", "별호", "강호가 %s%s 불렀다." % [alias, josa(alias, "라")])


## 폐관수련 — 몇 해 동안 세상과 끊고 수련만 한다(사건 · 인연 · 동년배가 닿지 않는다). 가족과는 멀어진다.
func _seclusion_year() -> bool:
	if secluded <= 0:
		return false
	secluded -= 1
	_gain(6.0 * (1.0 + 0.2 * _cat_count("내공")))
	neigong += 3.0
	_bond_kind(FAMILY, -4)
	if secluded == 0:
		_log("폐관을 마치고 문을 열었다. 눈빛이 달라져 있었다.", "big")
	else:
		_log("폐관 수련 중이다. 바깥 소식은 들리지 않았다.", "flavor")
	return true


func _wuxia_do(d: String) -> bool:
	if d.begins_with("art:"):
		var a := d.substr(4)
		if not arts_known.has(a):
			arts_known.append(a)
			_log("%s%s 깨쳤다." % [a, josa(a, "을")], "realm")
		return true
	if d.begins_with("moment:"):
		_moment("gh_m_cave", d.substr(7), "몸이 달라졌다.")
		return true
	match d:
		"rebirth":
			gol = mini(100, gol + 15)
			hp = 100.0
			flags["rebirth"] = true
			if cons == "천음절맥":
				cons = ""
				_log("천음절맥이 풀렸다.", "big")
			_log("환골탈태했다. 뼈마디가 새로 맞춰지는 소리가 사흘 밤낮 들렸다.", "big")
			_big("환골탈태")
			_moment("gh_m_realm", "환골탈태", "뼈와 살이 새로 태어났다.")
			if martial:
				_gain(20.0)
		"restore":
			flags.erase("crippled")
			realm = mini(realm + 2, GhD.REALMS.size() - 2)
			xp = maxf(xp, float(GhD.REALM_XP[realm]))
			neigong += 15.0
			_log("부서졌던 몸이 전보다 단단하게 다시 짜였다. 전화위복이었다.", "big")
			_big("전화위복")
			_moment("gh_m_cave", "전화위복", "잃었던 무공이 더 크게 돌아왔다.")
		"expel":
			flags["quit"] = true
			flags["expelled"] = true
			infamy += 10
			fame = maxi(0, fame - 10)
			_log("%s에서 파문당했다. 사문의 무공을 쓰지 말라는 명을 받았다." % sect_name(), "big")
			_big("%s에서 파문" % sect_name())
		"mengju":
			flags["mengju"] = true
			fame += 80
			_log("무림맹주로 추대되었다. 천하의 정파가 그 깃발 아래 모였다.", "big")
			_big("무림맹주")
			_moment("gh_m_leader", "무림맹주", "무림맹주가 되었다.")
		"disciple_heir":
			var nm := _stranger(rng.randf() < 0.3)
			_add_rel(nm, "제자", "warrior", 85)
			flags["heir_disciple"] = true
			flags["disciple"] = true
			_log("마침내 재목을 찾았다. 제자 %s에게 평생의 무공을 전했다." % nm, "big")
			_big("전인 %s" % nm)
			_moment("gh_m_heir", "전인", "제자 %s에게 무공을 물려주었다." % nm)
		"last_duel":
			if _duel(realm, 0.0, "마지막 결투에서 이겼다. 젊은이가 무릎을 꿇었다."):
				fame += 20
				_big("마지막 결투에서 이김")
			elif rng.randf() < 0.5:
				die("마지막 결투", "젊은 고수의 칼 아래 웃으며 쓰러졌다. 여한이 없었다.")
		"youth":
			flags["youth"] = true
			hp = 100.0
			_log("반로환동했다. 몸이 서른 해 전으로 돌아갔다.", "big")
			_big("반로환동")
			_moment("gh_m_realm", "반로환동", "늙은 몸이 젊음을 되찾았다.")
		"bounty":
			var opp := clampi(realm + rng.randi_range(-1, 1), 1, 8)
			if _duel(opp, 0.08, "수배범을 붙잡았다."):
				var pay := 80 + opp * 70
				gold += pay
				fame += 3
				_log("관아에서 현상금 %d냥을 받았다." % pay)
				_fx({feat = 1})
		_:
			return false
	return true


## 해마다 — 별호 · 관부 신망 · 타고난 병(천음절맥)
func _wuxia_year() -> void:
	_alias_check()
	if job in ["geumui", "dongchang", "officer", "pokwae", "constable"] or office > 0:
		gov += 1
	if cons == "천음절맥" and age >= 12:
		hp -= 2.0
		if age == 16 and is_player:
			_log("몸속에서 찬 기운이 치솟아 사흘을 앓았다. 의원이 천음절맥이라 했다.", "big")


# ==================== 인생의 갈림길 — 위험과 보상 ====================
# 안전한 쪽은 조금 얻고, 무리한 쪽은 크게 얻거나 크게 잃는다(사용자 요청 11-07 — "돈을 거는 게 아니라
# 인생 선택지의 위험과 보상"). 그래서 결과가 돈 한 줄로 끝나지 않고 **자리가 바뀝니다** — 사업의 단 ·
# 일의 단 · 일자리 · 몸 · 문파. 사건은 GhEv.RISK 에 있다.

func _biggest_biz() -> String:
	var best := ""
	for id in biz:
		if best == "" or int(biz[id]) > int(biz[best]):
			best = id
	return best


func _life_do(d: String) -> bool:
	if d.begins_with("fam:"):
		_bond_kind(FAMILY, int(d.substr(4)))
		return true
	if d.begins_with("debt:"):
		debt += int(d.substr(5))
		_log("전장에 %d냥의 빚을 졌다." % int(d.substr(5)))
		return true
	match d:
		"biz_grow", "biz_grow2":
			var id := _biggest_biz()
			if id == "":
				return true
			var b := GhD.biz(id)
			var up := 2 if d == "biz_grow2" else 1
			var lv := mini(3, int(biz[id]) + up)
			if lv == int(biz[id]):
				gold += int(b.base) * 3
				_log("%s%s 더 넓힐 데가 없어 번 돈이 그대로 남았다." % [b.name, josa(String(b.name), "은")])
			else:
				biz[id] = lv
				_log("%s%s %d단으로 커졌다." % [b.name, josa(String(b.name), "이"), lv], "big")
				_big("%s %d단" % [b.name, lv])
		"biz_shrink":
			var id := _biggest_biz()
			if id == "":
				return true
			var b := GhD.biz(id)
			if int(biz[id]) <= 1:
				biz.erase(id)
				_log("%s%s 문을 닫았다." % [b.name, josa(String(b.name), "이")], "big")
				_big("%s 문 닫음" % b.name)
			else:
				biz[id] = int(biz[id]) - 1
				_log("%s%s 한 단 줄였다." % [b.name, josa(String(b.name), "을")])
		"biz_ruin":
			var id := _biggest_biz()
			if id == "":
				return true
			var b := GhD.biz(id)
			var owe := int(int(b.cost) * int(biz[id]) * 0.5)
			biz.erase(id)
			debt += owe
			_log("%s%s 통째로 넘어갔다. 빚 %d냥이 남았다." % [b.name, josa(String(b.name), "이"), owe], "big")
			_big("%s 파산" % b.name)
			_moment("gh_m_ruin", "파산", "무리한 확장 끝에 %s%s 잃었다." % [b.name, josa(String(b.name), "을")])
		"rank_up":
			var k := work_key()
			if k == "":
				gold += 80
				return true
			var info: Dictionary = GhD.JOB_RANKS[k]
			var r := int(work_rank.get(k, 0))
			if r < (info.ranks as Array).size() - 1:
				work_rank[k] = r + 1
				var nm := String(info.ranks[r + 1])
				_log("단번에 %s%s 되었다." % [nm, josa(nm, "이")], "big")
				_big(nm)
				_moment("gh_m_rank", nm, "모험이 통해 %s%s 되었다." % [nm, josa(nm, "이")])
		"rank_down":
			var k := work_key()
			var r := int(work_rank.get(k, 0))
			if k != "" and r > 0:
				work_rank[k] = r - 1
				var nm := String(GhD.JOB_RANKS[k].ranks[r - 1])
				_log("자리에서 밀려나 다시 %s%s 되었다." % [nm, josa(nm, "이")], "big")
				_big("%s%s 강등" % [nm, josa(nm, "으로")])
		"lose_job":
			if job != "":
				var nm := job_name()
				job = ""
				_log("%s 자리를 잃고 집안의 일로 돌아갔다." % nm, "big")
				_big("%s 자리를 잃음" % nm)
			else:
				_do("rank_down")
		"cripple":
			flags["crippled"] = true
			if martial:
				realm = maxi(0, realm - 1)
				xp = float(GhD.REALM_XP[realm])
			hp -= 20.0
			_log("몸이 크게 상했다. 예전처럼 움직이지 못했다.", "big")
			_big("몸이 상함")
		"founder":
			flags["founder"] = true
			flags["quit"] = false
			fame += 30
			_log("스스로 문파를 열었다. 제자들이 문 앞에 줄을 섰다.", "big")
			_big("개파조사")
			_moment("gh_m_leader", "개파조사", "제 이름으로 문파를 세웠다.")
		_:
			return false
	return true
