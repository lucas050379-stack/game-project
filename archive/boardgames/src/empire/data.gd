class_name EmD
extends RefCounted

## 제국 연대기 — 수치 전부(자원 · 카드 · 불가사의 · 발전 토큰 · 배치 모양).
##
## 규칙은 1대1 문명 카드 드래프트 장르의 규칙 그대로이고, **카드 하나하나 · 불가사의 효과 · 발전 토큰은 새로 짠 것**입니다
## (사용자 결정 11-09 — 아르카나와 같은 선: 규칙 · 뼈대만 같고 원작 카드 표를 옮기지 않음). 뼈대(시대별 장수 · 색별 장수 ·
## 배치 모양 · 과학 심볼 수 · 군사 트랙 길이)만 장르와 같습니다. 기획서: `docs/design/empire.md`.
## **수치를 바꾸면 `tools/empire_check.gd` 부터 돌리세요**(봇끼리 수천 판 — 승리 경로 비율 · 선 승률 · 카드별 승률).
##
## **화면 글자에 `·` `—` `×` `→` 를 쓰지 마세요**(Jua 에 없음).

## 자원 — 0 나무 · 1 점토 · 2 돌(원자재, 갈색) · 3 유리 · 4 양피지(가공품, 회색)
const N_RES := 5
const RAW := [0, 1, 2]
const MAN := [3, 4]
const RES_NAME := ["나무", "점토", "돌", "유리", "양피지"]
const RES_COL := [Color8(150, 98, 52), Color8(206, 110, 70), Color8(150, 150, 160), Color8(110, 200, 230), Color8(232, 214, 160)]

## 카드 색
enum K { BROWN, GREY, BLUE, GREEN, RED, YELLOW, PURPLE }
const KIND_NAME := ["원자재", "가공품", "문화", "과학", "군사", "상업", "길드"]
const KIND_COL := [Color8(140, 92, 50), Color8(130, 134, 146), Color8(70, 120, 210), Color8(70, 160, 90),
		Color8(200, 60, 56), Color8(226, 180, 50), Color8(130, 80, 170)]

## 과학 심볼 — 0~5 는 초록 카드에 2장씩, 6 철학은 발전 토큰에만
const SCI_NAME := ["문자", "바퀴", "의술", "천문", "연금", "기하", "철학"]
const SCI_WIN := 6            ## 서로 다른 심볼 이만큼이면 과학 승리

const START_COIN := 7
const MIL_WIN := 9            ## 군사 말이 이만큼 넘어가면 승리
const MIL_LOSS := [[3, 2], [6, 5]]   ## [칸, 상대가 잃는 돈] — 처음 넘을 때 한 번씩
const DISCARD_BASE := 2       ## 버리기 수익 = 이것 + 내 노란 카드 수 (+ 효과)
const WONDER_MAX := 7         ## 둘이 합쳐 지을 수 있는 불가사의
const AGE_N := 3

const PLAYER_NAMES := ["나", "상대"]
const PLAYER_COL := [Color8(90, 170, 255), Color8(240, 110, 90)]
const AI_LEVEL_NAME := ["쉬움", "보통", "어려움"]


## 군사 점수 — 말이 상대 쪽으로 넘어간 칸 수(0~8)에 따라.
static func mil_points(d: int) -> int:
	if d >= 6:
		return 5
	if d >= 3:
		return 2
	return 0


## 배치 모양 — 시대마다 줄(위가 먼 줄) [x 목록, 앞면인가]. x 는 반 카드 단위. 줄 r 의 카드는 줄 r+1 의 x±1 카드에 덮인다.
const LAYOUT := [
	[[[-1, 1], true], [[-2, 0, 2], false], [[-3, -1, 1, 3], true], [[-4, -2, 0, 2, 4], false], [[-5, -3, -1, 1, 3, 5], true]],
	[[[-5, -3, -1, 1, 3, 5], true], [[-4, -2, 0, 2, 4], false], [[-3, -1, 1, 3], true], [[-2, 0, 2], false], [[-1, 1], true]],
	[[[-1, 1], true], [[-2, 0, 2], false], [[-3, -1, 1, 3], true], [[-2, 2], false], [[-3, -1, 1, 3], true],
			[[-2, 0, 2], false], [[-1, 1], true]],
]

