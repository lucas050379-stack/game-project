class_name SaHud
extends RefCounted

## 세로 화면의 표시 — 위 점수 띠 · 좌우 여백 · 아래 단추 띠 · 플레이필드 위 보스 막대와 배너.
##
## 갈루가는 가로 창이라 점수 · 파워 · 봄을 전부 **옆 패널**에 뒀다. 세로 화면에서는 옆이 좁아서
## 위(점수 · 진행 · 잔기 · 파워)와 아래(스킬 · 봄 단추)로 나눴다. **플레이필드 안에는 아무것도
## 겹쳐 놓지 않는다** — 탄을 가려서, 가려진 자리에서 죽는다. 보스 막대만 예외(위쪽 끝에 얇게).
##
## 위 띠 · 아래 띠는 **화면 px** 로 그린다(배율 없음). 보스 막대와 배너는 `over` 레이어라
## 월드와 같은 논리 좌표다.

const PAD := 18.0


## 플레이필드 좌우 여백 — 가로줄 무늬로 필드와 결을 달리한다.
static func gutters(ci: CanvasItem, play: Rect2, vs: Vector2) -> void:
	for side in 2:
		var x0 := 0.0 if side == 0 else play.end.x
		var x1 := play.position.x if side == 0 else vs.x
		if x1 - x0 < 2.0:
			continue
		var y := play.position.y + 6.0
		while y < play.end.y:
			ci.draw_line(Vector2(x0, y), Vector2(x1, y), SaP.a(SaP.DIM, 0.05), 1.0)
			y += 9.0
	ci.draw_line(Vector2(play.position.x - 0.5, play.position.y), Vector2(play.position.x - 0.5, play.end.y),
			SaP.a(SaP.DIM, 0.3), 1.0)
	ci.draw_line(Vector2(play.end.x + 0.5, play.position.y), Vector2(play.end.x + 0.5, play.end.y),
			SaP.a(SaP.DIM, 0.3), 1.0)


## 위 띠 — 왼쪽 점수 · 라운드, 오른쪽 잔기 · 파워, 아래 끝에 진행 막대.
## 위 띠 — 왼쪽 점수 · 라운드, 오른쪽 잔기 · 파워, 아래 끝에 진행 막대.
## **글자는 폰 기준 크기입니다**(캔버스 720 이 폰에서는 절반쯤으로 보입니다 — 20 미만은 읽기 힘듭니다).
static func top_bar(ci: CanvasItem, vs: Vector2, h: float, w: SaWorld) -> void:
	ci.draw_rect(Rect2(0, 0, vs.x, h), Color(0.035, 0.05, 0.08, 1.0), true)
	ci.draw_line(Vector2(0, h - 0.5), Vector2(vs.x, h - 0.5), SaP.a(SaP.DIM, 0.3), 1.0)
	var col := w.craft_col()
	SaG2.text(ci, Vector2(PAD, 48), "1P", 24.0, SaP.hdr(SaP.GOLD, 1.1))
	SaG2.text(ci, Vector2(PAD + 50, 50), SaP.n(w.score), 44.0, SaP.WHITE)
	SaG2.text(ci, Vector2(PAD, 94), SaD.ROUND[w.round_i].name, 24.0, SaP.DIM)
	SaG2.text(ci, Vector2(PAD, 126), SaD.DIFF[w.diff].name, 22.0, SaP.hdr(SaP.GOLD, 1.0))
	if SaD.test_build():
		SaG2.text(ci, Vector2(PAD + 110, 126), "TEST  B 보스", 20.0, SaP.hdr(SaP.FOE_MARK, 1.1))

	var rx := vs.x - PAD
	# 잔기 — 작은 기체 그림
	for i in maxi(0, w.lives):
		SaArt.craft(ci, w.craft, Vector2(rx - 20 - i * 44, 36), w.t, 0.75)
	# 파워 칸
	SaG2.text_right(ci, Vector2(rx, 96), "POWER %d / %d" % [w.power, SaD.POWER_MAX], 22.0, SaP.DIM)
	for i in SaD.POWER_MAX + 1:
		var r := Rect2(rx - (SaD.POWER_MAX + 1 - i) * 32.0 + 4.0, 110, 26, 14)
		ci.draw_rect(r, SaP.hdr(col, 1.15) if i <= w.power else SaP.a(SaP.DIMMER, 0.3), true)

	var bar := Rect2(0, h - 6, vs.x, 5)
	ci.draw_rect(bar, SaP.a(SaP.DIMMER, 0.35), true)
	ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * w.prog, bar.size.y)), SaP.hdr(SaP.GOLD, 1.05), true)


