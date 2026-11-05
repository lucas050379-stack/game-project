extends SceneTree

## 천성 그림 다듬기 — 아치 안의 하늘을 투명하게 파내고 아래 끝을 들쭉날쭉하게 깎아 art/sky/ 에 넣는다.
##   godot --headless --path . --script res://tools/fort_cut.gd -- <art/source 안의 원본 파일명>
## 그림이 프레임을 꽉 채워서(바위가 네 변까지 닿음) 가장자리 flood fill 은 안 듣고, 아치 안에서부터 번져야 한다.

const BAY_SEED := Vector2i(512, 900)
const TOL := 0.17
const OUT := 768


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var im := Image.load_from_file(ProjectSettings.globalize_path("res://art/source/") + a[0])
	im.convert(Image.FORMAT_RGBA8)
	var w := im.get_width()
	var h := im.get_height()
	var bg := im.get_pixelv(BAY_SEED)
	var seen := PackedByteArray()
	seen.resize(w * h)
	var st: Array[Vector2i] = [BAY_SEED]
	seen[BAY_SEED.y * w + BAY_SEED.x] = 1
	while not st.is_empty():
		var p: Vector2i = st.pop_back()
		var c := im.get_pixelv(p)
		var d := Vector3(c.r - bg.r, c.g - bg.g, c.b - bg.b).length()
		if d > TOL:
			continue
		im.set_pixelv(p, Color(c.r, c.g, c.b, 0.0))
		for q in [Vector2i(p.x + 1, p.y), Vector2i(p.x - 1, p.y), Vector2i(p.x, p.y + 1), Vector2i(p.x, p.y - 1)]:
			if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and seen[q.y * w + q.x] == 0:
				seen[q.y * w + q.x] = 1
				st.append(q)
	# 아래 끝 — 칼로 벤 직선이면 그림이 화면 가운데서 잘린 것처럼 보인다
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	noise.seed = 7
	for x in w:
		var cut := h - 26 - int((noise.get_noise_1d(x) * 0.5 + 0.5) * 60.0)
		for y in range(cut, h):
			im.set_pixel(x, y, Color(0, 0, 0, 0))
	im.resize(OUT, OUT, Image.INTERPOLATE_LANCZOS)
	var out := ProjectSettings.globalize_path("res://art/sky/sky_boss_cheonseong_citadel.png")
	im.save_png(out)
	print("-> ", out)
	quit()
