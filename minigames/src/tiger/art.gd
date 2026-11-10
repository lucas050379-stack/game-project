class_name TgArt
extends RefCounted

## 떡 하나 주면 안 잡아먹지 그림 — 전부 코드(호랑이 · 장애물 · 떡 · 배경). 그림 파일(`art/tiger/tg_*.png`)이 있으면 얹고 **없어도 돈다**(ADR-0005).
## 민화(까치호랑이) 느낌 — 굵은 먹선, 오방색(빨강 · 파랑 · 노랑 · 흰 · 검정)에 솔잎 초록. 좌표는 화면 좌표. 글자는 20px 아래로 쓰지 않는다.

const INK := Color8(40, 30, 28)
const FOX := Color8(240, 160, 50)       ## 호랑이 털(이름은 뼈대 때 것 — main 이 같이 쓴다)
const FOX_DARK := Color8(196, 116, 30)
const CREAM := Color8(252, 244, 226)
const EMBER := Color8(250, 196, 70)     ## 강조(별 · 게이지 · 테)
const FLAME := Color8(226, 70, 50)      ## 호랑이 기운 — 붉은 기운
const PAPER := Color8(250, 242, 224)
const HEAD := Color8(252, 246, 232)     ## 제목 · 강조 글자
const TTEOK := [Color8(252, 248, 240), Color8(250, 180, 190), Color8(160, 200, 130), Color8(250, 214, 110), Color8(150, 110, 90)]   ## 흰 · 분홍 · 쑥 · 노랑 · 팥

## 테마별 하늘(위 · 아래) · 멀리 실루엣 · 땅 색
const SKY := [
	[Color8(150, 200, 230), Color8(246, 232, 204)],   # 고갯마루 — 맑은 낮
	[Color8(40, 70, 80), Color8(140, 180, 150)],      # 대숲 — 어스름
	[Color8(170, 186, 210), Color8(240, 240, 246)],   # 눈 산 — 흐린 겨울
	[Color8(24, 20, 50), Color8(110, 60, 70)],        # 곶감 익는 밤
]
const FAR := [Color8(150, 176, 160), Color8(30, 70, 66), Color8(196, 206, 224), Color8(40, 30, 60)]
const GROUND := [Color8(170, 130, 90), Color8(90, 100, 70), Color8(226, 230, 240), Color8(80, 56, 60)]
const BG_DIM := 0.38   ## 배경(하늘 · 먼 띠 · 가까운 띠)을 덮는 세기 — 앞이 튀게


static func text(ci: CanvasItem, pos: Vector2, s: String, size: float, c: Color, outline: float = 0.0, oc: Color = INK) -> void:
	G2.text_mid(ci, pos, s, size, c, outline, oc)


static func rr(ci: CanvasItem, r: Rect2, rad: float, fill: Color, edge: Color = Color(0, 0, 0, 0), lw: float = 0.0) -> void:
	G2.panel(ci, r, fill, edge, lw, rad)

# ==================== 배경 ====================


## 하늘 · 멀리(0.2배) · 가까이(0.5배) · 땅(1배). dist 는 달린 거리, w h 는 화면.
## cam: 화면이 위로 따라 올라간 높이 — 땅과 가까운 띠는 그만큼 내려가고, 먼 띠는 조금만(0.35배) 내려간다(산 위에서 먼 산이 같이 보인다).
static func bg(ci: CanvasItem, w: float, h: float, theme: int, dist: float, t: float, cam: float = 0.0) -> void:
	var ground_y := TgD.GROUND_Y + cam
	var far_y := TgD.GROUND_Y + cam * 0.35
	var back := img("tg_back_%d" % theme)
	if back != null:   # 한 겹짜리 흐린 풍경(11-10 밤 — 예전 두 겹 띠는 윤곽선 그림이라 앞과 다투고 지평선이 둘로 보였다)
		ci.draw_rect(Rect2(0, 0, w, ground_y), FAR[theme])
		_strip(ci, back, w, ground_y, dist * 0.25, 1.12)
		ci.draw_rect(Rect2(0, 0, w, ground_y), Color((FAR[theme] as Color).darkened(0.35), BG_DIM * 0.5))
		ci.draw_rect(Rect2(0, ground_y, w, h - ground_y), GROUND[theme])
		return
	var sky: Array = SKY[theme]
	for k in 8:
		var y0 := ground_y * k / 8.0
		ci.draw_rect(Rect2(0, y0, w, ground_y / 8.0 + 1.0), (sky[0] as Color).lerp(sky[1], float(k) / 7.0))
	# 구름(낮) · 눈(겨울) · 별과 달(밤)
	for k in 7:
		var sx := fposmod(k * 233.0 - dist * 0.08, w + 240.0) - 120.0
		var sy := 60.0 + fmod(k * 71.0, ground_y * 0.4)
		if theme == 0:
			for j in 3:
				ci.draw_circle(Vector2(sx + j * 34.0, sy + (j % 2) * 8.0), 28.0, Color(1, 1, 1, 0.7))
		elif theme == 3 or theme == 1:
			ci.draw_circle(Vector2(sx, sy), 2.5, Color(1, 0.95, 0.7, 0.5 + 0.4 * sin(t * 2.0 + k)))
	if theme == 2:
		for k in 50:
			ci.draw_circle(Vector2(fposmod(k * 97.0 - dist * 0.3 + sin(t + k) * 20.0, w), fposmod(k * 53.0 + t * 60.0, ground_y)), 2.5, Color(1, 1, 1, 0.8))
	if theme == 3:
		ci.draw_circle(Vector2(w * 0.78, 110), 46, Color8(250, 240, 200))
	var far_tex := img("tg_bg_%d_far" % theme)
	if far_tex != null:
		_strip(ci, far_tex, w, far_y, dist * 0.3, 0.55)
		if cam > 0.5:
			ci.draw_rect(Rect2(0, far_y - 1.0, w, ground_y - far_y + 1.0), FAR[theme])
	else:
		_far_code(ci, w, ground_y, theme, dist * 0.3)
	var near_tex := img("tg_bg_%d_near" % theme)
	if near_tex != null:
		_strip(ci, near_tex, w, ground_y, dist * 0.7, 0.85)   # 시차를 키워(0.5 → 0.7) 앞으로 내달리는 느낌을
	else:
		_near_code(ci, w, ground_y, theme, dist * 0.7, t)
	# 배경 누르기(11-10 이어 달리기) — 밝고 빽빽한 배경이 앞의 떡 · 장애물 · 호랑이와 다퉜다. 테마의 먼 색으로 덮어 채도와 대비를 낮춘다
	ci.draw_rect(Rect2(0, 0, w, ground_y), Color((FAR[theme] as Color).darkened(0.35), BG_DIM))
	# 땅 — 흙길에 풀포기 · 자갈
	ci.draw_rect(Rect2(0, ground_y, w, h - ground_y), GROUND[theme])
	ci.draw_rect(Rect2(0, ground_y, w, 6), (GROUND[theme] as Color).lightened(0.2))
	var off := fmod(dist, 120.0)
	for k in int(w / 120.0) + 2:
		var x := k * 120.0 - off
		ci.draw_rect(Rect2(x + 60, ground_y + 36, 30, 5), Color(0, 0, 0, 0.14))
		ci.draw_circle(Vector2(x + 14, ground_y + 70), 6.0, Color(0, 0, 0, 0.1))
		if theme < 2:
			for j in 3:
				ci.draw_line(Vector2(x + 96 + j * 5, ground_y), Vector2(x + 92 + j * 7, ground_y - 12), Color8(90, 140, 70), 2.5)


