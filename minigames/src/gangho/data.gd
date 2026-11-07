class_name GhD
extends RefCounted

## 강호일생 — 수치와 표. **인생 계산(GhLife)은 그리기 · 소리 · 저장을 모릅니다** — 헤드리스 검산
## (tools/gangho_check.gd)이 `--script` 로 이 표와 GhLife 만 읽어 수천 번 태어나 봅니다.
##
## 이 게임의 뼈대는 "고를 수 없는 출생" 입니다. **천하 사람 대부분은 무공을 모르고 삽니다** —
## 농가 · 소작이 절반이 넘고, 그들의 일생은 대개 풍년 · 흉년 · 혼인 · 자식으로 흘러갑니다.
## 무림은 그중 일부만 닿는 세계이고, 그래서 닿았을 때 귀합니다. 출생 표를 무림 쪽으로 기울이면
## "누구로 태어나느냐" 가 사라지고 그냥 무협 육성 게임이 됩니다.
##
## **화면 글자에 `·` `—` `×` `→` 와 한자를 쓰지 마세요**(Jua 글꼴에 없어 웹에서 네모로 나옵니다).

## 천하 인구 — 출생 확률을 "약 몇 명 중 하나" 로 보여 줄 때 쓴다.
const POPULATION := 120000000

## 한 해의 길이(초, 배속 1). 다섯 살까지는 절반 — 아기 때는 일이 적다.
## 평균 수명이 50 안팎이라 배속 1 이면 한 인생이 10~15분이다(사용자 결정: 10~20분 + 배속).
const YEAR_SEC := 11.0
const CHILD_K := 0.45
const SPEEDS := [0.5, 1.0, 2.0, 4.0, 8.0]
const CHOICE_AUTO_SEC := 6.0   ## 자동 선택을 켜면 갈림길에서 이만큼 기다렸다 성향대로 고른다

# ==================== 땅 ====================

## 지역: id · 이름 · 인구 비중 · 바다 · 변방
const REGIONS := [
	{id = "hebei", name = "하북", w = 13.0, sea = true},
	{id = "shandong", name = "산동", w = 12.0, sea = true},
	{id = "henan", name = "하남", w = 14.0},
	{id = "shaanxi", name = "섬서", w = 8.0},
	{id = "sichuan", name = "사천", w = 11.0},
	{id = "hubei", name = "호북", w = 10.0},
	{id = "jiangnan", name = "강남", w = 15.0, sea = true},
	{id = "fujian", name = "복건", w = 6.0, sea = true},
	{id = "yunnan", name = "운남", w = 4.0},
	{id = "north", name = "북방 초원", w = 3.0, frontier = true},
	{id = "west", name = "서역", w = 4.0, frontier = true},
]

# ==================== 집안 ====================

## 태어나는 집안. w = 천하 전체에서의 비중(%).
## mart = 무공을 배울 길이 처음부터 열려 있을 확률 · side = 그 길이 열리면 닿는 쪽
## wf = 변방(초원 · 서역)에서의 비중 — 없으면 w 의 0.3배. gold = 처음 집안 재산(냥) · only = 이 지역에서만 · not = 이 지역에는 없음 · hp = 어릴 적 건강 보정
const CLASSES := [
	{id = "farm", name = "농가", w = 38.0, wf = 8.0, mart = 0.0, gold = 20, hp = 0},
	{id = "tenant", name = "소작농", w = 13.0, wf = 3.0, mart = 0.0, gold = 2, hp = -8},
	{id = "fisher", name = "어촌", w = 5.0, mart = 0.0, gold = 10, hp = 0, sea = true},
	{id = "hunter", name = "산골 사냥꾼", w = 3.0, wf = 6.0, mart = 0.12, side = "독학", gold = 8, hp = 4},
	{id = "craft", name = "장인", w = 7.0, mart = 0.0, gold = 40, hp = 0},
	{id = "merchant", name = "상인", w = 7.0, wf = 5.0, mart = 0.0, gold = 150, hp = 2},
	{id = "clerk", name = "아전", w = 3.0, mart = 0.0, gold = 80, hp = 2},
	{id = "scholar", name = "선비 집안", w = 2.0, mart = 0.0, gold = 120, hp = 2},
	{id = "soldier", name = "군호", w = 4.0, wf = 7.0, mart = 0.6, side = "관군", gold = 25, hp = 2},
	{id = "escort", name = "표국", w = 1.4, mart = 0.85, side = "표국", gold = 90, hp = 4, arts = ["표사 권법", "호표술", "표국 도법", "철포삼"]},
	{id = "beggar", name = "거지", w = 3.0, mart = 0.0, gold = 0, hp = -14},
	{id = "bandit", name = "녹림 산채", w = 1.6, mart = 0.7, side = "사", gold = 30, hp = 0, nreg = ["north", "west"]},
	{id = "sectfam", name = "문파 속가", w = 1.5, mart = 0.95, side = "정", gold = 70, hp = 4, nreg = ["north", "west"]},
	{id = "clan", name = "무림세가", w = 0.7, mart = 1.0, side = "세가", gold = 600, hp = 6, only = ["hebei", "jiangnan", "hubei", "sichuan"]},
	{id = "cult", name = "신교 영역", w = 1.2, wf = 14.0, mart = 0.75, side = "마", gold = 30, hp = 0, only = ["west", "sichuan", "yunnan"], arts = ["마령장", "혈천검", "천마파천장", "천마신공", "천마군림보"]},
	{id = "nomad", name = "유목민", w = 2.5, wf = 55.0, mart = 0.3, side = "새외", gold = 40, hp = 2, only = ["north", "west"]},
	# 천마신교의 핵심 혈통 — 서역 본교에서만. 장로가는 세가급, 교주 혈통은 황족보다 드물다(소교주 · 교주 즉위 사건이 있다)
	{id = "cult_elder", name = "신교 장로가", w = 0.04, wf = 1.0, mart = 1.0, side = "마", gold = 800, hp = 4, only = ["west"]},
	{id = "cult_heir", name = "천마 혈통", w = 0.002, wf = 0.07, mart = 1.0, side = "마", gold = 5000, hp = 6, only = ["west"]},
	{id = "noble", name = "고관대작", w = 0.45, mart = 0.0, gold = 3000, hp = 8, nreg = ["north", "west"]},
	{id = "royal", name = "황족", w = 0.03, mart = 0.0, gold = 30000, hp = 10, only = ["henan", "hebei"]},
	{id = "temple", name = "절에 버려진 아이", w = 0.9, mart = 0.6, side = "소림", gold = 0, hp = -4, nreg = ["north", "west"]},
]

# ==================== 문파 ====================

