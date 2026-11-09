class_name NvFx
extends RefCounted

## 파티클 · 데미지 숫자 · 고리 · 화면 섬광.
##
## 적이 많아 이펙트도 금방 불어난다. 개수 상한을 두고 **자리를 돌려 쓴다**.
##
## **`pop_front()` 으로 버리지 마세요.** 배열을 통째로 앞으로 당기는 연산이라, 상한이 꽉 찬
## 상태에서 초당 수백 번 불리면 그것만으로 프레임을 먹습니다.
## 수명이 다한 것은 `update()` 가 따로 지우므로 돌려 쓰는 순서가 정확히 오래된 순은 아니지만,
## 0.2~0.6초 사는 알갱이라 눈에는 차이가 없습니다.
##
## **데미지 숫자는 `draw_string` 이라 특히 비쌉니다.** 무기 5개를 진화시키고 적이 600마리쯤
## 되면 숫자만 100개가 떠서 그리기에 4ms 를 썼습니다(실측) — 그 상황에서는 읽을 수도 없는
## 숫자입니다. 상한을 낮추고, 자리가 차면 드물게만 띄웁니다.

## 알갱이 하나하나가 GDScript 루프 한 바퀴 + `draw_circle` 한 번이다. 420개를 두면
## 그리는 데만 2ms 가 갔다(실측). 220개면 한꺼번에 터져도 충분히 자글자글하다.
const MAX_PARTS := 220
const MAX_TEXTS := 24
## 고리는 `draw_arc` 라 한 개가 선분 28개다. 진화한 미사일 8발이 계속 터지면 금방 쌓인다.
const MAX_RINGS := 12

var parts: Array = []
## **pixelfx 시트 애니메이션**(11-09) — pixelfx 에서 캐릭터 없이(`--no-actor`) 내보낸 시트(`art/neon/fx_*.png`)를 월드에 재생한다.
## 맞는 쪽(spark · boom · ring)은 아래 anims 로, 공격 쪽(slash · fireball · arrow)은 NvArt 가 스킬을 그릴 때 `draw_sheet` 로 바로.
## 시트가 없으면 지금처럼 코드 파티클 · 고리만(ADR-0005). 한꺼번에 MAX_ANIMS 개, 넘치면 오래된 자리를 갈아 쓴다.
## fs = 칸 크기 · cols = 한 줄 칸 수 · n = 칸 수 · fps · pv = 기준점(이펙트의 원점) — pixelfx 가 낸 json 의 meta.pixelfx 그대로.
const SHEETS := {
	"spark": {fs = Vector2(136, 80), cols = 4, n = 16, fps = 30.0, pv = Vector2(44, 64)},    # impacts/hit-spark
	"boom": {fs = Vector2(216, 136), cols = 5, n = 28, fps = 30.0, pv = Vector2(84, 106)},   # impacts/crit-hit
	"ring": {fs = Vector2(208, 150), cols = 7, n = 55, fps = 30.0, pv = Vector2(104, 124)},  # arcane/mana-burst
	# 공격 — 무사 회전 참격 · 마법사 화염구 · 궁수 화살(관통 저격 · 연사 화살)
	"slash": {fs = Vector2(208, 104), cols = 4, n = 25, fps = 30.0, pv = Vector2(104, 52)},  # melee/spin-slash (기준점을 칸 가운데로 — 위에서 내려다보는 판)
	"fireball": {fs = Vector2(136, 56), cols = 4, n = 36, fps = 30.0, pv = Vector2(112, 28)},  # fire/fireball (돈다)
	"arrow": {fs = Vector2(112, 32), cols = 3, n = 18, fps = 30.0, pv = Vector2(92, 16)},   # projectiles/arrow (돈다)
}