## 가로로 이어 붙는 띠 그림 — 아래 끝을 바닥에 맞춘다.
static func _strip(ci: CanvasItem, tex: Texture2D, w: float, ground_y: float, scroll: float, hk: float) -> void:
	var ts := tex.get_size()
	var dh := TgD.GROUND_Y * hk   # 띠의 키는 늘 같다 — 화면이 올라가도(ground_y 가 내려가도) 안 커진다
	var dw := ts.x * dh / ts.y
	var off := fmod(scroll, dw)
	var x := -off
	while x < w:
		ci.draw_texture_rect(tex, Rect2(x, ground_y - dh, dw, dh), false)
		x += dw


static func _far_code(ci: CanvasItem, w: float, ground_y: float, theme: int, scroll: float) -> void:
	var col: Color = FAR[theme]
	var period := 260.0
	var off := fmod(scroll, period)
	for k in int(w / period) + 2:
		var x := k * period - off
		var seed := int(fmod(scroll - off, 1e6) / period) + k
		var hh := 80.0 + float((seed * 37) % 90)
		# 겹겹 산등성이(민화의 둥근 산) — 테마마다 색만 다르고, 고갯마루에는 초가집
		G2.fill_fan(ci, G2.ellipse_pts(Vector2(x + 130, ground_y), 190.0, hh + 60.0), col, Vector2(x + 130, ground_y))
		if theme == 0 and seed % 2 == 0:
			ci.draw_rect(Rect2(x + 30, ground_y - 46, 80, 46), Color8(226, 210, 180))
			G2.fill_fan(ci, G2.ellipse_pts(Vector2(x + 70, ground_y - 46), 56.0, 26.0), Color8(200, 170, 110), Vector2(x + 70, ground_y - 46))
		elif theme == 2:
			G2.fill_fan(ci, G2.ellipse_pts(Vector2(x + 130, ground_y - hh - 30), 70.0, 22.0), Color(1, 1, 1), Vector2(x + 130, ground_y - hh - 30))


static func _near_code(ci: CanvasItem, w: float, ground_y: float, theme: int, scroll: float, t: float) -> void:
	var period := 340.0
	var off := fmod(scroll, period)
	for k in int(w / period) + 2:
		var x := k * period - off
		match theme:
			1:   # 대나무 줄기
				for j in 3:
					var bx := x + j * 110.0 + 30.0
					ci.draw_rect(Rect2(bx, 0, 14, ground_y), Color8(60, 120, 80))
					for s in int(ground_y / 70.0):
						ci.draw_rect(Rect2(bx - 1, s * 70.0 + 20, 16, 4), Color8(30, 76, 54))
			3:   # 감나무 — 가지에 주황 감
				var tx := x + 120.0
				ci.draw_line(Vector2(tx, ground_y), Vector2(tx + 10, ground_y - 230), Color8(60, 40, 36), 14.0)
				for j in 5:
					var br := Vector2(tx + 10, ground_y - 120 - j * 24) + Vector2((j % 2 * 2 - 1) * (50 + j * 8), -10)
					ci.draw_line(Vector2(tx + 8, ground_y - 110 - j * 24), br, Color8(60, 40, 36), 5.0)
					ci.draw_circle(br + Vector2(0, 8 + sin(t * 2.0 + j) * 2.0), 9.0, Color8(240, 130, 40))
			_:   # 소나무 — 굽은 줄기에 둥근 솔잎 덩이(눈 산에서는 눈을 얹는다)
				var px := x + 120.0
				ci.draw_line(Vector2(px, ground_y), Vector2(px + 24, ground_y - 150), Color8(120, 70, 50), 14.0)
				for j in 3:
					var c := Vector2(px + 24 + (j - 1) * 50, ground_y - 160 - (j % 2) * 30)
					G2.fill_fan(ci, G2.ellipse_pts(c, 58.0, 26.0), Color8(50, 110, 80), c)
					if theme == 2:
						G2.fill_fan(ci, G2.ellipse_pts(c + Vector2(0, -12), 46.0, 12.0), Color(1, 1, 1), c + Vector2(0, -12))

# ==================== 호랑이 ====================


