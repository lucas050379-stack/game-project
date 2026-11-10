extends Node2D
## 떡 하나 주면 안 잡아먹지 — 진입점(허브가 자식으로 연다). 화면 배치 · 입력 · 그리기 · 연출.
##
## 규칙은 전부 [TgGame](길 만들기 · 부딪힘 · 봇 포함)에 있고 여기는 **보여 주고 키를 행동으로 바꾸기만** 합니다.
## 화면: 처음(TITLE) → 라운드 고르기(PICK) → 달리기(PLAY) → 결과 창. 1280×720 데스크톱 전용.
## 연출은 규칙이 남긴 `g.events` 를 받아 입자 · 흔들림 · 섬광 · 컷인으로 바꿉니다(행동 → 판의 반응).
## **자리 함수(`_*_rect`)를 그리기와 클릭이 같이 봅니다.** 화면 글자에 `·` `—` `×` `→` 를 쓰지 마세요(Jua). 말투는 해요체.

enum Scr { TITLE, PICK, PLAY }

var scr := Scr.TITLE
var vs := Vector2(1280, 720)
var t := 0.0
var g: TgGame = null
var start_zone := 0            ## 출발 구간 — 늘 0(확인용 --tg-round=N 으로만 바뀐다)
var fresh := {}                ## 이번 판이 세운 새 기록 {score, m, zone}(TgSv.add)
var banner_t := 9.0            ## 구간 이름 띠가 뜬 뒤 지난 시간
var parts: Array = []          ## 입자 {p(화면), v, t, life, col, r, grav}
var sucks: Array = []          ## 먹은 떡 · 엽전 · 꼬치가 호랑이 입으로 빨려 드는 중 {p(먹은 자리, 화면), kind, t} — 그 자리에서 사라지면 "먹었다" 가 안 느껴졌다(사용자 지적 11-10)
const SUCK_T := 0.22
var pops: Array = []           ## 떠오르는 글 {p, txt, col, t}
var rings: Array = []          ## 퍼지는 고리 {p, t, dur, col}
var shake := 0.0
var soff := Vector2.ZERO        ## 이번 프레임의 흔들림(배경 · 세상 층이 같은 값을 쓴다)
var cv: CanvasItem = self      ## 지금 그리는 층(_draw_play 설명)
var _world: Node2D
var _top: Node2D
var cam := 0.0                 ## 화면이 위로 따라 올라간 높이(px) — 산을 오르거나 윗길에서 뛸 때
var flash := 0.0
var combo := 0                 ## 이어 먹은 떡 — 방울 음이 올라간다
var combo_t := 0.0
var goblin_k := 0.0            ## 곶감 귀신이 얼마나 가까운가(0~1, 따라감)
var modal := ""
var end_open := false
var end_t := 0.0
var saved := false
var no_save := false
var mouse := Vector2(-999, -999)
var mouse_slide := false
var mouse_jump := false        ## 왼쪽 절반을 누르고 있다(하늘 보너스에서 오르기)
var show_box := false          ## 판정 상자 보기 — 테스트 빌드는 켜진 채로, H 로 켜고 끈다(`--tg-box`)
var hit_flash := 0.0           ## 맞은 뒤 판정 상자가 붉게 남는 시간
var rules := UiRules.new()     ## 규칙서 — 처음 화면의 [규칙] 단추
var keys := UiKeys.new()       ## 키 설정 창 — 처음 화면의 [키 설정] 메뉴
const KEYS := [["jump", "점프", KEY_SPACE], ["slide", "숙이기", KEY_S], ["power", "호랑이 기운", KEY_ENTER]]   ## 키 설정 창의 줄(하는 일 · 이름 · 기본 키)
var shot_path := ""
var tg_miss := 0.0
var shot_at: Array = []
var _shot_i := 0
var tg_auto := false
var auto_drive := false         ## 테스트 빌드 — 판에서 F2 · [자동 주행] 단추로 켜고 끄는 자동 주행(검산의 완벽 봇이 대신 달린다, 사용자 요청 11-10)
var tg_seed := -1
var click_test := false
var _ct := 0.0
var _cs := 0
var _wait := 0.0


func _ready() -> void:
	_world = Node2D.new()
	_world.scale = Vector2(TgD.VIEW_ZOOM, TgD.VIEW_ZOOM)
	_world.position = Vector2(TgD.FOX_X, TgD.GROUND_Y) * (1.0 - TgD.VIEW_ZOOM)   # 호랑이 발밑(FOX_X, 땅)이 제자리에 남게
	# 지형지물 · 장애물 · 떡 · 호랑이의 채도를 올린다 — 옅은 배경과 갈리게(사용자 11-10 밤)
	var sat := Shader.new()
	sat.code = "shader_type canvas_item;
void fragment() {
	float g = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb = clamp(mix(vec3(g), COLOR.rgb, 1.25), 0.0, 1.0);
}
"
	var sm := ShaderMaterial.new()
	sm.shader = sat
	_world.material = sm
	add_child(_world)
	_world.draw.connect(_draw_world_layer)
	_top = Node2D.new()
	add_child(_top)
	_top.draw.connect(_draw_top_layer)
	Bgm.use("tiger")
	TgSnd.init(Hub.host(self))
	TgSv.load_()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--shot-at="):
			for s in a.substr(10).split(","):
				shot_at.append(float(s))
		elif a.begins_with("--tg-miss="):   # 확인용 — 자동 주행 봇이 장애물을 못 볼 확률(1 이면 구덩이에 다 빠진다)
			tg_miss = float(a.substr(10))
		elif a == "--tg-auto":
			tg_auto = true
		elif a.begins_with("--tg-force="):   # 확인용 — 그 장애물 · 지형만 나온다(moving · ledge · rhythm · steps · spikes · pestle · flyer …)
			TgGame.force = a.substr(11)
		elif a == "--tg-box":
			show_box = true
		elif a == "--tg-click-test":
			click_test = true
		elif a.begins_with("--tg-seed="):
			tg_seed = int(a.substr(10))
		elif a.begins_with("--tg-rules"):   # 확인용 — 규칙서 N쪽을 바로 연다
			var pg := int(a.substr(11)) - 1 if a.length() > 11 else 0
			(func(): _open_rules(); rules.page = clampi(pg, 0, rules.pages.size() - 1)).call_deferred()
		elif a.begins_with("--tg-round="):   # 확인용 — N 번째 구간부터 달린다
			start_zone = maxi(0, int(a.substr(11)) - 1)
	no_save = not OS.get_cmdline_user_args().is_empty()
	if OS.has_feature("testbuild"):
		show_box = true
	if tg_auto:
		_start.call_deferred()


func _start() -> void:
	g = TgGame.new(start_zone, tg_seed, TgSv.up)
	scr = Scr.PLAY
	parts = []
	sucks = []
	pops = []
	rings = []
	shake = 0.0
	flash = 0.0
	combo = 0
	goblin_k = 0.0
	cam = 0.0
	banner_t = 0.0
	fresh = {}
	if g.boss():
		pops.append({p = Vector2(vs.x * 0.5, 230), txt = "곶감 귀신이 쫓아와요!  부딪히면 따라잡혀요", col = Color8(255, 190, 120), t = -0.8})
	modal = ""
	end_open = false
	end_t = 0.0
	saved = false
	mouse_slide = false
	TgSnd.play("tick")


func _paused() -> bool:
	return modal != "" or Vol.open or end_open or rules.open


