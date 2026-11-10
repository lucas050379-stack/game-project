class_name AcArt
extends RefCounted

## 아르카나 컬렉션 그림 — 자원 · 토큰 · 성물 카드 · 영웅 · 틀. 전부 코드(벡터)로 그리고,
## `art/arcana/<이름>.png` 가 있으면 그림 칸만 그 그림으로 바꿉니다(**그림이 없어도 돕니다**).
##   성물 그림: 카드마다 `ac_r_<자원>_<물건>`(카드 사전의 `art`) · 영웅 그림: `ac_hero_<id>` · 허브 카드: `ac_card`.
## **자원은 색만으로 가르지 않습니다** — 불꽃 · 물방울 · 잎 · 빛살 · 육각 결정 · 별, 모양이 다 다릅니다.
## **성물은 카드마다 물건이 다릅니다**(`AcD.GLYPHS` 45종 · [method relic_glyph]) — 같은 그림을 돌려 쓰지 마세요(사용자 지적 11-08).
## 틀은 둥근 모서리 사각형([method frame])입니다. 한때 단계마다 깎은 모서리 · 지붕 · 아치로 바꿨다가 사용자가 되돌렸습니다(11-08).
## 판 배경(원판 테이블 등)은 나중에 AI 그림으로 정하기로 했습니다.

static var _img := {}

const TIER_FRAME := ["round", "round", "round"]   ## 성물 단계별 틀(지금은 모두 둥근 모서리)
const TIER_TOP := [6.0, 6.0, 6.0]                 ## 틀 위쪽 여백(110 폭 기준)


static func img(name: String) -> Texture2D:
	if not _img.has(name):
		var p := "res://art/arcana/%s.png" % name
		_img[name] = load(p) if ResourceLoader.exists(p) else null
	return _img[name]

# ==================== 틀 ====================


## 틀의 꼭짓점 — 둥근 모서리 사각형. c = 모서리 반지름. (kind 는 예전 모양 이름의 자리 — 지금은 쓰지 않음)
static func frame_pts(r: Rect2, _kind: String, c: float) -> PackedVector2Array:
	return G2.round_rect(r, minf(c, minf(r.size.x, r.size.y) * 0.5), 0)   # 카드 틀은 둥근 모서리 그대로(사용자 결정 11-08) — 게임 기본 모서리(파임)를 안 따른다


## 틀 하나 — G2.panel 과 같다(둥근 모서리). c = 모서리 반지름.
static func frame(ci: CanvasItem, r: Rect2, fill: Color, edge: Color = Color(0, 0, 0, 0), lw: float = 0.0,
		c: float = 12.0, kind: String = "round") -> void:
	var pts := frame_pts(r, kind, c)
	G2.fill_fan(ci, pts, fill, r.get_center())
	if lw > 0.0:
		G2.stroke(ci, pts, edge, lw)

# ==================== 자원 모양 ====================


## 자원 하나의 상징 — 반지름 r 안에 들어간다.
static func gem(ci: CanvasItem, c: Vector2, r: float, col: int, alpha: float = 1.0) -> void:
	var fill: Color = AcD.COL[col]
	fill.a = alpha
	var edge := Color(P.INK, alpha)
	var pts := _shape(col, c, r)
	G2.fill_fan(ci, pts, fill, c)
	G2.stroke(ci, pts, edge, maxf(1.5, r * 0.12))
	ci.draw_circle(c + Vector2(-r * 0.28, -r * 0.3), r * 0.16, Color(1, 1, 1, 0.55 * alpha))


