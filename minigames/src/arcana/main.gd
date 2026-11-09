extends Node2D
## 아르카나 컬렉션 — 진입점(허브가 자식으로 연다). 화면 배치 · 입력 · 그리기.
##
## 규칙은 전부 [AcGame], 상대 수는 [AcAi] 에 있고 여기는 **보여 주고 클릭을 행동으로 바꾸기만** 합니다.
## 화면: 처음(TITLE) → 판(PLAY) → 결과 창(END, 판 위에 겹침) · 규칙(RULES).
## **자리 함수(`_*_rect`)를 그리기와 클릭이 같이 봅니다** — 키만 되고 마우스가 안 되는 화면을 만들지 않으려고.
## 가로(1280×720)는 왼쪽 단(위 상대 · 아래 내 수집판) · 가운데 판 · 오른쪽 자원과 행동,
## 세로(720×1280)는 위 상대 한 줄 → 영웅 → 판 → 자원 → 단추 → 맨 아래 내 수집판.
## **내가 모은 것이 보여야 합니다**(사용자 요청 11-08 — "맞고처럼 카드를 모으는 게 부각됐으면"). 산 성물은 판에서 내 수집판의
## 같은 색 더미로 날아가 겹쳐 쌓이고(`cfx`), 찾아온 영웅도 판에서 날아와 수집판 위에 앉습니다(`hfx`). 점수 숫자만 올리지 마세요.
##
## **화면 글자에 `·` `—` `×` `→` 를 쓰지 마세요**(Jua 에 없어 웹에서 네모).

enum Scr { TITLE, PLAY, RULES }

const AI_DELAY := 1.0          ## 상대가 두기 전 뜸(사람이 무엇을 했는지 보게)
const FLY_T := 0.45
const CARD_T := 0.65           ## 성물 · 영웅이 수집판으로 날아가는 시간
const APPEAR_T := 0.3          ## 빈자리에 새 성물이 펼쳐지는 시간(날아가는 동안은 빈자리)
const REVEAL_ME := 2.4         ## 내 영웅 등장 연출 길이(누르면 넘어감)
const REVEAL_AI := 1.5         ## 상대 영웅 등장 연출 길이

var scr := Scr.TITLE
var vs := Vector2(1280, 720)
var t := 0.0
var g: AcGame = null
var opp := 1
var sel_tok: Array = []        ## 고른 자원(가운데 토큰)
var sel := {}                  ## 고른 성물 {src: "row" · "deck" · "res", tier, idx}
var ai_t := 0.0
var fx: Array = []             ## 날아가는 토큰 {a, b, col, t}
var cfx: Array = []            ## 날아가는 성물 {card, a: Rect2, b: Rect2, t} — 도착 전에는 수집판에서 그 카드를 안 그린다
var hfx: Array = []            ## 날아가는 영웅 {hero, a: Rect2, b: Rect2, t}
var appear: Array = []         ## 판에 새로 깔리는 성물 {tier, idx, t}
var reveals: Array = []        ## 영웅 등장(카드 뽑기처럼 큰 화면) {hero, p, t} — 앞의 것부터 하나씩. 떠 있는 동안 판이 멈춘다
var pops: Array = []           ## 떠오르는 글 {p, txt, col, t}
var toast := ""
var toast_t := 0.0
var modal := ""                ## "" · "quit"
var end_open := false
var end_t := 0.0
var saved := false
var no_save := false
var mouse := Vector2(-999, -999)

# 확인용 실행
var shot_path := ""
var shot_at: Array = []
var _shot_i := 0
var ac_auto := false
var click_test := false
var _ct := 0.0
var _cs := 0
var ac_seed := -1
var book := UiBook.new()      ## 처음 화면의 도감 · 순위 창
var ac_reveal := false        ## --ac-reveal: 시작하자마자 첫 영웅 조건을 채워 영웅 등장 연출을 본다(캡처용)


func _ready() -> void:
	Bgm.use("arcana")
	AcSnd.init(Hub.host(self))
	AcSv.load_()
	opp = AcSv.opp
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--shot-at="):
			for s in a.substr(10).split(","):
				shot_at.append(float(s))
		elif a == "--ac-auto":
			ac_auto = true
		elif a == "--ac-click-test":
			click_test = true
		elif a.begins_with("--ac-opp="):
			opp = clampi(int(a.substr(9)), 1, 3)
		elif a.begins_with("--ac-seed="):
			ac_seed = int(a.substr(10))
		elif a == "--ac-rules":
			scr = Scr.RULES
		elif a == "--ac-reveal":
			ac_reveal = true
		elif a.begins_with("--menu="):   # 확인용 — 처음 화면 N번 메뉴(도감 · 순위)를 바로 연다
			_menu.call_deferred(int(a.substr(7)))
	no_save = ac_auto or click_test or shot_path != "" or ac_reveal
	if ac_reveal:
		_start.call_deferred()
	if click_test and ac_seed < 0:
		ac_seed = 11
	if ac_auto:
		_start.call_deferred()


func _start() -> void:
	var ai := [ac_auto, true, true, true]
	g = AcGame.new(opp + 1, ac_seed, ai)
	scr = Scr.PLAY
	sel_tok = []
	sel = {}
	fx = []
	pops = []
	cfx = []
	hfx = []
	appear = []
	end_open = false
	saved = false
	ai_t = 0.0
	toast = "내 차례부터 시작합니다" if not ac_auto else ""
	toast_t = 2.5
	if not no_save:
		AcSv.opp = opp
		AcSv.save_()
	AcSnd.play("chip")
	if ac_reveal:
		# 첫 영웅의 조건만큼 1단계 성물을 더미에서 꺼내 내 것으로 — 그리고 차례를 넘기면 영웅이 온다
		var h: Dictionary = g.heroes[0]
		for c in h.need:
			var left := int(h.need[c])
			for card in g.decks[0].duplicate():
				if left > 0 and int(card.col) == int(c):
					g.decks[0].erase(card)
					g.players[0].cards.append(card)
					left -= 1
		g.pass_turn()
		_after_action()


func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	t += dt
	vs = get_viewport_rect().size
	toast_t = maxf(0.0, toast_t - dt)
	for f: Dictionary in fx:
		f.t += dt
	fx = fx.filter(func(f): return f.t < FLY_T)
	for p: Dictionary in pops:
		p.t += dt
	pops = pops.filter(func(p): return p.t < 1.4)
	for arr: Array in [cfx, hfx, appear]:
		for f: Dictionary in arr:
			f.t += dt
	if not reveals.is_empty():
		var rv: Dictionary = reveals[0]
		var before := float(rv.t)
		rv.t += dt
		if before < 0.5 and float(rv.t) >= 0.5:
			AcSnd.play("hero")   # 뒤집히는 순간
		if float(rv.t) >= _reveal_dur(rv):
			_finish_reveal()
	cfx = cfx.filter(func(f): return f.t < CARD_T)
	hfx = hfx.filter(func(f): return f.t < CARD_T)
	appear = appear.filter(func(f): return f.t < APPEAR_T)
	if scr == Scr.PLAY and g != null:
		if not reveals.is_empty():
			pass   # 영웅 등장이 떠 있는 동안은 판이 멈춘다(상대도 안 둔다)
		elif g.over:
			if not end_open:
				end_t += dt
				if end_t > 1.2:
					_open_end()
		elif _ai_turn():
			ai_t += dt
			if ai_t >= (0.25 if ac_auto else AI_DELAY):
				ai_t = 0.0
				AcAi.act(g)
				_after_action()
		elif g.cur == 0 and g.pending == "" and not g.can_act():
			# 사람이 할 수 있는 것이 없다 — 넘기기 단추를 보여 준다(그리기 쪽)
			pass
	if click_test:
		_click_test_step(dt)
	if shot_path != "" and _shot_i < shot_at.size() and t >= float(shot_at[_shot_i]):
		var path := shot_path
		if shot_at.size() > 1:
			path = shot_path.get_basename() + "_%d.png" % _shot_i
		get_viewport().get_texture().get_image().save_png(path)
		_shot_i += 1
		if _shot_i >= shot_at.size() and not click_test:   # 클릭 검사는 자기가 끝낸다
			get_tree().quit()
	queue_redraw()


func _ai_turn() -> bool:
	return g != null and not g.over and bool(g.players[g.cur].ai)


func _my_turn() -> bool:
	return g != null and not g.over and g.cur == 0 and not bool(g.players[0].ai) and modal == "" and not end_open \
			and reveals.is_empty()


func _reveal_dur(rv: Dictionary) -> float:
	return REVEAL_ME if int(rv.p) == 0 and not ac_auto else REVEAL_AI


