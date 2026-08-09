class_name P
extends RefCounted

## 색 팔레트와 폰트. 발광은 HDR(1.0 초과 색)로 내고 엔진이 번지게 한다.

const VOID0 := Color8(10, 12, 22)
const VOID1 := Color8(18, 22, 38)
const GROUND := Color8(26, 32, 52)
const GRID := Color8(38, 48, 74)

const PANEL := Color8(24, 30, 50)
const PANEL_HI := Color8(40, 50, 80)
const LINE := Color8(14, 16, 30)

const WHITE := Color8(244, 248, 255)
const DIM := Color8(146, 158, 190)
const DIMMER := Color8(88, 98, 128)

const GOLD := Color8(255, 198, 68)
const GOLD_HI := Color8(255, 232, 150)
const ORANGE := Color8(255, 146, 52)
const CRIMSON := Color8(240, 78, 84)
const CRIMSON_DEEP := Color8(150, 32, 44)
## **적이 쏜 것 전용 색.** 아군 탄(금·주황·옥색)에도 젬(초록)에도 안 쓰는 분홍이라
## "분홍은 피한다"가 한 판 안에서 굳는다. 붉은색으로 두면 붉은 티어 적·피격 알갱이·
## 데미지 숫자에 통째로 묻힌다 — 실제로 침이 안 보인다는 말이 거기서 나왔다.
const VENOM := Color8(255, 82, 196)
const JADE := Color8(74, 222, 150)
const CYAN := Color8(96, 214, 240)
const VIOLET := Color8(178, 140, 255)
const AZURE := Color8(88, 150, 255)

## 플레이어
const HERO := Color8(96, 200, 255)
const HERO_DEEP := Color8(40, 120, 190)

## 직업 색. **스킬 카드·보유 칸·선택창이 전부 이 색을 쓴다** — 색 하나로 "내 직업 것인가"가
## 읽혀야 15종을 훑는 룰렛에서 눈이 덜 피곤하다. [D].CLASS_NAME 과 같은 순서다.
const CLS_COL := [
	Color8(255, 168, 96),    # 무사   — 주황
	Color8(178, 146, 255),   # 마법사 — 보라
	Color8(120, 240, 180),   # 궁수   — 초록
]


static func cls(i: int) -> Color:
	return CLS_COL[clampi(i, 0, CLS_COL.size() - 1)]

## 경험치 젬
const XP := Color8(120, 230, 140)


## 색을 1.0 위로 올려 발광시킨다
static func hdr(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)


static func a(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, clampf(alpha, 0.0, 1.0))


static func mix(x: Color, y: Color, t: float) -> Color:
	return x.lerp(y, clampf(t, 0.0, 1.0))


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
