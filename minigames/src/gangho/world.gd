class_name GhWorld
extends RefCounted

## 천하의 일 — 같은 해에 태어난 다섯(나 + 동년배 넷)이 **같은 세상**을 산다.
## 기근이 들면 다섯 집에 다 들고, 정마대전이 나면 무림인 다섯이 다 그 전쟁을 지난다.
## 그래서 "같은 해 태어나 다른 삶" 이 읽힌다 — 세상은 같고 갈린 것은 태어난 자리뿐이다.
##
## 씨앗 하나로 130년치를 미리 정해 둔다. 해마다 굴리면 다섯이 다른 세상을 겪는다.

const SPAN := 130

var start := 0
var years := {}    ## 해 → [종류, ...]
var war_side := "" ## 정마대전에서 이긴 쪽(끝날 때 정한다)


func _init(birth_year: int, seed_: int) -> void:
	start = birth_year
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var last_war := -100
	var last_rebel := -100
	var y := birth_year
	while y < birth_year + SPAN:
		var ks: Array = []
		if y % 8 == 0:
			ks.append("tourney")
		if y - last_war > 22 and rng.randf() < 0.02:
			for k in 3:
				_add(y + k, "war" if k > 0 else "war_start")
			_add(y + 3, "war_end")
			last_war = y
		elif y - last_rebel > 15 and rng.randf() < 0.012:
			_add(y, "rebel")
			_add(y + 1, "rebel")
			last_rebel = y
		var r := rng.randf()
		if r < 0.025:
			ks.append("famine")
		elif r < 0.045:
			ks.append("plague")
		elif r < 0.13:
			ks.append("harvest")
		if rng.randf() < 0.025:
			ks.append("emperor")
		if rng.randf() < 0.008:
			ks.append("comet")
		# 시대를 가르는 일들 — 무림맹 결성 · 마교 분열 · 이민족 침입 · 왜구
		if rng.randf() < 0.012:
			ks.append("alliance")
		if rng.randf() < 0.01:
			ks.append("cult_split")
		if rng.randf() < 0.015:
			_add(y, "invasion")
			_add(y + 1, "invasion")
		if rng.randf() < 0.02:
			ks.append("pirates")
		for k in ks:
			_add(y, k)
		y += 1


func _add(y: int, k: String) -> void:
	if not years.has(y):
		years[y] = []
	if not (years[y] as Array).has(k):
		years[y].append(k)


func at(y: int) -> Array:
	return years.get(y, [])


func has(y: int, k: String) -> bool:
	return at(y).has(k)


## 세상 소식 한 줄 — 연대기에 "천하" 로 찍힌다.
static func headline(k: String) -> String:
	match k:
		"war_start":
			return "천마신교가 중원으로 내려왔다. 정마대전이 시작되었다."
		"war_end":
			return "정마대전이 끝났다. 강호에 무덤이 늘었다."
		"rebel":
			return "곳곳에서 난리가 일어나 관군과 반군이 싸운다."
		"famine":
			return "큰 흉년이 들었다. 초근목피로 버티는 집이 많다."
		"plague":
			return "돌림병이 천하를 휩쓸었다."
		"harvest":
			return "드물게 풍년이 들었다."
		"tourney":
			return "무림 비무대회가 열렸다."
		"emperor":
			return "새 황제가 즉위했다."
		"comet":
			return "밤하늘에 꼬리별이 떴다. 사람들이 수군거린다."
		"alliance":
			return "정파 문파들이 무림맹을 세우고 맹주를 뽑았다."
		"cult_split":
			return "천마신교가 둘로 갈라져 피를 흘렸다."
		"invasion":
			return "북방 이민족이 장성을 넘어 쳐들어왔다."
		"pirates":
			return "바닷가 고을에 해적 떼가 출몰했다."
	return ""


## 시대의 기운 — 그 해를 가운데 둔 20년 동안의 난리(전쟁 · 반란 · 침입 · 기근 · 역병) 수로 가른다.
## 난세면 위험 · 무공에 닿을 일이 잦고, 태평성대면 장사 · 글의 길이 넓다(GhLife.mul 이 곱한다).
var _era := {}


func era(y: int) -> String:
	if _era.has(y):
		return _era[y]
	var n := 0
	for k in range(y - 10, y + 10):
		for e in at(k):
			if e in ["war", "war_start", "rebel", "invasion", "famine", "plague"]:
				n += 1
	var e2 := "난세" if n >= 9 else ("태평성대" if n <= 3 else "")
	_era[y] = e2
	return e2


const ERA_MUL := {"난세": {"danger": 1.3, "entry": 1.3, "trade": 0.8}, "태평성대": {"trade": 1.3, "civil": 1.2, "danger": 0.8}}