func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	t += dt
	vs = get_viewport_rect().size
	banner_t += dt
	shake = maxf(0.0, shake - dt)
	if g != null:   # 작은 언덕(80)까지는 호랑이가 오르내리고, 그 위로는 화면이 따라간다. 윗길에서 뛰어도 안 잘리게 높이도 본다
		cam = lerpf(cam, maxf(0.0, g.ground_h(g.dist) - 80.0) + maxf(0.0, g.fox_y - 180.0), minf(1.0, dt * 5.0))
	hit_flash = maxf(0.0, hit_flash - dt)
	flash = maxf(0.0, flash - dt * 3.0)
	combo_t -= dt
	if combo_t <= 0.0:
		combo = 0
	for p: Dictionary in parts:
		p.t += dt
		p.v = p.v * (1.0 - dt * 2.0) + Vector2(0, float(p.grav)) * dt
		p.p += p.v * dt
	parts = parts.filter(func(p): return p.t < p.life)
	for p: Dictionary in pops:
		p.t += dt
	pops = pops.filter(func(p): return p.t < 0.9)
	for s: Dictionary in sucks:
		s.t += dt
	sucks = sucks.filter(func(s): return s.t < SUCK_T)
	for r: Dictionary in rings:
		r.t += dt
	rings = rings.filter(func(r): return r.t < r.dur)
	var hot := false
	if scr == Scr.PLAY and g != null:
		hot = not g.over and g.oil < 25.0
		if g.over:
			end_t += dt
			if not end_open and end_t > 1.6:
				_open_end()
		elif not _paused():
			if tg_auto or auto_drive:
				g.bot(0.0, tg_miss)
			else:
				g.slide(mouse_slide or _held("slide"))
				g.fly_held = mouse_jump or _held("jump")
			g.step(dt)
			_take_events()
			if g.magnet_t > 0.0 and randf() < 0.5:   # 꿀단지 — 금빛 가루가 호랑이 쪽으로
				var a2 := randf() * TAU
				parts.append({p = _fox_feet() + Vector2(0, -40) + Vector2.from_angle(a2) * 200.0, v = -Vector2.from_angle(a2) * 320.0, t = 0.0, life = 0.5,
						col = TgArt.EMBER, r = 3.0, grav = 0.0})
			if g.on_ground() and not g.flying() and randf() < 0.6:   # 발밑 먼지 — 땅을 박차며 뒤로 날린다
				parts.append({p = _fox_feet() + Vector2(-14, -4), v = Vector2(-g.speed * randf_range(0.25, 0.45), -randf_range(20, 70)), t = 0.0, life = 0.35,
						col = Color(1, 0.95, 0.85, 0.5), r = randf_range(2.0, 3.5), grav = 200.0})
			if g.dashing() and randf() < 0.8:   # 질주 꼬리 불똥
				_spark(_fox_feet() + Vector2(-30, -40), TgArt.FLAME, 1, 160.0, 200.0)
			var want := 0.0
			if g.boss():
				want = g.chase
			goblin_k = lerpf(goblin_k, want, minf(1.0, dt * 2.0))
	Bgm.mood(hot)
	if click_test:
		_click_test_step(dt)
	if shot_path != "" and _shot_i < shot_at.size() and t >= float(shot_at[_shot_i]):
		var path := shot_path
		if shot_at.size() > 1:
			path = shot_path.get_basename() + "_%d.png" % _shot_i
		get_viewport().get_texture().get_image().save_png(path)
		_shot_i += 1
		if _shot_i >= shot_at.size() and not click_test:
			get_tree().quit()
	soff = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 22.0 if shake > 0.0 else Vector2.ZERO
	queue_redraw()
	_world.queue_redraw()
	_top.queue_redraw()


## 세상 좌표(x 거리, y 위로) → 화면.
func _scr(x: float, y: float) -> Vector2:
	return Vector2(TgD.FOX_X + (x - g.dist), _gy(x) - y)


## 그 자리 땅의 화면 y(언덕).
func _gy(x: float) -> float:
	return TgD.GROUND_Y + cam - g.ground_h(x)


func _fox_feet() -> Vector2:
	return Vector2(TgD.FOX_X, _gy(g.dist) - g.fox_y)


func _spark(at: Vector2, col: Color, n: int, speed: float, grav: float = 500.0) -> void:
	for k in n:
		var a := randf() * TAU
		parts.append({p = at, v = Vector2(cos(a), sin(a)) * speed * randf_range(0.3, 1.0), t = 0.0, life = randf_range(0.3, 0.7),
				col = col.lerp(Color(1, 1, 1), randf() * 0.4), r = randf_range(2.0, 4.5), grav = grav})


## 규칙이 남긴 일 → 입자 · 소리 · 흔들림. 행동 하나에 반응 하나씩.
func _take_events() -> void:
	for e: Dictionary in g.events:
		match String(e.kind):
			"jump":
				TgSnd.play("jump", 1.25 if e.second else 1.0)
				_spark(_fox_feet(), TgArt.PAPER, 5 if not e.second else 9, 120.0)
				if e.second:
					rings.append({p = _fox_feet() + Vector2(0, -30), t = 0.0, dur = 0.3, col = TgArt.EMBER})
			"land":
				TgSnd.play("land")
				for k in 6:   # 착지 먼지 — 양옆으로 낮게
					parts.append({p = _fox_feet(), v = Vector2((k - 2.5) * 50.0, -30.0 - randf() * 40.0), t = 0.0, life = 0.35,
							col = Color(1, 1, 1, 0.6), r = 4.0, grav = 100.0})
			"slide":
				TgSnd.play("slide")
			"ember":
				combo += 1
				combo_t = 0.6
				TgSnd.play("ember", 1.0 + minf(combo, 12) * 0.05)
				sucks.append({p = _scr(e.x, e.y), kind = "ember", t = 0.0})
				if e.full:
					pops.append({p = _gauge_btn().get_center() + Vector2(0, -50), txt = "호랑이 기운 준비", col = TgArt.EMBER, t = 0.0})
					rings.append({p = _gauge_btn().get_center(), t = 0.0, dur = 0.5, col = TgArt.EMBER})
			"big":   # 무지개떡 — 큰 소리 · 고리 · 점수 글
				TgSnd.play("lantern", 1.4)
				combo += 1
				combo_t = 0.6
				sucks.append({p = _scr(e.x, e.y), kind = "big", t = 0.0})
				rings.append({p = _scr(e.x, e.y), t = 0.0, dur = 0.35, col = Color.from_hsv(fposmod(t * 0.35, 1.0), 0.6, 1.0)})
				pops.append({p = _scr(e.x, e.y) + Vector2(0, -30), txt = "무지개떡 +%d" % (TgD.BIG_SCORE * int(e.m)), col = Color8(255, 200, 240), t = 0.0})
				if e.full:
					pops.append({p = _gauge_btn().get_center() + Vector2(0, -50), txt = "호랑이 기운 준비", col = TgArt.EMBER, t = 0.0})
			"kkochi":
				TgSnd.play("lantern")
				sucks.append({p = _scr(e.x, e.y), kind = "kkochi", t = 0.0})
				rings.append({p = _scr(e.x, e.y), t = 0.0, dur = 0.4, col = TgArt.EMBER})
				pops.append({p = _scr(e.x, e.y), txt = "배 +%d  %d점%s" % [int(TgD.OIL_LANTERN), TgD.SCORE_LANTERN * int(e.m), "" if int(e.m) < 2 else " (x%d)" % int(e.m)],
						col = Color8(255, 240, 170), t = 0.0})
			"crumble":   # 발판이 꺼지기 시작 — 우지끈
				TgSnd.play("hit", 0.7)
			"zone":   # 다음 구간 — 이름 띠가 뜨고 배경이 바뀐다(흰 번쩍임으로 이음매를 가린다)
				banner_t = 0.0
				flash = maxf(flash, 0.6)
				TgSnd.play("lantern", 1.2)
				if g.boss() and int(TgGame.zone_row(int(e.zone) - 1)[1]) != 3:
					pops.append({p = Vector2(vs.x * 0.5, 230), txt = "곶감 귀신이 쫓아와요!  부딪히면 따라잡혀요", col = Color8(255, 190, 120), t = -0.8})
			"mult":   # 겹치기 — 호랑이 기운 · 산삼 · 꿀단지가 둘 이상 켜졌다
				TgSnd.play("awaken", 1.3 + 0.1 * int(e.n))
				rings.append({p = _fox_feet() + Vector2(0, -50), t = 0.0, dur = 0.5, col = Color8(255, 120, 200)})
				pops.append({p = _fox_feet() + Vector2(0, -160), txt = "겹치기! 점수 x%d" % int(e.n), col = Color8(255, 150, 210), t = 0.0})
			"bite":
				shake = 0.5
				flash = 0.8
				pops.append({p = Vector2(vs.x * 0.5, 260), txt = "곶감 귀신에게 물렸어요!  체력 -%d" % int(TgD.OIL_BITE), col = Color8(255, 150, 90), t = -0.6})
			"hit", "pit":
				if g.boss() and e.kind == "hit":
					pops.append({p = Vector2(190, _gy(g.dist) - 190), txt = "귀신이 다가와요!", col = Color8(255, 190, 120), t = 0.0})
				hit_flash = 0.6
				TgSnd.play("hit")
				shake = 0.3
				flash = 0.5
				combo = 0
				_spark(_fox_feet() + Vector2(10, -40), Color8(255, 90, 70), 14, 280.0)
				pops.append({p = _fox_feet() + Vector2(0, -110), txt = "체력 -%d" % int(TgD.OIL_HIT if e.kind == "hit" else TgD.OIL_PIT),
						col = Color8(255, 120, 100), t = 0.0})
			"smash":
				TgSnd.play("hit", 1.4)
				shake = maxf(shake, 0.12)
				_spark(_scr(e.x, e.y), TgArt.FLAME, 16, 380.0)
			"awaken":
				TgSnd.play("awaken")
			"bigcoin":
				TgSnd.play("lantern", 1.6)
				sucks.append({p = _scr(e.x, e.y), kind = "bigcoin", t = 0.0})
				pops.append({p = _scr(e.x, e.y) + Vector2(0, -34), txt = "큰 엽전 +10닢", col = TgArt.EMBER, t = 0.0})
			"coin":
				TgSnd.play("tick", 1.5)
				sucks.append({p = _scr(e.x, e.y), kind = "coin", t = 0.0})
			"item":
				TgSnd.play("lantern", 0.8)
				flash = 0.35
				rings.append({p = _scr(e.x, e.y), t = 0.0, dur = 0.5, col = TgArt.EMBER})
				pops.append({p = _fox_feet() + Vector2(0, -130), txt = {honey = "꿀단지! 떡이 끌려와요", sansam = "산삼! 몸이 커져요", rope = "동아줄! 하늘로", box = "보따리! 엽전 8닢"}.get(e.item, ""), col = TgArt.EMBER, t = 0.0})
				if e.item == "rope":
					TgSnd.play("awaken", 1.4)
			"club":   # 도깨비 방망이 — 장애물이 펑 하고 떡으로, 떡이 전부 날아온다
				TgSnd.play("boom", 1.3)
				flash = 0.6
				shake = 0.2
				pops.append({p = _fox_feet() + Vector2(0, -130), txt = "도깨비 방망이! 떡 %d개" % e.got.size(), col = TgArt.EMBER, t = 0.0})
				for q: Vector2 in e.got:   # 떡이 시차를 두고 줄줄이 빨려 든다
					var sp := _scr(q.x, q.y)
					sucks.append({p = sp, kind = "ember", t = -randf() * 0.3})
					_spark(sp, TgArt.EMBER, 3, 120.0, 0.0)
			"fly_end":
				TgSnd.play("land")
			"dash":
				flash = 1.0
				shake = 0.25
				rings.append({p = _fox_feet() + Vector2(0, -40), t = 0.0, dur = 0.6, col = TgArt.FLAME})
			"dash_end":
				TgSnd.play("boom")
				shake = 0.35
				for k in 2:
					rings.append({p = _fox_feet() + Vector2(0, -40), t = -k * 0.12, dur = 0.7, col = TgArt.EMBER if k == 0 else Color(1, 1, 1)})
				_spark(_fox_feet() + Vector2(0, -40), TgArt.FLAME, 30, 420.0)
			"finish":
				TgSnd.play("win")
				for k in 60:   # 결승 종이 꽃가루
					parts.append({p = Vector2(randf() * vs.x, -20.0 - randf() * 120.0), v = Vector2(randf_range(-60, 60), randf_range(80, 220)), t = 0.0,
							life = 2.4, col = [Color8(230, 70, 60), Color8(250, 200, 80), Color8(120, 180, 230), Color(1, 1, 1)][k % 4], r = 4.0, grav = 60.0})
			"fail":
				TgSnd.play("lose")
				_spark(_fox_feet() + Vector2(44, -50), Color8(180, 180, 190), 12, 90.0, -60.0)   # 힘 빠진 한숨
	g.events.clear()


