extends Node2D

## 게임 루프 · 입력 · 카메라 · 상태 기계. 그리기도 여기서 한 번에 한다.
##
## 적이 수백이라 노드를 만들지 않는다. `_draw()` 한 곳에서 카메라 변환을 걸고
## 월드를 그린 뒤, 변환을 풀고 HUD 를 그린다.
##
## 한 판(run)은 **라운드**의 연속이다.
## TITLE → CHARSEL(캐릭터 고르기) → PLAY → (버티면) CLEAR(코인 상점) → PLAY → …
## 죽으면 OVER 로 가고 다음 판은 다시 1라운드부터. 코인과 상점 강화만 [NvSv] 에 남는다.

## `CHEST` 는 보물상자를 연 결과를 보여 주는 화면이고, `ARCANA` 는 판 중간에 규칙 카드를
## 고르는 화면이다. 둘 다 `PLAY` 를 멈춘다 — 상자는 보여 주기만 하고, 아르카나는 고른다.
enum St { TITLE, CHARSEL, PLAY, LEVELUP, ARCANA, CHEST, PAUSED, SWEEP, CLEAR, OVER }

var st := St.TITLE
## 확인용 실행(미니게임 모음 추가분, 11-09) — --neon-auto: 봇이 1라운드를 끝까지(피하며 젬 줍기, 카드는 무작위) 두고 결과를 찍고 끝낸다.
## --shot=파일 --shot-at=초: 캡처. 명령줄 인자가 있으면 기록하지 않는다(ADR-0009).
var neon_auto := false
var shot_path := ""
var shot_at := 0.0
var _auto_t := 0.0
## 처음 화면의 도감 · 순위 창(공통 UiBook — ADR-0008, 재정비 8-1)
var book := UiBook.new()
const NEON_AUTO_SPEED := 10.0
var g: NvGame
var w: NvWorld
var fx := NvFx.new()

var t := 0.0
var cam := Vector2.ZERO
var cards: Array = []
var card_sel := 0
var card_anim := 0.0
var over_t := 0.0
## 보물상자를 열어 나온 줄들과 그 화면의 경과 시간
var chest_rows: Array = []
var chest_t := 0.0
## 아르카나 후보와 고르는 칸
var arc_cards: Array = []
var arc_sel := 0

## 캐릭터 선택창에서 지금 보고 있는 칸
var char_sel := 0
## 캐릭터 선택창에서 고른 시작 라운드. **이미 도달해 본 라운드까지만**(`NvSv.best_round`).
var start_round := 1
## 라운드 클리어 때 마지막으로 쓸어 담은 경험치 (클리어 화면에 보여 준다)
var clear_gems := 0
## 라운드 클리어 화면에서 지금 보고 있는 상점 칸 · 이번에 번 코인
var shop_sel := 0
var clear_coins := 0
var clear_t := 0.0
## 적을 얼마나 자세히 그릴지 (0 전부 · 1 몸통과 머리만 · 2 덩어리 두 개). `_pick_tier` 가 정한다.
var draw_tier := 0
var _tier_hold := 3.0
var _up_wait := 5.0
var _fps_cap := 1.0

## 화면 안 적이 이만큼을 넘으면 **0단계(팔다리까지)는 애초에 60fps 를 못 지킨다.**
## 마리당 약 25µs 인데(실측) 0단계는 마리당 그리기 호출이 7~8번이라, 170마리면 이미
## 4ms 로 예산을 다 쓴다. 프레임이 실제로 떨어지길 기다렸다 내리면 그 몇 초 동안 뚝뚝
## 끊기므로, 이 선을 넘으면 미리 1단계로 내려 둔다 —
## `_pick_tier` 는 그대로 두고 **바닥만 올리는** 것이라 등급이 더 내려가는 건 막지 않는다.
const TIER0_MAX_SHOWN := 170

## 월드를 이 배율로 그린다. 1보다 작으면 더 멀리서(위에서) 내려다보는 그림이 된다.
##
## `1 / 1.32` 는 화면에 담기는 월드가 가로세로 1.32배라는 뜻이다 — 1.10 이던 것을
## **20% 더 넓게** 잡았다. 맵도 같은 비율로 10% 키웠다.
##
## > **넓게 보면 세 가지가 같이 움직인다.**
## > ① 적이 나오는 거리(`NvD.SPAWN_MIN`) — 안 늘리면 화면 안에서 툭 튀어나온다.
## > ② 화면 안 적 수 — 넓이가 1.32² 배라 같은 밀도에서 74% 더 그린다.
## >   `_pick_tier` 가 프레임을 보고 알아서 등급을 내리지만, `TIER0_MAX_SHOWN` 에
## >   더 자주 걸린다는 뜻이다.
## > ③ 카메라 고정 범위(`_follow`) — 맵이 화면보다 작으면 잘라 봐야 소용이 없다.
##
## **월드 좌표로 그리는 곳은 전부 이 값을 알아야 한다.** 카메라 변환을 한 번 걸어 두지만
## `NvSpr.blit`·`NvSpr.limb_tex` 가 좌우 뒤집기·회전 때문에 `draw_set_transform` 으로 그 변환을
## **덮어쓰기** 때문이다 — 그래서 `NvSpr.zoom` 에도 같은 값을 넣어 준다.
## 화면에 담기는 월드 크기(`_world_view`)도 이 배율만큼 넓어지므로 카메라 고정 범위와
## 그리기 판정 범위를 그 값으로 잡아야 맵 밖이 비치거나 화면 끝 적이 사라지지 않는다.
const ZOOM := 1.0 / 1.32


