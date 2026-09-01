class_name World
extends RefCounted

## 한 판의 상태와 규칙.
##
## 적·탄·이펙트는 노드를 만들지 않고 [Dictionary] 배열로 들고 [method draw] 한 곳에서 그린다.
## 수백 개를 노드로 만들면 생성·해제 비용만으로 프레임이 무너진다.

enum St { PLAY, DEAD, CLEAR, OVER, ALLCLEAR }

var st := St.PLAY
var t := 0.0
var scroll := 0.0
var w := D.PLAY_W
var h := 640.0

# ---------- 아군 ----------
var craft := 0
var pos := Vector2.ZERO
var lives := D.LIVES
var bombs := D.BOMBS
var power := 0
var invuln := 0.0
var respawn := 0.0
var fire_cd := 0.0
var wave_cd := 0.0
var focus := false

# ---------- 미사일 버튼 ----------
## 톡 누르면 미사일, 길게 눌러 채우고 **떼면** 서브기체 스킬. 본 사격은 자동 그대로다.
var charge := 0.0      ## 누르고 있는 시간. D.CHARGE_T 를 넘으면 스킬이 준비된다.
var btn := false       ## 지난 프레임에 눌려 있었나 (누름·뗌을 가리려고 둔다)
var skill_cd := 0.0
var skill_t := 0.0     ## 스킬이 나가는 중이면 0 보다 크다
var skill_seq := 0     ## 스킬이 몇 번 뿜었나
## 서브기체 사격 횟수. 두 번에 한 번만 쏘는 기체(커세어 · 스핏파이어)가 이걸 본다.
var opt_seq := 0

# ---------- 판 ----------
var round_i := 0
var diff := 0
var prog := 0.0          ## 라운드 진행도 0~1
var wave_i := 0
var power_i := 0     ## D.POWER_AT 에서 어디까지 지났나
var power_due := 0   ## 아직 안 떨어뜨린 P 개수
var mid_done := false
var boss_done := false
var score := 0
var next_extend := D.EXTEND_AT

# ---------- 배열 ----------
var pb: Array[Dictionary] = []      ## 아군 탄
var opts: Array[Dictionary] = []    ## 옵션기(편대). 슈팅스타만 쓴다.
var eb: Array[Dictionary] = []      ## 적 탄
var foes: Array[Dictionary] = []
var items: Array[Dictionary] = []
var booms: Array[Dictionary] = []
var boss: Dictionary = {}
var bomb: Dictionary = {}
## 관통탄이 "이미 때린 표적"을 가리는 데 쓴다. 적마다 번호를 하나씩 준다.
var foe_seq := 0

## 전기 기둥(라이트닝). 탄이 아니라 기체가 들고 있는 하나짜리 무기다.
## `bolt` 는 마디별 **좌우 흔들림(px)** 이고, 실제 좌표는 그릴 때 기체 위치에서 만든다.
var bolt := PackedFloat32Array()
var bolt_cd := 0.0
var bolt_re := 0.0
## 기둥이 막히는 y. 관통을 안 하므로 여기까지만 그린다.
var bolt_top := -20.0
## 이번 프레임의 기둥 굵기. **판정과 그리기가 같은 값을 본다** — 채우는 동안 가늘어지는데
## 그림만 그대로면 맞는 자리와 보이는 자리가 어긋난다.
var bolt_w := 0.0

var clear_t := 0.0
var shake := 0.0
## 총구 섬광. 쏘는 순간 1 이 되고 빠르게 준다 — 자동 사격이라 **쏘고 있다는 것 자체가
## 화면에서 안 읽히면** 손에 든 것이 장식처럼 보인다.
var flash := 0.0
## 무인 주행 전용. 가만히 서 있으면 죽어서 보스까지 못 가므로 soak 테스트에서만 켠다.
var god := false
var rng := RandomNumberGenerator.new()


func _init(craft_idx: int = 0, round_idx: int = 0, diff_idx: int = 0) -> void:
	rng.randomize()
	craft = craft_idx
	round_i = round_idx
	diff = clampi(diff_idx, 0, D.DIFF.size() - 1)
	pos = Vector2(w * 0.5, h - 110.0)


func setup(play_h: float) -> void:
	h = play_h
	pos = Vector2(w * 0.5, h - 110.0)


## soak 테스트용. 웨이브 표를 건너뛰고 진행도를 앞으로 감는다.
func skip_to(p: float) -> void:
	if p <= 0.0:
		return
	_wind_to(p)
	mid_done = prog >= D.MIDBOSS_AT


## 진행도를 앞으로 감고, 그 사이의 웨이브와 P 를 **지나간 것으로 친다.**
## 감기만 하고 표 색인을 안 밀면 다음 프레임에 밀린 웨이브가 한꺼번에 쏟아진다.
func _wind_to(p: float) -> void:
	prog = p
	var wv: Array = D.WAVE[round_i]
	while wave_i < wv.size() and wv[wave_i].at <= prog:
		wave_i += 1
	while power_i < D.POWER_AT.size() and D.POWER_AT[power_i] <= prog:
		power_i += 1


## **테스트 빌드 전용** — 라운드 보스 직전까지 감는다. soak 의 `--prog` 을 손으로 하는 것으로,
## 보스를 만질 때마다 40~50초를 기다리지 않으려고 둔다. 키는 `D.test_build()` 일 때만
## 걸리므로(`main.gd`) 배포판에는 이 통로가 아예 없다.
##
## **화면에 남은 잡졸과 적 탄을 치운다** — 안 치우면 보스가 무리 위로 내려앉고,
## 지나가지도 않은 웨이브의 탄에 맞아 죽는다.
##
## **파워는 만렙으로 둔다.** 진행도 0.92 면 P 아홉 개가 이미 다 나온 뒤라 제대로 논 판과
## 같은 상태이고, 보스의 설계 초(`secs`)도 만렙 화력 기준으로 잡혀 있다. 맨몸으로 두면
## 손으로 재는 초가 표와 안 맞아서 무엇이 기준인지 알 수 없게 된다.
func skip_to_boss() -> bool:
	if st != St.PLAY or boss_done or not boss.is_empty():
		return false
	_wind_to(D.BOSS_AT)
	mid_done = true       # 중간보스는 지나간 것으로 친다
	power_due = 0
	power = D.POWER_MAX
	foes.clear()
	eb.clear()
	items.clear()
	return true


## 다음 라운드로 넘어간다. **점수 · 잔기 · 봄 · 파워는 그대로 가져간다** —
## 라운드마다 맨몸으로 되돌리면 뒤로 갈수록 클리어가 아니라 벌이 된다.
func advance() -> bool:
	if round_i + 1 >= D.ROUND.size():
		return false
	round_i += 1
	prog = 0.0
	wave_i = 0
	power_i = 0
	power_due = 0
	mid_done = false
	boss_done = false
	clear_t = 0.0
	foes.clear()
	eb.clear()
	pb.clear()
	items.clear()
	booms.clear()
	boss = {}
	bomb = {}
	opts.clear()
	st = St.PLAY
	invuln = D.INVULN
	pos = Vector2(w * 0.5, h - 110.0)
	charge = 0.0
	btn = false
	skill_cd = 0.0
	skill_t = 0.0
	if god:
		print("[round] %s" % D.ROUND[round_i].name)
	return true


func dm() -> Dictionary:
	return D.DIFF[diff]


func land() -> String:
	return D.ROUND[round_i].land


func craft_col() -> Color:
	return P.craft(craft, 3)

# ==================== 진행 ====================

func step(dt: float, dir: Vector2, want_focus: bool, want_bomb: bool,
		want_skill: bool = false) -> void:
	t += dt
	scroll += D.SCROLL * dt
	shake = maxf(0.0, shake - dt * 3.0)
	flash = maxf(0.0, flash - dt * 11.0)
	focus = want_focus

	if st == St.PLAY or st == St.DEAD:
		_step_round(dt)
	elif st == St.CLEAR:
		clear_t += dt
	_step_player(dt, dir, want_bomb)
	_step_bolt(dt)
	_step_fire(dt, want_skill)
	_step_bomb(dt)
	_step_bullets(dt)
	_step_foes(dt)
	_step_boss(dt)
	_step_items(dt)
	_collide()
	_sweep()

	for b in booms:
		b.p += dt * 2.3
	booms = _keep(booms, func(b): return b.p < 1.0)


func _step_round(dt: float) -> void:
	var rd: Dictionary = D.ROUND[round_i]
	if boss.is_empty():
		prog = minf(1.0, prog + dt / rd.time)
	var wv: Array = D.WAVE[round_i]
	while wave_i < wv.size() and wv[wave_i].at <= prog:
		_spawn_wave(wv[wave_i])
		wave_i += 1
	while power_i < D.POWER_AT.size() and D.POWER_AT[power_i] <= prog:
		power_i += 1
		power_due += 1
	if not mid_done and prog >= D.MIDBOSS_AT and boss.is_empty():
		mid_done = true
		_spawn_boss("midboss", true)
	if not boss_done and prog >= D.BOSS_AT and boss.is_empty():
		boss_done = true
		_spawn_boss(rd.boss, false)
	if boss_done and boss.is_empty() and st == St.PLAY:
		st = St.CLEAR


# ==================== 아군 ====================


