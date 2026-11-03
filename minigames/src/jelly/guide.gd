class_name Guide
extends RefCounted

## 장애물 도감 — 장애물 · 장치 · 몬스터를 그림 + 설명 두 줄로 보여 준다.
## 처음 나오는 스테이지는 **지도에서 센다**(`first`). 손으로 적으면 스테이지를 고칠 때 어긋난다.
##
## 새 장애물을 넣으면 여기 한 줄 + `icon()` 에 case 하나. 빠뜨리면 도감에 없는 장애물이 된다.
## 설명 글에 `·` `—` `×` `→` 를 쓰지 마세요(Jua 에 없음).
##   sym   = 지도 rows 에서 찾을 기호들     layer = 덧붙는 층 이름     goal = 미션 종류

const PER_PAGE := 7

const ENTRIES := [
	{"key": "sugar", "name": "설탕막", "layer": "floor", "goal": "sugar",
		"lines": ["젤리 밑 바닥에 깔린 막이에요(1~3겹).", "그 위에서 젤리를 터뜨리면 한 겹씩 벗겨져요."]},
	{"key": "box", "name": "쿠키 상자", "sym": "123",
		"lines": ["칸을 막는 상자예요(1~3겹).", "옆에서 터뜨리거나 특수 젤리로 한 겹씩 부숴요."]},
	{"key": "choco", "name": "초콜릿", "sym": "c",
		"lines": ["한 턴에 하나도 못 부수면 옆 젤리로 번져요.", "옆에서 터뜨리거나 특수 젤리로 치워요."]},
	{"key": "ice", "name": "얼음", "sym": "iI",
		"lines": ["갇힌 젤리는 맞출 수도 옮길 수도 없어요.", "옆에서 터뜨리거나 특수 젤리로 깨요(1~2겹)."]},
	{"key": "chain", "name": "사슬", "sym": "l",
		"lines": ["묶인 젤리는 바꿀 수 없어요(떨어지기는 해요).", "그 젤리를 맞추거나 특수 젤리로 맞혀 풀어요."]},
	{"key": "fruit", "name": "열매", "sym": "f",
		"lines": ["맞춰지지 않고 젤리처럼 떨어져요.", "맨 아래 칸까지 내려보내면 모아져요."]},
	{"key": "dough", "name": "꾸덕이", "sym": "D",
		"lines": ["체력 8. 3턴마다 옆 젤리를 쿠키 상자로 굳혀요.", "붉게 표시된 칸을 미리 바꿔 두면 막아요."]},
	{"key": "knot", "name": "매듭이", "sym": "K",
		"lines": ["체력 10. 4턴마다 자기 줄 젤리 넷을", "사슬로 묶어요. 옆에서 터뜨려 체력을 깎아요."]},
	{"key": "thief", "name": "슬쩍이", "sym": "T",
		"lines": ["체력 8. 3턴마다 이동을 하나 훔쳐 가요.", "쓰러뜨리면 훔친 이동을 돌려받아요."]},
	{"key": "belt", "name": "컨베이어 벨트", "layer": "belt",
		"lines": ["턴이 끝날 때마다 벨트 위 조각이", "화살표 방향으로 한 칸씩 움직여요."]},
	{"key": "portal", "name": "포탈", "layer": "portal",
		"lines": ["입구로 떨어진 조각이", "같은 색 출구 위에서 나와요."]},
	{"key": "gear", "name": "톱니바퀴", "sym": "Gg",
		"lines": ["턴 끝마다 둘레 조각을 한 칸씩 돌려요.", "눌러서 방향을 바꿔요(이동은 안 써요)."]},
	{"key": "wind", "name": "바람개비", "sym": "W",
		"lines": ["옆에서 건드리면 턴 끝에", "둘레 두 칸 안의 젤리를 섞어요."]},
	{"key": "push", "name": "푸시 상자", "sym": "><^v",
		"lines": ["턴 끝마다 한 칸 나아가며 앞을 밀어내요.", "막히면 방향을 돌려요."]},
	{"key": "field", "name": "자기장", "layer": "field",
		"lines": ["줄 폭탄 광선이 이 앞에서 멈춰요.", "광선으로 저 너머를 칠 수 없어요."]},
	{"key": "pipe", "name": "파이프", "layer": "pipe",
		"lines": ["칸을 차지해서 젤리가 못 들어가요.", "줄 폭탄 광선이 이 칸에서 꺾여 돌아 나가요."]},
	{"key": "capsule", "name": "캡슐", "sym": "O",
		"lines": ["옆에서 터져도 끄떡없어요.", "특수 젤리 효과로만 깨져요."]},
	{"key": "laser", "name": "레이저 포대", "sym": "Z",
		"lines": ["옆에서 세 번 터지면 턴 끝에", "정해진 방향으로 광선을 쏴요."]},
	{"key": "rocket", "name": "드릴 로켓", "sym": "R",
		"lines": ["자기 색 젤리가 옆에서 터지면", "턴 끝에 날아가며 그 줄을 뚫어요."]},
	{"key": "frost", "name": "얼음뿔", "sym": "F",
		"lines": ["체력 10. 3턴마다 옆 젤리 하나를 얼려요.", "붉게 표시된 칸을 미리 바꿔 두면 막아요."]},
	{"key": "lock", "name": "숫자 자물쇠", "sym": "X",
		"lines": ["그 색 젤리를 판 어디서든", "적힌 수만큼 터뜨리면 열려요."]},
	{"key": "csugar", "name": "색 설탕막", "layer": "csugar",
		"lines": ["그 색 젤리를 위에서 터뜨리거나", "특수 효과로 맞혀야만 벗겨져요."]},
	{"key": "glass", "name": "유리 상자", "sym": "qQ",
		"lines": ["안의 젤리를 가둬요.", "깨지면 안에 든 특수 젤리가 그대로 풀려나요."]},
	{"key": "gift", "name": "선물 상자", "sym": "P",
		"lines": ["맞으면 열려요. 특수 젤리나 이동 +1,", "가끔은 꽝(쿠키 상자)이 나와요."]},
	{"key": "cloud", "name": "구름", "layer": "cloud",
		"lines": ["칸을 가려요. 그 칸이 터지거나", "특수 효과에 맞아야 걷혀요."]},
	{"key": "steam", "name": "증기 기계", "sym": "S",
		"lines": ["3턴마다 옆 칸에 구름을 뿜어요.", "부서지지 않아요."]},
	{"key": "dice", "name": "주사위 젤리", "sym": "d",
		"lines": ["턴마다 색이 바뀌어요.", "바뀌기 전에 맞춰 버리세요."]},
	{"key": "ninja", "name": "그림자", "sym": "N",
		"lines": ["체력 14. 3턴마다 젤리를 분신으로 바꿔요.", "분신은 한 대 맞으면 사라져요."]},
	{"key": "glutton", "name": "먹보", "sym": "E",
		"lines": ["체력 14. 2턴마다 옆 젤리를 먹고 회복해요.", "특수 젤리를 먹이면 5만큼 다쳐요."]},
	{"key": "web", "name": "거미줄", "layer": "web",
		"lines": ["1겹은 바꾸기만 막고 2겹은 붙들어요.", "못 푼 턴엔 번져요. 맞추거나 옆에서 터뜨려요."]},
	{"key": "plant", "name": "끈끈이 식물", "sym": "p",
		"lines": ["건드리면 사라지며", "둘레 여덟 칸에 거미줄을 쳐요."]},
	{"key": "steel", "name": "강철 젤리", "sym": "s",
		"lines": ["그 색으로 줄에 끼지만", "움직이지도 터지지도 않아요."]},
	{"key": "mole", "name": "두더지", "sym": "M",
		"lines": ["체력 3. 한 턴에 한 대만 맞고", "맞은 턴 끝에 다른 자리로 도망가요."]},
	{"key": "rise", "name": "솟는 줄", "layer": "rise",
		"lines": ["이 세로줄이 턴마다", "한 칸씩 위로 돌아요."]},
	{"key": "campfire", "name": "모닥불", "sym": "U",
		"lines": ["옆에서 터지면 2턴 동안 켜져요.", "전부 한꺼번에 켜야 미션 완료예요."]},
	{"key": "paint", "name": "물감", "layer": "paint", "goal": "paint",
		"lines": ["칠한 칸에 닿게 맞추거나 폭탄을 터뜨리면", "그 칸이 칠해져요. 판 전체를 칠하면 완료예요."]},
	{"key": "jar", "name": "색 그릇", "sym": "J",
		"lines": ["둘레 두 칸 안에서 그 색이 터지면 차요.", "가득 채우면 완료예요."]},
	{"key": "octo", "name": "문어발", "sym": "H",
		"lines": ["체력 14. 2턴마다 근처 젤리 둘을", "거미줄 두 겹으로 붙들어요."]},
	{"key": "boss", "name": "대왕꾸덕", "sym": "Y",
		"lines": ["체력 24. 4턴마다 근처 젤리를", "새끼 꾸덕이(체력 4)로 바꿔요."]},
]