## 시트 한 칸을 월드 좌표 at 에 sc 배 · rot 만큼 돌려 그린다(loop 면 칸이 돈다). 시트가 없으면 false — 부른 쪽이 원래 그림으로.
## 카메라 변환을 덮어쓰므로 NvSpr.blit 처럼 origin · zoom 을 다시 곱하고, 끝나면 카메라 변환으로 되돌린다.
static func draw_sheet(ci: CanvasItem, kind: String, t: float, at: Vector2, sc: float, rot: float = 0.0, loop: bool = false,
		mod: Color = Color(1.5, 1.5, 1.5, 1.0)) -> bool:
	var tex := sheet(kind)
	if tex == null:
		return false
	var sd: Dictionary = SHEETS[kind]
	var f := int(t * float(sd.fps))
	f = posmod(f, int(sd.n)) if loop else clampi(f, 0, int(sd.n) - 1)
	var fs: Vector2 = sd.fs
	var src := Rect2(Vector2(f % int(sd.cols), f / int(sd.cols)) * fs, fs)
	ci.draw_set_transform(NvSpr.origin + at * NvSpr.zoom, rot, Vector2(sc, sc) * NvSpr.zoom)
	ci.draw_texture_rect_region(tex, Rect2(-sd.pv, fs), src, mod)
	ci.draw_set_transform(NvSpr.origin, 0.0, Vector2(NvSpr.zoom, NvSpr.zoom))
	return true
const MAX_ANIMS := 40
static var _sheet := {}
var anims: Array = []
var _anim_i := 0


static func sheet(kind: String) -> Texture2D:
	if not _sheet.has(kind):
		var path := "res://art/neon/fx_%s.png" % kind
		_sheet[kind] = load(path) if ResourceLoader.exists(path) else null
	return _sheet[kind]


## 시트 하나를 at 에 sc 배로 튼다. 시트가 없으면 false(부른 쪽이 코드 이펙트로).
func _anim(kind: String, at: Vector2, sc: float) -> bool:
	if sheet(kind) == null:
		return false
	var q := {"k": kind, "p": at, "s": sc, "t": 0.0}
	if anims.size() < MAX_ANIMS:
		anims.append(q)
	else:
		anims[_anim_i] = q
		_anim_i = (_anim_i + 1) % MAX_ANIMS
	return true

var texts: Array = []
var rings: Array = []
var flash_col := NvP.WHITE
var flash_t := 0.0
var flash_max := 0.0

var _part_i := 0
var _text_i := 0
var _ring_i := 0


func clear() -> void:
	parts.clear()
	texts.clear()
	rings.clear()
	_part_i = 0
	_text_i = 0
	_ring_i = 0
	flash_t = 0.0


func _push_part(q: Dictionary) -> void:
	if parts.size() < MAX_PARTS:
		parts.append(q)
		return
	parts[_part_i] = q
	_part_i = (_part_i + 1) % MAX_PARTS


func _push_text(q: Dictionary) -> void:
	if texts.size() < MAX_TEXTS:
		texts.append(q)
		return
	texts[_text_i] = q
	_text_i = (_text_i + 1) % MAX_TEXTS


func spark(at: Vector2, col: Color, n: int) -> void:
	if n >= 3 and _anim("spark", at, 1.2):
		n = n / 2   # 시트가 불꽃을 맡으니 파티클은 절반
	for i in n:
		var a := randf() * TAU
		var sp := randf_range(60.0, 230.0)
		_push_part({
			"p": at, "v": Vector2(cos(a), sin(a)) * sp,
			"r": randf_range(2.0, 4.6), "life": randf_range(0.22, 0.5),
			"max": 0.5, "col": col, "drag": 4.0,
		})


func boom(at: Vector2, col: Color, r: float) -> void:
	var sheet_on := _anim("boom", at, maxf(0.6, r * 2.4 / 216.0))
	if not sheet_on:
		ring(at, col, r, 0.34)
	for i in (8 if sheet_on else 16):
		var a := randf() * TAU
		_push_part({
			"p": at, "v": Vector2(cos(a), sin(a)) * randf_range(120.0, r * 3.4),
			"r": randf_range(3.0, 7.0), "life": randf_range(0.3, 0.62),
			"max": 0.62, "col": col, "drag": 3.0,
		})


func ring(at: Vector2, col: Color, r: float, dur: float) -> void:
	if r >= 80.0 and _anim("ring", at, r * 2.0 / 170.0):
		return   # 큰 충격파는 시트가 맡는다
	var q := {"p": at, "r": r, "life": dur, "max": dur, "col": col}
	if rings.size() < MAX_RINGS:
		rings.append(q)
		return
	rings[_ring_i] = q
	_ring_i = (_ring_i + 1) % MAX_RINGS