static func _shape(col: int, c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match col:
		0:   # 불꽃 — 위가 뾰족, 옆에 혀 둘
			var a := [Vector2(0, -1.0), Vector2(0.3, -0.45), Vector2(0.55, -0.6), Vector2(0.72, 0.05),
					Vector2(0.55, 0.62), Vector2(0, 0.85), Vector2(-0.55, 0.62), Vector2(-0.72, 0.05),
					Vector2(-0.5, -0.35), Vector2(-0.25, -0.2)]
			for v: Vector2 in a:
				pts.append(c + v * r)
		1:   # 물방울 — 뾰족한 위 꼭지 + 둥근 아래
			pts.append(c + Vector2(0, -r))
			for k in 17:
				var t := lerpf(-0.15 * PI, 1.15 * PI, k / 16.0)
				pts.append(c + Vector2(cos(t) * r * 0.66, sin(t) * r * 0.62 + r * 0.25))
		2:   # 잎 — 끝이 뾰족한 타원, 비스듬히
			for k in 20:
				var t := TAU * k / 20.0
				var p := Vector2(cos(t) * r * 0.95, sin(t) * r * 0.48 * (1.0 - 0.35 * absf(cos(t))))
				pts.append(c + p.rotated(-0.75))
		3:   # 빛 — 5각형 다이아몬드(위가 평평한 보석). 예전 네 갈래 반짝임은 속이 좁아 숫자가 안 읽혔다(사용자 요청 11-10)
			var a3 := [Vector2(-0.5, -0.72), Vector2(0.5, -0.72), Vector2(0.95, -0.2), Vector2(0, 0.95), Vector2(-0.95, -0.2)]
			for v: Vector2 in a3:
				pts.append(c + v * r)
		4:   # 그림자 — 길쭉한 육각 결정
			var a2 := [Vector2(0, -1.0), Vector2(0.62, -0.5), Vector2(0.62, 0.5), Vector2(0, 1.0),
					Vector2(-0.62, 0.5), Vector2(-0.62, -0.5)]
			for v: Vector2 in a2:
				pts.append(c + v * r)
		_:   # 별가루 — 다섯 갈래 별
			for k in 10:
				var t := TAU * k / 10.0 - PI * 0.5
				var rr := r if k % 2 == 0 else r * 0.45
				pts.append(c + Vector2(cos(t), sin(t)) * rr)
	return pts


## 자원 토큰 — 카지노 칩처럼(사용자 지적 11-09 "코인이 투박하다"): 바깥 테 + 테두리 눈금 + 안쪽 면 + 자원 모양 + 광택.
static func token(ci: CanvasItem, c: Vector2, r: float, col: int, n: int = -1, dim: bool = false) -> void:
	var a := 0.35 if dim else 1.0
	_chip(ci, c, r, col, a)
	gem(ci, c, r * 0.5, col, a)
	if n >= 0:
		var b := c + Vector2(r * 0.72, r * 0.72)
		ci.draw_circle(b, r * 0.42, Color(P.INK, a))
		ci.draw_arc(b, r * 0.42, 0, TAU, 20, Color(1, 0.86, 0.5, 0.8 * a), maxf(1.5, r * 0.06), true)
		G2.text_mid(ci, b, str(n), r * 0.52, Color(1, 1, 1, a))


## 칩 몸통(토큰 · 내 판의 토큰 공통).
static func _chip(ci: CanvasItem, c: Vector2, r: float, col: int, a: float) -> void:
	var base: Color = AcD.COL[col]
	ci.draw_circle(c + Vector2(0, r * 0.12), r, Color(0, 0, 0, 0.35 * a))
	ci.draw_circle(c, r, Color(base.darkened(0.35), a))
	for i in 8:   # 테두리 눈금
		var ang := TAU * i / 8.0
		ci.draw_arc(c, r * 0.86, ang - 0.13, ang + 0.13, 4, Color(base.lightened(0.55), a), r * 0.2, true)
	ci.draw_circle(c, r * 0.7, Color(base.lightened(0.08), a))
	ci.draw_arc(c, r * 0.7, 0, TAU, 28, Color(base.darkened(0.45), a), maxf(1.2, r * 0.06), true)
	ci.draw_arc(c, r, 0, TAU, 32, Color(AcD.edge(col), a), maxf(1.5, r * 0.08), true)
	ci.draw_arc(c, r * 0.62, PI * 1.1, PI * 1.6, 10, Color(1, 1, 1, 0.45 * a), maxf(1.0, r * 0.08), true)   # 광택


## 플레이어 판의 토큰 — 작은 칩이라 상징 대신 개수를 가운데에 크게(0 이면 흐리게).
static func token_num(ci: CanvasItem, c: Vector2, r: float, col: int, n: int) -> void:
	var a := 0.3 if n == 0 else 1.0
	_chip(ci, c, r, col, a)
	if n == 0:
		gem(ci, c, r * 0.45, col, 0.4)
	else:
		# 글자색은 자원마다(AcD.INK_ON) — 흰 칩(빛 · 별가루)에 흰 숫자는 안 읽혔다(사용자 지적 11-10)
		var ink: Color = AcD.INK_ON[col]
		var ol := Color(0, 0, 0, 0.75) if ink.get_luminance() > 0.5 else Color(1, 1, 1, 0.8)
		G2.text_mid(ci, c, str(n), r * 1.05, ink, r * 0.28, ol)


# ==================== 성물 물건 ====================

## 물건 그림 — 단위 좌표(-1~1, 아래가 +y)의 조각 목록. 조각: [모양, 색, 값...]
##   poly 꼭짓점 · circle x y r · ell x y rx ry · rect x y w h · line x1 y1 x2 y2 굵기 · arc x y r 굵기 a0 a1
## 색: m 자원 색 · M 진한 자원 색 · L 밝은 자원 색 · g 금 · s 은 · w 나무 · d 어두움 · l 밝음
const GLYPH_PARTS := {
	"ring": [["arc", "g", 0, 0.2, 0.55, 0.22, 0.0, 6.2832], ["poly", "m", [0, -0.85, 0.3, -0.45, 0, -0.15, -0.3, -0.45]]],
	"amulet": [["arc", "g", 0, -0.2, 0.75, 0.07, 3.6, 5.8], ["poly", "g", [0, -0.35, 0.55, 0.2, 0, 0.85, -0.55, 0.2]],
			["poly", "m", [0, -0.1, 0.32, 0.22, 0, 0.58, -0.32, 0.22]]],
	"candle": [["rect", "l", -0.25, -0.25, 0.5, 0.95], ["rect", "g", -0.5, 0.7, 1.0, 0.18],
			["poly", "m", [0, -0.95, 0.2, -0.55, 0, -0.32, -0.2, -0.55]], ["line", "d", 0, -0.32, 0, -0.25, 0.05]],
	"pouch": [["poly", "w", [-0.3, -0.45, 0.3, -0.45, 0.7, 0.3, 0.45, 0.8, -0.45, 0.8, -0.7, 0.3]],
			["poly", "w", [-0.35, -0.75, 0.35, -0.75, 0.2, -0.45, -0.2, -0.45]], ["line", "m", -0.35, -0.45, 0.35, -0.45, 0.1],
			["circle", "m", 0, 0.25, 0.2]],
	"key": [["arc", "g", -0.45, -0.35, 0.32, 0.14, 0.0, 6.2832], ["circle", "m", -0.45, -0.35, 0.14],
			["line", "g", -0.2, -0.12, 0.65, 0.72, 0.16], ["line", "g", 0.4, 0.48, 0.58, 0.3, 0.12], ["line", "g", 0.55, 0.62, 0.72, 0.45, 0.12]],
	"feather": [["poly", "m", [0.55, -0.9, 0.7, -0.4, 0.3, 0.3, -0.35, 0.7, -0.15, 0.1, 0.15, -0.5]],
			["line", "l", 0.55, -0.85, -0.6, 0.9, 0.06]],
	"flute": [["line", "w", -0.8, 0.6, 0.8, -0.6, 0.24], ["circle", "d", -0.3, 0.22, 0.06], ["circle", "d", 0.0, 0.0, 0.06],
			["circle", "d", 0.3, -0.22, 0.06], ["poly", "m", [-0.65, 0.35, -0.4, 0.75, -0.55, 0.9, -0.8, 0.5]]],
	"potion": [["circle", "m", 0, 0.3, 0.55], ["rect", "l", -0.18, -0.55, 0.36, 0.4], ["rect", "w", -0.24, -0.8, 0.48, 0.25],
			["circle", "L", -0.18, 0.12, 0.12]],
	"shell": [["poly", "m", [0, 0.8, -0.85, -0.1, -0.5, -0.65, 0, -0.8, 0.5, -0.65, 0.85, -0.1]],
			["line", "L", 0, 0.75, 0, -0.75, 0.06], ["line", "L", 0, 0.75, -0.45, -0.55, 0.06], ["line", "L", 0, 0.75, 0.45, -0.55, 0.06],
			["rect", "M", -0.25, 0.65, 0.5, 0.2]],
	"bell": [["poly", "g", [-0.2, -0.7, 0.2, -0.7, 0.45, 0.2, 0.75, 0.55, -0.75, 0.55, -0.45, 0.2]], ["circle", "d", 0, 0.7, 0.16],
			["circle", "m", 0, -0.82, 0.14], ["line", "m", -0.55, 0.38, 0.55, 0.38, 0.08]],
	"quill": [["poly", "m", [0.75, -0.9, 0.8, -0.3, 0.2, 0.35, 0.0, 0.3, 0.25, -0.35]], ["line", "d", 0.1, 0.3, -0.25, 0.7, 0.06],
			["rect", "d", -0.75, 0.45, 0.5, 0.45], ["rect", "m", -0.7, 0.4, 0.4, 0.1]],
	"dice": [["poly", "l", [0, -0.85, 0.75, -0.45, 0.75, 0.45, 0, 0.85, -0.75, 0.45, -0.75, -0.45]],
			["line", "d", 0, 0.0, 0, 0.85, 0.04], ["line", "d", 0, 0.0, 0.75, -0.45, 0.04], ["line", "d", 0, 0.0, -0.75, -0.45, 0.04],
			["circle", "m", 0, -0.45, 0.1], ["circle", "m", -0.4, 0.2, 0.09], ["circle", "m", 0.4, 0.35, 0.09], ["circle", "m", 0.4, 0.05, 0.09]],
	"acorn": [["ell", "w", 0, 0.25, 0.48, 0.6], ["poly", "M", [-0.62, -0.15, 0.62, -0.15, 0.45, -0.5, -0.45, -0.5]],
			["line", "w", 0, -0.5, 0.1, -0.85, 0.08], ["poly", "m", [0.12, -0.75, 0.65, -0.95, 0.45, -0.55]]],
	"mushroom": [["poly", "m", [-0.85, 0.0, -0.6, -0.55, 0, -0.8, 0.6, -0.55, 0.85, 0.0]], ["rect", "l", -0.22, 0.0, 0.44, 0.75],
			["circle", "l", -0.35, -0.3, 0.12], ["circle", "l", 0.3, -0.45, 0.1], ["circle", "l", 0.5, -0.15, 0.08]],
	"coin": [["circle", "g", 0, 0, 0.8], ["circle", "m", 0, 0, 0.55], ["poly", "g", [0, -0.35, 0.1, -0.1, 0.35, -0.1, 0.15, 0.05, 0.22, 0.32, 0, 0.17, -0.22, 0.32, -0.15, 0.05, -0.35, -0.1, -0.1, -0.1]]],
	"compass": [["circle", "s", 0, 0, 0.8], ["circle", "l", 0, 0, 0.62], ["poly", "m", [0, -0.55, 0.13, 0, 0, 0.1, -0.13, 0]],
			["poly", "d", [0, 0.55, 0.13, 0, -0.13, 0]], ["circle", "g", 0, -0.88, 0.1]],
	"hourglass": [["rect", "w", -0.6, -0.9, 1.2, 0.15], ["rect", "w", -0.6, 0.75, 1.2, 0.15],
			["poly", "l", [-0.45, -0.75, 0.45, -0.75, 0.08, 0, 0.45, 0.75, -0.45, 0.75, -0.08, 0]],
			["poly", "m", [-0.3, 0.75, 0.3, 0.75, 0, 0.35]], ["poly", "m", [-0.25, -0.5, 0.25, -0.5, 0, -0.2]]],
	"lantern": [["arc", "g", 0, -0.7, 0.22, 0.08, 3.14, 6.28], ["rect", "g", -0.5, -0.55, 1.0, 0.12], ["rect", "g", -0.5, 0.65, 1.0, 0.15],
			["rect", "L", -0.4, -0.43, 0.8, 1.08], ["circle", "m", 0, 0.1, 0.25], ["line", "g", -0.42, -0.43, -0.42, 0.65, 0.06],
			["line", "g", 0.42, -0.43, 0.42, 0.65, 0.06]],
	"dagger": [["poly", "s", [0, -0.95, 0.16, -0.75, 0.13, 0.15, -0.13, 0.15, -0.16, -0.75]], ["rect", "g", -0.45, 0.15, 0.9, 0.13],
			["rect", "w", -0.1, 0.28, 0.2, 0.45], ["circle", "m", 0, 0.82, 0.14]],
	"mask": [["poly", "m", [-0.85, -0.45, 0, -0.6, 0.85, -0.45, 0.7, 0.3, 0.3, 0.55, 0, 0.35, -0.3, 0.55, -0.7, 0.3]],
			["ell", "d", -0.38, -0.12, 0.2, 0.12], ["ell", "d", 0.38, -0.12, 0.2, 0.12], ["line", "g", -0.85, -0.45, -1.0, -0.2, 0.06]],
	"sword": [["poly", "s", [0, -0.98, 0.12, -0.8, 0.1, 0.35, -0.1, 0.35, -0.12, -0.8]], ["line", "L", 0, -0.8, 0, 0.3, 0.04],
			["rect", "g", -0.5, 0.35, 1.0, 0.12], ["rect", "w", -0.08, 0.47, 0.16, 0.35], ["circle", "m", 0, 0.88, 0.12]],
	"helmet": [["poly", "m", [-0.7, 0.55, -0.72, -0.05, -0.45, -0.5, 0, -0.65, 0.45, -0.5, 0.72, -0.05, 0.7, 0.55]],
			["rect", "d", -0.5, 0.0, 1.0, 0.16], ["line", "d", 0, 0.16, 0, 0.55, 0.12], ["poly", "g", [-0.08, -0.65, 0.08, -0.65, 0.3, -0.98, 0.05, -0.9]],
			["line", "g", -0.7, 0.55, 0.7, 0.55, 0.08]],
	"banner": [["line", "w", -0.65, -0.95, -0.65, 0.95, 0.1], ["poly", "m", [-0.6, -0.85, 0.75, -0.85, 0.75, 0.35, 0.05, 0.1, -0.6, 0.35]],
			["circle", "g", 0.08, -0.38, 0.22], ["circle", "g", -0.65, -0.95, 0.09]],
	"shield": [["poly", "m", [-0.75, -0.8, 0.75, -0.8, 0.7, 0.1, 0, 0.9, -0.7, 0.1]], ["line", "l", 0, -0.65, 0, 0.6, 0.1],
			["line", "l", -0.5, -0.2, 0.5, -0.2, 0.1], ["circle", "g", 0, -0.2, 0.13]],
	"harp": [["poly", "g", [-0.6, 0.85, -0.6, -0.85, -0.35, -0.85, 0.75, 0.6, 0.6, 0.85]], ["poly", "M", [-0.45, 0.7, -0.45, -0.65, 0.5, 0.65]],
			["line", "l", -0.25, -0.4, -0.25, 0.7, 0.03], ["line", "l", 0.0, -0.1, 0.0, 0.7, 0.03], ["line", "l", 0.25, 0.2, 0.25, 0.7, 0.03],
			["circle", "m", -0.48, -0.85, 0.13]],
	"book": [["rect", "M", -0.7, -0.8, 1.4, 1.6], ["rect", "l", -0.55, -0.68, 1.15, 1.4], ["rect", "m", -0.7, -0.8, 1.25, 1.5],
			["poly", "g", [-0.05, -0.4, 0.25, -0.05, -0.05, 0.3, -0.35, -0.05]], ["rect", "g", 0.45, -0.2, 0.15, 0.35]],
	"staff": [["line", "w", 0.45, -0.45, -0.55, 0.95, 0.14], ["arc", "g", 0.5, -0.55, 0.32, 0.08, 2.4, 5.6], ["circle", "m", 0.5, -0.55, 0.22],
			["circle", "L", 0.43, -0.62, 0.07]],
	"armor": [["poly", "s", [-0.5, -0.75, 0.5, -0.75, 0.6, -0.3, 0.5, 0.75, -0.5, 0.75, -0.6, -0.3]], ["ell", "s", -0.72, -0.55, 0.28, 0.2],
			["ell", "s", 0.72, -0.55, 0.28, 0.2], ["line", "m", 0, -0.7, 0, 0.7, 0.12], ["line", "m", -0.45, 0.2, 0.45, 0.2, 0.1]],
	"mirror": [["ell", "g", 0, -0.2, 0.55, 0.68], ["ell", "L", 0, -0.2, 0.42, 0.55], ["line", "w", 0, 0.48, 0, 0.95, 0.15],
			["line", "l", -0.15, -0.5, 0.05, -0.65, 0.06]],
	"scroll": [["rect", "l", -0.55, -0.6, 1.1, 1.2], ["ell", "w", 0, -0.62, 0.7, 0.12], ["ell", "w", 0, 0.62, 0.7, 0.12],
			["line", "d", -0.35, -0.25, 0.35, -0.25, 0.04], ["line", "d", -0.35, 0.0, 0.25, 0.0, 0.04], ["circle", "m", 0.2, 0.3, 0.15]],
	"gauntlet": [["poly", "s", [-0.45, 0.85, -0.5, -0.1, -0.35, -0.8, 0.0, -0.85, 0.3, -0.75, 0.6, -0.3, 0.5, 0.0, 0.4, 0.85]],
			["rect", "m", -0.55, 0.45, 1.05, 0.25], ["line", "d", -0.2, -0.8, -0.2, -0.35, 0.04], ["line", "d", 0.1, -0.8, 0.1, -0.35, 0.04]],
	"hammer": [["line", "w", 0.0, -0.3, 0.0, 0.95, 0.15], ["rect", "s", -0.65, -0.75, 1.3, 0.5], ["rect", "m", -0.15, -0.75, 0.3, 0.5],
			["line", "d", -0.65, -0.25, 0.65, -0.25, 0.04]],
	"trident": [["line", "g", 0, -0.4, 0, 0.95, 0.12], ["poly", "g", [-0.6, -0.95, -0.45, -0.35, 0.45, -0.35, 0.6, -0.95, 0.35, -0.55, 0.12, -0.95, 0, -0.55, -0.12, -0.95, -0.35, -0.55]],
			["circle", "m", 0, -0.3, 0.13]],
	"bow": [["arc", "w", -0.5, 0, 0.95, 0.13, -1.1, 1.1], ["line", "l", -0.06, -0.85, -0.06, 0.85, 0.03],
			["line", "s", -0.7, 0, 0.8, 0, 0.06], ["poly", "s", [0.95, 0, 0.75, -0.12, 0.75, 0.12]], ["poly", "m", [-0.7, 0, -0.9, -0.18, -0.6, -0.05]]],
	"horn": [["poly", "l", [-0.85, 0.55, -0.6, 0.15, -0.1, -0.2, 0.45, -0.6, 0.8, -0.85, 0.85, -0.55, 0.55, -0.2, 0.0, 0.3, -0.5, 0.75]],
			["line", "g", -0.25, 0.05, -0.05, 0.45, 0.1], ["line", "g", 0.3, -0.35, 0.5, -0.05, 0.1], ["ell", "m", 0.82, -0.7, 0.1, 0.18]],
	"heart": [["poly", "m", [0, 0.85, -0.75, 0.05, -0.8, -0.4, -0.45, -0.75, 0, -0.45, 0.45, -0.75, 0.8, -0.4, 0.75, 0.05]],
			["line", "M", 0, -0.45, 0.15, 0.2, 0.06], ["line", "M", 0.15, 0.2, -0.2, 0.5, 0.06], ["circle", "L", -0.4, -0.4, 0.15]],
	"egg": [["ell", "m", 0, 0.08, 0.6, 0.8], ["line", "g", -0.55, -0.15, 0.55, 0.1, 0.07], ["line", "g", -0.5, 0.35, 0.55, 0.5, 0.07],
			["circle", "L", -0.25, -0.35, 0.14], ["poly", "g", [-0.3, -0.1, -0.15, -0.3, 0.0, -0.05, 0.15, -0.28, 0.3, -0.05]]],
	"crown": [["poly", "g", [-0.8, 0.5, -0.8, -0.55, -0.4, -0.1, 0, -0.75, 0.4, -0.1, 0.8, -0.55, 0.8, 0.5]],
			["rect", "M", -0.8, 0.3, 1.6, 0.25], ["circle", "m", 0, 0.42, 0.13], ["circle", "m", -0.5, 0.42, 0.1], ["circle", "m", 0.5, 0.42, 0.1],
			["circle", "l", 0, -0.75, 0.1]],
	"throne": [["poly", "m", [-0.55, 0.1, -0.55, -0.7, -0.3, -0.95, 0.3, -0.95, 0.55, -0.7, 0.55, 0.1]], ["rect", "w", -0.75, 0.1, 1.5, 0.3],
			["line", "w", -0.65, 0.4, -0.65, 0.95, 0.12], ["line", "w", 0.65, 0.4, 0.65, 0.95, 0.12], ["poly", "g", [0, -0.7, 0.2, -0.35, 0, -0.1, -0.2, -0.35]]],
	"orb": [["circle", "m", 0, 0.15, 0.68], ["arc", "g", 0, 0.15, 0.68, 0.08, 0.0, 6.2832], ["line", "g", -0.68, 0.15, 0.68, 0.15, 0.08],
			["line", "g", 0, -0.53, 0, -0.95, 0.1], ["line", "g", -0.18, -0.78, 0.18, -0.78, 0.1], ["circle", "L", -0.25, -0.1, 0.15]],
	"scepter": [["line", "g", 0.35, -0.35, -0.55, 0.9, 0.13], ["poly", "m", [0.5, -0.95, 0.8, -0.55, 0.5, -0.15, 0.2, -0.55]],
			["arc", "g", 0.5, -0.55, 0.42, 0.06, 2.2, 4.0], ["circle", "g", -0.1, 0.28, 0.12]],
	"chalice": [["poly", "g", [-0.65, -0.75, 0.65, -0.75, 0.45, -0.1, 0.12, 0.1, 0.1, 0.55, 0.45, 0.85, -0.45, 0.85, -0.1, 0.55, -0.12, 0.1, -0.45, -0.1]],
			["ell", "m", 0, -0.72, 0.6, 0.12], ["circle", "m", 0, -0.32, 0.14]],
	"sundisk": [["poly", "g", [0, -0.95, 0.22, -0.5, 0.67, -0.67, 0.5, -0.22, 0.95, 0, 0.5, 0.22, 0.67, 0.67, 0.22, 0.5, 0, 0.95, -0.22, 0.5, -0.67, 0.67, -0.5, 0.22, -0.95, 0, -0.5, -0.22, -0.67, -0.67, -0.22, -0.5]],
			["circle", "m", 0, 0, 0.42], ["circle", "L", -0.12, -0.12, 0.13]],
	"wing": [["poly", "l", [-0.85, 0.6, -0.6, -0.2, -0.1, -0.75, 0.6, -0.95, 0.9, -0.7, 0.55, -0.45, 0.8, -0.25, 0.4, -0.05, 0.6, 0.2, 0.1, 0.3, 0.2, 0.55]],
			["poly", "m", [0.6, -0.95, 0.9, -0.7, 0.55, -0.45, 0.8, -0.25, 0.4, -0.05, 0.6, 0.2, 0.3, 0.1, 0.3, -0.5]]],
	"eye": [["poly", "l", [-0.9, 0, -0.45, -0.45, 0, -0.55, 0.45, -0.45, 0.9, 0, 0.45, 0.45, 0, 0.55, -0.45, 0.45]],
			["circle", "m", 0, 0, 0.36], ["circle", "d", 0, 0, 0.15], ["circle", "l", -0.1, -0.1, 0.07],
			["line", "g", 0, -0.62, 0, -0.95, 0.06], ["line", "g", -0.5, -0.55, -0.68, -0.82, 0.06], ["line", "g", 0.5, -0.55, 0.68, -0.82, 0.06]],
}


static func _role(r: String, col: int) -> Color:
	var m: Color = AcD.COL[col]
	match r:
		"m":
			return m
		"M":
			return m.darkened(0.35)
		"L":
			return m.lightened(0.45)
		"g":
			return Color8(240, 196, 80)
		"s":
			return Color8(200, 208, 224)
		"w":
			return Color8(150, 104, 64)
		"d":
			return Color8(56, 40, 66)
	return Color8(250, 244, 230)


## 성물의 물건 하나 — 가운데 c, 반지름 s. 그림자(어두운 자원)는 테를 밝게.
static func relic_glyph(ci: CanvasItem, c: Vector2, s: float, glyph: String, col: int, alpha: float = 1.0) -> void:
	var parts: Array = GLYPH_PARTS.get(glyph, [["circle", "m", 0, 0, 0.6]])
	var lw := maxf(1.2, s * 0.07)
	var ink := Color(P.INK, alpha)
	for p: Array in parts:
		var fill := _role(String(p[1]), col)
		fill.a *= alpha
		match String(p[0]):
			"poly":
				var raw: Array = p[2]
				var pts := PackedVector2Array()
				var cen := Vector2.ZERO
				for i in range(0, raw.size(), 2):
					var v := c + Vector2(float(raw[i]), float(raw[i + 1])) * s
					pts.append(v)
					cen += v
				cen /= pts.size()
				G2.fill_fan(ci, pts, fill, cen)
				G2.stroke(ci, pts, ink, lw)
			"circle":
				var cc := c + Vector2(float(p[2]), float(p[3])) * s
				var rr := float(p[4]) * s
				ci.draw_circle(cc, rr, fill)
				ci.draw_arc(cc, rr, 0, TAU, 20, ink, lw, true)
			"ell":
				var pts2 := G2.ellipse_pts(c + Vector2(float(p[2]), float(p[3])) * s, float(p[4]) * s, float(p[5]) * s, 18)
				G2.fill_fan(ci, pts2, fill, c + Vector2(float(p[2]), float(p[3])) * s)
				G2.stroke(ci, pts2, ink, lw)
			"rect":
				var rr2 := Rect2(c + Vector2(float(p[2]), float(p[3])) * s, Vector2(float(p[4]), float(p[5])) * s)
				ci.draw_rect(rr2, fill)
				ci.draw_rect(rr2, ink, false, lw)
			"line":
				var a := c + Vector2(float(p[2]), float(p[3])) * s
				var b := c + Vector2(float(p[4]), float(p[5])) * s
				var w := float(p[6]) * s
				ci.draw_line(a, b, ink, w + lw * 1.6)
				ci.draw_line(a, b, fill, w)
			"arc":
				var ac := c + Vector2(float(p[2]), float(p[3])) * s
				var ar := float(p[4]) * s
				var aw := float(p[5]) * s
				ci.draw_arc(ac, ar, float(p[6]), float(p[7]), 28, ink, aw + lw * 1.6, true)
				ci.draw_arc(ac, ar, float(p[6]), float(p[7]), 28, fill, aw, true)

# ==================== 성물 카드 ====================


# ==================== 카드 꾸밈(고급 보드게임풍, 사용자 요청 11-09) ====================

## 단계별 금속 — 견습 동 · 장인 은 · 전설 금.
const METAL := [Color8(196, 134, 78), Color8(206, 214, 226), Color8(240, 196, 96)]


## 위아래 그라데이션으로 칠한 둥근 사각형(가운데에서 부채꼴 — draw_polygon 대신, CLAUDE.md 단추 규칙).
static func _grad(ci: CanvasItem, r: Rect2, top: Color, bot: Color, c: float) -> void:
	var pts := frame_pts(r, "round", c)
	var cen := r.get_center()
	var cc := top.lerp(bot, 0.5)
	for i in pts.size():
		var p0: Vector2 = pts[i]
		var p1: Vector2 = pts[(i + 1) % pts.size()]
		var c0 := top.lerp(bot, clampf((p0.y - r.position.y) / r.size.y, 0.0, 1.0))
		var c1 := top.lerp(bot, clampf((p1.y - r.position.y) / r.size.y, 0.0, 1.0))
		ci.draw_primitive(PackedVector2Array([cen, p0, p1]), PackedColorArray([cc, c0, c1]), PackedVector2Array())


## 점수 메달 — 금화(테 · 안쪽 면 · 광택) 위에 숫자.
static func medal(ci: CanvasItem, c: Vector2, r: float, n: int, metal: Color = Color8(240, 196, 96)) -> void:
	ci.draw_circle(c + Vector2(0, r * 0.12), r, Color(0, 0, 0, 0.35))
	ci.draw_circle(c, r, metal.darkened(0.3))
	ci.draw_circle(c, r * 0.82, metal)
	ci.draw_arc(c, r * 0.82, 0, TAU, 24, metal.darkened(0.45), maxf(1.0, r * 0.07), true)
	ci.draw_arc(c, r, 0, TAU, 28, P.INK, maxf(1.2, r * 0.1), true)
	ci.draw_arc(c, r * 0.62, PI * 1.1, PI * 1.6, 8, Color(1, 1, 1, 0.55), maxf(1.0, r * 0.08), true)
	G2.text_mid(ci, c + Vector2(0, r * 0.04), str(n), r * 1.25, Color8(70, 40, 16), r * 0.16, Color(1, 0.95, 0.8, 0.8))


## 비용 보석 — 자원 모양(불꽃 · 물방울 · 잎 · 별 · 보석) 안에 숫자. 색을 못 가려도 모양으로 읽힌다(색약).
static func cost_gem(ci: CanvasItem, c: Vector2, r: float, col: int, n: int) -> void:
	var pts := _shape(col, c, r)
	var pts_sh := _shape(col, c + Vector2(0, r * 0.12), r)
	G2.fill_fan(ci, pts_sh, Color(0, 0, 0, 0.35), c + Vector2(0, r * 0.12))
	G2.fill_fan(ci, pts, AcD.COL[col], c)
	G2.stroke(ci, pts, P.INK, maxf(1.5, r * 0.13))
	ci.draw_circle(c + Vector2(-r * 0.3, -r * 0.32), r * 0.14, Color(1, 1, 1, 0.55))
	# 글자색은 자원마다(AcD.INK_ON) — 흰 별(빛) 위에 흰 숫자는 별 끝과 섞여 "-3-" 처럼 보였다(11-09)
	var ink: Color = AcD.INK_ON[col]
	var ol := Color(0, 0, 0, 0.85) if ink.get_luminance() > 0.5 else Color(1, 1, 1, 0.7)
	G2.text_mid(ci, c + Vector2(0, r * 0.08), str(n), r * 1.2, ink, r * 0.3, ol)


## 이름 리본 — 양 끝이 제비꼬리로 파인 띠.
static func ribbon(ci: CanvasItem, r: Rect2, fill: Color, edge: Color, k: float) -> void:
	var n := r.size.y * 0.35
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x - n, r.get_center().y),
			r.end, Vector2(r.position.x, r.end.y), Vector2(r.position.x + n, r.get_center().y)])
	G2.fill_fan(ci, pts, fill, r.get_center())
	G2.stroke(ci, pts, edge, 1.5 * k)