func _ready() -> void:
	set_process(true)
	# 미니게임 모음 — 허브가 자식으로 연다. 음악은 이 게임의 합성기(NvSnd)가 맡으므로 허브 곡은 멈춘다.
	Bgm.use("neon")
	var snd := NvSnd.s()
	if not snd.is_inside_tree():
		Hub.host(self).add_child.call_deferred(snd)
	# 발광 — 원본 main.tscn 의 WorldEnvironment 를 코드로(스카이와 같은 방식, 허브가 닫을 때 hdr 을 되돌린다)
	get_viewport().use_hdr_2d = true
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_strength = 1.05
	env.glow_bloom = 0.12
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 0.95
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	NvSv.load_()
	NvSv.no_save = not OS.get_cmdline_user_args().is_empty()
	for a in OS.get_cmdline_user_args():
		if a == "--neon-auto":
			neon_auto = true
		elif a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--shot-at="):
			shot_at = float(a.substr(10))
	_new_run(0)
	st = St.TITLE
	start_round = clampi(NvSv.best_round, 1, NvD.MAX_ROUND)
	if neon_auto:
		Engine.time_scale = NEON_AUTO_SPEED   # 나갈 때 1 로 되돌린다(_auto_step)
		_begin_run.call_deferred()


func _new_run(character: int) -> void:
	g = NvGame.new(character, start_round)
	fx.clear()
	w = NvWorld.new(g, fx)
	cam = w.pos - _view_size() * 0.5
	cards.clear()
	card_anim = 0.0
	over_t = 0.0
	clear_coins = 0


func _view_size() -> Vector2:
	return get_viewport_rect().size

# ==================== 루프 ====================

func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	if st == St.PLAY and g != null and w != null:
		var boss := false
		for e: Dictionary in w.enemies:
			if e["boss"]:
				boss = true
				break
		NvSnd.s().tense = boss or NvD.round_time(g.round_no) - g.time < 60.0   # 상황 음악(11-09)
	if neon_auto:
		_auto_step(dt)
	if shot_path != "" and t >= shot_at and shot_at > 0.0:
		get_viewport().get_texture().get_image().save_png(shot_path)
		Hub.leave(self)
		return          # 창을 끌거나 멈췄다 돌아왔을 때 한 프레임에 몰아 도는 걸 막는다
	t += dt

	match st:
		St.TITLE, St.CHARSEL:
			pass
		St.PLAY:
			w.update(dt, _move_dir())
			fx.update(dt)
			_follow(dt)
			# **순서가 중요하다.** 상자가 먼저다 — 상자 안에서 진화가 일어나므로,
			# 레벨업 카드보다 뒤로 밀면 진화 직전 상태로 카드를 고르게 된다.
			if w.chest_ready:
				_open_chest()
			elif g.arcana_due():
				_open_arcana()
			elif g.can_level():
				_open_cards()
			elif w.dead:
				_finish()
			elif w.cleared:
				w.begin_sweep()
				fx.level_text(w.pos + Vector2(0, -70), "CLEAR!", NvP.GOLD_HI)
				st = St.SWEEP
		St.SWEEP:
			# 적은 멈추고 젬만 빨려 들어온다 — 클리어 직후의 보상 장면이다
			fx.update(dt)
			_follow(dt)
			if w.sweep_step(dt):
				_clear_round()
		St.LEVELUP, St.ARCANA:
			card_anim = minf(1.0, card_anim + dt * 5.0)
			fx.update(dt * 0.25)
		St.CHEST:
			chest_t += dt
			fx.update(dt * 0.25)
		St.PAUSED:
			pass
		St.CLEAR:
			clear_t += dt
			fx.update(dt * 0.25)
		St.OVER:
			over_t += dt
			fx.update(dt)

	if st == St.PLAY:
		_pick_tier(dt)

	queue_redraw()