## 호랑이 — feet: 발이 닿는 화면 점. state: "run" · "jump" · "slide". dash: 호랑이 기운(붉은 기운이 몸 뒤로 뻗는다).
static func fox(ci: CanvasItem, feet: Vector2, phase: float, state: String, dash: bool, inv_blink: bool, t: float) -> void:
	var tex := img("tg_tiger_%s" % state)
	if inv_blink:
		return
	if dash:
		# 호랑이 기운 — 불꽃 호랑이 머리 모양 기운이 몸을 감싸고 뒤로 흐른다(그림 tg_fx_aura, 없으면 붉은 줄). 숨 쉬듯 커졌다 작아진다
		var au := img("tg_fx_aura")
		if au != null:
			var asz := au.get_size()
			var k2 := (300.0 + sin(t * 14.0) * 16.0) / asz.x
			ci.draw_texture_rect(au, Rect2(feet + Vector2(-asz.x * k2 * 0.62, -asz.y * k2 * 0.5 - 62.0), asz * k2), false, Color(1, 1, 1, 0.92))
		else:
			for k in 9:
				var a := -PI * 0.5 - 0.9 + k * 0.22
				var tip := feet + Vector2(-30, -40) + Vector2.from_angle(a) * (70.0 + sin(t * 9.0 + k) * 8.0)
				ci.draw_line(feet + Vector2(-26, -36), tip, Color(FLAME if k % 2 == 0 else EMBER, 0.75), 9.0)
	# 달리기는 네 칸 갤럽(tg_tiger_run_0~3 — 같은 크기 판에 발을 아래에 맞춰 넣은 것). 칸이 없으면 한 장을 위아래로 흔든다.
	if state == "run" and img("tg_tiger_run_0") != null:
		var fr := img("tg_tiger_run_%d" % (int(phase * 1.6) % 4))
		var fs := fr.get_size()
		var k := 136.0 / fs.y   # 치비 호랑이 — 키 기준(판정 상자 72 보다 조금 크게: 머리털 · 귀가 상자 밖)
		ci.draw_texture_rect(fr, Rect2(feet - Vector2(fs.x * k * 0.5, fs.y * k - 6.0), fs * k), false)
		return
	if tex != null:
		var ts := tex.get_size()
		# 숙일 때도 **호랑이 크기는 그대로** — 엎드린 그림은 길이를 기준으로 맞춘다(높이로 맞추면 통째로 작아졌다)
		var hh := 136.0 if state != "slide" else 190.0 * ts.y / ts.x
		var ww := ts.x * hh / ts.y
		var bob := absf(sin(phase * PI * 0.8)) * 6.0 if state == "run" else 0.0
		ci.draw_texture_rect(tex, Rect2(feet - Vector2(ww * 0.5, hh - 6.0 + bob), Vector2(ww, hh)), false)
		return
	var body_c := feet + Vector2(0, -40)
	if state == "slide":
		body_c = feet + Vector2(0, -20)
	var leg_swing := sin(phase * TAU) * (18.0 if state == "run" else 6.0)
	# 꼬리 — 길게 말려 올라가고 줄무늬
	var tail_root := body_c + Vector2(-28, -2)
	var tail_mid := tail_root + Vector2(-26, -8)
	var tail_tip := tail_mid + Vector2(-6, -30 + sin(t * 8.0) * 6.0)
	ci.draw_line(tail_root, tail_mid, FOX, 10.0)
	ci.draw_line(tail_mid, tail_tip, FOX, 10.0)
	ci.draw_circle(tail_tip, 6.0, INK)
	ci.draw_line(tail_mid + Vector2(8, -4), tail_mid + Vector2(8, 6), INK, 3.0)
	for k in 2:
		var side := -1.0 if k == 0 else 1.0
		var hip := body_c + Vector2(-14 + k * 26, 10)
		var foot := hip + Vector2(side * leg_swing * 0.6, 26 if state != "jump" else 18)
		if state == "slide":
			foot = hip + Vector2(20 + k * 10, 14)
		ci.draw_line(hip, foot, FOX_DARK, 9.0)
		ci.draw_circle(foot, 6.0, CREAM)
	var rx := 32.0 if state != "slide" else 38.0
	var ry := 21.0 if state != "slide" else 14.0
	G2.fill_fan(ci, G2.ellipse_pts(body_c, rx, ry), FOX, body_c)
	G2.fill_fan(ci, G2.ellipse_pts(body_c + Vector2(2, ry * 0.4), rx * 0.6, ry * 0.5), CREAM, body_c + Vector2(2, ry * 0.4))
	for j in 4:   # 등 줄무늬
		var sx := body_c.x - 18 + j * 11
		ci.draw_line(Vector2(sx, body_c.y - ry * 0.95), Vector2(sx + 3, body_c.y - ry * 0.3), INK, 3.5)
	var head := body_c + Vector2(28, -20) if state != "slide" else body_c + Vector2(36, -8)
	ci.draw_circle(head + Vector2(-11, -15), 7.0, FOX)   # 둥근 귀
	ci.draw_circle(head + Vector2(9, -16), 7.0, FOX)
	ci.draw_circle(head + Vector2(-11, -15), 3.5, INK)
	ci.draw_circle(head + Vector2(9, -16), 3.5, INK)
	ci.draw_circle(head, 18.0, FOX)
	ci.draw_circle(head + Vector2(9, 7), 9.0, CREAM)      # 주둥이
	ci.draw_circle(head + Vector2(14, 4), 3.0, INK)
	ci.draw_line(head + Vector2(-2, -14), head + Vector2(-2, -8), INK, 3.0)   # 이마 임금 왕 자 대신 세 줄
	ci.draw_line(head + Vector2(-7, -12), head + Vector2(-7, -7), INK, 2.5)
	ci.draw_line(head + Vector2(3, -12), head + Vector2(3, -7), INK, 2.5)
	ci.draw_circle(head + Vector2(3, -2), 4.5, Color8(250, 230, 120))          # 큰 노란 눈(민화)
	ci.draw_circle(head + Vector2(4, -2), 2.2, INK)

# ==================== 장애물 · 먹을 것 ====================


