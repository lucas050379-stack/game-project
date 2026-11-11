class_name BgD
extends RefCounted

## 버거왕 표 — 재료 · 날 · 강화 · 조절값(기획서 docs/design/burger.md). 그리기를 모른다.
## 버거 = 아래 빵 + 층들 + 위 빵(같은 빵). 주문과 조립대의 버거는 재료 id 의 줄(아래에서 위로)이다.

const DAY_T := 180.0           ## 하루 영업(초)
const DAYS := 30
const BASE_PAY := 10           ## 버거 하나의 기본 값(재료 값에 더한다)
const STACK_MAX := 12
const COOK_T := 3.0            ## 패티가 익는 데 걸리는 시간
const GOOD_T := 5.0            ## 알맞은 채로 버티는 시간(보온 철판이 늘린다)
const PERFECT_K := 0.6         ## 알맞은 구간의 앞 이만큼이 "딱 알맞음"(미식가)
const FLIP_T := 1.9            ## 뒤집는 날 — 한 면이 익는 시간(두 면 다 익혀야 한다)
const PREP_N := 6              ## 야채 한 번 손질한 양(이만큼 얹으면 떨어진다)
const PREP_T := 1.5            ## 야채를 써는 시간
const MELT_T := 1.0            ## 철판의 패티 위에서 치즈가 녹는 시간
const WRAP_PAY := 3            ## 포장 값
const WRONG_K := 0.25          ## 틀린 버거를 내면 깎이는 참을성(전체에 대한 비)
const LEAVE_T := 2.2           ## 떠나는 손님을 그리는 시간(문까지 걸어 나간다 — 자리는 바로 빈다)
const WALK_IN_T := 1.0         ## 손님이 문에서 자리까지 걸어오는 시간 — 그동안은 참을성이 안 준다(11-11 사용자: 땅에서 솟고 땅으로 꺼지는 게 어색하다)
const SHOP_SLOTS := [2, 3, 3, 4]   ## 가게 단계(노점 · 작은 가게 · 동네 버거집 · 큰 매장)마다 손님 자리
const SHOP_PAT := [1.0, 1.0, 1.12, 1.2]   ## 〃 참을성 배(가게가 예쁠수록 오래 기다린다)
const SHOP_PAY := [1.0, 1.2, 1.4, 1.65]   ## 〃 버거 값 배 — 넓힐수록 비싸게 판다(확장의 주된 이득, 11-11: 자리만 늘리면 봇 검산에서 버는 돈이 그대로였다)
const SHOP_DAY := [5, 12, 20]  ## 〃 다음 단계로 넓힐 수 있는 날(1 부터 — 그날이 열려 있어야)
const SHOP_NAME := ["골목 노점", "작은 버거 가게", "동네 버거집", "큰 매장"]
const SET_PAY := {drink = 8, fries = 12}
## 음료 — 기계의 꼭지 넷. [이름, 색(따르는 막대 · 그림이 없을 때)]
const DRINKS := {"dr_cola": ["콜라", Color8(92, 52, 36)], "dr_fanta": ["퐌타", Color8(255, 150, 30)], "dr_cider": ["사이다", Color8(214, 240, 226)],
		"dr_oj": ["오렌지주스", Color8(255, 190, 60)]}
const DRINK_IDS := ["dr_cola", "dr_fanta", "dr_cider", "dr_oj"]
const POUR_T := 1.4            ## 컵이 가득 차는 데 걸리는 시간(누르고 있는 동안)
const POUR_OK := 0.78          ## 이만큼은 따라야 낼 수 있다(선)
const POUR_MAX := 1.1          ## 이걸 넘기면 넘쳐서 버린다
## 감자튀김 — 바구니를 넣고 노릇할 때 건진다. 그 위에 **가루 양념**을 뿌린다(가게에서 쓰는 통 — 찍어 먹는 소스가 아니다, 사용자 결정 11-10).
const FRY_T := 3.5             ## 튀겨지는 시간
const FRY_GOOD := 3.5          ## 노릇한 채로 버티는 시간
const DIPS := {"dp_salt": ["소금", Color8(250, 250, 250)], "dp_cheese": ["치즈 가루", Color8(255, 176, 40)], "dp_onion": ["어니언 가루", Color8(190, 226, 150)],
		"dp_chili": ["매운 가루", Color8(226, 54, 40)], "dp_honey": ["허니버터 가루", Color8(250, 210, 110)]}
const DIP_IDS := ["dp_salt", "dp_cheese", "dp_onion", "dp_chili", "dp_honey"]

