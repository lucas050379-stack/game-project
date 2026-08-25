class_name P
extends RefCounted

## 색 팔레트와 폰트.
##
## 발광은 HDR(1.0 을 넘는 색)로 내고 엔진 블룸에 맡긴다. 반투명 원을 여러 겹 겹쳐
## 만들지 않는다 — 층 경계가 띠로 보이고, 폰에서는 그 겹치기 비용이 그대로 프레임이다.

# ---------- 바탕 ----------
## 구간 세 종의 하늘. [위, 아래]
const SKY := [
	[Color8(38, 74, 128), Color8(96, 146, 186)],    ## 초원 — 한낮
	[Color8(96, 52, 44), Color8(184, 104, 58)],     ## 협곡 — 노을
	[Color8(10, 12, 34), Color8(34, 26, 62)],       ## 밤하늘 — 폭풍
]
const GROUND := [
	Color8(46, 84, 52),
	Color8(96, 58, 40),
	Color8(20, 22, 44),
]
const GROUND_D := [
	Color8(34, 62, 40),
	Color8(72, 42, 30),
	Color8(14, 15, 32),
]

const LINE := Color8(10, 12, 20)            ## 모든 외곽선
const SHADE := Color(0.02, 0.03, 0.06, 0.32)

const WHITE := Color8(246, 250, 255)
const DIM := Color8(158, 170, 196)
const DIMMER := Color8(96, 106, 134)
const PANEL := Color(0.04, 0.05, 0.09, 0.82)

# ---------- 드래곤 ----------
## 세 마리가 색으로 갈린다. [바탕, 그늘, 뿔·등지느러미, 브레스]
const DRAGON_COL := [
	[Color8(196, 62, 48), Color8(138, 38, 30), Color8(244, 176, 92), Color8(255, 146, 52)],
	[Color8(118, 92, 196), Color8(78, 58, 138), Color8(196, 184, 255), Color8(150, 198, 255)],
	[Color8(58, 166, 180), Color8(36, 114, 126), Color8(202, 242, 250), Color8(140, 236, 255)],
]
const BELLY := Color8(232, 214, 186)
const EYE := Color8(255, 244, 214)

# ---------- 적 ----------
## 드래곤을 알록달록하게 칠할 수 있는 건 적이 칙칙하기 때문이다.
## 둘 다 화려하면 화면에서 누가 내 편인지 사라진다.
const FOE := Color8(122, 128, 108)
const FOE_D := Color8(84, 90, 76)
const FOE_HORN := Color8(178, 172, 150)
const STONE := Color8(112, 116, 126)
const STONE_D := Color8(76, 80, 90)
const FOE_MARK := Color8(206, 76, 62)

# ---------- 탄 · 아이템 ----------
## **적이 쏜 것 전용 색.** 브레스(기체색)에도 금화(금색)에도 안 쓰는 분홍이라
## "분홍은 피한다"가 한 판 안에서 굳는다. 붉은색으로 두면 붉은 적과 폭발에 묻힌다.
const VENOM := Color8(255, 92, 168)
const VENOM_HI := Color8(255, 202, 228)
const GOLD := Color8(255, 206, 96)
const GOLD_D := Color8(196, 140, 40)
const POWER := Color8(108, 232, 176)
const SHIELD := Color8(126, 202, 255)
const FLAME := Color8(255, 150, 60)
const SMOKE := Color8(126, 122, 118)


static func hdr(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)


static func a(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, clampf(alpha, 0.0, 1.0))


static func dragon(i: int, slot: int) -> Color:
	return DRAGON_COL[clampi(i, 0, DRAGON_COL.size() - 1)][slot]


static var _font: SystemFont
static var _font_b: SystemFont


## **폰에는 맑은 고딕이 없다.** 안드로이드는 Noto 계열이라 이름을 같이 적어 두고,
## 그래도 못 찾으면 시스템 대체 글꼴이 한글을 메우게 둔다(`allow_system_fallback`).
static func _make(bold: bool) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"Malgun Gothic", "Noto Sans CJK KR", "Noto Sans KR", "Roboto", "sans-serif"])
	f.allow_system_fallback = true
	if bold:
		f.font_weight = 700
	return f


static func font(bold: bool = true) -> SystemFont:
	if bold:
		if _font_b == null:
			_font_b = _make(true)
		return _font_b
	if _font == null:
		_font = _make(false)
	return _font


## 1234567 -> "1,234,567"
static func n(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if v < 0 else "") + out
