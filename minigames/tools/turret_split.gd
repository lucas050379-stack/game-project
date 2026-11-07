extends SceneTree
## 철갑 주포 그림(sky_cheolgap_turret)을 **포탑 몸체**와 **포신**으로 나눈다(사용자 요청 11-07: 포신만 움직여야 한다).
##   godot --headless --path . --script res://tools/turret_split.gd
## 포신 자리(BARREL, 256 칸 기준)는 그림을 다시 뽑으면 맞추세요. 몸체에서는 포신을 지우고 — 돔 밖은 투명,
## 돔 위는 좌우 옆 칸 무늬를 끌어와 메운다. 포신 그림은 그 띠를 잘라 낸 것(뿌리가 아래).

const SRC := "res://art/sky/sky_cheolgap_turret.png"
const BARREL := Rect2i(118, 8, 20, 98)   ## 포신 띠(x, y, 폭, 높이) — 뿌리는 아래 끝(포탑 해치 가운데)
const DOME_TOP := 36                    ## 이 위는 돔 밖(하늘) — 지우면 투명


func _init() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	img.convert(Image.FORMAT_RGBA8)
	var k := img.get_width() / 256.0
	var b := Rect2i(Vector2i(Vector2(BARREL.position) * k), Vector2i(Vector2(BARREL.size) * k))
	var barrel := img.get_region(b)
	var base := img.duplicate() as Image
	for y in range(b.position.y, b.end.y):
		for x in range(b.position.x, b.end.x):
			if y < int(DOME_TOP * k):
				base.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				# 가까운 쪽 바깥 칸(띠 왼쪽 밖 · 오른쪽 밖)에서 같은 거리만큼 떨어진 무늬를 거울로 가져온다
				var left := x - b.position.x < b.end.x - x
				var sx := b.position.x - 1 - (x - b.position.x) if left else b.end.x + (b.end.x - 1 - x)
				base.set_pixel(x, y, img.get_pixel(clampi(sx, 0, img.get_width() - 1), y))
	base.save_png(ProjectSettings.globalize_path("res://art/sky/sky_cheolgap_turret_base.png"))
	barrel.save_png(ProjectSettings.globalize_path("res://art/sky/sky_cheolgap_barrel.png"))
	print("turret_split -> sky_cheolgap_turret_base.png, sky_cheolgap_barrel.png")
	quit()