func _open_end() -> void:
	end_open = true
	end_t = 0.0
	if not saved and not no_save:
		fresh = TgSv.add(g)
		TgSv.save_()
	saved = true

# ==================== 자리 ====================


func _back_btn() -> Rect2:
	return Hub.std_rect("hub", vs)


func _vol_btn() -> Rect2:
	return Hub.std_rect("vol", vs)


## 장애물 등장 연출 — 호랑이가 가까이 오면(만나기 0.8초 전부터 0.3초 동안) 제자리로 들어온다. 판정은 처음부터 제자리라 보이는 것만 다르다.
##   rise 땅에서 솟음 · roll 오른쪽에서 굴러 옴 · fall 하늘에서 떨어져 박힘(흙먼지) · pop 가시가 튀어나옴
##   drop 위에서 내려옴 · swing 그네처럼 흔들리며 들어옴 · shake 천장이 흔들리다 내려앉음
func _draw_enter(it: Dictionary, en: String, sx: float, theme: int) -> void:
	var d := float(it.x) - g.dist
	var k := clampf((g.speed * 0.8 - d) / (g.speed * 0.3), 0.0, 1.0)
	var gy := _gy(it.x)
	if k <= 0.0 and en in ["rise", "pop", "fall", "drop"]:
		return   # 아직 안 보인다
	var xf := Transform2D()
	match en:
		"rise", "pop":
			xf = Transform2D(0.0, Vector2(1.0, G2.out_back(k)), 0.0, Vector2(sx, gy))
		"roll":
			var off := (1.0 - G2.out_cubic(k)) * 420.0
			xf = Transform2D(-(1.0 - k) * 7.0, Vector2(sx + off, gy - float(it.h) * 0.5)) * Transform2D(0.0, Vector2(0, float(it.h) * 0.5))
		"fall":
			var e := k * k
			var bounce := sin(clampf((k - 0.85) / 0.15, 0.0, 1.0) * PI) * 14.0
			xf = Transform2D(0.0, Vector2(sx, gy - (1.0 - e) * 560.0 - bounce))
			if k >= 1.0 and not it.has("dusted"):
				it.dusted = true
				shake = maxf(shake, 0.08)
				for j in 8:
					parts.append({p = Vector2(sx, gy), v = Vector2((j - 3.5) * 40.0, -40.0 - randf() * 50.0), t = 0.0, life = 0.4, col = Color(0.9, 0.85, 0.75, 0.7), r = 4.0, grav = 120.0})
		"drop":
			xf = Transform2D(0.0, Vector2(sx, gy - (1.0 - k * k) * 420.0))
		"swing":
			var top := gy - float(it.y) - minf(float(it.h), 600.0)
			var ang := (1.0 - k) * 1.1 * cos(k * PI * 2.0)
			xf = Transform2D(ang, Vector2(sx, top)) * Transform2D(0.0, Vector2(0, gy - top))
		"shake":
			var jit := (1.0 - k) * 6.0 * sin(t * 50.0)
			xf = Transform2D(0.0, Vector2(sx + jit, gy - (1.0 - G2.out_back(k)) * 90.0))
	cv.draw_set_transform_matrix(xf)
	TgArt.obstacle(cv, it, 0.0, 0.0, theme, t)
	cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 땅 덩어리 하나 — 땅 띠(풀 + 흙)를 덩어리 윗면 높이에 16px 조각으로 깔고, 그 밑은 흙 색으로 화면 아래까지. 옆면에 어두운 테.
func _draw_block(it: Dictionary, gtex: Texture2D, soil: Color, th: float, tw: float, surf: float) -> void:
	var x0 := float(it.x) - float(it.w) * 0.5
	var x1 := float(it.x) + float(it.w) * 0.5
	var white := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	var wx := x0
	while wx < x1:
		var seg := minf(16.0, x1 - wx)
		var p := _scr(wx, float(it.y))
		if p.x > -20.0 and p.x < vs.x / TgD.VIEW_ZOOM + 400.0:
			var ya := p.y - surf
			if gtex != null:
				var u0 := fposmod(wx, tw) / tw
				var u1 := u0 + seg / tw
				cv.draw_primitive(PackedVector2Array([Vector2(p.x, ya), Vector2(p.x + seg + 0.5, ya), Vector2(p.x + seg + 0.5, ya + th), Vector2(p.x, ya + th)]), white,
						PackedVector2Array([Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1)]), gtex)
			cv.draw_rect(Rect2(p.x, ya + th - 1.0, seg + 0.5, vs.y + 400.0 - ya), soil)
		wx += 16.0
	for ex in [x0, x1]:   # 옆면 — 흙 벽의 그늘
		var q := _scr(ex, float(it.y))
		cv.draw_rect(Rect2(q.x - 3.0, q.y - surf + 8.0, 6.0, vs.y + 400.0), Color(0, 0, 0, 0.35))


## 화면의 허공 칸 — wx 부터 16px 가 허공 안이면 가장 가까운 벼랑 끝까지의 거리(px), 아니면 -1.
func _void_edge(wx: float) -> float:
	for v: Array in g.voids:
		if wx + 8.0 > float(v[0]) and wx + 8.0 < float(v[1]):
			return minf(wx + 8.0 - float(v[0]), float(v[1]) - (wx + 8.0))
	return -1.0


## 준비 화면의 길 지도 — k 번째 구간의 점. 왼쪽에서 오른쪽으로 굽이치며 오른다(고갯길).
func _road_pt(k: int) -> Vector2:
	var n := TgD.ZONES.size()
	var f := float(k) / (n - 1)
	return Vector2(lerpf(90.0, vs.x - 90.0, f), lerpf(430.0, 230.0, f) + sin(f * TAU * 2.0) * 60.0)


## 가게 칸 — 라운드 고르기 화면 왼쪽 아래 네 칸.
func _shop_rect(i: int) -> Rect2:
	return Rect2(18 + i * 212, 600, 204, 100)


func _cost(i: int) -> int:
	return int(TgD.UPGRADES[i][2]) * (int(TgSv.up[i]) + 1)


func _buy(i: int) -> void:
	if int(TgSv.up[i]) >= int(TgD.UPGRADES[i][3]) or TgSv.coins < _cost(i):
		TgSnd.play("tick", 0.6)
		return
	TgSv.coins -= _cost(i)
	TgSv.up[i] = int(TgSv.up[i]) + 1
	if not no_save:
		TgSv.save_()
	TgSnd.play("lantern")


func _gauge_btn() -> Rect2:
	return Rect2(vs.x - 250, vs.y - 96, 232, 76)


func _oil_rect() -> Rect2:
	return Rect2(vs.x * 0.5 - 250, 22, 500, 26)


func _modal_btn(k: int) -> Rect2:
	return Rect2(vs.x * 0.5 - 250 + k * 260, vs.y * 0.5 + 30, 240, 64)


func _end_btn(k: int) -> Rect2:
	return Rect2(vs.x * 0.5 - 230 + k * 240, vs.y * 0.5 + 160, 220, 60)

# ==================== 입력 ====================