## 영웅 등장 연출의 카드 자리 — 화면 가운데, 처음엔 작게 커지며 나온다.
func _reveal_rect(rv: Dictionary) -> Rect2:
	var h := minf(vs.y * 0.6, 430.0)   # 영웅 카드 비율(성물과 같음)
	var k := G2.out_back(clampf(float(rv.t) / 0.3, 0.0, 1.0))
	var sz := Vector2(h * 106.0 / 150.0, h) * lerpf(0.25, 1.0, k)
	return Rect2(vs * 0.5 + Vector2(0, -10) - sz * 0.5, sz)


## 등장을 마치고 그 사람 수집판으로 날려 보낸다.
func _finish_reveal() -> void:
	var rv: Dictionary = reveals.pop_front()
	var p: int = rv.p
	var j := 0
	var hs: Array = g.players[p].heroes
	for k in hs.size():
		if hs[k].id == rv.hero.id:
			j = k
	var hb := _hchip_rect(p, j)
	var full := rv.duplicate()
	full.t = 99.0
	hfx.append({hero = rv.hero, a = _reveal_rect(full), b = hb, t = 0.0})
	pops.append({p = hb.get_center() + Vector2(60, -10), txt = "%s +3점" % String(rv.hero.name), col = Color8(255, 200, 255), t = -0.3})


## 행동 하나가 끝난 뒤 — 소리 · 날아가는 토큰 · 떠오르는 글.
func _after_action() -> void:
	var l := g.last
	var p: int = l.get("p", 0)
	var pc := _player_rect(p).get_center()
	match String(l.get("kind", "")):
		"take":
			for k in l.cols.size():
				var c: int = l.cols[k]
				fx.append({a = _bank_rect(c).get_center(), b = _ptok_rect(p, c).get_center(), col = c, t = -k * 0.08})
			AcSnd.play("chip", 1.0 + randf() * 0.1)
		"buy":
			var pay: Array = l.pay
			var n := 0
			for c in 6:
				for j in int(pay[c]):
					fx.append({a = _ptok_rect(p, c).get_center(), b = _bank_rect(c).get_center(), col = c, t = -n * 0.05})
					n += 1
			# 성물이 판(또는 봉인 칸)에서 그 사람 수집판의 같은 색 더미로 날아간다
			var card: Dictionary = l.card
			var from := _card_rect(l.tier, l.idx) if l.src == "row" else (_res_rect(l.idx) if p == 0 else _resicon_rect(p))
			var k2 := int(g.bonus(p)[card.col]) - 1
			cfx.append({card = card, a = from, b = _stack_rect(p, card.col, k2), t = 0.0})
			if l.src == "row":
				appear.append({tier = l.tier, idx = l.idx, t = -FLY_T})
			if int(card.pts) > 0:
				pops.append({p = _stack_rect(p, card.col, k2).get_center() if p == 0 else pc, txt = "+%d점" % int(card.pts),
						col = Color8(255, 220, 110), t = -FLY_T * 0.6})
			AcSnd.play("buy")
		"reserve":
			if l.get("gold", false):
				fx.append({a = _bank_rect(AcD.GOLD).get_center(), b = _ptok_rect(p, AcD.GOLD).get_center(), col = AcD.GOLD, t = 0.0})
			var to := _res_rect(g.players[0].reserved.size() - 1) if p == 0 else _resicon_rect(p)
			cfx.append({card = l.card, a = _card_rect(l.tier, l.idx), b = to, t = 0.0, back = l.blind and p != 0})
			if not l.blind:
				appear.append({tier = l.tier, idx = l.idx, t = -FLY_T})
			AcSnd.play("seal")
	if l.has("hero"):
		# 카드 뽑기처럼 — 가운데 큰 화면에서 뒤집혀 나타난 뒤 수집판으로(_finish_reveal)
		reveals.append({hero = l.hero, p = p, t = 0.0})
		AcSnd.play("seal")
	if not g.events.is_empty():
		var e: Dictionary = g.events[-1]
		toast = "%s: %s" % [AcD.PLAYER_NAMES[int(e.p)], String(e.txt)]
		toast_t = 3.0
	sel_tok = []
	sel = {}
	if g.over:
		end_t = 0.0


func _open_end() -> void:
	end_open = true
	if not saved and not no_save and not bool(g.players[0].ai):
		AcSv.add(g)
	saved = true
	AcSnd.play("win" if g.winner == 0 else "lose")

# ==================== 자리 ====================


func wide() -> bool:
	return vs.x > vs.y


## 왼쪽 위 — 처음 화면은 "게임 선택", 판에서는 "나가기"(같은 자리 · `Hub.std_rect`).
func _back_btn() -> Rect2:
	return Hub.std_rect("hub", vs)


func _vol_btn() -> Rect2:
	return Hub.std_rect("vol", vs)


## 세로 화면에서 위쪽 상대 줄이 끝나는 곳(가로는 0).
func _players_end() -> float:
	return 0.0 if wide() else 196.0


const OPP_H := 64.0    ## 가로 화면의 상대 판 높이 — 두 줄짜리 얇은 띠(4인에서도 내 수집판이 제 크기로 들어가게, 사용자 지적 11-08)


## 플레이어 판. 0 = 나(큰 수집판), 1~ = 상대(작은 판).
func _player_rect(i: int) -> Rect2:
	var n := g.n if g != null else 2
	if wide():
		if i > 0:
			return Rect2(16, 72 + (i - 1) * (OPP_H + 6.0), 290, OPP_H)
		var y := 72.0 + (n - 1) * (OPP_H + 6.0)
		return Rect2(16, y, 290, vs.y - 12.0 - y)
	if i > 0:
		var w := (vs.x - 32.0 - (n - 2) * 8.0) / (n - 1)
		return Rect2(16 + (i - 1) * (w + 8.0), 70, w, 120)
	var top := _act_area().end.y + 8.0
	return Rect2(16, top, vs.x - 32.0, vs.y - 8.0 - top)


## 내 수집판에서 색 col 묶음의 k 번째 카드(0 = 맨 왼쪽). 상대는 그 색 묶음 표시 하나.
## **같은 색끼리 묶어 옆으로 반씩 겹칩니다**(사용자 요청 11-08 — "맞고처럼 카드의 절반만 보이게 같은 카드끼리 뭉쳐서").
## 묶음 다섯은 두 칸씩 세 줄(화염 · 물 / 숲 · 빛 / 그림자). 묶음이 칸보다 길어지면 겹침을 더 좁힌다.
func _stack_rect(i: int, col: int, k: int) -> Rect2:
	var pr := _player_rect(i)
	if i > 0:
		# 상대 띠 아랫줄 — 색마다 [성물 수 네모][토큰 동그라미]
		var cw := (pr.size.x - 16.0) / 6.0
		return Rect2(pr.position.x + 8.0 + cw * col + 2.0, pr.position.y + 35.0, 20, 22)
	var cell := _group_rect(col)
	var cs := _mini_size()
	var n := maxi(1, int(g.bonus(0)[col])) if g != null else 1
	var step := minf(cs.x * 0.5, (cell.size.x - 8.0 - cs.x) / maxf(1.0, n - 1.0))
	return Rect2(cell.position.x + 4.0 + k * step, cell.position.y + (cell.size.y - cs.y) * 0.5, cs.x, cs.y)


## 수집판 한 줄 높이 — 영웅 줄 하나 + 색 다섯 줄. 넉넉하면 여섯 줄, 모자라면(상대 셋) 영웅 줄 + 두 칸씩 세 줄.
func _row_h() -> float:
	var a := _collect_area()
	return a.size.y / 6.0 if a.size.y / 6.0 >= 56.0 else a.size.y / 4.0


## 수집판 축소 카드 크기 — 성물 · 영웅 같은 크기(판의 카드와 같은 비율 — 진짜 축소판).
func _mini_size() -> Vector2:
	var h := minf(_row_h() - 6.0, 76.0)
	return Vector2(h * 106.0 / 150.0, h)


## 내 수집판에서 영웅 줄 · 성물 줄들이 놓이는 칸 전체.
func _collect_area() -> Rect2:
	var pr := _player_rect(0)
	if wide():
		return Rect2(pr.position.x + 6, pr.position.y + 40, pr.size.x - 12, pr.size.y - 40 - 56)
	return Rect2(pr.position.x + 6, pr.position.y + 38, 320, pr.size.y - 38 - 52)


## 맨 위 영웅 줄 — 특별한 띠(금테)로 성물 줄과 가른다.
func _hero_row() -> Rect2:
	var a := _collect_area()
	return Rect2(a.position, Vector2(a.size.x, _row_h()))