## 문파 · 세력 — 구파일방(정 아홉 + 개방) · 오대세가 · 천마신교 · 새외오궁 · 사파 · 관군 · 표국.
## side = 정 · 사 · 마 · 세가 · 개방 · 새외 · 관군 · 표국 · 독학
## k = 수련 배율 · reg = 본거지(그 지역 사람이 먼저 닿는다) · men/women = 받는 성별
const SECTS := [
	{id = "shaolin", name = "소림사", side = "정", k = 1.3, reg = "henan", women = false, art = "백보신권", arts = ["나한권", "나한진", "백보신권", "반야장", "대력금강장", "금강부동신법", "금강지"]},
	{id = "wudang", name = "무당파", side = "정", k = 1.3, reg = "hubei", art = "태극검", arts = ["무당장권", "면장", "제운종", "태극권", "양의검법", "태극검"]},
	{id = "huashan", name = "화산파", side = "정", k = 1.2, reg = "shaanxi", art = "매화검법", arts = ["육합검법", "매화권", "매화검법", "암향표", "이십사수매화검", "자하신공"]},
	{id = "emei", name = "아미파", side = "정", k = 1.15, reg = "sichuan", men = false, art = "금정검법", arts = ["아미권", "표묘신법", "금정검법", "사자후", "복호장", "아미구양공"]},
	{id = "kunlun", name = "곤륜파", side = "정", k = 1.1, reg = "west", art = "운룡신법", arts = ["곤륜장", "곤륜검법", "운룡신법", "설산비호", "운룡대팔식"]},
	{id = "diancang", name = "점창파", side = "정", k = 1.05, reg = "yunnan", art = "회풍검", arts = ["점창검법", "유운보", "회풍검", "사일검", "분광검"]},
	{id = "qingcheng", name = "청성파", side = "정", k = 1.05, reg = "sichuan", art = "송풍검", arts = ["청성검법", "청성장", "송풍검", "최심장", "청성구검"]},
	{id = "zhongnan", name = "종남파", side = "정", k = 1.1, reg = "shaanxi", art = "천하삼십육검", arts = ["종남검법", "종남장", "천하삼십육검", "북두칠성진", "태을신공"]},
	{id = "kongtong", name = "공동파", side = "정", k = 1.05, reg = "shaanxi", art = "칠상권", arts = ["공동권", "공동검법", "칠상권", "복마장", "복마검"]},
	{id = "beggars", name = "개방", side = "개방", k = 1.1, reg = "hebei", art = "타구봉법", arts = ["연화락", "소요보", "취팔선보", "타구봉법", "항마장", "강룡장"]},
	{id = "namgung", name = "남궁세가", side = "세가", k = 1.25, reg = "jiangnan", art = "창궁검법", arts = ["남궁검법", "남궁보법", "창궁검법", "천뢰신검", "제왕검형"]},
	{id = "moyong", name = "모용세가", side = "세가", k = 1.2, reg = "hebei", art = "두전성이", arts = ["모용검법", "유운장", "참합지", "연환비도", "두전성이"]},
	{id = "jegal", name = "제갈세가", side = "세가", k = 1.0, reg = "hubei", art = "팔괘진법", arts = ["팔괘장", "제갈신산", "팔진도", "칠성보", "기문진법"]},
	{id = "tang", name = "당가", side = "세가", k = 1.15, reg = "sichuan", art = "만천화우", arts = ["당문암기술", "독공", "추혼표", "폭우이화침", "만천화우"]},
	{id = "paeng", name = "팽가", side = "세가", k = 1.15, reg = "hebei", art = "오호단문도", arts = ["팽가도법", "오호권", "혼원벽력도", "광풍도법", "오호단문도"]},
	{id = "haomun", name = "하오문", side = "사", k = 0.8, reg = "jiangnan", art = "그림자 걸음", arts = ["비수술", "그림자 걸음", "소식술", "미혼향", "혈하비수"]},
	{id = "heuksa", name = "흑사방", side = "사", k = 0.85, reg = "shandong", art = "흑살장", arts = ["흑사도법", "흑살장", "흑사편", "흑사독공"]},
	{id = "nokrim", name = "녹림채", side = "사", k = 0.8, reg = "shaanxi", art = "개산부법", arts = ["산적 박투술", "녹림도법", "개산부법", "녹림십팔채진"]},
	{id = "jangang", name = "장강수로채", side = "사", k = 0.8, reg = "hubei", art = "파랑도법", arts = ["분수자", "수중격", "파랑도법", "장강대파도"]},
	{id = "hyeolsa", name = "혈사곡", side = "사", k = 1.0, reg = "yunnan", art = "혈영조", arts = ["혈사검", "혈영조", "혈수인", "혈마공", "혈사대법"]},
	{id = "cult", name = "천마신교", side = "마", k = 1.3, reg = "west", art = "천마군림보"},
	# 새외오궁 — 중원 밖의 다섯 궁. 변방에서 태어나면 여기로 간다
	{id = "binggung", name = "북해빙궁", side = "새외", k = 1.2, reg = "north", art = "빙백신장", arts = ["설화보", "한빙지", "빙백장", "빙궁검법", "빙백신장"]},
	{id = "podalla", name = "포달랍궁", side = "새외", k = 1.2, reg = "west", art = "대수인", arts = ["밀종심법", "금강인", "대수인", "화염도", "용상반야공"]},
	{id = "yasu", name = "남만야수궁", side = "새외", k = 1.1, reg = "yunnan", art = "야수권", arts = ["맹수보", "독충술", "야수권", "만수장", "혈랑조"]},
	{id = "cheonsan", name = "천산설궁", side = "새외", k = 1.15, reg = "west", art = "설화검", arts = ["빙심결", "천산검법", "천산육양장", "천산절매수", "설화검"]},
	{id = "namhae", name = "남해신궁", side = "새외", k = 1.15, reg = "fujian", art = "해일검", arts = ["조수보", "해심공", "해일검", "파도장", "천해검"]},
	{id = "army", name = "관군", side = "관군", k = 0.7, reg = "", art = "군용 창술", arts = ["군용 창술", "기마술", "궁술", "진법", "도독 창법"]},
	{id = "escort", name = "표국", side = "표국", k = 0.75, reg = "", art = "표국 도법"},
]
## 절세 무공 — 문파의 비전. 장문인 · 가주가 되거나, 그 문파에 몸담은 채 기연을 얻거나, 화경에 이르러야 익힌다.
## 익히면 비무에서 한 단 위의 힘을 낸다(GhLife._art_power).
const SECRET := {"shaolin": "역근경", "wudang": "태청강기", "huashan": "자하검강", "emei": "아미금정신공", "kunlun": "곤륜무량검",
		"diancang": "천풍분광검", "qingcheng": "청명신공", "zhongnan": "현천무극공", "kongtong": "칠상무적권", "beggars": "천하제일장",
		"namgung": "제왕무적검", "moyong": "환우성이", "jegal": "천기진해", "tang": "천라지망", "paeng": "광룡십팔도",
		"binggung": "빙백현천공", "podalla": "금강불괴신공", "yasu": "만수귀원공", "cheonsan": "천산설화신공", "namhae": "해천일색",
		"haomun": "무영신법", "hyeolsa": "혈천대법", "cult": "천마해체대법"}