## 적을 얼마나 자세히 그릴지 정한다 ([NvArt].tier).
##
## 예전에는 "화면 안 적 70마리를 넘으면 덩어리 두 개"로 잘랐다. 그 70 은 팔다리를 **벡터로**
## 그리던 시절의 값(200마리에서 23fps)인데, 지금은 부위 그림을 텍스처로 그려서 **290마리를
## 전부 그려도 50~60fps** 가 나온다(실측). 그래서 8라운드처럼 적이 몰리면 멀쩡히 돌아가는데도
## 좀비가 전부 동그라미로 보였다.
##
## 그래서 **대수가 아니라 실제 프레임 속도**로 정한다. 대수로 자르면 기기마다 성능이 다른데도
## 같은 선에서 잘린다. 떨어질 때만 한 단계 내리고 여유가 돌아오면 다시 올리되, 오르내림이
## 떨리지 않게 양쪽에 여유(히스테리시스)와 대기 시간을 둔다.
##
## 기준은 **이 기기가 낼 수 있는 프레임**(≈주사율)이다. 60 위는 볼 필요가 없어 거기서 자르고,
## 주사율이 낮은 기기(30Hz 등)에서 늘 최하 등급이 되지 않게 절대값 대신 이 값을 쓴다.
##
## **이 기준을 시간이 지나면서 내려가게 두면 안 된다.** 처음에는 조금씩 잊게(0.999배) 만들었는데,
## 느려진 상태가 20초쯤 이어지면 기준 자체가 30까지 따라 내려가서 "기준의 90% 니까 괜찮다"고
## 판단해 버렸다 — 25fps 로 기어가는데도 등급을 안 내렸다(실측). 그래서 최대값만 취한다.
func _pick_tier(dt: float) -> void:
	var fps := float(Engine.get_frames_per_second())
	if fps < 1.0:
		return
	_fps_cap = minf(60.0, maxf(_fps_cap, fps))
	_tier_hold -= dt
	if _tier_hold > 0.0:
		return
	if fps < _fps_cap - 14.0 and draw_tier < 2:
		draw_tier += 1
		_tier_hold = 1.5
		# 올렸다가 곧바로 되내려왔다면 다음 시도를 점점 더 미룬다. 이게 없으면 등급이
		# 0↔1 을 1초 간격으로 왕복하며 화면이 계속 바뀐다(실측).
		_up_wait = minf(30.0, maxf(5.0, _up_wait * 2.0))
	elif fps > _fps_cap - 3.0 and draw_tier > 0:
		draw_tier -= 1
		_tier_hold = _up_wait


## 화면에 담기는 **월드** 크기. 줌아웃한 만큼 화면 픽셀보다 넓다.
func _world_view() -> Vector2:
	return _view_size() / ZOOM


func _follow(dt: float) -> void:
	var vw := _world_view()
	var want := w.pos - vw * 0.5
	# 맵 밖이 보이지 않게 잘라 준다 — 단 맵이 화면보다 작으면 잘라 봐야 소용없다
	want.x = clampf(want.x, 0.0, maxf(0.0, w.arena.x - vw.x))
	want.y = clampf(want.y, 0.0, maxf(0.0, w.arena.y - vw.y))
	cam = cam.lerp(want, clampf(dt * 9.0, 0.0, 1.0))


func _move_dir() -> Vector2:
	if neon_auto:
		return _bot_dir()
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.y += 1.0
	return v.normalized() if v.length_squared() > 0.01 else Vector2.ZERO

# ==================== 상태 전환 ====================

## 멈춰 있다 돌아오면 프레임 측정값이 잠깐 부풀어 있다 — 아무것도 안 그리고 안 굴린
## 프레임이 평균에 섞이기 때문이다. 그 값으로 등급을 올리면 곧바로 되내려온다.
## 레벨업·상점처럼 게임이 멈추는 상태에서 나올 때마다 잠시 판단을 미룬다.
func _resume_play() -> void:
	st = St.PLAY
	_tier_hold = maxf(_tier_hold, 1.0)


## 고른 캐릭터로 판을 시작한다. **잠긴 캐릭터는 고를 수 없다** —
## 키·마우스 두 길이 모두 여기를 지나야 한쪽만 빠지는 일이 없다.
func _begin_run() -> void:
	if NvD.char_locked(char_sel):
		NvSnd.s().ui()
		return
	_new_run(char_sel)
	_start_round()


func _start_round() -> void:
	_resume_play()
	NvSnd.s().music(true)


## 시작 라운드를 옮긴다. 키와 버튼이 같은 길을 쓰도록 한 곳에 모아 뒀다 —
## 걸러 내는 범위(`1 ~ best_round`)와 효과음을 두 군데에 적어 두면 반드시 어긋난다.
## 시작 라운드를 옮긴다. **도달 기록으로 막지 않는다** — 1~`NvD.MAX_ROUND` 아무 데나
## 고를 수 있다. 난이도를 스스로 정하는 것이 이 화면의 목적이고, 어렵게 고르면 어려운 만큼
## 코인이 더 들어온다(`NvD.diff_coin` · `req_power`).
func _set_round(n: int) -> void:
	var next := clampi(n, 1, NvD.MAX_ROUND)
	if next == start_round:
		return
	start_round = next
	NvSnd.s().ui()


## 난이도를 옮긴다. 잠금이 없고, 고른 값은 [NvSv] 에 바로 저장된다.
func _set_diff(i: int) -> void:
	var next := clampi(i, 0, NvD.DIFFICULTY.size() - 1)
	if next == NvSv.difficulty:
		return
	NvSv.difficulty = next
	NvSv.save_()
	NvSnd.s().ui()


## 라운드를 버텨 냈다 — 남은 젬을 전부 거둬들이고, 코인을 주고 상점을 연다.
## **흡수가 먼저다** — 보상 코인이 그 라운드에서 번 경험치에 비례하므로 순서가 바뀌면
## 마지막에 쓸어 담은 젬이 코인에 안 잡힌다.
func _clear_round() -> void:
	clear_gems = w.swept_xp + w.absorb_gems()
	clear_coins = g.next_round()
	shop_sel = 0
	clear_t = 0.0
	st = St.CLEAR
	fx.flash(NvP.GOLD_HI, 0.7)
	NvSnd.s().clear_()


## 다음 라운드로. 무기와 레벨은 그대로 들고 맵만 갈아 끼운다.
func _next_round() -> void:
	w.begin_round()
	cam = w.pos - _view_size() * 0.5
	_start_round()