## 색 col 묶음이 차지하는 칸. 여섯 줄 모드면 한 색 한 줄, 아니면 두 칸씩 세 줄.
func _group_rect(col: int) -> Rect2:
	var area := _stack_area()
	var rh := _row_h()
	if _collect_area().size.y / 6.0 >= 56.0:
		return Rect2(area.position.x, area.position.y + col * rh, area.size.x, rh)
	var cw := area.size.x / 2.0
	return Rect2(area.position.x + (col % 2) * cw, area.position.y + (col / 2) * rh, cw, rh)


## 내 수집판에서 색별 묶음이 놓이는 칸(영웅 줄 아래).
func _stack_area() -> Rect2:
	var a := _collect_area()
	var rh := _row_h()
	return Rect2(a.position.x, a.position.y + rh, a.size.x, a.size.y - rh)


## 찾아온 영웅 j 의 자리 — 내 것은 영웅 줄에 성물과 같은 크기로 나란히, 상대는 이름 옆 작은 세로 카드.
func _hchip_rect(i: int, j: int) -> Rect2:
	var pr := _player_rect(i)
	if i > 0:
		return Rect2(pr.position.x + 74 + j * 17.0, pr.position.y + 5, 14, 20)
	var hr := _hero_row()
	var cs := _mini_size()
	return Rect2(hr.position.x + 8 + j * (cs.x + 6.0), hr.position.y + (hr.size.y - cs.y) * 0.5, cs.x, cs.y)


func _center_x() -> Vector2:
	## 가로 화면 가운데 단의 [왼쪽, 폭]
	return Vector2(322, 668) if wide() else Vector2(0, vs.x)


## 성물 크기 — 영웅 카드도 같은 크기(가로 화면: 영웅 전당 한 줄 + 성물 세 줄이 화면 높이에 들어가게).
func _card_size() -> Vector2:
	return Vector2(112, 158) if wide() else Vector2(96, 136)


## 영웅 전당 — 판 상자 위, 따로 떨어진 금테 띠(영웅이 판 상자에 걸쳐 있으면 어색하다 — 사용자 지적 11-08).
func _hall_rect() -> Rect2:
	var t0 := _card_rect(2, -1)
	var x1 := _card_rect(0, 3).end.x
	var cs := _card_size()
	return Rect2(t0.position.x - 14, t0.position.y - 12 - 10 - (cs.y + 12), x1 - t0.position.x + 28, cs.y + 12)


## 판 위 영웅 k(영웅 전당 안, 성물과 같은 크기). `n` 은 그때 판에 있던 영웅 수(날아가는 연출이 빠지기 전 자리) — 생략하면 지금 수.
func _hero_rect(k: int, n: int = -1) -> Rect2:
	if n < 0:
		n = g.heroes.size()
	var cs := _card_size()
	var gap := 12.0
	var hall := _hall_rect()
	var x0 := hall.get_center().x - (n * cs.x + (n - 1) * gap) * 0.5
	return Rect2(x0 + k * (cs.x + gap), hall.position.y + 6, cs.x, cs.y)


## 성물 자리 — idx -1 은 더미. 위 줄이 전설(3단계), 아래 줄이 견습(1단계).
func _card_rect(tier: int, idx: int) -> Rect2:
	var cs := _card_size()
	var gap := 12.0
	var cx := _center_x()
	var x0 := cx.x + (cx.y - (5 * cs.x + 4 * gap)) * 0.5
	var y0 := (14.0 + cs.y + 12.0 + 10.0 + 12.0) if wide() else _players_end() + 6.0 + cs.y + 12.0 + 10.0 + 12.0
	return Rect2(x0 + (idx + 1) * (cs.x + gap), y0 + (2 - tier) * (cs.y + 12.0), cs.x, cs.y)


func _cards_end() -> float:
	return _card_rect(0, 0).end.y


func _bank_rect(c: int) -> Rect2:
	var r := 34.0
	var p: Vector2
	if wide():
		p = Vector2(1044 + (c % 3) * 88, 100 + (c / 3) * 80)
	else:
		p = Vector2(vs.x * 0.5 + (c - 2.5) * 112.0, _cards_end() + 46.0)
	return Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0)


## 행동 칸(고른 것 + 단추).
func _act_area() -> Rect2:
	if wide():
		return Rect2(1000, 222, 264, 156)
	return Rect2(16, _bank_rect(0).end.y + 10.0, vs.x - 32.0, 54)


## 행동 단추 k(가로 = 위에서 아래, 세로 = 왼쪽에서 오른쪽 한 줄).
func _act_btn(k: int) -> Rect2:
	var a := _act_area()
	if wide():
		return Rect2(a.position.x + k * 90.0, a.position.y + 46, 84, 50)
	return Rect2(a.position.x + k * 150.0, a.position.y + 1, 140, 52)


## 내가 봉인한 성물 k.
func _res_rect(k: int) -> Rect2:
	if wide():
		return Rect2(1000 + k * 90, 414, 84, 119)
	var pr := _player_rect(0)
	var h := pr.size.y - 66.0
	var w := minf(100.0, h / 1.42)
	return Rect2(pr.position.x + 344 + k * (w + 10.0), pr.position.y + 58, w, w * 1.42)


## 플레이어 판 안의 토큰 c(0~5) — 버리기 클릭 · 날아가는 토큰의 도착점.
func _ptok_rect(i: int, c: int) -> Rect2:
	var pr := _player_rect(i)
	if i > 0:
		var cw := (pr.size.x - 16.0) / 6.0
		var r := 10.0
		var x := pr.position.x + 8.0 + cw * c + (34.0 if c < AcD.N_COL else 14.0)
		return Rect2(Vector2(x, pr.position.y + 46.0) - Vector2(r, r), Vector2(r, r) * 2.0)
	var x0 := pr.position.x + 8.0
	var cw2 := (pr.size.x - 16.0) / 6.0 if wide() else 54.0
	var r2 := minf(20.0, cw2 * 0.42)
	return Rect2(Vector2(x0 + cw2 * (c + 0.5), pr.end.y - 27.0) - Vector2(r2, r2), Vector2(r2, r2) * 2.0)


## 상대 판의 봉인 표시(색별 더미 줄의 여섯째 칸).
func _resicon_rect(i: int) -> Rect2:
	var pr := _player_rect(i)
	return Rect2(pr.end.x - 78, pr.position.y + 5, 18, 22)


## 처음 화면 단추 — 0 시작(오른쪽 아래, 다섯 게임 같은 자리) · 1 규칙 보기(가운데).
func _title_btn(k: int) -> Rect2:
	if k == 0:
		return Hub.std_rect("start", vs)
	var w := 340.0
	var y0 := 290.0 if wide() else vs.y * 0.5 + 120.0
	return Rect2(_menu_x() - w * 0.5, y0, w, 66)


## 처음 화면 오른쪽 메뉴 줄의 가운데 x(다섯 게임 같은 틀 — 왼쪽 제목, 오른쪽 메뉴, 오른쪽 아래 시작).
func _menu_x() -> float:
	return vs.x * 0.72 if wide() else vs.x * 0.5


func _modal_btn(k: int) -> Rect2:
	var c := vs * 0.5
	return Rect2(c.x - 200 + k * 210, c.y + 30, 190, 60)


func _end_btn(k: int) -> Rect2:
	var c := vs * 0.5
	return Rect2(c.x - 200 + k * 210, c.y + 150, 190, 60)

# ==================== 입력 ====================


func _unhandled_input(ev: InputEvent) -> void:
	if Vol.open:
		Vol.handle(ev, vs)
		return
	if ev is InputEventMouseMotion:
		mouse = ev.position
		return
	var key := ev as InputEventKey
	if key != null and key.pressed and not key.echo:
		if book.key(key.keycode):
			return
		match key.keycode:
			KEY_ESCAPE:
				_escape()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if scr == Scr.TITLE:
					_start()
				elif _my_turn() and not sel_tok.is_empty():
					_do_take()
		return
	var mb := ev as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		mouse = mb.position
		_click(mb.position)


func _escape() -> void:
	match scr:
		Scr.TITLE:
			Hub.leave(self)
		Scr.RULES:
			scr = Scr.TITLE
		Scr.PLAY:
			if modal != "":
				modal = ""
			elif not sel.is_empty() or not sel_tok.is_empty():
				sel = {}
				sel_tok = []
			else:
				modal = "quit"