func _step_player(dt: float, dir: Vector2, want_bomb: bool) -> void:
	if st == St.OVER or st == St.CLEAR:
		return
	if st == St.DEAD:
		respawn -= dt
		if respawn <= 0.0:
			if lives <= 0:
				st = St.OVER
			else:
				st = St.PLAY
				pos = Vector2(w * 0.5, h - 90.0)
				invuln = D.INVULN
				power = maxi(0, power - 1)
				bombs = D.BOMBS
		return

	invuln = maxf(0.0, invuln - dt)
	var sp: float = D.CRAFT[craft].speed * (D.FOCUS_MUL if focus else 1.0)
	pos += dir * sp * dt
	pos.x = clampf(pos.x, 12.0, w - 12.0)
	pos.y = clampf(pos.y, 26.0, h - 22.0)
	_step_opts(dt)

	if want_bomb:
		fire_bomb()

	fire_cd -= dt
	if fire_cd <= 0.0:
		fire_cd = _shoot()
	# 파동은 본 사격과 **주기가 다르다.** 같이 쏘면 고리가 화면을 덮어
	# 적도 적 탄도 안 보인다 — 느리고 무거운 한 방이라야 파동이다.
	if craft == 5:
		wave_cd -= dt
		if wave_cd <= 0.0:
			wave_cd = _fire_waves()


## 탄의 **생김새**. 판정은 `st` 가 정하고 이건 그림만 바꾼다 — 둘을 한 값으로 묶으면
## 모양을 손볼 때마다 판정 상자가 같이 움직여서, 이펙트를 만질 때마다 밸런스를 다시
## 재야 한다. 여섯이 서로 다른 형태를 갖는 것이 화면에서 기체를 알아보는 방법이다.
##
## 레이저(하야부사) · 번개(라이트닝) · 에너지포(커세어) · 다트(스핏파이어) ·
## 별(슈팅스타) · 반달(신덴).
const VFX := ["laser", "bolt", "cannon", "dart", "star", "moon", "needle"]


## 기체마다 파워업이 자라는 **방향**이 다르다. 세기가 아니라 방향이 이 기체를 고르는 이유다.
##
## 본 사격은 여섯 다 **직선에 가깝다.** 벌어지는 각을 크게 두면 좁은 표적에서만 절반이
## 새어 나가고, 그 손실이 표적마다 달라 화력을 숫자 하나로 못 적는다.
func _shoot() -> float:
	var n0 := pb.size()
	var cd := 0.0
	match craft:
		0: cd = _sh_hayabusa()
		1: cd = _sh_lightning()
		2: cd = _sh_corsair()
		3: cd = _sh_spitfire()
		4: cd = _sh_shooting()
		5: cd = _sh_shinden()
		_: cd = _sh_phantom()
	_opt_shot()
	var vk: String = VFX[craft]
	for i in range(n0, pb.size()):
		# 이미 제 생김새를 받은 것은 안 덮는다(라이트닝 서브기체의 코일).
		if pb[i].vfx == "":
			pb[i].vfx = vk
	flash = 1.0
	return cd


## 서브기체는 기체 종류와 무관하게 **곧게 한 발**씩 쏜다. 여기에 기체별 성격까지 넣으면
## 대수가 그대로 화력 배수가 되어, 방금 없앤 문제(표적·상황마다 다른 화력)가 돌아온다.
## 서브기체 사격. **기체마다 다르다.**
##
## 한때 여섯이 똑같이 곧은 한 발을 쐈다. 검산을 지키려고 그랬는데, 그러면 서브기체가
## **총구가 하나 더 늘어난 것**일 뿐이라 편대로 안 보이고 기체를 고를 이유에도 안 보탠다.
##
## 개성을 내되 검산은 지키는 선이 둘이다.
##
## 1. **표적 크기를 타는 것을 넣지 않는다** — 넓게 벌어지는 확산도, 겹친 동안 반복해서
##    때리는 관통도 안 된다(관통은 표적당 1회라 괜찮다). 이게 화력을 숫자 하나로
##    적을 수 있게 하는 조건이다.
## 2. **한 대가 내는 평균 피해는 여섯이 같다** — 커세어와 스핏파이어는 두 번에 한 번
##    쏘는 대신 두 배로 때린다. 대수가 곧 화력 배수인 것은 그대로 두고 **형태만** 나눈다.
##
## **안쪽으로 겨누게 하지 마라.** 좁은 표적을 빗나가는 걸 막으려고 탄을 본체 쪽으로
## 모아 봤는데, 여섯 대가 전부 안으로 겨누는 그림이 되어 편대가 아니라 고장 난 것처럼
## 보였다. 명중은 **탄의 각도가 아니라 서브기체의 자리**로 푼다(`_opt_slot`).
func _opt_shot() -> void:
	# **채우는 동안에는 서브기체가 아무것도 안 한다 — 사격도 미사일도.**
	#
	# 스킬은 **서브기체의 것**이다. 힘을 모으는 동안 서브기체가 평소대로 쏘고 있으면
	# 화면에서 규칙이 안 읽힌다 — 실제로 버튼 미사일만 막았더니 서브기체 탄이 3초에
	# 156발씩 계속 나가서 "미사일이 여전히 나온다" 로 보였다.
	# 고리 그림에서 서브기체가 본체 쪽으로 딸려 들어오는 것과 같은 이야기다.
	#
	# **본체 사격은 안 멈춘다.** 그건 자동 사격이고, 멈추면 채우는 동안 무방비가 된다.
	# 스핏파이어 본 사격의 유도탄이 계속 나가는 것도 그래서다 — 그건 미사일이 아니라
	# 이 기체의 기본탄이다.
	if charge > 0.0:
		return
	var c := craft_col()
	opt_seq += 1
	var alt := opt_seq % 2 == 0
	for i in opts.size():
		var p: Vector2 = opts[i].pos + Vector2(0, -8)
		match craft:
			0:
				# 가는 관통 빔 — 본체 빔의 축소판. 줄 서 있는 잡졸을 같이 꿴다.
				var b0 := _bul(p, Vector2(0, -520), "beam", c)
				b0.wd = 5.0
				b0.pierce = true
			1:
				# 좌우로 번갈아 — 서 있어도 훑는 폭이 생긴다. 각은 ±6° 뿐이다.
				# **라이트닝 서브기체는 안 쏜다.** 기둥에 기운을 보낼 뿐이고, 그 몫은
				# 기둥의 피해(`D.BOLT_DMG`)에 이미 들어가 있다 — 화면에서는 서브기체에서
				# 뿌리로 흐르는 줄기(`Art.feed`)와 기둥을 감는 나선으로 보인다.
				#
				# 탄을 따로 띄웠다가 되돌렸다. 기둥과 따로 노는 알갱이가 되어 "보조기체가
				# 뭘 하는지" 가 오히려 안 읽혔다.
				pass
			2:
				# 두 번에 한 번, 두 배로. 느리고 무거운 것이 이 기체다.
				if alt:
					var b2 := _bul(p, Vector2(0, -430), "spread", c)
					b2.dmg = 2
			3:
				# 두 번에 한 번, 작은 유도탄. 서브기체까지 알아서 쫓아간다.
				if alt:
					var b3 := _bul(p, Vector2(0, -330), "homing", c)
					b3.k = "h"
					b3.dmg = 2
					b3.life = 1.8
			4:
				# 편대가 축이다 — 본체와 같은 곧은 탄으로 두고 **대수로** 승부한다.
				_bul(p, Vector2(0, -470), "spread", c)
			6:
				# 두 번에 한 번, 작은 추진 미사일. 본체와 같은 축이라 묶여 보인다.
				if alt:
					var b6 := _bul(p + Vector2(0, 12.0), Vector2(0, 95.0), "missile", c)
					b6.dmg = 3
					b6.grav = D.MSL_GRAV
					b6.life = 1.9
			_:
				# 작은 반달 고리. 본체 파동과 같은 결이라 한 기체의 것으로 묶여 보인다.
				#
				# **안 커지고 금방 사라진다.** 서브기체가 4대가 되면서 초당 서른 개 넘게
				# 나가는데, 이게 본체 파동처럼 자라면 고리가 화면을 통째로 덮어 **적도 적
				# 탄도 안 보인다**(실제로 그랬다). 커지는 것은 본체 파동 하나뿐이라야
				# "파동"이 이 기체의 축으로 읽힌다.
				# 수명은 **닿을 만큼**은 줘야 한다 — 0.7초(280px)면 위쪽에 뜬 보스에 아예
				# 안 닿아서 서브기체 무기가 통째로 놀았다. 대신 빠르게 보내 화면에 겹치는
				# 수는 그대로 둔다.
				var b5 := _bul(p, Vector2(0, -480), "wave", c)
				b5.k = "w"
				b5.wd = 12.0
				b5.grow = 0.0
				b5.life = 1.0
				b5.pierce = true


## 관통 · 집중 — 가운데로 모이면서 굵어지고, 끝에는 적을 뚫는 빔이 된다.
##
## **레벨별 값은 전부 길이 `D.POWER_MAX + 1` 짜리 배열이다.** `match power` 로 쓰면
## 단계를 늘릴 때마다 여섯 함수를 다 뜯어야 하고, 빠뜨린 단계가 조용히 아래 단계로
## 떨어진다. 배열이면 칸을 하나 더 적는 것으로 끝난다.
func _sh_hayabusa() -> float:
	var c := craft_col()
	var y := pos.y - 16.0
	var bw: float = [0.0, 5.0, 8.0, 11.0, 13.0, 15.0][power]
	var bd: int = [0, 2, 2, 3, 3, 3][power]
	if bw > 0.0:
		_beam(Vector2(pos.x, y - 6.0), bw, power >= 2, bd)
	# 옆탄은 레벨이 오를수록 안쪽으로 휜다 — 이 기체의 축이 "집중" 이다.
	var ox: float = [7.0, 9.0, 11.0, 11.0, 13.0, 13.0][power]
	var vx: float = [0.0, 0.0, 14.0, 18.0, 22.0, 22.0][power]
	# **옆탄은 느리게 나가다 확 빨라진다**(`accel`). 궤적은 직선 그대로라 화력은 안 변하고,
	# 튀어나가는 리듬만 생긴다 — "집중"이라는 축을 안 흔드는 방식이다.
	_acc(_bul(Vector2(pos.x - ox, y), Vector2(vx, -480), "shot", c))
	_acc(_bul(Vector2(pos.x + ox, y), Vector2(-vx, -480), "shot", c))
	if power >= 5:
		_acc(_bul(Vector2(pos.x - ox - 8.0, y + 6.0), Vector2(vx * 1.5, -470), "shot", c))
		_acc(_bul(Vector2(pos.x + ox + 8.0, y + 6.0), Vector2(-vx * 1.5, -470), "shot", c))
	return [0.12, 0.115, 0.11, 0.105, 0.10, 0.10][power]