## 성물 카드. `hl` 0 없음 · 1 살 수 있음(초록 테) · 2 고름(금 테). 단계마다 틀 모양이 다르다.
## 칸 폭에 맞춘 글자 크기 — 기준(docs/adr/0007)인 20px 까지 키우되 폭을 넘으면 줄인다(Jua 한글 한 자 폭 ≈ 글자 크기).
static func fit_size(s: String, width: float, cap: float) -> float:
	return minf(cap, width / maxf(1.0, s.length()))


## 카드 둘레의 깜빡이는 강조 테 — hl 1 = 살 수 있음(초록), 2 = 고른 것(금빛). 카드 몸통보다 **먼저**(밑에) 그린다.
## 판 화면은 카드 몸통을 판이 바뀔 때만 다시 그리므로(main 의 그리기 층), 이 테만 따로 매 프레임 아래 층에 그린다.
static func hl_frame(ci: CanvasItem, r: Rect2, hl: int, t: float) -> void:
	var k := r.size.x / 110.0
	if hl == 2:
		frame(ci, r.grow(5 * k), Color(1, 0.85, 0.3, 0.75 + 0.25 * sin(t * 6.0)), Color(), 0.0, 16 * k)
	elif hl == 1:
		frame(ci, r.grow(4 * k), Color(0.5, 1, 0.6, 0.55 + 0.2 * sin(t * 4.0)), Color(), 0.0, 15 * k)


