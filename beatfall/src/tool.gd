extends SceneTree

## 헤드리스 도구. `import.bat` 과 `check.bat` 이 부른다.
##
##   godot --headless --script src/tool.gd -- import --wav=a.wav --out=songs/곡 ...
##   godot --headless --script src/tool.gd -- check
##
## **게임 코드에서 부르지 않는다.** 분석은 곡 하나에 수십 초가 걸리므로
## 판 안에서 돌 물건이 아니다.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var cmd := "" if args.is_empty() else args[0]
	var opt := _opts(args)
	var code := 1
	match cmd:
		"import":
			code = _import(opt)
		"check":
			code = _check()
		"sweep":
			code = _sweep()
		"demo-song":
			code = _demo_song()
		"inspect":
			code = _inspect(opt)
		_:
			print("쓰는 법: tool.gd -- import --wav=<파일> --out=<폴더> [--title=] [--artist=] [--audio=]")
			print("        tool.gd -- check")
	quit(code)


func _opts(args: Array) -> Dictionary:
	var o := {}
	for a in args:
		var s := str(a)
		if not s.begins_with("--"):
			continue
		var i := s.find("=")
		if i < 0:
			o[s.substr(2)] = "1"
		else:
			o[s.substr(2, i - 2)] = s.substr(i + 1)
	return o


# ==================== import ====================