## 덤으로 듣는 키(방향키 · W · E …) — **키 설정에서 다른 일에 준 키는 덤에서 빠진다**(E 를 숙이기로 바꿨는데 호랑이 기운이 나갔다).
const ALT := {jump = [KEY_UP, KEY_W], slide = [KEY_DOWN, KEY_SHIFT], power = [KEY_KP_ENTER, KEY_E]}


func _key_of(action: String) -> int:
	for row: Array in KEYS:
		if String(row[0]) == action:
			return UiKeys.code("tiger", action, int(row[2]))
	return 0


func _alts(action: String) -> Array:
	var used := []
	for row: Array in KEYS:
		used.append(_key_of(String(row[0])))
	return (ALT[action] as Array).filter(func(k): return not used.has(k))


func _is(kc: int, action: String) -> bool:
	return kc == _key_of(action) or _alts(action).has(kc)


func _held(action: String) -> bool:
	if Input.is_physical_key_pressed(_key_of(action)) or Input.is_key_pressed(_key_of(action)):
		return true
	for k: int in _alts(action):
		if Input.is_physical_key_pressed(k):
			return true
	return false



func _unhandled_input(ev: InputEvent) -> void:
	if Vol.open:
		Vol.handle(ev, vs)
		return
	if ev is InputEventMouseMotion:
		mouse = ev.position
		return
	var key := ev as InputEventKey
	if key != null and key.pressed and not key.echo:
		if keys.key(key.keycode):
			return
		if rules.key(key.keycode):
			return
		var kc := key.keycode
		var in_play := scr == Scr.PLAY and g != null and not _paused()
		if kc == KEY_ESCAPE:
			_escape()
		elif _is(kc, "jump"):
			if in_play:
				if g.busy():
					g.skip_cine()
				else:
					g.jump()
			elif scr == Scr.TITLE and kc == KEY_SPACE:
				scr = Scr.PICK
		elif _is(kc, "power"):
			if in_play:
				if g.busy():
					g.skip_cine()
				else:
					g.awaken()
			elif scr == Scr.TITLE:
				scr = Scr.PICK
			elif scr == Scr.PICK:
				_start()
		elif kc == KEY_F2 and _can_auto():
			_toggle_auto()
		elif kc == KEY_H:
			show_box = not show_box
		return
	var mb := ev as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		mouse = mb.position
		if not mb.pressed:
			mouse_slide = false
			mouse_jump = false
			return
		_click(mb.position)


func _escape() -> void:
	match scr:
		Scr.TITLE:
			Hub.leave(self)
		Scr.PICK:
			scr = Scr.TITLE
		Scr.PLAY:
			if end_open:
				scr = Scr.PICK
			else:
				modal = "" if modal != "" else "quit"


func _click(p: Vector2) -> void:
	if keys.click(p, vs):
		return
	if rules.click(p, vs):
		return
	if _vol_btn().has_point(p):
		Vol.open = true
		return
	match scr:
		Scr.TITLE:
			if _back_btn().has_point(p):
				Hub.leave(self)
			elif Hub.std_rect("start", vs).has_point(p):
				scr = Scr.PICK
				TgSnd.play("tick")
			elif _rules_rect().has_point(p):
				_open_rules()
			elif UiKit.menu_rect(vs, 0).has_point(p):
				keys.show("tiger", KEYS)
		Scr.PICK:
			if _back_btn().has_point(p):
				scr = Scr.TITLE
			elif Hub.std_rect("start", vs).has_point(p):
				_start()
			else:
				for i in TgD.UPGRADES.size():   # 가게 — 엽전으로 강화
					if _shop_rect(i).has_point(p):
						_buy(i)
						return
		Scr.PLAY:
			_click_play(p)


func _click_play(p: Vector2) -> void:
	if end_open:
		if _end_btn(0).has_point(p):
			scr = Scr.PICK
		elif _end_btn(1).has_point(p):
			_start()
		return
	if modal == "quit":
		if _modal_btn(0).has_point(p):
			modal = ""
			scr = Scr.PICK
		elif _modal_btn(1).has_point(p):
			modal = ""
		return
	if _back_btn().has_point(p):
		modal = "quit"
		return
	if _can_auto() and _auto_btn().has_point(p):
		_toggle_auto()
		return
	if Hub.std_rect("rules", vs).has_point(p):   # 판에서도 규칙을 본다(그동안 멈춘다)
		_open_rules()
		return
	if g.over:
		return
	if g.busy():
		g.skip_cine()
	elif _gauge_btn().has_point(p):
		g.awaken()
	elif p.x < vs.x * 0.5:
		mouse_jump = true
		g.jump()
	else:
		mouse_slide = true

# ==================== 그리기 ====================


func _btn(r: Rect2, label: String, fill: Color, size: float = 24.0, on: bool = true) -> void:
	UiKit.plain(cv, r, label, fill, "tiger", t, on, size)


func _draw() -> void:
	cv = self
	Hub.compact = scr == Scr.PLAY   # 판 화면은 아이콘 단추
	match scr:
		Scr.TITLE:
			_draw_title()
		Scr.PICK:
			_draw_pick()
		Scr.PLAY:
			if g != null:
				_draw_play()   # 배경만 — 세상 · 글자판은 위 두 층
				return
	Vol.draw(cv, vs, t)


func _draw_world_layer() -> void:
	if scr != Scr.PLAY or g == null:
		return
	cv = _world
	_draw_play_world()
	cv = self


func _draw_top_layer() -> void:
	if scr != Scr.PLAY or g == null:
		return
	cv = _top
	_draw_play_top()
	Vol.draw(cv, vs, t)
	cv = self


func _draw_title() -> void:
	var bg := TgArt.img("tg_bg_title")
	if bg != null:
		cv.draw_texture_rect(bg, Rect2(Vector2.ZERO, vs), false)
	else:
		TgArt.bg(cv, vs.x, vs.y, 0, t * 60.0, t)
	var below := UiKit.title(cv, vs, "tiger", "떡 하나 주면 안 잡아먹지", "해와 달이 된 오누이의 그 호랑이가 고갯길을 달려요", t)
	if bg == null:   # 표지 그림에 호랑이가 이미 있다
		TgArt.fox(cv, Vector2(vs.x * 0.3, below + 190), t * 1.6, "run", false, false, t)
	if TgSv.plays > 0:   # 한 판도 안 달렸으면 기록 줄을 보이지 않는다
		UiKit.record_line(cv, vs, "최고 %s점, %dm" % [_num(TgSv.best_score), TgSv.best_m])
	UiKit.key_hint(cv, vs, "%s 점프, %s 숙이기, %s 호랑이 기운" % [OS.get_keycode_string(UiKeys.code("tiger", "jump", KEY_SPACE)),
			OS.get_keycode_string(UiKeys.code("tiger", "slide", KEY_S)), OS.get_keycode_string(UiKeys.code("tiger", "power", KEY_ENTER))])
	UiKit.button(cv, vs, "start", "tiger", t)
	UiKit.button(cv, vs, "hub", "tiger", t)
	UiKit.button(cv, vs, "vol", "tiger", t)
	UiKit.menu(cv, UiKit.menu_rect(vs, 0), "키 설정", Color8(60, 90, 140), "tiger", t)
	UiKit.plain(cv, _rules_rect(), "규칙", UiKit.theme("tiger").hub, "tiger", t, true, 24)
	rules.draw(cv, vs, t)
	keys.draw(cv, vs, t)


