class_name AcD
extends RefCounted

## 아르카나 컬렉션 — 수치 전부(자원 · 성물 · 영웅 · 판 차리기).
##
## 규칙은 스플렌더 본판 그대로입니다. 카드(성물) 하나하나의 비용 · 점수와 영웅 조건은 **새로 짠 것**이고
## 원작 표를 옮기지 않습니다. 뼈대(단계별 장수 · 점수 분포 · 비용 틀의 크기)만 원작과 같습니다:
##   1단계 40장(색마다 0점 7 · 1점 1) · 2단계 30장(1점 2 · 2점 3 · 3점 1) · 3단계 20장(3점 1 · 4점 2 · 5점 1).
## 성물은 [method deck] 가 틀(`PAT`)에 색을 돌려 넣어 만듭니다 — 판마다 같은 90장이고 섞기만 다릅니다.
## **수치를 바꾸면 `tools/arcana_check.gd` 부터 돌리세요**(봇끼리 수천 판 — 판 길이 · 선 플레이어 승률).
##
## **화면 글자에 `·` `—` `×` `→` 를 쓰지 마세요**(Jua 에 없음).

const N_COL := 5          ## 원소 자원 다섯
const GOLD := 5           ## 별가루(만능) — 토큰 배열의 여섯째 칸
const WIN_PTS := 15
const HAND_MAX := 10      ## 들 수 있는 토큰
const RESERVE_MAX := 3    ## 봉인해 둘 수 있는 성물
const TAKE2_MIN := 4      ## 같은 자원 둘을 가져오려면 그 자원이 이만큼 남아 있어야
const GOLD_N := 5
const HERO_PTS := 3

## 인원 → 자원마다 깔 토큰 수
const BANK := {2: 4, 3: 5, 4: 7}

const NAMES := ["화염", "물", "숲", "빛", "그림자", "별가루"]
const GEM := ["화염 결정", "물의 정수", "숲의 씨앗", "빛의 깃털", "그림자 흑요석", "별가루"]
const COL := [Color8(232, 74, 58), Color8(60, 140, 230), Color8(70, 180, 90), Color8(244, 236, 214),
		Color8(150, 86, 205), Color8(250, 200, 70)]
## 그림자는 보라입니다(사용자 요청 11-08). 처음엔 어두운 검보라라 어두운 바탕에 묻혀서 밝은 테를 둘렀는데 "이질적" 이라
## 테를 빼고 색을 밝은 보라로 바꿨습니다 — 테두리는 다른 자원과 같습니다.


## 자원 칸의 테두리 — 모든 자원이 같다(P.INK 와 같은 색 — 검산이 그림 쪽을 안 읽게 직접 적음).
static func edge(_c: int) -> Color:
	return Color8(70, 40, 90)
## 글자를 얹을 때 자원 색 위에서 읽히는 색
const INK_ON := [Color(1, 1, 1), Color(1, 1, 1), Color(1, 1, 1), Color8(70, 40, 90), Color(1, 1, 1), Color8(70, 40, 90)]

const TIER_NAME := ["견습 성물", "장인 성물", "전설 성물"]
const TIER_COL := [Color8(96, 150, 110), Color8(176, 130, 70), Color8(110, 90, 170)]
const ROW_N := 4          ## 단계마다 펼쳐 두는 성물

