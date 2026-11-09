extends SceneTree

## 네온 서바이버 리깅 — 배경을 지운 전신 한 장을 머리 · 몸통(팔 포함) · 다리 둘로 자른다(docs/design/neon.md 12절).
##   godot --headless --path . --script res://tools/rig_split.gd
## 읽는 곳: art/source/rig_cut/<이름>.png (sprite-gen cutout 결과, 오른쪽을 보는 옆모습, 팔 내리고 다리 편 자세)
## 쓰는 곳: art/neon/<이름>_head · _torso · _leg_b · _leg_f .png  +  src/neon/rig_data.gd (관절 자리 표)
## 자동으로 찾는 것:
##   목 = 위쪽 12~38% 줄 가운데 불투명 폭이 가장 좁은 줄
##   가랑이 = 발에서 위로 훑어 올라가며 두 다리가 갈라져 보이는(불투명 덩어리 둘) 줄이 끝나는 곳. 못 찾거나 발목 근처면 키의 55%
##   두 다리를 가르는 x = 가랑이 아래 줄들에서 두 덩어리 사이 틈의 가운데(중앙값). 못 찾으면 몸 가운데
## 조각은 이음매가 안 보이게 서로 조금 겹친다(OVER). 가만히 두면 원래 그림 그대로 다시 맞춰진다.
## **팔은 몸통에 붙인 채로 둔다** — 옆모습은 앞팔이 몸통 위에 겹쳐 있어 떼어 내면 몸통에 구멍이 나거나 팔이 두 개로 보인다.

const SRC := "res://art/source/rig_cut/"
const DST := "res://art/neon/"
const OVER := 0.025   ## 키에 대한 겹침 비율
## 리깅 방식(neon.md 13절) — walk 옆모습 걷기(머리 · 몸통 · 다리 둘) · bounce/float 한 장(몸 전체가 찌그러지고 튀거나 떠다님) ·
## flap 정면 날개(몸통 · 왼날개 · 오른날개). 표에 없으면 walk.
const MODES := {"slime": "bounce", "mushroom": "bounce", "ghost": "float", "bat": "flap", "dragon": "flap"}


func _init() -> void:
	var out := ["class_name NvRig", "extends RefCounted", "",
		"## tools/rig_split.gd 가 만든다 — 손으로 고치지 마세요. 좌표는 원래 그림 픽셀, 원점 = 엉덩이 가운데(가랑이 줄 · 두 다리 사이).",
		"## h = 전신 키(px) · feet = 엉덩이에서 발바닥까지 · 조각마다 tex_anchor = 그 그림 안에서 관절이 놓이는 픽셀 · at = 엉덩이에서 관절까지.",
		"const PARTS := {"]
	var n := 0
	for f in DirAccess.get_files_at(ProjectSettings.globalize_path(SRC)):
		if not f.ends_with(".png"):
			continue
		var name := f.get_basename()
		var line := _split(name)
		if line != "":
			out.append(line)
			n += 1
	out.append("}")
	out.append("")
	var fa := FileAccess.open("res://src/neon/rig_data.gd", FileAccess.WRITE)
	fa.store_string("\n".join(out))
	fa.close()
	print("RIG SPLIT: %d 종" % n)
	quit(0)


func _opaque(img: Image, x: int, y: int) -> bool:
	return img.get_pixel(x, y).a > 0.25


## 한 줄의 불투명 덩어리들 [[x0, x1], ...] — 3px 미만 틈은 이어 붙인다.
func _runs(img: Image, y: int, r: Rect2i) -> Array:
	var runs: Array = []
	var x := r.position.x
	while x < r.end.x:
		if _opaque(img, x, y):
			var s := x
			while x < r.end.x and _opaque(img, x, y):
				x += 1
			if not runs.is_empty() and s - int(runs[-1][1]) < 3:
				runs[-1][1] = x
			else:
				runs.append([s, x])
		x += 1
	return runs.filter(func(rn): return int(rn[1]) - int(rn[0]) >= 4)