## 아래 띠 — 왼쪽 스킬 단추(누르고 있다가 떼기), 오른쪽 봄 단추, 가운데 기체 · 서브기체.
##
## **스킬 단추 안에 게이지를 그린다.** 손가락이 거기 있으니 얼마나 찼는지도 거기서 읽혀야
## 언제 뗄지 안다. 기체 둘레의 고리(`SaArt.charge_ring`)는 원본 그대로 같이 뜬다.
static func controls(ci: CanvasItem, vs: Vector2, h: float, skill_r: Rect2, bomb_r: Rect2,
		holding: bool, w: SaWorld) -> void:
	ci.draw_rect(Rect2(0, vs.y - h, vs.x, h), Color(0.035, 0.05, 0.08, 1.0), true)
	ci.draw_line(Vector2(0, vs.y - h + 0.5), Vector2(vs.x, vs.y - h + 0.5), SaP.a(SaP.DIM, 0.3), 1.0)
	buttons(ci, skill_r, bomb_r, holding, w)
	var col := w.craft_col()
	var c: Dictionary = SaD.CRAFT[w.craft]
	# ---- 가운데: 기체 · 서브기체 ----
	var mx := vs.x * 0.5
	var my := vs.y - h + 50.0
	SaG2.text_mid(ci, Vector2(mx, my), c.name, 26.0, SaP.hdr(col, 1.05))
	SaG2.text_mid(ci, Vector2(mx, my + 38), "서브기체 %d대" % w.opts.size(), 21.0, SaP.DIM)
	SaG2.text_mid(ci, Vector2(mx, my + 72), "끌어서 이동", 20.0, SaP.DIMMER)


## 가로 화면 좌우 정보창 — 판 하나로 묶는다. 왼쪽 점수 · 라운드 · 기체 · 조작법, 오른쪽 잔기 · 파워 · 진행 · 보스 체력.
## 필드 위에는 아무것도 안 얹는다(보스 막대가 보스 윗부분을 가렸다). 단추는 `buttons`.
static func sides(ci: CanvasItem, vs: Vector2, play: Rect2, w: SaWorld) -> void:
	var col := w.craft_col()
	var c: Dictionary = SaD.CRAFT[w.craft]
	var lp := Rect2(8, 8, play.position.x - 16, vs.y - 16)
	var rp := Rect2(play.end.x + 8, 8, vs.x - play.end.x - 16, vs.y - 16)
	for r: Rect2 in [lp, rp]:
		ci.draw_rect(r, Color(0.04, 0.06, 0.1, 1.0), true)
		# 금속 판 그림(sky_bg_side)을 아주 어둡게 깐다 — 위에 글 · 단추가 얹히므로 무늬만 비친다
		var side := SaArt.img("sky_bg_side")
		if side != null:
			ci.draw_texture_rect(side, r, false, Color(0.42, 0.46, 0.55))
		ci.draw_rect(r, SaP.a(SaP.DIM, 0.28), false, 1.5)
	var lx := lp.position.x + 16.0
	var cx := lp.get_center().x
	SaG2.text(ci, Vector2(lx, 48), "1P", 24.0, SaP.hdr(SaP.GOLD, 1.1))
	SaG2.text(ci, Vector2(lx + 50, 50), SaP.n(w.score), 44.0, SaP.WHITE)
	SaG2.text(ci, Vector2(lx, 100), SaD.ROUND[w.round_i].name, 24.0, SaP.DIM)
	SaG2.text(ci, Vector2(lx, 134), SaD.DIFF[w.diff].name, 22.0, SaP.DIM)
	if SaD.test_build():
		SaG2.text(ci, Vector2(lx + 110, 134), "TEST  B 보스", 20.0, SaP.hdr(SaP.FOE_MARK, 1.1))
	SaArt.craft(ci, w.craft, Vector2(cx, 236), w.t, 1.7)
	SaG2.text_mid(ci, Vector2(cx, 322), c.name, 28.0, SaP.hdr(col, 1.05))
	SaG2.text_mid(ci, Vector2(cx, 356), "서브기체 %d대" % w.opts.size(), 22.0, SaP.DIM)
	SaG2.text_mid(ci, Vector2(cx, 420), "끌어서 이동", 22.0, SaP.DIM)
	SaG2.text_mid(ci, Vector2(cx, 450), "스킬은 누르고 있다 떼기", 22.0, SaP.DIM)

	var rx := rp.end.x - 16.0
	var rl := rp.position.x + 16.0
	for i in maxi(0, w.lives):
		SaArt.craft(ci, w.craft, Vector2(rx - 20 - i * 44, 40), w.t, 0.75)
	SaG2.text_right(ci, Vector2(rx, 100), "POWER %d / %d" % [w.power, SaD.POWER_MAX], 22.0, SaP.DIM)
	for i in SaD.POWER_MAX + 1:
		var r := Rect2(rx - (SaD.POWER_MAX + 1 - i) * 32.0 + 4.0, 114, 26, 14)
		ci.draw_rect(r, SaP.hdr(col, 1.15) if i <= w.power else SaP.a(SaP.DIMMER, 0.3), true)
	# 진행 — 이름표를 달아 무엇인지 읽히게, 끝에 보스 표시
	var bw := rx - rl
	SaG2.text(ci, Vector2(rl, 178), "보스까지", 22.0, SaP.DIM)
	SaG2.text_right(ci, Vector2(rx, 178), "%d%%" % int(w.prog * 100.0), 22.0, SaP.DIM)
	var bar := Rect2(rl, 190, bw, 10)
	ci.draw_rect(bar, SaP.a(SaP.DIMMER, 0.35), true)
	ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * w.prog, bar.size.y)), SaP.hdr(SaP.GOLD, 1.05), true)
	ci.draw_rect(Rect2(bar.end.x - 4, bar.position.y - 4, 4, bar.size.y + 8), SaP.hdr(SaP.FOE_MARK, 1.1), true)
	boss_meter(ci, Vector2(rl, 280), bw, 18.0, 22.0, w)