## 처음 화면 메뉴(다섯 게임 같은 구조 — 모드 · 도감 · 도감 · 순위). 0 상대 수(누를 때마다 1 → 2 → 3) · 1 성물 도감 · 2 영웅 도감 · 3 순위.
func _menu(j: int) -> void:
	book.game = "arcana"
	match j:
		0:
			opp = opp % 3 + 1
			if not no_save:
				AcSv.opp = opp
				AcSv.save_()
		1:
			var items := [{name = "규칙", desc = "\n".join(RULES).replace("    ", ""), draw = func(ci, r, tt):
					for k in 3:
						AcArt.token(ci, r.get_center() + Vector2((k - 1) * r.size.x * 0.26, 0), minf(r.size.x, r.size.y) * 0.16, k * 2)}]
			for c: Dictionary in AcD.deck():
				var cc := c
				var cost := []
				for i in AcD.N_COL:
					if int(c.cost[i]) > 0:
						cost.append("%s %d" % [AcD.NAMES[i], int(c.cost[i])])
				items.append({name = String(c.name), desc = "%d점, %s 할인\n비용: %s" % [int(c.pts), AcD.NAMES[c.col], ", ".join(cost)],
						draw = func(ci, r, tt):
							var h: float = r.size.y * 0.96
							var w: float = h * 106.0 / 150.0
							AcArt.card(ci, Rect2(r.get_center() - Vector2(w, h) * 0.5, Vector2(w, h)), cc, 0, tt)})
			book.show("성물 도감", items, "grid", 5, 2)
		2:
			var items2 := []
			for h: Dictionary in AcD.HEROES:
				var hh := h
				var need := []
				var ks: Array = h.need.keys()
				ks.sort()
				for c in ks:
					need.append("%s %d장" % [AcD.NAMES[c], int(h.need[c])])
				items2.append({name = String(h.name), desc = "3점\n성물 %s" % ", ".join(need),
						draw = func(ci, r, tt):
							var hgt: float = r.size.y * 0.96
							var w2: float = hgt * 106.0 / 150.0
							AcArt.hero(ci, Rect2(r.get_center() - Vector2(w2, hgt) * 0.5, Vector2(w2, hgt)), hh, 0, tt)})
			book.show("영웅 도감", items2, "grid", 5, 2)
		3:
			var rows := []
			for k in 3:
				var key := str(k + 1)
				var pl := int(AcSv.plays.get(key, 0))
				var w3 := int(AcSv.wins.get(key, 0))
				rows.append({main = "상대 %d명" % (k + 1), sub = "%d판 %d승%s" % [pl, w3, "  승률 %d%%" % roundi(100.0 * w3 / pl) if pl > 0 else ""]})
			rows.append({main = "최고 점수", sub = "%d점" % AcSv.best if AcSv.best > 0 else "아직 없음"})
			rows.append({main = "가장 빠른 승리", sub = "%d라운드" % AcSv.fastest if AcSv.fastest > 0 else "아직 없음"})
			book.show("순위", rows, "list")


func _click(p: Vector2) -> void:
	if book.click(p, vs):
		return
	match scr:
		Scr.TITLE:
			if _back_btn().has_point(p):
				Hub.leave(self)
				return
			if _vol_btn().has_point(p):
				Vol.open = true
				return
			for j in 4:
				if UiKit.menu_rect(vs, j).has_point(p):
					AcSnd.play("tick")
					_menu(j)
					return
			if _title_btn(0).has_point(p):
				_start()
		Scr.RULES:
			scr = Scr.TITLE
		Scr.PLAY:
			_click_play(p)


func _click_play(p: Vector2) -> void:
	if not reveals.is_empty():
		# 영웅 등장 — 뒤집힌 뒤에 누르면 바로 수집판으로
		if float(reveals[0].t) > 0.6:
			_finish_reveal()
		return
	if end_open:
		if _end_btn(0).has_point(p):
			_start()
		elif _end_btn(1).has_point(p):
			scr = Scr.TITLE
			g = null
		return
	if modal == "quit":
		if _modal_btn(0).has_point(p):
			modal = ""
			scr = Scr.TITLE
			g = null
		elif _modal_btn(1).has_point(p):
			modal = ""
		return
	if _back_btn().has_point(p):
		modal = "quit"
		return
	if not _my_turn():
		return
	# 넘친 토큰 버리기
	if g.pending == "discard":
		for c in 6:
			if _ptok_rect(0, c).grow(6).has_point(p) and g.discard(c):
				fx.append({a = _player_rect(0).get_center(), b = _bank_rect(c).get_center(), col = c, t = 0.0})
				AcSnd.play("tick")
				if g.pending == "":
					_after_action()
				return
		return
	if g.pending == "hero":
		for k in g.heroes.size():
			if k in g.pend_heroes and _hero_rect(k).has_point(p):
				g.pick_hero(k)
				_after_action()
				return
		return
	# 행동 단추
	for k in 3:
		if _act_btn(k).has_point(p) and _act_enabled(k):
			_act(k)
			return
	# 가운데 토큰
	for c in AcD.N_COL:
		if _bank_rect(c).grow(4).has_point(p):
			_toggle_tok(c)
			return
	# 성물 · 더미
	for tier in 3:
		for idx in range(-1, AcD.ROW_N):
			if _card_rect(tier, idx).has_point(p):
				if idx >= 0 and g.rows[tier][idx] == null:
					return
				sel = {src = "deck" if idx < 0 else "row", tier = tier, idx = idx}
				sel_tok = []
				AcSnd.play("tick")
				return
	for k in g.players[0].reserved.size():
		if _res_rect(k).has_point(p):
			sel = {src = "res", tier = -1, idx = k}
			sel_tok = []
			AcSnd.play("tick")
			return
	sel = {}
	sel_tok = []


func _toggle_tok(c: int) -> void:
	sel = {}
	if g.bank[c] <= 0:
		return
	if sel_tok.size() == 2 and sel_tok[0] == sel_tok[1]:
		sel_tok = [] if sel_tok[0] == c else [c]
	elif sel_tok == [c]:
		# 같은 것을 한 번 더 — 둘 가져오기(넷 이상 남았을 때)
		if int(g.bank[c]) >= AcD.TAKE2_MIN:
			sel_tok = [c, c]
		else:
			sel_tok = []
	elif c in sel_tok:
		sel_tok.erase(c)
	elif sel_tok.size() < 3:
		sel_tok.append(c)
	AcSnd.play("tick")


## 지금 보여 줄 단추들 [글, 할 수 있나].
func _acts() -> Array:
	if not _my_turn() or g.pending != "":
		return []
	if not sel_tok.is_empty():
		return [["가져오기", g.can_take(sel_tok)], ["취소", true]]
	if not sel.is_empty():
		var src: String = sel.src
		var buy_ok := src != "deck" and g.can_buy_at("res" if src == "res" else "row", sel.tier, sel.idx)
		var res_ok := src != "res" and g.can_reserve(sel.tier, sel.idx)
		if src == "res":
			return [["갖추기", buy_ok], ["취소", true]]
		if src == "deck":
			return [["봉인", res_ok], ["취소", true]]
		return [["갖추기", buy_ok], ["봉인", res_ok], ["취소", true]]
	if not g.can_act():
		return [["넘기기", true]]
	return []


func _act_enabled(k: int) -> bool:
	var a := _acts()
	return k < a.size() and bool(a[k][1])


func _act(k: int) -> void:
	var a := _acts()
	var label: String = a[k][0]
	match label:
		"가져오기":
			_do_take()
		"갖추기":
			if g.buy("res" if sel.src == "res" else "row", sel.tier, sel.idx):
				_after_action()
		"봉인":
			if g.reserve(sel.tier, sel.idx):
				_after_action()
		"넘기기":
			g.pass_turn()
			_after_action()
		_:
			sel = {}
			sel_tok = []


func _do_take() -> void:
	if g.take(sel_tok):
		_after_action()

# ==================== 그리기 ====================


func _draw() -> void:
	_draw_bg()
	match scr:
		Scr.TITLE:
			_draw_title()
		Scr.RULES:
			_draw_rules()
		Scr.PLAY:
			if g != null:
				_draw_play()
	Vol.draw(self, vs, t)


func _draw_bg() -> void:
	var top := Color8(34, 20, 58)
	var bot := Color8(18, 30, 62)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(vs.x, 0), vs, Vector2(0, vs.y)]),
			PackedColorArray([top, top, bot, bot]))
	for k in 40:
		var p := Vector2(fposmod(k * 197.3, vs.x), fposmod(k * 131.7 + k * k * 3.1, vs.y))
		var a := 0.15 + 0.15 * sin(t * (0.8 + (k % 5) * 0.3) + k)
		draw_circle(p, 1.2 + (k % 3) * 0.6, Color(1, 1, 0.9, a))


