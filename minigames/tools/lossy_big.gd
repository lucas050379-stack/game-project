extends SceneTree

## 큰 그림(긴 변 512 이상)을 손실 압축(WebP, 품질 0.8)으로 가져오게 `.import` 를 고친다 — docs/adr/0011.
##   godot --headless --path . --script res://tools/lossy_big.gd
##   godot --headless --path . --import          ← 그다음 꼭(안 하면 예전 크기 그대로)
## 작은 스프라이트는 무손실로 둔다(테두리 · 외곽선이 뭉개지지 않게). 새 그림을 `post.bat` 으로 넣은 뒤 한 번 돌린다.
## 고친 파일 수를 찍는다. 이미 손실이면 건드리지 않는다.

const MIN_SIDE := 512


func _init() -> void:
	var n := 0
	for dir in ["res://art/", "res://"]:
		n += _scan(dir, dir == "res://art/")
	print("LOSSY BIG: %d 개 .import 를 손실 압축으로 바꿈" % n)
	quit(0)


func _scan(dir: String, deep: bool) -> int:
	var n := 0
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".png"):
			n += _fix(dir + f)
	if deep:
		for d in DirAccess.get_directories_at(dir):
			if d != "source":   # 후보 원본(git 제외)은 안 본다
				n += _scan(dir + d + "/", true)
	return n


func _fix(png: String) -> int:
	var imp := png + ".import"
	if not FileAccess.file_exists(imp):
		return 0
	var img := Image.load_from_file(ProjectSettings.globalize_path(png))
	if img == null or maxi(img.get_width(), img.get_height()) < MIN_SIDE:
		return 0
	var txt := FileAccess.get_file_as_string(imp)
	if not txt.contains("compress/mode=0"):
		return 0
	txt = txt.replace("compress/mode=0", "compress/mode=1").replace("compress/lossy_quality=0.7", "compress/lossy_quality=0.8")
	var f := FileAccess.open(imp, FileAccess.WRITE)
	f.store_string(txt)
	f.close()
	return 1
