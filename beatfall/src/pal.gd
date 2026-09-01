class_name P
extends RefCounted

## 색 팔레트.
##
## 발광은 HDR(1.0 초과 색)로 내고 엔진 블룸에 맡긴다. 반투명 원을 겹쳐 만들지 않는다.
##
## 리듬게임 색의 제1원칙: **레인 색은 판정 색과 겹치면 안 된다.**
## 노트가 흐르는 색과 "PERFECT" 가 뜨는 색이 같으면, 화면이 빨라졌을 때
## 지금 잘 치고 있는 건지 노트가 쌓인 건지 순간적으로 구분이 안 된다.

# ---------- 바탕 ----------
const VOID := Color8(7, 8, 16)           ## 플레이필드 밖
const BG_TOP := Color8(17, 19, 38)       ## 레인 위쪽
const BG_BOT := Color8(10, 11, 24)       ## 레인 아래쪽 (판정선 부근)
const LANE_EDGE := Color8(41, 46, 82)    ## 레인 구분선
const LANE_LIT := Color8(70, 80, 138)    ## 눌린 레인
const LINE := Color8(6, 7, 14)           ## 외곽선
const PANEL := Color8(13, 15, 30)
const PANEL_EDGE := Color8(38, 43, 76)

const WHITE := Color8(240, 245, 255)
const DIM := Color8(140, 150, 186)
const DIMMER := Color8(84, 92, 122)

# ---------- 노트 ----------
## 레인은 두 종류만 쓴다 — 바깥(흰 건반 자리)과 안쪽(검은 건반 자리).
## 4키·6키 어느 쪽이든 `note_col()` 이 가운데를 기준으로 갈라 준다.
## 레인마다 다른 색을 주면 예뻐 보이지만, 빠른 구간에서 색이 정보가 아니라 소음이 된다.
const NOTE_A := Color8(122, 214, 255)    ## 바깥 레인
const NOTE_A_HI := Color8(210, 242, 255)
const NOTE_B := Color8(196, 150, 255)    ## 안쪽 레인
const NOTE_B_HI := Color8(232, 214, 255)
const HOLD_DIM := Color(0.42, 0.46, 0.62, 1.0)  ## 놓친 롱노트 몸통

# ---------- 판정 ----------
## 노트 색(청록·보라)과 절대 겹치지 않는 축 — 금 → 초록 → 주황 → 적.
const J_PERFECT := Color8(255, 214, 92)
const J_GREAT := Color8(126, 235, 150)
const J_GOOD := Color8(120, 176, 236)
const J_BAD := Color8(240, 148, 74)
const J_MISS := Color8(238, 82, 96)

# ---------- HUD ----------
const HP_OK := Color8(96, 220, 176)
const HP_LOW := Color8(240, 96, 104)
const COMBO := Color8(255, 236, 176)
const BEAT := Color(1.0, 1.0, 1.0, 0.10)


## 색을 1.0 위로 올려 엔진 블룸에 맡긴다. 알파는 건드리지 않는다 —
## 밝기를 낮추려고 여기에 작은 값을 넣으면 색만 검어지고 알파는 1 로 남아 검은 자국이 된다.
## 페이드는 반드시 [method a] 로 한다.
static func hdr(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)


static func a(c: Color, v: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * v)


## 레인 색. 가운데를 기준으로 바깥/안쪽을 나눈다.
## 4키 = A B B A · 6키 = A B A A B A 가 아니라 A B B B B A — 양 끝만 바깥이다.
static func note_col(lane: int, keys: int) -> Color:
	return NOTE_A if (lane == 0 or lane == keys - 1) else NOTE_B


static func note_hi(lane: int, keys: int) -> Color:
	return NOTE_A_HI if (lane == 0 or lane == keys - 1) else NOTE_B_HI


static func judge_col(j: int) -> Color:
	match j:
		0: return J_PERFECT
		1: return J_GREAT
		2: return J_GOOD
		3: return J_BAD
	return J_MISS