const MONSTERS := ["dough", "knot", "thief", "frost", "ninja", "glutton", "octo", "boss"]

static var _order: Array = []
static var _first := {}


## 처음 나오는 스테이지 순서로 늘어놓은 목록 — 플레이어가 만나는 순서와 같다.
static func entries() -> Array:
	if _order.is_empty():
		for e in ENTRIES:
			_first[e.key] = _find_first(e)
		_order = ENTRIES.duplicate()
		_order.sort_custom(func(a, b): return _first[a.key] < _first[b.key])
	return _order


## 그 장애물이 처음 나오는 스테이지 번호(1부터). 지도에 없으면 0.
static func first(key: String) -> int:
	entries()
	return int(_first.get(key, 0))


static func pages(list: Array) -> int:
	return maxi(1, ceili(list.size() / float(PER_PAGE)))


## 이 스테이지에 나오는 것만 — 게임 중 "장애물" 단추가 보여 주는 목록.
static func in_stage(st: Dictionary) -> Array:
	return entries().filter(func(e): return _has(e, st))


static func _find_first(e: Dictionary) -> int:
	var all := Stages.all()
	for n in all.size():
		if _has(e, all[n]):
			return n + 1
	return 0


static func _has(e: Dictionary, st: Dictionary) -> bool:
	var sym := String(e.get("sym", ""))
	if sym != "":
		for row in st.rows:
			for ch in String(row):
				if sym.contains(ch):
					return true
	var ly := String(e.get("layer", ""))
	if ly != "" and st.has(ly):
		var v = st[ly]
		if v is Array and not v.is_empty() and not (v[0] is String):
			return true   # rise — 세로줄 번호 배열
		if v is Dictionary and not v.is_empty():
			return true
		if v is Array:
			for row in v:
				for ch in String(row):
					if ch != ".":
						return true
	for g in st.goals:
		if g.type == e.get("goal", "-"):
			return true
	return false


