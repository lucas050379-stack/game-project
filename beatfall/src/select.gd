class_name Sel
extends RefCounted

## 곡 선택 · 캘리브레이션.
##
## **자리 함수를 하나 두고 그리기와 클릭 판정이 같이 본다**([method song_rect] ·
## [method diff_rect]). 두 곳에서 따로 계산하면 한쪽만 고쳤을 때 조용히 어긋난다.

const ROW_H := 46.0
const LIST_TOP := 118.0
const DIFF_W := 300.0

var songs: Array = []
var si := 0
var di := 0
var cal := false          ## 캘리브레이션 화면인가


func _init() -> void:
	songs = Song.scan()


func song() -> Song:
	return songs[clampi(si, 0, songs.size() - 1)]


func diff() -> Dictionary:
	var c := song().chart
	return c.diffs[clampi(di, 0, c.diffs.size() - 1)]


func list_rect(vs: Vector2) -> Rect2:
	return Rect2(40.0, LIST_TOP, vs.x - DIFF_W - 100.0, vs.y - LIST_TOP - 70.0)


func song_rect(vs: Vector2, i: int) -> Rect2:
	var lr := list_rect(vs)
	return Rect2(lr.position.x, lr.position.y + (i - _scroll(vs)) * ROW_H, lr.size.x, ROW_H - 5.0)


func diff_rect(vs: Vector2, i: int) -> Rect2:
	var x := vs.x - DIFF_W - 40.0
	return Rect2(x, LIST_TOP + i * 44.0, DIFF_W, 39.0)


# ==================== 아래쪽 토글 ====================
##
## **키만 넣으면 "마우스로 못 켠다"를 눈치채기 어렵다.** 자동 연주(F2)가 실제로
## 그렇게 아무도 모르는 기능이 되어 있었다. 그래서 자리 함수를 하나 두고
## [method draw] 와 [method click] 이 **같은 값을 본다** — 두 곳에서 따로 계산하면
## 한쪽만 고쳤을 때 "보이는데 안 눌리는" 버튼이 조용히 생긴다.

## {키, 이름}. 순서가 곧 화면 순서다.
const TOGGLES := [
	{"key": KEY_C, "name": "판정 보정"},
	{"key": KEY_K, "name": "키음"},
	{"key": KEY_H, "name": "타격음"},
	{"key": KEY_F2, "name": "자동 연주"},
]

const TOG_H := 26.0
const TOG_GAP := 8.0


func toggle_rect(vs: Vector2, i: int) -> Rect2:
	var x := 40.0
	for j in i:
		x += G2.text_w(_toggle_label(j), 13) + 18.0 + TOG_GAP
	return Rect2(x, vs.y - TOG_H - 12.0,
		G2.text_w(_toggle_label(i), 13) + 18.0, TOG_H)


func _toggle_label(i: int) -> String:
	match i:
		0: return "C  판정 보정 %+dms" % int(round(Sv.offset * 1000.0))
		1: return "K  키음 %s" % ("켬" if not Sv.no_keysound else "끔")
		2: return "H  타격음 %s" % ("켬" if Sv.vol_hit > 0.001 else "끔")
	return "F2  자동 연주 %s" % ("켬" if Sv.autoplay else "끔")


## 켜져 있는가(칸을 밝게 그릴지). 판정 보정은 켜고 끄는 것이 아니라 늘 밝다.
func _toggle_on(i: int) -> bool:
	match i:
		0: return true
		1: return not Sv.no_keysound
		2: return Sv.vol_hit > 0.001
	return Sv.autoplay


## 고른 곡이 목록 밖으로 나가지 않게 스크롤한다.
func _scroll(vs: Vector2) -> int:
	var rows := maxi(1, int(list_rect(vs).size.y / ROW_H))
	return clampi(si - rows / 2, 0, maxi(0, songs.size() - rows))


func _clamp() -> void:
	si = clampi(si, 0, maxi(0, songs.size() - 1))
	di = clampi(di, 0, maxi(0, song().chart.diffs.size() - 1))


# ==================== 입력 ====================

## 눌린 키를 처리한다. 곡을 시작해야 하면 true.
func key(k: int) -> bool:
	if cal:
		_cal_key(k)
		return false
	match k:
		KEY_UP, KEY_W:
			si -= 1
			di = 0
			_clamp()
			Snd.ui()
		KEY_DOWN, KEY_S:
			si += 1
			di = 0
			_clamp()
			Snd.ui()
		KEY_LEFT, KEY_A:
			di -= 1
			_clamp()
			Snd.ui()
		KEY_RIGHT, KEY_Z:
			di += 1
			_clamp()
			Snd.ui()
		KEY_BRACKETLEFT:
			Sv.speed = clampf(Sv.speed - D.SPEED_STEP, D.SPEED_MIN, D.SPEED_MAX)
			Sv.save_cfg()
		KEY_BRACKETRIGHT:
			Sv.speed = clampf(Sv.speed + D.SPEED_STEP, D.SPEED_MIN, D.SPEED_MAX)
			Sv.save_cfg()
		KEY_C:
			cal_open()
		KEY_K:
			# 키음 끄기 — 예전처럼 곡 전체를 통으로 재생한다.
			Sv.no_keysound = not Sv.no_keysound
			Sv.save_cfg()
			Snd.ui()
		KEY_H:
			# 타격음. 기본은 꺼져 있다 — 원곡을 방해하지 않으려는 것이고, 틀렸을 때
			# 음악이 무너지는 것과의 대비도 타격음이 없어야 산다([Warp] 참고).
			Sv.vol_hit = 0.0 if Sv.vol_hit > 0.001 else 0.6
			Sv.save_cfg()
			Snd.ui()
		KEY_F2:
			Sv.autoplay = not Sv.autoplay
			Snd.ui()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			return true
	return false