## 재료: id → [이름, 분류(bun · patty · veg · cheese · top · sauce), 값, 해금 값(0 = 처음부터 있다)]
const ING := {
	"bun_sesame": ["참깨 번", "bun", 2, 0], "bun_brioche": ["브리오슈", "bun", 4, 300], "bun_potato": ["포테이토 번", "bun", 4, 500],
	"bun_ink": ["먹물 번", "bun", 6, 900], "bun_lettuce": ["양상추 번", "bun", 5, 700], "bun_muffin": ["머핀", "bun", 5, 600],
	"pt_beef": ["소고기 패티", "patty", 8, 0], "pt_chicken": ["치킨 패티", "patty", 9, 250], "pt_pork": ["돼지 패티", "patty", 9, 400],
	"pt_shrimp": ["새우 패티", "patty", 12, 800], "pt_vegan": ["비건 패티", "patty", 10, 600],
	"vg_lettuce": ["양상추", "veg", 2, 0], "vg_tomato": ["토마토", "veg", 3, 0], "vg_onion": ["양파", "veg", 3, 120],
	"vg_pickle": ["피클", "veg", 3, 150], "vg_jalapeno": ["할라피뇨", "veg", 4, 350], "vg_avocado": ["아보카도", "veg", 6, 700],
	"vg_mushroom": ["버섯", "veg", 5, 450],
	"ch_cheddar": ["체다", "cheese", 4, 0], "ch_swiss": ["스위스", "cheese", 5, 300], "ch_mozza": ["모짜렐라", "cheese", 5, 400],
	"ch_pepper": ["페퍼잭", "cheese", 6, 550], "ch_blue": ["블루치즈", "cheese", 7, 800],
	"tp_bacon": ["베이컨", "top", 6, 200], "tp_egg": ["계란", "top", 5, 250], "tp_hash": ["해시브라운", "top", 6, 450],
	"tp_pork": ["풀드포크", "top", 8, 750], "tp_chili": ["칠리", "top", 7, 650],
	"sc_ketchup": ["케첩", "sauce", 1, 0], "sc_mayo": ["마요", "sauce", 1, 80], "sc_mustard": ["머스터드", "sauce", 1, 100],
	"sc_house": ["하우스 소스", "sauce", 2, 220], "sc_bbq": ["바비큐 소스", "sauce", 2, 260], "sc_hot": ["핫 소스", "sauce", 2, 300],
	"sc_truffle": ["트러플 마요", "sauce", 4, 700], "sc_tartar": ["타르타르", "sauce", 2, 340], "sc_bulgogi": ["불고기 소스", "sauce", 3, 420],
}
## 선반에 놓는 순서 — 분류끼리 모은다(같은 재료는 늘 같은 쪽에 온다)
const ORDER := ["bun_sesame", "bun_brioche", "bun_potato", "bun_ink", "bun_lettuce", "bun_muffin",
		"pt_beef", "pt_chicken", "pt_pork", "pt_shrimp", "pt_vegan",
		"ch_cheddar", "ch_swiss", "ch_mozza", "ch_pepper", "ch_blue",
		"vg_lettuce", "vg_tomato", "vg_onion", "vg_pickle", "vg_jalapeno", "vg_avocado", "vg_mushroom",
		"tp_bacon", "tp_egg", "tp_hash", "tp_pork", "tp_chili",
		"sc_ketchup", "sc_mayo", "sc_mustard", "sc_house", "sc_bbq", "sc_hot", "sc_truffle", "sc_tartar", "sc_bulgogi"]
## 소스 색 — 흰 소스 그림 한 장에 곱한다
const SAUCE_COL := {"sc_ketchup": Color8(226, 54, 44), "sc_mayo": Color8(252, 244, 214), "sc_mustard": Color8(240, 196, 40),
		"sc_house": Color8(244, 150, 110), "sc_bbq": Color8(120, 52, 30), "sc_hot": Color8(240, 96, 20),
		"sc_truffle": Color8(214, 204, 170), "sc_tartar": Color8(232, 240, 200), "sc_bulgogi": Color8(96, 60, 40)}