func dmg_text(at: Vector2, v: float, col: Color) -> void:
	# 자리가 다 차 있으면 대부분 건너뛴다 — 안 그러면 24칸을 초당 수백 번 갈아 치우며
	# 숫자가 부르르 떨기만 하고, 그리기 비용은 그대로 든다.
	if texts.size() >= MAX_TEXTS and randf() > 0.22:
		return
	_push_text({
		"p": at + Vector2(randf_range(-8.0, 8.0), -10.0),
		"s": str(int(round(v))), "life": 0.62, "max": 0.62,
		"col": col, "size": 15.0 + minf(11.0, v * 0.16),
	})


## 레벨업 같은 알림은 상한과 무관하게 반드시 보여야 한다
func level_text(at: Vector2, s: String, col: Color) -> void:
	texts.append({"p": at, "s": s, "life": 1.1, "max": 1.1, "col": col, "size": 26.0})


func flash(col: Color, strength: float) -> void:
	flash_col = col
	flash_t = strength
	flash_max = maxf(strength, 0.001)


func update(dt: float) -> void:
	for i in range(parts.size() - 1, -1, -1):
		var q: Dictionary = parts[i]
		q["life"] = float(q["life"]) - dt
		if float(q["life"]) <= 0.0:
			parts.remove_at(i)
			continue
		q["p"] = q["p"] + q["v"] * dt
		q["v"] = q["v"] * exp(-dt * float(q["drag"]))

	for i in range(texts.size() - 1, -1, -1):
		var t: Dictionary = texts[i]
		t["life"] = float(t["life"]) - dt
		if float(t["life"]) <= 0.0:
			texts.remove_at(i)
			continue
		t["p"] = t["p"] + Vector2(0, -46.0 * dt)

	for i in range(rings.size() - 1, -1, -1):
		rings[i]["life"] = float(rings[i]["life"]) - dt
		if float(rings[i]["life"]) <= 0.0:
			rings.remove_at(i)

	if flash_t > 0.0:
		flash_t = maxf(0.0, flash_t - dt * 1.9)

	for i in range(anims.size() - 1, -1, -1):
		var an: Dictionary = anims[i]
		an["t"] = float(an["t"]) + dt
		var sd: Dictionary = SHEETS[an["k"]]
		if float(an["t"]) * float(sd.fps) >= int(sd.n):
			anims.remove_at(i)


## 월드 좌표계에서 그리는 것들
func draw_world(ci: CanvasItem) -> void:
	for an: Dictionary in anims:
		var sd: Dictionary = SHEETS[an["k"]]
		var tex := sheet(String(an["k"]))
		var f := mini(int(float(an["t"]) * float(sd.fps)), int(sd.n) - 1)
		var fs: Vector2 = sd.fs
		var src := Rect2(Vector2(f % int(sd.cols), f / int(sd.cols)) * fs, fs)
		var sc: float = an["s"]
		ci.draw_texture_rect_region(tex, Rect2(an["p"] - sd.pv * sc, fs * sc), src, Color(1.6, 1.6, 1.6, 1.0))   # 1.0 넘게 — 발광
	for r: Dictionary in rings:
		var u: float = 1.0 - float(r["life"]) / float(r["max"])
		var rr: float = float(r["r"]) * NvG2.out_cubic(u)
		ci.draw_arc(r["p"], rr, 0.0, TAU, 28,
			NvP.a(NvP.hdr(r["col"], 1.5), (1.0 - u) * 0.85), maxf(1.5, 5.0 * (1.0 - u)), true)

	for q: Dictionary in parts:
		var a: float = clampf(float(q["life"]) / float(q["max"]), 0.0, 1.0)
		ci.draw_circle(q["p"], float(q["r"]) * (0.4 + a * 0.6),
			NvP.a(NvP.hdr(q["col"], 1.6), a))

	for t: Dictionary in texts:
		var a2: float = clampf(float(t["life"]) / float(t["max"]), 0.0, 1.0)
		var pop: float = 1.0 + (1.0 - a2) * 0.25
		NvG2.text_mid(ci, t["p"], t["s"], float(t["size"]) * pop,
			NvP.a(NvP.hdr(t["col"], 1.35), minf(1.0, a2 * 1.8)))


## 화면 좌표계 (카메라 영향 없음)
func draw_screen(ci: CanvasItem, w: float, h: float) -> void:
	if flash_t > 0.0:
		ci.draw_rect(Rect2(0, 0, w, h), NvP.a(flash_col, clampf(flash_t, 0.0, 0.7) * 0.55))