## 비용 틀 — [점수, [자원 개수...]]. 개수는 "자기 색 다음 자원부터" 차례로 들어간다(`OFF` 로 어느 칸인지).
## 자기 색이 섞이는 틀은 `OWN` 에 그 자리를 적는다.
const PAT := [
	# 1단계 — 색마다 8장
	[[0, [1, 1, 1, 1]], [0, [1, 2, 1, 1]], [0, [2, 2, 1]], [0, [1, 1, 3]], [0, [2, 1]], [0, [2, 2]],
			[0, [3]], [1, [4]]],
	# 2단계 — 색마다 6장
	[[1, [2, 2, 3]], [1, [3, 2, 3]], [2, [1, 4, 2]], [2, [5, 3]], [2, [5]], [3, [6]]],
	# 3단계 — 색마다 4장
	[[3, [3, 3, 5, 3]], [4, [7]], [4, [3, 6, 3]], [5, [7, 3]]],
]
## 틀마다 개수를 넣을 자원 — 자기 색 c 에서 몇 칸 떨어진 자원인지(0 = 자기 색)
const OFF := [
	[[1, 2, 3, 4], [1, 2, 3, 4], [2, 3, 4], [1, 3, 4], [2, 4], [1, 3], [3], [2]],
	[[1, 3, 4], [0, 2, 3], [1, 2, 4], [3, 2], [2], [0]],
	[[1, 2, 3, 4], [4], [0, 4, 1], [4, 0]],
]

## 성물마다 **물건이 다릅니다**(사용자 요청 11-08 — "카드 모양을 다 중복해서 쓰고 있는데 싹 다 다른 모양이었으면").
## 단계마다 물건 묶음이 있고(견습 20 · 장인 15 · 전설 10 = 45종), 색 c 의 k 번째 성물은 묶음의 `(c × 색마다 장수 + k) % 묶음 크기` 번째 —
## 그래서 **같은 색 안에서는 물건이 안 겹치고**, 한 물건은 서로 다른 두 색에 한 번씩만 나옵니다.
## 그림 파일도 카드마다 따로입니다(`art/arcana/ac_r_<색>_<물건>.png`). 물건 그림은 `AcArt.relic_glyph` 가 코드로 그립니다.
## **물건을 더하거나 순서를 바꾸면 모든 성물의 물건 · 이름이 바뀝니다**(비용 · 점수는 그대로).
const GLYPHS := [
	# 견습 — 손에 드는 작은 것
	["ring", "반지"], ["amulet", "부적"], ["candle", "양초"], ["pouch", "주머니"], ["key", "열쇠"],
	["feather", "깃털"], ["flute", "피리"], ["potion", "물약"], ["shell", "조개"], ["bell", "종"],
	["quill", "깃펜"], ["dice", "주사위"], ["acorn", "도토리"], ["mushroom", "버섯"], ["coin", "금화"],
	["compass", "나침반"], ["hourglass", "모래시계"], ["lantern", "등불"], ["dagger", "단검"], ["mask", "가면"],
	# 장인 — 장인이 만든 무구 · 악기 · 책
	["sword", "검"], ["helmet", "투구"], ["banner", "깃발"], ["shield", "방패"], ["harp", "하프"],
	["book", "마법서"], ["staff", "지팡이"], ["armor", "갑옷"], ["mirror", "거울"], ["scroll", "두루마리"],
	["gauntlet", "건틀릿"], ["hammer", "망치"], ["trident", "삼지창"], ["bow", "활"], ["horn", "뿔나팔"],
	# 전설 — 하나뿐인 것
	["heart", "심장"], ["egg", "알"], ["crown", "왕관"], ["throne", "왕좌"], ["orb", "보주"],
	["scepter", "왕홀"], ["chalice", "성배"], ["sundisk", "원반"], ["wing", "날개"], ["eye", "눈"],
]
const GLYPH_POOL := [[0, 20], [20, 15], [35, 10]]   ## 단계 → [GLYPHS 시작, 개수]
const COL_WORD := ["불꽃", "파도", "숲", "빛", "그림자"]
## 성물 이름의 앞말 — 색마다 여덟 가지. 예전에는 90장이 전부 "[색] [물건]"(불꽃 반지 · 파도 반지 …)이라 틀로 찍은 티가 났다
## (docs/ai-look-overhaul.md #35). 같은 색 안에서는 물건이 안 겹치므로 앞말이 겹쳐도 이름은 겹치지 않는다(tools/arcana_check.gd 가 본다).
const NAME_MOD := [
	["불씨", "잿불", "화덕의", "그을린", "달군", "용암", "숯검정", "불꽃"],
	["파도", "밀물", "젖은", "소금", "해무", "썰물의", "깊은 물", "이슬"],
	["이끼", "숲", "덩굴", "떡갈", "고사리", "늙은 나무의", "풀빛", "솔"],
	["새벽", "빛", "한낮의", "흰", "금빛", "첫 햇살", "별", "눈부신"],
	["그림자", "밤", "어스름", "검은", "재", "달 없는", "먹빛", "숨은"],
]