## 단추 — 다섯 게임 같은 입체 단추(UiKit). 판의 행동 단추 · 결과 창 · 나가기 창 전부.
func _btn(r: Rect2, label: String, fill: Color, size: float = 28.0, on: bool = true) -> void:
	UiKit.plain(self, r, label, fill, "arcana", t, on, size)


func _draw_title() -> void:
	# 왼쪽 — 제목 · 소개 · 자원 여섯 · 성물 세 장(다섯 게임 같은 틀)
	var lx := vs.x * 0.3 if wide() else vs.x * 0.5
	# 게임 이름 — 다섯 게임 같은 방식(UiKit.title). 자원 여섯은 소개 아래 한 줄
	var below := UiKit.title(self, vs, "arcana", "아르카나 컬렉션", "자원을 모아 성물을 갖추고, 영웅을 불러 모으세요", t)
	for k in 6:
		AcArt.token(self, Vector2(lx + (k - 2.5) * 66.0, below + 40.0 + sin(t * 2.0 + k * 0.9) * 5.0), 22, k)
	if wide():
		var demo := AcD.deck()
		for k in 3:
			var c: Dictionary = demo[[3, 47, 85][k]]
			var cr := Rect2(lx - 190 + k * 132, 340 + absf(k - 1.0) * 18.0 + sin(t * 1.5 + k) * 4.0, 116, 164)
			AcArt.card(self, cr, c, 0, t)
	# 오른쪽 메뉴 — 다섯 게임 같은 구조(모드 · 도감 · 도감 · 순위)
	var labels := ["상대 수: %d명" % opp, "성물 도감", "영웅 도감", "순위"]
	var fills := [Color8(214, 160, 60), Color8(80, 130, 190), Color8(150, 60, 90), Color8(110, 80, 170)]
	for j in 4:
		UiKit.menu(self, UiKit.menu_rect(vs, j), labels[j], fills[j], "arcana", t)
	var key := str(opp)
	var rec := "상대 %d명: %d판 %d승" % [opp, int(AcSv.plays.get(key, 0)), int(AcSv.wins.get(key, 0))]
	UiKit.record_line(self, vs, rec)
	UiKit.button(self, vs, "start", "arcana", t)
	UiKit.button(self, vs, "hub", "arcana", t)
	UiKit.button(self, vs, "vol", "arcana", t)
	book.draw(self, vs, t)


const RULES := [
	"차례마다 셋 중 하나를 합니다.",
	"1. 자원 가져오기: 서로 다른 자원 셋, 또는 같은 자원 둘",
	"    (같은 자원 둘은 그 자원이 넷 이상 남았을 때만)",
	"2. 성물 갖추기: 비용을 내고 성물을 삽니다.",
	"    가진 성물은 그 자원을 하나씩 영원히 깎아 줍니다.",
	"3. 봉인: 성물 하나를 맡아 두고 별가루(만능 자원)를 받습니다.",
	"    셋까지 맡을 수 있고, 더미 맨 위의 것도 봉인할 수 있습니다.",
	"토큰은 열 개까지만 들 수 있고, 넘치면 돌려놓습니다.",
	"성물만으로 영웅의 조건을 채우면 영웅이 찾아옵니다(3점).",
	"누가 15점에 닿으면 그 라운드를 끝까지 돌고,",
	"점수가 가장 높은 사람이 이깁니다. 같으면 성물이 적은 쪽이 이깁니다.",
]


func _draw_rules() -> void:
	var w := minf(vs.x - 40.0, 1000.0)
	var h := 560.0 if wide() else 760.0
	var r := Rect2(vs.x * 0.5 - w * 0.5, vs.y * 0.5 - h * 0.5, w, h)
	AcArt.frame(self, r, Color8(44, 32, 72), Color8(255, 220, 140), 4.0, 26)
	G2.text_mid(self, Vector2(r.get_center().x, r.position.y + 46), "규칙", 44, Color8(255, 226, 150), 10)
	var size := 24.0 if wide() else 21.0
	var step := 40.0 if wide() else 52.0
	for k in RULES.size():
		var s: String = RULES[k]
		draw_string(UiKit.font(), Vector2(r.position.x + 40, r.position.y + 110 + k * step), s,
				HORIZONTAL_ALIGNMENT_LEFT, w - 60, int(size), Color(1, 1, 1, 0.92))
	G2.text_mid(self, Vector2(r.get_center().x, r.end.y - 30), "아무 데나 누르면 돌아갑니다", 22, Color(1, 1, 1, 0.55), 0)


func _draw_play() -> void:
	# 판 바탕
	var cs := _card_rect(2, -1)
	var table := Rect2(cs.position - Vector2(14, 12), Vector2(_card_rect(0, 3).end.x - cs.position.x + 28,
			_cards_end() - cs.position.y + 24))
	AcArt.frame(self, table, Color(0, 0, 0, 0.25), Color(1, 1, 1, 0.12), 2.0, 22)
	# 영웅 전당 — 판 상자와 떨어진 금테 띠, 깊은 남보라 바탕 + 은은한 빛
	var hall := _hall_rect()
	AcArt.frame(self, hall, Color8(34, 22, 60, 235), Color8(240, 200, 100), 2.5, 20)
	AcArt.frame(self, hall.grow(-5), Color(0, 0, 0, 0), Color(1, 0.86, 0.5, 0.35), 1.2, 16)
	draw_circle(hall.get_center(), hall.size.y * 0.55, Color(1, 0.85, 0.5, 0.05 + 0.02 * sin(t * 1.5)))
	var tag := Rect2(hall.position.x + 16, hall.position.y - 13, 112, 28)
	AcArt.frame(self, tag, Color8(150, 40, 60), Color8(240, 200, 100), 1.5, 6)
	G2.text_mid(self, tag.get_center(), "영웅 전당", 20, Color(1, 0.95, 0.85), 3)
	_draw_me()
	for i in range(1, g.n):
		_draw_opp(i)
	var me_b := g.bonus(0)
	for k in g.heroes.size():
		var h: Dictionary = g.heroes[k]
		var hl := 0
		if g.pending == "hero" and g.cur == 0 and k in g.pend_heroes:
			hl = 2
		AcArt.hero(self, _hero_rect(k), h, hl, t, me_b)
	for tier in 3:
		var dr := _card_rect(tier, -1)
		var dsel: bool = sel.get("src", "") == "deck" and int(sel.get("tier", -9)) == tier
		AcArt.card_back(self, dr, tier, g.decks[tier].size(), 2 if dsel else 0, t)
		for idx in AcD.ROW_N:
			var c = g.rows[tier][idx]
			if c == null:
				continue
			var hl := 0
			if sel.get("src", "") == "row" and int(sel.tier) == tier and int(sel.idx) == idx:
				hl = 2
			elif _my_turn() and g.can_buy(0, c):
				hl = 1
			var cr := _card_rect(tier, idx)
			var ap := _appear_k(tier, idx)
			if ap < 0.0:
				continue   # 산 성물이 날아가는 동안은 빈자리
			if ap < 1.0:
				var s := G2.out_back(ap)
				cr = Rect2(cr.get_center() - cr.size * s * 0.5, cr.size * s)
			AcArt.card(self, cr, c, hl, t)
	_draw_bank()
	_draw_actions()
	_draw_reserved()
	_draw_top()
	for f: Dictionary in fx:
		if f.t < 0.0:
			continue
		var k := G2.out_cubic(clampf(f.t / FLY_T, 0.0, 1.0))
		var p: Vector2 = f.a.lerp(f.b, k) + Vector2(0, -sin(k * PI) * 60.0)
		AcArt.token(self, p, 18, f.col)
	# 날아가는 성물 · 영웅 — 판에서 수집판으로, 크기도 같이 줄며 살짝 위로 휜다
	for f: Dictionary in cfx:
		var r := _fly_rect(f)
		if f.get("back", false):
			AcArt.card_back(self, r, int(f.card.tier), 1, 0, t)
		else:
			AcArt.card(self, r, f.card, 0, t)
	for f: Dictionary in hfx:
		AcArt.hero(self, _fly_rect(f), f.hero, 0, t)
	for pp: Dictionary in pops:
		if pp.t < 0.0:
			continue
		var a := clampf(1.4 - pp.t, 0.0, 1.0)
		var at: Vector2 = pp.p + Vector2(0, -pp.t * 50.0)
		at.x = clampf(at.x, 130.0, vs.x - 130.0)   # 화면 가장자리에서 글이 잘리지 않게
		G2.text_mid(self, at, pp.txt, 34, Color(pp.col, a), 8)
	if not reveals.is_empty():
		_draw_reveal(reveals[0])
	if modal == "quit":
		_draw_modal("그만두고 처음 화면으로 갈까요?", ["그만두기", "계속하기"])
	if end_open:
		_draw_end()


