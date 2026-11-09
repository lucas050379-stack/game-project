class_name RsD
extends RefCounted

## 붉은 별 개척단 — 수치 전부(자원 · 지표 · 지도 · 기업 · 사업 카드 · 목표 · 후원).
##
## 규칙은 행성 개조 엔진 빌딩 장르의 규칙 그대로이고, **기업 · 카드 · 지도 · 목표 · 후원 · 수치는 새로 짠 것**입니다
## (사용자 결정 11-09 — 아르카나 · 제국 연대기와 같은 선). 기획서: `docs/design/redstar.md`.
## **수치를 바꾸면 `tools/redstar_check.gd` 부터 돌리세요**(봇끼리 수천 판).
## **화면 글자에 `·` `—` `×` `→` 를 쓰지 마세요**(Jua 에 없음).

## 자원 — 0 크레딧 · 1 금속 · 2 합금 · 3 식물 · 4 전력 · 5 열
const N_RES := 6
const RES_NAME := ["크레딧", "금속", "합금", "식물", "전력", "열"]
const RES_COL := [Color8(240, 200, 80), Color8(170, 120, 80), Color8(170, 180, 200), Color8(110, 190, 90),
		Color8(160, 110, 230), Color8(240, 110, 60)]
const METAL_VAL := 2          ## 건물 태그 비용에 금속 1개 = 크레딧
const ALLOY_VAL := 3          ## 우주 태그 비용에 합금 1개 = 크레딧
const GREEN_COST := 7         ## 식물로 녹지
const HEAT_COST := 7          ## 열로 온도 1단계
const PROD_MIN := -5          ## 크레딧 생산 하한
const START_TR := 15
const CARD_BUY := 3
const RESEARCH_N := 4
const START_HAND := 8
const MAX_GEN := 14

## 지표 — 온도 · 대기 · 바다
const PARAM_NAME := ["온도", "대기", "바다"]
const PARAM_MAX := [8, 8, 6]
const PARAM_COL := [Color8(240, 110, 60), Color8(120, 200, 240), Color8(60, 120, 220)]

## 태그 — 0 건물 · 1 우주 · 2 과학 · 3 식물 · 4 생물 · 5 전력 · 6 도시 · 7 사건
const N_TAG := 8
const TAG_NAME := ["건물", "우주", "과학", "식물", "생물", "전력", "도시", "사건"]
const TAG_COL := [Color8(150, 110, 70), Color8(40, 40, 70), Color8(230, 230, 240), Color8(90, 170, 80),
		Color8(60, 140, 120), Color8(150, 100, 220), Color8(120, 130, 150), Color8(200, 70, 60)]

const KIND_NAME := ["건설", "운영", "사건"]
const KIND_COL := [Color8(90, 150, 90), Color8(70, 120, 190), Color8(190, 70, 60)]

const PLAYER_NAMES := ["나", "상대"]
const PLAYER_COL := [Color8(90, 170, 255), Color8(240, 110, 90)]
const AI_LEVEL_NAME := ["쉬움", "보통", "어려움"]

# ==================== 지도 ====================
## 반지름 3 육각형(축 좌표 q, r) 37칸. 칸 종류: 0 평원 · 1 바다 자리 · 2 고원 · 3 분화구 · 4 빈 땅
const MAP_R := 3
const OCEAN_SPOTS := [[-3, 1], [-3, 2], [-3, 3], [-2, 3], [-2, 2], [-1, 3], [0, 0], [1, -1], [0, -1]]
const HIGHLAND := [[1, -3], [0, -3], [-1, -2], [2, -2], [3, 0], [2, 1], [1, 2], [0, 2]]
const VOLCANO := [[3, -3], [3, -2], [2, -3], [3, -1]]
const BARREN := [[-1, -1], [1, 1]]
const CELL_NAME := ["평원", "바다 자리", "고원", "분화구", "빈 땅"]


static func cells() -> Array:
	var out := []
	for q in range(-MAP_R, MAP_R + 1):
		for r in range(-MAP_R, MAP_R + 1):
			if absi(q + r) <= MAP_R:
				out.append(Vector2i(q, r))
	return out