func _open_cards() -> void:
	g.level_up()
	cards = g.roll_cards(NvD.CARD_COUNT)
	card_sel = 0
	card_anim = 0.0
	st = St.LEVELUP
	fx.level_text(w.pos + Vector2(0, -60), "LEVEL UP!", NvP.GOLD_HI)
	NvSnd.s().levelup()


## 보물상자를 연다. **여는 순간 이미 적용된다** — 화면은 무엇이 들어왔는지 보여 줄 뿐이다.
## 고르는 화면이 아니라서 아무 키나 누르면 닫힌다.
func _open_chest() -> void:
	w.chest_ready = false
	chest_rows = g.open_chest()
	chest_t = 0.0
	st = St.CHEST
	fx.flash(NvP.GOLD_HI, 0.6)


func _open_arcana() -> void:
	arc_cards = g.roll_arcana(3)
	if arc_cards.is_empty():
		g.arcana_at += 1          # 더 고를 것이 없으면 그냥 넘어간다
		return
	arc_sel = 0
	card_anim = 0.0
	st = St.ARCANA
	NvSnd.s().arcana()


func _pick_arcana(i: int) -> void:
	if i < 0 or i >= arc_cards.size():
		return
	g.take_arcana(int(arc_cards[i]))
	arc_cards.clear()
	NvSnd.s().levelup()
	_resume_play()


func _click_arcana(at: Vector2) -> void:
	var vs := _view_size()
	for i in arc_cards.size():
		if NvHud.arcana_rect(vs.x, vs.y, i, arc_cards.size()).has_point(at):
			_pick_arcana(i)
			return


## 보물상자 화면을 닫는다. 고르는 화면이 아니라 **아무 키·아무 클릭**으로 닫힌다.
## 열자마자 눌러 지나치지 않게 잠깐(0.5초)은 안 닫는다 — 무엇이 들어왔는지 볼 시간이다.
func _close_chest() -> void:
	if chest_t <= 0.5:
		return
	chest_rows.clear()
	if g.can_level():
		_open_cards()
	else:
		_resume_play()


func _reroll() -> void:
	if g.reroll_left <= 0:
		return
	g.reroll_left -= 1
	cards = g.roll_cards(NvD.CARD_COUNT)
	card_sel = 0
	card_anim = 0.0
	NvSnd.s().ui()


## 카드를 하나도 안 고르고 넘어간다. 뱀서와 같이 **아무것도 안 받는 대신 판이 안 멈춘다.**
func _skip() -> void:
	if g.skip_left <= 0:
		return
	g.skip_left -= 1
	cards.clear()
	NvSnd.s().ui()
	if g.can_level():
		_open_cards()
	else:
		_resume_play()


## 고른 카드를 이 판에서 영구히 지운다. 지우고 나면 그 자리를 다시 뽑는다.
func _banish(i: int) -> void:
	if i < 0 or i >= cards.size():
		return
	if not g.banish(cards[i]):
		NvSnd.s().ui()
		return
	cards = g.roll_cards(NvD.CARD_COUNT)
	card_sel = 0
	NvSnd.s().ui()


func _pick(i: int) -> void:
	if i < 0 or i >= cards.size():
		return
	g.apply_card(cards[i])
	NvSnd.s().ui()
	cards.clear()
	# 한 번에 여러 레벨이 오르는 경우가 있다 (보스 젬). 남아 있으면 카드를 또 띄운다.
	if g.can_level():
		_open_cards()
	else:
		_resume_play()


func _buy(i: int) -> void:
	if i < 0 or i >= NvD.SHOP.size():
		return
	if NvSv.buy(i):
		# 라운드 사이라 어차피 만피로 시작한다 — 방탄 조끼로 최대 체력이 늘면 늘어난 만큼
		# 바로 채워 줘야 "샀는데 체력이 안 찬" 상태로 다음 라운드에 들어가지 않는다.
		g.hp = g.max_hp()
		NvSnd.s().levelup()
	else:
		NvSnd.s().ui()


func _finish() -> void:
	st = St.OVER
	over_t = 0.0
	# **죽을 때도 기록을 넘긴다.** 판 안에서 주운 동전은 `NvSv.pick_coins` 가 저장을 미루므로
	# (초당 여러 번 들어온다) 여기서 안 부르면 그 라운드에 번 것이 통째로 사라진다.
	g.commit_record()
	NvSnd.s().gameover()
	fx.flash(NvP.CRIMSON, 0.8)

# ==================== 입력 ====================

func _unhandled_input(e: InputEvent) -> void:
	if Vol.open:
		Vol.handle(e, _view_size())
		return
	if st == St.TITLE and e is InputEventKey and (e as InputEventKey).pressed and book.key((e as InputEventKey).keycode):
		return
	if e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo:
		_key((e as InputEventKey).keycode)
	elif e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		var at := (e as InputEventMouseButton).position
		# **화면을 새로 만들면 이 목록에도 넣어야 합니다.** 키 처리(`_key`)만 넣고 여기를
		# 빠뜨리면 "마우스로는 고를 수가 없다"가 되는데, 키로는 되기 때문에 눈치채기 어렵습니다
		# (아르카나·보물상자가 실제로 그랬습니다).
		if st == St.TITLE:
			_click_title(at)
		elif st == St.LEVELUP:
			_click_cards(at)
		elif st == St.ARCANA:
			_click_arcana(at)
		elif st == St.CHEST:
			_close_chest()
		elif st == St.CHARSEL:
			_click_chars(at)
		elif st == St.CLEAR:
			_click_shop(at)