## 성물 카드 — 금속 테(단계) · 그라데이션 몸통 · 모서리 장식 · 점수 메달 · 보석 홈 · 그림 창 · 이름 리본 · 비용 보석.
static func card(ci: CanvasItem, r: Rect2, c: Dictionary, hl: int = 0, t: float = 0.0, dim: bool = false) -> void:
	var tier: int = c.tier
	var col: int = c.col
	var tc: Color = AcD.TIER_COL[tier]
	var metal: Color = METAL[tier]
	var k := r.size.x / 110.0
	var top: float = TIER_TOP[tier] * k
	hl_frame(ci, r, hl, t)
	frame(ci, r.grow(1.5 * k), Color(0, 0, 0, 0.45), Color(), 0.0, 13 * k)
	_grad(ci, r, tc.darkened(0.25), tc.darkened(0.62), 12 * k)
	G2.stroke(ci, frame_pts(r, "round", 12 * k), metal, 3.0 * k)
	G2.stroke(ci, frame_pts(r.grow(-4.5 * k), "round", 9 * k), Color(metal, 0.45), 1.2 * k)
	for cx in [r.position.x + 7 * k, r.end.x - 7 * k]:
		for cy in [r.position.y + 7 * k, r.end.y - 7 * k]:
			_diamond(ci, Vector2(cx, cy), 3.5 * k + tier * 0.6 * k, metal.lightened(0.2))
	var pic := Rect2(r.position + Vector2(8 * k, top + 26 * k), Vector2(r.size.x - 16 * k, r.size.y * 0.46 - top * 0.4))
	var bg: Color = AcD.COL[col]
	frame(ci, pic.grow(2 * k), Color(0, 0, 0, 0.55), Color(), 0.0, 7 * k)
	frame(ci, pic, bg.darkened(0.45).lerp(tc, 0.3), Color(), 0.0, 6 * k)
	var tex := img(String(c.get("art", "")))
	if tex != null:
		_tex_cover(ci, tex, pic.grow(-1 * k))
	else:
		_relic_pic(ci, pic, c, t)
	G2.stroke(ci, frame_pts(pic, "round", 6 * k), metal.darkened(0.1), 1.8 * k)
	if int(c.pts) > 0:
		medal(ci, r.position + Vector2(17 * k, top + 13 * k), 12 * k, int(c.pts), metal if tier == 2 else Color8(240, 196, 96))
	var sock := r.position + Vector2(r.size.x - 17 * k, top + 13 * k)
	ci.draw_circle(sock, 12 * k, Color(0, 0, 0, 0.45))
	ci.draw_arc(sock, 12 * k, 0, TAU, 24, metal, 1.8 * k, true)
	gem(ci, sock, 9 * k, col)
	var rib := Rect2(r.position.x + 4 * k, pic.end.y - 4 * k, r.size.x - 8 * k, 20 * k)
	ribbon(ci, rib, tc.darkened(0.5).lerp(Color8(120, 30, 50), 0.35), metal, k)
	G2.text_mid(ci, rib.get_center(), String(c.name), fit_size(String(c.name), rib.size.x - 22 * k, 20 * k), Color(1, 0.96, 0.88), 3 * k)
	var costs := []
	for i in AcD.N_COL:
		if int(c.cost[i]) > 0:
			costs.append(i)
	var cy := r.end.y - 18 * k
	var step := minf(29.0 * k, (r.size.x - 14 * k) / maxf(1.0, costs.size()))
	var x0 := r.get_center().x - step * (costs.size() - 1) * 0.5
	for j in costs.size():
		var i: int = costs[j]
		cost_gem(ci, Vector2(x0 + j * step, cy), 14 * k, i, int(c.cost[i]))
	if dim:
		frame(ci, r, Color(0, 0, 0, 0.45), Color(), 0.0, 12 * k)


