class_name Spr
extends RefCounted

## 그림 파일이 있으면 쓰고, 없으면 벡터로 그린다.
##
## `art/<이름>.png` 를 넣어 두기만 하면 자동으로 잡힌다. 파일이 없으면 `get_tex` 가 null 을
## 돌려주고 [Art] 가 지금까지의 벡터 그림으로 넘어간다 — **그림이 하나도 없어도 게임은 돈다.**
##
## PNG 는 `build.bat` 의 임포트 단계에서 PCK 안으로 들어간다. 배포는 여전히 exe 한 파일이다.
## 런타임에 폴더에서 파일을 읽는 방식(FileAccess)은 쓰지 않는다 — 그러면 단일 exe 가 깨진다.

## 적 종류 번호 -> 파일 이름 (D.E_* 순서와 같아야 한다)
const ENEMY_NAME := ["zombie", "runner", "fat", "bomber", "spitter", "boss"]

## 카메라 변환. main.gd 가 매 프레임 자기가 건 값을 그대로 넣어 준다.
##
## `draw_set_transform` 은 덮어쓰기라서, 좌우 뒤집기를 하려면 카메라 변환을 직접 다시
## 곱해 줘야 한다. 이걸 안 하면 스프라이트만 화면 좌표로 튀어 나간다.
static var origin := Vector2.ZERO

static var _cache := {}


static func get_tex(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var path := "res://art/%s.png" % name
	var tex: Texture2D = null
	# ResourceLoader.exists 를 먼저 봐야 없는 파일에 대해 오류를 안 뱉는다
	if ResourceLoader.exists(path):
		tex = load(path)
	_cache[name] = tex
	return tex


static func has(name: String) -> bool:
	return get_tex(name) != null


## 적 스프라이트. 두 번째 프레임(<이름>_b.png)이 있으면 걸음에 맞춰 번갈아 쓴다.
static func enemy_tex(kind: int, walk: float) -> Texture2D:
	if kind < 0 or kind >= ENEMY_NAME.size():
		return null
	var base: String = ENEMY_NAME[kind]
	if sin(walk) < 0.0:
		var alt := get_tex(base + "_b")
		if alt != null:
			return alt
	return get_tex(base)


## 월드 좌표 at 에 세로 h 로 그린다. face < 0 이면 좌우로 뒤집는다.
##
## flash 는 피격 번쩍임 — 1.0 을 넘기면 색이 흰쪽으로 날아간다(HDR 곱).
static func blit(ci: CanvasItem, tex: Texture2D, at: Vector2, h: float, face: float,
		flash: float = 1.0) -> void:
	if tex == null or h <= 0.0:
		return
	var s := h / float(maxi(1, tex.get_height()))
	var w := tex.get_width() * s
	var tint := Color(flash, flash, flash, 1.0)
	if face < 0.0:
		ci.draw_set_transform(origin + at, 0.0, Vector2(-1.0, 1.0))
		ci.draw_texture_rect(tex, Rect2(-w * 0.5, -h * 0.5, w, h), false, tint)
		ci.draw_set_transform(origin, 0.0, Vector2.ONE)
	else:
		ci.draw_texture_rect(tex, Rect2(at - Vector2(w, h) * 0.5, Vector2(w, h)), false, tint)
