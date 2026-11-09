class_name P
extends RefCounted

## 색과 글꼴.

const BG_TOP := Color8(255, 196, 222)
const BG_BOT := Color8(146, 168, 255)
const BOARD := Color8(60, 36, 110, 150)   ## 판 바탕 — 열린 칸 밑에 깔아 젤리가 허공이 아니라 판 위에 놓여 보이게(사용자 결정 11-04)
const BOARD_EDGE := Color8(255, 255, 255, 150)
const CELL_A := Color8(255, 255, 255, 46)
const CELL_B := Color8(255, 255, 255, 20)
const LINE := Color8(70, 40, 90)          ## 외곽선 — 검정 대신 짙은 보라
const INK := Color8(70, 40, 90)
const WHITE := Color(1, 1, 1)
const SCORE := Color8(255, 255, 255)
const WARN := Color8(255, 70, 90)
const FEVER := Color8(255, 120, 200)
const GOLD := Color8(255, 214, 90)
const RAINBOW := [
	Color8(255, 92, 110), Color8(255, 160, 60), Color8(255, 216, 64),
	Color8(110, 214, 92), Color8(80, 170, 255), Color8(186, 110, 255),
]


static func a(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, clampf(alpha, 0.0, 1.0))


static func jelly(c: int) -> Color:
	return D.JELLY[c] if c >= 0 and c < D.JELLY.size() else WHITE


## **브라우저에는 한글 시스템 글꼴이 없다.** SystemFont 는 웹에서 기본 글꼴로 떨어지고
## 그 글꼴에는 한글이 없어 네모만 찍힌다. 그래서 글꼴 파일을 같이 싣는다(Jua, OFL).
##
## **Jua 에는 `·` `×` 같은 기호가 없다.** 데스크톱에서는 시스템 글꼴이 메워 줘서 멀쩡해
## 보이고 브라우저에서만 네모가 나온다. 화면 글자에는 한글 · 영숫자 · 기본 문장부호만 쓴다.
static func font() -> Font:
	return UiKit.font()   # 앱 전체에 한 벌 — 허브가 갖고 있다(docs/adr/0007)


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
