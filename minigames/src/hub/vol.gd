class_name Vol
extends RefCounted

## 음량 창 — **전체 · 효과음 · 배경음** 세 막대. 허브와 젤리팝 처음 화면이 같은 창을 띄운다.
##
## 값은 `Sv.vol_master` · `Sv.vol_sfx` · `Sv.vol_music`(0~1)에 저장한다. 예전의 켬/끔 깃발
## (`Sv.music` · `Sv.sfx`)은 남겨 두되 **막대 값에서 따라온다**(0 이면 끔) — 효과음 · 배경음 코드가
## 그 깃발로 소리를 건너뛰므로, 깃발과 막대가 따로 놀면 "막대는 올렸는데 소리가 안 난다"가 된다.
##
## 전체는 Master 버스 볼륨이다. 효과음 · 배경음은 각자의 플레이어 볼륨에 곱한다.
## **테스트할 때는 전체를 꺼서 돌린다**([member test_mute]) — 저장된 값은 그대로 둔다.
##
## 막대는 눌러서 그 자리로, 끌어서 조절, `-` `+` 는 10%씩. 손가락이 굵은 폰 기준으로 칸을 크게 잡았다.
## 자리 함수(`*_rect`)를 그리기와 누르기가 같이 본다.

const STEP := 0.1
const NAMES := ["전체", "효과음", "배경음"]

static var open := false
static var test_mute := false
static var _drag := -1          ## 끌고 있는 막대(-1 = 없음)

## 이 창은 **설정**이다(사용자 요청 11-12 — 키 설정을 하려고 처음 화면까지 나가야 했다). 오른쪽 위 톱니 단추가 열고,
## 판 중에도 열린다. 키를 바꿀 수 있는 게임은 `_ready` 에서 `Vol.key_sets = [["키 설정", "tiger", KEYS]]` 처럼 걸어 두면
## 아래 줄에 단추가 생긴다(물거품은 1P · 2P 둘). 허브가 게임을 닫을 때 비운다.
static var key_sets: Array = []
static var _keys := UiKeys.new()


static func get_v(i: int) -> float:
	match i:
		0:
			return Sv.vol_master
		1:
			return Sv.vol_sfx
	return Sv.vol_music


static func set_v(i: int, v: float) -> void:
	v = clampf(snappedf(v, 0.01), 0.0, 1.0)
	match i:
		0:
			Sv.vol_master = v
		1:
			Sv.vol_sfx = v
		_:
			Sv.vol_music = v
	apply()


## 저장된 값을 소리에 반영한다. 허브가 켤 때 한 번, 값이 바뀔 때마다 부른다.
static func apply() -> void:
	Sv.sfx = Sv.vol_sfx > 0.001
	Sv.music = Sv.vol_music > 0.001
	var mute := test_mute or Sv.vol_master <= 0.001
	AudioServer.set_bus_mute(0, mute)
	if not mute:
		AudioServer.set_bus_volume_db(0, linear_to_db(Sv.vol_master))
	Snd.volume_db = Snd.BASE_DB + (linear_to_db(Sv.vol_sfx) if Sv.sfx else 0.0)
	Bgm.set_volume(Sv.vol_music)
	Bgm.apply()

# ==================== 자리 ====================


static func panel_rect(vs: Vector2) -> Rect2:
	var w := minf(620.0, vs.x - 40.0)
	return Rect2(vs.x * 0.5 - w * 0.5, vs.y * 0.5 - 330, w, 660)


static func bar_rect(vs: Vector2, i: int) -> Rect2:
	var p := panel_rect(vs)
	return Rect2(p.position.x + 110, p.position.y + 170 + i * 130, p.size.x - 220, 44)


static func minus_rect(vs: Vector2, i: int) -> Rect2:
	var b := bar_rect(vs, i)
	return Rect2(b.position.x - 92, b.position.y - 14, 72, 72)


static func plus_rect(vs: Vector2, i: int) -> Rect2:
	var b := bar_rect(vs, i)
	return Rect2(b.end.x + 20, b.position.y - 14, 72, 72)


## 아래 줄 단추 — 키 설정(들) + 맨 오른쪽 닫기. j = key_sets 번호, key_sets.size() 이면 닫기.
static func foot_rect(vs: Vector2, j: int) -> Rect2:
	var p := panel_rect(vs)
	var n := key_sets.size() + 1
	var w := 240.0 if n == 1 else minf(200.0, (p.size.x - 60.0 - 16.0 * (n - 1)) / n)
	var x0 := p.get_center().x - (w * n + 16.0 * (n - 1)) * 0.5
	return Rect2(x0 + j * (w + 16.0), p.end.y - 104, w, 80)


static func close_rect(vs: Vector2) -> Rect2:
	return foot_rect(vs, key_sets.size())

# ==================== 입력 ====================