## 문파 없이 혼자 익힌 무공 — 익히는 차례
const SOLO_ARTS := ["삼재검법", "오행권", "육합권", "철포삼"]
## 무림인의 해마다 보수(경지별) — 호위 · 청부 · 문파 녹봉 같은 것을 한 줄로. 무공만 익히고 돈을 못 버는 길이 되면 안 된다
## (사용자 지적 11-07 "무관 루트는 돈벌기가 너무 힘들다"). 쪽마다 배율(MART_PAY_K).
const MART_PAY := [0, 4, 8, 15, 28, 45, 70, 100, 150]
const MART_PAY_K := {"정": 1.0, "세가": 1.5, "사": 1.3, "마": 1.0, "개방": 0.5, "관군": 1.2, "표국": 1.4, "새외": 1.0, "독학": 0.8}
## 문파 없이 혼자 익힌 무공의 배율
const SOLO_K := 0.5

## 집안의 `side` → 처음 들어가는 문파를 고르는 쪽. "정" 이면 정파 문파 중 지역에 가까운 것.
const CLASS_SECT := {"정": "정", "사": "사", "마": "마", "세가": "세가", "관군": "army", "표국": "escort",
		"소림": "shaolin", "독학": ""}

# ==================== 경지 ====================

const REALMS := ["범인", "삼류", "이류", "일류", "절정", "초절정", "화경", "현경", "생사경"]
## 그 경지에 닿는 누적 수련치
const REALM_XP := [0, 6, 20, 48, 100, 190, 300, 440, 700]
## 이 경지에서 다음으로 넘어가려면 **깨달음**(벽)이 필요하다 — 수련치만 쌓아서는 못 넘는다.
## 4 = 절정 → 초절정부터. 해마다 오성으로 깨달을 기회를 굴린다(GhLife._train).
const WALL_FROM := 4
## 경지가 높으면 오래 산다 — 경지마다 사망률에 곱한다.
const REALM_LIFE := [1.0, 1.0, 0.97, 0.92, 0.85, 0.72, 0.55, 0.4, 0.25]

# ==================== 죽음 ====================

## 나이대별 한 해 사망률(%) — 옛 시대 기준. 아기 때가 가장 위험하다.
## 평균 수명이 50 안팎으로 나오게 맞췄다(tools/gangho_check.gd 로 잰다).
static func mortality(age: int) -> float:
	if age < 1:
		return 5.0
	if age < 5:
		return 1.2
	if age < 15:
		return 0.35
	if age < 40:
		return 0.7
	if age < 55:
		return 1.4
	if age < 65:
		return 3.0
	if age < 75:
		return 6.5
	if age < 85:
		return 13.0
	return 24.0

## 자연사 사인 — 나이대로 고른다.
const CAUSE_CHILD := ["돌림병", "열병", "홍역", "익사"]
const CAUSE_ADULT := ["열병", "돌림병", "사고", "폐병", "산짐승", "배앓이"]
const CAUSE_OLD := ["노환", "노환", "노환", "중풍", "폐병", "잠들듯이"]

# ==================== 이름 ====================

const SURNAMES := ["왕", "이", "장", "유", "진", "양", "조", "황", "주", "오", "서", "손", "마", "호", "곽", "하",
		"고", "임", "나", "정", "한", "백", "위", "소", "송", "육", "방", "엽", "단", "용", "석", "연", "남궁", "제갈", "사마", "구양",
		"독고", "상관", "공손", "황보"]
const NAME_M := ["무", "천", "운", "호", "진", "강", "철", "명", "성", "준", "학", "청", "산", "룡", "검", "풍", "석", "영",
		"광", "도", "문", "현", "태", "백", "일", "평", "수", "효", "인", "걸"]
const NAME_F := ["연", "화", "설", "란", "희", "옥", "영", "미", "수", "향", "월", "진", "아", "소", "령", "운", "청", "매",
		"정", "혜", "주", "린", "하", "은", "선"]

# ==================== 시대 ====================

## 천하력 — 태어나는 해. 해마다 세상 일(GhWorld)이 정해지고 같은 해 태어난 다섯이 같이 겪는다.
const YEAR_MIN := 280
const YEAR_MAX := 520

# ==================== 진로를 기울이는 것 ====================
#
# **사건마다 꼬리표(`tag`)가 있고, 할 일 · 물건 · 인연이 그 꼬리표의 배수를 곱한다**(GhLife.mul).
# 원작의 "자전거를 사거나 여행을 가거나 자격증을 공부하면 진로 확률이 바뀌는" 장치다(사용자 요청 11-06).
# 출생은 못 고르지만 그 뒤의 방향은 조금씩 기울일 수 있다 — 다만 **확정은 없다**. 배수가 아무리 커도
# 사건 확률(`pr`)은 0.95 를 못 넘고, 입문 시험 같은 굴림은 그대로 남는다.

## 꼬리표 → 화면 이름(영향 표에 나온다)
const TAGS := {"entry": "무공에 닿을 기회", "civil": "글, 과거의 길", "trade": "장사, 재물의 길", "luck": "기연",
		"meet": "사람을 만날 일", "danger": "위험한 일", "vice": "노름, 유혹", "train": "수련 속도"}

## 방침 — 여섯 중 하나. 바꾸면 그해부터 듣는다. fx 는 해마다 더하는 양(근골 · 오성은 높을수록 덜 오른다).
## 원작의 "건강 우선 · 일 우선 · 학업 집중" 같은 방침이다(사용자 설명 11-07). 무림인의 "무예 단련" 은 수련 속도도 올린다.
const FOCUS := [
	{id = "home", name = "생업 우선", a = [6, 200], desc = "가업에 힘쓴다. 재물이 조금씩 늘고 손재주가 붙는다.", fx = {gold = 4, dex = 1}, mul = {}},
	{id = "rest", name = "건강 우선", a = [0, 200], desc = "건강을 되찾고 위험한 일을 피한다.", fx = {hp = 4}, mul = {danger = 0.6}},
	{id = "study", name = "학업 집중", a = [6, 70], desc = "오성이 오르고 글, 과거의 길이 잘 열린다. 돈이 든다.", fx = {wis = 3, gold = -2},
			mul = {civil = 3.0}},
	{id = "body", name = "무예 단련", a = [6, 120], desc = "근골이 오르고 무공에 닿을 일이 잦아진다. 무림인이면 수련이 빨라진다.",
			fx = {gol = 3, hp = 1}, mul = {entry = 2.5, train = 1.35, danger = 1.15}},
	{id = "trade", name = "장사 우선", a = [12, 80], desc = "재물, 수완이 늘고 장사의 길이 잘 열린다.", fx = {gold = 7, wit = 2}, mul = {trade = 3.0}},
	{id = "travel", name = "견문 넓히기", a = [14, 75], desc = "낯선 사람과 기연을 만나고 매력이 는다. 돈이 들고 위험하다.", fx = {gold = -6, hp = -1, cha = 2},
			mul = {entry = 2.0, luck = 2.5, meet = 3.0, danger = 1.5}},
]