## 스킬 · 봄 단추. **스킬 단추 안에 게이지를 그린다** — 손가락이 거기 있으니 얼마나 찼는지도 거기서 읽혀야 한다.
static func buttons(ci: CanvasItem, skill_r: Rect2, bomb_r: Rect2, holding: bool, w: SaWorld) -> void:
	var col := w.craft_col()
	var c: Dictionary = SaD.CRAFT[w.craft]

	# ---- 스킬 ----
	var k := minf(1.0, skill_r.size.y / 180.0)   # 가로 화면 단추는 낮다 — 글 자리 · 크기를 같이 줄인다
	var kf: float = w.charge_frac()
	ci.draw_rect(skill_r, Color(0.06, 0.08, 0.13, 1.0), true)
	ci.draw_rect(Rect2(skill_r.position, Vector2(skill_r.size.x * kf, skill_r.size.y)),
			SaP.a(col, 0.35 if kf < 1.0 else 0.55), true)
	ci.draw_rect(skill_r, SaP.hdr(SaP.WHITE, 1.2) if kf >= 1.0 else SaP.a(col, 0.9 if holding else 0.45),
			false, 4.0 if holding else 1.5)
	var sc := skill_r.get_center()
	SaG2.text_mid(ci, sc - Vector2(0, 38) * k, "스킬", 40.0 * k, SaP.WHITE)
	SaG2.text_mid(ci, sc + Vector2(0, 8) * k, c.skill, maxf(20.0, 26.0 * k), SaP.hdr(col, 1.05))
	var tip := "누르고 있다 떼기"
	if kf >= 1.0:
		tip = "떼면 발동"
	elif w.charge > 0.0:
		tip = "채우는 중"
	SaG2.text_mid(ci, sc + Vector2(0, 50) * k, tip, 20.0,
			SaP.hdr(SaP.GOLD, 1.0 + 0.25 * sin(w.t * 9.0)) if kf >= 1.0 else SaP.DIM)

	# ---- 봄 ----
	ci.draw_rect(bomb_r, Color(0.06, 0.08, 0.13, 1.0), true)
	ci.draw_rect(bomb_r, SaP.a(SaP.GOLD, 0.45) if w.bombs > 0 else SaP.a(SaP.DIMMER, 0.5), false, 1.5)
	var bc := bomb_r.get_center()
	SaG2.text_mid(ci, bc - Vector2(0, 38) * k, "봄", 40.0 * k, SaP.WHITE if w.bombs > 0 else SaP.DIMMER)
	SaG2.text_mid(ci, bc + Vector2(0, 8) * k, c.bomb, maxf(20.0, 24.0 * k), SaP.DIM)
	var n := maxi(SaD.BOMBS, w.bombs)
	for i in n:
		var p := bc + Vector2((i - (n - 1) * 0.5) * 34.0, 50.0 * k)
		if i < w.bombs:
			SaG2.glow(ci, p, 18.0, col, 0.35)
			ci.draw_arc(p, 11.0, 0.0, TAU, 20, SaP.hdr(col, 1.2), 3.0, true)
		else:
			ci.draw_arc(p, 11.0, 0.0, TAU, 20, SaP.a(SaP.DIMMER, 0.4), 2.0, true)


