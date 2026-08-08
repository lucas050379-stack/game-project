class_name Reel
extends RefCounted

## 릴 한 줄의 회전 상태. 스크롤 값이 커질수록 심볼이 아래로 흐른다.

var scroll := 0.0
var speed := 0.0
var spinning := false
var landing := false
var t := 0.0
var dur := 0.0
var from := 0.0
var to := 0.0
var blur := 0.0        ## 0..1 잔상 강도
var bounce := 0.0      ## 정지 직후 출렁임
var glow := 0.0        ## 총통 등장 시 발광
var tick_acc := 0.0
var tick_n := 0


func busy() -> bool:
	return spinning or landing


func start_spin(sp: float) -> void:
	spinning = true
	landing = false
	speed = sp
	blur = 0.0


## stop 위치에 정확히 서도록 목표 스크롤을 잡는다
func land(stop: int, d: float, min_cells: int) -> void:
	var L := D.STRIP_LEN
	var want := posmod(L - stop, L)
	# floor() 는 Variant 를 돌려주므로 floorf() 를 써야 타입이 잡힌다
	var s := floorf(scroll) + min_cells
	var cur := posmod(int(s), L)
	var add := posmod(want - cur, L)
	to = s + add
	from = scroll
	t = 0.0
	dur = d
	spinning = false
	landing = true


func update(dt: float) -> void:
	if spinning:
		scroll += speed * dt
		blur = minf(1.0, blur + dt * 5.0)
	elif landing:
		t += dt
		var u := clampf(t / dur, 0.0, 1.0)
		# 목표를 살짝 지나쳤다가 되돌아온다
		var over := sin(PI * minf(1.0, u / 0.82)) * 0.16 * (1.0 - u)
		scroll = from + (to - from) * G2.out_quint(u) + over
		blur = maxf(0.0, 1.0 - u * 1.6)
		if u >= 1.0:
			scroll = to
			landing = false
			blur = 0.0
			bounce = 1.0
	if bounce > 0.0:
		bounce = maxf(0.0, bounce - dt * 4.2)
	if glow > 0.0:
		glow = maxf(0.0, glow - dt * 1.1)