## 매년 하는 일 — 켜 두면 해마다 돈을 내고 효과가 쌓인다. 여럿을 같이 켤 수 있다. 돈이 모자라면 그해는 거른다.
## fam · friends · kids · parents = 그 사람들과의 정을 해마다 그만큼 올린다. cost_kid = 자식 하나당 값.
## 원작의 "해마다 가족 여행 · 헬스장 · 가족 식사 · 자식 용돈" 자리다(사용자 설명 11-07).
const HABITS := [
	{id = "trip", name = "해마다 가족 나들이", cost = 12, a = [18, 90], fam = 4, fx = {hp = 1}, mul = {luck = 1.1},
			desc = "가족과의 정 +4, 건강 +1"},
	{id = "meal", name = "가족과 저녁 식사", cost = 2, a = [12, 100], fam = 3, good = 1, desc = "가족과의 정 +3, 심성이 고와진다"},
	{id = "allow", name = "자식에게 용돈", cost_kid = 4, a = [25, 100], kids = 6, desc = "자식과의 정 +6 (자식 하나에 4냥)"},
	{id = "parents", name = "부모님 봉양", cost = 6, a = [16, 70], parents = 6, good = 1, desc = "부모와의 정 +6"},
	{id = "dojo", name = "무관 다니기", cost = 6, a = [8, 60], fx = {gol = 2, hp = 1}, mul = {entry = 1.5}, desc = "근골이 오르고 무공에 닿을 기회 x1.5"},
	{id = "school", name = "서당 다니기", cost = 5, a = [6, 30], fx = {wis = 2}, mul = {civil = 1.4}, flag = "study",
			desc = "오성이 오르고 글, 과거의 길 x1.4"},
	{id = "drink", name = "벗과 술자리", cost = 4, a = [16, 90], friends = 5, fx = {hp = -1}, mul = {meet = 1.3, vice = 1.2},
			desc = "벗과의 정 +5, 만남 x1.3, 건강 -1"},
	{id = "temple", name = "절에 시주", cost = 5, a = [10, 100], good = 1, mul = {luck = 1.15}, desc = "심성이 고와지고 기연 x1.15"},
]

## 지금 하기 — 즉흥 행동. 각각 한 해에 한 번. 조건 · 결과는 GhLife.can_act · act 에 있다.
const ACTIONS := [
	{id = "trip", name = "가족과 여행 떠나기", cost = 20, desc = "가족과의 정 +8, 건강 +3, 뜻밖의 일이 생기기도"},
	{id = "feast", name = "가족에게 한턱내기", cost = 8, desc = "가족과의 정 +6"},
	{id = "pocket", name = "자식에게 용돈 주기", cost = 10, desc = "자식과의 정 +10"},
	{id = "gift", name = "부모님께 선물", cost = 10, desc = "부모와의 정 +10, 심성 +2"},
	{id = "doctor", name = "의원 찾아가기", cost = 15, desc = "건강 +12"},
	{id = "drink", name = "벗과 술 한잔", cost = 4, desc = "벗과의 정 +7"},
	{id = "sect", name = "문파 찾아가 입문 청하기", cost = 5, desc = "근골로 굴린다. 평생 세 번까지"},
	{id = "exam", name = "과거 보러 가기", cost = 10, desc = "오성으로 굴린다. 붙으면 벼슬"},
	{id = "match", name = "혼처 알아보기", cost = 10, desc = "절반쯤 혼인이 성사된다"},
	{id = "duel", name = "비무 신청하기", cost = 0, desc = "비슷한 고수와 겨룬다. 다칠 수 있다"},
	{id = "market", name = "장터에서 한몫 노리기", cost = 20, desc = "운으로 굴린다. 벌거나 잃거나"},
	{id = "guard", name = "호위 의뢰 받기", cost = 0, desc = "경지가 높을수록 많이 번다. 싸움이 붙기도 한다"},
	{id = "dojo", name = "무관 차리기", cost = 100, desc = "일류부터. 해마다 제자 수업료가 들어온다"},
	{id = "buyoffice", name = "벼슬 사기", cost = 1500, desc = "명성 30 이상. 돈으로 벼슬을 산다. 심성 -10"},
	{id = "charity", name = "의연금 내기", cost = 300, desc = "명성 +15, 심성 +10"},
	{id = "seclusion", name = "폐관수련", cost = 30, desc = "두 해 동안 세상과 끊고 수련만 한다. 가족과는 멀어진다"},
	{id = "loan", name = "전장에서 돈 빌리기", cost = 0, desc = "신용만큼 빌린다. 해마다 이자 1할이 붙는다"},
	{id = "repay", name = "빚 갚기", cost = 0, desc = "가진 돈으로 빚을 갚는다"},
]


static func habit(id: String) -> Dictionary:
	for f in HABITS:
		if f.id == id:
			return f
	return {}


static func action(id: String) -> Dictionary:
	for f in ACTIONS:
		if f.id == id:
			return f
	return {}

## 물건 — 한 번 사면 평생 듣는다.
const ITEMS := [
	{id = "sword", name = "목검", cost = 5, a = [6, 30], desc = "무공에 닿을 기회 x1.6", mul = {entry = 1.6}},
	{id = "book", name = "천자문", cost = 8, a = [6, 40], desc = "글, 과거의 길 x1.6, 오성 +3", fx = {wis = 3}, mul = {civil = 1.6}},
	{id = "charm", name = "부적", cost = 10, a = [0, 200], desc = "운이 조금 트인다. 기연 x1.2", fx = {luck = 1}, mul = {luck = 1.2}},
	{id = "herbs", name = "약재 상자", cost = 30, a = [0, 200], desc = "건강 +15, 병으로 죽을 일이 준다.", fx = {hp = 15}, mul = {}},
	{id = "donkey", name = "나귀", cost = 40, a = [14, 75], desc = "장사 x1.4, 만남 x1.5", mul = {trade = 1.4, meet = 1.5, luck = 1.1}},
	{id = "copy", name = "비급 필사본", cost = 80, a = [10, 70], mart = true, desc = "수련 속도 x1.25", mul = {train = 1.25}},
	{id = "horse", name = "좋은 말", cost = 120, a = [15, 75], desc = "기연 x1.4, 만남 x1.6, 위험 x0.85", mul = {luck = 1.4, meet = 1.6, danger = 0.85}},
]