## 추진 — **쏘고 나서 붙는 미사일.** 기관포 두 발에 미사일이 딸린다.
##
## 미사일은 **아래로 나갔다가** `D.MSL_GRAV` 로 뒤집혀 앞질러 간다(`_step_bullets`).
## 눈앞의 적에는 느리고 조금 떨어진 적에는 제일 빠르므로, **거리를 두는 것이 이득인
## 유일한 기체**다 — 다른 기체가 전부 붙어서 쏘는 것과 반대다.
func _sh_phantom() -> float:
	var c := craft_col()
	var y := pos.y - 14.0
	_bul(Vector2(pos.x - 9.0, y), Vector2(0, -470), "shot", c)
	_bul(Vector2(pos.x + 9.0, y), Vector2(0, -470), "shot", c)
	if power >= 3:
		_bul(Vector2(pos.x - 17.0, y + 5.0), Vector2(0, -460), "shot", c)
		_bul(Vector2(pos.x + 17.0, y + 5.0), Vector2(0, -460), "shot", c)
	var mn: int = [1, 1, 2, 2, 3, 3][power]
	var md: int = [2, 2, 3, 3, 3, 3][power]
	for i in mn:
		var o: float = i - (mn - 1) * 0.5
		# 날개 밑에서 **아래로** 떨어뜨린다. 옆으로 미는 것은 겹쳐 보이지 않을 만큼만 —
		# 크게 벌리면 발수를 늘려도 그만큼 빗나가서, P4 가 P3 보다 약해지는 역전이 났다.
		var b := _bul(pos + Vector2(o * 16.0, 8.0), Vector2(o * 34.0, 105.0), "missile", c)
		b.dmg = md
		b.grav = D.MSL_GRAV
		b.life = 1.9
	# **프레임 양자화에 걸리지 않게 한 칸씩 벌린다.** 0.16 과 0.155 는 60fps 에서 둘 다
	# 10프레임이라 P4 와 P5 가 똑같아졌었다 — 재사용 대기는 1/60 단위로만 의미가 있다.
	return [0.22, 0.21, 0.20, 0.19, 0.185, 0.17][power]


## 확산 — **전기 기둥.** 본 사격에서 탄이 안 나간다(`_step_bolt` 가 대신 한다).
## 여기서는 서브기체 주기만 돌려준다.
func _sh_lightning() -> float:
	return [0.14, 0.13, 0.12, 0.12, 0.125, 0.125][power]


## 전기 기둥을 한 프레임 굴린다. 기체에서 화면 위까지 **곧게** 선다.
##
## 지그재그는 `BOLT_FLICK` 마다 다시 뽑는다 — 매 프레임 뽑으면 너무 시끄러워서 형태가
## 안 읽히고, 안 뽑으면 그냥 굵은 선이라 전기로 안 보인다.
func _step_bolt(dt: float) -> void:
	if craft != 1 or st != St.PLAY:
		bolt.resize(0)
		return
	# **채우는 동안에는 기둥이 가늘고 약해진다.** 서브기체가 기둥에 기운을 보내는
	# 기체이므로, 그 기운을 스킬로 돌리면 기둥이 그만큼 줄어드는 것이 앞뒤가 맞는다 —
	# 다른 기체가 채우는 동안 서브기체 사격을 잃는 것과 같은 대가다.
	var wk: float = D.BOLT_CHARGE_K if charge > 0.0 else 1.0
	var wdt: float = D.BOLT_W[power] * wk
	bolt_w = wdt
	bolt_re -= dt
	if bolt_re <= 0.0 or bolt.size() != D.BOLT_SEG:
		bolt_re = D.BOLT_FLICK
		bolt.resize(D.BOLT_SEG)
		for i in D.BOLT_SEG:
			# 뿌리와 끝은 안 흔든다. 뿌리가 흔들리면 총구에서 떨어져 보인다.
			var e: float = sin(float(i) / float(D.BOLT_SEG - 1) * PI)
			bolt[i] = rng.randf_range(-1.0, 1.0) * wdt * 0.30 * e

	# **기둥은 관통하지 않는다.** 처음 닿는 것에서 막히고 거기까지만 그려진다 —
	# 그래야 "지지는 중" 이 화면에 보이고, 앞의 것을 치우는 것이 곧 사거리가 된다.
	# (관통시키면 한 틱에 줄 서 있는 것을 전부 때려서 화력이 표적 수를 그대로 탄다.)
	var half: float = wdt * 0.5
	var top: float = pos.y - 14.0
	var hit_f: Dictionary = {}
	var stop: float = -20.0
	for f in foes:
		if f.dead or f.pos.y > top:
			continue
		if absf(f.pos.x - pos.x) >= half + f.r:
			continue
		var edge: float = f.pos.y + f.r
		if edge > stop:
			stop = edge
			hit_f = f
	var hit_boss := false
	if not boss.is_empty() and boss.y_in and not boss.morphing:
		var bedge: float = boss.pos.y + boss.r.y
		if bedge < top and absf(boss.pos.x - pos.x) < half + boss.r.x and bedge > stop:
			stop = bedge
			hit_f = {}
			hit_boss = true
	bolt_top = minf(top, stop)

	bolt_cd -= dt
	if bolt_cd > 0.0:
		return
	bolt_cd = D.BOLT_TICK
	var dmg: int = maxi(1, int(round(D.BOLT_DMG[power] * wk)))
	if hit_boss:
		boss.hp -= dmg
		booms.append({pos = Vector2(pos.x, stop), p = 0.0, s = 12.0, k = "hit",
				c = craft_col()})
		_award(40)
	elif not hit_f.is_empty():
		booms.append({pos = hit_f.pos, p = 0.0, s = 10.0, k = "hit", c = craft_col()})
		_hurt(hit_f, dmg)


## 확산 — 줄기가 는다. **폭이 아니라 발수로 덮는다.**
##
## 예전에는 만렙이 ±41° 로 벌어졌는데, 그러면 해룡(가로 반지름 25px)처럼 좁은 표적에서만
## 20% 를 잃어서 "표적에 따라 다른 화력"이 된다. 지금은 벌어지는 폭을 훑는 느낌이 남을
## 만큼만 두고(만렙 ±11°) 발수로 촘촘하게 만든다.


## 화력 · 관통 — 한 줄기가 계속 두꺼워진다. 연사는 느리지만 보스에 붙으면 제일 빠르다.
func _sh_corsair() -> float:
	var c := craft_col()
	var y := pos.y - 18.0
	var wd: float = [7.0, 9.0, 12.0, 16.0, 20.0, 23.0][power]
	var bdmg: int = [2, 2, 3, 4, 4, 5][power]
	_beam(Vector2(pos.x, y), wd, power >= 3, bdmg)
	if power >= 2:
		_fan(Vector2(pos.x - 14.0, pos.y - 4.0), -0.09, 400.0, "spread", c)
		_fan(Vector2(pos.x + 14.0, pos.y - 4.0), 0.09, 400.0, "spread", c)
	if power >= 4:
		_fan(Vector2(pos.x - 19.0, pos.y + 2.0), -0.17, 380.0, "spread", c)
		_fan(Vector2(pos.x + 19.0, pos.y + 2.0), 0.17, 380.0, "spread", c)
	return [0.19, 0.175, 0.16, 0.15, 0.135, 0.125][power]


## 유도 — **자동으로 쫓아가는 탄을 가진 유일한 기체.**
##
## 유도를 미사일 버튼으로만 내보냈던 적이 있는데, 그러면 "겨냥을 안 해도 맞는다"는 축이
## **버튼을 눌러야만 성립한다.** 본 사격이 자동인 게임에서 그건 축이 아니라 옵션이다.
##
## 예전에 유도탄이 문제였던 건 유도가 아니라 **처음 각도(±78°)** 였다. 되돌아오는 데
## 시간을 다 쓰고 절반이 화면 밖으로 샜다. 지금은 거의 곧게 내보내고 나머지를 유도에
## 맡긴다 — 그래서 표적이 좁든 넓든 화력이 같다.
func _sh_spitfire() -> float:
	var c := craft_col()
	var y := pos.y - 14.0
	_bul(Vector2(pos.x - 8.0, y), Vector2(0, -460), "shot", c)
	_bul(Vector2(pos.x + 8.0, y), Vector2(0, -460), "shot", c)
	if power >= 2:
		_bul(Vector2(pos.x - 16.0, y + 4.0), Vector2(0, -460), "shot", c)
		_bul(Vector2(pos.x + 16.0, y + 4.0), Vector2(0, -460), "shot", c)
	if power >= 5:
		_bul(Vector2(pos.x - 23.0, y + 9.0), Vector2(0, -450), "shot", c)
		_bul(Vector2(pos.x + 23.0, y + 9.0), Vector2(0, -450), "shot", c)
	var hn: int = [1, 1, 1, 2, 2, 3][power]
	for i in hn:
		var off: float = i - (hn - 1) * 0.5
		var b := _fan(pos + Vector2(off * 13.0, -6.0), off * 0.22, 330.0, "homing", c)
		b.k = "h"
		# 수명을 준다. 표적을 놓친 유도탄이 화면을 맴돌면 그것만으로 화면이 지저분해지고,
		# 살아 있는 탄 수가 그대로 그리기 비용이 된다.
		b.life = 2.0
	return [0.135, 0.13, 0.125, 0.12, 0.115, 0.115][power]