static func _in(list: Array, c: Vector2i) -> bool:
	for v in list:
		if int(v[0]) == c.x and int(v[1]) == c.y:
			return true
	return false


static func cell_kind(c: Vector2i) -> int:
	if _in(OCEAN_SPOTS, c):
		return 1
	if _in(HIGHLAND, c):
		return 2
	if _in(VOLCANO, c):
		return 3
	if _in(BARREN, c):
		return 4
	return 0


## 칸 보너스 {자원: 개수} · "card": 장수. 자리마다 고정(판마다 같음).
static func cell_bonus(c: Vector2i) -> Dictionary:
	var k := cell_kind(c)
	var h := absi(c.x * 7 + c.y * 13)
	match k:
		1:
			return {card = 1} if h % 2 == 0 else {3: 1}
		2:
			return {1: 2} if h % 3 == 0 else {1: 1}
		3:
			return {2: 1}
		0:
			return {3: 2} if h % 3 == 0 else {3: 1}
	return {}


static func neighbors(c: Vector2i) -> Array:
	var out := []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		var n: Vector2i = c + d
		if absi(n.x) <= MAP_R and absi(n.y) <= MAP_R and absi(n.x + n.y) <= MAP_R:
			out.append(n)
	return out

# ==================== 기업 ====================
## [이름, 시작 크레딧, 시작 생산 {자원: n}, 시작 자원 {자원: n}, 능력 키, 능력 설명]
const CORPS := [
	["홍암 광업", 36, {1: 2}, {}, "metal3", "금속 1개가 크레딧 3으로 계산됨"],
	["녹색 방주단", 38, {3: 1}, {}, "green6", "식물 6개로 녹지"],
	["궁형 항공", 42, {}, {2: 4}, "space2", "우주 태그를 낼 때마다 크레딧 2"],
	["심도 연구소", 35, {}, {}, "sci_draw", "시작 카드 2장 더, 과학 태그를 낼 때마다 카드 1장"],
	["열류 에너지", 38, {4: 2}, {}, "heat6", "열 6개로 온도 1단계"],
	["구립 도시 연합", 46, {0: 2}, {}, "city_prod", "도시를 놓을 때마다 크레딧 생산 1 더"],
]

