class_name MsAnim
extends RefCounted

## 구운 시트(art/mystic/*.png + .json) 읽기와 그리기. 시트는 tools/pixelfx_src/bake.mjs 가 pixelfx 로 굽는다.
## - 주인공(ms_hero): 한 줄 = 동작 하나, 칸 크기 · 발(피벗) 하나 — JSON 의 cell · pivot · anims.
## - 이펙트 · 적(fx_* · en_*): pixelfx 시트 그대로(Aseprite 식 frames + meta.pixelfx.pivot · fps · loop).
## **시트가 없으면 null 을 돌려주고, 부르는 쪽이 벡터 사각형으로 대신 그린다**(그림이 없어도 돈다).
## JSON 은 리소스가 아니라서 웹 내보내기에서 빠진다 — export_presets.cfg 의 include_filter 에 art/mystic/*.json 이 있어야 합니다.

const DIR := "res://art/mystic/"

static var _cache := {}


## 시트 하나: {tex, frames:[Rect2], pivot:Vector2, fps, loop, cell:Vector2, anims:{}} 또는 null.
static func sheet(name: String) -> Variant:
	if _cache.has(name):
		return _cache[name]
	var s: Variant = null
	var png := DIR + name + ".png"
	var js := DIR + name + ".json"
	if ResourceLoader.exists(png) and FileAccess.file_exists(js):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(js))
		if data is Dictionary:
			s = _build(load(png), data)
	_cache[name] = s
	return s


static func _build(tex: Texture2D, d: Dictionary) -> Dictionary:
	var out := {tex = tex, frames = [], anims = {}, fps = 15.0, loop = false}
	if d.has("cell"):
		# 주인공 시트 — 줄 · 칸으로 자른다
		out.cell = Vector2(d.cell[0], d.cell[1])
		out.pivot = Vector2(d.pivot[0], d.pivot[1])
		out.anims = d.anims
		return out
	var pf: Dictionary = d.meta.pixelfx
	for f in d.frames:
		out.frames.append(Rect2(f.frame.x, f.frame.y, f.frame.w, f.frame.h))
	out.pivot = Vector2(pf.pivot[0], pf.pivot[1])
	out.fps = float(pf.fps)
	out.loop = bool(pf.loop)
	return out


## 이펙트 · 적 시트에서 t 초째 칸. 끝난 원샷이면 -1.
static func frame_at(s: Dictionary, t: float) -> int:
	var n: int = s.frames.size()
	var i := int(floorf(t * float(s.fps)))
	if s.loop:
		return posmod(i, n)
	return i if i < n else -1


## 주인공 시트에서 동작 a 의 t 초째 칸 영역.
static func hero_region(s: Dictionary, a: String, t: float) -> Rect2:
	var an: Dictionary = s.anims.get(a, s.anims.idle)
	var n := int(an.n)
	var i := int(floorf(t * float(an.fps)))
	i = posmod(i, n) if an.loop else mini(i, n - 1)
	return Rect2(Vector2(i, int(an.row)) * s.cell, s.cell)


## 칸 하나를 그린다. pos = 피벗이 갈 화면 좌표(이미 배율이 걸린 캔버스 기준), flip = 좌우 뒤집기, k = 배율.
## 뒤집기는 draw_set_transform 으로 한다 — 크기가 음수인 사각형은 엔진이 조용히 안 그리는 일이 있다.
static func blit(ci: CanvasItem, tex: Texture2D, region: Rect2, pivot: Vector2, pos: Vector2, flip: bool,
		k: float, col: Color = Color(1, 1, 1), rot: float = 0.0) -> void:
	ci.draw_set_transform(pos, rot, Vector2(-k if flip else k, k))
	ci.draw_texture_rect_region(tex, Rect2(-pivot, region.size), region, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