## 카드 한 장: [이름, 색, 돈, 자원 비용 {자원: 개수}, 효과 {…}, 앞 카드(연계로 공짜가 되는 조건) 이름]
## 효과 키: prod [자원별 생산] · pick [고를 수 있는 자원들](매 턴 하나) · pts · mil · sci(심볼) · coin(즉시)
##   fix {자원: 값}(구매가 고정) · disc(버리기 수익 +) · coin_age3(3시대 시작에 돈) · per_brown(내 갈색 카드당 돈)
##   per_red_pts(게임 끝 내 빨간 카드당 점수) · opp_yellow(상대 노란 카드당 돈) · buy_minus(모든 자원 구매가 -) · guild(길드 점수 종류)
const AGE1 := [
	["벌목장", K.BROWN, 0, {}, {prod = [1, 0, 0, 0, 0]}, ""],
	["나무꾼 야영지", K.BROWN, 1, {}, {prod = [1, 0, 0, 0, 0]}, ""],
	["점토 구덩이", K.BROWN, 0, {}, {prod = [0, 1, 0, 0, 0]}, ""],
	["진흙 채취장", K.BROWN, 1, {}, {prod = [0, 1, 0, 0, 0]}, ""],
	["채석장", K.BROWN, 0, {}, {prod = [0, 0, 1, 0, 0]}, ""],
	["돌 깎는 터", K.BROWN, 1, {}, {prod = [0, 0, 1, 0, 0]}, ""],
	["유리 공방", K.GREY, 1, {}, {prod = [0, 0, 0, 1, 0]}, ""],
	["양피지 공방", K.GREY, 1, {}, {prod = [0, 0, 0, 0, 1]}, ""],
	["제단", K.BLUE, 1, {}, {pts = 2}, ""],
	["광장 무대", K.BLUE, 0, {0: 1}, {pts = 3}, ""],
	["공중목욕탕", K.BLUE, 0, {2: 1, 1: 1}, {pts = 4}, ""],
	["서기실", K.GREEN, 0, {4: 1}, {sci = 0}, ""],
	["수레 공방", K.GREEN, 0, {0: 1}, {sci = 1}, ""],
	["약초원", K.GREEN, 0, {1: 1}, {sci = 2, pts = 1}, ""],
	["별 관측대", K.GREEN, 0, {3: 1}, {sci = 3}, ""],
	["망루", K.RED, 0, {}, {mil = 1}, ""],
	["목책", K.RED, 2, {}, {mil = 1}, ""],
	["주둔지", K.RED, 0, {1: 1}, {mil = 1}, ""],
	["마구간", K.RED, 0, {0: 1}, {mil = 1}, ""],
	["주막", K.YELLOW, 0, {}, {coin = 3}, ""],
	["강가 교역소", K.YELLOW, 2, {}, {fix = {0: 2, 1: 2}}, ""],
	["산길 교역소", K.YELLOW, 2, {}, {fix = {2: 2, 3: 2}}, ""],
	["행상인 조합", K.YELLOW, 1, {}, {disc = 1}, ""],
]

const AGE2 := [
	["제재소", K.BROWN, 2, {}, {prod = [2, 0, 0, 0, 0]}, ""],
	["벽돌 가마", K.BROWN, 2, {}, {prod = [0, 2, 0, 0, 0]}, ""],
	["대채석장", K.BROWN, 2, {}, {prod = [0, 0, 2, 0, 0]}, ""],
	["유리 가마", K.GREY, 1, {}, {prod = [0, 0, 0, 1, 0]}, ""],
	["건조실", K.GREY, 1, {}, {prod = [0, 0, 0, 0, 1]}, ""],
	["법정", K.BLUE, 0, {0: 2, 3: 1}, {pts = 5}, ""],
	["신전", K.BLUE, 0, {0: 1, 4: 1}, {pts = 4}, "제단"],
	["조각상", K.BLUE, 0, {1: 2}, {pts = 4}, "광장 무대"],
	["수로", K.BLUE, 0, {2: 3}, {pts = 5}, "공중목욕탕"],
	["연단", K.BLUE, 0, {2: 1, 0: 1}, {pts = 3}, ""],
	["도서관", K.GREEN, 0, {2: 1, 0: 1, 3: 1}, {sci = 0, pts = 2}, "서기실"],
	["학교", K.GREEN, 0, {0: 1, 4: 2}, {sci = 1, pts = 1}, "수레 공방"],
	["약제실", K.GREEN, 0, {1: 2, 2: 1}, {sci = 2, pts = 2}, "약초원"],
	["실험실", K.GREEN, 0, {0: 1, 3: 2}, {sci = 4, pts = 1}, ""],
	["막사", K.RED, 3, {}, {mil = 2}, "주둔지"],
	["궁술장", K.RED, 0, {2: 1, 0: 1, 4: 1}, {mil = 2}, ""],
	["기마 훈련장", K.RED, 0, {1: 1, 0: 1}, {mil = 1}, "마구간"],
	["성벽", K.RED, 0, {2: 2}, {mil = 2}, "목책"],
	["연병장", K.RED, 0, {1: 2, 3: 1}, {mil = 2}, ""],
	["시장 광장", K.YELLOW, 2, {0: 1}, {pick = [3, 4], pts = 1}, ""],
	["대상 숙소", K.YELLOW, 0, {1: 1, 3: 1}, {pick = [0, 1, 2]}, ""],
	["조폐소", K.YELLOW, 2, {}, {coin = 2, disc = 1}, ""],
	["곡물 창고", K.YELLOW, 0, {}, {coin = 4, coin_age3 = 2}, ""],
]