func _draw_top() -> void:
	_btn(_back_btn(), "나가기", Color(1, 1, 1, 0.85), 24)
	var who: String = AcD.PLAYER_NAMES[g.cur]
	var line := "%d라운드   %s 차례" % [g.round_no, "내" if g.cur == 0 else who]
	if g.last_round:
		line += "   마지막 라운드!"
	var tx := _back_btn().end.x + 20.0
	if wide():
		draw_string(UiKit.font(), Vector2(1000, 44), line, HORIZONTAL_ALIGNMENT_LEFT, 264, 22, Color(1, 1, 1, 0.9))
		# 알림 줄 — 오른쪽 단 맨 아래(봉인 칸 밑). 판 아래에 두었다가 판을 키우려고 옮겼다
		var y := _res_rect(0).end.y + 34.0
		var nl := int((vs.y - y) / 26.0) + 1
		var lines := g.events.slice(maxi(0, g.events.size() - nl))
		for k in lines.size():
			var e: Dictionary = lines[k]
			var a := 0.4 + 0.6 * float(k + 1) / lines.size()
			var s := "%s: %s" % [AcD.PLAYER_NAMES[int(e.p)], String(e.txt)]
			draw_string(UiKit.font(), Vector2(1002, y + k * 26.0), s, HORIZONTAL_ALIGNMENT_LEFT, 262, 20,
					Color(AcD.PLAYER_COL[int(e.p)], a))
	else:
		# 세로 — 윗줄 라운드 · 차례, 아랫줄 방금 일어난 일
		draw_string(UiKit.font(), Vector2(tx, 32), line, HORIZONTAL_ALIGNMENT_LEFT, vs.x - tx - 16, 22, Color(1, 1, 1, 0.9))
		if toast_t > 0.0:
			draw_string(UiKit.font(), Vector2(tx, 58), toast, HORIZONTAL_ALIGNMENT_LEFT, vs.x - tx - 16, 20,
					Color(1, 1, 1, minf(1.0, toast_t) * 0.8))
	# 지금 할 일 안내(내 차례)
	var hint := ""
	if _my_turn():
		match g.pending:
			"discard":
				hint = "토큰이 넘쳤어요. 내 판에서 %d개를 눌러 돌려놓으세요" % g.pend_n
			"hero":
				hint = "찾아올 영웅을 하나 고르세요"
			_:
				if sel.is_empty() and sel_tok.is_empty():
					hint = "자원을 누르거나 성물을 고르세요"
					var near := _near_hero()
					if near != "" and not wide():
						hint = near
	elif _ai_turn():
		hint = "%s 생각하는 중" % AcD.josa(String(AcD.PLAYER_NAMES[g.cur]), "이")
	if hint != "" and (wide() or _acts().is_empty()):
		# 가로 = 행동 칸 맨 위 줄, 세로 = 단추 줄(단추가 없을 때)
		var hp := Vector2(_act_area().get_center().x, _act_area().position.y + 20.0) if wide() \
				else _act_area().get_center()
		G2.text_mid(self, hp, hint, 18 if wide() else 21, Color8(255, 230, 160), 5)


## 내게 가장 가까운 영웅 한 줄 — "도적까지 성물 2장"(모자란 성물 수가 가장 적은 영웅).
func _near_hero() -> String:
	var b := g.bonus(0)
	var best := ""
	var best_n := 99
	for h: Dictionary in g.heroes:
		var miss := 0
		for c in h.need:
			miss += maxi(0, int(h.need[c]) - int(b[c]))
		if miss < best_n:
			best_n = miss
			best = String(h.name)
	if best == "" or best_n > 6:
		return ""
	return "%s까지 성물 %d장" % [best, best_n]


## 영웅 등장(카드 뽑기) — 어둡게 깔고, 뒷면 카드가 커지며 나와(0~0.3초) 휙 뒤집히고(0.3~0.6초),
## 뒤로 빛살이 돌고 반짝이가 퍼지는 가운데 영웅이 숨 쉰다. 끝나면 `_finish_reveal` 이 수집판으로 날린다.
func _draw_reveal(rv: Dictionary) -> void:
	var rt := float(rv.t)
	var dur := _reveal_dur(rv)
	var fade := clampf(rt / 0.2, 0.0, 1.0) * clampf((dur - rt) / 0.25, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.0, 0.06, 0.62 * fade))
	var h: Dictionary = rv.hero
	var keys: Array = h.need.keys()
	keys.sort()
	var hc: Color = AcD.COL[keys[0]]
	var r := _reveal_rect(rv)
	var c := r.get_center()
	var shown := clampf((rt - 0.3) / 0.3, 0.0, 1.0)   # 뒤집힘 진행
	# 빛살 — 뒤집힌 뒤부터 천천히 돈다
	if shown > 0.0:
		var rays := 14
		var rad := r.size.x * 1.25
		for i in rays:
			var a0 := t * 0.35 + TAU * i / rays
			var a1 := a0 + TAU / rays * 0.5
			var col := Color(hc.lightened(0.4), 0.18 * shown * fade)
			draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * rad, c + Vector2(cos(a1), sin(a1)) * rad]), col)
		for k in 3:
			draw_circle(c, r.size.x * (0.62 + k * 0.1), Color(hc.lightened(0.5), 0.07 * shown * fade))
		# 반짝이 — 가운데에서 바깥으로
		for i in 18:
			var a := TAU * i / 18.0 + i * 0.37
			var d := r.size.x * (0.35 + fposmod((rt - 0.3) * 0.6 + i * 0.13, 1.0) * 0.8)
			var p := c + Vector2(cos(a), sin(a)) * d
			var s := 3.0 + (i % 3) * 2.0
			var al := (1.0 - fposmod((rt - 0.3) * 0.6 + i * 0.13, 1.0)) * shown * fade
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s * 2), p + Vector2(s * 0.5, 0), p + Vector2(0, s * 2),
					p + Vector2(-s * 0.5, 0)]), Color(1, 0.95, 0.75, al))
	# 카드 — 0.3~0.6초 사이에 가로로 접혔다 펴지며 뒤집힌다(앞 절반은 뒷면, 뒤 절반은 앞면)
	var flip := absf(cos(shown * PI))
	var cr := Rect2(c.x - r.size.x * flip * 0.5, r.position.y, r.size.x * flip, r.size.y)
	if shown < 0.5:
		AcArt.frame(self, cr, Color8(70, 52, 120), Color8(255, 220, 140), 4.0, 18)
		if cr.size.x > 20:
			AcArt.frame(self, cr.grow(-12), Color8(100, 76, 160), Color(1, 1, 1, 0.4), 2.0, 12)
			var dc := cr.get_center()
			draw_colored_polygon(PackedVector2Array([dc + Vector2(0, -40), dc + Vector2(28 * flip, 0), dc + Vector2(0, 40),
					dc + Vector2(-28 * flip, 0)]), Color(1, 0.9, 0.6, 0.85))
	elif cr.size.x > 4:
		AcArt.hero(self, cr, h, 0, t)
	# 글 — 뒤집힌 뒤
	if shown >= 1.0:
		var who := int(rv.p)
		var head := "영웅이 찾아왔다!" if who == 0 else "%s에게 영웅이 찾아왔다" % AcD.PLAYER_NAMES[who]
		var ta := fade
		G2.text_mid(self, Vector2(c.x, r.position.y - 34), head, 40, Color(1, 0.9, 0.6, ta), 10)
		G2.text_mid(self, Vector2(c.x, r.end.y + 34), "%s   +3점" % String(h.name), 34, Color(1, 1, 1, ta), 8)
		if who == 0:
			G2.text_mid(self, Vector2(c.x, r.end.y + 72), "누르면 넘어갑니다", 20, Color(1, 1, 1, 0.5 * ta), 0)


## 날아가는 것의 지금 자리 — a 에서 b 로, 크기도 같이 바뀌며 가운데가 살짝 위로 휜다. t < 0 이면 아직 a.
func _fly_rect(f: Dictionary) -> Rect2:
	var k := G2.out_cubic(clampf(float(f.t) / CARD_T, 0.0, 1.0))
	var a: Rect2 = f.a
	var b: Rect2 = f.b
	var c := a.get_center().lerp(b.get_center(), k) + Vector2(0, -sin(k * PI) * 50.0)
	var s := a.size.lerp(b.size, k)
	return Rect2(c - s * 0.5, s)