static func boss_bar(ci: CanvasItem, play: Rect2, w: SaWorld) -> void:
	boss_meter(ci, play.position + Vector2(22, 46), play.size.x - 44.0, 9.0, 12.0, w)


static func boss_meter(ci: CanvasItem, top: Vector2, bw: float, bh: float, fs: float, w: SaWorld) -> void:
	# ---- 보스 체력 ----
	#
	# 막대 하나만 두면 4,800 짜리 보스는 한 대 맞을 때마다 0.02% 씩 줄어서 **안 움직이는
	# 것처럼 보인다.** 뒤따라오는 잔상 막대를 겹쳐 두면 맞은 만큼이 눈에 띄게 깎이고,
	# 숫자를 같이 적어 두면 남은 양이 정확히 읽힌다.
	if not w.boss.is_empty() and w.boss.y_in:
		var hp: float = maxf(0.0, w.boss.hp / w.boss.max)
		var lag: float = maxf(hp, w.boss.shown / w.boss.max)
		var bcol := SaP.hdr(Color8(224, 163, 60) if w.boss.mid else Color8(216, 90, 80), 1.1)
		var fill := SaP.hdr(Color8(192, 138, 58) if w.boss.mid else SaP.FOE_MARK, 1.15)
		ci.draw_rect(Rect2(top, Vector2(bw, bh)), Color(0.03, 0.05, 0.08, 0.85), true)
		ci.draw_rect(Rect2(top, Vector2(bw * lag, bh)), SaP.a(SaP.WHITE, 0.55), true)
		ci.draw_rect(Rect2(top, Vector2(bw * hp, bh)), fill, true)
		if w.boss.rage:
			# 2페이즈에 들어간 건 화면에서 바로 알아야 한다.
			ci.draw_rect(Rect2(top, Vector2(bw * hp, bh)),
					SaP.a(SaP.WHITE, 0.12 + 0.12 * sin(w.t * 9.0)), true)
		ci.draw_rect(Rect2(top - Vector2(1, 1), Vector2(bw + 2, bh + 2)), SaP.a(SaP.WHITE, 0.35), false, 1.0)
		for i in 3:
			var qx := top.x + bw * (i + 1) * 0.25
			ci.draw_line(Vector2(qx, top.y), Vector2(qx, top.y + bh), SaP.a(SaP.VOID, 0.5), 1.0)
		SaG2.text(ci, top - Vector2(0, fs * 0.65),
				("중간보스  " if w.boss.mid else "") + w.boss.name, fs, bcol)
		SaG2.text_right(ci, Vector2(top.x + bw, top.y - fs * 0.65),
				"%s / %s" % [SaP.n(int(ceil(maxf(0.0, w.boss.hp)))), SaP.n(int(w.boss.max))],
				fs, SaP.WHITE)


static func overlay(ci: CanvasItem, play: Rect2, w: SaWorld) -> void:
	var mid := play.position + play.size * 0.5
	match w.st:
		SaWorld.St.CLEAR:
			_banner(ci, play, mid, "라운드 클리어", "다음 라운드로…", SaP.hdr(SaP.GOLD, 1.2))
		SaWorld.St.ALLCLEAR:
			_banner(ci, play, mid, "ALL CLEAR", "아래 단추로 다시 하거나 기체를 고르세요", SaP.hdr(SaP.POWER, 1.2))
		SaWorld.St.OVER:
			_banner(ci, play, mid, "GAME OVER", "아래 단추로 다시 하거나 기체를 고르세요", SaP.hdr(SaP.FOE_MARK, 1.2))


static func _banner(ci: CanvasItem, play: Rect2, mid: Vector2, big: String, small: String,
		col: Color) -> void:
	ci.draw_rect(Rect2(play.position.x, mid.y - 62, play.size.x, 124),
			Color(0.02, 0.03, 0.06, 0.72), true)
	ci.draw_line(Vector2(play.position.x, mid.y - 62), Vector2(play.end.x, mid.y - 62),
			SaP.a(col, 0.7), 1.5)
	ci.draw_line(Vector2(play.position.x, mid.y + 62), Vector2(play.end.x, mid.y + 62),
			SaP.a(col, 0.7), 1.5)
	SaG2.text_mid(ci, mid - Vector2(0, 12), big, 30.0, col)
	SaG2.text_mid(ci, mid + Vector2(0, 28), small, 14.0, SaP.DIM)