## 도감 칸 하나의 그림 — 판에 그리는 것과 같은 Art 함수를 쓴다(따로 그리면 판과 달라 보인다).
static func icon(ci: CanvasItem, key: String, pos: Vector2, r: float, t: float) -> void:
	var cell := Rect2(pos - Vector2(r, r) * 1.19, Vector2(r, r) * 2.38)
	# 판처럼 진한 바탕 — 흰 창 위에 바로 그리면 캡슐의 흰 반쪽 같은 밝은 부분이 묻힌다
	G2.panel(ci, cell, Color8(150, 120, 205), Color(), 0.0, cell.size.x * 0.18)
	Art.cell_bg(ci, cell, true)
	if key in MONSTERS:
		Art.monster(ci, pos, r * 1.05, key, 1.0, t, 0.0, false)
		return
	match key:
		"sugar":
			Art.sugar(ci, cell, 2)
			_jelly(ci, pos, r, 0, t)
		"box":
			Art.box(ci, pos, r, 2, 0.0)
		"choco":
			Art.choco(ci, pos, r, t)
		"ice":
			_jelly(ci, pos, r, 4, t)
			Art.ice(ci, pos, r, 1)
		"chain":
			_jelly(ci, pos, r, 1, t)
			Art.chain(ci, pos, r)
		"fruit":
			Art.fruit(ci, pos, r, t)
		"belt":
			Art.belt(ci, cell, 2, t)
		"portal":
			Art.portal_mark(ci, cell, 0, true, t)
			Art.portal_mark(ci, cell, 0, false, t)
		"gear":
			Art.gear(ci, pos, r, 1, t, 0.0)
		"wind":
			Art.wind(ci, pos, r, t, false)
		"push":
			Art.push(ci, pos, r, Vector2i.RIGHT)
		"field":
			Art.field(ci, cell, t)
			Art.field_top(ci, cell, t)
		"pipe":
			Art.pipe(ci, cell, 1)
		"capsule":
			Art.capsule(ci, pos, r, t)
		"laser":
			Art.laser(ci, pos, r, Vector2i.RIGHT, 1, t, 0.0)
		"rocket":
			Art.rocket(ci, pos, r, Vector2i.RIGHT, 0, false, t)
		"lock":
			Art.lock(ci, pos, r, 0, Play.LOCK_N, 0.0)
		"csugar":
			Art.csugar(ci, cell, 2)
			_jelly(ci, pos, r, 2, t)
		"glass":
			_jelly(ci, pos, r, 3, t)
			Art.glass(ci, pos, r, t)
		"gift":
			Art.gift(ci, pos, r, t, 0.0)
		"cloud":
			Art.cloud(ci, pos, r, t)
		"steam":
			Art.steam(ci, pos, r, t, 2)
		"dice":
			_jelly(ci, pos, r, int(t) % 5, t)
			Art.dice_mark(ci, pos, r)
		"web":
			_jelly(ci, pos, r, 5, t)
			Art.web(ci, pos, r, 1)
		"plant":
			Art.plant(ci, pos, r, t)
		"steel":
			_jelly(ci, pos, r, 2, t)
			Art.steel_mark(ci, pos, r)
		"mole":
			Art.mole(ci, pos, r, 3, t, 0.0)
		"rise":
			Art.rise_col(ci, cell, t)
			_jelly(ci, pos, r, 3, t)
		"campfire":
			Art.campfire(ci, pos, r, 1, t)
		"paint":
			Art.paint(ci, cell)
			_jelly(ci, pos, r, 1, t)
		"jar":
			Art.jar(ci, pos, r, 0, Play.JAR_N / 2, Play.JAR_N)


