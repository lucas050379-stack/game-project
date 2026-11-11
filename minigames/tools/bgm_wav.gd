extends SceneTree
## 배경 음악을 wav 로 굽는다(들어 보기용). 게임과 같은 합성 코드(Bgm)를 그대로 쓴다.
##   godot --headless --path . --script res://tools/bgm_wav.gd -- <출력 폴더> 곡 [곡 ...]     (곡 이름 끝에 ! 를 붙이면 급박 변주)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: -- <out_dir> song [song ...]")
		quit(1)
		return
	var out := args[0]
	DirAccess.make_dir_recursive_absolute(out)
	for i in range(1, args.size()):
		var id := args[i]
		Bgm._start(id)
		while Bgm._job != "":
			Bgm._bake()
		var s: AudioStreamWAV = Bgm._streams.get(id)
		if s == null:
			printerr("굽기 실패: " + id)
			continue
		var path := out.path_join(id.replace("!!", "_tense2").replace("!", "_tense") + ".wav")
		s.save_to_wav(path)
		print("wav %s  %.1f초" % [path, s.data.size() / 2.0 / Bgm.RATE])
	quit(0)
