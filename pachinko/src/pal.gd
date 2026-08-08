class_name P
extends RefCounted

## 색 팔레트와 폰트.
##
## 1.0 을 넘는 색 성분은 블룸으로 번진다 (project.godot 의 viewport/hdr_2d).
## 발광시키고 싶으면 hdr() 로 밝기를 올려라 — GDI+ 판처럼 반투명 원을 겹치지 말 것.

const VOID0 := Color(0.024, 0.035, 0.094)
const VOID1 := Color(0.051, 0.078, 0.188)
const SEA0 := Color(0.039, 0.102, 0.227)
const SEA1 := Color(0.086, 0.204, 0.408)
const SEA2 := Color(0.149, 0.361, 0.612)
const PANEL := Color(0.071, 0.102, 0.220)
const PANEL_HI := Color(0.125, 0.180, 0.345)
const FRAME := Color(0.227, 0.180, 0.094)

const GOLD := Color(1.000, 0.804, 0.290)
const GOLD_HI := Color(1.000, 0.941, 0.667)
const GOLD_DEEP := Color(0.698, 0.463, 0.047)
const CRIMSON := Color(0.886, 0.212, 0.243)
const CRIMSON_DEEP := Color(0.494, 0.078, 0.118)
const JADE := Color(0.204, 0.839, 0.675)
const CYAN := Color(0.376, 0.839, 1.000)
const VIOLET := Color(0.659, 0.463, 1.000)
const ORANGE := Color(1.000, 0.557, 0.188)

const WHITE := Color(0.980, 0.980, 1.000)
const INK := Color(0.055, 0.063, 0.118)
const DIM := Color(0.541, 0.596, 0.745)
const DIMMER := Color(0.329, 0.376, 0.518)

## 외곽선 — 검정 대신 짙은 남보라라야 덜 딱딱하다
const LINE := Color(0.125, 0.094, 0.180)

## 해전 4개 색
const TIER := [
	Color(0.376, 0.784, 1.000),
	Color(0.290, 0.886, 0.627),
	Color(1.000, 0.690, 0.220),
	Color(1.000, 0.290, 0.361),
]


## 블룸이 걸리도록 밝기를 올린다. m 이 1 보다 크면 번진다.
static func hdr(c: Color, m: float) -> Color:
	return Color(c.r * m, c.g * m, c.b * m, c.a)


## 알파만 바꾼 색
static func a(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, alpha)


static func mix(x: Color, y: Color, t: float) -> Color:
	return x.lerp(y, clampf(t, 0.0, 1.0))


static func lighten(c: Color, t: float) -> Color:
	return mix(c, Color(1, 1, 1, c.a), t)


static func darken(c: Color, t: float) -> Color:
	return mix(c, Color(0, 0, 0, c.a), t)


static func hsv(h: float, s: float, v: float) -> Color:
	return Color.from_hsv(fposmod(h, 360.0) / 360.0, s, v)

# ==================== 폰트 ====================

static var _fonts := {}


## 맑은 고딕(윈도우 기본 탑재)을 쓰고, 없으면 엔진 기본 폰트로 떨어진다.
static func font(bold: bool = true) -> Font:
	var key := "b" if bold else "r"
	if _fonts.has(key):
		return _fonts[key]
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Noto Sans KR", "Segoe UI"])
	f.font_weight = 700 if bold else 400
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	_fonts[key] = f
	return f


## 1,234,567 형태
static func n(v: float) -> String:
	var s := str(int(round(abs(v))))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if v < 0 else "") + out
