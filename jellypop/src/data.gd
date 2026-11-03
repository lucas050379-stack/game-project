class_name D
extends RefCounted

## 수치는 전부 여기에 모은다 — 판 · 점수 · 피버 · 움직임 · 이펙트.
## 손맛을 맞출 때는 이 파일만 고친다.

# ==================== 판 ====================

const W := 7
const H := 7
const COLORS := 6

## 특수 블록 종류. 판(`Board.sp`)에 그대로 들어간다.
const SP_NONE := 0
const SP_LINE_H := 1     ## 가로 4개 → 그 줄(가로) 전부
const SP_LINE_V := 2     ## 세로 4개 → 그 칸(세로) 전부
const SP_AREA := 3       ## L·T 자 → 둘레 AREA_R 칸
const SP_RAINBOW := 4    ## 5개 일자 → 바꾼 상대 색 전부

const SP_FLY := 5        ## 2×2 네모 → 날아가서 한 칸을 친다 (장애물 · 몬스터부터 노림)

const AREA_R := 1        ## 1 = 3×3
const BIG_R := 2         ## 범위 + 범위 = 5×5

# ==================== 스테이지 모드 ====================

## 한 수 안의 연쇄마다 점수 +25%. 스테이지 모드에는 시간 콤보가 없다.
const CHAIN_STEP := 0.50
const OBS_PTS := 20      ## 장애물 · 몬스터를 한 번 칠 때마다

## 몬스터 피해. 옆에서 젤리가 터지면 터진 수만큼, 특수 젤리에 맞으면 BLAST_DMG.
const ADJ_DMG := 1
const BLAST_DMG := 3

## 몬스터는 `every` 턴마다 한 번 행동한다. **행동 한 턴 전에 노리는 칸을 정해 화면에 표시한다** —
## 경고 없이 행동하면 막을 방법이 없어서 난이도가 아니라 운이 된다. 정한 칸은 바꾸지 않는다.
const MON := {
	"dough": {"name": "꾸덕이", "hp": 8, "every": 3},   # 옆 젤리 하나를 쿠키 상자로 굳힌다
	"knot": {"name": "매듭이", "hp": 10, "every": 4},    # 자기 줄의 젤리 몇 개를 사슬로 묶는다
	"thief": {"name": "슬쩍이", "hp": 8, "every": 3},    # 이동 하나를 훔친다. 쓰러뜨리면 돌려받는다
	"frost": {"name": "얼음뿔", "hp": 10, "every": 3},   # 옆 젤리 하나를 얼린다
	"ninja": {"name": "그림자", "hp": 14, "every": 3},   # 아무 젤리 하나를 분신으로 바꾼다(분신은 한 대에 사라진다)
	"glutton": {"name": "먹보", "hp": 14, "every": 2},
	"octo": {"name": "문어발", "hp": 14, "every": 2},    # 근처 젤리 둘을 거미줄 두 겹으로 붙든다
	"boss": {"name": "대왕꾸덕", "hp": 24, "every": 4},  # 근처 젤리 하나를 새끼 꾸덕이로 바꾼다   # 옆 젤리를 먹고 1 회복. 특수 젤리를 먹으면 GLUTTON_SICK 만큼 다친다
}
const GLUTTON_SICK := 5
const BOSS_MINION_HP := 4
const KNOT_MAX := 4

const FRUIT_MAX_ON := 2      ## 판 위에 동시에 떠 있는 열매 상한
const FRUIT_CHANCE := 0.18   ## 위에서 새로 채울 때 열매가 나올 확률(남은 수가 있을 때만)

## 별 문턱은 스테이지마다 `check.bat tune` 이 잰다(Stages.STARS). 이건 표에 없을 때의 대비값.
const STAR2_PER_MOVE := 90
const STAR3_PER_MOVE := 140

## 이기고 남은 이동 하나당 주는 점수(줄 폭탄과 별개). **별 3개로 가는 길이 이것이다** —
## 미션을 깨면 판이 끝나므로, 점수를 더 내는 방법은 "이동을 남기고 빨리 깨는 것" 뿐이다.
## 남은 이동이 점수에 크게 안 닿으면 별 문턱을 넘을 방법 자체가 없어진다(실제로 그랬다).
const BONUS_MOVE_PTS := 150

const BONUS_STEP_T := 0.12   ## 이기고 남은 이동 하나당 줄 폭탄 하나 — 그 간격

# ==================== 한 판 ====================

const GAME_T := 60.0
const WARN_T := 10.0     ## 이 아래로 내려가면 테두리가 붉게 맥동하고 초침이 운다

const BLOCK_PTS := 20
## 콤보 하나당 블록 점수 +10%. 콤보는 "연쇄"가 아니라 "빨리 이어서 맞춘 횟수"다 —
## 연쇄만 세면 운이고, 손이 빠른 것이 점수가 되어야 한다.
const COMBO_STEP := 0.10
const COMBO_KEEP := 2.2  ## 이 시간 안에 다음 터짐이 없으면 콤보가 끊긴다
const SP_BONUS := 80     ## 특수 블록이 터질 때마다 얹는 점수

