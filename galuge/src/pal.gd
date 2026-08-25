class_name P
extends RefCounted

## 색 팔레트와 폰트.
##
## 발광은 HDR(1.0 초과 색)로 내고 엔진 블룸에 맡긴다. 반투명 원을 겹쳐 만들지 않는다.

# ---------- 바탕 ----------
const VOID := Color8(6, 9, 15)          ## 플레이필드 밖 (좌우 패널)
const SEA_TOP := Color8(12, 26, 44)
const SEA_BOT := Color8(6, 14, 24)
const FOAM := Color8(122, 178, 220)
const ISLE := Color8(56, 71, 47)
const LINE := Color8(8, 13, 20)         ## 모든 외곽선
const SHADE := Color(0.024, 0.04, 0.07, 0.30)  ## 셀 셰이딩 그늘

const WHITE := Color8(244, 248, 255)
const DIM := Color8(146, 158, 190)
const DIMMER := Color8(88, 98, 128)

# ---------- 아군기 ----------
## 여섯 대가 색으로 갈린다. [바탕, 그늘, 등마루, 무늬·탄]
const CRAFT_COL := [
	[Color8(46, 147, 172), Color8(31, 107, 126), Color8(99, 199, 220), Color8(127, 228, 245)],
	[Color8(198, 140, 44), Color8(143, 99, 27), Color8(237, 192, 97), Color8(242, 194, 99)],
	[Color8(122, 95, 182), Color8(84, 64, 138), Color8(169, 145, 224), Color8(198, 172, 247)],
	[Color8(49, 161, 117), Color8(31, 116, 84), Color8(104, 210, 166), Color8(107, 234, 198)],
	[Color8(175, 189, 204), Color8(126, 143, 161), Color8(228, 237, 245), Color8(127, 168, 232)],
	[Color8(78, 126, 196), Color8(52, 85, 143), Color8(121, 169, 230), Color8(180, 255, 106)],
]
const GLASS := Color8(39, 56, 74)
const GLASS_HI := Color(0.77, 0.89, 0.97, 0.55)
const PROP := Color8(167, 186, 203)
const PROP_TIP := Color8(207, 227, 242)

# ---------- 적 ----------
## 아군을 알록달록하게 칠할 수 있는 건 적이 칙칙하기 때문이다.
## 둘 다 화려하면 화면에서 누가 내 편인지 사라진다.
const OLIVE := Color8(126, 140, 90)
const OLIVE_D := Color8(90, 102, 64)
const RUST := Color8(154, 113, 70)
const RUST_D := Color8(109, 79, 48)
const IRON := Color8(110, 122, 136)
const IRON_D := Color8(76, 86, 99)
const NAVY := Color8(89, 99, 111)
const NAVY_D := Color8(62, 71, 83)
const DECK := Color8(76, 86, 97)
const HULL_R := Color8(122, 58, 50)
const FOE_MARK := Color8(192, 69, 58)

# ---------- 탄 · 이펙트 ----------
## **적이 쏜 것 전용 색.** 아군 탄(기체색)에도 폭발(주황)에도 안 쓰는 분홍이라
## "분홍은 피한다"가 한 판 안에서 굳는다. 붉은색으로 두면 붉은 적·피격 알갱이에 묻힌다.
const VENOM := Color8(255, 95, 168)
const VENOM_HI := Color8(255, 201, 228)
const HOT := Color8(255, 180, 77)
const GOLD := Color8(255, 210, 122)
const FLAME_O := Color8(255, 138, 46)
const FLAME_G := Color8(79, 224, 52)
const POWER := Color8(111, 227, 176)


static func hdr(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)


static func a(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, clampf(alpha, 0.0, 1.0))


static func craft(i: int, slot: int) -> Color:
	return CRAFT_COL[clampi(i, 0, CRAFT_COL.size() - 1)][slot]


static var _font: SystemFont
static var _font_b: SystemFont


static func font(bold: bool = true) -> SystemFont:
	if bold:
		if _font_b == null:
			_font_b = SystemFont.new()
			_font_b.font_names = PackedStringArray(["Malgun Gothic", "Segoe UI", "sans-serif"])
			_font_b.font_weight = 700
		return _font_b
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Malgun Gothic", "Segoe UI", "sans-serif"])
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