## 편대 — 서브기체가 남보다 한 대씩 많다. 본체 사격은 곧은 줄기뿐이고,
## 서브기체 사격은 `_opt_shot` 이 여섯 기체 공통으로 처리한다.
func _sh_shooting() -> float:
	var c := craft_col()
	var y := pos.y - 16.0
	_bul(Vector2(pos.x - 6.0, y), Vector2(0, -480), "shot", c)
	_bul(Vector2(pos.x + 6.0, y), Vector2(0, -480), "shot", c)
	if power >= 4:
		_bul(Vector2(pos.x - 15.0, y + 5.0), Vector2(0, -470), "shot", c)
		_bul(Vector2(pos.x + 15.0, y + 5.0), Vector2(0, -470), "shot", c)
	return [0.12, 0.115, 0.11, 0.105, 0.098, 0.098][power]


## 파동 — 앞으로 나가며 커지는 고리. 멀리 있는 적일수록 넓게 훑는다.
func _sh_shinden() -> float:
	var c := craft_col()
	var y := pos.y - 16.0
	# **나선** — 앞으로 가면서 좌우로 감긴다. 좌우가 서로 반대로 감겨야 꼬인 것으로
	# 보인다(같은 위상이면 그냥 둘 다 흔들리는 것으로 읽힌다).
	_spin(_bul(Vector2(pos.x - 7.0, y), Vector2(0, -470), "shot", c), -1.0)
	_spin(_bul(Vector2(pos.x + 7.0, y), Vector2(0, -470), "shot", c), 1.0)
	if power >= 3:
		_spin(_bul(Vector2(pos.x - 16.0, y + 5.0), Vector2(0, -450), "shot", c), 1.0)
		_spin(_bul(Vector2(pos.x + 16.0, y + 5.0), Vector2(0, -450), "shot", c), -1.0)
	return [0.16, 0.15, 0.145, 0.14, 0.13, 0.125][power]


## 파동 — 앞으로 나가며 커지는 고리. 멀리 있는 적일수록 넓게 훑는다.
func _fire_waves() -> float:
	var c := craft_col()
	var n: int = [1, 1, 1, 2, 2, 3][power]
	var w0: float = [16.0, 18.0, 20.0, 24.0, 26.0, 28.0][power]
	var gw: float = [46.0, 50.0, 54.0, 62.0, 66.0, 70.0][power]
	for i in n:
		var b := _bul(Vector2(pos.x + (i - (n - 1) * 0.5) * 34.0, pos.y - 12.0),
				Vector2(0, -290), "wave", c)
		b.k = "w"
		b.wd = w0
		b.grow = gw
		b.vfx = "moon"
		# 관통이 표적당 1회가 되면서 고리가 한 번만 들어간다. 예전 값(2)이면 초당 12 밖에
		# 안 나와 파동이 장식이 된다 — **한 번 지나갈 때 무겁게** 들어가야 축이 산다.
		b.dmg = 6
		b.pierce = true
	return [0.66, 0.62, 0.58, 0.55, 0.52, 0.5][power]


## `hit` 은 **관통탄이 이미 때린 적 번호**다. 한 표적은 한 번만 때리므로 여기 있는지 본다.
## `hitb` 는 보스용(하나뿐이라 번호가 필요 없다). `life` 가 0 보다 크면 그만큼 뒤에 터진다.
## 지연 가속을 건다. 평소 발사 속도 그대로 만든 탄에 걸면 된다.
##
## **방향은 그대로 두고 속력만 낮춘다.** 처음에 `vy` 만 낮춰서 느리게 만들었더니
## 벌어지는 각도가 2.6° → 3.8° 로 커져서 작고 빠르게 움직이는 표적을 더 빗나갔다
## (중간보스가 12.0 → 13.4초로 늘었다). 고정 표적 계측에는 안 잡히는 종류의 실수다.
func _acc(b: Dictionary) -> Dictionary:
	b.vel *= 0.55
	b.accel = 1600.0
	return b


## 나선을 건다. `dir` 이 감기는 쪽(±1). 좌우를 반대로 줘야 꼬인 것으로 보인다.
func _spin(b: Dictionary, dir: float) -> Dictionary:
	b.spin = D.SPIN_AMP * dir
	return b


func _bul(p: Vector2, v: Vector2, st_: String, col: Color) -> Dictionary:
	var b := {pos = p, vel = v, st = st_, col = col, wd = 0.0, grow = 0.0, pierce = false,
		k = "s", dmg = 1, dead = false, hit = PackedInt32Array(), hitb = false, life = 0.0,
		vfx = "", tgt = Vector2.INF, tcd = 0.0,
		# 궤적을 바꾸는 것들. 0 이면 그냥 직진한다.
		chain = 0, spin = 0.0, accel = 0.0, age = 0.0, grav = 0.0}
	pb.append(b)
	return b


func _fan(p: Vector2, ang: float, spd: float, st_: String, col: Color) -> Dictionary:
	return _bul(p, Vector2(sin(ang), -cos(ang)) * spd, st_, col)


func _beam(p: Vector2, wd: float, pierce: bool, dmg: int) -> void:
	var b := _bul(p, Vector2(0, -520), "beam", craft_col())
	b.wd = wd
	b.pierce = pierce
	b.dmg = dmg


## 서브기체 자리. **자리표를 두지 않고 계산한다** — 기체마다 대수가 다르고(슈팅스타는
## 「분열 편대」로 잠시 8대까지 간다) 표로 두면 여섯 벌을 관리하게 된다.
## 짝수 번은 왼쪽, 홀수 번은 오른쪽으로 좌우 대칭이 유지된다.
## **옆으로 벌리지 말고 뒤로 세운다.** 서브기체는 곧게 쏘므로 자리가 곧 명중률이다 —
## 옆으로 벌린 만큼 좁은 표적(해룡은 가로 반지름 25px)을 통째로 빗나가서, 대수가 화력이
## 아니라 표적 운이 된다. 예전 자리(±26 · ±41)에서 슈팅스타가 해룡에게만 32% 를 잃었다.
## 지금은 넷이 다 ±26 안에 들어오고, 늘어나는 만큼 **뒤로** 늘어선다.
func _opt_slot(i: int) -> Vector2:
	var side := -1.0 if i % 2 == 0 else 1.0
	var rank := float(i / 2)
	return Vector2(side * (22.0 + rank * 4.0), 14.0 + rank * 26.0)


## **서브기체는 여섯 기체 전부에 있다.** 대수만 기체마다 다르고(`D.CRAFT[i].opts`),
## 슈팅스타가 한 대씩 더 많다 — 그게 편대라는 축이다.
func _step_opts(dt: float) -> void:
	var want: int = D.CRAFT[craft].opts[power]
	if skill_t > 0.0 and craft == 4:
		want *= 2                     # 「분열 편대」 — 스킬이 도는 동안만 두 배
	while opts.size() < want:
		opts.append({pos = pos})
	while opts.size() > want:
		opts.pop_back()
	for i in want:
		var tgt: Vector2 = pos + _opt_slot(i) + Vector2(sin(t * 2.0 + i) * 4.0, 0.0)
		opts[i].pos = opts[i].pos.lerp(tgt, minf(1.0, dt * 7.0))


# ==================== 서브기체 스킬 ====================
#
# **손으로 하는 것은 `R` 하나다.**
#
# 본 사격은 자동이고 발사 버튼이 없다 — 안 누를 이유가 없는 버튼은 늘 누르고 있는 것이
# 정답이라 판단이 아니라 손가락 부담일 뿐이다. 한때 미사일에 그런 버튼을 뒀다가 같은
# 이유로 없앴고, **미사일이라는 층 자체도 지금은 없다**(스킬 「미사일 폭우」 뿐이다).
#
# 남은 것은 **`R` 을 누르고 있으면 서브기체가 전부 멈추고 스킬이 차오르는 것** 하나다.
# 떼면 나간다 — **지금 화력을 접고 한 방을 준비할 때인가.**

func _step_fire(dt: float, want_skill: bool) -> void:
	skill_cd = maxf(0.0, skill_cd - dt)
	if skill_t > 0.0:
		skill_t = maxf(0.0, skill_t - dt)
		_skill_tick()
	if st != St.PLAY:
		charge = 0.0
		btn = want_skill
		return
	if want_skill:
		# **누르고 있는 동안에는 예외 없이 서브기체가 멈춘다**(`_opt_shot` 이 바로 빠진다).
		# "이럴 때만 나간다" 같은 예외를 두면 화면에서 규칙이 안 읽힌다 — 누르고 있는데
		# 뭔가 나가는 순간을 본 사람은 그걸 고장으로 받아들인다.
		#
		# 대신 **식는 중에도 게이지는 찬다.** 안 그러면 누르고 있어도 아무 일이 없는
		# 구간이 생겨서, 눌러 봐야 손해인 함정이 된다. 오래 누르면 언제나 결국 나간다.
		charge += dt
	else:
		if btn and charge >= D.CHARGE_T and skill_cd <= 0.0:
			_fire_skill()
		charge = 0.0
	btn = want_skill


## 황금 밧줄이 지금 어디까지 뻗었나(라이트닝 스킬).
##
## **기체에서 자라 나온다.** 다 자란 채로 튀어나오면 갑자기 생긴 것처럼 보인다.
## 끝에서는 다시 감겨 들어가 툭 사라지지 않게 한다.
func rope_top() -> float:
	if skill_t <= 0.0:
		return pos.y
	var root: float = pos.y - 14.0
	var p: float = 1.0 - skill_t / D.SKILL_DUR       # 0 → 1
	var k: float = minf(1.0, p / 0.30)               # 앞 30%% 동안 자란다
	if p > 0.82:
		k = minf(k, (1.0 - p) / 0.18)                # 뒤 18%% 동안 감겨 들어간다
	var grown: float = root - (root + 20.0) * maxf(0.0, k)
	# **밧줄도 기둥처럼 처음 닿는 것에서 막힌다.** 자란 길이와 막힌 자리 중 **가까운 쪽**이
	# 실제 끝이다. 막히지 않고 화면 끝까지 가면 앞의 것을 치울 이유가 사라진다.
	var rr: float = D.COIL_R + 10.0
	var stop := -20.0
	for f in foes:
		if f.dead or f.pos.y > root:
			continue
		if absf(f.pos.x - pos.x) < rr + f.r:
			stop = maxf(stop, f.pos.y + f.r)
	if not boss.is_empty() and boss.y_in and not boss.morphing:
		if absf(boss.pos.x - pos.x) < rr + boss.r.x:
			stop = maxf(stop, boss.pos.y + boss.r.y)
	return maxf(grown, stop)


