class_name MsRig
extends RefCounted

## 컷아웃 캐릭터 — AI 로 그린 부위 그림(art/mystic/ms_<이름>_<부위>.png)을 관절 자리에 붙여 그린다.
## 관절 자리는 tools/pixelfx_src/bake.mjs 가 pixelfx 뼈대로 계산해 둔 ms_<이름>_bones.json(동작마다 12fps 프레임 목록).
## 그래서 **동작은 pixelfx 자세표(hero.mjs · foe.mjs) 그대로**이고 겉모습만 그림이다(사용자 결정 11-08 — 이펙트만 pixelfx).
## 프레임 그림을 통째로 AI 로 뽑지 않는 이유: 이미지 AI 는 프레임마다 다른 사람을 그린다.
## 부위 그림이 없으면 같은 뼈에 색 막대를 그린다(그림이 없어도 돈다).

const PARTS := ["leg_upper", "leg_lower", "arm_upper", "arm_lower", "torso", "head"]

static var _bones := {}
static var _tex := {}


static func bones(who: String) -> Dictionary:
	if not _bones.has(who):
		var p := "res://art/mystic/ms_%s_bones.json" % who
		var d: Variant = null
		if FileAccess.file_exists(p):
			d = JSON.parse_string(FileAccess.get_file_as_string(p))
		_bones[who] = d if d is Dictionary else {}
	return _bones[who]


static func tex(who: String, part: String) -> Texture2D:
	var key := who + "_" + part
	if not _tex.has(key):
		var p := "res://art/mystic/ms_%s.png" % key
		_tex[key] = load(p) if ResourceLoader.exists(p) else null
	return _tex[key]


## 동작 a 의 t 초째 관절(없으면 빈 사전).
static func pose(who: String, a: String, t: float) -> Dictionary:
	var b := bones(who)
	var fr: Array = b.get(a, b.get("idle", []))
	if fr.is_empty():
		return {}
	var i := int(floorf(t * 12.0))
	var loop := a in ["idle", "walk"]
	i = posmod(i, fr.size()) if loop else mini(i, fr.size() - 1)
	return fr[i]


## 그린다. feet = 발이 갈 화면 좌표, s = 관절 1px 이 화면에서 몇 px 인가, flip = 왼쪽을 본다.
static func draw(ci: CanvasItem, who: String, a: String, t: float, feet: Vector2, s: float, flip: bool,
		col: Color = Color(1, 1, 1), rot: float = 0.0, look: Dictionary = {}) -> bool:
	var j := pose(who, a, t)
	if j.is_empty():
		return false
	var fx := -1.0 if flip else 1.0
	var P := func(n: String) -> Vector2:
		var v: Array = j[n]
		return Vector2(float(v[0]) * fx, float(v[1])).rotated(rot) * s + feet
	var Z := func(n: String) -> float:
		return float(j[n][2])
	# 그릴 조각 [깊이, 부위, 시작 관절, 끝 관절, 굵기(관절 px)]
	var segs: Array = []
	for side in ["F", "N"]:
		segs.append([(Z.call("hip" + side) + Z.call("knee" + side)) * 0.5, "leg_upper", "hip" + side, "knee" + side, 6.0])
		segs.append([(Z.call("knee" + side) + Z.call("ankle" + side)) * 0.5 + 0.05, "leg_lower", "knee" + side, "toe" + side, 5.0])
		segs.append([(Z.call("shoulder" + side) + Z.call("elbow" + side)) * 0.5, "arm_upper", "shoulder" + side, "elbow" + side, 4.0])
		segs.append([(Z.call("elbow" + side) + Z.call("hand" + side)) * 0.5 + 0.05, "arm_lower", "elbow" + side, "hand" + side, 4.0])
	segs.append([0.0, "torso", "pelvis", "neck", 12.0])
	segs.append([0.2, "head", "neck", "crown", 9.0])
	segs.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	var pal: Dictionary = look.get("pal", {})
	for sg in segs:
		var a2: Vector2 = P.call(sg[2])
		var b2: Vector2 = P.call(sg[3])
		_seg(ci, who, String(sg[1]), a2, b2, float(sg[4]) * s, col, pal, flip)
	return true


## 조각 하나 — 그림이 있으면 a→b 를 따라 세로로 늘려 돌려 그리고, 없으면 굵은 선.
static func _seg(ci: CanvasItem, who: String, part: String, a: Vector2, b: Vector2, w: float, col: Color, pal: Dictionary, flip: bool) -> void:
	var tx := tex(who, part)
	var d := b - a
	var L := d.length()
	if tx == null:
		var c: Color = pal.get(part, Color(0.85, 0.85, 0.9))
		ci.draw_line(a, b, c * col, w, true)
		ci.draw_circle(a, w * 0.5, c * col)
		ci.draw_circle(b, w * 0.5, c * col)
		if part == "head":
			ci.draw_circle(a.lerp(b, 0.5), w * 0.62, c * col)
		return
	# 그림은 "위 = 시작 관절 · 아래 = 끝 관절" 로 세워 뽑았다(몸통 · 머리는 거꾸로: 아래 = 시작)
	var ts := tx.get_size()
	var up := part in ["torso", "head"]
	var ang := d.angle() - PI * 0.5
	if up:
		ang += PI
	var over := 1.18 if not up else 1.08          # 관절 사이를 조금 넘겨 이음매를 덮는다
	var hgt := L * over
	var wid := hgt * ts.x / ts.y
	if part == "head":
		hgt = L * 2.6
		wid = hgt * ts.x / ts.y
	var mid := a.lerp(b, 0.5)
	ci.draw_set_transform(mid, ang, Vector2(-1 if flip else 1, 1))
	ci.draw_texture_rect(tx, Rect2(-wid * 0.5, -hgt * 0.5, wid, hgt), false, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
