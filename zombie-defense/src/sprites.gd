class_name Spr
extends RefCounted

## 그림 파일이 있으면 쓰고, 없으면 벡터로 그린다.
##
## `art/<이름>.png` 를 넣어 두기만 하면 자동으로 잡힌다. 파일이 없으면 `get_tex` 가 null 을
## 돌려주고 [Art] 가 지금까지의 벡터 그림으로 넘어간다 — **그림이 하나도 없어도 게임은 돈다.**
##
## PNG 는 `build.bat` 의 임포트 단계에서 PCK 안으로 들어간다. 배포는 여전히 exe 한 파일이다.
## 런타임에 폴더에서 파일을 읽는 방식(FileAccess)은 쓰지 않는다 — 그러면 단일 exe 가 깨진다.
##
## 캐릭터는 전신 한 장이 아니라 **부위별 컷아웃**(torso·head·arm_b·arm_f·leg_b·leg_f)으로
## 잘라서 넣는다. 팔다리는 관절에서 매 프레임 실제로 회전해 그리므로 프레임 수와 무관하게
## 걸음이 항상 매끄럽다 — [Art] 가 이미 갖고 있던 벡터 그림의 관절 좌표를 그대로 재사용한다.

## 카메라 변환. main.gd 가 매 프레임 자기가 건 값을 그대로 넣어 준다.
##
## `draw_set_transform` 은 덮어쓰기라서, 좌우 뒤집기를 하려면 카메라 변환을 직접 다시
## 곱해 줘야 한다. 이걸 안 하면 스프라이트만 화면 좌표로 튀어 나간다.
static var origin := Vector2.ZERO

## 카메라 배율. `origin` 과 한 쌍으로 카메라 변환을 그대로 재현하는 데 쓴다 —
## `draw_set_transform` 은 배율까지 통째로 덮어쓰므로 이걸 빼먹으면 좌우로 뒤집힌 조각만
## 원래 크기로 튀어 보인다. HUD 를 그리기 전에 1.0 으로 되돌려야 한다.
static var zoom := 1.0

## 지금 그리는 조각에 곱할 색. 캐릭터마다 그림을 따로 그리기 전까지 `hero` 그림을 색만 바꿔
## 쓰기 위한 것이다. 쓰고 나면 **반드시 흰색으로 되돌려야 한다** — 안 그러면 다음에 그리는
## 적까지 그 색으로 물든다.
static var tint := Color.WHITE

static var _cache := {}
static var _base_cache := {}


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


## 캐릭터 그림 접두어를 고른다. `<name>_torso.png` 가 없으면 `hero` 그림으로 대신한다 —
## 캐릭터를 늘릴 때 그림 6장이 준비되기 전에도 선택창에 바로 올릴 수 있게 하려는 것이다.
## 그림을 제대로 넣으면 이 함수가 알아서 그쪽을 쓰기 시작한다.
static func char_base(name: String) -> String:
	if _base_cache.has(name):
		return _base_cache[name]
	var base := name if has(name + "_torso") else "hero"
	_base_cache[name] = base
	return base


## 월드 좌표 at 에 세로 h 로 그린다. face < 0 이면 좌우로 뒤집는다. 몸통·머리처럼
## 통째로 놓는 조각에 쓴다.
##
## flash 는 피격 번쩍임 — 1.0 을 넘기면 색이 흰쪽으로 날아간다(HDR 곱).
## rot 은 그림 자체를 기울이는 각도(라디안). 0 이고 face 도 안 뒤집으면 변환 없이
## `draw_texture_rect` 로 바로 그려 배칭을 안 끊는다.
static func blit(ci: CanvasItem, tex: Texture2D, at: Vector2, h: float, face: float,
		flash: float = 1.0, rot: float = 0.0) -> void:
	if tex == null or h <= 0.0:
		return
	var s := h / float(maxi(1, tex.get_height()))
	var w := tex.get_width() * s
	var col := Color(tint.r * flash, tint.g * flash, tint.b * flash, 1.0)
	var sx := s if face >= 0.0 else -s
	if rot == 0.0 and face >= 0.0:
		ci.draw_texture_rect(tex, Rect2(at - Vector2(w, h) * 0.5, Vector2(w, h)), false, col)
	else:
		ci.draw_set_transform(origin + at * zoom, rot, Vector2(sx, s) * zoom)
		ci.draw_texture_rect(tex, Rect2(-tex.get_width() * 0.5, -tex.get_height() * 0.5,
			tex.get_width(), tex.get_height()), false, col)
		ci.draw_set_transform(origin, 0.0, Vector2(zoom, zoom))


## 팔다리 한 조각 — 관절(pivot)에서 반대쪽 끝(tip) 방향으로 실제로 회전시켜 그린다.
## 이미지는 **위쪽 끝이 관절, 그 아래로 다리/팔이 뻗은** 세로 그림으로 준비한다
## (art/README.md 참고). 회전+길이 스케일이라 walk 위상이 뭐든 항상 이어져 보인다 —
## 정지 프레임을 갈아 끼우는 방식과 달리 프레임 수에 걸음의 매끄러움이 좌우되지 않는다.
##
## face < 0 이면 좌우로도 뒤집는다. 회전만 시키면 발끝·엄지 같은 그림 자체의 좌우
## 비대칭은 그대로 따라 돌 뿐 거울상이 안 되므로, 왼쪽으로 걸을 때 발이 뒤집힌 채
## (오른쪽 볼 때의 발 모양 그대로) 돌기만 해서 방향이 어색해 보인다.
static func limb_tex(ci: CanvasItem, tex: Texture2D, pivot: Vector2, tip: Vector2,
		face: float = 1.0, flash: float = 1.0) -> void:
	if tex == null:
		return
	var d := tip - pivot
	var length := d.length()
	if length < 1.0:
		return
	var ang := d.angle() - PI * 0.5
	var s := length / float(maxi(1, tex.get_height()))
	var sx := s if face >= 0.0 else -s
	var col := Color(tint.r * flash, tint.g * flash, tint.b * flash, 1.0)
	ci.draw_set_transform(origin + pivot * zoom, ang, Vector2(sx, s) * zoom)
	ci.draw_texture_rect(tex, Rect2(-tex.get_width() * 0.5, 0.0, tex.get_width(), tex.get_height()),
		false, col)
	ci.draw_set_transform(origin, 0.0, Vector2(zoom, zoom))