# ==================== 카드 ====================
## [이름, 종류(0 건설 · 1 운영 · 2 사건), 비용, 태그, 조건, 효과, 점수]
## 조건 키: tmin · tmax(온도) · omin · omax(대기) · wmin(바다 수)
## 효과 키: prod {자원: n} · gain {자원: n} · temp · oxy · ocean · tr · tile("green" · "city") · draw · opp {자원: n}(상대가 잃음)
##   disc {"all" 또는 태그 번호: n}(지속 할인) · on_tag [태그, 자원, n](그 태그를 낼 때마다) ·
##   act {pay {자원: n}, get {자원: n}, temp, oxy, draw, acc}(세대마다 한 번) · acc_pts(쌓인 것 몇 개당 1점)
const CARDS := [
	# ---------- 건설 40 ----------
	["모래 제련소", 0, 11, [0], {}, {prod = {1: 1, 0: 1}}, 0],
	["동굴 온실", 0, 14, [3, 0], {tmin = 3}, {prod = {3: 2}}, 0],
	["궤도 거울", 0, 17, [1, 5], {}, {prod = {4: 2}}, 1],
	["극지 얼음 절단", 0, 16, [1], {}, {ocean = 1}, 0],
	["지하 도시", 0, 20, [6, 0], {}, {tile = "city", prod = {0: 2}}, 0],
	["이끼 배양조", 0, 6, [3], {omin = 2}, {prod = {3: 1}}, 0],
	["구름 파종기", 0, 12, [2], {wmin = 2}, {oxy = 1}, 0],
	["철광 채굴장", 0, 13, [0], {}, {prod = {1: 2}}, 0],
	["합금 정련소", 0, 16, [0, 2], {}, {prod = {2: 1}, gain = {2: 2}}, 0],
	["풍력 발전 단지", 0, 9, [5, 0], {omin = 3}, {prod = {4: 1}}, 1],
	["지열 굴착기", 0, 12, [0, 5], {}, {prod = {5: 2}}, 0],
	["대형 태양판", 0, 14, [5], {}, {prod = {4: 2}}, 0],
	["이주민 정착지", 0, 18, [6], {}, {tile = "city", prod = {0: 1}}, 0],
	["고원 마을", 0, 15, [6, 0], {omin = 4}, {tile = "city"}, 0],
	["해조 양식장", 0, 10, [3], {wmin = 3}, {prod = {3: 1}, gain = {3: 2}}, 0],
	["나무 심기 사업", 0, 14, [3], {tmin = 5}, {tile = "green"}, 0],
	["수경 농장", 0, 12, [3, 0], {}, {prod = {3: 1}}, 1],
	["우주 정거장 확장", 0, 20, [1], {}, {prod = {2: 2}}, 1],
	["소행성 채굴 기지", 0, 22, [1], {}, {prod = {2: 2, 1: 1}}, 0],
	["대기 압축기", 0, 18, [0, 2], {}, {oxy = 1, prod = {0: -1}}, 0],
	["온실가스 공장", 0, 11, [0], {}, {prod = {5: 1, 0: 1}}, 0],
	["연구 단지", 0, 15, [2, 0], {}, {draw = 2}, 1],
	["생물 연구소", 0, 13, [2, 4], {omin = 3}, {draw = 1}, 2],
	["해안 도시", 0, 23, [6], {wmin = 4}, {tile = "city", prod = {0: 2}}, 0],
	["전력망", 0, 10, [5, 0], {}, {prod = {0: 2}}, 0],
	["금속 재활용", 0, 8, [0], {}, {prod = {1: 1}}, 0],
	["궤도 조선소", 0, 25, [1, 0], {}, {prod = {2: 2}}, 2],
	["탄소 포집탑", 0, 15, [2, 0], {}, {temp = 1}, 0],
	["화산 발전소", 0, 17, [5, 0], {}, {prod = {4: 2, 5: 1}}, 0],
	["곤충 사육장", 0, 9, [4], {omin = 5}, {}, 2],
	["숲 보호구역", 0, 21, [3], {omin = 6}, {tile = "green", prod = {3: 1}}, 0],
	["위성 통신망", 0, 13, [1, 2], {}, {prod = {0: 2}}, 0],
	["극지 도시", 0, 21, [6, 0], {tmax = 4}, {tile = "city", prod = {0: 1}, gain = {1: 2}}, 0],
	["토양 미생물", 0, 7, [4, 3], {tmin = 2}, {gain = {3: 3}}, 0],
	["수력 발전소", 0, 15, [5, 0], {wmin = 3}, {prod = {4: 2}}, 0],
	["열 교환기", 0, 10, [0], {}, {prod = {5: 2}}, 0],
	["거대 돔", 0, 28, [6, 0, 2], {}, {tile = "city", prod = {0: 3}}, 1],
	["꽃 정원", 0, 16, [3], {tmin = 7}, {prod = {3: 2}}, 1],
	["생태 연구 기지", 0, 19, [2, 3, 4], {omin = 5}, {}, 3],
	["해수 담수화", 0, 14, [0], {wmin = 2}, {prod = {0: 2}}, 0],
	# ---------- 운영 20 ----------
	["토양 박테리아", 1, 9, [4, 2], {}, {act = {acc = 1}, acc_pts = 3}, 0],
	["광물 선별 로봇", 1, 15, [0, 2], {}, {act = {pay = {4: 2}, get = {1: 2}}}, 0],
	["궤도 항만", 1, 21, [1], {}, {disc = {1: 2}}, 1],
	["연구 지원금", 1, 8, [2], {}, {on_tag = [2, 0, 2]}, 0],
	["산소 공장", 1, 18, [0, 2], {}, {act = {pay = {4: 3}, oxy = 1}}, 0],
	["증기 엔진", 1, 12, [5, 0], {}, {act = {pay = {5: 4}, get = {0: 5}}}, 0],
	["비료 공장", 1, 11, [3, 0], {}, {act = {pay = {4: 1}, get = {3: 2}}}, 0],
	["무역 위성", 1, 14, [1], {}, {act = {get = {0: 2}}}, 0],
	["지질 탐사단", 1, 10, [2], {}, {act = {pay = {0: 2}, draw = 1}}, 0],
	["축산 농장", 1, 12, [4], {omin = 4}, {act = {acc = 1}, acc_pts = 2}, 0],
	["건축 조합", 1, 10, [0], {}, {disc = {0: 2}}, 0],
	["궤도 승강기", 1, 27, [1, 0], {}, {act = {pay = {1: 1}, get = {0: 5}}}, 2],
	["과학 학회", 1, 9, [2], {}, {disc = {2: 2}}, 0],
	["생명 공학 회사", 1, 16, [2, 4], {}, {on_tag = [3, 3, 2]}, 1],
	["전력 거래소", 1, 11, [5], {}, {act = {pay = {4: 2}, get = {0: 4}}}, 0],
	["기상 조절국", 1, 20, [2], {}, {act = {pay = {0: 10}, temp = 1}}, 0],
	["대규모 농장", 1, 17, [3, 0], {tmin = 4}, {act = {get = {3: 1}}}, 1],
	["도시 계획청", 1, 14, [6], {}, {on_tag = [6, 0, 3]}, 0],
	["녹색 기금", 1, 13, [3], {}, {disc = {"all": 1}}, 0],
	["곰팡이 배양실", 1, 7, [4], {}, {act = {acc = 1}, acc_pts = 4}, 0],
	# ---------- 사건 20 ----------
	["혜성 끌어오기", 2, 19, [1, 7], {}, {temp = 1, ocean = 1}, 0],
	["대규모 폭파", 2, 10, [0, 7], {}, {gain = {1: 5}, opp = {3: 3}}, 0],
	["긴급 투자", 2, 3, [7], {}, {gain = {0: 8}, prod = {0: -1}}, 0],
	["자기장 방패", 2, 22, [2, 1, 7], {tmin = 6}, {tr = 3}, 0],
	["소행성 충돌", 2, 14, [1, 7], {}, {temp = 1, gain = {2: 2}}, 0],
	["얼음 운석", 2, 23, [1, 7], {}, {ocean = 2}, 0],
	["산림 녹화 운동", 2, 24, [3, 7], {}, {tile = "green", gain = {3: 2}}, 0],
	["화산 분화 유도", 2, 12, [7], {}, {temp = 1, opp = {5: 4}}, 0],
	["투자 유치", 2, 5, [7], {}, {gain = {0: 6}}, 0],
	["기술 공유", 2, 7, [2, 7], {}, {draw = 2}, 0],
	["대기 방출", 2, 15, [7], {}, {oxy = 1}, 0],
	["이끼 살포", 2, 9, [3, 7], {omin = 3}, {gain = {3: 5}}, 0],
	["정부 보조금", 2, 1, [7], {}, {gain = {0: 3}}, 0],
	["해빙", 2, 16, [7], {tmin = 4}, {ocean = 1}, 0],
	["장비 지원", 2, 6, [0, 7], {}, {gain = {1: 4}}, 0],
	["궤도 낙하 물자", 2, 11, [1, 7], {}, {gain = {2: 3, 0: 2}}, 0],
	["사보타주", 2, 6, [7], {}, {opp = {1: 3, 2: 2}}, 0],
	["연구 돌파구", 2, 12, [2, 7], {}, {draw = 3}, 0],
	["태양 폭풍", 2, 8, [1, 7], {}, {opp = {3: 4}, gain = {5: 3}}, 0],
	["개척 기념 행사", 2, 9, [7], {omin = 5}, {tr = 1}, 0],
]