## 판의 (tier, idx) 자리에 새 성물이 펼쳐지는 정도 — 1 이상이면 다 펼쳐짐, 0 미만이면 아직 빈자리.
func _appear_k(tier: int, idx: int) -> float:
	for f: Dictionary in appear:
		if int(f.tier) == tier and int(f.idx) == idx:
			return float(f.t) / APPEAR_T
	return 1.0


## 날아가는 중이라 아직 수집판에 안 그릴 성물 · 영웅.
func _flying_ids() -> Dictionary:
	var d := {}
	for f: Dictionary in cfx:
		d[f.card.id] = true
	for f: Dictionary in hfx:
		d["h_" + String(f.hero.id)] = true
	for f: Dictionary in reveals:
		d["h_" + String(f.hero.id)] = true
	return d


## 내 수집판 — 이름 · 점수 · 찾아온 영웅 · **색별로 겹쳐 쌓은 성물** · 토큰.
func _draw_me() -> void:
	var pr := _player_rect(0)
	var pl: Dictionary = g.players[0]
	var pc: Color = AcD.PLAYER_COL[0]
	var on := g.cur == 0 and not g.over
	if on:
		AcArt.frame(self, pr.grow(5), Color(pc, 0.45 + 0.25 * sin(t * 4.0)), Color(), 0.0, 20)
	AcArt.frame(self, pr, Color8(40, 30, 66), pc.darkened(0.2) if on else Color(1, 1, 1, 0.2), 3.0, 18)
	draw_string(UiKit.font(), pr.position + Vector2(14, 30), "나의 수집", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, pc)
	var px := pr.end.x - 40.0 if wide() else pr.position.x + 250.0
	# 점수 숫자 뒤에 "점"(앞에 두면 20px 로 키운 "토큰 n/10" 과 겹친다)
	G2.text_mid(self, Vector2(px - 10, pr.position.y + 21), str(g.points(0)), 34, Color8(255, 220, 110), 7)
	draw_string(UiKit.font(), Vector2(px + 12, pr.position.y + 30), "점", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.5))
	var flying := _flying_ids()
	# 영웅 줄 — 성물 줄과 갈리게 금테 띠(판의 영웅 전당과 같은 모양)
	var hr := _hero_row()
	AcArt.frame(self, hr, Color8(34, 22, 60, 220), Color8(240, 200, 100, 200), 1.8, 10)
	var heroes: Array = pl.heroes
	for j in heroes.size():
		if flying.has("h_" + String(heroes[j].id)):
			continue
		AcArt.hero(self, _hchip_rect(0, j), heroes[j], 0, t)
	if heroes.is_empty():
		G2.text_mid(self, _hero_row().get_center(), "찾아온 영웅이 아직 없어요", 20, Color(1, 0.9, 0.7, 0.4), 0)
	# 색별 묶음 — 옆으로 반씩 겹친다. 빈 색은 자리만(그 색 상징을 흐리게)
	var by := [[], [], [], [], []]
	for c: Dictionary in pl.cards:
		by[c.col].append(c)
	for col in AcD.N_COL:
		var cards: Array = by[col]
		var shown := []
		for c: Dictionary in cards:
			if not flying.has(c.id):
				shown.append(c)
		if shown.is_empty():
			var r0 := _stack_rect(0, col, 0)
			AcArt.frame(self, r0, Color(AcD.COL[col], 0.08), Color(AcD.COL[col], 0.3), 1.5, 6)
			AcArt.gem(self, r0.get_center(), r0.size.x * 0.24, col, 0.35)
			continue
		for k in shown.size():
			AcArt.card(self, _stack_rect(0, col, k), shown[k], 0, t)
		# 장수 배지 — 묶음 오른쪽 끝
		var last := _stack_rect(0, col, shown.size() - 1)
		var bp := Vector2(last.end.x + 2, last.position.y + 4)
		draw_circle(bp, 11, P.INK)
		G2.text_mid(self, bp, str(shown.size()), 15, Color(1, 1, 1), 0.0)
	# 토큰
	var discard := g.pending == "discard" and g.cur == 0
	for c in 6:
		var tr := _ptok_rect(0, c)
		var n: int = pl.tok[c]
		if discard and n > 0:
			draw_circle(tr.get_center(), tr.size.x * 0.5 + 6, Color(1, 0.4, 0.4, 0.5 + 0.3 * sin(t * 6.0)))
		AcArt.token_num(self, tr.get_center(), tr.size.x * 0.5, c, n)
	var tl := "토큰 %d/10" % g.tokens(0)
	if wide():
		# 머리줄 가운데(이름과 점수 사이)
		draw_string(UiKit.font(), Vector2(pr.position.x + 128, pr.position.y + 29), tl, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.5))
	else:
		draw_string(UiKit.font(), Vector2(_ptok_rect(0, 5).end.x + 10, pr.end.y - 20), tl, HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
				Color(1, 1, 1, 0.5))


## 상대 띠(두 줄) — 윗줄: 이름 · 찾아온 영웅 · 봉인 수 · 점수 / 아랫줄: 색마다 [성물 수 네모][토큰 수 동그라미] + 별가루.
func _draw_opp(i: int) -> void:
	var pr := _player_rect(i)
	var pl: Dictionary = g.players[i]
	var pc: Color = AcD.PLAYER_COL[i]
	var on := g.cur == i and not g.over
	if on:
		AcArt.frame(self, pr.grow(3), Color(pc, 0.45 + 0.25 * sin(t * 4.0)), Color(), 0.0, 14)
	AcArt.frame(self, pr, Color8(40, 30, 66), pc.darkened(0.2) if on else Color(1, 1, 1, 0.2), 2.0, 12)
	draw_string(UiKit.font(), pr.position + Vector2(10, 24), String(AcD.PLAYER_NAMES[i]), HORIZONTAL_ALIGNMENT_LEFT, 80, 20, pc)
	G2.text_mid(self, Vector2(pr.end.x - 24, pr.position.y + 17), str(g.points(i)), 26, Color8(255, 220, 110), 6)
	var flying := _flying_ids()
	for j in pl.heroes.size():
		if not flying.has("h_" + String(pl.heroes[j].id)):
			AcArt.hero(self, _hchip_rect(i, j), pl.heroes[j], 0, t)
	var b := g.bonus(i)
	for col in AcD.N_COL:
		var n := int(b[col])
		for f: Dictionary in cfx:
			if f.card.col == col and f.b == _stack_rect(i, col, 0):
				n -= 1   # 날아오는 중인 것은 도착하면 센다
		var sr := _stack_rect(i, col, 0)
		AcArt.frame(self, sr, AcD.COL[col] if n > 0 else Color(AcD.COL[col], 0.18), AcD.edge(col), 1.5, 4)
		if n > 0:
			G2.text_mid(self, sr.get_center(), str(n), 16, AcD.INK_ON[col], 0.0)
	# 봉인 수 — 카드 뒷면 하나 + 숫자(없으면 그리지 않음)
	var rr := _resicon_rect(i)
	var nres: int = pl.reserved.size()
	if nres > 0:
		AcArt.frame(self, rr, Color8(110, 90, 170), Color(1, 1, 1, 0.6), 1.5, 4)
		G2.text_mid(self, rr.get_center(), str(nres), 15, Color(1, 1, 1), 3)
	for c in 6:
		var tr := _ptok_rect(i, c)
		AcArt.token_num(self, tr.get_center(), tr.size.x * 0.5, c, int(pl.tok[c]))


func _draw_bank() -> void:
	for c in 6:
		var r := _bank_rect(c)
		var n: int = g.bank[c]
		var picked := sel_tok.count(c)
		if picked > 0:
			draw_circle(r.get_center(), r.size.x * 0.5 + 7, Color(1, 0.85, 0.3, 0.7 + 0.3 * sin(t * 6.0)))
		AcArt.token(self, r.get_center(), r.size.x * 0.5, c, n, n == 0)
		if picked > 0:
			G2.text_mid(self, r.get_center() + Vector2(0, -r.size.y * 0.62), "+%d" % picked, 22, Color8(255, 230, 140), 5)


