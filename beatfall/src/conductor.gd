class_name Conductor
extends RefCounted

## 음악 시계. 이 게임에서 제일 중요한 파일이다.
##
## **`_process` 의 delta 를 더해서 곡 위치를 세지 마세요.** 프레임이 한 번 튀면
## 그 오차가 영구히 남고, 3분짜리 곡이면 끝에서 100ms 넘게 밀린다. 그 상태에서
## 판정창을 아무리 다듬어도 곡 후반이 통째로 안 맞는다.
##
## 진짜 시계는 **오디오 하드웨어가 지금까지 재생한 샘플 수**다. Godot 에서는
## `AudioStreamPlayer.get_playback_position()` 으로 얻는데, 이 값은 믹스 블록
## 단위로만 갱신되어 프레임마다 **계단처럼** 움직인다. 그래서 세 가지를 더한다.
##
##   1. `AudioServer.get_time_since_last_mix()` — 마지막 믹스 이후 흐른 시간.
##      계단을 메워 준다.
##   2. `AudioServer.get_output_latency()` — 믹스된 소리가 스피커에서 실제로
##      들리기까지의 지연. **빼야** 한다. 안 빼면 화면이 소리보다 빨라진다.
##   3. [Sv].offset — 사람이 캘리브레이션 화면에서 직접 맞춘 값. 위 둘로도
##      기기마다 남는 차이(블루투스 이어폰은 100ms 넘게 밀린다)를 걷어낸다.
##
## 그 결과를 그대로 쓰지 않고 **판정용**과 **그리기용** 둘로 나눈다. 원값은 계단이라
## 그대로 그리면 노트가 미세하게 떨리고, 다듬은 값으로 판정하면 정확도를 잃는다.
## 판정은 [member pos], 그리기는 [member smooth] 를 본다.

## 곡 시작 전 리드인. 첫 노트가 0초에 있어도 화면에 미리 내려와야 한다.
const LEAD := 2.0

var player: AudioStreamPlayer = null

## 곡 파일 앞에 붙은 무음. 채보가 아니라 여기서 걷어낸다.
var song_offset := 0.0

var playing := false
var length := 0.0

## 판정에 쓰는 위치(초). 오디오 하드웨어에서 바로 나온 값.
var pos := 0.0
## 그리기에 쓰는 위치(초). [member pos] 를 부드럽게 따라간다.
var smooth := 0.0

var _latency := 0.0
var _lead := 0.0
## 리드인 동안에는 재생이 아직 안 걸려 있어 시스템 시계로 센다.
var _lead_usec := 0
var _rolling := false


func attach(p: AudioStreamPlayer) -> void:
	player = p


func start(lead := LEAD) -> void:
	if player == null or player.stream == null:
		return
	length = player.stream.get_length()
	_latency = AudioServer.get_output_latency()
	_lead = maxf(lead, 0.05)
	pos = -_lead
	smooth = -_lead
	playing = true
	_rolling = false
	_lead_usec = Time.get_ticks_usec()
	player.stop()


func stop() -> void:
	playing = false
	if player != null:
		player.stop()


## 매 프레임 한 번.
func tick(delta: float) -> void:
	if not playing:
		return
	if not _rolling:
		pos = -_lead + float(Time.get_ticks_usec() - _lead_usec) / 1000000.0
		smooth = pos
		if pos >= 0.0:
			# 리드인이 끝났다. 이미 지나간 만큼 건너뛴 자리에서 재생을 건다.
			var from := clampf(song_offset + pos, 0.0, maxf(length - 0.01, 0.0))
			player.play(from)
			_rolling = true
		return
	var raw := player.get_playback_position()
	raw += AudioServer.get_time_since_last_mix()
	raw -= _latency
	raw -= Sv.offset
	raw -= song_offset
	pos = raw
	# 그리기용 시계: 늘 앞으로만 가되 원값 쪽으로 끌어당긴다.
	smooth += delta
	var d := pos - smooth
	if absf(d) > 0.08:
		smooth = pos          # 크게 벌어졌으면(끊김) 그냥 맞춘다
	else:
		smooth += d * 0.14


## 곡이 끝났는지. 마지막 노트가 지나고도 조금 더 재생되게 여유를 둔다.
func finished(last_note_t: float) -> bool:
	if not playing:
		return true
	if _rolling and not player.playing:
		return true
	return pos > maxf(length - song_offset, last_note_t) + 0.6