## 마우스 클릭. 화면 좌표를 받는다.
func click(vs: Vector2, at: Vector2) -> bool:
	if cal:
		_cal_tap()
		return false
	# 토글이 먼저다 — 곡 목록보다 위에 그려져 있으므로 판정도 먼저 해야 한다.
	for i in TOGGLES.size():
		if toggle_rect(vs, i).has_point(at):
			key(int(TOGGLES[i].key))     # 키와 같은 길을 지나야 동작이 안 갈린다
			return false
	for i in songs.size():
		var r := song_rect(vs, i)
		if r.position.y < LIST_TOP - ROW_H or not r.has_point(at):
			continue
		if si == i:
			return true            # 이미 고른 곡을 다시 누르면 시작
		si = i
		di = 0
		_clamp()
		Snd.ui()
		return false
	for i in song().chart.diffs.size():
		if diff_rect(vs, i).has_point(at):
			if di == i:
				return true
			di = i
			Snd.ui()
			return false
	return false


# ==================== 캘리브레이션 ====================
##
## 화면과 소리가 어긋나는 양을 사람이 직접 잰다. `AudioServer.get_output_latency()`
## 로 걷어내지 못하는 몫(블루투스 이어폰·모니터 지연)이 남기 때문에 필요하다.
##
## 메트로놈을 일정 박으로 울리고 그 박에 맞춰 스페이스를 누르게 한다. 누른 시각과
## 가장 가까운 박의 차이를 모아 **중앙값**을 쓴다 — 평균은 실수로 한 번 크게 어긋난
## 입력 하나에 통째로 끌려간다.

const CAL_BPM := 120.0
const CAL_NEED := 12       ## 이만큼 모으면 확정

var cal_hits: Array = []
var _cal_start := 0
var _cal_last_beat := -1


func cal_open() -> void:
	cal = true
	cal_hits.clear()
	_cal_start = Time.get_ticks_usec()
	_cal_last_beat = -1


func cal_close(apply: bool) -> void:
	if apply and cal_hits.size() >= 3:
		var v := cal_hits.duplicate()
		v.sort()
		Sv.offset = v[v.size() / 2]
		Sv.save_cfg()
	cal = false


func cal_now() -> float:
	return float(Time.get_ticks_usec() - _cal_start) / 1000000.0


## 매 프레임. 박이 넘어갈 때마다 소리를 낸다.
func cal_step() -> void:
	if not cal:
		return
	var b := 60.0 / CAL_BPM
	var i := int(floorf(cal_now() / b))
	if i != _cal_last_beat:
		_cal_last_beat = i
		Snd.click(i % 4 == 0)


func _cal_key(k: int) -> void:
	match k:
		KEY_SPACE:
			_cal_tap()
		KEY_ESCAPE:
			cal_close(false)
		KEY_ENTER, KEY_KP_ENTER:
			cal_close(true)
		KEY_R:
			cal_hits.clear()
		KEY_MINUS:
			Sv.offset -= 0.005
			Sv.save_cfg()
		KEY_EQUAL:
			Sv.offset += 0.005
			Sv.save_cfg()


func _cal_tap() -> void:
	var b := 60.0 / CAL_BPM
	# 소리가 난 시각은 지금 - 출력 지연. 그 기준에서 얼마나 벗어났는지를 잰다.
	var t := cal_now() - AudioServer.get_output_latency()
	var err: float = t - round(t / b) * b
	cal_hits.append(err)
	if cal_hits.size() > CAL_NEED * 2:
		cal_hits.pop_front()


# ==================== 그리기 ====================