static func _relic_pic(ci: CanvasItem, pic: Rect2, c: Dictionary, t: float) -> void:
	var tier: int = c.tier
	var col: int = c.col
	var cen := pic.get_center()
	var s := minf(pic.size.x, pic.size.y)
	var glow: Color = AcD.COL[col]
	if tier == 2:
		for k in 3:
			ci.draw_circle(cen, s * (0.3 + k * 0.08) + sin(t * 2.0 + k) * 1.5, Color(glow, 0.12))
	var base_y := cen.y + s * 0.4
	if tier == 0:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(cen.x - s * 0.42, base_y), Vector2(cen.x + s * 0.42, base_y),
				Vector2(cen.x + s * 0.32, base_y - s * 0.1), Vector2(cen.x - s * 0.32, base_y - s * 0.1)]), Color(0, 0, 0, 0.25))
	else:
		var st := PackedVector2Array([Vector2(cen.x - s * 0.36, base_y), Vector2(cen.x + s * 0.36, base_y),
				Vector2(cen.x + s * 0.24, base_y - s * 0.12), Vector2(cen.x - s * 0.24, base_y - s * 0.12)])
		G2.fill_fan(ci, st, Color8(200, 170, 110) if tier == 2 else Color8(160, 130, 95), Vector2(cen.x, base_y - s * 0.06))
		G2.stroke(ci, st, P.INK, 1.5)
	relic_glyph(ci, cen + Vector2(0, -s * 0.05 + sin(t * 2.0 + int(c.id)) * 1.2), s * 0.36, String(c.get("glyph", "")), col)


