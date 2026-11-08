class_name MsCmd
extends RefCounted

## 커맨드 판독. 방향 입력을 "누른 순간" 만 시각과 함께 쌓아 두고, 공격 버튼이 눌리면 거꾸로 맞춰 본다.
## 키보드와 터치 십자키가 같은 [method dir] 을 지난다 — 판독은 한 곳뿐이다.
## 방향은 바라보는 쪽 기준으로 바꿔 넣는다(F 앞 · B 뒤 · U · D). 그래서 왼쪽을 볼 때 ←→← 가 돌진이다.

var buf: Array = []      ## [[글자, 시각], ...] 최근 것이 뒤
var now := 0.0


func tick(dt: float) -> void:
	now += dt
	while not buf.is_empty() and now - float(buf[0][1]) > 1.0:
		buf.remove_at(0)   # 짧은 배열(많아야 대여섯)이라 앞에서 빼도 괜찮다


## 방향 하나가 눌렸다. d = "L" "R" "U" "D", facing = 1(오른쪽) / -1.
func dir(d: String, facing: int) -> void:
	var c := d
	if d == "L":
		c = "F" if facing < 0 else "B"
	elif d == "R":
		c = "F" if facing > 0 else "B"
	buf.append([c, now])


## 공격 버튼 — 맞는 기술 이름(없으면 ""). air 는 지금 공중인가. 맞춘 커맨드는 버퍼에서 지운다.
func read(air: bool) -> String:
	for cm in MsD.CMDS:
		if cm.get("ground", false) and air:
			continue
		if cm.get("air", false) and not air:
			continue
		if _match(String(cm.seq)):
			buf.clear()
			return String(cm.move)
	return ""


func _match(seq: String) -> bool:
	var n := seq.length()
	if buf.size() < n:
		return false
	var start := buf.size() - n
	for i in n:
		if String(buf[start + i][0]) != seq[i]:
			return false
	# 첫 방향부터 지금(버튼)까지가 창 안이어야 한다
	return now - float(buf[start][1]) <= MsD.CMD_WINDOW


func clear() -> void:
	buf.clear()