## 출발 준비 — 위: 최고 기록 · 길 지도(구간 열여섯, 가 본 곳은 밝게) · 아래: 가게. 늘 첫 구간부터 이어 달린다.
func _draw_pick() -> void:
	var far := maxi(0, TgSv.best_zone)
	TgArt.bg(cv, vs.x, vs.y, int(TgGame.zone_row(mini(far, TgD.ZONES.size() - 1))[1]), t * 40.0, t)
	cv.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.5))
	G2.text_mid(cv, Vector2(vs.x * 0.5, 50), "고갯길 이어 달리기", 32, TgArt.HEAD, 6)
	var rec := "아직 달린 기록이 없어요. 배가 바닥날 때까지 멀리 가 보세요" if TgSv.plays == 0 else \
			"최고 %s점    가장 멀리 %dm    %d. %s 까지" % [_num(TgSv.best_score), TgSv.best_m, TgSv.best_zone + 1, _zone_name(TgSv.best_zone)]
	G2.text_mid(cv, Vector2(vs.x * 0.5, 100), rec, 22, Color(1, 1, 1, 0.85), 0)
	# 길 지도 — 한 줄로 이어진 고갯길. 구간은 길 위의 점이고, 가 본 곳까지 길이 밝다(고르는 칸이 아니다 — 늘 처음부터 이어 달린다).
	# 예전 16칸 격자는 라운드 고르기 화면처럼 보였다(사용자 "라운드 없앤다고 하지 않았나?", 11-10)
	var n := TgD.ZONES.size()
	var pts := PackedVector2Array()
	for k in n:
		pts.append(_road_pt(k))
	for k in n - 1:   # 길 — 가 본 곳은 금빛, 아직은 흐린 점선
		var lit := k + 1 <= TgSv.best_zone
		if lit:
			cv.draw_line(pts[k], pts[k + 1], TgArt.EMBER, 8.0, true)
		else:
			for s in 6:
				cv.draw_line(pts[k].lerp(pts[k + 1], s / 6.0), pts[k].lerp(pts[k + 1], (s + 0.5) / 6.0), Color(1, 1, 1, 0.25), 4.0)
	for k in n:
		var row: Array = TgD.ZONES[k]
		var seen := k <= TgSv.best_zone
		var col: Color = (TgArt.GROUND[int(row[1])] as Color)
		cv.draw_circle(pts[k], 13.0, TgArt.INK)
		cv.draw_circle(pts[k], 10.0, col if seen else Color8(70, 64, 70))
		if seen and (k % 4 == 0 or k == TgSv.best_zone):   # 테마가 바뀌는 곳과 가장 멀리 간 곳만 이름(다 쓰면 붐빈다)
			G2.text_mid(cv, pts[k] + Vector2(0, -34 if k % 2 == 0 else 38), String(row[0]), 20, Color(1, 1, 1, 0.9), 4)
	var head := mini(maxi(TgSv.best_zone, 0), n - 1)
	TgArt.fox(cv, pts[head] + Vector2(0, -16), t * 1.6, "run", false, false, t) if TgSv.plays > 0 else TgArt.fox(cv, pts[0] + Vector2(0, -16), t * 1.6, "run", false, false, t)
	if TgSv.best_zone >= n:
		G2.text_mid(cv, Vector2(vs.x * 0.5, 500), "해와 달 너머 %d 구간까지 가 봤어요" % (TgSv.best_zone + 1 - n), 22, TgArt.EMBER, 4)
	# 가게 — 엽전으로 호랑이를 강화한다(달리며 주운 엽전)
	TgArt.coin(cv, Vector2(40, 572), t)
	G2.text_mid(cv, Vector2(110, 572), "엽전 %d" % TgSv.coins, 24, TgArt.EMBER, 5)
	for i in TgD.UPGRADES.size():
		var sr := _shop_rect(i)
		var u: Array = TgD.UPGRADES[i]
		var lv := int(TgSv.up[i])
		var full := lv >= int(u[3])
		var can := not full and TgSv.coins >= _cost(i)
		TgArt.rr(cv, sr, 12, Color8(60, 50, 44) if can else Color8(40, 36, 40), TgArt.EMBER if can else Color(1, 1, 1, 0.2), 3.0 if can else 1.5)
		G2.text_mid(cv, sr.position + Vector2(sr.size.x * 0.5, 22), "%s %d" % [String(u[0]), lv], 22, TgArt.HEAD, 0)
		G2.text_mid(cv, sr.position + Vector2(sr.size.x * 0.5, 50), String(u[1]), 20, Color(1, 1, 1, 0.7), 0)
		G2.text_mid(cv, sr.position + Vector2(sr.size.x * 0.5, 80), "끝까지 올림" if full else "엽전 %d" % _cost(i), 20, TgArt.EMBER if can else Color(1, 1, 1, 0.45), 0)
	UiKit.button(cv, vs, "start", "tiger", t, "달리기")
	UiKit.button(cv, vs, "hub", "tiger", t, "뒤로")
	UiKit.button(cv, vs, "vol", "tiger", t)


## 구간 이름 — 16 구간 뒤로 되풀이할 때는 "(두 바퀴째)" 를 붙인다.
func _zone_name(z: int) -> String:
	var r := TgGame.zone_row(maxi(0, z))
	if z < TgD.ZONES.size():
		return String(r[0])
	return "%s(%d바퀴째)" % [String(r[0]), 2 + (z - TgD.ZONES.size()) / 4]