## 인연의 성향 — 정(bond)이 깊을수록 그 사람 쪽으로 끌린다. 배수 = 1 + k × 정/100.
## good = 해마다 심성을 미는 양(정 100 기준).
const TRAITS := [
	{id = "warrior", name = "무예를 좋아함", mul = {entry = 1.2, danger = 0.2}},
	{id = "scholar", name = "글 읽기를 좋아함", mul = {civil = 1.3}},
	{id = "trader", name = "장사 수완이 좋음", mul = {trade = 1.3}},
	{id = "wander", name = "떠돌이 기질", mul = {meet = 1.0, luck = 0.5, danger = 0.2}},
	{id = "gambler", name = "노름을 좋아함", mul = {vice = 1.8}, good = -2},
	{id = "kind", name = "마음씨가 고움", mul = {}, good = 3},
	{id = "rough", name = "성정이 거침", mul = {danger = 0.5}, good = -2},
	{id = "pious", name = "신심이 깊음", mul = {luck = 0.4}, good = 1},
]
## 집안 → 부모 성향 쪽으로 기우는 정도(없으면 무작위)
const CLASS_TRAIT := {"merchant": "trader", "craft": "trader", "scholar": "scholar", "noble": "scholar", "clerk": "scholar",
		"soldier": "warrior", "escort": "warrior", "sectfam": "warrior", "clan": "warrior", "bandit": "rough",
		"cult": "rough", "cult_elder": "rough", "cult_heir": "rough", "nomad": "wander", "hunter": "wander", "temple": "pious", "beggar": "wander"}


static func focus(id: String) -> Dictionary:
	for f in FOCUS:
		if f.id == id:
			return f
	return FOCUS[0]


static func item(id: String) -> Dictionary:
	for f in ITEMS:
		if f.id == id:
			return f
	return {}


static func trait_of(id: String) -> Dictionary:
	for f in TRAITS:
		if f.id == id:
			return f
	return TRAITS[0]

# ==================== 색 ====================

const INK := Color8(30, 26, 24)
const PAPER := Color8(236, 226, 204)
const PAPER_D := Color8(214, 200, 172)
const RED := Color8(176, 42, 36)
const GOLD := Color8(214, 168, 72)
const JADE := Color8(86, 150, 128)
const DIM := Color8(120, 108, 92)
const BG := Color8(24, 22, 26)
const SIDE_COL := {"정": Color8(80, 140, 210), "사": Color8(160, 110, 60), "마": Color8(190, 50, 60),
		"세가": Color8(200, 160, 70), "개방": Color8(140, 120, 90), "관군": Color8(110, 130, 100),
		"표국": Color8(150, 130, 100), "새외": Color8(90, 170, 190), "독학": Color8(120, 120, 120), "": Color8(120, 110, 100)}


static func region(id: String) -> Dictionary:
	for r in REGIONS:
		if r.id == id:
			return r
	return REGIONS[0]


static func cls(id: String) -> Dictionary:
	for c in CLASSES:
		if c.id == id:
			return c
	return CLASSES[0]


static func sect(id: String) -> Dictionary:
	for s in SECTS:
		if s.id == id:
			return s
	return {}

# ==================== 배움 · 직업 ====================
#
# **태어난 집안의 일을 평생 하지 않아도 된다.** 원작에서 직장을 다니며 자격증을 따거나 대학을 가서 진로를 바꾸던
# 자리다(사용자 요청 11-07). 배움은 여러 해에 걸쳐 쌓이고(해마다 진도 = 0.6 + 그 스텟/100), 해마다 돈이 든다.
# 한 번에 하나. 다 마치면 자격(`quals`)이 남고, 직업이 딸린 배움이면 전직할지 갈림길이 뜬다.

## 배움. years = 다 마치는 데 드는 해(진도), cost = 해마다 드는 돈, stat = 진도를 미는 스텟,
## job = 마치면 고를 수 있는 직업, join = 마치면 들어가는 곳(문파 동작), mart = 무림인만, nmart = 무림인이 아닐 때만
const COURSES := [
	{id = "medicine", name = "의술 배우기", years = 3, cost = 10, a = [12, 50], stat = "wis", job = "doctor",
			desc = "의원 밑에서 맥 짚는 법과 약 짓는 법을 배운다"},
	{id = "academy", name = "서원 유학", years = 4, cost = 15, a = [12, 35], stat = "wis", flag = "study",
			desc = "서원에서 경전을 배운다. 마치면 과거의 길 x2"},
	{id = "commerce", name = "상단 견습", years = 2, cost = 0, a = [12, 45], stat = "wis", job = "merchant",
			desc = "상단을 따라다니며 장사를 배운다. 돈이 안 든다"},
	{id = "smith", name = "대장일 수업", years = 3, cost = 5, a = [12, 40], stat = "gol", job = "smith",
			desc = "풀무 앞에서 쇠 다루는 법을 배운다"},
	{id = "escort", name = "표국 견습", years = 2, cost = 0, a = [14, 35], stat = "gol", nmart = true, join = "join_escort",
			desc = "짐을 나르며 칼 쓰는 법을 배운다. 마치면 표사"},
	{id = "military", name = "무과 준비", years = 3, cost = 8, a = [15, 40], stat = "gol", job = "officer",
			desc = "병법과 활쏘기 말타기를 익혀 무과를 본다"},
	{id = "herbal", name = "약초학", years = 2, cost = 4, a = [12, 60], stat = "wis", job = "herbalist",
			desc = "약초를 가려 캐는 법을 배운다. 기연이 잦아진다"},
	{id = "divine", name = "역술 공부", years = 2, cost = 6, a = [15, 70], stat = "wis", job = "diviner",
			desc = "주역과 관상을 배운다"},
	{id = "painting", name = "서화 공부", years = 3, cost = 8, a = [10, 60], stat = "wis", job = "painter",
			desc = "붓으로 산수를 그리는 법을 배운다"},
	{id = "monk", name = "출가 수행", years = 1, cost = 0, a = [15, 80], stat = "wis", job = "monk",
			desc = "머리를 깎고 산사에서 한 해를 보낸다"},
	{id = "inner", name = "내공 심법 정진", years = 3, cost = 10, a = [12, 90], stat = "wis", mart = true,
			desc = "무림인 전용. 마치면 수련치 +40, 다음 무공"},
]