## 강화(가게에서 돈으로 산다): [열쇠, 이름, 설명, 단계마다의 값]
const UP := [
	# 끝 칸 = 쓰이기 시작하는 날(1 부터) — 가게 화면에 "N일째부터" 로 보인다(사용자 11-11 "언제부터 쓰이는지 모른다"). 철판은 4일째(day().grill), 음료 · 튀김은 13일째(day().sets)
	["grill", "철판 넓히기", "패티를 굽는 칸이 하나 늘어요", [400, 900], 4],
	["warm", "보온 철판", "알맞게 익은 채로 더 오래 버텨요", [300, 700, 1200], 4],
	["helper", "굽기 보조", "패티가 훨씬 늦게 타요", [1200], 4],
	["drink", "음료 기계", "음료 주문을 받아요(네 가지를 따라요)", [800], 13],
	["fries", "감자튀김기", "감자튀김 주문을 받아요(튀겨서 가루 양념을)", [900], 13],
	# 가게 확장(11-11) — 자리 늘리기 · 가게 꾸미기를 합쳤다. 단계마다 배경(bg_room_N) · 자리 · 참을성이 바뀐다. 산 날 조건은 SHOP_DAY. 계산 알바는 뺐다(사용자)
	["shop", "가게 확장", "가게가 넓어지고 손님 자리가 늘어요", [800, 1800, 3000], 1],
]
## 손님 갈래 — [이름, 참을성 배, 값 배, 팁 배]
const KIND := {"normal": ["", 1.0, 1.0, 1.0], "kid": ["꼬마", 0.85, 1.0, 1.0], "gourmet": ["미식가", 1.0, 1.0, 3.0],
		"group": ["단체", 1.5, 1.0, 1.0], "rider": ["배달", 1.7, 1.4, 1.0]}
## 날마다의 목표 금액(별 하나) — 완벽하게 만든 봇이 버는 돈의 절반쯤(tools/burger_check.gd 가 찍어 준다)
const GOALS := [420, 420, 420, 430, 430, 450, 460, 480, 500, 500, 500, 500, 550, 550, 550, 550, 550, 550, 570, 570,
		580, 580, 580, 580, 580, 580, 580, 580, 620, 620]


## 층 이름의 꼬리표를 뗀 재료 id — "+" = 소스 듬뿍(두 번 짠 것), "~" = 녹인 치즈(철판의 패티 위에서 녹인 것).
static func base(id: String) -> String:
	return id.trim_suffix("+").trim_suffix("~")


static func name_of(id: String) -> String:
	return String(ING[base(id)][0]) + (" 듬뿍" if id.ends_with("+") else "") + (" 녹임" if id.ends_with("~") else "")


static func cat(id: String) -> String:
	return String(ING[base(id)][1])


static func price(id: String) -> int:
	return int(ING[base(id)][2]) + (1 if id != base(id) else 0)


static func unlock_cost(id: String) -> int:
	return int(ING[id][3])


## 처음부터 열려 있는 재료.
static func starters() -> Array:
	return ORDER.filter(func(id): return unlock_cost(id) == 0)


## 그날의 조절값. d = 0 이 첫날.
static func day(d: int) -> Dictionary:
	var tier := 0 if d < 3 else (1 if d < 7 else (2 if d < 12 else (3 if d < 18 else (4 if d < 24 else 5))))
	var k := d / float(DAYS - 1)
	return {
		lay_min = [2, 3, 3, 4, 4, 5][tier], lay_max = [3, 4, 5, 5, 6, 7][tier],   # 11-10 밤: 한 층씩 낮춤(사용자 "너무 어렵다")
		shelf_n = [6, 9, 12, 15, 18, 21][tier],
		gap0 = lerpf(8.5, 7.5, k), gap1 = lerpf(6.5, 5.8, k),      # 11-10 밤: 손님이 덜 몰리게(6.8 · 5.2 → 8.5 · 6.5)
		# 아래 설명은 예전 값:      # 손님이 오는 간격 — 하루의 처음 · 끝(첫 닷새가 한가해서 처음 값을 8 → 6.8 로, 11-10)
		# 참을성 배 — 13일째부터는 1.3배 더: 봇은 재료를 한 번에 집지만 사람은 통을 열고 집어 누르는 횟수가 훨씬 많다(일도 그때부터 겹친다)
		patience = lerpf(2.2, 2.0, k) * (1.3 if d >= 12 else 1.0),   # 11-10 밤: 1.5 → 2.2(마우스로는 재료 하나에 두 번 움직인다)
		grill = d >= 3, sets = d >= 12, special = d >= 18,
		prep = d >= 5,      # 6일째부터 야채를 손질해 채운다
		sauce2 = d >= 7,    # 8일째부터 소스 듬뿍(두 번 짜기) 주문
		flip = d >= 9,      # 10일째부터 패티를 뒤집는다
		melt = d >= 15,     # 16일째부터 치즈를 녹이는 주문
		wrap = d >= 21,     # 22일째부터 포장 손님
		goal = int(GOALS[d]),
	}


