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
		_strip(ci, far_tex, w, far_y, dist * 0.2, 0.55)
		if cam > 0.5:
			ci.draw_rect(Rect2(0, far_y - 1.0, w, ground_y - far_y + 1.0), FAR[theme])
	else:
		_far_code(ci, w, ground_y, theme, dist * 0.2)
	var near_tex := img("tg_bg_%d_near" % theme)
	if near_tex != null:
		_strip(ci, near_tex, w, ground_y, dist * 0.5, 0.85)
	else:
		_near_code(ci, w, ground_y, theme, dist * 0.5, t)
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
static func candy(ci: CanvasItem, c: Vector2, t: float, icon: bool = false) -> void:
	var tex := img("tg_tteok")
	var bob := 0.0 if icon else sin(t * 5.0 + c.x * 0.02) * 3.0
	var p := c + Vector2(0, bob)
	if tex != null:
		var cs := tex.get_size()
		ci.draw_texture_rect(tex, Rect2(p - Vector2(22, 22.0 * cs.y / cs.x), Vector2(44, 44.0 * cs.y / cs.x)), false)
		return
	var col: Color = TTEOK[int(absf(c.x) * 0.031) % 5] if not icon else TTEOK[1]
	var pts := PackedVector2Array()
	for k in 9:
		pts.append(p + Vector2(cos(PI + k * PI / 8.0) * 14.0, sin(PI + k * PI / 8.0) * 12.0 + 5.0))
	G2.fill_fan(ci, pts, col, p)
	G2.stroke(ci, pts, INK, 2.0)
	ci.draw_arc(p + Vector2(0, 5), 9.0, PI * 1.15, PI * 1.6, 6, Color(1, 1, 1, 0.7), 2.0)


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