## 직업 — 배움으로 바꾼다. inc = 해마다 버는 돈(집안 벌이 대신), mul = 진로 배수, flavor = 아무 일 없던 해의 글.
const JOBS := {
	"doctor": {name = "의원", inc = 20, mul = {}, flavor = ["환자들의 맥을 짚으며 하루를 보냈다.", "약재를 말리고 썰었다.", "왕진을 다녔다."]},
	"smith": {name = "대장장이", inc = 12, mul = {}, flavor = ["풀무질로 하루를 열었다.", "농기구를 벼렸다.", "칼 한 자루를 오래 두드렸다."]},
	"officer": {name = "무관", inc = 35, mul = {danger = 1.2}, flavor = ["병사들을 조련했다.", "성벽을 순찰했다."]},
	"herbalist": {name = "약초꾼", inc = 8, mul = {luck = 1.3}, flavor = ["산을 타며 약초를 캤다.", "캔 약초를 약방에 넘겼다."]},
	"diviner": {name = "점쟁이", inc = 10, mul = {meet = 1.2}, flavor = ["저잣거리에서 점괘를 봐 주었다.", "관상을 보러 온 손님이 끊이지 않았다."]},
	"painter": {name = "화공", inc = 10, mul = {}, flavor = ["산수화 한 폭을 그렸다.", "먹을 갈며 하루를 보냈다."]},
	"monk": {name = "승려", inc = 0, mul = {luck = 1.1}, flavor = ["새벽 예불을 올렸다.", "마당을 쓸고 경을 읽었다."]},
	"laborer": {name = "일꾼", inc = 6, mul = {}, flavor = ["남의 집 일을 거들고 품삯을 받았다.", "짐을 져 나르며 하루를 보냈다."]},
	"teacher": {name = "훈장", inc = 14, mul = {civil = 1.3}, flavor = ["서당 아이들에게 천자문을 가르쳤다.", "회초리를 들었다 놓았다."]},
	"constable": {name = "포졸", inc = 12, mul = {danger = 1.2}, flavor = ["저잣거리를 순찰했다.", "좀도둑을 잡았다."]},
	"factor": {name = "객주", inc = 22, mul = {trade = 1.4}, flavor = ["오가는 상인들의 물건을 맡아 주었다.", "장부를 맞췄다."]},
	"pokwae": {name = "포쾌", inc = 22, mul = {danger = 1.3}, flavor = ["관아의 명을 받아 도둑을 쫓았다.", "현상금 붙은 자의 행방을 캤다."]},
	"assassin": {name = "살수", inc = 70, mul = {danger = 1.6, vice = 1.3}, flavor = ["밤에만 움직였다.", "칼날에 묻은 피를 닦았다.", "누구에게도 이름을 말하지 않았다."]},
	"munsa": {name = "문사", inc = 16, mul = {civil = 1.3}, flavor = ["시를 짓고 글을 써 팔았다.", "벗들과 시회를 열었다."]},
	"strategist": {name = "책사", inc = 45, mul = {civil = 1.2}, flavor = ["주군에게 올릴 계책을 짰다.", "밤새 지도를 들여다보았다."]},
	"ronin": {name = "낭인", inc = 15, mul = {danger = 1.3, meet = 1.3}, flavor = ["칼 한 자루로 떠돌았다.", "객잔 구석에서 술을 마셨다."]},
	"escortman": {name = "표사", inc = 20, mul = {danger = 1.2}, flavor = ["표물을 지키며 먼 길을 갔다.", "녹림의 눈을 피해 돌아갔다."]},
	"instructor": {name = "무관 사범", inc = 32, mul = {}, flavor = ["제자들의 자세를 바로잡아 주었다.", "새로 온 아이들에게 기본을 가르쳤다."]},
	"informant": {name = "정보상", inc = 20, mul = {meet = 1.5}, flavor = ["주워들은 소문을 비싸게 팔았다.", "골목마다 귀를 심어 두었다."]},
	"taoist": {name = "도사", inc = 9, mul = {luck = 1.3}, flavor = ["부적을 써 주고 쌀을 받았다.", "산 기슭 도관에서 수행했다."]},
	"gambler": {name = "도박사", inc = 0, mul = {vice = 2.0}, flavor = ["노름판에서 밤을 지새웠다.", "주사위 소리로 하루를 보냈다."]},
	"storyteller": {name = "이야기꾼", inc = 8, mul = {}, flavor = ["찻집에서 강호 이야기를 풀어놓았다.", "사람들이 다음 이야기를 졸랐다."]},
	"boatman": {name = "사공", inc = 7, mul = {}, flavor = ["나룻배로 사람들을 건네주었다.", "강물이 불어 배를 묶어 두었다."]},
	"waiter": {name = "점소이", inc = 5, mul = {meet = 1.2}, flavor = ["객잔에서 술상을 날랐다.", "손님들의 무용담을 엿들었다."]},
	"interpreter": {name = "역관", inc = 26, mul = {}, flavor = ["변방 사신의 말을 옮겼다.", "오랑캐 말을 공부했다."]},
	# 무협 직업(조사 뒤 11-07 추가) — 관부 · 강호 · 저잣거리
	"geumui": {name = "금의위", inc = 45, mul = {danger = 1.3}, flavor = ["황명을 받아 무림인의 뒤를 캤다.", "비단 제복을 입고 성안을 순찰했다."]},
	"dongchang": {name = "동창 번자", inc = 40, mul = {danger = 1.2, vice = 1.3}, flavor = ["환관의 명으로 사람을 잡아들였다.", "밀고장을 읽으며 밤을 새웠다."]},
	"bounty": {name = "현상금 사냥꾼", inc = 12, mul = {danger = 1.4, meet = 1.2}, flavor = ["방에 붙은 수배범의 얼굴을 외웠다.", "흔적을 쫓아 산을 넘었다."]},
	"gibang": {name = "기루 주인", inc = 45, mul = {meet = 1.5, vice = 1.4}, flavor = ["기루에 등불을 밝혔다.", "귀한 손님을 맞았다."]},
	"gisaeng": {name = "기녀", inc = 25, mul = {meet = 1.6}, flavor = ["가야금을 타며 손님을 맞았다.", "시 한 수로 좌중을 울렸다."]},
	"innkeeper": {name = "객잔 주인", inc = 30, mul = {meet = 1.4, trade = 1.2}, flavor = ["객잔 문을 열고 손님을 받았다.", "강호인들의 소문을 귀동냥했다."]},
	"cook": {name = "숙수", inc = 14, mul = {}, flavor = ["새벽부터 화덕에 불을 지폈다.", "새 요리를 궁리했다."]},
	"bodyguard": {name = "보표", inc = 35, mul = {danger = 1.2}, flavor = ["주인의 뒤를 그림자처럼 따랐다.", "가마 곁에서 칼자루를 쥐었다."]},
	"patrol": {name = "무림맹 순찰", inc = 30, mul = {danger = 1.2, meet = 1.2}, flavor = ["맹의 깃발을 들고 고을을 돌았다.", "사파의 동태를 살폈다."]},
	"alchemist": {name = "연단사", inc = 20, mul = {luck = 1.4}, flavor = ["단로에 불을 지켰다.", "약재를 달여 단약을 빚었다."]},
	"mechanist": {name = "기관사", inc = 28, mul = {}, flavor = ["톱니와 쇠뇌를 깎았다.", "기관 함정의 설계도를 그렸다."]},
	"poisoner": {name = "독사", inc = 30, mul = {danger = 1.2, vice = 1.2}, flavor = ["독초를 다려 독을 우렸다.", "독물을 길렀다."]},
	"musician": {name = "악사", inc = 12, mul = {meet = 1.3}, flavor = ["퉁소를 불며 저잣거리를 걸었다.", "연회에서 비파를 탔다."]},
	"graverobber": {name = "도굴꾼", inc = 5, mul = {luck = 1.5, danger = 1.3}, flavor = ["밤마다 옛 무덤을 살폈다.", "도굴한 물건을 몰래 팔았다."]},
	"pirate": {name = "수적", inc = 30, mul = {danger = 1.4, vice = 1.3}, flavor = ["강을 오가는 배를 노렸다.", "물길의 길목을 지켰다."]},
}