## 장애물 — it: 규칙의 항목, x: 화면 x(가운데), ground_y: 바닥. 높이는 위로 양수(세상) → 화면은 아래로.
static func obstacle(ci: CanvasItem, it: Dictionary, x: float, ground_y: float, _theme: int, t: float) -> void:
	match String(it.kind):
		"low" when int(it.v) == 2:   # 가시밭의 가시 — 낮고 날카로운 나무 말뚝 셋(테마 땅색과 갈리게 짙은 먹 + 흰 끝)
			var hw := float(it.w) * 0.5
			var hh := float(it.h)
			for k in 3:
				var bx := x - hw + k * hw * 0.6 + hw * 0.2
				var tri := PackedVector2Array([Vector2(bx - hw * 0.42, ground_y), Vector2(bx, ground_y - hh * (1.0 if k == 1 else 0.82)), Vector2(bx + hw * 0.42, ground_y)])
				ci.draw_colored_polygon(tri, INK)
				var tip := PackedVector2Array([tri[1], tri[1].lerp(tri[0], 0.3), tri[1].lerp(tri[2], 0.3)])
				ci.draw_colored_polygon(tip, CREAM)
		"low" when int(it.v) == 5:   # 땅 가까이 떠 있는 밤송이
			burr(ci, Vector2(x, ground_y - float(it.h) * 0.5 - 4.0), float(it.w) * 0.5, t)
		"high" when int(it.v) == 4:   # 머리 위 · 높은 곳에 떠 있는 밤송이
			burr(ci, Vector2(x, ground_y - float(it.y) - float(it.h) * 0.5), float(it.w) * 0.5, t)
		"high" when int(it.v) == 5:   # 흔들리는 도끼 — 화면 위 못에 줄로 매달려 흔들린다. 날 아래 끝이 판정
			var blade := Vector2(x, ground_y - float(it.y))
			var pivot := Vector2(x + float(it.x0) - float(it.x), ground_y - TgD.HIGH_Y - TgD.AXE_L)
			var u := (blade - pivot).normalized()
			var nn := Vector2(-u.y, u.x)
			ci.draw_line(pivot, blade - u * 60.0, INK, 12.0)
			ci.draw_line(pivot, blade - u * 60.0, Color8(150, 100, 60), 7.0)
			var ax := img("tg_obs_axe")
			if ax != null:
				var asz := ax.get_size() * (150.0 / ax.get_size().x)
				ci.draw_set_transform(blade, u.angle() - PI * 0.5, Vector2.ONE)
				ci.draw_texture_rect(ax, Rect2(-asz.x * 0.5, -asz.y, asz.x, asz.y), false)
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				var c5 := blade - u * 46.0
				var head5 := PackedVector2Array([c5 - u * 30 + nn * 16, c5 - u * 44 + nn * 78, c5 + u * 46 + nn * 70, c5 + u * 22 + nn * 16,
						c5 + u * 22 - nn * 16, c5 + u * 46 - nn * 70, c5 - u * 44 - nn * 78, c5 - u * 30 - nn * 16])
				var in5 := PackedVector2Array()
				for p5 in head5:
					in5.append(p5 + (c5 - p5).normalized() * 5.0)
				ci.draw_colored_polygon(head5, INK)
				ci.draw_colored_polygon(in5, Color8(190, 196, 206))
				ci.draw_line(c5 + u * 34 + nn * 60, c5 - u * 34 + nn * 66, Color(1, 1, 1, 0.6), 4.0)
				ci.draw_line(c5 + u * 34 - nn * 60, c5 - u * 34 - nn * 66, Color(1, 1, 1, 0.6), 4.0)
				ci.draw_circle(c5, 9.0, INK)
		"roller":   # 굴러오는 맷돌 — 크고 둥글다. 2단 점프로 넘는다
			var rc := Vector2(x, ground_y - float(it.h) * 0.5)
			var rad := float(it.w) * 0.5
			var mt := img("tg_obs_millstone")
			if mt != null:
				ci.draw_set_transform(rc, -t * 7.0, Vector2.ONE)
				ci.draw_texture_rect(mt, Rect2(-rad * 1.05, -rad * 1.05, rad * 2.1, rad * 2.1), false)
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				ci.draw_circle(rc, rad + 3.0, INK)
				ci.draw_circle(rc, rad - 2.0, Color8(150, 146, 150))
				ci.draw_circle(rc, rad * 0.72, Color8(176, 172, 176))
				for k in 8:
					var ra := -t * 7.0 + k * TAU / 8.0
					ci.draw_line(rc + Vector2.from_angle(ra) * rad * 0.3, rc + Vector2.from_angle(ra) * rad * 0.9, Color8(110, 106, 112), 5.0)
				ci.draw_circle(rc, rad * 0.2, INK)
				ci.draw_circle(rc + Vector2(-rad * 0.4, -rad * 0.45), rad * 0.12, Color(1, 1, 1, 0.35))
			for k in 3:
				ci.draw_line(rc + Vector2(rad + 10 + k * 6, -rad * 0.5 + k * rad * 0.5), rc + Vector2(rad + 60 + k * 20, -rad * 0.5 + k * rad * 0.5), Color(1, 1, 1, 0.5), 4.0)
		"flyer" when bool(it.get("bolt", false)):   # 벼락 — 오른쪽 위에서 비스듬히 내리꽂힌다. 떨어질 자리에 표시
			var off := maxf(0.0, float(it.x) - float(it.meet))
			var mx := x - off
			var bc := Vector2(x, ground_y - float(it.y) - float(it.h) * 0.5 - off * 0.55)
			if off > 20.0:   # 떨어질 자리 — 깜박이는 고리
				var wk := 0.5 + 0.5 * sin(t * 18.0)
				ci.draw_arc(Vector2(mx, ground_y - 4.0), 30.0, 0.0, TAU, 20, Color(1.0, 0.85, 0.2, 0.35 + 0.5 * wk), 5.0)
				ci.draw_circle(Vector2(mx, ground_y - 4.0), 8.0, Color(1.0, 0.3, 0.2, 0.5 + 0.4 * wk))
			var bt := img("tg_obs_bolt")
			if bt != null:
				var bs := bt.get_size() * (110.0 / bt.get_size().y)
				ci.draw_texture_rect(bt, Rect2(bc.x - bs.x * 0.5, bc.y - bs.y * 0.5, bs.x, bs.y), false)
			else:
				var zz := PackedVector2Array([bc + Vector2(34, -62), bc + Vector2(58, -50), bc + Vector2(14, -8), bc + Vector2(36, -2),
						bc + Vector2(-30, 34), bc + Vector2(-6, 2), bc + Vector2(-26, -4)])
				var zo := PackedVector2Array()
				for p6 in zz:
					zo.append(bc + (p6 - bc) * 1.18)
				ci.draw_colored_polygon(zo, INK)
				ci.draw_colored_polygon(zz, Color8(255, 222, 60))
				ci.draw_line(bc + Vector2(40, -52), bc + Vector2(8, -6), Color(1, 1, 1, 0.8), 3.0)
		"low":
			var tex := img("tg_obs_rock" if int(it.v) == 0 else "tg_obs_stump")
			if tex != null:
				# 그림은 판정 상자(w × h)를 살짝 넘는 크기로 — 보이는 것과 닿는 것이 같아야 한다
				var ts := tex.get_size()
				var k := minf(float(it.w) * 1.5 / ts.x, float(it.h) * 1.2 / ts.y)
				ci.draw_texture_rect(tex, Rect2(x - ts.x * k * 0.5, ground_y - ts.y * k, ts.x * k, ts.y * k), false)
			elif int(it.v) == 0:   # 바위
				var c := Vector2(x, ground_y - 22)
				G2.fill_fan(ci, G2.ellipse_pts(c, 26.0, 28.0), INK, c)
				G2.fill_fan(ci, G2.ellipse_pts(c, 23.0, 25.0), Color8(150, 150, 156), c)
				ci.draw_line(c + Vector2(-8, -10), c + Vector2(4, 2), Color(0, 0, 0, 0.3), 2.5)
			else:   # 그루터기
				ci.draw_rect(Rect2(x - 20, ground_y - 46, 40, 46), INK)
				ci.draw_rect(Rect2(x - 17, ground_y - 44, 34, 44), Color8(150, 100, 60))
				G2.fill_fan(ci, G2.ellipse_pts(Vector2(x, ground_y - 46), 19.0, 6.0), Color8(220, 190, 140), Vector2(x, ground_y - 46))
		"tall" when int(it.get("v", 0)) == 1:   # 밤송이 기둥
			for k in 3:
				burr(ci, Vector2(x, ground_y - 6.0 - float(it.w) * (0.5 + k) - k * 3.0), float(it.w) * 0.5, t + k * 0.7)
		"tall":   # 높은 장승 — 2단 점프로 넘는다
			var tt := img("tg_obs_tall")
			if tt != null:
				var ts2 := tt.get_size()
				var k2 := float(it.h) * 1.04 / ts2.y
				ci.draw_texture_rect(tt, Rect2(x - ts2.x * k2 * 0.5, ground_y - ts2.y * k2, ts2.x * k2, ts2.y * k2), false)
			else:
				ci.draw_rect(Rect2(x - float(it.w) * 0.5, ground_y - float(it.h), it.w, it.h), INK)
				ci.draw_rect(Rect2(x - float(it.w) * 0.5 + 3, ground_y - float(it.h) + 3, float(it.w) - 6, float(it.h) - 3), Color8(150, 100, 60))
				for j in 2:
					ci.draw_circle(Vector2(x - 10 + j * 20, ground_y - float(it.h) + 40), 5.0, INK)
				ci.draw_rect(Rect2(x - 12, ground_y - float(it.h) + 62, 24, 6), Color8(200, 60, 50))
		"high" when int(it.v) == 2:   # 천장에서 내려오는 절굿공이 — 화면 위에서 줄에 매달려 내려온다. 굵고 커서 멀리서도 보인다
			var bottom2 := ground_y - float(it.y)
			var hw2 := float(it.w) * 0.5
			ci.draw_line(Vector2(x, -40), Vector2(x, bottom2 - 260), Color8(190, 160, 110), 5.0)
			var body := Rect2(x - hw2, bottom2 - 260, hw2 * 2.0, 260)
			ci.draw_rect(body.grow(3), INK)
			ci.draw_rect(body, Color8(176, 124, 74))
			ci.draw_rect(Rect2(body.position.x, body.position.y + 40, body.size.x, 14), Color8(130, 86, 50))
			ci.draw_rect(Rect2(body.position.x + 8, body.position.y + 6, 10, body.size.y - 12), Color(1, 1, 1, 0.18))
			var head := G2.ellipse_pts(Vector2(x, bottom2 - 30), hw2 + 14, 34)
			G2.fill_fan(ci, head, INK, Vector2(x, bottom2 - 30))
			G2.fill_fan(ci, G2.ellipse_pts(Vector2(x, bottom2 - 32), hw2 + 10, 30), Color8(196, 144, 90), Vector2(x, bottom2 - 32))
		"high" when int(it.v) == 3 and int(it.get("sv", 0)) == 1:   # 천장 — 고드름 다발(아래 끝이 판정 선)
			var bot1 := ground_y - float(it.y)
			var hw4 := float(it.w) * 0.5
			ci.draw_rect(Rect2(x - hw4 - 8, -40, hw4 * 2.0 + 16, bot1 - 60 + 40), Color8(120, 150, 180))
			ci.draw_rect(Rect2(x - hw4 - 8, -40, hw4 * 2.0 + 16, bot1 - 60 + 40), INK, false, 3.0)
			var n4 := maxi(3, int(hw4 * 2.0 / 22.0))
			for k in n4:
				var tx := x - hw4 + (k + 0.5) * hw4 * 2.0 / n4
				var ln := 60.0 if k % 2 == 0 else 40.0
				var tri := PackedVector2Array([Vector2(tx - 11, bot1 - 60), Vector2(tx + 11, bot1 - 60), Vector2(tx, bot1 - 60 + ln)])
				ci.draw_colored_polygon(tri, Color8(210, 235, 250))
				ci.draw_polyline(PackedVector2Array([tri[0], tri[2], tri[1]]), INK, 2.0)
		"high" when int(it.v) == 3 and int(it.get("sv", 0)) == 2:   # 천장 — 밧줄에 매달린 통나무 두셋
			var bot2 := ground_y - float(it.y)
			var hw5 := float(it.w) * 0.5
			var n5 := maxi(1, int(hw5 * 2.0 / 70.0))
			for k in n5:
				var lx := x - hw5 + (k + 0.5) * hw5 * 2.0 / n5
				ci.draw_line(Vector2(lx, -40), Vector2(lx, bot2 - 70), Color8(190, 160, 110), 4.0)
				var log := Rect2(lx - 30, bot2 - 76, 60, 76)
				ci.draw_rect(log.grow(3), INK)
				ci.draw_rect(log, Color8(150, 100, 60))
				for j in 3:
					ci.draw_line(Vector2(log.position.x + 6, log.position.y + 18 + j * 20), Vector2(log.end.x - 6, log.position.y + 18 + j * 20), Color8(110, 70, 40), 2.0)
		"high" when int(it.v) == 3:   # 리듬 구간의 천장 — 위에서 내려온 바위 덩이(아래 끝이 높아 서 있으면 안 닿고, 2단 점프를 일찍 하면 박는다)
			var bot := ground_y - float(it.y)
			var hw3 := float(it.w) * 0.5
			var pts := PackedVector2Array([Vector2(x - hw3 - 10, -40), Vector2(x + hw3 + 10, -40), Vector2(x + hw3, bot - 30),
					Vector2(x + hw3 * 0.4, bot), Vector2(x - hw3 * 0.3, bot - 8), Vector2(x - hw3, bot - 36)])
			G2.fill_fan(ci, pts, INK, Vector2(x, bot - 120))
			var inner := PackedVector2Array()
			for p in pts:
				inner.append(p + (Vector2(x, bot - 120) - p).normalized() * 5.0)
			G2.fill_fan(ci, inner, Color8(110, 100, 110), Vector2(x, bot - 120))
			for k in 3:   # 고드름처럼 늘어진 끝
				var tx := x - hw3 * 0.5 + k * hw3 * 0.5
				ci.draw_colored_polygon(PackedVector2Array([Vector2(tx - 8, bot - 14), Vector2(tx + 8, bot - 14), Vector2(tx, bot + 10)]), Color8(90, 80, 90))
		"flyer":   # 날아오는 곶감 — 주황 몸통 · 초록 꼭지 · 뒤로 흐르는 속도선. 낮게(뛰어 넘는다) · 머리 높이(숙인다)
			var c := Vector2(x, ground_y - float(it.y) - float(it.h) * 0.5)
			var rr := float(it.w) * 0.5
			for k in 4:
				ci.draw_line(c + Vector2(rr + 6 + k * 4, -rr * 0.6 + k * rr * 0.4), c + Vector2(rr + 40 + k * 14, -rr * 0.6 + k * rr * 0.4), Color(1, 1, 1, 0.5), 3.0)
			var spin := t * 9.0
			G2.fill_fan(ci, G2.ellipse_pts(c, rr + 3, rr + 1), INK, c)
			G2.fill_fan(ci, G2.ellipse_pts(c, rr, rr - 2), Color8(232, 120, 40), c)
			ci.draw_circle(c + Vector2(-rr * 0.35, -rr * 0.35), rr * 0.22, Color(1, 1, 1, 0.45))
			for k in 4:
				var a := spin + k * TAU / 4.0
				ci.draw_line(c + Vector2.from_angle(a) * 3.0, c + Vector2.from_angle(a) * rr * 0.55, Color8(70, 120, 50), 4.0)
		"high":
			var top := ground_y - float(it.y) - float(it.h)
			var bottom := ground_y - float(it.y)
			var tex := img("tg_obs_branch" if int(it.v) == 0 else "tg_obs_gotgam")
			if tex != null:
				var ts := tex.get_size()
				var hh := bottom - top
				ci.draw_texture_rect(tex, Rect2(x - ts.x * hh / ts.y * 0.5, top, ts.x * hh / ts.y, hh), false)
			elif int(it.v) == 0:   # 늘어진 소나무 가지
				var sway := sin(t * 2.0 + x * 0.01) * 4.0
				ci.draw_line(Vector2(x + 20, top), Vector2(x + sway, bottom - 20), Color8(110, 66, 46), 10.0)
				for k in 3:
					var c := Vector2(x + sway + (k - 1) * 22, bottom - 20 + (k % 2) * 6)
					G2.fill_fan(ci, G2.ellipse_pts(c, 26.0, 16.0), Color8(50, 110, 80), c)
			else:   # 곶감 줄 — 새끼줄에 줄줄이 매단 곶감
				for k in 3:
					var px := x - 18 + k * 18
					ci.draw_line(Vector2(px, top), Vector2(px, bottom), Color8(190, 160, 110), 3.0)
					var n := int((bottom - top) / 26.0)
					for j in n:
						ci.draw_circle(Vector2(px + sin(t * 3.0 + k + j) * 2.0, top + 16 + j * 26.0), 9.0, Color8(226, 110, 40))
		"pit" when int(it.v) >= 8:   # 낭떠러지 · 허공 구간의 구덩이 — main 이 땅을 끊어 그린다
			pass
		"pit":   # 함정 구덩이 — 그림(tg_pit)이 있으면 그것, 없으면 검은 구덩이에 대나무 창
			var hw := float(it.w) * 0.5
			var pt := img("tg_pit")
			if pt != null:
				var ps := pt.get_size()
				var pw := hw * 2.0 + 44.0
				ci.draw_rect(Rect2(x - hw, ground_y, hw * 2.0, 20), Color8(30, 20, 20))
				ci.draw_texture_rect(pt, Rect2(x - pw * 0.5, ground_y - 14.0, pw, pw * ps.y / ps.x), false)
				return
			ci.draw_rect(Rect2(x - hw, ground_y, hw * 2.0, 160), Color8(30, 20, 20))
			ci.draw_rect(Rect2(x - hw, ground_y, hw * 2.0, 10), Color(0, 0, 0, 0.6))
			for k in 4:
				ci.draw_line(Vector2(x - hw + 14 + k * 26, ground_y + 110), Vector2(x - hw + 14 + k * 26, ground_y + 70), Color8(200, 190, 170), 4.0)   # 대나무 창