## 게이지가 실제로 얼마나 준비됐나 (0~1). **채우기와 식기 중 늦은 쪽**이다 —
## 둘을 따로 그리면 "다 찼는데 왜 안 나가지" 가 된다.
func charge_frac() -> float:
	var a: float = minf(1.0, charge / D.CHARGE_T)
	var b: float = 1.0 if skill_cd <= 0.0 else 1.0 - skill_cd / D.SKILL_CD
	return minf(a, b)


## 화면에 "지금 떼면 스킬" 을 알려 주려고 HUD 와 기체 그림이 같이 본다.
func charge_ready() -> bool:
	return charge_frac() >= 1.0


func _fire_skill() -> void:
	skill_cd = D.SKILL_CD
	skill_t = D.SKILL_DUR
	skill_seq = 0
	shake = maxf(shake, 0.45)


## 스킬은 지속 시간 동안 여러 번 뿜는다.
##
## **서브기체가 없으면 본체가 대신 쏜다** — 파워 0 이면 대부분 기체가 서브기체가 없어서,
## 안 그러면 P 를 아직 못 먹은 판에서 버튼이 고장 난 것처럼 보인다.
func _skill_tick() -> void:
	var want := int((D.SKILL_DUR - skill_t) / 0.1)
	if want <= skill_seq:
		return
	skill_seq = want
	var src: Array[Vector2] = []
	for o in opts:
		src.append(o.pos)
	if src.is_empty():
		src.append(pos + Vector2(0, -12))
	var c := craft_col()
	var n0 := pb.size()
	match craft:
		0:
			# 관통 창 — 굵고 긴 관통 한 줄기씩
			for p in src:
				_beam(p + Vector2(0, -10), 17.0, true, 10)
		1:
			# **황금 밧줄** — 기둥과 따로 뻗는다. 기둥과 달리 **막히지 않고** 띠 안의 것을
			# 한 틱에 전부 때린다(그림은 `World.draw`).
			#
			# 기둥은 처음 닿는 하나만 때리므로, 줄 서 있는 것을 한 번에 쓸어 주는 것이
			# 이 스킬의 값어치다 — 채우는 동안 기둥이 가늘어지는 대가와 짝을 이룬다.
			#
			# **뻗은 만큼만 때린다**(`rope_top`). 그림은 자라는데 판정이 처음부터 끝까지
			# 걸려 있으면, 아직 닿지도 않은 것이 죽는다.
			var rr: float = D.COIL_R + 10.0
			var rtop: float = rope_top()
			for f in foes:
				# 닿는 데까지만 때린다. 막은 놈 자신은 **앞쪽 가장자리**가 끝에 닿아 있으므로
				# 중심이 아니라 가장자리로 재야 그놈이 빠지지 않는다.
				if f.dead or f.pos.y > pos.y or f.pos.y + f.r < rtop:
					continue
				if absf(f.pos.x - pos.x) < rr + f.r:
					booms.append({pos = f.pos, p = 0.0, s = 11.0, k = "hit", c = P.GOLD})
					_hurt(f, D.ROPE_DMG[power])
			if not boss.is_empty() and boss.y_in and not boss.morphing:
				var in_band: bool = absf(boss.pos.x - pos.x) < rr + boss.r.x
				# **막은 놈 자신이 빠지지 않게 `>=` 다.** 끝은 그놈 앞쪽 가장자리에 정확히 걸리므로
				# `>` 로 두면 밧줄이 멈춰 세운 상대를 안 때린다(실제로 화력이 18%% 날아갔다).
				if in_band and boss.pos.y + boss.r.y >= rtop:
					boss.hp -= D.ROPE_DMG[power]
					booms.append({pos = Vector2(pos.x, boss.pos.y + boss.r.y), p = 0.0,
							s = 12.0, k = "hit", c = P.GOLD})
					_award(40)
		2:
			# 집속 화염 — 한가운데 굵은 기둥 하나
			_beam(pos + Vector2(0, -14), 44.0, true, 30)
		3:
			# 미사일 폭우
			for j in 3:
				var side := -1.0 if j % 2 == 0 else 1.0
				var b := _fan(pos + Vector2(side * 12.0, -6.0), side * 0.13,
						D.MSL_SPD * 1.15, "missile", c)
				b.k = "h"
				b.dmg = D.MSL_DMG * 3
				b.life = D.MSL_LIFE
		4:
			# 분열 편대 — 늘어난 서브기체가 통째로 일제 사격 (대수는 _step_opts 가 늘린다)
			for p in src:
				var b := _bul(p + Vector2(0, -8), Vector2(0, -540), "spark", c)
				b.dmg = 6
		6:
			# 일제 발사 — 부채꼴로 쏟아낸다. 이것도 처졌다가 붙으므로 한 박자 늦게 날아간다.
			for j in 5:
				var o6: float = j - 2.0
				var b6 := _bul(pos + Vector2(o6 * 13.0, 8.0),
						Vector2(o6 * 130.0, 120.0), "missile", c)
				b6.dmg = 5
				b6.grav = D.MSL_GRAV
				b6.life = 2.4
		_:
			# 공명 파동 — 큰 고리를 동시에
			for p in src:
				var b := _bul(p + Vector2(0, -10), Vector2(0, -330), "wave", c)
				b.k = "w"
				b.wd = 40.0
				b.grow = 96.0
				b.dmg = 8
				b.pierce = true
	# 스킬 탄도 기체 생김새를 따른다 — 커세어의 「집속 화염」이 레이저로 보이면 안 된다.
	# `spark`·`missile` 은 그림이 따로 있어서 이 값이 안 쓰인다.
	var vk: String = VFX[craft]
	for i in range(n0, pb.size()):
		pb[i].vfx = vk


## 연쇄가 다음에 튈 곳. **이미 때린 적은 건너뛴다** — 안 그러면 두 마리 사이를
## 오가며 무한히 튄다. 보스는 아예 안 본다(연쇄는 무리에만 듣는다).
func _nearest_foe_new(from: Vector2, skip: PackedInt32Array) -> Vector2:
	var best := Vector2.INF
	var bd := 250000.0     # 500px 밖으로는 안 튄다. 화면 반대편까지 날아가면 연쇄로 안 읽힌다.
	for f in foes:
		if f.dead or skip.has(f.id):
			continue
		var d: float = from.distance_squared_to(f.pos)
		if d < bd:
			bd = d
			best = f.pos
	return best


func _nearest_foe(from: Vector2) -> Vector2:
	var best := Vector2.INF
	var bd := 1e18
	for f in foes:
		if f.dead:
			continue
		var d: float = from.distance_squared_to(f.pos)
		if d < bd:
			bd = d
			best = f.pos
	if not boss.is_empty() and boss.y_in and bd > 90000.0:
		return boss.pos
	return best


func fire_bomb() -> void:
	if not bomb.is_empty() or bombs <= 0 or st != St.PLAY:
		return
	bombs -= 1
	bomb = {p = 0.0, dur = D.CRAFT[craft].bomb_dur, org = pos}
	shake = 1.0


func _step_bomb(dt: float) -> void:
	if bomb.is_empty():
		return
	bomb.p += dt / bomb.dur
	# **봄은 화면을 실제로 지운다.** 조금씩 갉는 정도면 위급할 때 눌러도 못 살아남아서
	# 있으나 마나가 된다. 잡졸은 한 번에 쓸고, 보스에게도 한 입 분량이 들어간다.
	if bomb.p < D.BOMB_CLEAR:
		eb.clear()
		for f in foes:
			if not f.dead:
				_hurt(f, D.BOMB_DPS * dt)
		if not boss.is_empty() and boss.y_in and not boss.morphing:
			boss.hp -= D.BOMB_BOSS_DPS * dt
	if bomb.p >= 1.0:
		bomb = {}

# ==================== 적 ====================

func _spawn_wave(spec: Dictionary) -> void:
	var n: int = spec.n
	var gap: float = spec.gap
	var kind: String = spec.k
	match spec.kind:
		"line":
			for i in n:
				var off: float = (i - (n - 1) * 0.5) * gap
				_add_foe(kind, Vector2(w * 0.5 + off, -30.0 - absf(off) * 0.5), i * 0.7)
		"pair":
			for i in n:
				var x: float = w * (i + 1.0) / (n + 1.0)
				_add_foe(kind, Vector2(x, -70.0 - i * gap * 0.3), i)
		"dive":
			for i in n:
				var x: float = 44.0 + i * (w - 88.0) / maxf(1.0, n - 1.0)
				_add_foe(kind, Vector2(x, -40.0 - i * 40.0), i)
		"arc":
			# 옆에서 들어와 화면을 **가로로 가로지른다.** 다른 적은 전부 위에서 내려오므로
			# 이것만 세로 회피로는 안 풀린다.
			for i in n:
				var side := 1.0 if i % 2 == 0 else -1.0
				var f := _add_foe(kind, Vector2(w * 0.5 - side * (w * 0.5 + 34.0),
						54.0 + i * gap * 0.42), i * 0.7)
				f.dirx = side
		"spot":
			# 지형에 붙어 흘러오는 것들 — 자리를 흩어 놓아야 한 줄로 안 보인다
			for i in n:
				var x: float = clampf(w * (i + 1.0) / (n + 1.0)
							+ rng.randf_range(-0.22, 0.22) * gap, 26.0, w - 26.0)
				_add_foe(kind, Vector2(x, -46.0 - i * gap * 0.55), i)