const AGE3 := [
	["판테온", K.BLUE, 0, {1: 1, 0: 1, 4: 2}, {pts = 5}, "신전"],
	["정원", K.BLUE, 0, {1: 2, 0: 2}, {pts = 6}, "조각상"],
	["시청", K.BLUE, 0, {2: 3, 0: 2}, {pts = 6}, ""],
	["궁전", K.BLUE, 0, {1: 1, 2: 1, 0: 1, 3: 2}, {pts = 7}, ""],
	["원로원", K.BLUE, 0, {1: 2, 2: 1, 4: 1}, {pts = 5}, "연단"],
	["오벨리스크", K.BLUE, 0, {2: 2, 3: 1}, {pts = 5}, ""],
	["아카데미", K.GREEN, 0, {2: 1, 0: 1, 3: 2}, {sci = 4, pts = 3}, "실험실"],
	["대학", K.GREEN, 0, {1: 1, 3: 1, 4: 1}, {sci = 5, pts = 2}, "학교"],
	["천문대", K.GREEN, 0, {2: 1, 4: 2}, {sci = 3, pts = 2}, "별 관측대"],
	["측량소", K.GREEN, 0, {0: 2, 3: 1, 4: 1}, {sci = 5, pts = 3}, ""],
	["무기고", K.RED, 0, {1: 3, 0: 2}, {mil = 3}, ""],
	["공성 공방", K.RED, 0, {0: 3, 3: 1}, {mil = 2}, "궁술장"],
	["원형 경기장", K.RED, 0, {1: 2, 2: 2}, {mil = 2}, "연병장"],
	["요새", K.RED, 0, {2: 2, 1: 1, 4: 1}, {mil = 2}, "성벽"],
	["군사 학교", K.RED, 0, {0: 1, 2: 1, 3: 1, 4: 1}, {mil = 2, pts = 1}, ""],
	["대항구", K.YELLOW, 0, {0: 1, 3: 1, 4: 1}, {per_brown = 1, pts = 2}, ""],
	["금고", K.YELLOW, 0, {2: 2}, {coin = 6, pts = 2}, ""],
	["개선문", K.YELLOW, 0, {2: 2, 1: 1}, {per_red_pts = 1}, ""],
	["교역 연맹", K.YELLOW, 0, {1: 1, 4: 1}, {opp_yellow = 2, pts = 2}, ""],
	["대시장", K.YELLOW, 0, {0: 2, 3: 1}, {buy_minus = 1, pts = 1}, ""],
]

## 길드 — 게임 끝에 **내 도시만** 센다. 3시대 덱에 7종 중 3장이 섞인다.
const GUILDS := [
	["건축가 협회", K.PURPLE, 0, {2: 2, 1: 2, 3: 1, 4: 1}, {guild = "wonder"}, ""],
	["상인 협회", K.PURPLE, 0, {1: 1, 0: 1, 3: 1, 4: 1}, {guild = "yellow"}, ""],
	["학자 협회", K.PURPLE, 0, {0: 2, 1: 2}, {guild = "green"}, ""],
	["장인 협회", K.PURPLE, 0, {2: 2, 0: 1, 4: 1}, {guild = "craft"}, ""],
	["사제 협회", K.PURPLE, 0, {0: 2, 1: 1, 3: 1, 4: 1}, {guild = "blue"}, ""],
	["장군 협회", K.PURPLE, 0, {2: 2, 1: 1, 4: 1}, {guild = "red"}, ""],
	["은행가 협회", K.PURPLE, 0, {2: 2, 0: 2, 3: 1}, {guild = "coin"}, ""],
]