## 상대 판의 색별 묶음 — 장수만큼 겹친 카드 모양(셋까지) + 가운데 숫자. 0 이면 빈 자리 테두리만.
static func stack(ci: CanvasItem, r: Rect2, col: int, n: int) -> void:
	if n <= 0:
		frame(ci, r, Color(AcD.COL[col], 0.12), Color(AcD.COL[col], 0.35), 1.5, 5)
		return
	var layers := mini(n, 3)
	for j in range(layers - 1, -1, -1):
		var rr := Rect2(r.position + Vector2(j * 3, -j * 3), r.size)
		frame(ci, rr, AcD.COL[col].darkened(0.15 * j), AcD.edge(col), 2.0, 5)
	G2.text_mid(ci, r.get_center(), str(n), r.size.y * 0.55, AcD.INK_ON[col], r.size.y * 0.12,
			P.INK if AcD.INK_ON[col] == Color(1, 1, 1) else Color(1, 1, 1, 0.6))


## 카드 뒷면(더미) — 앞면과 같은 금속 테 · 가운데 문장(단계만큼 마름모) · 아래 장수 명판. n = 남은 장수.
static func card_back(ci: CanvasItem, r: Rect2, tier: int, n: int, hl: int = 0, t: float = 0.0) -> void:
	var k := r.size.x / 110.0
	var tc: Color = AcD.TIER_COL[tier]
	var metal: Color = METAL[tier]
	if hl == 2:
		hl_frame(ci, r, hl, t)
	if n <= 0:
		frame(ci, r, Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.25), 2.0 * k, 12 * k)
		return
	frame(ci, r.grow(1.5 * k), Color(0, 0, 0, 0.45), Color(), 0.0, 13 * k)
	_grad(ci, r, tc.darkened(0.3), tc.darkened(0.65), 12 * k)
	G2.stroke(ci, frame_pts(r, "round", 12 * k), metal, 3.0 * k)
	G2.stroke(ci, frame_pts(r.grow(-9 * k), "round", 8 * k), Color(metal, 0.55), 1.5 * k)
	var c := r.get_center() - Vector2(0, 8 * k)
	ci.draw_circle(c, 30 * k, Color(metal, 0.12))
	ci.draw_arc(c, 30 * k, 0, TAU, 32, Color(metal, 0.6), 1.5 * k, true)
	for i in tier + 1:
		var y := c.y + (i - tier * 0.5) * 18 * k
		_diamond(ci, Vector2(c.x, y), 11 * k, metal.lightened(0.15))
	var plate := Rect2(r.get_center().x - 26 * k, r.end.y - 30 * k, 52 * k, 20 * k)
	frame(ci, plate, Color(0, 0, 0, 0.5), metal, 1.5 * k, 6 * k)
	G2.text_mid(ci, plate.get_center(), "%d장" % n, 16 * k, Color(1, 1, 1, 0.95), 0)