func _add_foe(kind: String, p: Vector2, ph: float) -> Dictionary:
	var e: Dictionary = D.ENEMY[kind]
	var tier: float = D.ROUND[round_i].tier
	var hold: float = h * 0.26 + fposmod(ph, 3.0) * 20.0
	foe_seq += 1
	var f := {kind = kind, art = e.art, pos = p, hp = e.hp * dm().hp * tier, id = foe_seq,
		r = e.r, ph = ph, sz = e.sz, move = e.move, aim = PI * 0.5, dirx = 0.0, hold = hold,
		cd = e.fire * (0.6 + ph * 0.25), spd = e.speed, dead = false}
	foes.append(f)
	return f


func _step_foes(dt: float) -> void:
	for f in foes:
		if f.dead:
			continue
		# **나는 방식은 종류 번호가 아니라 move 로 가른다.**
		match f.move:
			"wave":
				f.pos.y += f.spd * dt
				f.pos.x += sin(t * 1.7 + f.ph) * 52.0 * dt
			"swoop":
				f.pos.y += f.spd * dt
				f.pos.x += sin(t * 3.0 + f.ph) * 30.0 * dt
			"ground":
				# 지형과 같은 속도로 흘러간다. 스스로 못 움직이는 대신 **포신이 겨눈다.**
				f.pos.y += D.SCROLL * dt
				f.aim = (pos - f.pos).angle()
			"arc":
				f.pos.x += f.dirx * f.spd * dt
				f.pos.y += (f.spd * 0.26 + sin(t * 1.4 + f.ph) * 42.0) * dt
			"hover":
				# 내려와 자리를 잡고 버틴다 — 지나가 주지 않으니 쳐내야 한다
				if f.pos.y < f.hold:
					f.pos.y += f.spd * dt
				else:
					f.pos.x += sin(t * 0.8 + f.ph) * 64.0 * dt
			_:
				f.pos.y += f.spd * dt
		var reach: float = 0.82 if f.move == "ground" else 0.62
		if f.cd > 0.0 and bomb.is_empty():
			f.cd -= dt
			if f.cd <= 0.0 and f.pos.y > 10.0 and f.pos.y < h * reach:
				f.cd = D.ENEMY[f.kind].fire
				if f.art == "gunship":
					# 고리 탄 — 붙어 있으면 빠져나갈 곳이 없다
					_ring_shot(f.pos, 8, t * 0.6 + f.ph, 96.0, f.sz)
				else:
					var n := 3 if f.art == "bomber" else 1
					_aim_shot(f.pos, n, 0.28, f.sz)
		if f.pos.y > h + 60.0 or (f.move == "arc" and (f.pos.x < -70.0 or f.pos.x > w + 70.0)):
			f.dead = true


func _eb(from: Vector2, ang: float, spd: float, sz: int) -> void:
	var k: float = D.EB[sz].spd * dm().spd
	eb.append({pos = from, vel = Vector2(cos(ang), sin(ang)) * spd * k, sz = sz})


func _aim_shot(from: Vector2, n: int, spread: float, sz: int = 1) -> void:
	var cnt := maxi(1, int(round(n * dm().dense)))
	var a := (pos - from).angle()
	for i in cnt:
		_eb(from, a + (i - (cnt - 1) * 0.5) * spread, D.E_BULLET_SPD, sz)


func _ring_shot(from: Vector2, n: int, rot: float, spd: float, sz: int = 1) -> void:
	var cnt := maxi(3, int(round(n * dm().dense)))
	for i in cnt:
		_eb(from, i * TAU / cnt + rot, spd, sz)

# ==================== 보스 ====================

func _spawn_boss(key: String, mid: bool) -> void:
	var sc := 1.0
	var r: Vector2 = D.MIDBOSS.r
	var hp: float = D.MIDBOSS.hp
	var nm := "초중폭격기"
	if not mid:
		var b: Dictionary = D.BOSS[key]
		sc = b.scale
		r = b.r * sc
		hp = b.hp
		nm = b.name
	hp *= dm().hp
	boss = {key = key, mid = mid, scale = sc, r = r, name = nm,
		pos = Vector2(w * 0.5, -r.y * 1.3), hp = hp, max = hp,
		hover = 30.0 + r.y, cd = 1.4, sw = 0, y_in = false, rage = false, born = t,
		t0 = t, shown = hp, morph = 0.0, morphing = false, pdead = 0}


## 보스마다 다른 탄막. **얼굴만 바꾸면 다 같은 보스다** — 피하는 방법이 달라야 한다.
## 보스마다 다르게 움직인다. **여섯이 같은 궤적으로 흔들리면 얼굴만 바꾼 것과 같다.**
## 돌아온 값은 화면 한가운데(hover) 기준 오프셋이다.
## 부위 하나의 자리. **그리기와 판정이 같은 함수를 본다** — 도는 방출구처럼 자리가
## 시간에 따라 바뀌는 것은 여기서 한 번만 계산하고 [Art] 에도 같은 규칙을 적어 둔다.
func _part_pos(i: int) -> Vector2:
	var b: Dictionary = D.BOSS[boss.key]
	if boss.key == "disc":
		var a: float = (t - boss.t0) * 0.55 + i * TAU / 6.0
		return boss.pos + Vector2(sin(a), -cos(a)) * boss.r.x * 0.85
	var off: Vector2 = b.parts[i]
	return boss.pos + off * boss.scale


## 체력이 깎이면 부위가 하나씩 떨어져 나간다. **부순 만큼 탄막이 실제로 줄어든다** —
## 그림만 사라지면 부순 보람이 없고, 어디부터 칠지를 고를 이유도 없어진다.
func _step_parts() -> void:
	var pn: int = D.BOSS[boss.key].parts.size()
	var frac: float = boss.hp / boss.max
	var want := 0
	for i in pn:
		if frac <= 1.0 - float(i + 1) / (pn + 1):
			want = i + 1
	while boss.pdead < want:
		var pp := _part_pos(boss.pdead)
		for k in 6:
			booms.append({pos = pp + Vector2(rng.randf_range(-16.0, 16.0),
				rng.randf_range(-16.0, 16.0)), p = -rng.randf() * 0.35,
				s = 22.0 + rng.randf() * 16.0})
		boss.pdead += 1
		shake = maxf(shake, 0.7)
		_award(D.PART_SCORE)


func _boss_move(age: float, span: float) -> Vector2:
	if boss.mid:
		return Vector2(sin(age * 0.5) * span, 0)
	match boss.key:
		"battleship":
			return Vector2(sin(age * 0.5) * span, 0)
		"landfort":
			# 무거운 놈이라 양끝에서 **머문다** — 밀고 들어갈 틈이 생긴다
			# 궤도를 부순 만큼 못 움직이고, 둘 다 부수면 아예 선다
			var k: float = (2.0 - boss.pdead) * 0.5
			return Vector2(clampf(sin(age * 0.5) * 1.9, -1.0, 1.0) * span * k, 0)
		"carrier":
			return Vector2(sin(age * 0.32) * span, sin(age * 0.8) * 11.0)
		"disc":
			# 원을 그리며 돈다 — 좌우만 보고 있으면 위아래로 파고든다
			return Vector2(sin(age * 0.7) * span, cos(age * 0.7) * 30.0)
		"robot":
			if boss.morph < 0.5:
				return Vector2(sin(age * 1.05) * span, sin(age * 2.1) * 14.0)
			return Vector2(sin(age * 0.38) * span * 0.8, 0)
		_:
			# 최종 요새는 거의 안 움직인다. 피할 곳은 좌우 끝뿐.
			return Vector2(sin(age * 0.22) * span * 0.42, sin(age * 0.6) * 8.0)