func _key(k: int) -> void:
	if k == KEY_M:
		NvSnd.s().muted = not NvSnd.s().muted
		return

	match st:
		St.TITLE:
			if k == KEY_SPACE or k == KEY_ENTER:
				_begin_run()   # 출격 — 출격 준비에서 고른 기체 · 난이도 · 라운드 그대로(처음엔 도달한 가장 높은 라운드)
			elif k == KEY_ESCAPE:
				NvSnd.s().music(false)
				Hub.leave(self)
		St.CHARSEL:
			if k == KEY_LEFT or k == KEY_A:
				char_sel = maxi(0, char_sel - 1)
				NvSnd.s().ui()
			elif k == KEY_RIGHT or k == KEY_D:
				char_sel = mini(NvD.CHAR.size() - 1, char_sel + 1)
				NvSnd.s().ui()
			elif k == KEY_UP or k == KEY_W:
				_set_round(start_round + 1)
			elif k == KEY_DOWN or k == KEY_S:
				_set_round(start_round - 1)
			elif k == KEY_END or k == KEY_PAGEUP:
				_set_round(NvD.MAX_ROUND)
			elif k == KEY_HOME or k == KEY_PAGEDOWN:
				_set_round(1)
			elif k == KEY_Q:
				_set_diff(NvSv.difficulty - 1)
			elif k == KEY_E:
				_set_diff(NvSv.difficulty + 1)
			elif k >= KEY_1 and k < KEY_1 + NvD.CHAR.size():
				char_sel = k - KEY_1
				_begin_run()
			elif k == KEY_SPACE or k == KEY_ENTER:
				_begin_run()
			elif k == KEY_ESCAPE:
				st = St.TITLE
		St.PLAY:
			if k == KEY_ESCAPE:
				st = St.PAUSED
		St.PAUSED:
			if k == KEY_ESCAPE or k == KEY_SPACE:
				_resume_play()
		St.LEVELUP:
			if k == KEY_1:
				_pick(0)
			elif k == KEY_2:
				_pick(1)
			elif k == KEY_3:
				_pick(2)
			elif k == KEY_LEFT or k == KEY_A:
				card_sel = maxi(0, card_sel - 1)
				NvSnd.s().ui()
			elif k == KEY_RIGHT or k == KEY_D:
				card_sel = mini(cards.size() - 1, card_sel + 1)
				NvSnd.s().ui()
			elif k == KEY_SPACE or k == KEY_ENTER:
				_pick(card_sel)
			elif k == KEY_R:
				_reroll()
			elif k == KEY_S:
				_skip()
			elif k == KEY_B:
				_banish(card_sel)
		St.ARCANA:
			if k >= KEY_1 and k < KEY_1 + arc_cards.size():
				_pick_arcana(k - KEY_1)
			elif k == KEY_LEFT or k == KEY_A:
				arc_sel = maxi(0, arc_sel - 1)
				NvSnd.s().ui()
			elif k == KEY_RIGHT or k == KEY_D:
				arc_sel = mini(arc_cards.size() - 1, arc_sel + 1)
				NvSnd.s().ui()
			elif k == KEY_SPACE or k == KEY_ENTER:
				_pick_arcana(arc_sel)
		St.CHEST:
			_close_chest()
		St.CLEAR:
			if k == KEY_LEFT or k == KEY_A:
				shop_sel = maxi(0, shop_sel - 1)
				NvSnd.s().ui()
			elif k == KEY_RIGHT or k == KEY_D:
				shop_sel = mini(NvD.SHOP.size() - 1, shop_sel + 1)
				NvSnd.s().ui()
			elif k >= KEY_1 and k < KEY_1 + NvD.SHOP.size():
				shop_sel = k - KEY_1
				_buy(shop_sel)
			elif k == KEY_UP or k == KEY_W:
				_buy(shop_sel)
			elif k == KEY_SPACE or k == KEY_ENTER:
				_next_round()
			elif k == KEY_ESCAPE:
				# 스스로 그만두는 거라 "실패" 화면을 띄우지 않는다. 코인은 이미 저장돼 있다.
				st = St.TITLE
				NvSnd.s().music(false)
		St.OVER:
			if k == KEY_SPACE or k == KEY_ENTER:
				st = St.CHARSEL
				NvSnd.s().ui()
			elif k == KEY_ESCAPE:
				st = St.TITLE


func _click_cards(at: Vector2) -> void:
	var vs := _view_size()
	# 아래 줄은 셋으로 나뉜다 — 그리는 쪽(`NvHud.cards`)과 **같은 식으로** 잘라야 어긋나지 않는다.
	var rb := NvHud.reroll_rect(vs.x, vs.y)
	if rb.has_point(at):
		var bw := rb.size.x / 3.0 - 6.0
		var i := clampi(int((at.x - rb.position.x) / (bw + 9.0)), 0, 2)
		match i:
			0: _reroll()
			1: _skip()
			_: _banish(card_sel)
		return
	var n := cards.size()
	var cw := minf(268.0, (vs.x - 80.0) / maxi(1, n) - 18.0)
	var chh := minf(330.0, vs.y * 0.48)
	var total := cw * n + 18.0 * (n - 1)
	var x0 := (vs.x - total) * 0.5
	var y0 := vs.y * 0.34
	for i in n:
		var r := Rect2(x0 + i * (cw + 18.0), y0, cw, chh)
		if r.has_point(at):
			_pick(i)
			return