## 떠 있는 밤송이 — 가시 돋친 갈색 공 + 둘레의 점선 고리(떠 있다는 표시). 판정은 반지름 r 의 네모.
static func burr(ci: CanvasItem, c: Vector2, r: float, t: float) -> void:
	c.y += sin(t * 3.0 + c.x * 0.02) * 3.0
	for k in 12:
		var a0 := t * 0.8 + k * TAU / 12.0
		ci.draw_arc(c, r + 12.0, a0, a0 + TAU / 24.0, 4, Color(1, 1, 1, 0.55), 3.0)
	var tex := img("tg_obs_burr")
	if tex != null:
		ci.draw_texture_rect(tex, Rect2(c.x - r * 1.25, c.y - r * 1.25, r * 2.5, r * 2.5), false)
		return
	var pts := PackedVector2Array()
	for k in 20:
		pts.append(c + Vector2.from_angle(k * TAU / 20.0) * (r * 1.28 if k % 2 == 0 else r * 0.8))
	var inn := PackedVector2Array()
	for k in 20:
		inn.append(c + Vector2.from_angle(k * TAU / 20.0) * (r * 1.12 if k % 2 == 0 else r * 0.7))
	ci.draw_colored_polygon(pts, INK)
	ci.draw_colored_polygon(inn, Color8(196, 150, 70))
	ci.draw_circle(c, r * 0.62, Color8(150, 104, 50))
	ci.draw_circle(c + Vector2(-r * 0.2, -r * 0.2), r * 0.16, Color(1, 1, 1, 0.5))
	for j in 2:   # 심술궂은 눈
		ci.draw_line(c + Vector2(-r * 0.36 + j * r * 0.5, -r * 0.05), c + Vector2(-r * 0.14 + j * r * 0.5, r * 0.08 - j * r * 0.13), INK, 3.0)