## 큰 수에 쉼표.
func _num(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return ("-" if n < 0 else "") + out


func _star(c: Vector2, r: float, on: bool, k: float = 1.0) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		pts.append(c + Vector2.from_angle(-PI * 0.5 + i * PI / 5.0) * (r * k if i % 2 == 0 else r * k * 0.45))
	G2.fill_fan(cv, pts, TgArt.EMBER if on else Color(1, 1, 1, 0.14), c)
	if on:
		G2.stroke(cv, pts, TgArt.INK, 2.0)


## 놀이 화면은 세 층(11-10 — 사용자 "캐릭터 크기가 화면에서 차지하는 비율이 많이 다르다"):
##   이 노드 = 배경(하늘 · 먼 띠 · 가까운 띠, 확대 안 함) · `_world` = 땅 · 장애물 · 떡 · 호랑이 · 입자(**VIEW_ZOOM 배 확대**, 호랑이 발밑이 제자리) ·
##   `_top` = 어둠 · 번쩍임 · 컷인 · 글자판 · 창. 그리기 함수는 `cv`(지금 그리는 층)에 그린다. 규칙(판정 · 거리)은 확대를 모른다.
func _draw_play() -> void:
	var theme := int(g.row()[1])
	cv.draw_set_transform(soff)
	TgArt.bg(cv, vs.x, vs.y, theme, g.dist, t, cam * TgD.VIEW_ZOOM)   # 세상 층이 확대돼 있어 땅도 그만큼 더 내려간다 — 안 맞추면 배경의 땅 색이 풀 위로 띠처럼 보인다
	cv.draw_set_transform(Vector2.ZERO)


func _draw_play_world() -> void:
	var theme := int(g.row()[1])
	var off := soff
	cv.draw_set_transform(off)
	# 땅 — 풀 + 흙 띠(tg_ground_N)를 16px 조각으로 잘라 **땅의 높이를 따라 기울여** 잇는다(평지 · 언덕 · 산이 한 그림으로 이어진다). 띠 밑은 흙 색으로 화면 끝까지.
	# 예전엔 배경 띠의 맨 아래를 조각마다 들어 올렸는데, 계단처럼 끊기고 배경의 물건이 같이 밀려 보였다(사용자 지적 11-10).
	var gtex := TgArt.img("tg_ground_%d" % theme)
	var soil: Color = TgD.SOIL[theme] if gtex != null else TgArt.GROUND[theme]
	const TW := 640.0    # 띠 한 장의 화면 폭 — 조각(16)의 배수라 조각이 이음매에 안 걸친다
	const SURF := 25.0   # 띠 그림에서 풀 윗선까지(화면 px)
	var th := (TW * gtex.get_size().y / gtex.get_size().x) if gtex != null else 8.0
	var wx0 := floorf((g.dist - TgD.FOX_X - 16.0) / 16.0) * 16.0
	var white := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	for i in int(vs.x / 16.0) + 3:
		var wx := wx0 + i * 16.0
		var xa := TgD.FOX_X + wx - g.dist
		var ya := _gy(wx) - SURF
		var yb := _gy(wx + 16.0) - SURF
		# 허공 구간 — 땅을 끊고 낭떠러지(아래로 깊어지는 어둠 · 바닥의 창살)를 그린다. 예전엔 폭 130 구덩이 그림을 늘려 덩어리처럼 보였다(사용자 지적 11-10)
		var vd := _void_edge(wx)
		if vd >= 0.0:
			var top := _gy(wx) - 2.0   # 풀 윗선에 맞춘다(예전엔 띠 그림 위 끝 = 풀보다 25px 위라 낭떠러지만 높이 떠 보였다, 사용자 11-10). 예전 설명: 땅 그림의 풀 윗선부터 — 그 아래를 비워 두면 배경 그림 맨 아래의 길 띠가 비쳐 땅이 이어진 것처럼 보였다
			# 낭떠러지는 **아무것도 안 그린다** — 배경이 그대로 비친다(사용자 11-10 밤 "별도 색 말고 그냥 배경으로"). 벼랑 끝의 그늘만
			if vd < 16.0:
				cv.draw_rect(Rect2(xa - 2, top, 6, vs.y), Color(0, 0, 0, 0.35))
			continue
		if gtex != null:
			var u0 := fposmod(wx, TW) / TW
			var u1 := u0 + 16.0 / TW
			cv.draw_primitive(PackedVector2Array([Vector2(xa, ya), Vector2(xa + 16.5, yb), Vector2(xa + 16.5, yb + th), Vector2(xa, ya + th)]), white,
					PackedVector2Array([Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1)]), gtex)
		cv.draw_primitive(PackedVector2Array([Vector2(xa, ya + th - 1.0), Vector2(xa + 16.5, yb + th - 1.0), Vector2(xa + 16.5, vs.y + 60.0), Vector2(xa, vs.y + 60.0)]),
				PackedColorArray([soil, soil, soil, soil]), PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]))
	# 장애물 · 떡
	var plank := TgArt.img("tg_plank_%d" % theme)   # 테마마다 다른 발판(있으면) — 눈 산에 초록 풀 발판이 어색했다(사용자 11-10 밤)
	if plank == null:
		plank = TgArt.img("tg_plank")
	for it: Dictionary in g.items:
		if it.gone:
			continue
		if it.kind == "plank" and int(it.v) == 5:   # 땅 덩어리 — 땅 띠 그림을 그 높이에 깔고 밑은 흙으로 화면 끝까지(낭떠러지 위로 솟은 땅)
			_draw_block(it, gtex, soil, th, TW, SURF)
			continue
		if it.kind == "plank":   # 윗길 — 16px 조각으로 잘라 언덕을 따라 놓는다(양 끝은 그림의 끝, 가운데는 되풀이)
			var x0 := float(it.x) - float(it.w) * 0.5
			var ph := 46.0
			var tw := ph * 5.0
			for i in int(ceil(float(it.w) / 16.0)):
				var dd := i * 16.0
				var pp := _scr(x0 + dd, it.y)
				if it.has("crumble_t") and not it.has("falling"):   # 꺼지기 직전 — 덜덜 떤다
					pp += Vector2(randf_range(-3, 3), randf_range(-2, 2))
				if pp.x < -20.0 or pp.x > vs.x + 20.0:
					continue
				if plank == null:
					cv.draw_rect(Rect2(pp.x, pp.y, 16.5, 20.0), Color8(150, 100, 60))
					continue
				var u := 0.25 + fmod(dd - tw * 0.25, tw * 0.5) / tw
				if dd < tw * 0.25:
					u = dd / tw
				elif dd > float(it.w) - tw * 0.25:
					u = 1.0 - (float(it.w) - dd) / tw
				var ts := plank.get_size()
				cv.draw_texture_rect_region(plank, Rect2(pp.x, pp.y - ph * 0.2, 16.5, ph), Rect2(u * ts.x, 0, 16.0 / tw * ts.x, ts.y))
			continue
		var sx := _scr(it.x, 0).x
		if sx < -120 or sx > vs.x + 120:
			continue
		match String(it.kind):
			"ember":
				TgArt.candy(cv, _scr(it.x, it.y), t, false, int(it.v))
			"big":
				TgArt.big_tteok(cv, _scr(it.x, it.y), t, float(it.get("sz", 1.0)))
			"bigcoin":
				TgArt.big_coin(cv, _scr(it.x, it.y), t)
			"kkochi":
				TgArt.lollipop(cv, _scr(it.x, it.y), t)
			"coin":
				TgArt.coin(cv, _scr(it.x, it.y), t)
			"honey", "sansam", "club", "rope", "box":
				TgArt.item(cv, String(it.kind), _scr(it.x, it.y), t)
			_:
				var en := String(it.get("enter", "drop" if bool(it.get("late", false)) and it.kind == "high" else ("rise" if bool(it.get("late", false)) else "")))
				if en != "":
					_draw_enter(it, en, sx, theme)
					continue
				TgArt.obstacle(cv, it, sx, _gy(it.x), theme, t)
	if g.boss() or goblin_k > 0.01:
		TgArt.goblin(cv, Vector2(-70 + goblin_k * 250, _gy(g.dist - 370.0 + goblin_k * 250.0)), goblin_k, t)
	var feet := _fox_feet()
	var ok := g.oil / TgD.OIL_MAX
	var state := "slide" if g.sliding else ("jump" if not g.on_ground() else "run")
	var blink := g.inv_t > 0.0 and not g.dashing() and fmod(t, 0.16) < 0.08
	if g.flying():   # 하늘 보너스 — 동아줄을 타고 난다. 흰 띠가 지금 떡 물결 높이를 가리킨다
		cv.draw_line(feet + Vector2(0, -80), Vector2(feet.x + 40, -20), Color8(230, 190, 110), 6.0)
		state = "jump"
	# 땅에 있을 때는 비탈을 따라 몸이 기운다. 산삼을 먹었으면 발을 기준으로 크게
	var tilt := -atan((g.ground_h(g.dist + 24.0) - g.ground_h(g.dist - 24.0)) / 48.0) if g.on_ground() else 0.0
	var gk := TgD.GIANT_K if g.giant() else 1.0
	if g.pit_fall and int(g.pit_it.get("v", 0)) < 8:   # 작은 구덩이 — 구멍 속으로 작아지며 빨려 든다(땅 그림 위로 떨어지는 것처럼 보이지 않게)
		gk *= clampf(1.0 + g.fox_y / 150.0, 0.0, 1.0)
		feet.y = _gy(g.dist) - maxf(g.fox_y, -40.0)
	cv.draw_set_transform(feet + off, tilt, Vector2(gk, gk))
	TgArt.fox(cv, Vector2.ZERO, g.run_phase, state, g.dashing(), blink and (not g.giant() or g.giant_t < 0.8), t)
	cv.draw_set_transform(off)
	# 빨려 드는 떡 · 엽전 · 꼬치 — 먹은 자리에서 호랑이 입으로 점점 빨라지며 휘어 들어가고 작아진다. 입에 닿을 때 작은 반짝
	var mouth := feet + Vector2(26.0 * gk, -g.fox_h() * 0.62)   # 숙이면 입도 낮다
	for s: Dictionary in sucks:
		var k := clampf(float(s.t) / SUCK_T, 0.0, 1.0)
		var e := k * k   # 처음엔 천천히, 갈수록 빨리
		var p0: Vector2 = s.p
		var bend := Vector2(0, -40.0) * sin(k * PI) * (1.0 if p0.y > mouth.y else -0.5)
		var at := p0.lerp(mouth, e) + bend
		var sc := lerpf(1.0, 0.25, e)
		cv.draw_set_transform(at + off, k * 3.0, Vector2(sc, sc))
		match String(s.kind):
			"ember":
				TgArt.candy(cv, Vector2.ZERO, t)
			"coin":
				TgArt.coin(cv, Vector2.ZERO, t)
			"big":
				TgArt.big_tteok(cv, Vector2.ZERO, t)
			"bigcoin":
				TgArt.big_coin(cv, Vector2.ZERO, t)
			_:
				TgArt.lollipop(cv, Vector2.ZERO, t)
		cv.draw_set_transform(off)
		if k > 0.85:
			cv.draw_circle(mouth, 6.0 + (k - 0.85) * 60.0, Color(1, 0.95, 0.75, (1.0 - k) * 4.0))
	if not g.dashing() and not g.over:   # 늘 흐르는 옅은 속도선 — 빠를수록 짙다(사용자 "속도감이 떨어진다")
		var sk := clampf((g.speed - 450.0) / 400.0, 0.15, 1.0)
		for j in 7:
			var ly2 := fposmod(j * 83.0 + 40.0, TgD.GROUND_Y - 120.0) + 70.0
			var lx2 := vs.x - fposmod(t * (1100.0 + j * 70.0) + j * 257.0, vs.x + 300.0)
			cv.draw_line(Vector2(lx2, ly2), Vector2(lx2 + 70.0 + j * 8.0, ly2), Color(1, 1, 1, 0.12 * sk), 2.0)
	if g.dashing():   # 속도선 — 화면을 가로지르는 흰 줄, 호랑이 뒤로 흐른다
		for j in 12:
			var ly := fposmod(j * 67.0, TgD.GROUND_Y - 80.0) + 60.0
			var lx := vs.x - fposmod(t * (1500.0 + j * 90.0) + j * 311.0, vs.x + 300.0)
			cv.draw_line(Vector2(lx, ly), Vector2(lx + 120.0 + j * 10.0, ly), Color(1, 1, 1, 0.35), 3.0)
	if show_box:
		_draw_boxes()
	# 입자 · 고리 · 떠오르는 글
	for p: Dictionary in parts:
		var a := 1.0 - float(p.t) / float(p.life)
		cv.draw_circle(p.p, float(p.r) * (0.5 + 0.5 * a), Color(p.col, a * (p.col as Color).a))
	for r: Dictionary in rings:
		if r.t < 0.0:
			continue
		var k := float(r.t) / float(r.dur)
		cv.draw_arc(r.p, 20.0 + k * 260.0, 0, TAU, 48, Color(r.col, 1.0 - k), 10.0 * (1.0 - k) + 1.0)
	for p: Dictionary in pops:
		var k2 := float(p.t) / 0.9
		G2.text_mid(cv, p.p + Vector2(0, -40.0 * k2), String(p.txt), 26, Color(p.col, 1.0 - k2 * k2), 5)
	cv.draw_set_transform(Vector2.ZERO)


func _draw_play_top() -> void:
	var ok := g.oil / TgD.OIL_MAX
	# 체력이 적으면 가장자리가 어두워진다
	if ok < 0.3 and not g.over:
		var dk := (0.3 - ok) / 0.3
		for j in 6:
			var w := 40.0 * (j + 1)
			var a2 := 0.09 * dk
			cv.draw_rect(Rect2(0, 0, w, vs.y), Color(0, 0, 0, a2))
			cv.draw_rect(Rect2(vs.x - w, 0, w, vs.y), Color(0, 0, 0, a2))
	if g.over:   # 배가 고파 멈췄다
		cv.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, minf(0.75, end_t * 0.8)))
	if flash > 0.0:
		cv.draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 0.92, 0.7, flash * 0.6))
	if g.busy():
		_draw_cine()
	_draw_hud()
	if modal == "quit":
		_draw_modal("달리기를 그만둘까요?", ["그만두기", "계속하기"])
	if end_open:
		_draw_end()
	rules.draw(cv, vs, t)