func _import(o: Dictionary) -> int:
	var wav := str(o.get("wav", ""))
	var out := str(o.get("out", ""))
	if wav.is_empty() or out.is_empty():
		printerr("--wav 와 --out 이 필요합니다.")
		return 1
	var t0 := Time.get_ticks_msec()
	print("wav 읽는 중: ", wav)
	var w := An.read_wav(wav)
	if w.is_empty():
		return 1
	var data: PackedFloat32Array = w.data
	var rate: int = w.rate
	var dur := float(data.size()) / rate
	print("  %.1f초 · %dHz · 샘플 %d개" % [dur, rate, data.size()])

	print("스펙트럼 분석 중...")
	var sp := An.spectral(data, rate, func(k): printraw("\r  %d%%   " % int(k * 100.0)))
	print("\r  100%%  (%.1f초)" % ((Time.get_ticks_msec() - t0) / 1000.0))

	var ons := An.onsets(sp)
	print("온셋 %d개" % ons.size())
	if ons.is_empty():
		printerr("온셋을 하나도 못 찾았습니다. 소리가 너무 작거나 무음일 수 있습니다.")
		return 1

	var tp := An.tempo(sp, ons)
	print("BPM 추정 %.2f · 첫 박 %.3f초" % [tp.bpm, tp.phase])

	var title := str(o.get("title", out.get_file()))
	var artist := str(o.get("artist", ""))
	var audio := str(o.get("audio", ""))
	var c := An.build(ons, tp, dur, title, artist, audio)
	if c.diffs.is_empty():
		printerr("채보를 만들지 못했습니다.")
		return 1
	c.bed = str(o.get("bed", ""))
	c.keys = str(o.get("keys", ""))
	_verify_layers(data, str(o.get("bed-wav", "")), str(o.get("keys-wav", "")))

	DirAccess.make_dir_recursive_absolute(out)
	var path := out.path_join("chart.json")
	if not c.save_to(path):
		return 1
	for d in c.diffs:
		print("  %-7s %dK Lv.%-2d  노트 %d개  (초당 %.1f)" % [
			d.name, d.keys, d.level, d.notes.size(),
			float(d.notes.size()) / maxf(dur, 1.0)])
	print("완료: ", path, "  (%.1f초 걸림)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	return 0


## 두 층을 더하면 원곡이 되는지 실제 곡에서 확인한다.
##
## **이게 "다 맞히면 원곡 그대로"의 근거다.** 필터가 겹치거나 벌어지면 저역 근처가
## 두 배가 되거나 파여서, 다 맞혀도 원곡과 다른 곡이 들린다. 귀로는 "원래 이런
## 곡인가" 싶어 못 잡으니 수치로 본다. 1차(6dB/oct) 필터는 저역과 고역을 더하면
## 정확히 원신호로 돌아온다 — 그래서 기울기가 완만한 걸 감수하고 1차를 쓴다.
func _verify_layers(orig: PackedFloat32Array, bed_wav: String, keys_wav: String) -> void:
	if bed_wav.is_empty() or keys_wav.is_empty():
		return
	var b := An.read_wav(bed_wav)
	var k := An.read_wav(keys_wav)
	if b.is_empty() or k.is_empty():
		printerr("층 검사를 건너뜁니다 — 임시 wav 를 못 읽었습니다.")
		return
	var bd: PackedFloat32Array = b.data
	var kd: PackedFloat32Array = k.data
	var n := mini(mini(orig.size(), bd.size()), kd.size())
	var se := 0.0
	var so := 0.0
	for i in range(0, n, 3):
		var d := orig[i] - (bd[i] + kd[i])
		se += d * d
		so += orig[i] * orig[i]
	# 잔차를 원신호 대비 데시벨로. -30dB 아래면 귀로 못 듣는 수준이다.
	var db := 10.0 * log(maxf(se, 1e-12) / maxf(so, 1e-12)) / log(10.0)
	print("층 합산 검사: 잔차 %.1f dB (원곡 대비)" % db)
	if db > -25.0:
		printerr("  두 층의 합이 원곡과 다릅니다 — 다 맞혀도 원곡이 안 나옵니다.")
		printerr("  ffmpeg 필터가 1차(poles=1)인지, 두 차단 주파수가 같은지 보세요.")


# ==================== check ====================
##
## 자체 검증. 데모 곡은 **소리와 채보가 같은 표에서 나오므로 정답을 안다.**
## 그 곡을 wav 로 뽑아 분석기에 넣고, 분석기가 찾아낸 온셋이 원래 소리가 난
## 자리와 얼마나 맞는지 잰다. 실제 mp4 로는 이 검산이 불가능하다.

const TOL := 0.045      ## 이 안에 들면 맞힌 것으로 친다(초). 판정창 GREAT 수준.


func _check() -> int:
	var fail := 0
	fail += _check_warp()
	fail += _check_keys()
	fail += _check_chart_sanity()
	fail += _check_analyzer()
	print("")
	if fail == 0:
		print("모두 통과")
	else:
		printerr("%d개 실패" % fail)
	return 0 if fail == 0 else 1


## 음이탈([Warp])이 **중립일 때 원곡을 건드리지 않는가.**
##
## 이 게임의 약속은 "다 맞히면 원곡 그대로"다. 그런데 효과는 버스에 **항상**
## 얹혀 있으므로, 중립값이 하나라도 어긋나면 잘 치는 사람의 곡이 조용히 상한다.
## 로우패스 기본값이 2000Hz 라 특히 위험하다 — 얹기만 하고 안 올려 두면
## 멀쩡한 곡이 처음부터 먹먹하게 들린다. 귀로는 "원래 이런 곡인가" 싶어서
## 눈치채기 어려우니 여기서 못 박는다.
func _check_warp() -> int:
	print("[0] 음이탈 중립 검사")
	var w := Warp.new()
	w.setup()
	if w.idx < 0:
		printerr("  음악 버스를 못 만들었습니다.")
		return 1
	var bad := 0
	w.apply(0.0)
	var lp: AudioEffectLowPassFilter = null
	var ch: AudioEffectChorus = null
	for i in AudioServer.get_bus_effect_count(w.idx):
		var e := AudioServer.get_bus_effect(w.idx, i)
		if e is AudioEffectLowPassFilter:
			lp = e
		elif e is AudioEffectChorus:
			ch = e
	if lp == null or ch == null:
		printerr("  효과가 안 얹혔습니다.")
		return 1
	var vol := AudioServer.get_bus_volume_db(w.idx)
	print("  중립:  차단 %.0fHz · 코러스 wet %.3f · 볼륨 %.2fdB" % [lp.cutoff_hz, ch.wet, vol])
	if lp.cutoff_hz < 18000.0:
		printerr("  로우패스가 가청 대역을 자르고 있습니다 — 원곡이 먹먹해집니다.")
		bad += 1
	if ch.wet > 0.001:
		printerr("  코러스가 섞이고 있습니다 — 원곡에 없는 흔들림이 붙습니다.")
		bad += 1
	if absf(vol) > 0.01:
		printerr("  볼륨이 0dB 이 아닙니다.")
		bad += 1
	if absf(ch.dry - 1.0) > 0.001:
		printerr("  마른 소리가 온전히 안 지나갑니다.")
		bad += 1
	w.apply(1.0)
	print("  최대:  차단 %.0fHz · 코러스 wet %.3f · 볼륨 %.2fdB" % [
		lp.cutoff_hz, ch.wet, AudioServer.get_bus_volume_db(w.idx)])
	# 완전히 무너졌을 때는 확실히 달라져야 한다. 안 그러면 벌이 안 된다.
	if lp.cutoff_hz > 2000.0 or ch.wet < 0.3:
		printerr("  최대치가 너무 약합니다 — 틀려도 음악이 안 무너집니다.")
		bad += 1
	w.reset()
	# 한 번 놓치면 얼마나 오래 티가 나는지. 너무 짧으면 벌이 안 되고,
	# 너무 길면 한 번 무너진 뒤 곡이 안 돌아온다.
	print("  한 번 놓치면 %.2f초, 완전히 무너지면 %.2f초 걸려 돌아옵니다." % [
		D.WARP_MISS / D.WARP_DECAY, 1.0 / D.WARP_DECAY])
	return bad


## 키음([Keys])의 조각표가 곡을 **빈틈없이** 덮는지.
##
## 조각은 곡을 시간으로 자른 것이라, 이어 붙이면 원곡이 그대로 나와야 한다.
## 틈이 있으면 다 맞혀도 그 자리가 비고(원곡이 아니게 된다), 겹치면 같은 소리가
## 두 번 나서 플랜저처럼 울린다. **귀로는 "원래 이런 곡인가" 싶어 못 잡는다.**
func _check_keys() -> int:
	print("[1] 키음 조각표 검사")
	var bad := 0
	var c := Demo.chart()
	var node := Node.new()
	get_root().add_child(node)
	for di in c.diffs.size():
		var d: Dictionary = c.diffs[di]
		# **[Play] 를 쓰지 않는다.** play.gd 는 오토로드(`Snd`)를 참조하는데
		# `--script` 모드에는 오토로드가 없어서 컴파일 자체가 안 된다.
		# 조각표는 노트 시각만 있으면 만들 수 있으므로 채보에서 바로 만든다.
		var notes: Array = []
		for n in d.notes:
			notes.append({"t": float(n[0])})
		var k := Keys.new()
		# 스트림은 아무거나 있으면 된다 — 여기서 보는 건 조각표지 소리가 아니다.
		k.setup(node, Demo.stream_keys(), notes, Demo.length())
		var gap := 0
		var over := 0
		var prev := 0.0
		for s in k.slices:
			if float(s.start) - prev > 0.001:
				gap += 1
			elif prev - float(s.start) > 0.001:
				over += 1
			prev = float(s.end)
		var tail: float = Demo.length() - prev
		# 노트마다 조각이 있어야 한다. 없으면 그 노트는 쳐도 소리가 안 난다.
		var orphan := 0
		for i in notes.size():
			var si := k.of_note[i]
			if si < 0 or si >= k.slices.size():
				orphan += 1
				continue
			if absf(float(k.slices[si].start) - float(notes[i].t)) > 0.001:
				orphan += 1
		print("  %-7s 노트 %4d · 조각 %4d · 틈 %d · 겹침 %d · 꼬리 %.2f초 · 짝 없는 노트 %d" % [
			d.name, notes.size(), k.slices.size(), gap, over, tail, orphan])
		if gap > 0 or over > 0:
			printerr("  %s: 조각이 곡을 빈틈없이 덮지 못합니다 (틈 %d · 겹침 %d)."
				% [d.name, gap, over])
			bad += 1
		if orphan > 0:
			printerr("  %s: 조각이 없는 노트가 %d개 — 쳐도 소리가 안 납니다." % [d.name, orphan])
			bad += 1
		k.stop()
	node.queue_free()
	# 두 층을 더하면 원곡이 되어야 한다. 데모는 이벤트 표에서 나오므로 정확히 잴 수 있다.
	var full := Demo.stream()
	var bed := Demo.stream_bed()
	var keysl := Demo.stream_keys()
	var n := mini(mini(full.data.size(), bed.data.size()), keysl.data.size()) / 2
	var worst := 0
	for i in range(0, n, 7):        # 전부 볼 필요는 없다. 7샘플마다면 충분히 촘촘하다
		var a := full.data.decode_s16(i * 2)
		var b := bed.data.decode_s16(i * 2) + keysl.data.decode_s16(i * 2)
		worst = maxi(worst, absi(a - b))
	print("  바닥층 + 키음층 vs 원곡: 최대 오차 %d / 32000" % worst)
	# 층마다 따로 정규화하면 여기가 크게 벌어진다. 반올림 오차만 남아야 한다.
	if worst > 4:
		printerr("  두 층의 합이 원곡과 다릅니다 — 이득(gain)이 층마다 따로 잡혔습니다.")
		bad += 1
	return bad


## 채보가 사람이 칠 수 있는 모양인지. 여기서 걸리면 게임이 아니라 채보가 문제다.
func _check_chart_sanity() -> int:
	print("[2] 데모 채보 검사")
	var c := Demo.chart()
	var bad := 0
	for d in c.diffs:
		var last := PackedFloat32Array()
		last.resize(d.keys)
		last.fill(-99.0)
		var prev_t := -99.0
		var clash := 0
		for n in d.notes:
			var t: float = n[0]
			var lane: int = n[1]
			if t < prev_t:
				printerr("  %s: 시각이 거꾸로 갑니다 (%.3f < %.3f)" % [d.name, t, prev_t])
				bad += 1
				break
			prev_t = t
			if t - last[lane] < D.AN_SAME_LANE_GAP:
				clash += 1
			last[lane] = t
		var span: float = d.notes[d.notes.size() - 1][0] - d.notes[0][0]
		print("  %-7s %dK Lv.%-2d 노트 %4d개 · 초당 %.2f · 겹침 %d" % [
			d.name, d.keys, d.level, d.notes.size(),
			float(d.notes.size()) / span, clash])
		if clash > 0:
			printerr("  %s: 한 손으로 못 치는 자리가 %d군데 있습니다." % [d.name, clash])
			bad += 1
	return bad


# ==================== inspect ====================
##
## 만들어진 채보를 뜯어본다. `import` 가 끝난 뒤 **사람이 쳐 보기 전에** 거르는 관문이다.
##
## 자동 채보는 소리를 잘 찾아도 **칠 수 없는 채보**를 만들 수 있다. 실제로 확인해야
## 하는 것은 셋이다.
##   1. 한 손으로 못 치는 자리 (같은 레인 연타)
##   2. 노트가 아예 없는 구간 — 곡은 흐르는데 화면이 비면 그냥 멈춘 것처럼 보인다
##   3. 사람 손을 넘는 밀도 — 순간 초당 20노트 같은 구간

func _inspect(o: Dictionary) -> int:
	var songs := Song.scan()
	var want := str(o.get("song", ""))
	var any := false
	for s in songs:
		if not want.is_empty() and s.id != want:
			continue
		any = true
		_inspect_song(s)
	if not any:
		printerr("그런 곡이 없습니다: ", want)
		print("있는 곡: ", ", ".join(songs.map(func(s): return s.id)))
		return 1
	return 0


func _inspect_song(s: Song) -> void:
	var c := s.chart
	print("\n== %s  (%s)  BPM %.2f ==" % [s.id, c.title, c.bpm])
	for di in c.diffs.size():
		var d: Dictionary = c.diffs[di]
		var notes: Array = d.notes
		if notes.is_empty():
			continue
		var last := PackedFloat32Array()
		last.resize(d.keys)
		last.fill(-99.0)
		var clash := 0
		var holds := 0
		var span: float = float(notes[notes.size() - 1][0]) + float(notes[notes.size() - 1][2])
		# 10초 칸으로 밀도를 센다. 빈 구간과 몰린 구간이 여기서 보인다.
		var slots := maxi(1, int(ceil(span / 10.0)))
		var per := PackedInt32Array()
		per.resize(slots)
		for n in notes:
			var t := float(n[0])
			var lane := int(n[1])
			if t - last[lane] < D.AN_SAME_LANE_GAP:
				clash += 1
			last[lane] = t + float(n[2])
			if float(n[2]) > 0.0:
				holds += 1
			per[clampi(int(t / 10.0), 0, slots - 1)] += 1
		# 순간 최대 밀도: 1초 창을 밀며 가장 많이 든 곳.
		var peak := 0
		var j := 0
		for i in notes.size():
			while float(notes[i][0]) - float(notes[j][0]) > 1.0:
				j += 1
			peak = maxi(peak, i - j + 1)
		var empty := 0
		var lo := 999
		for v in per:
			if v == 0:
				empty += 1
			lo = mini(lo, v)
		print("  %-7s %dK Lv.%-2d 노트 %4d · 초당 %.2f · 순간최대 %d/초 · 롱 %d(%.0f%%) · 겹침 %d · 빈 10초칸 %d/%d" % [
			d.name, d.keys, d.level, notes.size(), float(notes.size()) / span,
			peak, holds, float(holds) / notes.size() * 100.0, clash, empty, slots])
		if clash > 0:
			printerr("    한 손으로 못 치는 자리가 %d군데 있습니다." % clash)
		if empty > 0:
			printerr("    노트가 하나도 없는 10초 칸이 %d개 있습니다." % empty)
		if peak > d.keys * 4:
			printerr("    순간 밀도가 %d/초 입니다 — 사람 손을 넘습니다." % peak)


# ==================== demo-song ====================
##
## 데모 곡을 wav 로 굳혀 `songs/demo-auto/` 에 넣고, 자동 채보까지 태운다.
##
## **ffmpeg 없이 곡 넣기 경로 전체를 확인하는 방법이다.** 내장 데모는 코드에서
## 바로 오므로 파일 읽기·6키·롱노트를 하나도 안 지난다. 여기서 나온 곡은
## 사용자가 mp4 로 넣은 곡과 **완전히 같은 경로**를 지난다.

func _demo_song() -> int:
	var out := ProjectSettings.globalize_path("res://songs/demo-auto")
	DirAccess.make_dir_recursive_absolute(out)
	var wav := out.path_join("audio.wav")
	if not _write_wav(Demo.stream(), wav):
		return 1
	print("wav 를 썼습니다: ", wav)
	return _import({"wav": wav, "out": out, "audio": "audio.wav",
		"title": "데모 (자동 채보)", "artist": "analyze.gd"})


## AudioStreamWAV 를 디스크의 RIFF 파일로. 분석기가 읽는 형식 그대로 쓴다.
func _write_wav(st: AudioStreamWAV, path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("wav 를 쓰지 못했습니다: ", path)
		return false
	var pcm := st.data
	var ch := 2 if st.stereo else 1
	var rate := st.mix_rate
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + pcm.size())
	f.store_buffer("WAVE".to_ascii_buffer())
	f.store_buffer("fmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)                       # PCM
	f.store_16(ch)
	f.store_32(rate)
	f.store_32(rate * ch * 2)           # 초당 바이트
	f.store_16(ch * 2)                  # 블록 정렬
	f.store_16(16)                      # 비트
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(pcm.size())
	f.store_buffer(pcm)
	f.close()
	return true


# ==================== sweep ====================
##
## 온셋 문턱을 격자로 훑어 재현율과 정밀도를 같이 본다.
##
## **문턱은 감으로 정하면 안 된다.** 하나를 올리면 다른 하나가 내려가는 맞바꿈이라,
## 한 값만 보고 고치면 반대쪽이 조용히 나빠진다. 스펙트럼은 한 번만 구하고
## 문턱만 바꿔 가며 [method An.onsets] 를 다시 부르므로 격자 하나가 순식간이다.

func _sweep() -> int:
	var truth := _truth()
	var data := _demo_samples()
	var sp := An.spectral(data, Demo.RATE, Callable())
	print("문턱 스윕 — 재현율(놓치지 않는가) · 정밀도(없는 걸 만들지 않는가)")
	print("  mul   sd   온셋   재현율  정밀도   F1")
	var best_f1 := 0.0
	var best := ""
	for mul in [1.15, 1.25, 1.35, 1.45]:
		for sdw in [0.0, 0.2, 0.35, 0.5, 0.75, 1.1]:
			var ons := An.onsets(sp, mul, sdw)
			var m := _match(ons, truth)
			var f1 := 0.0
			if m.recall + m.prec > 0.0:
				f1 = 2.0 * m.recall * m.prec / (m.recall + m.prec)
			print("  %.2f  %.2f  %4d   %5.1f%%  %5.1f%%  %.3f" % [
				mul, sdw, ons.size(), m.recall * 100.0, m.prec * 100.0, f1])
			if f1 > best_f1:
				best_f1 = f1
				best = "mul=%.2f sd=%.2f" % [mul, sdw]
	print("가장 나은 조합: ", best, "  F1 %.3f" % best_f1)
	return 0


## 데모 곡을 float 샘플로.
func _demo_samples() -> PackedFloat32Array:
	var st := Demo.stream()
	var n := st.data.size() / 2
	var data := PackedFloat32Array()
	data.resize(n)
	var raw := st.data
	for i in n:
		data[i] = float(raw.decode_s16(i * 2)) / 32768.0
	return data


## 정답 시각(베이스 제외).
func _truth() -> Array:
	var t: Array = []
	for e in Demo.events():
		if e.kind != Demo.BASS:
			t.append(float(e.t))
	t.sort()
	return t


func _match(ons: Array, truth: Array) -> Dictionary:
	var found := 0
	for t in truth:
		for o in ons:
			if absf(float(o.t) - float(t)) <= TOL:
				found += 1
				break
	var hit := 0
	for o in ons:
		for t in truth:
			if absf(float(o.t) - float(t)) <= TOL:
				hit += 1
				break
	return {"recall": float(found) / maxi(truth.size(), 1),
		"prec": float(hit) / maxi(ons.size(), 1)}


## 분석기가 데모 곡의 소리를 실제로 찾아내는지.
func _check_analyzer() -> int:
	print("[3] 자동 채보 검사 (데모 곡을 정답지로)")
	var t0 := Time.get_ticks_msec()
	var st := Demo.stream()
	var n := st.data.size() / 2
	var data := PackedFloat32Array()
	data.resize(n)
	var raw := st.data
	for i in n:
		data[i] = float(raw.decode_s16(i * 2)) / 32768.0
	var t1 := Time.get_ticks_msec()
	var sp := An.spectral(data, Demo.RATE, Callable())
	var t2 := Time.get_ticks_msec()
	var ons := An.onsets(sp)
	var t3 := Time.get_ticks_msec()
	var tp := An.tempo(sp, ons)
	var t4 := Time.get_ticks_msec()
	print("  걸린 시간 — 곡 합성 %.1fs · 스펙트럼 %.1fs · 온셋 %.1fs · BPM %.1fs" % [
		(t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0, (t4 - t3) / 1000.0])
	print("  온셋 %d개 · BPM 추정 %.2f (실제 %.1f)" % [ons.size(), tp.bpm, Demo.BPM])

	var bad := 0
	# BPM 은 절반/두 배도 맞는 것으로 친다 — 사람도 그렇게 듣는다.
	var r: float = float(tp.bpm) / Demo.BPM
	if absf(r - 1.0) > 0.03 and absf(r - 2.0) > 0.06 and absf(r - 0.5) > 0.015:
		printerr("  BPM 이 어긋났습니다: %.2f (실제 %.1f)" % [tp.bpm, Demo.BPM])
		bad += 1

	# 정답: 데모의 소리 중 채보로 쓰는 것들(킥·스네어·리드·하이햇)의 시각.
	#
	# **악기별로 따로 잰다.** 전체 재현율 하나만 보면 어디가 약한지 알 수가 없어서
	# 문턱을 감으로 만지게 된다. 킥을 놓치는 것과 하이햇을 놓치는 것은 전혀 다른
	# 문제이고, 고칠 곳도 다르다.
	var kind_name := {Demo.KICK: "킥", Demo.SNARE: "스네어", Demo.HAT: "하이햇",
		Demo.LEAD: "리드"}
	var truth: Array = []
	var per := {}
	for e in Demo.events():
		if e.kind == Demo.BASS:
			continue
		truth.append(float(e.t))
		if not per.has(e.kind):
			per[e.kind] = [0, 0]
		var hitk := false
		for o in ons:
			if absf(float(o.t) - float(e.t)) <= TOL:
				hitk = true
				break
		per[e.kind][0] += 1
		if hitk:
			per[e.kind][1] += 1
	truth.sort()
	var found := 0
	for t in truth:
		for o in ons:
			if absf(float(o.t) - t) <= TOL:
				found += 1
				break
	var recall := float(found) / truth.size()
	# **체계적 지연을 잰다.** FFT 창이 46ms 라 온셋 시각은 원래 소리보다 늦게 잡힌다.
	# 이 편차가 판정창만큼 커지면 채보 전체가 곡보다 늦어서 못 치는 채보가 된다.
	# 넉넉한 허용치로 짝을 지어 중앙값을 본다 — 평균은 짝이 잘못 지어진 하나에 끌려간다.
	var errs: Array = []
	for t in truth:
		var best := 99.0
		for o in ons:
			var e: float = float(o.t) - float(t)
			if absf(e) < absf(best):
				best = e
		if absf(best) <= 0.12:
			errs.append(best)
	if not errs.is_empty():
		errs.sort()
		var med: float = errs[errs.size() / 2]
		print("  시각 편차 중앙값 %+.1f ms (짝지은 %d개) — 양수면 채보가 곡보다 늦다" % [
			med * 1000.0, errs.size()])
	for k in [Demo.KICK, Demo.SNARE, Demo.LEAD, Demo.HAT]:
		if not per.has(k):
			continue
		print("    %-6s %3d개 중 %3d개 — %.0f%%" % [kind_name[k], per[k][0], per[k][1],
			float(per[k][1]) / per[k][0] * 100.0])
	print("  실제 소리 %d개 중 %d개를 찾음 — 재현율 %.1f%%" % [truth.size(), found, recall * 100.0])
	if recall < 0.88:
		printerr("  재현율이 88%% 아래입니다. 온셋 문턱(D.AN_THRESH_*)을 보세요.")
		bad += 1

	# 반대로, 분석기가 찾은 것 중 실제 소리가 없는 자리(허위)가 얼마나 되는지.
	var hit := 0
	for o in ons:
		for t in truth:
			if absf(float(o.t) - t) <= TOL:
				hit += 1
				break
	var prec := float(hit) / maxi(ons.size(), 1)
	print("  찾은 것 %d개 중 %d개가 진짜 — 정밀도 %.1f%%" % [ons.size(), hit, prec * 100.0])

	# 지속 시간 분포. 롱노트가 과하게 나올 때 어디가 문제인지 여기서 바로 보인다.
	var edges := [0.05, 0.10, 0.15, 0.20, 0.28, 0.40, 0.60, 1.00, 99.0]
	var bins := PackedInt32Array()
	bins.resize(edges.size())
	for o in ons:
		for bi in edges.size():
			if float(o.dur) < float(edges[bi]):
				bins[bi] += 1
				break
	var line := "  지속시간 분포:"
	for bi in edges.size():
		line += "  <%.2f:%d" % [float(edges[bi]), bins[bi]]
	print(line)
	# 패드(유일하게 실제로 이어지는 소리)와 킥(가장 짧은 소리)의 지속 시간을 견준다.
	#
	# **대역까지 맞춰서 짝지어야 한다.** 데모의 패드는 마디 첫 박, 즉 킥과 같은
	# 시각에 난다 — 시각만 보고 짝지으면 킥의 온셋이 패드로 잡히거나 그 반대가 되어
	# 두 중앙값이 늘 같게 나온다(실제로 0.39 대 0.37 이었다). 대역이 두 소리를
	# 갈라 준다: 킥은 0번(0~110Hz), 패드는 2번(260~620Hz).
	var pad_d: Array = []
	var kick_d: Array = []
	for e in Demo.events():
		var band := -1
		if e.kind == Demo.PAD:
			band = 2
		elif e.kind == Demo.KICK:
			band = 0
		else:
			continue
		for o in ons:
			if int(o.band) == band and absf(float(o.t) - float(e.t)) <= TOL:
				if e.kind == Demo.PAD:
					pad_d.append(float(o.dur))
				else:
					kick_d.append(float(o.dur))
				break
	pad_d.sort()
	kick_d.sort()
	if not pad_d.is_empty() and not kick_d.is_empty():
		var pm: float = pad_d[pad_d.size() / 2]
		var km: float = kick_d[kick_d.size() / 2]
		print("  지속시간 중앙값 — 패드(실제 0.89초) %.2f초 [%d개] · 킥(실제 0.08초) %.2f초 [%d개]" % [
			pm, pad_d.size(), km, kick_d.size()])
		# 이어지는 소리와 때리는 소리가 갈려야 롱노트가 의미를 가진다.
		if pm < D.AN_HOLD_MIN or km >= D.AN_HOLD_MIN:
			printerr("  지속음과 타악기가 안 갈립니다 — 롱노트가 아무 데나 붙거나 하나도 안 붙습니다.")
			bad += 1
	if prec < 0.70:
		printerr("  정밀도가 70%% 아래입니다. 없는 노트가 채보에 섞입니다.")
		bad += 1

	# 만들어진 채보도 사람이 칠 수 있는지 본다.
	var c := An.build(ons, tp, float(n) / Demo.RATE, "검사", "", "")
	for d in c.diffs:
		var last := PackedFloat32Array()
		last.resize(d.keys)
		last.fill(-99.0)
		var clash := 0
		var holds := 0
		for note in d.notes:
			var lane := int(note[1])
			# 롱노트는 끝날 때까지 그 레인을 잡고 있다. 겹침 판정도 끝 시각으로 본다.
			if float(note[0]) - last[lane] < D.AN_SAME_LANE_GAP:
				clash += 1
			last[lane] = float(note[0]) + float(note[2])
			if float(note[2]) > 0.0:
				holds += 1
		var hratio := float(holds) / maxi(d.notes.size(), 1)
		print("  %-7s %dK 노트 %4d개 · 겹침 %d · 롱노트 %d (%.0f%%)" % [
			d.name, d.keys, d.notes.size(), clash, holds, hratio * 100.0])
		if clash > 0:
			printerr("  %s: 한 손으로 못 치는 자리가 %d군데 있습니다." % [d.name, clash])
			bad += 1
		# **롱노트가 다수가 되면 안 된다.** `_sustain` 이 절대값으로 재던 시절
		# 노트의 88%가 롱노트였다 — 그러면 손가락이 계속 눌려 있어서 칠 것이 없다.
		if hratio > 0.35:
			printerr("  %s: 롱노트가 %.0f%% 입니다. _sustain 이 길이를 과하게 잡고 있습니다."
				% [d.name, hratio * 100.0])
			bad += 1
	return bad