## 길 위의 물건 — "honey" 꿀단지(떡이 끌려온다) · "sansam" 산삼(몸이 커진다) · "club" 도깨비 방망이(장애물이 떡으로) · "rope" 동아줄(하늘 보너스).
static func item(ci: CanvasItem, kind: String, c: Vector2, t: float) -> void:
	var p := c + Vector2(0, sin(t * 3.0 + c.x * 0.02) * 4.0)
	ci.draw_circle(p, 30.0 + sin(t * 6.0) * 2.0, Color(1, 1, 1, 0.22))
	var tex := img("tg_item_" + kind)
	if tex != null:
		var ts := tex.get_size()
		var hh := 70.0 if kind != "rope" else 190.0
		var q := p if kind != "rope" else p + Vector2(0, -60)
		ci.draw_texture_rect(tex, Rect2(q - Vector2(ts.x * hh / ts.y * 0.5, hh * 0.5), Vector2(ts.x * hh / ts.y, hh)), false)
		return
	match kind:
		"honey":
			rr(ci, Rect2(p - Vector2(16, 14), Vector2(32, 32)), 8, Color8(150, 90, 50), INK, 2.0)
			ci.draw_rect(Rect2(p.x - 18, p.y - 20, 36, 8), Color8(250, 200, 80))
			ci.draw_circle(p + Vector2(10, -6), 5.0, Color8(250, 200, 80))
		"sansam":
			ci.draw_line(p + Vector2(0, -6), p + Vector2(-10, 20), Color8(230, 200, 150), 6.0)
			ci.draw_line(p + Vector2(0, -6), p + Vector2(10, 20), Color8(230, 200, 150), 6.0)
			ci.draw_circle(p + Vector2(0, -8), 9.0, Color8(230, 200, 150))
			ci.draw_circle(p + Vector2(-8, -24), 7.0, Color8(90, 170, 90))
			ci.draw_circle(p + Vector2(8, -24), 7.0, Color8(90, 170, 90))
		"box":   # 보따리
			ci.draw_circle(p + Vector2(0, 6), 20.0, INK)
			ci.draw_circle(p + Vector2(0, 6), 18.0, Color8(240, 150, 170))
			ci.draw_circle(p + Vector2(-6, -14), 7.0, Color8(120, 170, 230))
			ci.draw_circle(p + Vector2(6, -14), 7.0, Color8(120, 170, 230))
		"club":
			ci.draw_line(p + Vector2(-14, 18), p + Vector2(14, -18), Color8(150, 100, 60), 14.0)
			for k in 3:
				ci.draw_circle(p + Vector2(-2 + k * 8, 2 - k * 10) + Vector2(7, 7), 3.5, EMBER)
		_:   # 동아줄 — 하늘에서 내려온 줄
			ci.draw_line(p + Vector2(0, -400), p + Vector2(0, 24), Color8(230, 190, 110), 8.0)
			for k in 12:
				ci.draw_line(p + Vector2(-4, -380 + k * 34), p + Vector2(4, -370 + k * 34), Color8(170, 130, 70), 3.0)