## 특수 젤리를 **만들면** 주는 점수. 예전에는 0 이라 5개를 이어 무지개를 만들어도 5칸 × 10점이
## 전부였고, 그래서 잘 두는 사람과 아무 수나 두는 봇의 점수 차가 거의 없어 별 셋이 운이었다.
## 봇은 특수를 일부러 안 만드므로 이 몫이 곧 "실력으로 버는 점수"다.
const MADE_PTS := {1: 150, 2: 150, 3: 250, 4: 500, 5: 150}   ## SP_LINE_H · LINE_V · AREA · RAINBOW · FLY
## 특수끼리 합쳤을 때 얹는 점수(Play._combo 의 kind)
const COMBO_PTS := {"cross": 400, "bigcross": 600, "big": 800, "fly2": 400, "fly_carry": 500,
		"rainbow": 300, "rainbow_sp": 1200, "rainbow2": 2000}

const FEVER_PER_BLOCK := 0.022
const FEVER_DECAY := 0.05    ## 초당. 쉬면 조금씩 빠진다
const FEVER_T := 8.0
const FEVER_MUL := 2

const HINT_T := 4.0      ## 손을 안 대고 이만큼 지나면 둘 수 있는 수를 흔들어 보여 준다

# ==================== 움직임 (초 · 칸 단위) ====================

const SWAP_T := 0.14
const POP_T := 0.16          ## 맞춰진 블록이 부풀었다가 터지기까지
const FALL_G := 70.0         ## 칸/초²
const FALL_VMAX := 20.0      ## 칸/초
const LAND_T := 0.28         ## 착지 찌그러짐이 풀리는 시간
const LAND_SQUASH := 0.22    ## 착지 순간 가로로 퍼지는 양
const FALL_STRETCH := 0.012  ## 낙하 속도(칸/초) 하나당 세로로 늘어나는 양
const BREATH := 0.03         ## 대기 숨쉬기 폭
const BLINK_GAP := Vector2(2.0, 6.0)

## AI 그림 몸통 위에 얼굴을 얹을 자리(반지름 단위). 벡터 몸통은 다 가운데라 0 이다.
## 그림을 넣었는데 얼굴이 이마에 붙으면 여기를 고친다.
const FACE_AT := [
	Vector2(0, 0.05), Vector2(0, 0.05), Vector2(0, 0.12),
	Vector2(0, 0.18), Vector2(0, 0.22), Vector2(0, 0.0), Vector2(0, 0.05),
]

# ==================== 이펙트 ====================

## 파티클 상한. 다 차면 가장 오래된 자리를 돌려 쓴다(`pop_front` 는 배열을 통째로 당긴다).
## shortcut: 웹에서 실측하지 않은 값이다, 폰 브라우저에서 프레임이 떨어지면 낮춘다.
const FX_MAX := 300
const SHARDS := 6
const SPARKS := 4
const SHAKE_AREA := 10.0
const SHAKE_RAINBOW := 14.0

# ==================== 색 ====================

## 블록 색 6종. **색만으로 가르지 않는다** — 모양(`Art.SHAPE`)도 다 다르다.
const JELLY := [
	Color8(255, 92, 110),    # 0 딸기 · 동그라미
	Color8(255, 160, 60),    # 1 귤 · 둥근 네모
	Color8(255, 216, 64),    # 2 레몬 · 별
	Color8(110, 214, 92),    # 3 메론 · 물방울
	Color8(80, 170, 255),    # 4 소다 · 세모
	Color8(186, 110, 255),   # 5 포도 · 하트
	Color8(255, 150, 190),   # 6 복숭아 · 다이아몬드 (6색 판에만 나온다)
]
const NAMES := ["딸기", "귤", "레몬", "메론", "소다", "포도", "복숭아"]

const COOKIE := [Color8(232, 184, 120), Color8(196, 132, 74), Color8(150, 92, 52)]   ## 쿠키 상자 1~3겹
const CHOCO_C := Color8(110, 62, 40)
const SUGAR_C := Color8(255, 150, 200)
const ICE_C := Color8(190, 236, 255)
const CHAIN_C := Color8(255, 236, 246)
const FRUIT_C := Color8(220, 40, 70)
const FIELD_C := Color8(110, 150, 255)
const PIPE_C := Color8(150, 165, 185)
const CAPSULE_C := Color8(120, 220, 150)
const LOCK_C := Color8(255, 200, 80)
const GIFT_C := Color8(255, 110, 150)
const CLOUD_C := Color8(240, 244, 255)
const WEB_C := Color8(235, 235, 245)
const STEEL_C := Color8(150, 160, 175)
const PAINT_C := Color8(120, 200, 255)
const FIRE_C := Color8(255, 150, 60)