func _click_chars(at: Vector2) -> void:
	var vs := _view_size()
	# 바깥 두 칸(±2)은 양 끝으로 한 번에 간다. 최고 라운드가 100 이면 한 칸씩 눌러
	# 99번 딸깍해야 하는데, 그건 조작이 아니라 벌이다.
	for dir in [-2, -1, 1, 2]:
		if NvHud.round_btn_rect(vs.x, vs.y, dir).has_point(at):
			_set_round(NvD.MAX_ROUND if dir == 2 else (1 if dir == -2 else start_round + dir))
			return
	for i in NvD.DIFFICULTY.size():
		if NvHud.diff_rect(vs.x, vs.y, i).has_point(at):
			_set_diff(i)
			return
	for i in NvD.CHAR.size():
		if NvHud.char_rect(vs.x, vs.y, i).has_point(at):
			if char_sel == i:
				_begin_run()
			else:
				char_sel = i
				NvSnd.s().ui()
			return


func _click_shop(at: Vector2) -> void:
	var vs := _view_size()
	if NvHud.next_round_rect(vs.x, vs.y).has_point(at):
		_next_round()
		return
	for i in NvD.SHOP.size():
		if NvHud.shop_rect(vs.x, vs.y, i).has_point(at):
			shop_sel = i
			_buy(i)
			return

# ==================== 그리기 ====================