## 판정 상자 — 호랑이 몸(초록, 맞으면 잠깐 빨강) · 장애물(빨강) · 구덩이(보라) · 떡과 물건(노랑 원). 보이는 그림과 닿는 자리를 맞춰 볼 때 쓴다(H).
func _draw_boxes() -> void:
	var fr := g.fox_rect()
	var fs := Rect2(_scr(fr.position.x, fr.end.y), fr.size)
	cv.draw_rect(fs, Color(1, 0.2, 0.2, 0.35) if hit_flash > 0.0 else Color(0.2, 1, 0.3, 0.2))
	cv.draw_rect(fs, Color(1, 0.2, 0.2) if hit_flash > 0.0 else Color(0.2, 1, 0.3), false, 2.0)
	for it: Dictionary in g.items:
		if it.gone or absf(float(it.x) - g.dist) > 1100.0:
			continue
		match String(it.kind):
			"low", "high", "tall", "flyer", "roller":
				var hh := minf(float(it.h), 700.0)
				cv.draw_rect(Rect2(_scr(float(it.x) - float(it.w) * 0.5, float(it.y) + hh), Vector2(it.w, hh)), Color(1, 0.2, 0.2), false, 2.0)
			"plank":
				continue
			"pit":
				var hw := float(it.w) * 0.5 - 12.0
				cv.draw_rect(Rect2(_scr(float(it.x) - hw, 0.0), Vector2(hw * 2.0, 14)), Color(0.8, 0.3, 1), false, 2.0)
			"ember", "coin":
				cv.draw_arc(_scr(it.x, it.y), 18.0, 0, TAU, 16, Color(1, 0.9, 0.2), 1.5)
			_:
				cv.draw_arc(_scr(it.x, it.y), 30.0 if it.kind != "kkochi" else 28.0, 0, TAU, 20, Color(1, 0.9, 0.2), 2.0)
	G2.text_mid(cv, Vector2(vs.x * 0.5, vs.y - 24), "판정 상자 보기 (H 로 끄기)", 20, Color(1, 1, 1, 0.8), 4)


## 호랑이 기운 컷인 — 한 타임라인(0~1.2초)에 어두워짐 · 위아래 띠 · 큰 호랑이 · 붉은 기운 아홉 갈래 · 글자 · 끝에 섬광. 누르면 넘어간다.
func _draw_cine() -> void:
	var k := 1.0 - g.cine_t / TgD.CINE_T
	cv.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.04, 0.01, 0.02, 0.8 * minf(k / 0.15, 1.0)))
	var bar := 70.0 * G2.out_cubic(k / 0.2)
	cv.draw_rect(Rect2(0, 0, vs.x, bar), Color.BLACK)
	cv.draw_rect(Rect2(0, vs.y - bar, vs.x, bar), Color.BLACK)
	var c := Vector2(vs.x * 0.5, vs.y * 0.52)
	# 뒤의 방사 섬광(그림 tg_fx_burst) — 천천히 돌며 커진다. 없으면 붉은 줄 아홉
	# 컷인 그림(tg_cine, GPT) — 화면을 꽉 채운 한 장이 왼쪽에서 밀려 들어오며 크게 잡혔다가 물러난다. 처음 절반은 떨린다. 없으면 예전 조합(섬광 + 호랑이)
	var pic := TgArt.img("tg_cine")
	if pic != null:
		var ps := pic.get_size()
		var sc := maxf(vs.x / ps.x, vs.y / ps.y) * lerpf(1.35, 1.06, G2.out_cubic(minf(k / 0.4, 1.0)))
		var jit := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 12.0 * maxf(0.0, 1.0 - k / 0.5)
		var at := (vs - ps * sc) * 0.5 + Vector2((1.0 - G2.out_cubic(minf(k / 0.22, 1.0))) * -vs.x * 0.6, 0) + jit
		cv.draw_texture_rect(pic, Rect2(at, ps * sc), false, Color(1, 1, 1, minf(k / 0.1, 1.0)))
		for j in 10:   # 가로로 스치는 흰 줄
			var lx := vs.x - fposmod(t * (2600.0 + j * 170.0) + j * 377.0, vs.x + 500.0)
			cv.draw_line(Vector2(lx, 90.0 + j * 56.0), Vector2(lx + 260.0, 90.0 + j * 56.0), Color(1, 1, 1, 0.35), 3.0)
		cv.draw_rect(Rect2(0, 0, vs.x, bar), Color.BLACK)
		cv.draw_rect(Rect2(0, vs.y - bar, vs.x, bar), Color.BLACK)
	var burst := TgArt.img("tg_fx_burst")
	if pic != null:
		pass
	elif burst != null:
		var bk := G2.out_back(clampf((k - 0.1) / 0.3, 0.0, 1.0))
		for j in 2:
			cv.draw_set_transform(c, t * (0.5 if j == 0 else -0.3), Vector2.ONE * bk * (1.9 if j == 0 else 1.3))
			cv.draw_texture_rect(burst, Rect2(-256, -256, 512, 512), false, Color(1, 1, 1, 0.9 if j == 0 else 0.6))
		cv.draw_set_transform(Vector2.ZERO)
	else:
		for j in 9:
			var open := clampf((k - 0.15 - j * 0.04) / 0.2, 0.0, 1.0)
			if open <= 0.0:
				continue
			var a := -PI * 0.5 + (j - 4) * 0.3
			cv.draw_line(c, c + Vector2.from_angle(a) * 330.0 * G2.out_back(open), Color(TgArt.FLAME, 0.85), 26.0)
	# 포효 물결 — 호랑이 입에서 퍼지는 고리 셋
	for j in 3:
		var rk := fposmod(k * 2.2 - j * 0.33, 1.0)
		if k > 0.3:
			cv.draw_arc(c + Vector2(40, -20), 120.0 + rk * 520.0, -0.9, 0.9, 40, Color(1, 0.95, 0.8, (1.0 - rk) * 0.8), 14.0 * (1.0 - rk) + 2.0)
	# 큰 호랑이 — 왼쪽에서 밀려 들어온다
	var slide_in := G2.out_cubic(k / 0.3)
	if pic == null:
		cv.draw_set_transform(Vector2(lerpf(-200.0, vs.x * 0.5 - 20.0, slide_in), vs.y * 0.52 + 150.0), 0.0, Vector2(2.3, 2.3))
		TgArt.fox(cv, Vector2.ZERO, t * 2.0, "jump", false, false, t)
		cv.draw_set_transform(Vector2.ZERO)
	if k > 0.3:
		var ta := minf((k - 0.3) / 0.15, 1.0)
		UiKit._str(cv, UiKit.title_font("tiger"), Vector2(vs.x * 0.5, 130), "호랑이 기운", 96, Color(TgArt.HEAD, ta), 10, Color(TgArt.FLAME.darkened(0.4), ta))
	if k > 0.88:
		cv.draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 0.95, 0.8, (k - 0.88) / 0.12))
	# 진행 띠
	cv.draw_rect(Rect2(80, vs.y - 30, vs.x - 160, 4), Color(1, 1, 1, 0.2))
	cv.draw_rect(Rect2(80, vs.y - 30, (vs.x - 160) * k, 4), TgArt.EMBER)