## 영웅 — 성물 보너스만으로 조건을 채우면 찾아온다(늘 3점). 4+4 다섯 · 3+3+3 다섯.
## 조건 자원은 영웅다운 쪽으로 골랐다(마법사는 화염 + 물 …). **새 영웅은 같은 두 형식으로만.**
const HEROES := [
	{"id": "mage", "name": "마법사", "need": {0: 4, 1: 4}},
	{"id": "priest", "name": "성직자", "need": {3: 4, 1: 4}},
	{"id": "archer", "name": "궁수", "need": {2: 4, 3: 4}},
	{"id": "rogue", "name": "도적", "need": {4: 4, 2: 4}},
	{"id": "warlock", "name": "흑마법사", "need": {4: 4, 0: 4}},
	{"id": "paladin", "name": "성기사", "need": {3: 3, 0: 3, 4: 3}},
	{"id": "druid", "name": "드루이드", "need": {2: 3, 1: 3, 3: 3}},
	{"id": "knight", "name": "기사", "need": {0: 3, 3: 3, 2: 3}},
	{"id": "bard", "name": "음유시인", "need": {1: 3, 4: 3, 3: 3}},
	{"id": "hunter", "name": "사냥꾼", "need": {2: 3, 4: 3, 0: 3}},
]

const PLAYER_NAMES := ["나", "리엔", "카스", "모르간"]
const PLAYER_COL := [Color8(255, 210, 90), Color8(120, 200, 255), Color8(255, 130, 150), Color8(150, 230, 140)]


## 이름 뒤 조사 — 받침을 보고 을/를 · 이/가 · 은/는 · 과/와 를 고른다("성배를" · "용의 심장을").
static func josa(s: String, j: String) -> String:
	var has := false
	if not s.is_empty():
		var c := s.unicode_at(s.length() - 1)
		if c >= 0xAC00 and c <= 0xD7A3:
			has = (c - 0xAC00) % 28 != 0
	var pick := {"을": ["을", "를"], "이": ["이", "가"], "은": ["은", "는"], "과": ["과", "와"]}
	var p: Array = pick.get(j, [j, j])
	return s + String(p[0] if has else p[1])


## 성물 90장. {id, tier, col, pts, cost: [5]int, glyph, name, art}
static func deck() -> Array:
	var out := []
	var id := 0
	for tier in 3:
		var pats: Array = PAT[tier]
		var offs: Array = OFF[tier]
		var pool: Array = GLYPH_POOL[tier]
		for c in N_COL:
			for k in pats.size():
				var cost := [0, 0, 0, 0, 0]
				var nums: Array = pats[k][1]
				var off: Array = offs[k]
				for j in nums.size():
					cost[(c + int(off[j])) % N_COL] += int(nums[j])
				var gi := int(pool[0]) + (c * pats.size() + k) % int(pool[1])
				var gl: Array = GLYPHS[gi]
				var mods: Array = NAME_MOD[c]
				var nm := "%s %s" % [mods[(k * 3 + tier * 5) % mods.size()], gl[1]]
				out.append({id = id, tier = tier, col = c, pts = int(pats[k][0]), cost = cost,
						glyph = String(gl[0]), name = nm, art = "ac_r_%d_%s" % [c, gl[0]]})
				id += 1
	return out
