extends SceneTree

## 후보 고르기 — 이름마다 후보를 한 줄로 늘어놓은 한 장(접촉 인화지)을 만든다.
##   godot --headless --path . --script res://tools/contact.gd -- <이름 정규식> [출력 폴더] [한 장에 줄 수]
##   예) ... -- "^sky_boss_" C:/temp/pick 6
##
## 줄 왼쪽 끝 칸이 이름표 자리이고, 각 후보 칸 왼쪽 위에 **번호만큼 흰 점**을 찍는다(후보 번호 01 → 점 하나).
## 글꼴을 쓰지 않는 이유: --script 모드에서 이미지에 글자를 찍을 방법이 마땅치 않다. 이름은 표준 출력에 줄 번호와 같이 찍는다.
## 바탕은 어두운 색 + 체크무늬 — 투명 배경이 남은 후보(분홍 테두리 · 갇힌 배경)가 눈에 띈다.
##
## 같은 이름의 후보가 여러 번 뽑혔으면(날짜가 다른 묶음) 전부 늘어놓는다 — 번호가 겹치므로 점 색을 묶음마다 바꾼다.

const CELL := 220
const GAP := 6


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var pat := a[0] if a.size() > 0 else "."
	var out_dir := a[1] if a.size() > 1 else ProjectSettings.globalize_path("res://art/source/_contact")
	var per := int(a[2]) if a.size() > 2 else 6
	var re := RegEx.create_from_string(pat)
	var src := ProjectSettings.globalize_path("res://art/source/")
	var groups := {}
	var name_re := RegEx.create_from_string("^(.+)_(\\d{4}_\\d{6})_(\\d+)\\.jpg$")
	for f in DirAccess.get_files_at(src):
		var m := name_re.search(f)
		if m == null:
			continue
		var nm := m.get_string(1)
		if re.search(nm) == null:
			continue
		if not groups.has(nm):
			groups[nm] = []
		groups[nm].append([m.get_string(2), int(m.get_string(3)), src + f])
	var names := groups.keys()
	names.sort()
	if names.is_empty():
		print("후보 없음: ", pat)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	var sheet := 0
	var i := 0
	while i < names.size():
		var chunk := names.slice(i, i + per)
		var cols := 0
		for nm in chunk:
			cols = maxi(cols, (groups[nm] as Array).size())
		var w := (cols) * (CELL + GAP) + GAP
		var h := chunk.size() * (CELL + GAP) + GAP
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.07, 0.08, 0.11))
		print("--- 시트 %d ---" % sheet)
		for r in chunk.size():
			var nm: String = chunk[r]
			var list: Array = groups[nm]
			list.sort_custom(func(x, y): return x[0] < y[0] or (x[0] == y[0] and x[1] < y[1]))
			var batches := []
			for c in list:
				if not batches.has(c[0]):
					batches.append(c[0])
			print("%d줄  %s  (%s)" % [r + 1, nm, ", ".join(list.map(func(c): return "%02d" % c[1]))])
			for k in list.size():
				var x := GAP + k * (CELL + GAP)
				var y := GAP + r * (CELL + GAP)
				_checker(img, x, y)
				var cand := Image.load_from_file(list[k][2])
				if cand == null:
					continue
				cand.convert(Image.FORMAT_RGBA8)
				var s := float(CELL) / maxf(cand.get_width(), cand.get_height())
				cand.resize(int(cand.get_width() * s), int(cand.get_height() * s), Image.INTERPOLATE_BILINEAR)
				img.blend_rect(cand, Rect2i(Vector2i.ZERO, cand.get_size()),
						Vector2i(x + (CELL - cand.get_width()) / 2, y + (CELL - cand.get_height()) / 2))
				var col: Color = [Color.WHITE, Color(1, 0.8, 0.2), Color(0.4, 1, 0.6)][batches.find(list[k][0]) % 3]
				for d in list[k][1]:
					img.fill_rect(Rect2i(x + 6 + d * 12, y + 6, 8, 8), Color.BLACK)
					img.fill_rect(Rect2i(x + 7 + d * 12, y + 7, 6, 6), col)
		var path := out_dir.path_join("contact_%02d.png" % sheet)
		img.save_png(path)
		print("-> ", path)
		sheet += 1
		i += per
	quit(0)


func _checker(img: Image, x: int, y: int) -> void:
	for by in range(0, CELL, 20):
		for bx in range(0, CELL, 20):
			var dark := (bx / 20 + by / 20) % 2 == 0
			img.fill_rect(Rect2i(x + bx, y + by, mini(20, CELL - bx), mini(20, CELL - by)),
					Color(0.13, 0.14, 0.18) if dark else Color(0.17, 0.18, 0.23))