static func _diamond(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.7, 0), c + Vector2(0, r), c + Vector2(-r * 0.7, 0)])
	ci.draw_colored_polygon(pts, col)

# ==================== 영웅 ====================


## 영웅 카드 — **성물 카드와 같은 세로 비율 · 같은 크기**(사용자 요청 11-08 "영웅은 특별하게, 크기는 개발 카드와 같게").
## 성물과 갈리게 금빛 두 겹 테두리 · 네 모서리 보석 · 깊은 남보라 바탕으로 그린다.
##   위: 살아 있는 초상(`hero_portrait`) · 가운데: 이름 리본 · 아래: 조건(자원 칸 + 장수 + 내 진행 막대) 한 줄 · 왼쪽 위: 3점.
## part: 0 = 전부, 1 = 움직이지 않는 틀(테 · 조건 · 모서리 보석 — 판의 가운데 층), 2 = 살아 있는 것(초상 · 그 위의 리본 · 이름 · 점수 — 위 층).
## 1 과 2 를 겹쳐 그리면 0 과 같다(강조 테 hl 은 0 일 때만 — 판은 hl_frame 으로 아래 층에).
static func hero(ci: CanvasItem, r: Rect2, h: Dictionary, hl: int = 0, t: float = 0.0, have: Array = [], part: int = 0) -> void:
	var k := r.size.x / 110.0
	var gold := Color8(240, 200, 100)
	if part == 0:
		hl_frame(ci, r, hl, t)
	var inner := r.grow(-4 * k)
	var pic := Rect2(inner.position + Vector2(4, 4) * k, Vector2(inner.size.x - 8 * k, inner.size.y * 0.62))
	var rib := Rect2(r.position.x + 2 * k, pic.end.y - 9 * k, r.size.x - 4 * k, 20 * k)
	if part != 2:
		frame(ci, r, gold.darkened(0.25), P.INK, 2.5 * k, 12 * k)
		frame(ci, inner, Color8(40, 28, 72), gold.lightened(0.3), 1.5 * k, 9 * k)
	if part != 1:
		_hero_live(ci, pic, rib, h, t, k, gold)
	if part == 2:
		return
	# 조건 — 아래 한 줄
	var keys: Array = h.need.keys()
	keys.sort()
	var sw := 24.0 * k
	var gap := 5.0 * k
	var x0 := r.get_center().x - (keys.size() * sw + (keys.size() - 1) * gap) * 0.5
	var y0 := rib.end.y + 6 * k
	for j in keys.size():
		var c: int = keys[j]
		var sq := Rect2(x0 + j * (sw + gap), y0, sw, 20 * k)
		var need := int(h.need[c])
		cost_gem(ci, sq.get_center(), 12 * k, c, need)   # 성물 비용과 같은 보석(모양으로도 읽힘)
		# 내 진행 — 칸 밑 막대(내 성물 몇 장 / 필요 장수). 다 채우면 초록
		if have.size() > c:
			var got := mini(int(have[c]), need)
			var bar := Rect2(sq.position.x, sq.end.y + 2 * k, sq.size.x, 4 * k)
			ci.draw_rect(bar, Color(0, 0, 0, 0.5))
			if got > 0:
				ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * got / need, bar.size.y)),
						Color8(120, 230, 120) if got >= need else Color8(255, 220, 110))
	# 네 모서리 보석
	for cx in [r.position.x + 5 * k, r.end.x - 5 * k]:
		for cy in [r.position.y + 5 * k, r.end.y - 5 * k]:
			_diamond(ci, Vector2(cx, cy), 4.5 * k, gold.lightened(0.35))