## 주문 하나의 참을성(초) — 층이 많을수록 길다.
static func patience_of(layers: int) -> float:
	return 9.0 + layers * 2.4


## 그날 선반에 놓을 재료 — 열린 것 가운데 shelf_n 개. 빵 · 패티는 꼭 하나씩 들고, 나머지는 날마다 다르게(같은 날은 늘 같다) 섞는다.
static func shelf_for(d: int, unlocked: Array) -> Array:
	var n := int(day(d).shelf_n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 + d * 131
	var pool := ORDER.filter(func(id): return unlocked.has(id))
	var pick: Array = []
	# 새로 연 재료 둘은 **꼭** 선반에(unlocked 는 연 차례대로다) — 사서 열었는데 언제 나올지 몰랐다(사용자 11-11). 가게 화면도 "다음 판부터 꼭 나와요"
	var fresh := unlocked.filter(func(id): return pool.has(id) and unlock_cost(id) > 0)
	for i in range(fresh.size() - 1, maxi(-1, fresh.size() - 3), -1):
		pick.append(fresh[i])
	for c in ["bun", "patty", "veg", "cheese", "sauce"]:   # 분류마다 하나는 먼저
		var cs := pool.filter(func(id): return cat(id) == c and not pick.has(id))
		if not cs.is_empty() and not pick.any(func(id): return cat(id) == c):
			pick.append(cs[rng.randi() % cs.size()])
	var rest := pool.filter(func(id): return not pick.has(id))
	while pick.size() < n and not rest.is_empty():
		var i := rng.randi() % rest.size()
		pick.append(rest[i])
		rest.remove_at(i)
	return ORDER.filter(func(id): return pick.has(id))


## 주문 하나 — 선반의 재료로 만든다. 패티가 꼭 하나(높으면 가끔 둘) 들고, 같은 재료가 바로 겹치지 않는다.
static func make_order(rng: RandomNumberGenerator, shelf: Array, layers: int, c: Dictionary = {}) -> Array:
	var buns := shelf.filter(func(id): return cat(id) == "bun")
	var patties := shelf.filter(func(id): return cat(id) == "patty")
	var others := shelf.filter(func(id): return cat(id) != "bun" and cat(id) != "patty")
	var bun: String = buns[rng.randi() % buns.size()]
	var mid: Array = []
	var np := 2 if layers >= 5 and rng.randf() < 0.4 else 1
	for i in np:
		mid.append(patties[rng.randi() % patties.size()])
	var guard := 0
	while mid.size() < layers and not others.is_empty() and guard < 60:
		guard += 1
		var id: String = others[rng.randi() % others.size()]
		if mid.count(id) >= 2:
			continue
		mid.append(id)
	# 섞되 같은 것이 붙지 않게 몇 번 다시 섞는다
	for tries in 8:
		for i in range(mid.size() - 1, 0, -1):
			var j := rng.randi() % (i + 1)
			var tmp = mid[i]
			mid[i] = mid[j]
			mid[j] = tmp
		var ok := true
		for i in mid.size() - 1:
			if mid[i] == mid[i + 1]:
				ok = false
		if ok:
			break
	# 섞고도 같은 것이 붙어 있으면 하나를 뺀다 - 같은 소스가 붙으면 "듬뿍"과 구별이 안 되어 만들 수 없는 주문이 된다
	for i in range(mid.size() - 1, 0, -1):
		if mid[i] == mid[i - 1]:
			mid.remove_at(i)
	# 소스 듬뿍 · 녹인 치즈 — 그날의 규칙이 켜져 있을 때만 섞인다
	for i in mid.size():
		var id2 := String(mid[i])
		if bool(c.get("sauce2", false)) and cat(id2) == "sauce" and rng.randf() < 0.35:
			mid[i] = id2 + "+"
		elif bool(c.get("melt", false)) and cat(id2) == "cheese" and i > 0 and cat(String(mid[i - 1])) == "patty" and rng.randf() < 0.6:
			mid[i] = id2 + "~"
	var out: Array = [bun]
	out.append_array(mid)
	out.append(bun)
	return out


## 버거 값(팁 빼고).
static func value(order: Array) -> int:
	var v := BASE_PAY
	for i in order.size() - 1:   # 위 빵은 아래 빵 값에 들어 있다
		v += price(String(order[i]))
	return v