## 눌렀다. 창이 떠 있으면 true(아래 화면으로 넘기지 않는다).
static func press(p: Vector2, vs: Vector2) -> bool:
	if not open:
		return false
	if _keys.open:   # 키 설정 쪽 — 닫으면 설정 창으로 돌아온다
		_keys.click(p, vs)
		return true
	for j in key_sets.size():
		if foot_rect(vs, j).has_point(p):
			_keys.show(String(key_sets[j][1]), key_sets[j][2])
			return true
	for i in 3:
		if minus_rect(vs, i).has_point(p):
			set_v(i, get_v(i) - STEP)
			_tick(i)
			return true
		if plus_rect(vs, i).has_point(p):
			set_v(i, get_v(i) + STEP)
			_tick(i)
			return true
		if bar_rect(vs, i).grow(16).has_point(p):
			_drag = i
			_set_from(vs, i, p.x)
			return true
	if close_rect(vs).has_point(p) or not panel_rect(vs).has_point(p):
		close()
	return true


## 창이 떠 있을 때 게임 화면이 입력을 통째로 넘기는 곳 — 누르기 · 끌기 · 떼기 · Esc. 다섯 게임이 같이 쓴다.
static func handle(ev: InputEvent, vs: Vector2) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			press(ev.position, vs)
		else:
			release()
	elif ev is InputEventMouseMotion:
		motion(ev.position, vs)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		if _keys.open:
			_keys.key(ev.keycode)
		elif ev.keycode == KEY_ESCAPE:
			close()


static func motion(p: Vector2, vs: Vector2) -> void:
	if open and _drag >= 0:
		_set_from(vs, _drag, p.x)


static func release() -> void:
	if _drag >= 0:
		_tick(_drag)
	_drag = -1


static func close() -> void:
	open = false
	_keys.open = false
	_drag = -1
	Sv.save_()


static func _set_from(vs: Vector2, i: int, x: float) -> void:
	var b := bar_rect(vs, i)
	set_v(i, (x - b.position.x) / b.size.x)


## 효과음 · 전체를 바꿨으면 그 크기로 한 번 들려준다(배경음은 이미 흐르고 있다).
static func _tick(i: int) -> void:
	if i != 2:
		Snd.play("pop")

# ==================== 그리기 ====================


static func draw(ci: CanvasItem, vs: Vector2, t: float) -> void:
	if not open:
		return
	if _keys.open:
		_keys.draw(ci, vs, t)
		return
	ci.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.05, 0.03, 0.12, 0.6), true)
	var p := panel_rect(vs)
	G2.panel(ci, p, Color(1, 1, 1, 0.96), P.INK, 5.0, 36)
	G2.text_mid(ci, Vector2(p.get_center().x, p.position.y + 70), "설정", 56, P.INK)
	var cols := [Color8(255, 150, 90), Color8(255, 120, 180), Color8(110, 170, 255)]
	for i in 3:
		var b := bar_rect(vs, i)
		var v := get_v(i)
		G2.text_mid(ci, Vector2(b.position.x + 60, b.position.y - 26), NAMES[i], 32, P.INK)
		G2.text_mid(ci, Vector2(b.end.x - 40, b.position.y - 26), "%d%%" % int(roundf(v * 100.0)), 30,
				P.INK if v > 0.001 else P.WARN)
		G2.panel(ci, b, Color(0.85, 0.85, 0.92), P.INK, 3.0, b.size.y * 0.5)
		if v > 0.001:
			var fill := Rect2(b.position, Vector2(maxf(b.size.y, b.size.x * v), b.size.y))
			G2.panel(ci, fill, cols[i], Color(), 0.0, b.size.y * 0.5)
		var knob := Vector2(b.position.x + b.size.x * v, b.get_center().y)
		ci.draw_circle(knob, 30.0, P.INK)
		ci.draw_circle(knob, 25.0, Color.WHITE if _drag != i else cols[i].lightened(0.4))
		for k in 2:
			var r := minus_rect(vs, i) if k == 0 else plus_rect(vs, i)
			G2.panel(ci, r, Color8(235, 235, 245), P.INK, 3.0, 20)
			# 글꼴에 의지하지 않고 막대로 그린다(- +)
			ci.draw_line(r.get_center() - Vector2(16, 0), r.get_center() + Vector2(16, 0), P.INK, 6.0)
			if k == 1:
				ci.draw_line(r.get_center() - Vector2(0, 16), r.get_center() + Vector2(0, 16), P.INK, 6.0)
	if test_mute:
		G2.text_mid(ci, Vector2(p.get_center().x, close_rect(vs).position.y - 30), "테스트 실행이라 소리가 꺼져 있습니다", 22, P.WARN)
	for j in key_sets.size():
		var kr := foot_rect(vs, j)
		G2.panel(ci, kr, Color8(235, 235, 245) if not kr.has_point(ci.get_local_mouse_position()) else Color8(250, 240, 200), P.INK, 4.0, 30)
		G2.text_mid(ci, kr.get_center(), String(key_sets[j][0]), 30, P.INK, 0)
	var cr := close_rect(vs)
	G2.panel(ci, cr, Color8(110, 214, 92), P.INK, 4.0, 30)
	G2.text_mid(ci, cr.get_center(), "닫기", 36, Color.WHITE, 8)