## 영웅 카드의 살아 있는 부분 — 초상과 그 위에 겹치는 것(리본 · 이름 · 점수 금화).
static func _hero_live(ci: CanvasItem, pic: Rect2, rib: Rect2, h: Dictionary, t: float, k: float, gold: Color) -> void:
	hero_portrait(ci, pic, h, t)
	G2.stroke(ci, G2.round_rect(pic, 4 * k), Color(gold, 0.8), 1.5 * k)
	# 이름 리본
	frame(ci, rib, Color8(150, 40, 60), gold, 1.5 * k, 4 * k)
	G2.text_mid(ci, rib.get_center(), String(h.name), fit_size(String(h.name), rib.size.x - 8 * k, minf(20 * k, rib.size.y * 0.85)),
			Color(1, 0.96, 0.88), 3 * k)
	# 점수 — 왼쪽 위 금화
	medal(ci, pic.position + Vector2(11, 11) * k, 11 * k, 3, gold)


## 살아 있는 영웅 그림(카드 수집 게임처럼 — 사용자 요청 11-08 "캐릭터는 거의 그대로 있지만 약간의 동작").
## **AI 그림은 한 장만 뽑고 움직임은 코드가 줍니다** — 프레임을 여러 장 뽑으면 장마다 캐릭터가 달라져 떤다(젤리팝에서 겪음).
##   그림이 있으면: 가로 띠 여러 개로 잘라 그리면서 ① 숨쉬기(세로로 1% 들썩) ② 위쪽일수록 좌우로 살짝 흔들림(머리카락 · 망토)
##   ③ 몇 초마다 빛줄기가 한 번 훑고 지나감. 그림이 없으면 벡터 얼굴이 숨 쉬고 눈을 깜빡인다.
## 영웅마다 위상(`_phase`)이 달라서 판의 영웅들이 똑같이 움직이지 않는다.
static func hero_portrait(ci: CanvasItem, pic: Rect2, h: Dictionary, t: float) -> void:
	var ph := _phase(String(h.id))
	var tex := img("ac_hero_%s" % h.id)
	if tex == null:
		_hero_icon(ci, pic, h, t, ph)
	else:
		var ts := tex.get_size()
		var k := maxf(pic.size.x / ts.x, pic.size.y / ts.y)
		var src := Rect2((ts - pic.size / k) * 0.5, pic.size / k)
		var breathe := 1.0 + 0.012 * sin(t * 1.9 + ph)
		var sway := sin(t * 1.25 + ph * 1.7) * pic.size.x * 0.012
		var strips := 10
		for i in strips:
			var f0 := float(i) / strips
			var f1 := float(i + 1) / strips
			# 아래(발)는 붙어 있고 위로 갈수록 흔들림 · 들썩임이 커진다
			var up := 1.0 - f0
			var dy := -(breathe - 1.0) * pic.size.y * up
			var dx := sway * up * up
			var dst := Rect2(pic.position.x + dx, pic.position.y + pic.size.y * f0 + dy, pic.size.x, pic.size.y * (f1 - f0) + 1.0)
			var s2 := Rect2(src.position.x, src.position.y + src.size.y * f0, src.size.x, src.size.y * (f1 - f0))
			ci.draw_texture_rect_region(tex, dst, s2)
	# 빛줄기 — 4.5초마다 한 번, 왼쪽에서 오른쪽으로
	var sweep := fposmod(t + ph, 4.5) / 0.9
	if sweep < 1.0:
		var x := pic.position.x + pic.size.x * (sweep * 1.4 - 0.2)
		var w := pic.size.x * 0.16
		var x0 := clampf(x, pic.position.x, pic.end.x)
		var x1 := clampf(x + w, pic.position.x, pic.end.x)
		if x1 > x0:
			ci.draw_rect(Rect2(x0, pic.position.y, x1 - x0, pic.size.y), Color(1, 1, 1, 0.16 * sin(sweep * PI)))


static func _phase(id: String) -> float:
	return float(abs(id.hash()) % 1000) / 1000.0 * TAU


## 그림이 없을 때의 영웅 — 두건 쓴 머리 + 옷(조건 첫 자원 색) + 직업 표지. 숨쉬기 · 눈 깜빡임 · 표지가 둥실.
static func _hero_icon(ci: CanvasItem, pic: Rect2, h: Dictionary, t: float, ph: float = 0.0) -> void:
	var keys: Array = h.need.keys()
	keys.sort()
	var robe: Color = AcD.COL[keys[0]]
	var trim: Color = AcD.COL[keys[1]]
	var s := minf(pic.size.x, pic.size.y)
	var c := pic.get_center()
	frame(ci, pic, robe.darkened(0.6), Color(), 0.0, 6)
	var br := sin(t * 1.9 + ph)
	var head := c + Vector2(sin(t * 1.25 + ph * 1.7) * s * 0.012, -s * 0.14 - br * s * 0.012)
	var body := PackedVector2Array([c + Vector2(-s * 0.34, s * 0.48), c + Vector2(s * 0.34, s * 0.48),
			c + Vector2(s * 0.2, s * 0.02 - br * s * 0.01), c + Vector2(-s * 0.2, s * 0.02 - br * s * 0.01)])
	G2.fill_fan(ci, body, robe.darkened(0.1), c + Vector2(0, s * 0.3))
	G2.stroke(ci, body, P.INK, 2.0)
	ci.draw_line(c + Vector2(0, s * 0.04), c + Vector2(0, s * 0.46), trim, 3.0)
	ci.draw_circle(head, s * 0.17, Color8(240, 210, 180))
	ci.draw_arc(head, s * 0.17, 0, TAU, 20, P.INK, 2.0, true)
	# 눈 — 3~4초마다 한 번 깜빡(0.12초)
	var blink := fposmod(t + ph * 0.7, 3.6) < 0.12
	for sx in [-1.0, 1.0]:
		var e: Vector2 = head + Vector2(sx * s * 0.06, -s * 0.01)
		if blink:
			ci.draw_line(e - Vector2(s * 0.025, 0), e + Vector2(s * 0.025, 0), P.INK, maxf(1.0, s * 0.02))
		else:
			ci.draw_circle(e, s * 0.025, P.INK)
	ci.draw_arc(head + Vector2(0, -s * 0.02), s * 0.21, PI * 1.05, PI * 1.95, 14, robe.darkened(0.25), s * 0.08)
	gem(ci, c + Vector2(s * 0.34, -s * 0.02 + sin(t * 2.5 + ph) * 2.0), s * 0.12, keys[keys.size() - 1])


## 그림을 칸에 꽉 차게(넘치는 쪽을 잘라) 그린다.
static func _tex_cover(ci: CanvasItem, tex: Texture2D, r: Rect2) -> void:
	var ts := tex.get_size()
	var k := maxf(r.size.x / ts.x, r.size.y / ts.y)
	var src := Rect2((ts - r.size / k) * 0.5, r.size / k)
	ci.draw_texture_rect_region(tex, r, src)
