class_name Lay
extends RefCounted

## 화면 배치. 실제 빠칭코 기계를 본뜬 캐비닛 구조.
##
## 좌우 패널(gauge · side)의 너비는 반드시 같아야 한다 — 달라지면 릴 판이 중앙에서 밀린다.

var w := 0.0
var h := 0.0
var frame := 0.0          ## 캐비닛 테두리 두께
var marquee := Rect2()    ## 최상단 간판
var meter := Rect2()      ## 해전 4칸 램프 띠
var tile: Array[Rect2] = []
var gauge := Rect2()      ## 좌측 패널
var chara := Rect2()      ## 좌측 패널 안 캐릭터 자리
var gauge_bar := Rect2()  ## 좌측 패널 안 게이지 자리
var mid := Rect2()        ## 좌우 패널 사이 전체 영역
var board := Rect2()      ## 릴 프레임
var win := Rect2()        ## 릴이 보이는 창
var side := Rect2()       ## 우측 패널
var bar := Rect2()        ## 하단 조작대
var dial := Rect2()       ## 원형 핸들 (스핀)
var cell := Vector2()
## 조작대가 좁아지면 그 안의 요소도 같은 비율로 줄인다
var ui_k := 1.0

## 기계 바깥 윤곽 — 화면을 가로지르는 커다란 타원. 네 모서리가 잘려 둥글게 보인다.
var oval_c := Vector2()
var oval_r := Vector2()


## 세로 위치 y 에서 타원 안쪽의 반너비. 위아래로 갈수록 좁아진다.
func half_width(y: float) -> float:
	var dy := (y - oval_c.y) / oval_r.y
	if absf(dy) >= 1.0:
		return 0.0
	return oval_r.x * sqrt(1.0 - dy * dy)


## 타원 안에 들어가는 가로 폭 (여백 margin 을 뺀 값)
func _fit(y_top: float, y_bot: float, margin: float) -> float:
	return maxf(120.0, minf(half_width(y_top), half_width(y_bot)) * 2.0 - margin * 2.0)


func compute(vw: float, vh: float) -> void:
	w = vw
	h = vh
	tile.resize(4)
	frame = clampf(w * 0.011, 10.0, 18.0)
	var pad := 12.0
	var x0 := frame + pad
	var x1 := w - frame - pad
	var inner_w := x1 - x0

	oval_c = Vector2(w * 0.5, h * 0.5)
	oval_r = Vector2(w * 0.76, h * 0.52)

	var marq_h := clampf(h * 0.118, 88.0, 118.0)
	var strip_h := clampf(h * 0.052, 40.0, 52.0)
	var bar_h := clampf(h * 0.158, 116.0, 148.0)

	# 위아래 줄은 타원 안쪽에 맞춰 좁힌다 — 그래야 바깥 윤곽이 둥글게 읽힌다
	var my := frame + pad + 6.0
	var mw: float = minf(inner_w, _fit(my, my + marq_h, 34.0))
	marquee = Rect2(w * 0.5 - mw * 0.5, my, mw, marq_h)

	var sy := marquee.end.y + 8.0
	var sw: float = minf(inner_w, _fit(sy, sy + strip_h, 26.0))
	meter = Rect2(w * 0.5 - sw * 0.5, sy, sw, strip_h)
	var tw := (meter.size.x - 30.0) / 4.0
	for i in 4:
		tile[i] = Rect2(meter.position.x + i * (tw + 10.0), meter.position.y, tw, strip_h)

	var by := h - frame - pad - bar_h - 6.0
	var bw: float = minf(inner_w, _fit(by, by + bar_h, 30.0))
	bar = Rect2(w * 0.5 - bw * 0.5, by, bw, bar_h)

	var mid_y := meter.end.y + pad
	var mid_h := bar.position.y - pad - mid_y
	var side_w := clampf(w * 0.126, 150.0, 206.0)
	# 가운데 줄은 타원이 가장 넓은 곳이라 화면 폭을 그대로 쓴다
	var mid_x0: float = maxf(x0, w * 0.5 - half_width(mid_y + mid_h * 0.5) + 26.0)
	var mid_x1: float = minf(x1, w * 0.5 + half_width(mid_y + mid_h * 0.5) - 26.0)

	gauge = Rect2(mid_x0, mid_y, side_w, mid_h)
	side = Rect2(mid_x1 - side_w, mid_y, side_w, mid_h)

	var ci := 9.0
	chara = Rect2(gauge.position.x + ci, gauge.position.y + ci, side_w - ci * 2, mid_h * 0.46)
	gauge_bar = Rect2(gauge.position.x + ci, chara.end.y + 8.0,
			side_w - ci * 2, gauge.end.y - ci - (chara.end.y + 8.0))

	var inset := 18.0
	var mx := gauge.end.x + pad
	var mid_w := side.position.x - pad - mx
	mid = Rect2(mx, mid_y, mid_w, mid_h)

	var avail_h := mid_h - inset * 2 - 24.0
	var ch := avail_h / D.ROWS
	var cw: float = minf((mid_w - inset * 2) / D.REELS, ch * 1.10)
	cell = Vector2(cw, ch)
	var use := Vector2(cw * D.REELS, ch * D.ROWS)

	var board_w := use.x + inset * 2
	board = Rect2(w * 0.5 - board_w * 0.5, mid_y, board_w, mid_h)
	win = Rect2(w * 0.5 - use.x * 0.5,
			board.position.y + inset + (mid_h - inset * 2 - use.y) * 0.5 - 6.0,
			use.x, use.y)

	ui_k = clampf(bar.size.x / 1360.0, 0.60, 1.0)
	var dd: float = minf(bar_h - 18.0, 124.0 * ui_k)
	dial = Rect2(bar.end.x - 16.0 - dd, bar.position.y + (bar_h - dd) * 0.5, dd, dd)


func cell_center(reel: int, row: int) -> Vector2:
	return win.position + Vector2((reel + 0.5) * cell.x, (row + 0.5) * cell.y)


func cell_rect(reel: int, row: int) -> Rect2:
	return Rect2(win.position + Vector2(reel * cell.x, row * cell.y), cell)


## 사각형 둘레를 0..1 로 훑어 점 위치를 얻는다 (LED 러너용)
static func perimeter_at(r: Rect2, u: float) -> Vector2:
	u = fposmod(u, 1.0)
	var pw := r.size.x
	var ph := r.size.y
	var d := u * (pw + ph) * 2.0
	if d < pw:
		return Vector2(r.position.x + d, r.position.y)
	d -= pw
	if d < ph:
		return Vector2(r.end.x, r.position.y + d)
	d -= ph
	if d < pw:
		return Vector2(r.end.x - d, r.end.y)
	d -= pw
	return Vector2(r.position.x, r.end.y - d)