func _boss_fire(add: int) -> void:
	var live: int = 0 if boss.mid else D.BOSS[boss.key].parts.size() - boss.pdead
	var muzzle: Vector2 = boss.pos + Vector2(0, boss.r.y * 0.5)
	var wide: Vector2 = boss.pos + Vector2(boss.r.x * 0.7 * signf(sin(boss.sw * 1.7)), 0)
	if boss.mid:
		match boss.sw % 3:
			0: _ring_shot(muzzle, 12 + add * 2, boss.sw * 0.2, 118.0)
			1: _aim_shot(muzzle, 5 + add, 0.16)
			_: _aim_shot(wide, 3 + add, 0.13)
		return
	match boss.key:
		"battleship":
			# 주포 셋이 번갈아 — 넓게 조준하고, 셋째 발은 고리로 도망갈 곳을 지운다.
			match boss.sw % 3:
				0: _ring_shot(muzzle, 16 + add * 2, boss.sw * 0.2, 118.0)
				1: _aim_shot(muzzle, maxi(1, (7 + add) * live / 3), 0.16)
				_:
					_aim_shot(wide, maxi(1, (5 + add) * live / 3), 0.13)
					if boss.rage:
							_ring_shot(boss.pos, 10, -boss.sw * 0.3, 92.0)
		"landfort":
			# 무거운 놈이라 느리게, 대신 **벽처럼** 온다. 틈으로 빠져나가는 싸움.
			if boss.sw % 3 == 0:
				var gap := rng.randi_range(1, 7)
				for i in 9:
					if absi(i - gap) <= (0 if boss.rage else 1):
							continue
					_eb(Vector2(w * (i + 0.5) / 9.0, boss.pos.y), PI * 0.5, 132.0, 2)
			else:
				_aim_shot(muzzle, 5 + add, 0.2)
				_aim_shot(boss.pos + Vector2(-boss.r.x * 0.6, 20), 3, 0.26)
				_aim_shot(boss.pos + Vector2(boss.r.x * 0.6, 20), 3, 0.26)
		"carrier":
			# 발진구에서 잡졸기가 계속 나온다. 본체만 때리면 끝이 안 난다.
			if boss.sw % 2 == 0:
				for i in mini(live, 3 if boss.rage else 2):
					var bx: float = boss.pos.x + (i - 1) * 58.0
					_add_foe("grunt", Vector2(clampf(bx, 20.0, w - 20.0), boss.pos.y + 30.0), i)
			else:
				_aim_shot(muzzle, 5 + add, 0.15)
				_ring_shot(boss.pos, 8 + add, boss.sw * 0.4, 88.0)
		"disc":
			# 방출구 여섯이 고리를 따라 돈다 — **안전한 자리가 계속 옮겨 간다.**
			var spin: float = (t - boss.t0) * 0.55
			for i in range(boss.pdead, 6):
				var a: float = spin + i * TAU / 6.0
				var em: Vector2 = boss.pos + Vector2(sin(a), -cos(a)) * boss.r.x * 0.85
				var dir: Vector2 = (em - boss.pos).normalized()
				for k in (3 if boss.rage else 2):
					var aa: float = dir.angle() + (k - 0.5) * 0.16
					_eb(em, aa, 124.0, 0)
			if boss.sw % 3 == 0:
				_aim_shot(boss.pos, 5 + add, 0.14)
		"robot":
			if boss.morph < 0.5:
				# 비행 형태 — 앞으로 몰아친다
				_aim_shot(muzzle, 7 + add, 0.13)
				if boss.sw % 3 == 0:
					_ring_shot(boss.pos, 14 + add, boss.sw * 0.25, 104.0)
			else:
				# 로봇 형태 — **양팔이 좌우로 훑는다.** 가운데가 아니라 옆이 위험하다.
				for ai in range(boss.pdead, 2):
					var s := -1.0 if ai == 0 else 1.0
					var hand: Vector2 = boss.pos + Vector2(s * boss.r.x * 0.75, boss.r.y * 0.45)
					var base: float = PI * 0.5 + s * sin(t * 1.6) * 0.5
					for k in 4 + add:
							var aa: float = base + (k - (3 + add) * 0.5) * 0.17
							_eb(hand, aa, 146.0, 0)
				if boss.sw % 4 == 0:
					_aim_shot(muzzle, 5 + add, 0.18)
		_:
			# 최종 요새 — 포탑 다섯이 동시에. 피할 곳이 좌우 끝밖에 없다.
			match boss.sw % 3:
				0:
					_ring_shot(boss.pos, 20 + add * 2, boss.sw * 0.18, 108.0)
					_ring_shot(boss.pos, 14 + add, -boss.sw * 0.24, 76.0)
				1:
					for q in [-0.62, -0.3, 0.0, 0.3, 0.62].slice(0, maxi(1, live + 1)):
							_aim_shot(boss.pos + Vector2(q * boss.r.x * 1.5, boss.r.y * 0.4), 2 + add, 0.2)
				_:
					_aim_shot(muzzle, 9 + add, 0.11)
					if boss.rage:
							_ring_shot(muzzle, 12, boss.sw * 0.5, 132.0)


func _step_boss(dt: float) -> void:
	if boss.is_empty():
		return
	if boss.pos.y < boss.hover:
		boss.pos.y += 46.0 * dt
	else:
		if not boss.y_in:
			boss.y_in = true
			boss.t0 = t
		# **좌우 흔들림은 들어온 시점부터 센다.** 전역 시간을 그대로 sin 에 넣으면
		# 보스가 내려앉는 순간 사인값이 아무 데나 있어서 옆으로 순간이동한다.
		# 폭도 1.6초에 걸쳐 벌려야 자리를 잡고 흔들리기 시작하는 것으로 읽힌다.
		var age: float = t - boss.t0
		var span := maxf(0.0, w * 0.5 - boss.r.x - 10.0)
		boss.pos = Vector2(w * 0.5, boss.hover) + _boss_move(age, span) * minf(1.0, age / 1.6)
		if bomb.is_empty():
			boss.cd -= dt
	# 체력 막대가 **한 칸씩 깎이는 게 보이게** 뒤따라오는 잔상 값.
	boss.shown = maxf(boss.hp, boss.shown - maxf(boss.max * 0.12,
			(boss.shown - boss.hp) * 2.6) * dt)
	# **끝까지 같은 속도로 때리면 지루하다.** 절반을 깎으면 2페이즈로 넘어가
	# 발사 간격이 줄고 탄이 는다 — 마지막 구간이 제일 위험해야 한다.
	boss.rage = boss.hp <= boss.max * 0.5
	if not boss.mid:
		_step_parts()
		match boss.key:
			"robot":
				# 절반에서 인간형으로 펴진다. **변신 중에는 무적이고 공격도 안 한다** —
				# 그 몇 초가 회피 자세를 다시 잡는 시간이다.
				boss.morph = move_toward(boss.morph, 1.0 if boss.rage else 0.0, dt * 0.5)
				boss.morphing = boss.morph > 0.02 and boss.morph < 0.98
			"fortress":
				# 깎일수록 가운데 차폐가 열린다
				boss.morph = clampf((1.0 - boss.hp / boss.max) / 0.6, 0.0, 1.0)
	if boss.morphing:
		return
	if boss.cd <= 0.0:
		var base: float = 0.85 if boss.mid else 0.95
		boss.cd = D.BOSS_RAGE_CD if boss.rage else base
		boss.sw += 1
		var add: int = D.BOSS_RAGE_ADD if boss.rage else 0
		_boss_fire(add)
	if boss.hp <= 0.0:
		for i in 18:
			booms.append({pos = boss.pos + Vector2(rng.randf_range(-1.0, 1.0) * boss.r.x * 1.6,
				rng.randf_range(-1.0, 1.0) * boss.r.y * 1.2),
				p = -rng.randf() * 0.5, s = 30.0 + rng.randf() * 26.0})
		if god:
			# soak 테스트용 실측. "보스 체력은 초로 정한다" 가 지켜지는지 여기서 확인한다.
			print("[boss] %s  %.1f초  (설계 %.0f초)" % [boss.name, t - boss.born,
					D.MIDBOSS.secs if boss.mid else D.BOSS[boss.key].secs])
		items.append({pos = boss.pos, kind = "power"})
		_award(D.MIDBOSS.score if boss.mid else D.BOSS[boss.key].score)
		shake = 1.0
		boss = {}

# ==================== 탄 · 아이템 ====================

func _step_bullets(dt: float) -> void:
	for b in pb:
		if b.life > 0.0:
			# 미사일은 수명이 있다. 없으면 표적을 놓친 유도탄이 화면을 계속 맴돈다.
			b.life -= dt
			if b.life <= 0.0:
				b.dead = true
				booms.append({pos = b.pos, p = 0.0, s = 13.0, k = "hit", c = b.col})
				continue
		if b.k == "w":
			# 상한이 없으면 고리가 화면을 덮어 절대 안 빗나간다.
			b.wd = minf(b.wd + b.grow * dt, 92.0)
		elif b.k == "h":
			# **표적 찾기를 매 프레임 하지 않는다.** `_nearest_foe` 는 적 전수 비교라,
			# 미사일 40발 × 적 60마리면 프레임당 2,400번을 GDScript 로 돌게 된다 —
			# 스핏파이어 만렙 · 6라운드 물량에서 실제로 **CPU 9.9ms/프레임**이 나왔다
			# (다른 기체는 3.1ms). 그리기가 아니라 여기가 범인이었다.
			#
			# 0.1초마다, 그것도 발마다 어긋나게 다시 찾는다. 그 사이 표적이 움직여야
			# 30px 이고, 유도탄에는 그 정도 굼뜸이 오히려 자연스럽다.
			b.tcd -= dt
			if b.tcd <= 0.0:
				b.tcd = 0.09 + rng.randf() * 0.05
				b.tgt = _nearest_foe(b.pos)
			if b.tgt.x < 1e17:
				var tn: float = D.MSL_TURN
				var sp2: float = D.MSL_SPD
				var cur: float = b.vel.angle()
				cur += clampf(wrapf((b.tgt - b.pos).angle() - cur, -PI, PI),
						-tn * dt, tn * dt)
				b.vel = Vector2(cos(cur), sin(cur)) * sp2
		b.age += dt
		if b.grav != 0.0:
			# **처졌다가 추진.** 아래로 나간 속도를 위쪽 가속이 뒤집는다 — 궤적이 한 번
			# 꺾이므로, 발사 직후에는 기체 아래에 머물다가 뒤늦게 앞질러 간다.
			b.vel.y = maxf(b.vel.y - b.grav * dt, -D.MSL_BOOST)
		if b.accel > 0.0:
			# **지연 가속** — 느리게 나가다 확 빨라진다. 궤적은 직선인데 리듬이 바뀌어서,
			# "집중"이 축인 기체의 성격을 안 흔들면서 손맛만 달라진다.
			var sp: float = b.vel.length()
			if sp < D.ACCEL_MAX:
				b.vel = b.vel.normalized() * minf(D.ACCEL_MAX, sp + b.accel * dt)
		elif b.spin != 0.0:
			# **나선** — 앞으로 가면서 좌우로 감긴다. 각도 확산 없이 훑는 폭이 생긴다.
			#
			# 옆으로 미는 양은 **사인의 미분**(cos)이다. 위치를 매번 다시 계산하지 않고
			# 더해 가므로 기준 축을 따로 들고 다닐 필요가 없고, 유도나 가속이 방향을
			# 바꿔도 궤적이 안 튄다.
			b.pos.x += b.spin * D.SPIN_W * cos(b.age * D.SPIN_W) * dt
		b.pos += b.vel * dt
	pb = _keep(pb, func(b): return not b.dead and b.pos.y > -30.0 and b.pos.x > -50.0 and b.pos.x < w + 50.0)
	for b in eb:
		b.pos += b.vel * dt
	eb = _keep(eb, func(b): return b.pos.y < h + 24.0 and b.pos.y > -60.0 and b.pos.x > -40.0 and b.pos.x < w + 40.0)
	if eb.size() > 260:
		eb = _tail(eb, 260)