func draw(ci: CanvasItem, vs: Vector2) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, vs), P.VOID)
	if cal:
		_draw_cal(ci, vs)
		return
	G2.text(ci, Vector2(40.0, 56.0), "비트폴", 30, P.hdr(P.WHITE, 1.1))
	G2.text(ci, Vector2(40.0, 82.0), "다 맞히면 원곡 그대로 · 틀리면 음이 나갑니다", 13, P.DIM)
	var lr := list_rect(vs)
	for i in songs.size():
		var r := song_rect(vs, i)
		if r.end.y < lr.position.y or r.position.y > lr.end.y:
			continue
		var on := i == si
		ci.draw_rect(r, P.PANEL_EDGE if on else P.PANEL)
		if on:
			ci.draw_rect(Rect2(r.position, Vector2(4.0, r.size.y)), P.hdr(P.NOTE_A, 1.2))
		var s: Song = songs[i]
		G2.text(ci, r.position + Vector2(16.0, 20.0), s.title(), 16,
			P.WHITE if on else P.DIM)
		G2.text(ci, r.position + Vector2(16.0, 36.0), s.artist(), 11, P.DIMMER)
	_draw_diffs(ci, vs)
	# **안내는 두 줄로 나눈다.** 한 줄에 몰면 창이 좁을 때 뒤가 잘려 나가는데,
	# 잘리는 쪽이 늘 뒤에 붙인 최신 기능이라 **새로 넣은 것부터 안 보이게 된다.**
	# 자동 연주(F2)가 실제로 그렇게 아무도 모르는 기능이 되어 있었다.
	G2.text(ci, Vector2(40.0, vs.y - 56.0),
		"↑↓ 곡   ←→ 난이도   Enter 시작   [ ] 배속 %.1f" % Sv.speed, 13, P.DIMMER)
	for i in TOGGLES.size():
		var r := toggle_rect(vs, i)
		var on := _toggle_on(i)
		ci.draw_rect(r, P.PANEL_EDGE if on else P.PANEL)
		G2.text(ci, r.position + Vector2(9.0, 17.0), _toggle_label(i), 13,
			P.hdr(P.WHITE, 1.05) if on else P.DIMMER)
	# 자동 연주 중에는 점수가 기록되지 않는다. 켜 둔 걸 잊고 좋은 판을 날리지 않게
	# 목록 옆이 아니라 **눈에 띄는 자리**에 크게 알린다.
	if Sv.autoplay:
		var s := "자동 연주 — 기록 안 됨"
		G2.text(ci, Vector2(vs.x - G2.text_w(s, 15) - 40.0, 62.0), s, 15,
			P.hdr(P.J_PERFECT, 1.1))


func _draw_diffs(ci: CanvasItem, vs: Vector2) -> void:
	var c := song().chart
	G2.text(ci, Vector2(vs.x - DIFF_W - 40.0, 100.0), "난이도", 13, P.DIM)
	for i in c.diffs.size():
		var d: Dictionary = c.diffs[i]
		var r := diff_rect(vs, i)
		var on := i == di
		ci.draw_rect(r, P.PANEL_EDGE if on else P.PANEL)
		G2.text(ci, r.position + Vector2(14.0, 25.0), "%s  %dK" % [d.name, d.keys], 15,
			P.WHITE if on else P.DIM)
		G2.text(ci, r.position + Vector2(r.size.x - 96.0, 25.0),
			"Lv.%d  %d notes" % [d.level, d.notes.size()], 11, P.DIMMER)
	var b := Sv.best(song().id, diff().name)
	var y := LIST_TOP + c.diffs.size() * 44.0 + 26.0
	if b.is_empty():
		G2.text(ci, Vector2(vs.x - DIFF_W - 40.0, y), "기록 없음", 12, P.DIMMER)
	else:
		G2.text(ci, Vector2(vs.x - DIFF_W - 40.0, y),
			"최고  %07d  %s  %.2f%%" % [int(b.get("score", 0)), str(b.get("rank", "")),
			float(b.get("acc", 0.0)) * 100.0], 12, P.DIM)


func _draw_cal(ci: CanvasItem, vs: Vector2) -> void:
	var cx := vs.x * 0.5
	G2.text_c(ci, Vector2(cx, 90.0), "판정 보정", 28, P.WHITE)
	G2.text_c(ci, Vector2(cx, 122.0), "소리가 나는 순간에 맞춰 스페이스를 누르세요", 14, P.DIM)
	# 박에 맞춰 커지는 원. 눈으로도 박을 잡을 수 있어야 소리와의 차이를 느낀다.
	var b := 60.0 / CAL_BPM
	var ph: float = fmod(cal_now(), b) / b
	var rad := 26.0 + 34.0 * (1.0 - ph) * (1.0 - ph)
	G2.glow(ci, Vector2(cx, 250.0), rad * 2.4, P.a(P.NOTE_A, 0.5))
	ci.draw_circle(Vector2(cx, 250.0), rad, P.hdr(P.NOTE_A, 1.1))
	var n := cal_hits.size()
	G2.text_c(ci, Vector2(cx, 336.0), "%d / %d" % [mini(n, CAL_NEED), CAL_NEED], 18, P.DIM)
	if n >= 3:
		var v := cal_hits.duplicate()
		v.sort()
		var med: float = v[v.size() / 2]
		G2.text_c(ci, Vector2(cx, 372.0), "측정값  %+d ms" % int(round(med * 1000.0)), 22,
			P.hdr(P.J_PERFECT, 1.1))
	G2.text_c(ci, Vector2(cx, 424.0), "현재 적용값  %+d ms" % int(round(Sv.offset * 1000.0)),
		15, P.WHITE)
	G2.text_c(ci, Vector2(cx, vs.y - 60.0),
		"Enter 적용   ·   R 다시   ·   - / = 직접 조정   ·   Esc 취소", 13, P.DIMMER)
