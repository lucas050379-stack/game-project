extends SceneTree

## 후보 그림을 후처리(post) 전에 다듬는다 — 자르기 · 돌리기 · 지우기. 결과는 새 후보로 art/source/ 에 남는다.
##   godot --headless --path . --script res://tools/prep.gd -- <원본 파일명> <새 번호> [crop=x,y,w,h] [rot=시계방향 도] [erase=x,y,w,h] ...
## AI 는 비율 · 방향을 안 지킨다(이미지가 정사각 고정이고 "곧게 세워서" 도 무시한다). 그림 안의 길쭉한 조각을 세우거나
## 넓은 보스만 잘라 쓸 때 쓴다. 지운 자리와 돌린 뒤 빈 자리는 왼쪽 위 구석 색으로 칠한다 — post 가 배경으로 지운다.
## 순서는 지우기 → 자르기 → 돌리기이고 좌표는 전부 **원본** 기준이다.


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var dir := ProjectSettings.globalize_path("res://art/source/")
	var img := Image.load_from_file(dir + a[0])
	img.convert(Image.FORMAT_RGBA8)
	var bg := img.get_pixel(2, 2)
	var crop := Rect2i()
	var deg := 0.0
	for s: String in a.slice(2):
		var kv := s.split("=")
		if kv[0] == "rot":
			deg = float(kv[1])
			continue
		var n := kv[1].split(",")
		var r := Rect2i(int(n[0]), int(n[1]), int(n[2]), int(n[3]))
		if kv[0] == "crop":
			crop = r
		elif kv[0] == "erase":
			img.fill_rect(r, bg)
	if crop.has_area():
		img = img.get_region(crop)
	if deg != 0.0:
		img = _turn(img, deg, bg)
	var out := a[0].get_slice(".", 0)
	out = out.substr(0, out.rfind("_")) + "_%s.jpg" % a[1]
	img.convert(Image.FORMAT_RGB8)
	img.save_jpg(dir + out, 0.97)
	print("-> ", out)
	quit()


static func _turn(src: Image, deg: float, bg: Color) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(bg)
	var c := Vector2(w, h) * 0.5
	var ang := -deg_to_rad(deg)
	for y in h:
		for x in w:
			var p := (Vector2(x, y) - c).rotated(ang) + c
			var ix := int(p.x)
			var iy := int(p.y)
			if ix >= 0 and iy >= 0 and ix < w and iy < h:
				out.set_pixel(x, y, src.get_pixel(ix, iy))
	return out