func _draw_hud() -> void:
	# 체력 막대 — 떡 아이콘 + 막대, 20 아래면 붉게 떨린다
	var r := _oil_rect()
	var ok := g.oil / TgD.OIL_MAX
	var low := ok < 0.2
	var jit := Vector2(sin(t * 40.0) * 2.0, 0) if low and not g.over else Vector2.ZERO
	TgArt.rr(cv, Rect2(r.position + jit, r.size).grow(4), 10, Color(0, 0, 0, 0.55), Color(1, 1, 1, 0.25), 1.5)
	cv.draw_rect(Rect2(r.position + jit, Vector2(r.size.x * ok, r.size.y)), Color8(240, 80, 60) if low else TgArt.EMBER)
	TgArt.candy(cv, r.position + Vector2(-30, 13) + jit, t, true)
	# 구간 막대 — 이번 구간 안에서 얼마나 왔나(끝에 다음 구간). 이어 달리기라 결승선이 아니다
	var pr := Rect2(r.position.x, r.end.y + 16, r.size.x, 6)
	cv.draw_rect(pr, Color(1, 1, 1, 0.25))
	cv.draw_rect(Rect2(pr.position, Vector2(pr.size.x * g.progress(), pr.size.y)), TgArt.PAPER)
	cv.draw_circle(Vector2(pr.position.x + pr.size.x * g.progress(), pr.get_center().y), 8, TgArt.FOX)
	G2.text_mid(cv, Vector2(r.position.x - 150, r.get_center().y + 46), "%d. %s" % [g.zone + 1, _zone_name(g.zone)], 22, Color(1, 1, 1, 0.85), 4)
	# 점수 — 오른쪽 위에 크게, 그 밑에 거리 · 떡 · 엽전
	G2.text_mid(cv, Vector2(r.end.x + 110, r.get_center().y), _num(g.score()), 30, TgArt.HEAD, 6)
	G2.text_mid(cv, Vector2(r.end.x + 110, r.get_center().y + 38), "%dm   떡 %d" % [g.meters(), g.embers], 20, Color(1, 1, 1, 0.8), 4)
	TgArt.coin(cv, Vector2(r.end.x + 60, r.get_center().y + 72), t)
	G2.text_mid(cv, Vector2(r.end.x + 100, r.get_center().y + 72), str(g.coins), 20, TgArt.EMBER, 4)
	if g.mult >= 2:   # 겹치기 중
		G2.text_mid(cv, Vector2(TgD.FOX_X, 120), "겹치기 x%d" % g.mult, 34 + sin(t * 10.0) * 2.0, Color8(255, 150, 210), 6)
	# 구간 이름 띠 — 구간이 바뀔 때 2.4초
	if banner_t < 2.4:
		var a := minf(1.0, banner_t / 0.25) * minf(1.0, (2.4 - banner_t) / 0.4)
		var by := 190.0
		cv.draw_rect(Rect2(0, by - 34, vs.x, 68), Color(0, 0, 0, 0.45 * a))
		UiKit._str(cv, UiKit.title_font("tiger"), Vector2(vs.x * 0.5, by), "%d. %s" % [g.zone + 1, _zone_name(g.zone)], 44, Color(TgArt.HEAD, a), 8, Color(0, 0, 0, 0.6 * a))
	# 호랑이 기운 게이지 단추 — 차면 불빛이 돈다
	var gb := _gauge_btn()
	var gk := float(g.gauge) / g.need
	var full := gk >= 1.0
	TgArt.rr(cv, gb, 16, Color8(50, 44, 50), TgArt.EMBER if full else Color(1, 1, 1, 0.25), 4.0 if full else 2.0)
	cv.draw_rect(Rect2(gb.position.x + 8, gb.end.y - 16, (gb.size.x - 16) * gk, 8), TgArt.FLAME if full else TgArt.EMBER.darkened(0.3))
	if full:
		for j in 6:
			var a := t * 3.0 + j * TAU / 6.0
			cv.draw_circle(gb.get_center() + Vector2(cos(a) * gb.size.x * 0.46, sin(a) * gb.size.y * 0.4), 4.0, TgArt.EMBER)
	if g.dashing():
		cv.draw_rect(Rect2(gb.position.x + 8, gb.end.y - 16, (gb.size.x - 16) * g.dash_t / TgD.DASH_T, 8), Color(1, 1, 1))
	G2.text_mid(cv, gb.get_center() + Vector2(0, -8), "호랑이 기운 %s" % OS.get_keycode_string(UiKeys.code("tiger", "power", KEY_ENTER)) if full else "호랑이 기운 %d / %d" % [g.gauge, g.need], 24,
			TgArt.HEAD if full else Color(1, 1, 1, 0.6), 4)
	UiKit.button(cv, vs, "hub", "tiger", t, "나가기")
	UiKit.button(cv, vs, "rules", "tiger", t)
	UiKit.button(cv, vs, "vol", "tiger", t)
	if _can_auto():   # 테스트 빌드만 — 자동 주행 단추(켜져 있으면 금빛)
		_btn(_auto_btn(), "자동 주행 켬 (F2)" if auto_drive else "자동 주행 (F2)", TgArt.EMBER.darkened(0.2) if auto_drive else Color8(60, 90, 140), 20)


func _draw_modal(q: String, labels: Array) -> void:
	cv.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.55))
	var c := vs * 0.5
	TgArt.rr(cv, Rect2(c.x - 300, c.y - 110, 600, 240), 22, Color8(50, 44, 50), TgArt.EMBER, 4.0)
	G2.text_mid(cv, Vector2(c.x, c.y - 40), q, 30, TgArt.HEAD, 5)
	_btn(_modal_btn(0), String(labels[0]), Color8(60, 90, 140), 24)
	_btn(_modal_btn(1), String(labels[1]), UiKit.theme("tiger").start, 24)


## 결과 창 — 별이 0.35초 간격으로 하나씩 커졌다 박히고, 점수가 굴러 올라간다.
func _draw_end() -> void:
	cv.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.6))
	var c := vs * 0.5
	var r := Rect2(c.x - 360, c.y - 240, 720, 480)
	TgArt.rr(cv, r, 26, Color8(50, 44, 50), TgArt.EMBER, 4.0)
	G2.text_mid(cv, Vector2(c.x, r.position.y + 60), "떡이 없으면 잡아먹지", 48, TgArt.HEAD, 8)
	# 결과 그림 — 배가 고파 "잡아먹겠다" 덤비는 호랑이. 두 칸을 번갈아 보여 움직인다(사용자 요청 11-10). 아주 멀리 갔으면 배부른 호랑이
	var far := g.zone >= TgD.ZONES.size() - 1
	var pic := TgArt.img(("tg_end_win_%d" if far else "tg_end_fail_%d") % (int(end_t * 1.6) % 2))
	if pic != null:
		var ps := pic.get_size()
		var k := 250.0 / maxf(ps.x, ps.y) * G2.out_back(clampf(end_t / 0.4, 0.0, 1.0))
		var bob := sin(end_t * 5.0) * 4.0
		cv.draw_texture_rect(pic, Rect2(Vector2(r.position.x - 136, c.y + 40 + bob) - ps * k * 0.5, ps * k), false)
	# 어디까지 갔나 · 점수가 굴러 올라간다 · 새 기록은 금빛 꼬리표
	G2.text_mid(cv, Vector2(c.x, r.position.y + 132), "%d. %s 까지  %dm" % [g.zone + 1, _zone_name(g.zone), g.meters()], 30, TgArt.HEAD, 5)
	var roll := clampf((end_t - 0.3) / 1.0, 0.0, 1.0)
	G2.text_mid(cv, Vector2(c.x, r.position.y + 200), "%s점" % _num(int(g.score() * G2.out_cubic(roll))), 52, TgArt.EMBER, 7)
	var tags := []
	if fresh.get("score", false):
		tags.append("최고 점수")
	if fresh.get("m", false):
		tags.append("최고 거리")
	if fresh.get("zone", false) and g.zone > 0:
		tags.append("처음 가 본 구간")
	if not tags.is_empty() and end_t > 1.2:
		G2.text_mid(cv, Vector2(c.x, r.position.y + 252), "새 기록!  " + ", ".join(tags), 24, Color8(255, 220, 120), 5)
	var line := "떡 %d   무지개떡 %d   꼬치 %d / %d   엽전 %d   부딪힘 %d번%s" % [g.embers, g.bigs, g.lanterns, g.lanterns_all, g.coins, g.hits,
			"" if g.best_mult < 2 else "   겹치기 최고 x%d" % g.best_mult]
	G2.text_mid(cv, Vector2(c.x, r.position.y + 296), line, 20, Color(1, 1, 1, 0.75), 0)
	_btn(_end_btn(0), "준비 화면", Color8(60, 90, 140), 24)
	_btn(_end_btn(1), "다시 달리기", UiKit.theme("tiger").start, 24)

# ==================== 확인용 ====================


## `--tg-click-test` — 처음 → 라운드 고르기 → 달리기 → Space 점프 → Esc 창 → 그만두기 를 **진짜 마우스 · 키 이벤트**로. 실패하면 종료 코드 1.
func _click_test_step(dt: float) -> void:
	_ct += dt
	if _ct < 0.3:
		return
	_ct = 0.0
	var steps := [
		[func(): _press(Hub.std_rect("start", vs).get_center()), func(): return scr == Scr.PICK, "준비 화면"],
		[func(): _press(Hub.std_rect("start", vs).get_center()), func(): return scr == Scr.PLAY, "달리기 시작"],
		[func(): _key(KEY_SPACE), func(): return g != null and (g.fox_y > 0.0 or g.dist > 600.0), "점프"],
		[func(): _key(KEY_F2) if OS.has_feature("testbuild") else null, func(): return auto_drive or not OS.has_feature("testbuild"), "자동 주행 켜기(테스트 빌드)"],
		[func(): _press(_auto_btn().get_center()) if OS.has_feature("testbuild") else null, func(): return not auto_drive, "자동 주행 끄기(단추)"],
		[func(): _press(_back_btn().get_center()), func(): return modal == "quit", "그만둘까요 창"],
		[func(): _press(_modal_btn(0).get_center()), func(): return scr == Scr.PICK, "그만두기"],
	]
	var i := _cs / 2
	if i >= steps.size():
		print("TG CLICK TEST OK")
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
	_wait += 0.3
	if _wait < 10.0:
		return
	printerr("TG CLICK TEST FAIL: %s" % steps[i][2])
	get_tree().quit(1)


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


func _key(code: int) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)


## 자동 주행은 테스트 빌드에서만(확인용 실행 --tg-auto 는 따로). 정식판에는 단추도 키도 없다.
func _can_auto() -> bool:
	return OS.has_feature("testbuild") and scr == Scr.PLAY and g != null and not g.over


func _auto_btn() -> Rect2:
	return Rect2(18, vs.y - 76, 230, 58)


func _toggle_auto() -> void:
	auto_drive = not auto_drive
	mouse_slide = false
	mouse_jump = false
	g.slide(false)
	pops.append({p = Vector2(vs.x * 0.5, 260), txt = "자동 주행 켬" if auto_drive else "자동 주행 끔 — 손으로", col = TgArt.EMBER, t = 0.0})
	TgSnd.play("tick")


## 처음 화면의 [규칙] 단추 — 음량 왼쪽(아홉 게임 같은 자리).
func _rules_rect() -> Rect2:
	return Rect2(Hub.std_rect("vol", vs).position.x - 150, Hub.std_rect("vol", vs).position.y, 136, Hub.std_rect("vol", vs).size.y)


func _open_rules() -> void:
	rules.show("tiger", "떡 하나 주면 안 잡아먹지 규칙", TgRules.pages())