static func course(id: String) -> Dictionary:
	for c in COURSES:
		if c.id == id:
			return c
	return {}

## 고를 수 있는 직업 — need: qual(배움) · flag · gol(근골) · cls(집안). 조건이 맞으면 직업 탭에서 바로 바꾼다(한 해에 한 번).
const JOB_NEED := {
	"laborer": {}, "teacher": {any_flag = ["study"], qual = "academy"}, "constable": {gol = 55},
	"factor": {qual = "commerce"}, "doctor": {qual = "medicine"}, "smith": {qual = "smith"}, "officer": {flag = "mil_pass"},
	"herbalist": {qual = "herbal"}, "diviner": {qual = "divine"}, "painter": {qual = "painting"}, "monk": {qual = "monk"},
	"pokwae": {gol = 60, realm = 1}, "assassin": {realm = 2, good_max = -20}, "munsa": {any_flag = ["study"], wis = 65},
	"strategist": {qual = "academy", wis = 75}, "ronin": {martial = true}, "escortman": {realm = 1},
	"instructor": {realm = 3}, "informant": {wit = 60}, "taoist": {any_flag = ["hermit"], qual = "divine"},
	"gambler": {luck = 6}, "storyteller": {cha = 55}, "boatman": {}, "waiter": {},
	"interpreter": {cls_any = ["nomad", "cult"], qual = "academy"},
	"geumui": {gol = 65, realm = 1}, "dongchang": {wit = 55, good_max = 0}, "bounty": {realm = 1}, "gibang": {wit = 55, gold = 500},
	"gisaeng": {cha = 60, sex = "f"}, "innkeeper": {biz = "inn"}, "cook": {dex = 50}, "bodyguard": {realm = 2},
	"patrol": {realm = 2, sides = ["정", "세가", "개방"]}, "alchemist": {wis = 60, qual = "herbal"}, "mechanist": {dex = 65},
	"poisoner": {dex = 55, good_max = 10}, "musician": {cha = 55}, "graverobber": {luck = 5, good_max = 20}, "pirate": {gol = 55, good_max = -10},
}

# ==================== 재산 ====================
#
# **재물 · 명성으로 할 수 있는 일이 있어야 한다** — 원작의 집 사기 · 주식 · 채권 · 사업 자리(사용자 요청 11-07).
# 땅값(`GhLife.land`)은 해마다 출렁이고 흉년 · 전쟁에 떨어진다. 집은 그 값으로 사고판다.

## 집 — 사면 해마다 효과. inc = 세(貰) 수입, fam = 가족과의 정, hp = 건강
const HOUSES := [
	{id = "hut", name = "초가집", cost = 60, desc = "건강 +1, 가족과의 정 +1 해마다", hp = 1, fam = 1},
	{id = "tile", name = "기와집", cost = 350, desc = "건강 +2, 가족과의 정 +2, 명성 +5", hp = 2, fam = 2, fame = 5},
	{id = "shopbld", name = "상가 건물", cost = 900, desc = "해마다 세 70냥", inc = 70},
	{id = "manor", name = "장원", cost = 2500, desc = "해마다 소작료 150냥, 명성 +20", inc = 150, fame = 20},
]

## 투자 — 100냥 단위로 사고 언제든 판다. mu = 한 해 평균 수익 · sd = 출렁임 · bust = 한 해에 망할 확률
const INVEST := [
	{id = "deposit", name = "전장 예금", mu = 0.04, sd = 0.0, desc = "해마다 4푼. 잃지 않는다"},
	{id = "caravan", name = "상단 지분", mu = 0.07, sd = 0.3, desc = "평균 7푼. 전쟁, 흉년에 떨어진다"},
	{id = "mine", name = "광산 지분", mu = 0.1, sd = 0.55, bust = 0.08, desc = "크게 벌거나 통째로 망한다"},
]

## 사업 — 차리고(cost) 키우고(3단까지) 접는다. 해마다 벌이 = base × 단 × 운 × (1 + 명성/300). 나쁜 해도 있다.
## need: qual · job · cls · realm · fame
const BIZ := [
	{id = "inn", name = "객잔", cost = 300, base = 60, desc = "누구나. 오가는 손님에게 술과 방을 판다", need = {}},
	{id = "silk", name = "비단 가게", cost = 500, base = 90, desc = "상인 집안이나 상단 견습을 마치면", need = {trade = true}},
	{id = "pharmacy", name = "약방", cost = 400, base = 80, desc = "의술 또는 약초학을 배우면", need = {quals = ["medicine", "herbal"]}},
	{id = "forge", name = "대장간", cost = 250, base = 55, desc = "대장일을 배우면", need = {quals = ["smith"]}},
	{id = "escortco", name = "표국", cost = 1500, base = 260, desc = "일류 이상의 무림인", need = {realm = 3}},
	{id = "bank", name = "전장", cost = 4000, base = 650, desc = "명성 60 이상", need = {fame = 60}},
]


static func house(id: String) -> Dictionary:
	for h in HOUSES:
		if h.id == id:
			return h
	return {}


static func inv(id: String) -> Dictionary:
	for h in INVEST:
		if h.id == id:
			return h
	return {}


static func biz(id: String) -> Dictionary:
	for h in BIZ:
		if h.id == id:
			return h
	return {}

# ==================== 직업 단계 ====================
#
# **직업도 경지처럼 오른다**(사용자 요청 11-07). 해마다 경력이 쌓이고(0.6 + 그 직업의 스텟/100, 생업 우선이면 1.4배),
# 3단부터는 **벽**이 있다 — 그 직업의 큰일(역병 때 사람을 살림 · 명검을 벼림 · 큰 청부 · 계책 적중 …)을 해내면 공적(feat)이
# 쌓이고, 공적이 있어야 넘는다. 단이 오르면 벌이가 RANK_MUL 배, 높은 단 전용 사건(`jrank`)이 열리고 칭호가 바뀐다.
# 열쇠는 직업 id, 집안의 일은 "cls:<집안>". 단마다 이름 · 경력 문턱은 JOB_XP.

const JOB_XP := [0, 6, 20, 45, 80]
const RANK_MUL := [1.0, 1.7, 2.8, 4.2, 6.0]
const JOB_WALL_FROM := 2        ## 이 단에서 다음 단으로 갈 때부터 공적이 필요하다

