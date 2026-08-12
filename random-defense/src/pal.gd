class_name P
extends RefCounted

## 색 팔레트와 폰트.
##
## **3D 는 조명이 명암을 낸다.** 여기 값은 "정면에서 빛을 받았을 때의 색" 하나만 잡고,
## 어두운 쪽은 `DirectionalLight3D` 와 환경광에 맡긴다.
##
## 발광은 `WorldEnvironment` 의 glow 가 **1.0 을 넘는 색에서만** 낸다. 탄과 표시등에만
## [method hdr] 를 쓰고, 몸통에 쓰면 화면이 통째로 뿌예진다.

# ── 바닥 ──────────────────────────────────────────────────────
const VOID := Color8(12, 15, 28)
const GROUND := Color8(74, 88, 126)
const GROUND2 := Color8(60, 72, 106)
## 몬스터가 도는 고리 트랙
const TRACK := Color8(56, 42, 58)
const TRACK_EDGE := Color8(150, 116, 154)
## 스토리 라인은 본진과 **색조가 달라야** 한 눈에 다른 판임이 읽힌다
const STORY := Color8(58, 86, 82)
const STORY2 := Color8(46, 72, 70)
const STORY_EDGE := Color8(110, 200, 180)

# ── UI ────────────────────────────────────────────────────────
const PANEL := Color8(18, 23, 40)
const PANEL_HI := Color8(34, 43, 70)
const LINE := Color8(10, 12, 22)
const WHITE := Color8(244, 248, 255)
const DIM := Color8(148, 160, 192)
const DIMMER := Color8(88, 98, 128)
const GOLD := Color8(255, 198, 68)
const CRIMSON := Color8(240, 78, 84)
const JADE := Color8(74, 222, 150)
const WISP := Color8(150, 226, 255)
const LUMBER := Color8(196, 148, 92)

# ── 역할 3종 ──────────────────────────────────────────────────
## [U].ROLE 과 같은 순서 — 물뎀 · 마뎀 · 스토리.
## **탄 색이 곧 역할**이라서, 어느 유닛이 쏘고 있는지가 화면에서 읽힌다.
const ROLE_COL := [
	Color8(255, 146, 62),    # 물뎀 — 주황
	Color8(206, 130, 255),   # 마뎀 — 보라
	Color8(120, 232, 190),   # 스토리 — 옥색
]

# ── 몬스터 4종 ────────────────────────────────────────────────
## 어둡게 잡지 마라. 판이 짙어서 어두운 색은 바닥에 묻힌다.
const MOB_COL := [
	Color8(214, 132, 146),
	Color8(246, 152, 100),
	Color8(158, 176, 214),
	Color8(196, 150, 232),
]

# ── 등급 20단계 ───────────────────────────────────────────────
## 유닛의 색은 **등급**이 낸다. 회색 → 흰색 → 금색 → 자주색으로 올라간다.
## 20단계를 손으로 다 적으면 한 칸만 어긋나도 안 보이므로 세 구간을 이어 만든다.
const G_LOW := Color8(132, 144, 168)
const G_MID := Color8(238, 244, 255)
const G_HIGH := Color8(255, 196, 84)
const G_TOP := Color8(226, 122, 255)


static func grade(i: int) -> Color:
	var n := maxi(U.GRADE.size() - 1, 1)
	var t := clampf(float(i) / float(n), 0.0, 1.0)
	if t < 0.34:
		return G_LOW.lerp(G_MID, t / 0.34)
	if t < 0.68:
		return G_MID.lerp(G_HIGH, (t - 0.34) / 0.34)
	return G_HIGH.lerp(G_TOP, (t - 0.68) / 0.32)


static func role(i: int) -> Color:
	return ROLE_COL[clampi(i, 0, ROLE_COL.size() - 1)]


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