func _draw() -> void:
	var vs := _view_size()
	# 월드 점 p 는 화면의 `off + ZOOM * p` 로 간다. 카메라 좌상단(cam)이 화면 0 이 되도록 잡는다.
	# 흔들림은 화면 픽셀 단위라 배율을 곱한 **뒤에** 더한다.
	var off := -cam * ZOOM
	if w != null and w.shake > 0.0:
		off += Vector2(randf_range(-w.shake, w.shake), randf_range(-w.shake, w.shake))

	# 스프라이트가 좌우 뒤집기를 할 때 카메라 변환을 다시 곱해야 해서 넘겨 준다
	NvSpr.origin = off
	NvSpr.zoom = ZOOM
	draw_set_transform(off, 0.0, Vector2(ZOOM, ZOOM))
	_draw_world(Rect2(cam - Vector2(60, 60), _world_view() + Vector2(120, 120)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# HUD 는 화면 좌표로 그린다. 캐릭터 선택창이 NvArt.hero 를 그대로 쓰므로 카메라 오프셋과
	# 배율을 여기서 되돌려야 한다 — 안 그러면 선택창 캐릭터가 밀려 나가고 작게 그려진다.
	NvSpr.origin = Vector2.ZERO
	NvSpr.zoom = 1.0

	fx.draw_screen(self, vs.x, vs.y)

	match st:
		St.TITLE:
			_draw_title(vs)
		St.CHARSEL:
			NvHud.charsel(self, vs.x, vs.y, char_sel, start_round, t)
		St.PLAY, St.SWEEP, St.LEVELUP, St.ARCANA, St.CHEST, St.PAUSED:
			NvHud.bar(self, vs.x, vs.y, g, t)
			NvHud.minimap(self, vs.x, vs.y, w)
			NvHud.loadout(self, vs.x, vs.y, g)
			if st == St.LEVELUP:
				NvHud.cards(self, vs.x, vs.y, cards, card_sel, t, card_anim, g)
			elif st == St.ARCANA:
				NvHud.arcana(self, vs.x, vs.y, arc_cards, arc_sel, t, card_anim)
			elif st == St.CHEST:
				NvHud.chest(self, vs.x, vs.y, chest_rows, chest_t)
			elif st == St.PAUSED:
				NvHud.paused(self, vs.x, vs.y)
		St.CLEAR:
			NvHud.bar(self, vs.x, vs.y, g, t)
			NvHud.round_clear(self, vs.x, vs.y, g, clear_coins, clear_gems, shop_sel, clear_t)
		St.OVER:
			NvHud.bar(self, vs.x, vs.y, g, t)
			NvHud.result(self, vs.x, vs.y, g, over_t)


func _draw_world(view: Rect2) -> void:
	if w == null:
		NvArt.ground(self, view, NvD.MAP[0], t)
		return
	NvArt.ground(self, view, g.map(), t)

	for a: Dictionary in w.areas:
		NvArt.area(self, a, t)

	# 통은 바닥에 붙은 것이라 제일 아래
	for pr: Dictionary in w.props:
		if view.has_point(pr["p"]):
			NvArt.prop(self, pr, t)

	for gm: Dictionary in w.gems:
		if view.has_point(gm["p"]):
			NvArt.gem(self, gm, t)

	for cn: Dictionary in w.coins:
		if view.has_point(cn["p"]):
			NvArt.coin(self, cn, t)

	# 아이템은 젬·동전보다 위에 — 판 후반에 묻히면 주우러 갈 수가 없다
	for it: Dictionary in w.items:
		if view.has_point(it["p"]):
			NvArt.item(self, it, t)

	# 먼(위쪽) 놈부터 그려야 앞뒤가 맞는다
	var order: Array = []
	for e: Dictionary in w.enemies:
		if view.has_point(e["p"]):
			order.append(e)
	order.sort_custom(func(a, b): return a["p"].y < b["p"].y)
	# 등급은 `_pick_tier` 가 프레임을 보고 정하되, 화면 안 적이 너무 많으면 여기서 바닥을
	# 올린다 — 떨어지길 기다렸다 내리면 그 몇 초가 그대로 끊김으로 보인다.
	NvArt.set_tier(maxi(draw_tier, 1 if order.size() > TIER0_MAX_SHOWN else 0))
	for e: Dictionary in order:
		NvArt.enemy(self, e, t)

	# 회전 사슬 — **판정(`NvWorld._chain_touch`)과 같은 식으로 자리를 잡아야** 쇳덩이가
	# 보이는 곳과 맞는 곳이 어긋나지 않는다. 두 곳을 같이 고칠 것.
	if g.weapons.has(NvD.W_CHAIN):
		var wid := NvD.W_CHAIN
		var n := g.wcount(wid)
		var rad := g.wstat(wid, "radius", 90.0)
		var orb_r := 15.0
		# 마법사가 "부유 룬 고리"로 진화시켰으면 쇳덩이가 아니라 룬이다.
		var rune := g.evolved(wid) and not g.evo_alt(wid).is_empty()
		var rings := 2 if g.evolved(wid) else 1
		for ring in rings:
			var rr := rad * (1.0 if ring == 0 else 0.58)
			var cnt := n if rings == 1 else int(ceil(n * 0.5))
			for i in cnt:
				var a := w.orb_ang * (1.0 if ring == 0 else -1.35) + TAU * i / maxi(1, cnt)
				NvArt.orb(self, w.pos + Vector2(cos(a), sin(a)) * rr, orb_r, t, rune)

	for d: Dictionary in w.drones:
		NvArt.drone(self, d, t)

	# 자석이 켜져 있으면 주인공 밑에 고리를 깐다 (주인공보다 먼저 = 뒤에)
	if w.magnet_t > 0.0:
		NvArt.magnet_aura(self, w.pos, w.magnet_t / NvD.MAGNET_TIME, t)

	# 주인공은 화면에 하나뿐이라 언제나 전부 그린다
	NvArt.set_tier(0)
	NvArt.hero(self, w.pos, w.look, t, w.iframe > 0.0 and fmod(t, 0.16) < 0.08,
		_move_dir().length_squared() > 0.01, g.chr())

	for b: Dictionary in w.bullets:
		NvArt.bullet(self, b, t)
	for b2: Dictionary in w.beams:
		NvArt.beam(self, b2)
	for z: Dictionary in w.zaps:
		NvArt.zap(self, z)

	fx.draw_world(self)


# ==================== 확인용 — 봇 (--neon-auto) ====================


## 가까운 적에게서 멀어지고(거리 제곱 반비례) 가까운 젬 쪽으로 조금. 맵 벽에서 밀려난다.
func _bot_dir() -> Vector2:
	var away := Vector2.ZERO
	for e: Dictionary in w.enemies:
		var d: Vector2 = w.pos - (e["p"] as Vector2)
		var l2 := maxf(400.0, d.length_squared())
		if l2 < 360000.0:
			away += d / l2
	var to_gem := Vector2.ZERO
	var best := 1e12
	for gm: Dictionary in w.gems:
		var d2: float = (gm["p"] as Vector2).distance_squared_to(w.pos)
		if d2 < best:
			best = d2
			to_gem = (gm["p"] as Vector2) - w.pos
	var v := away.normalized() * 1.0 + to_gem.normalized() * 0.35
	# 벽에서 떨어지기
	var m := 200.0
	if w.pos.x < m: v.x += 1.0
	if w.pos.y < m: v.y += 1.0
	if w.pos.x > w.arena.x - m: v.x -= 1.0
	if w.pos.y > w.arena.y - m: v.y -= 1.0
	return v.normalized() if v.length_squared() > 0.0001 else Vector2.RIGHT


## 고르는 화면은 잠깐 뒤 무작위로 고른다. 라운드를 끝내거나 죽으면 결과를 찍고 나간다.
func _auto_step(dt: float) -> void:
	_auto_t += dt
	if _auto_t < 0.15:
		return
	_auto_t = 0.0
	match st:
		St.LEVELUP:
			_pick(randi() % maxi(1, cards.size()))
		St.ARCANA:
			_pick_arcana(randi() % maxi(1, arc_cards.size()))
		St.CHEST:
			_close_chest()
		St.CLEAR, St.OVER:
			print("NEON AUTO OK — %s, 라운드 %d, %d초, 레벨 %d, 처치 %d" % ["클리어" if st == St.CLEAR else "쓰러짐",
					g.round_no, int(g.time), g.level, g.kills])
			Engine.time_scale = 1.0
			Hub.leave(self)


# ==================== 처음 화면 — 다섯 게임과 같은 틀 (ADR-0008, 재정비 8-1) ====================


func _click_title(p: Vector2) -> void:
	var vs := _view_size()
	if book.click(p, vs):
		return
	if Hub.std_rect("hub", vs).has_point(p):
		NvSnd.s().music(false)
		Hub.leave(self)
	elif Hub.std_rect("vol", vs).has_point(p):
		Vol.open = true
	elif Hub.std_rect("start", vs).has_point(p):
		_begin_run()
	else:
		for j in 4:
			if UiKit.menu_rect(vs, j).has_point(p):
				NvSnd.s().ui()
				_menu(j)


## 오른쪽 메뉴: 0 출격 준비(기체 · 난이도 · 시작 라운드) · 1 무기 도감 · 2 적 도감 · 3 순위(이 기기의 기록).
func _menu(j: int) -> void:
	book.game = "neon"
	match j:
		0:
			st = St.CHARSEL
		1:
			var items := []
			for i in NvD.WEAPON.size():
				var wr: Dictionary = NvD.WEAPON[i]
				items.append({name = String(wr["name"]), desc = "%s  진화: %s" % [String(wr["desc"]), String(wr.get("evo_name", "-"))],
						draw = func(ci: CanvasItem, r: Rect2, tt: float): NvHud.icon(ci, String(wr["kind"]), r.get_center(), minf(r.size.x, r.size.y) * 0.7, Color(0.5, 0.95, 1.0))})
			book.show("무기 도감", items, "grid", 5, 2)
		2:
			var items2 := []
			for row: Dictionary in NvD.ENEMY:
				var art := String(row["art"])
				var col: Color = row["col"]
				items2.append({name = String(row["name"]), desc = "체력 %d  빠르기 %d  피해 %d" % [int(row["hp"]), int(row["spd"]), int(row["dmg"])],
						draw = func(ci: CanvasItem, r: Rect2, tt: float): NvArt.glitch(ci, r.get_center(), minf(r.size.x, r.size.y) * 0.32, art, col, tt, tt * 0.6)})
			book.show("적 도감", items2, "grid", 5, 2)
		3:
			var rows := [
				{main = "최고 라운드 %d" % NvSv.best_round, sub = "도달한 가장 높은 라운드"},
				{main = "누적 처치 %d" % NvSv.total_kills, sub = "지금까지 쓸어낸 글리치"},
				{main = "한 판 진화 %d" % NvSv.best_evo, sub = "한 판에 만든 가장 많은 진화"},
				{main = "모은 코인 %d" % NvSv.total_coins, sub = "지금 가진 코인 %d" % NvSv.coins},
			]
			book.show("순위", rows, "list")


func _draw_title(vs: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color8(6, 8, 20))
	for k in 18:   # 흐르는 격자
		var x := fposmod(k * 80.0 + t * 20.0, vs.x + 80.0) - 40.0
		draw_line(Vector2(x, 0), Vector2(x, vs.y), Color(0.25, 0.8, 1.0, 0.06), 1.0)
	for k in 10:
		var y := fposmod(k * 80.0 + t * 12.0, vs.y + 80.0) - 40.0
		draw_line(Vector2(0, y), Vector2(vs.x, y), Color(0.25, 0.8, 1.0, 0.06), 1.0)
	var below := UiKit.title(self, vs, "neon", "네온 서바이버", "움직이면 알아서 싸운다. 격자를 갉아먹는 글리치를 쓸어내라", t)
	# 왼쪽 그림 — 가운데 기체, 둘레에 몰려오는 글리치 다섯 종
	var c := Vector2(vs.x * 0.3, below + 170.0)
	var arts := ["zombie", "runner", "fat", "bomber", "spitter"]
	for k in 10:
		var a := TAU * k / 10.0 + t * 0.3
		var d := 150.0 - fposmod(t * 30.0 + k * 23.0, 70.0)
		var row: Dictionary = NvD.ENEMY[k % 5]
		NvArt.glitch(self, c + Vector2(cos(a), sin(a)) * d, 16.0, arts[k % 5], row["col"], t, a + PI)
	for k in 3:
		var a2 := t * 3.0 + TAU * k / 3.0
		draw_line(c + Vector2(cos(a2), sin(a2)) * 34.0, c + Vector2(cos(a2), sin(a2)) * 62.0, Color(0.6, 1.6, 2.0), 4.0, true)
	NvArt.glitch(self, c, 22.0, "fat", Color8(90, 230, 255), t, t)
	var labels := ["출격 준비", "무기 도감", "적 도감", "순위"]
	for j in 4:
		UiKit.menu(self, UiKit.menu_rect(vs, j), labels[j], Color8(24, 56, 104), "neon", t)
	var ch: Dictionary = NvD.CHAR[char_sel]
	UiKit.record_line(self, vs, "%s  %s  %d라운드부터   코인 %d" % [String(ch["name"]), String(NvD.DIFFICULTY[NvSv.difficulty]["name"]),
			start_round, NvSv.coins])
	UiKit.key_hint(self, vs, "Enter 출격   WASD 이동   Esc 게임 선택")
	UiKit.button(self, vs, "start", "neon", t, "출격")
	UiKit.button(self, vs, "hub", "neon", t)
	UiKit.button(self, vs, "vol", "neon", t)
	book.draw(self, vs, t)
	Vol.draw(self, vs, t)