## 기본 사업: [이름, 비용, 효과]
const STD := [
	["카드 팔기", 0, {}],
	["발전소", 10, {prod = {4: 1}}],
	["운석 유도", 12, {temp = 1}],
	["공기 정화기", 17, {oxy = 1}],
	["얼음 유입", 14, {ocean = 1}],
	["녹지 조성", 22, {tile = "green"}],
	["도시 건설", 24, {tile = "city", prod = {0: 1}}],
]

## 목표: [이름, 조건 설명, 종류, 값] — 먼저 채운 쪽이 8 내고 선점(5점). 한 사람 두 개까지.
const MILESTONES := [
	["개척자", "개척 등급 25", "tr", 25],
	["정원사", "녹지 3개", "green", 3],
	["건축가", "건물 태그 6개", "tag0", 6],
]
## 후원: [이름, 기준 설명, 종류] — 첫 개설 8, 두 번째 14. 게임 끝 1위 5점, 2위 2점.
const AWARDS := [
	["지주", "가장 많은 타일", "tiles"],
	["발명가", "가장 많은 과학 태그", "tag2"],
	["화부", "가장 많은 열 보유", "heat"],
]
const MILESTONE_COST := 8
const AWARD_COST := [8, 14]


static func card(k: int) -> Dictionary:
	var row: Array = CARDS[k]
	return {id = k, name = String(row[0]), kind = int(row[1]), cost = int(row[2]), tags = row[3], req = row[4],
			eff = row[5], pts = int(row[6])}