## 엽전 — 가운데 네모 구멍이 난 놋쇠 돈. 빙글 도는 것처럼 폭이 변한다.
static func coin(ci: CanvasItem, c: Vector2, t: float) -> void:
	var wk := absf(cos(t * 4.0 + c.x * 0.01)) * 0.7 + 0.3
	var tex := img("tg_coin")
	if tex != null:
		ci.draw_texture_rect(tex, Rect2(c - Vector2(17.0 * wk, 17), Vector2(34.0 * wk, 34)), false)
		return
	G2.fill_fan(ci, G2.ellipse_pts(c, 14.0 * wk, 14.0), INK, c)
	G2.fill_fan(ci, G2.ellipse_pts(c, 12.0 * wk, 12.0), EMBER, c)
	ci.draw_rect(Rect2(c.x - 3.5 * wk, c.y - 3.5, 7.0 * wk, 7), INK)


## 떡 — 반달 송편. 자리마다 색이 다르다(흰 · 분홍 · 쑥 · 노랑 · 팥).
static func candy(ci: CanvasItem, c: Vector2, t: float, icon: bool = false, tint: int = -1) -> void:
	var tex := img("tg_tteok")
	var bob := 0.0 if icon else sin(t * 5.0 + c.x * 0.02) * 3.0
	var p := c + Vector2(0, bob)
	if tex != null:
		var cs := tex.get_size()
		var mod := Color.WHITE if tint < 0 else (TTEOK[tint] as Color).lerp(Color.WHITE, 0.15)
		ci.draw_texture_rect(tex, Rect2(p - Vector2(22, 22.0 * cs.y / cs.x), Vector2(44, 44.0 * cs.y / cs.x)), false, mod)
		return
	var col: Color = TTEOK[tint] if tint >= 0 else (TTEOK[int(absf(c.x) * 0.031) % 5] if not icon else TTEOK[1])
	var pts := PackedVector2Array()
	for k in 9:
		pts.append(p + Vector2(cos(PI + k * PI / 8.0) * 14.0, sin(PI + k * PI / 8.0) * 12.0 + 5.0))
	G2.fill_fan(ci, pts, col, p)
	G2.stroke(ci, pts, INK, 2.0)
	ci.draw_arc(p + Vector2(0, 5), 9.0, PI * 1.15, PI * 1.6, 6, Color(1, 1, 1, 0.7), 2.0)


