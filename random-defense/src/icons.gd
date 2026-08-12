class_name Ico
extends RefCounted

## 유닛 아이콘. `art/icons/<유닛 id>.png` 를 쓴다.
##
## **그림이 하나도 없어도 게임은 돌아야 한다.** 없으면 `null` 을 돌려주고, 부르는 쪽은
## 이름만 그린다. 그래서 `tools/fetch_icons.ps1` 을 안 돌린 상태로 받아도 실행된다.
##
## 그림은 HUD 에서만 쓴다 — 3D 쪽 유닛은 로우폴리 도안이고, 아이콘은 "이게 누구인가"를
## 목록에서 읽게 하는 용도다. 310종을 이름만으로 구별하는 것은 사람이 할 일이 아니다.
##
## PNG 는 빌드 때 PCK 로 묶이므로 배포 파일은 여전히 exe 하나다.

const DIR := "res://art/icons/"

## 원본 아이콘의 가로세로 비 (52 × 39)
const ASPECT := 52.0 / 39.0

static var _cache := {}


static func tex(id: int) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var path := DIR + str(id) + ".png"
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	_cache[id] = t
	return t


## 유닛 자리([U].UNITS 의 색인)로 바로 찾는다.
static func of(ui: int) -> Texture2D:
	if ui < 0 or ui >= U.UNITS.size():
		return null
	return tex(int(U.UNITS[ui]["i"]))