const GUILD_DESC := {wonder = "내 불가사의 1개당 2점", yellow = "내 상업 카드 1장당 1점, 지을 때 1장당 돈 1",
		green = "내 과학 카드 1장당 1점", craft = "내 원자재 가공품 카드 2장당 1점", blue = "내 문화 카드 1장당 1점",
		red = "내 군사 카드 1장당 1점", coin = "내 돈 3당 1점 더"}

## 불가사의: [이름, 자원 비용, 효과, 역사 이미지]
## 효과 키: pts · mil · coin · opp_coin(상대 돈 -) · again(추가 턴) · blue_waive(문화 카드 비용 자원 1 면제) ·
##   library(버린 더미의 과학 카드 1장 공짜) · raw_minus(원자재 구매가 -) · token(공개된 발전 토큰 하나) · pick(매 턴 자원 하나) · sci
const WONDERS := [
	["피라미드", {2: 3, 1: 1}, {pts = 3, blue_waive = 1}, "거대한 노동력"],
	["알렉산드리아 도서관", {4: 1, 3: 1, 0: 1}, {library = true, pts = 2}, "지식의 집대성"],
	["만리장성", {2: 2, 1: 2, 0: 1}, {mil = 2, pts = 3}, "끝없는 방어선"],
	["콜로세움", {2: 2, 1: 2, 3: 1}, {pts = 4, again = true}, "시민의 열광"],
	["로도스의 거상", {1: 3, 3: 1}, {coin = 6, raw_minus = 1}, "항구와 교역"],
	["공중정원", {0: 2, 1: 1, 3: 1, 4: 1}, {coin = 4, pts = 2, again = true}, "풍요"],
	["스톤헨지", {2: 2, 0: 2}, {token = true}, "고대의 지혜"],
	["테라코타 군대", {1: 3, 2: 1}, {mil = 2, opp_coin = 2}, "대군"],
	["마추픽추", {2: 2, 0: 1, 4: 1}, {pts = 1, pick = [0, 1, 2]}, "산악 도시"],
	["페트라", {2: 1, 1: 2, 3: 1}, {opp_coin = 3, coin = 3, again = true}, "사막 교역 도시"],
	["치첸이트사", {2: 2, 0: 1, 3: 1}, {sci = 3, pts = 2}, "천문 관측"],
	["앙코르와트", {2: 2, 0: 2, 3: 1, 4: 1}, {pts = 7}, "신앙의 중심"],
]

## 발전 토큰: [이름, 효과, 설명]
## 효과 키: coin · coin_age(이후 시대 시작마다 돈) · disc · wonder_waive · no_mil_loss · sci · pair_pts · blue_pts ·
##   wonder_coin · prod · pts · raw_minus
const TOKENS := [
	["관개 농업", {coin = 4, coin_age = 2}, "돈 4, 이후 시대가 시작될 때마다 돈 2"],
	["화폐 주조", {disc = 2}, "버리기 수익 2 더"],
	["공학", {wonder_waive = 2}, "불가사의 비용에서 자원 2개 면제"],
	["방진", {no_mil_loss = true, pts = 2}, "군사로 돈을 잃지 않음, 2점"],
	["철학", {sci = 6}, "과학 심볼 철학 1개"],
	["천문학", {pair_pts = 2}, "게임 끝에 같은 과학 심볼 한 쌍마다 2점"],
	["석공 기술", {blue_pts = 1, pts = 1}, "1점, 이후 문화 카드를 지을 때마다 1점 더"],
	["건축학", {wonder_coin = 3}, "이후 불가사의를 지을 때마다 돈 3"],
	["인쇄술", {prod = [0, 0, 0, 0, 1], pts = 1}, "매 턴 양피지 1 생산, 1점"],
	["항해술", {raw_minus = 1, coin = 1}, "돈 1, 원자재 구매가 1 낮춤(최소 1)"],
]