## 큰 엽전 — 엽전의 두 배, 반짝임이 돈다(엽전 열 닢).
static func big_coin(ci: CanvasItem, c: Vector2, t: float) -> void:
	ci.draw_circle(c, 38.0 + sin(t * 6.0) * 2.0, Color(1, 0.9, 0.4, 0.18))
	ci.draw_set_transform(c, 0.0, Vector2(2.1, 2.1))
	coin(ci, Vector2.ZERO, t)
	ci.draw_set_transform(Vector2.ZERO)
	var a := t * 2.5
	var sp := c + Vector2(cos(a) * 30.0, sin(a) * 30.0)
	ci.draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -8), sp + Vector2(2, 0), sp + Vector2(0, 8), sp + Vector2(-2, 0)]), Color(1, 1, 1, 0.95))
	ci.draw_colored_polygon(PackedVector2Array([sp + Vector2(-8, 0), sp + Vector2(0, -2), sp + Vector2(8, 0), sp + Vector2(0, 2)]), Color(1, 1, 1, 0.95))


## 무지개떡 — 떡의 두 배쯤, 일곱 빛 켜가 쌓인 네모 떡. 둘레에 빛이 돌고 색이 천천히 흐른다(쿠키런의 큰 무지개 젤리 자리).
static func big_tteok(ci: CanvasItem, c: Vector2, t: float, sz: float = 1.0) -> void:
	var p := c + Vector2(0, sin(t * 4.0 + c.x * 0.02) * 5.0)
	var glow := Color.from_hsv(fposmod(t * 0.35, 1.0), 0.6, 1.0)
	for k in 3:   # 둘레 빛
		ci.draw_circle(p, (70.0 + k * 12.0 + sin(t * 6.0) * 3.0) * sz, Color(glow, 0.16 - k * 0.04))
	var w := 110.0 * sz   # 떡(44)을 넷 합친 것보다 크게
	var h := 84.0 * sz
	var r := Rect2(p - Vector2(w, h) * 0.5, Vector2(w, h))
	ci.draw_rect(r.grow(3.0), INK)
	var layers := 6
	for k in layers:   # 켜 — 위에서부터 빨 · 주 · 노 · 초 · 파 · 보, 색이 아래로 흐른다
		var hue := fposmod(k / float(layers) - t * 0.25, 1.0)
		ci.draw_rect(Rect2(r.position.x, r.position.y + k * h / layers, w, h / layers + 0.5), Color.from_hsv(hue, 0.45, 1.0))
	ci.draw_rect(Rect2(r.position.x + 8 * sz, r.position.y + 6 * sz, 14 * sz, h - 12 * sz), Color(1, 1, 1, 0.35))
	for k in 2:   # 반짝이
		var a := t * 3.0 + k * PI
		var sp := p + Vector2(cos(a) * 66.0, sin(a) * 50.0) * sz
		ci.draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -7), sp + Vector2(2, 0), sp + Vector2(0, 7), sp + Vector2(-2, 0)]), Color(1, 1, 1, 0.9))
		ci.draw_colored_polygon(PackedVector2Array([sp + Vector2(-7, 0), sp + Vector2(0, -2), sp + Vector2(7, 0), sp + Vector2(0, 2)]), Color(1, 1, 1, 0.9))


## 꿀떡 꼬치 — 큰 것(체력 많이 · 점수). 세 가지 색 경단.
static func lollipop(ci: CanvasItem, c: Vector2, t: float) -> void:
	var tex := img("tg_kkochi")
	var p := c + Vector2(0, sin(t * 2.5 + c.x * 0.02) * 4.0)
	ci.draw_circle(p, 38.0, Color(1, 1, 1, 0.16))
	if tex != null:
		var ks := tex.get_size()
		ci.draw_texture_rect(tex, Rect2(p - Vector2(40.0 * ks.x / ks.y, 40), Vector2(80.0 * ks.x / ks.y, 80)), false)
		return
	ci.draw_line(p + Vector2(0, -34), p + Vector2(0, 40), Color8(200, 170, 120), 4.0)
	for k in 3:
		var q := p + Vector2(0, -20 + k * 20)
		ci.draw_circle(q, 12.0, INK)
		ci.draw_circle(q, 10.5, TTEOK[[1, 0, 2][k]])
		ci.draw_circle(q + Vector2(-3, -3), 3.0, Color(1, 1, 1, 0.7))


## 곶감 귀신 — 라운드 10 에서 뒤쫓아 온다("호랑이보다 무서운 곶감"). k: 얼마나 가까운가(0~1, 그림 크기).
static func goblin(ci: CanvasItem, feet: Vector2, k: float, t: float) -> void:
	var tex := img("tg_gotgam_ghost")
	var s := 0.8 + 0.4 * k
	if tex != null:
		var ts := tex.get_size()
		var hh := 150.0 * s
		ci.draw_texture_rect(tex, Rect2(feet - Vector2(ts.x * hh / ts.y * 0.5, hh), Vector2(ts.x * hh / ts.y, hh)), false)
		return
	var bob := absf(sin(t * 10.0)) * 8.0 * s
	var c := feet + Vector2(0, -64 * s - bob)
	G2.fill_fan(ci, G2.ellipse_pts(c, 50 * s, 42 * s), INK, c)
	G2.fill_fan(ci, G2.ellipse_pts(c, 47 * s, 39 * s), Color8(214, 100, 36), c)
	ci.draw_rect(Rect2(c.x - 6 * s, c.y - 52 * s, 12 * s, 14 * s), Color8(90, 60, 40))   # 꼭지
	for j in 4:   # 하얀 분
		ci.draw_circle(c + Vector2((-24 + j * 16) * s, (10 - (j % 2) * 20) * s), 5 * s, Color(1, 1, 1, 0.35))
	ci.draw_circle(c + Vector2(4 * s, -8 * s), 7 * s, Color(1, 1, 1))
	ci.draw_circle(c + Vector2(26 * s, -8 * s), 7 * s, Color(1, 1, 1))
	ci.draw_circle(c + Vector2(6 * s, -8 * s), 3 * s, INK)
	ci.draw_circle(c + Vector2(28 * s, -8 * s), 3 * s, INK)
	ci.draw_arc(c + Vector2(16 * s, 10 * s), 12 * s, 0.1, PI - 0.1, 10, INK, 4.0 * s)
	for j in 2:
		ci.draw_rect(Rect2(c.x - 20 * s + j * 26 * s, c.y + 36 * s, 12 * s, 26 * s + bob), Color8(150, 70, 30))

# ==================== 그림 파일 ====================

static var _tex := {}


static func img(name: String) -> Texture2D:
	if _tex.has(name):
		return _tex[name]
	var path := "res://art/tiger/%s.png" % name
	var tx: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex[name] = tx
	return tx