func _split(name: String) -> String:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC + name + ".png"))
	if img == null:
		return ""
	img.convert(Image.FORMAT_RGBA8)
	var bb := img.get_used_rect()
	var h := bb.size.y
	var mode: String = MODES.get(name, "walk")
	if mode == "bounce" or mode == "float":
		# 한 장 — 기준점은 발바닥 가운데(통통 튈 때 바닥에서 찌그러진다)
		var one := img.get_region(bb)
		one.save_png(ProjectSettings.globalize_path(DST + name + "_torso.png"))
		return "\t\"%s\": {mode = \"%s\", h = %d, feet = 0, torso = {tex_anchor = Vector2(%d, %d), at = Vector2(0, 0)}, head = {}, leg_b = {}, leg_f = {}}," % [
				name, mode, h, bb.size.x / 2, bb.size.y]
	if mode == "flap":
		# 정면 날개 — 가운데 36% 가 몸통, 양쪽이 날개(몸통 쪽으로 조금 겹침). 날개 관절 = 안쪽 끝, 키의 35% 높이
		var w := bb.size.x
		var bw := int(w * 0.36)
		var bx := bb.position.x + (w - bw) / 2
		var ov2 := int(w * 0.05)
		var pieces := {"torso": Rect2i(bx, bb.position.y, bw, h), "wing_l": Rect2i(bb.position.x, bb.position.y, bx - bb.position.x + ov2, h),
				"wing_r": Rect2i(bx + bw - ov2, bb.position.y, bb.end.x - (bx + bw - ov2), h)}
		var feet := Vector2(bb.get_center().x, bb.end.y)
		var parts2 := []
		for k in pieces:
			var r2: Rect2i = pieces[k]
			var pc := img.get_region(r2)
			var u := pc.get_used_rect()
			if u.size.x <= 0:
				parts2.append("%s = {}" % k)
				continue
			pc = pc.get_region(u)
			var org2 := Vector2(r2.position + u.position)
			pc.save_png(ProjectSettings.globalize_path(DST + "%s_%s.png" % [name, k]))
			var jy := bb.position.y + h * 0.35
			var joint: Vector2 = feet
			if k == "wing_l":
				joint = Vector2(bx + ov2, jy)
			elif k == "wing_r":
				joint = Vector2(bx + bw - ov2, jy)
			parts2.append("%s = {tex_anchor = Vector2(%d, %d), at = Vector2(%d, %d)}" % [k, int(joint.x - org2.x), int(joint.y - org2.y),
					int(joint.x - feet.x), int(joint.y - feet.y)])
		return "\t\"%s\": {mode = \"flap\", h = %d, feet = 0, %s, head = {}, leg_b = {}, leg_f = {}}," % [name, h, ", ".join(parts2)]
	var ov := int(h * OVER)
	# 목
	var neck_y := bb.position.y + int(h * 0.2)
	var best := 1 << 30
	for y in range(bb.position.y + int(h * 0.12), bb.position.y + int(h * 0.38)):
		var w := 0
		for rn in _runs(img, y, bb):
			w += int(rn[1]) - int(rn[0])
		if w > 0 and w < best:
			best = w
			neck_y = y
	var nr: Array = _runs(img, neck_y, bb)
	var neck_x := (int(nr[0][0]) + int(nr[-1][1])) / 2 if not nr.is_empty() else bb.get_center().x
	# 가랑이 — 발 바로 위에서 위로
	var crotch_y := -1
	var gaps: Array = []
	var seen_two := false
	for y in range(bb.end.y - int(h * 0.06), bb.position.y + int(h * 0.4), -1):
		var rs: Array = _runs(img, y, bb)
		if rs.size() >= 2:
			seen_two = true
			gaps.append((int(rs[0][1]) + int(rs[1][0])) / 2)
		elif seen_two:
			crotch_y = y
			break
	# 못 찾았거나, 다리가 위쪽에서 겹쳐 발목 근처에서만 갈라져 보이면(엉덩이에서 발까지가 키의 30% 미만) 키의 55%
	if crotch_y < 0 or bb.end.y - crotch_y < int(h * 0.3):
		crotch_y = bb.position.y + int(h * 0.55)
		gaps = []
	var split_x := bb.get_center().x
	if not gaps.is_empty():
		gaps.sort()
		split_x = int(gaps[gaps.size() / 2])
	var hip := Vector2(split_x, crotch_y)
	# 조각 사각형
	var head_r := Rect2i(bb.position.x, bb.position.y, bb.size.x, neck_y + ov - bb.position.y)
	var torso_r := Rect2i(bb.position.x, neck_y - ov, bb.size.x, crotch_y + ov * 2 - (neck_y - ov))
	var legs_top := crotch_y - ov
	var lb := Rect2i(bb.position.x, legs_top, split_x - bb.position.x, bb.end.y - legs_top)
	var lf := Rect2i(split_x, legs_top, bb.end.x - split_x, bb.end.y - legs_top)
	var parts := {"head": head_r, "torso": torso_r, "leg_b": lb, "leg_f": lf}
	var anchors := {}
	for k in parts:
		var r: Rect2i = parts[k]
		var piece := img.get_region(r)
		var used := piece.get_used_rect()
		if used.size.x <= 0:
			continue
		piece = piece.get_region(used)
		var org := Vector2(r.position + used.position)   # 조각 그림의 왼쪽 위(원래 그림 좌표)
		piece.save_png(ProjectSettings.globalize_path(DST + "%s_%s.png" % [name, k]))
		var joint: Vector2
		match k:
			"head":
				joint = Vector2(neck_x, neck_y)
			"torso":
				joint = hip
			_:
				joint = Vector2(org.x + used.size.x * 0.5, legs_top)   # 다리 = 위쪽 가운데가 엉덩이 관절
		anchors[k] = "%s = {tex_anchor = Vector2(%d, %d), at = Vector2(%d, %d)}" % [k, int(joint.x - org.x), int(joint.y - org.y),
				int(joint.x - hip.x), int(joint.y - hip.y)]
	return "\t\"%s\": {mode = \"walk\", h = %d, feet = %d, %s, %s, %s, %s}," % [name, h, bb.end.y - crotch_y,
			anchors.get("head", "head = {}"), anchors.get("torso", "torso = {}"), anchors.get("leg_b", "leg_b = {}"), anchors.get("leg_f", "leg_f = {}")]