## 카드 사전 하나로 펼친다.
static func _card(row: Array, age: int, id: int) -> Dictionary:
	var cost := [0, 0, 0, 0, 0]
	for r in row[3]:
		cost[int(r)] = int(row[3][r])
	var eff: Dictionary = row[4]
	return {id = id, name = String(row[0]), kind = int(row[1]), coin = int(row[2]), cost = cost, eff = eff,
			chain = String(row[5]), age = age}


## 시대마다 전체 카드(길드는 3시대에 같이 넣지 않음 — 따로).
static func age_cards(age: int) -> Array:
	var src: Array = [AGE1, AGE2, AGE3][age]
	var out := []
	for k in src.size():
		out.append(_card(src[k], age, age * 100 + k))
	return out


static func guild_cards() -> Array:
	var out := []
	for k in GUILDS.size():
		out.append(_card(GUILDS[k], 2, 300 + k))
	return out


static func all_cards() -> Array:
	return age_cards(0) + age_cards(1) + age_cards(2) + guild_cards()


static func wonder(k: int) -> Dictionary:
	var row: Array = WONDERS[k]
	var cost := [0, 0, 0, 0, 0]
	for r in row[1]:
		cost[int(r)] = int(row[1][r])
	return {id = k, name = String(row[0]), cost = cost, eff = row[2], note = String(row[3])}


static func token(k: int) -> Dictionary:
	var row: Array = TOKENS[k]
	return {id = k, name = String(row[0]), eff = row[1], desc = String(row[2])}


## 카드 효과를 사람이 읽는 글로(도감 · 카드 설명).
static func eff_text(e: Dictionary) -> String:
	var s := []
	if e.has("prod"):
		for r in N_RES:
			if int(e.prod[r]) > 0:
				s.append("%s %d 생산" % [RES_NAME[r], int(e.prod[r])])
	if e.has("pick"):
		var names := []
		for r in e.pick:
			names.append(RES_NAME[int(r)])
		s.append("매 턴 %s 중 하나" % ", ".join(names))
	if e.has("sci"):
		s.append("과학 %s" % SCI_NAME[int(e.sci)])
	if e.has("mil"):
		s.append("군사 %d" % int(e.mil))
	if e.has("coin"):
		s.append("돈 %d" % int(e.coin))
	if e.has("opp_coin"):
		s.append("상대 돈 %d 잃음" % int(e.opp_coin))
	if e.has("fix"):
		var names2 := []
		for r in e.fix:
			names2.append(RES_NAME[int(r)])
		s.append("%s 구매가 %d" % [", ".join(names2), int(e.fix.values()[0])])
	if e.has("disc"):
		s.append("버리기 수익 %d 더" % int(e.disc))
	if e.has("coin_age3"):
		s.append("3시대 시작에 돈 %d" % int(e.coin_age3))
	if e.has("per_brown"):
		s.append("내 원자재 카드당 돈 %d" % int(e.per_brown))
	if e.has("per_red_pts"):
		s.append("끝에 내 군사 카드당 %d점" % int(e.per_red_pts))
	if e.has("opp_yellow"):
		s.append("상대 상업 카드당 돈 %d" % int(e.opp_yellow))
	if e.has("buy_minus"):
		s.append("모든 구매가 %d 낮춤" % int(e.buy_minus))
	if e.has("raw_minus"):
		s.append("원자재 구매가 %d 낮춤" % int(e.raw_minus))
	if e.has("blue_waive"):
		s.append("문화 카드 비용 자원 1 면제")
	if e.has("library"):
		s.append("버린 과학 카드 1장 공짜로 짓기")
	if e.has("token"):
		s.append("발전 토큰 하나")
	if e.has("guild"):
		s.append(String(GUILD_DESC[e.guild]))
	if e.get("again", false):
		s.append("한 번 더")
	if e.has("pts"):
		s.append("%d점" % int(e.pts))
	return ", ".join(s)


static func cost_text(coin: int, cost: Array) -> String:
	var s := []
	if coin > 0:
		s.append("돈 %d" % coin)
	for r in N_RES:
		if int(cost[r]) > 0:
			s.append("%s %d" % [RES_NAME[r], int(cost[r])])
	return "무료" if s.is_empty() else ", ".join(s)