static func _jelly(ci: CanvasItem, pos: Vector2, r: float, c: int, t: float) -> void:
	Art.jelly(ci, pos, r, c, D.SP_NONE, Art.Face.IDLE, Vector2.ZERO, false, Vector2.ONE, 0.0, 0.0, t)


# ==================== 좋은 젤리 도감 ====================

## 특수 젤리 다섯과 특수끼리 맞바꿨을 때의 조합. `sp` = 그림에 늘어놓을 특수 젤리(하나 또는 둘).
## 조합 효과를 바꾸면(`Play._combo`) 여기 설명도 같이 고치세요 — 화면에 그대로 나갑니다.
const SPECIALS := [
	{"key": "sp_line_h", "name": "줄 폭탄 (가로)", "sp": [D.SP_LINE_H],
		"lines": ["젤리 4개를 가로로 이으면 생겨요.", "터지면 그 가로줄을 통째로 쓸어요."]},
	{"key": "sp_line_v", "name": "줄 폭탄 (세로)", "sp": [D.SP_LINE_V],
		"lines": ["젤리 4개를 세로로 이으면 생겨요.", "터지면 그 세로줄을 통째로 쓸어요."]},
	{"key": "sp_area", "name": "범위 폭탄", "sp": [D.SP_AREA],
		"lines": ["가로와 세로를 L자나 T자로 이으면 생겨요.", "터지면 둘레 한 칸(3x3)을 날려요."]},
	{"key": "sp_fly", "name": "날개 젤리", "sp": [D.SP_FLY],
		"lines": ["같은 젤리 넷을 2x2 네모로 모으면 생겨요.", "날아가서 장애물이나 몬스터부터 쳐요."]},
	{"key": "sp_rainbow", "name": "무지개 젤리", "sp": [D.SP_RAINBOW],
		"lines": ["젤리 5개를 한 줄로 이으면 생겨요.", "옆 젤리와 바꾸면 그 색을 판에서 전부 지워요."]},
	{"key": "c_cross", "name": "십자 폭발", "sp": [D.SP_LINE_H, D.SP_LINE_V],
		"lines": ["줄 폭탄 둘을 맞바꾸면", "가로 한 줄과 세로 한 줄을 십자로 쓸어요."]},
	{"key": "c_bigcross", "name": "굵은 십자", "sp": [D.SP_LINE_H, D.SP_AREA],
		"lines": ["줄 폭탄과 범위 폭탄을 맞바꾸면", "세 줄 굵기의 십자로 쓸어요."]},
	{"key": "c_big", "name": "큰 폭발", "sp": [D.SP_AREA, D.SP_AREA],
		"lines": ["범위 폭탄 둘을 맞바꾸면", "둘레 두 칸(5x5)을 한꺼번에 날려요."]},
	{"key": "c_fly2", "name": "날개 셋", "sp": [D.SP_FLY, D.SP_FLY],
		"lines": ["날개 젤리 둘을 맞바꾸면", "날개가 하나 더 생겨 셋이 날아가요."]},
	{"key": "c_carry", "name": "날개 싣기", "sp": [D.SP_FLY, D.SP_AREA],
		"lines": ["날개 젤리를 줄 폭탄이나 범위 폭탄과 바꾸면", "그 폭탄을 싣고 날아가 그 자리에서 터뜨려요."]},
	{"key": "c_rainbow_sp", "name": "무지개 변신", "sp": [D.SP_RAINBOW, D.SP_LINE_V],
		"lines": ["무지개와 특수 젤리를 맞바꾸면 그 색 젤리가", "전부 같은 특수 젤리로 바뀌어 한꺼번에 터져요."]},
	{"key": "c_rainbow2", "name": "판 청소", "sp": [D.SP_RAINBOW, D.SP_RAINBOW],
		"lines": ["무지개 둘을 맞바꾸면", "판 위의 젤리를 전부 터뜨려요."]},
]