func _step_items(dt: float) -> void:
	for it in items:
		var d: Vector2 = pos - it.pos
		if d.length() < D.ITEM_MAGNET and st == St.PLAY:
			it.pos += d.normalized() * 190.0 * dt
		else:
			it.pos.y += D.ITEM_FALL * dt
	var keep: Array[Dictionary] = []
	for it in items:
		if st == St.PLAY and pos.distance_to(it.pos) < 15.0:
			if it.kind == "bomb":
				if bombs >= D.BOMBS_MAX:
					_award(D.BOMB_FULL_SCORE)
				else:
					bombs += 1
					_award(800)
			elif power >= D.POWER_MAX:
				_award(D.POWER_FULL_SCORE)
			else:
				power += 1
				_award(500)
			continue
		if it.pos.y < h + 30.0:
			keep.append(it)
	items = keep

# ==================== 판정 ====================

func _collide() -> void:
	for b in pb:
		if b.dead:
			continue
		var br := 5.0
		if b.st == "beam":
			br = 6.0 + b.wd * 0.5
		elif b.st == "wave":
			br = b.wd * 0.5
		for f in foes:
			if f.dead:
				continue
			if absf(b.pos.x - f.pos.x) < f.r + br and absf(b.pos.y - f.pos.y) < f.r + br:
				if b.pierce:
					# **한 표적은 한 번만.** 뚫고 지나가되 같은 적을 다시 때리지 않는다.
					# 대신 겹친 적은 **한 프레임에 전부** 때린다 — 관통의 값어치는
					# 여기(여러 마리)에 있지 한 마리를 오래 지지는 데 있지 않다.
					if b.hit.has(f.id):
						continue
					b.hit.append(f.id)
				elif b.chain > 0:
					# **연쇄** — 죽지 않고 다음 적으로 튄다. 확산을 각도가 아니라 연쇄로
					# 내는 것이라, 좁은 표적에서 옆으로 새는 손실이 아예 없다.
					#
					# **보스에게는 튀지 않는다**(아래 보스 판정은 그냥 사라진다).
					# 표적이 하나뿐인 싸움에서 연쇄가 값을 내면 그게 곧 보스 화력이
					# 되어, 지금 맞춰 둔 "보스는 몇 초" 가 기체마다 달라진다.
					# 연쇄는 **무리에만** 듣는 것이 이 기체의 값어치다.
					if b.hit.has(f.id):
						continue
					b.hit.append(f.id)
					b.chain -= 1
					var nx := _nearest_foe_new(b.pos, b.hit)
					if nx.x < 1e17:
						b.vel = (nx - b.pos).normalized() * b.vel.length()
					else:
						b.dead = true
				else:
					b.dead = true
				booms.append({pos = b.pos, p = 0.0, s = 9.0, k = "hit", c = b.col})
				_hurt(f, b.dmg)
				if not b.pierce:
					break     # 연쇄탄은 방향만 틀고 다음 프레임에 다음 적을 때린다
		if b.dead or boss.is_empty() or not boss.y_in:
			continue
		if boss.morphing:
			continue
		if absf(b.pos.x - boss.pos.x) < boss.r.x + br and absf(b.pos.y - boss.pos.y) < boss.r.y + br:
			if b.pierce:
				if b.hitb:
					continue
				b.hitb = true
			else:
				b.dead = true
			boss.hp -= b.dmg
			booms.append({pos = b.pos, p = 0.0, s = 10.0, k = "hit", c = b.col})
			_award(40)

	if st != St.PLAY or invuln > 0.0:
		return
	var hit: float = D.CRAFT[craft].hit
	for b in eb:
		if b.pos.distance_to(pos) < hit + D.EB[b.sz].r:
			_die()
			return
	for f in foes:
		if not f.dead and f.pos.distance_to(pos) < hit + f.r * 0.62:
			_die()
			return
	if not boss.is_empty() and boss.y_in:
		if absf(pos.x - boss.pos.x) < boss.r.x * 0.8 and absf(pos.y - boss.pos.y) < boss.r.y * 0.8:
			_die()


func _hurt(f: Dictionary, dmg: float) -> void:
	f.hp -= dmg
	if f.hp > 0:
		return
	f.dead = true
	booms.append({pos = f.pos, p = 0.0, s = 34.0 if f.art == "bomber" else 20.0})
	_award(D.ENEMY[f.kind].score)
	# **한 마리는 많아야 아이템 하나를 떨군다.** 종류마다 따로 뽑으면 드물게 둘이 겹쳐서
	# 화면에서 무엇을 주웠는지 읽을 수가 없다.
	# **한 마리는 많아야 아이템 하나를 떨군다.** 종류마다 따로 뽑으면 드물게 둘이 겹쳐서
	# 화면에서 무엇을 주웠는지 읽을 수가 없다. P 가 먼저고, 없을 때만 봄을 굴린다.
	if power_due > 0:
		power_due -= 1
		items.append({pos = f.pos, kind = "power"})
	elif rng.randf() < D.BOMB_CHANCE:
		items.append({pos = f.pos, kind = "bomb"})


func _die() -> void:
	if god:
		invuln = 1.0
		return
	st = St.DEAD
	respawn = 1.4
	lives -= 1
	shake = 1.0
	for i in 10:
		booms.append({pos = pos + Vector2(rng.randf_range(-18.0, 18.0),
			rng.randf_range(-18.0, 18.0)), p = -rng.randf() * 0.3, s = 26.0})
	eb.clear()
	bomb = {}


func _award(n: int) -> void:
	score += n
	if score >= next_extend:
		next_extend += D.EXTEND_AT
		lives += 1


## 조건에 맞는 것만 남긴다. Array.filter 는 타입 없는 Array 를 돌려주므로
## Array[Dictionary] 에 그대로 담을 수 없다.
func _keep(src: Array[Dictionary], ok: Callable) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it in src:
		if ok.call(it):
			out.append(it)
	return out


func _tail(src: Array[Dictionary], n: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(maxi(0, src.size() - n), src.size()):
		out.append(src[i])
	return out


func _sweep() -> void:
	foes = _keep(foes, func(f): return not f.dead)

# ==================== 그리기 ====================

func draw(ci: CanvasItem) -> void:
	Art.terrain(ci, land(), w, h, scroll, t)
	for it in items:
		if it.kind == "bomb":
			Art.item_bomb(ci, it.pos, t)
		else:
			Art.item_power(ci, it.pos, t)
	for f in foes:
		if f.dead:
			continue
		if f.move == "ground":
			Art.ground_unit(ci, f.art, f.pos, f.aim, t, D.ROUND[round_i].base)
		else:
			Art.enemy(ci, f.art, f.pos, t + f.ph)
	if not boss.is_empty():
		Art.draw_shape(ci, boss.key, boss.pos, t, boss.scale, boss.morph, boss.pdead)
	if st == St.PLAY or st == St.CLEAR:
		# 무적 동안은 깜빡인다. 0 까지 내리면 사라진 것처럼 보이니 반만 지운다.
		var vis := invuln <= 0.0 or fmod(invuln * 12.0, 1.0) > 0.4
		if vis:
			G2.glow(ci, pos + Vector2(0, 20), 16.0, craft_col(),
					0.3 + 0.12 * sin(t * 22.0))
			Art.craft(ci, craft, pos, t)
			for o in opts:
				Art.craft(ci, craft, o.pos, t, 0.56)
			# 총구 섬광. 사격이 자동이라 **쏘고 있다는 것 자체가** 화면에서 안 읽히면
			# 손에 든 것이 장식처럼 보인다. 기체와 서브기체 모두에 얹는다.
			if flash > 0.0:
				Art.muzzle(ci, craft, pos, opts, flash, craft_col())
			# **채우는 중인 것은 기체에도 보여야 한다.** 옆 패널 막대만으로는 탄을 보는
			# 동안 눈이 못 간다 — 세로 슈팅에서 시선은 계속 기체 언저리에 있다.
			if charge > 0.0:
				Art.charge_ring(ci, pos, opts, charge_frac(), craft_col(), t)
		if skill_t > 0.0:
			# 라이트닝 스킬은 **황금 밧줄** — 기둥과 따로 화면 끝까지 뻗는다.
			if craft == 1:
				Art.coil(ci, pos.x, pos.y - 14.0, rope_top(), P.GOLD, t)
			else:
				Art.skill_burst(ci, craft, pos, opts, 1.0 - skill_t / D.SKILL_DUR,
						craft_col(), t)
		# 판정점. 그림보다 훨씬 작은 실제 피격 범위 — 없으면 억울하게 죽는다.
		var hit: float = D.CRAFT[craft].hit
		if focus:
			G2.glow(ci, pos, 14.0, Color(1, 1, 1), 0.5)
			ci.draw_arc(pos, hit + 3.0, 0.0, TAU, 16, P.a(P.WHITE, 0.7), 1.2, true)
		ci.draw_circle(pos, hit * 0.7, Color(1, 1, 1))
	# 기둥은 탄보다 아래에 그린다 — 굵어서 위에 있으면 다른 것을 다 덮는다.
	if bolt.size() > 1 and (st == St.PLAY or st == St.CLEAR):
		Art.bolt_beam(ci, bolt, pos + Vector2(0, -14.0), bolt_top, bolt_w,
				opts, craft_col(), t)
	for b in pb:
		Art.bullet_ally(ci, b)
	for b in eb:
		Art.bullet_foe(ci, b.pos, t, b.sz, b.vel)
	for b in booms:
		if b.p >= 0.0:
			Art.boom(ci, b.pos, b.p, b.s, b.get("k", "kill"), b.get("c", P.GOLD))
	if not bomb.is_empty():
		Art.bomb(ci, craft, bomb.p, bomb.org, w, h)