static func all_cards() -> Array:
	var out := []
	for k in CARDS.size():
		out.append(card(k))
	return out


static func req_text(req: Dictionary) -> String:
	var s := []
	if req.has("tmin"):
		s.append("온도 %d 이상" % int(req.tmin))
	if req.has("tmax"):
		s.append("온도 %d 이하" % int(req.tmax))
	if req.has("omin"):
		s.append("대기 %d 이상" % int(req.omin))
	if req.has("omax"):
		s.append("대기 %d 이하" % int(req.omax))
	if req.has("wmin"):
		s.append("바다 %d 이상" % int(req.wmin))
	return ", ".join(s)


static func _res_list(d: Dictionary, sign_s: String = "") -> String:
	var s := []
	for r in d:
		var v := int(d[r])
		s.append("%s %s%d" % [RES_NAME[int(r)], "+" if v > 0 and sign_s == "+" else "", v])
	return ", ".join(s)


static func eff_text(e: Dictionary, pts: int = 0) -> String:
	var s := []
	if e.has("prod"):
		s.append("생산 " + _res_list(e.prod, "+"))
	if e.has("gain"):
		s.append("얻음 " + _res_list(e.gain))
	if e.has("temp"):
		s.append("온도 +%d" % int(e.temp))
	if e.has("oxy"):
		s.append("대기 +%d" % int(e.oxy))
	if e.has("ocean"):
		s.append("바다 %d개" % int(e.ocean))
	if e.has("tr"):
		s.append("개척 등급 +%d" % int(e.tr))
	if e.has("tile"):
		s.append("녹지 놓기" if e.tile == "green" else "도시 놓기")
	if e.has("draw"):
		s.append("카드 %d장" % int(e.draw))
	if e.has("opp"):
		s.append("상대 " + _res_list(e.opp) + " 잃음")
	if e.has("disc"):
		for k in e.disc:
			s.append("%s 카드 비용 -%d" % ["모든" if str(k) == "all" else TAG_NAME[int(k)], int(e.disc[k])])
	if e.has("on_tag"):
		s.append("%s 태그를 낼 때마다 %s %d" % [TAG_NAME[int(e.on_tag[0])], RES_NAME[int(e.on_tag[1])], int(e.on_tag[2])])
	if e.has("act"):
		var a: Dictionary = e.act
		var parts := []
		if a.has("pay"):
			parts.append(_res_list(a.pay) + " 내고")
		if a.has("get"):
			parts.append(_res_list(a["get"]) + " 얻음")   # a.get 은 사전의 메서드라 키로 못 씀
		if a.has("temp"):
			parts.append("온도 +1")
		if a.has("oxy"):
			parts.append("대기 +1")
		if a.has("draw"):
			parts.append("카드 %d장" % int(a.draw))
		if a.has("acc"):
			parts.append("이 카드에 1개 쌓기")
		s.append("행동(세대마다): " + " ".join(parts))
	if e.has("acc_pts"):
		s.append("쌓인 것 %d개마다 1점" % int(e.acc_pts))
	if pts > 0:
		s.append("%d점" % pts)
	return ", ".join(s)