const JOB_RANKS := {
	"doctor": {stat = "wis", ranks = ["견습의", "의원", "명의", "신의", "어의"]},
	"smith": {stat = "dex", ranks = ["풀무꾼", "대장장이", "명장", "신장"]},
	"officer": {stat = "gol", ranks = ["초관", "천총", "도독", "대장군"]},
	"herbalist": {stat = "luck", ranks = ["약초꾼", "심마니", "약왕"]},
	"diviner": {stat = "wis", ranks = ["점쟁이", "역술가", "국사"]},
	"painter": {stat = "dex", ranks = ["환쟁이", "화공", "명화가", "화성"]},
	"monk": {stat = "wis", ranks = ["행자", "승려", "선사", "대사"]},
	"laborer": {stat = "gol", ranks = ["품팔이", "일꾼", "십장"]},
	"teacher": {stat = "wis", ranks = ["훈장", "이름난 훈장", "서원 학장"]},
	"constable": {stat = "gol", ranks = ["포졸", "포졸 반장", "포졸 대장"]},
	"pokwae": {stat = "gol", ranks = ["포쾌", "포두", "총포두", "천하신포"]},
	"factor": {stat = "wit", ranks = ["객주", "대객주", "도객주"]},
	"assassin": {stat = "gol", ranks = ["청부꾼", "살수", "일급 살수", "그림자", "살왕"]},
	"munsa": {stat = "wis", ranks = ["서생", "문사", "명문장가", "문호"]},
	"strategist": {stat = "wis", ranks = ["모사", "책사", "군사", "와룡"]},
	"ronin": {stat = "gol", ranks = ["떠돌이", "낭인", "검귀"]},
	"escortman": {stat = "gol", ranks = ["쟁자수", "표사", "표두", "총표두"]},
	"instructor": {stat = "gol", ranks = ["교두", "사범", "대사범"]},
	"informant": {stat = "wit", ranks = ["귀동냥", "정보상", "정보왕"]},
	"taoist": {stat = "wis", ranks = ["도동", "도사", "진인"]},
	"gambler": {stat = "luck", ranks = ["노름꾼", "도박사", "도신"]},
	"storyteller": {stat = "cha", ranks = ["이야기꾼", "설서인", "천하명설서"]},
	"boatman": {stat = "gol", ranks = ["사공", "선주", "수운 대방"]},
	"waiter": {stat = "cha", ranks = ["점소이", "점원 우두머리", "객잔 장궤"]},
	"interpreter": {stat = "wit", ranks = ["통사", "역관", "수석 역관"]},
	"geumui": {stat = "gol", ranks = ["교위", "백호", "천호", "지휘사", "도독"]},
	"dongchang": {stat = "wit", ranks = ["번자", "당두", "첩형", "제독"]},
	"bounty": {stat = "gol", ranks = ["추적꾼", "현상금 사냥꾼", "천하제일 추적자"]},
	"gibang": {stat = "wit", ranks = ["기루 주인", "이름난 기루", "천하제일루"]},
	"gisaeng": {stat = "cha", ranks = ["동기", "기녀", "명기", "경국지색"]},
	"innkeeper": {stat = "cha", ranks = ["객잔 주인", "이름난 객잔", "천하객잔"]},
	"cook": {stat = "dex", ranks = ["부엌데기", "숙수", "명숙수", "식신"]},
	"bodyguard": {stat = "gol", ranks = ["보표", "호위 무사", "호위대장"]},
	"patrol": {stat = "gol", ranks = ["순찰", "순찰대장", "맹의 집법"]},
	"alchemist": {stat = "wis", ranks = ["단동", "연단사", "단성"]},
	"mechanist": {stat = "dex", ranks = ["목수", "기관사", "기관의 대가"]},
	"poisoner": {stat = "dex", ranks = ["독쟁이", "독사", "독왕"]},
	"musician": {stat = "cha", ranks = ["떠돌이 악사", "악사", "악성"]},
	"graverobber": {stat = "luck", ranks = ["도굴꾼", "고분 사냥꾼", "도굴왕"]},
	"pirate": {stat = "gol", ranks = ["수적", "수적 두목", "수채주"]},
	"cls:farm": {stat = "gol", ranks = ["농부", "자작농", "부농", "대지주"]},
	"cls:tenant": {stat = "gol", ranks = ["소작인", "자작농", "부농"]},
	"cls:merchant": {stat = "wit", ranks = ["행상", "객상", "거상", "천하제일상"]},
	"cls:craft": {stat = "dex", ranks = ["도제", "장인", "명장", "대명장"]},
	"cls:fisher": {stat = "gol", ranks = ["어부", "선주", "선단주"]},
	"cls:hunter": {stat = "gol", ranks = ["사냥꾼", "명포수"]},
	"cls:clerk": {stat = "wit", ranks = ["아전", "이방", "호장"]},
	"cls:nomad": {stat = "gol", ranks = ["목동", "목자", "족장"]},
}

# ==================== 가세 · 몇째 ====================
#
# **같은 집안이라도 형편이 다르고, 몇째로 태어났느냐가 다르다**(사용자 요청 11-07 "부잣집 · 사천당가 첫째 아들").
# 가세는 처음 재물 · 집안 재산(가산) · 신용 · 건강에 곱하고, 장남 · 장녀(또는 외동)가 부모가 떠날 때 가산을 물려받는다.
# 세가 · 문파 속가의 장자는 후계 사건을 겪는다(GhLife._heir_events).

## 가세 — w = 비중(%), k = 재물 배수, credit = 신용에 더함
const WEALTH := [
	{name = "빈한한", w = 20.0, k = 0.3, credit = -40, hp = -4},
	{name = "", w = 50.0, k = 1.0, credit = 0, hp = 0},
	{name = "넉넉한", w = 20.0, k = 2.5, credit = 60, hp = 1},
	{name = "부유한", w = 8.5, k = 8.0, credit = 200, hp = 3},
	{name = "거부의", w = 1.5, k = 40.0, credit = 800, hp = 5},
]
## 가세 → 물려받을 집(가산에 딸린 것)
const WEALTH_HOUSE := ["", "hut", "tile", "tile", "manor"]

## 몇째 — w = 비중(%). heir = 가산 · 가주 자리를 잇는 자리
const ORDER := [
	{id = "only", w = 15.0, heir = true},
	{id = "first", w = 35.0, heir = true},
	{id = "second", w = 30.0, heir = false},
	{id = "last", w = 20.0, heir = false},
]

## 세가 — 본거지에서만 태어난다. 이름은 땅을 붙여 부른다(사천당가 · 하북팽가)
const CLAN_AT := {"sichuan": ["tang"], "hebei": ["moyong", "paeng"], "jiangnan": ["namgung"], "hubei": ["jegal"]}
const CLAN_NAME := {"tang": "사천당가", "paeng": "하북팽가", "namgung": "남궁세가", "moyong": "모용세가", "jegal": "제갈세가"}
const CLAN_SUR := {"tang": "당", "paeng": "팽", "namgung": "남궁", "moyong": "모용", "jegal": "제갈"}