## 도감 한 줄의 그림 — 특수 젤리 항목이면 젤리를, 아니면 장애물 그림을.
static func icon_entry(ci: CanvasItem, e: Dictionary, pos: Vector2, r: float, t: float) -> void:
	if not e.has("sp"):
		icon(ci, e.key, pos, r, t)
		return
	var cell := Rect2(pos - Vector2(r, r) * 1.19, Vector2(r, r) * 2.38)
	G2.panel(ci, cell, Color8(150, 120, 205), Color(), 0.0, cell.size.x * 0.18)
	Art.cell_bg(ci, cell, true)
	var sps: Array = e.sp
	if sps.size() == 1:
		Art.jelly(ci, pos, r, 0, sps[0], Art.Face.HAPPY, Vector2.ZERO, false, Vector2.ONE, 0.0, 0.0, t)
		return
	# 조합 — 두 젤리를 나란히. 겹치면 앞 젤리가 뒤 젤리의 표시(줄무늬 · 날개)를 가려 무엇끼리인지 안 읽힌다
	var rr := r * 0.56
	for k in 2:
		Art.jelly(ci, pos + Vector2((k * 2 - 1) * r * 0.6, 0), rr, [0, 4][k], sps[k], Art.Face.HAPPY, Vector2.ZERO,
				false, Vector2.ONE, 0.0, 0.0, t + k)