func _draw_actions() -> void:
	var a := _act_area()
	var acts := _acts()
	if wide():
		# 작은 행동 칸 — 윗줄 안내(또는 고른 것에 대한 한 줄) · 단추 한 줄 · 아랫줄 가까운 영웅.
		# 예전엔 고른 성물 미리 보기와 사용법 세 줄로 칸이 컸는데 "이 칸을 줄이고 다른 칸을 늘리고 싶다"(11-08) — 고른 성물은 판에서 금테로 보인다.
		AcArt.frame(self, a, Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.12), 2.0, 14)
		if not sel.is_empty():
			_sel_note(Vector2(a.get_center().x, a.position.y + 22))
		elif not sel_tok.is_empty():
			var names := []
			for c in sel_tok:
				names.append(AcD.NAMES[c])
			G2.text_mid(self, Vector2(a.get_center().x, a.position.y + 22), "가져올 자원: %s" % " ".join(names), 20,
					Color8(255, 230, 160), 4)
		if _my_turn() and g.pending == "":
			var near := _near_hero()
			if near != "":
				G2.text_mid(self, Vector2(a.get_center().x, a.end.y - 22), "가까운 영웅: %s" % near, 20, Color8(255, 200, 255), 4)
	elif not sel.is_empty():
		# 세로 — 단추 줄 오른쪽 남는 칸
		var bx := a.position.x + acts.size() * 150.0
		_sel_note(Vector2((bx + a.end.x) * 0.5, a.get_center().y))
	for k in acts.size():
		var col := Color8(120, 200, 120) if k == 0 and acts.size() > 1 else Color8(90, 120, 190)
		if String(acts[k][0]) == "취소":
			col = Color8(110, 100, 130)
		elif String(acts[k][0]) == "봉인":
			col = Color8(170, 110, 200)
		_btn(_act_btn(k), String(acts[k][0]), col, 21 if wide() else 26, bool(acts[k][1]))


## 고른 성물에 대한 한 줄(못 사면 왜인지).
func _sel_note(p: Vector2) -> void:
	var c = _sel_card()
	var s := ""
	if sel.src == "deck":
		s = "더미 맨 위를 봉인" if g.can_reserve(sel.tier, -1) else "봉인은 셋까지"
	elif c != null:
		if g.can_buy(0, c):
			var pay := g.pay_for(0, c)
			var sum := 0
			for v in pay:
				sum += int(v)
			s = "토큰 %d개로 갖출 수 있어요" % sum if sum > 0 else "공짜로 갖출 수 있어요"
		else:
			var sh := g.short(0, c)
			var miss := 0
			for v in sh:
				miss += int(v)
			s = "자원 %d개가 모자라요" % maxi(1, miss - int(g.players[0].tok[AcD.GOLD]))
	G2.text_mid(self, p, s, 20, Color8(255, 230, 160), 4)


func _sel_card():
	if sel.is_empty():
		return null
	if sel.src == "res":
		var res: Array = g.players[0].reserved
		return res[sel.idx] if int(sel.idx) < res.size() else null
	if sel.src == "row":
		return g.rows[sel.tier][sel.idx]
	return null


func _draw_reserved() -> void:
	var res: Array = g.players[0].reserved
	if wide():
		draw_string(UiKit.font(), Vector2(1002, 404), "내가 봉인한 성물", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.6))
	for k in AcD.RESERVE_MAX:
		var r := _res_rect(k)
		if k < res.size():
			var hl := 0
			if sel.get("src", "") == "res" and int(sel.idx) == k:
				hl = 2
			elif _my_turn() and g.can_buy(0, res[k]):
				hl = 1
			AcArt.card(self, r, res[k], hl, t)
		else:
			AcArt.frame(self, r, Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.15), 2.0, 10)


func _draw_modal(q: String, labels: Array) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.55))
	var c := vs * 0.5
	var r := Rect2(c.x - 250, c.y - 90, 500, 200)
	AcArt.frame(self, r, Color8(44, 32, 72), Color8(255, 220, 140), 4.0, 22)
	G2.text_mid(self, Vector2(c.x, c.y - 30), q, 26, Color(1, 1, 1), 5)
	for k in labels.size():
		_btn(_modal_btn(k), String(labels[k]), Color8(200, 90, 90) if k == 0 else Color8(120, 200, 120), 26)


func _draw_end() -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.6))
	var c := vs * 0.5
	var w := minf(vs.x - 40.0, 620.0)
	var r := Rect2(c.x - w * 0.5, c.y - 250, w, 480)
	AcArt.frame(self, r, Color8(44, 32, 72), Color8(255, 220, 140), 4.0, 26)
	var win := g.winner == 0 and not bool(g.players[0].ai)
	var title := "승리!" if win else "%s 이겼습니다" % AcD.josa(String(AcD.PLAYER_NAMES[g.winner]), "이")
	G2.text_mid(self, Vector2(c.x, r.position.y + 54), title, 52, Color8(255, 226, 150) if win else Color(1, 1, 1), 12)
	G2.text_mid(self, Vector2(c.x, r.position.y + 104), "%d라운드" % g.round_no, 22, Color(1, 1, 1, 0.6), 0)
	var order := g.rank()
	for k in order.size():
		var i: int = order[k]
		var y := r.position.y + 160 + k * 60
		var row := Rect2(r.position.x + 30, y - 24, w - 60, 50)
		AcArt.frame(self, row, Color(AcD.PLAYER_COL[i], 0.18), Color(), 0.0, 12)
		draw_string(UiKit.font(), Vector2(row.position.x + 16, y + 9), "%d위  %s" % [k + 1, AcD.PLAYER_NAMES[i]],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 26, AcD.PLAYER_COL[i])
		var info := "%d점   성물 %d   영웅 %d" % [g.points(i), g.players[i].cards.size(), g.players[i].heroes.size()]
		# 오른쪽 맞춤 — 위치는 상자의 왼쪽 끝(상자 폭 bw)
		var bw := w - 260.0
		draw_string(UiKit.font(), Vector2(row.end.x - 16 - bw, y + 9), info, HORIZONTAL_ALIGNMENT_RIGHT, bw, 22, Color(1, 1, 1, 0.85))
	_btn(_end_btn(0), "다시 하기", Color8(120, 200, 120), 26)
	_btn(_end_btn(1), "처음으로", Color8(90, 120, 190), 26)

# ==================== 확인용 ====================


## `--ac-click-test` — 처음 → 시작 → 자원 셋 고르기 → 가져오기 → (상대 차례) → 성물 고르기 → 봉인 → 나가기 를
## **진짜 마우스 이벤트**로. 실패하면 종료 코드 1.
func _click_test_step(dt: float) -> void:
	_ct += dt
	if _ct < 0.3:
		return
	_ct = 0.0
	var steps := [
		[func(): _press(_title_btn(0).get_center()), func(): return scr == Scr.PLAY, "시작"],
		[func(): _press(_bank_rect(0).get_center()), func(): return sel_tok == [0], "자원 하나 고르기"],
		[func(): _press(_bank_rect(1).get_center()), func(): return sel_tok.size() == 2, "자원 둘"],
		[func(): _press(_bank_rect(2).get_center()), func(): return sel_tok.size() == 3, "자원 셋"],
		[func(): _press(_act_btn(0).get_center()), func(): return g.tokens(0) == 3, "가져오기"],
		[func(): pass, func(): return _my_turn(), "상대 차례 지나가기"],
		[func(): _press(_card_rect(1, 0).get_center()), func(): return sel.get("src", "") == "row", "성물 고르기"],
		[func(): _press(_act_btn(1).get_center()), func(): return g.players[0].reserved.size() == 1, "봉인"],
		[func(): pass, func(): return _my_turn(), "상대 차례 지나가기 2"],
		[func(): _press(_res_rect(0).get_center()), func(): return sel.get("src", "") == "res", "봉인한 성물 고르기"],
		[func(): _press(_back_btn().get_center()), func(): return modal == "quit", "나가기 창"],
		[func(): _press(_modal_btn(0).get_center()), func(): return scr == Scr.TITLE, "그만두기"],
	]
	var i := _cs / 2
	if i >= steps.size():
		print("AC CLICK TEST OK")
		get_tree().quit(0)
		return
	if _cs % 2 == 0:
		steps[i][0].call()
		_cs += 1
		_wait = 0.0
		return
	if steps[i][1].call():
		_cs += 1
		return
	# 조건이 바로 안 맞으면 조금 기다린다 — 상대 차례는 길게(상대마다 AI_DELAY)
	_wait += 0.3
	if _wait < (12.0 if String(steps[i][2]).begins_with("상대") else 1.2):
		return
	printerr("AC CLICK TEST FAIL: %s" % steps[i][2])
	get_tree().quit(1)


var _wait := 0.0


func _press(p: Vector2) -> void:
	var xf := get_viewport().get_final_transform()
	var wp := xf * p
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = wp
		e.global_position = wp
		Input.parse_input_event(e)
