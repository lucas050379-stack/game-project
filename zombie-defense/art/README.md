# art — 그림 파일 넣는 곳

여기에 PNG 를 넣으면 게임이 **자동으로** 그걸 씁니다.
**파일이 없으면 지금까지의 벡터 그림으로 그대로 돌아갑니다** — 하나만 넣어도 되고, 안 넣어도 됩니다.

넣은 뒤 `build.bat` 을 다시 돌리면 exe **안에** 들어갑니다. 배포 파일은 여전히 `zombie-defense.exe` 하나입니다.
런타임에 이 폴더를 읽는 게 아니라 빌드 때 PCK 로 묶이는 방식이라, exe 만 복사해도 그림이 따라갑니다.

## 전신 한 장이 아니라 부위별 컷아웃입니다

**옛날 방식(전신 그림 한 장, 또는 걸음마다 정지 프레임 여러 장을 갈아 끼우는 방식)은 버렸습니다.**
프레임을 아무리 늘려도 결국 몇 장을 스냅해서 보여주는 거라 걸음이 뚝뚝 끊겨 보였습니다.

지금은 **몸통·머리·팔(뒤/앞)·다리(뒤/앞) 6조각**으로 나눠서 넣습니다. 걸을 때 코드
([src/art.gd](../src/art.gd)의 `_cutout_body`, [src/sprites.gd](../src/sprites.gd)의
`Spr.limb_tex`)가 팔다리를 **관절에서 매 프레임 실제로 회전**시켜 그립니다 — 종이인형을
관절마다 오려서 실로 꿰맨 다음 손으로 움직이는 것과 같은 방식(컷아웃 애니메이션)입니다.
정지 프레임이 아니라 각도 계산이라, 몇 장을 넣든 걸음은 항상 매끄럽게 이어집니다.

플레이어(주인공)도 똑같은 컷아웃 방식입니다. 화면에 하나뿐이라 진짜 뼈대(Godot `Skeleton2D`)를
써도 성능에는 문제가 없지만, 이 프로젝트는 애초에 **노드를 하나도 안 만들고 `_draw()` 한 곳에서
전부 그리는 구조**([../CLAUDE.md](../../CLAUDE.md) 참고)라 좀비와 다른 렌더링 방식을 하나
더 얹으면 그리기 순서·카메라 좌표 변환이 두 갈래로 갈라집니다. 그래서 주인공도 좀비와 같은
코드 경로(관절 회전)를 쓰되, 그림만 더 정성 들여 준비하면 됩니다.

## 파일 목록

캐릭터마다 이 6개 이름이 붙습니다: `<이름>_torso.png`, `<이름>_head.png`,
`<이름>_arm_b.png`, `<이름>_arm_f.png`, `<이름>_leg_b.png`, `<이름>_leg_f.png`
(`_b` = back, 뒤쪽/먼저 그려서 몸 뒤로 가는 쪽 · `_f` = front, 앞쪽/나중에 그려서 위로 덮는 쪽).

| 이름 접두어 | 캐릭터 | 화면에 그려지는 몸통 세로 크기 |
|---|---|---|
| `hero` | 플레이어 특공대원 | `r * 1.7` ≈ 29px |
| `zombie` | 기본 좀비 | `r * 1.5` ≈ 21px |
| `runner` | 질주 좀비 | `r * 1.3` ≈ 16px |
| `fat` | 비대 좀비 | `r * 1.7` ≈ 43px |
| `bomber` | 폭탄 좀비 | `r * 1.5` ≈ 24px |
| `spitter` | 침 뱉는 좀비 | `r * 1.3` ≈ 20px |
| `boss` | 변이체 (보스) | `r * 2.0` ≈ 104px |

**캐릭터가 늘어나면** 그 캐릭터의 `art` 접두어(`D.CHAR` 의 `art` 값 — 지금은 `scout`, `heavy`)로
같은 6장을 넣으면 됩니다. `<접두어>_torso.png` 가 있는 순간 `Spr.char_base` 가 자동으로 그쪽을
쓰기 시작합니다. 그 전까지는 `hero` 그림을 `tint` 색으로 물들여 쓰고 있으니, 그림을 제대로
넣었으면 `D.CHAR` 의 `tint` 를 흰색(`Color8(255, 255, 255)`)으로 되돌리세요.

`r` 은 [src/data.gd](../src/data.gd)의 캐릭터 반지름(`D.PLAYER_R`, `D.ENEMY[*]["r"]`)입니다.
머리 크기는 몸통의 약 55~65% 로 자동으로 잡힙니다. 6장을 다 안 채워도 됩니다 — **`_torso` 가
없는 캐릭터는 통째로 지금까지의 벡터 그림으로 돌아가고**, `_torso` 만 있고 나머지가 없으면
그 부위만 안 보입니다(예: `_head` 만 빠지면 머리 없이 그려짐). 6장을 다 갖추는 걸 권합니다.

**지금은 7종 × 6장이 다 채워져 있습니다** — 원래 있던 `sheet_01.png` · `sheet_02.png` 기반
전신/프레임 그림은 새 방식과 안 맞아서 지웠습니다. `gem.png`, `drone.png` 두 개는 걷지 않는
소품이라 그대로 남아 있고 예전 방식(전신 한 장) 그대로 씁니다.

원본 시트는 [source/](source/)에 두고 그 폴더에 `.gdignore` 를 넣어 exe 에서 뺍니다
(안 넣으면 1.9MB 짜리 참조용 시트가 그대로 PCK 에 딸려 들어갑니다 — 실제로 그랬습니다).

크기가 어색하면 그림을 다시 뽑을 필요 없이 [../src/art.gd](../src/art.gd) 에서 해당 캐릭터
함수의 `_cutout_body(...)` 호출에 있는 `torso_h`·`head_h` 인자(`r * 1.7` 같은 값)만 고치면
됩니다.

## 부위별로 그릴 때 지켜야 할 것

### 몸통(`_torso`) · 머리(`_head`) — 지금까지와 같은 규칙

1. **배경 투명 PNG.** 흰 배경이 있으면 사각형이 그대로 보입니다.
2. **오른쪽을 보게.** 왼쪽으로 갈 때는 코드가 알아서 좌우로 뒤집습니다.
3. **부위가 이미지 정중앙.** 위아래·좌우 여백을 비슷하게 두세요.
4. **정사각형 권장** (512×512). 화면에서는 위 표의 크기로 줄여 그립니다.
5. **팔다리 없이 몸통/머리만.** 팔다리는 따로 그려서 코드가 관절에 붙이므로, 몸통 그림에
   팔다리가 같이 그려져 있으면 화면에 팔다리가 두 벌 보입니다.

### 팔(`_arm_b`/`_arm_f`) · 다리(`_leg_b`/`_leg_f`) — 방향·기준점이 다릅니다

**세로로 긴 그림, 위쪽 끝이 관절(어깨/엉덩이)에 붙고 아래로 곧게 뻗은 자세로 그리세요**
(팔이면 아래로 늘어뜨린 자세, 다리면 곧게 편 자세). 코드가 이 "아래로 뻗은 기본 자세"를
걷기 각도만큼 돌리고 관절-끝점 사이 거리에 맞춰 길이를 늘였다 줄였다 합니다. 즉:

- **위쪽 끝 = 관절.** 이미지 위쪽 가로 중앙이 어깨/엉덩이에 딱 붙는 지점입니다.
  여백을 두면 관절이 붕 떠 보입니다.
- **세로가 길이, 가로가 두께.** 정사각형이 아니라 **세로로 긴 비율**(예: 200×420)로 그리세요.
- **곧게 뻗은 중립 자세.** 구부러진 포즈로 그리면 회전시켰을 때 관절이 안 맞습니다.
- 배경 투명, 두꺼운 외곽선 + 평평한 셀 셰이딩은 몸통/머리와 동일합니다.

`_b`(뒤)와 `_f`(앞)는 같은 팔/다리를 그대로 두 번 써도 됩니다 — 코드가 각도만 따로
계산해서 돌리므로, 그림 자체가 달라야 하는 건 아닙니다. 다만 좀비류는 원래 벡터 그림에서
`_b`가 그림자 쪽 색, `_f`가 밝은 쪽 색으로 살짝 갈라져 있었으니, 색만 조금 다르게 두 벌
그리면 더 잘 어울립니다.

## 이미지 AI 프롬프트

그대로 붙여 넣어 쓰시면 됩니다. **공통 조건**을 매번 같이 넣어야 화풍이 맞습니다.

### 공통 조건 (몸통·머리 — 매번 붙이기)

```
2D game character part, flat cel shading with 2 tones, thick dark navy outline,
bold readable silhouette, lit from upper-left, centered in frame with even margins,
transparent background, no ground shadow, no text, no border, mobile game art style
```

### 공통 조건 (팔·다리 — 매번 붙이기)

```
2D game character limb cutout piece, a single arm or leg hanging straight down in a
neutral relaxed pose, the very top edge is the joint attachment point, elongated
vertical shape, flat cel shading with 2 tones, thick dark navy outline,
transparent background, no text, no border, mobile game art style
```

### 캐릭터별 지시문 (부위 공통으로 이어붙이기)

각 캐릭터 지시문 뒤에 "torso only, no arms or legs" / "head only" /
"just the arm, no torso" / "just the leg, no torso" 를 붙여서 부위별로 나눠 뽑으세요.

**hero** (플레이어)
```
a determined soldier in a navy blue tactical uniform, blue combat helmet with a
glowing cyan visor, cyan chest strap, heroic and clean
```

**zombie**
```
a shambling green zombie, tattered clothes, pale green skin, dull white eyes, open jaw
```

**runner**
```
a lean fast zombie, orange-tan skin, glowing red eyes, ragged clothing, sinewy build
```

**fat**
```
an obese bloated zombie, purple-grey mottled skin, a split gash across the belly,
short stubby limbs
```

**bomber**
```
a swollen red zombie with cracks of orange light across the skin, short thick limbs,
about to explode
```

**spitter**
```
a zombie with teal-cyan sickly skin, thin limbs, a bloated green throat sac on the head
```

**boss**
```
a huge hulking mutant boss, magenta-crimson flesh, exposed white ribs on the torso,
two white horns and glowing golden eyes on the head, thin limbs — the asymmetric
giant right arm is handled separately, draw arm_f/arm_b as normal-proportioned limbs
```

### 소품 (전신 한 장, 예전 방식 그대로)

> **젬은 더 이상 그림을 쓰지 않습니다.** 화면에 수백 개가 깔려서 그리기 비용이 컸습니다 —
> 지금은 `draw_circle` 하나로 그리고 발광은 엔진 블룸에 맡깁니다([../src/art.gd](../src/art.gd)
> 의 `Art.gem`). 쓰던 `gem.png` 는 `source/` 로 옮겨 뒀습니다(exe 에는 안 들어갑니다).

**drone.png**
```
2D game sprite, single item, flat cel shading with 2 tones, thick dark navy outline,
transparent background, square 512x512, mobile game art style —
a small green quadcopter combat drone seen from the front,
four rotors, a glowing cyan sensor eye in the center, compact and mechanical
```

## 잘 안 나올 때

### 투명 배경이라더니 체크무늬가 그려져 있다

**가장 자주 겪는 함정입니다.** 이미지 AI 는 "transparent background" 를 달라고 하면
알파 채널을 비우는 대신 **투명을 뜻하는 회색 체크무늬를 그림으로 그려 놓는** 경우가 많습니다.
파일은 멀쩡해 보이지만 알파는 전부 255 입니다. 예전 `sheet_01.png` · `sheet_02.png` 가
정확히 그랬습니다 (지금은 지웠지만 같은 함정을 또 만날 수 있습니다). 처리 순서:

1. **가장자리에서 안으로 번져 들어가며** 밝고 채도 낮은 픽셀을 지웁니다.
   부위 안쪽의 흰색(눈, 갈비뼈 같은 디테일)은 어두운 외곽선에 막혀 살아남습니다.
2. 남은 **밝은 테두리 자국**을 두 겹 깎습니다 (안티에일리어싱 잔여물).
3. **팔 안쪽처럼 갇힌 체크무늬**는 1번이 못 들어갑니다. 채도가 거의 0 인 순회색 덩어리 중
   **일정 크기 이상**인 것만 따로 지웁니다 — 작은 흰색 하이라이트는 남깁니다.

프롬프트에 `on a plain solid magenta background` 를 넣고 그 색을 빼는 쪽이 더 안정적일 때도 있습니다.

### 몸통 그림에 팔이 같이 그려져 왔다

**"torso only, no arms or legs" 를 넣어도 이미지 AI 는 어깨~팔을 같이 그려 옵니다.**
받아 온 7종 중 좀비류 6종이 전부 그랬습니다. 이걸 그대로 쓰면 `_arm_b`/`_arm_f` 조각이
그 위에 또 얹혀 **팔이 두 벌** 보입니다. 팔 조각을 포기하고 몸통째로 기울여 쓰면 팔이
걷기에 맞춰 움직이지 않고 시트 그림과도 달라 보입니다 — 팔을 지우는 쪽이 맞습니다.

[source/dearm.ps1](source/dearm.ps1) 이 그걸 합니다. 세로선으로 뭉텅 자르는 게 아니라
**짙은 외곽선을 벽 삼아 영역을 나눈 뒤 팔에 해당하는 영역만 통째로 지우므로** 자른 자리에
원래 테두리가 그대로 남습니다. 팔과 몸이 같은 색이고 외곽선도 안 닫힌 캐릭터
(`fat`·`bomber`·`boss`)는 경계 폴리라인을 손으로 하나 그어 주면 됩니다.
잘린 자리에는 원본에서 뽑은 외곽선 색을 2px 로 둘러 줍니다.

```
art\source\dearm.ps1        # 캐릭터별 경계값이 이 파일 위쪽 표에 있습니다
```

원본은 `source/torso_original/` 에 그대로 남아 있으니 경계를 다시 잡아 몇 번이든
돌릴 수 있습니다. 새로 그림을 받았으면 `<이름>_torso.png` 를 눈으로 먼저 확인하세요.

### 한 시트에 여러 부위를 몰아서 뽑았다면

**라벨 글자를 조심하세요.** 참고용으로 "hero torso / hero head / hero arm" 처럼 제목과
파일명을 같이 그린 시트를 뽑으면, 글자가 부위 실루엣과 픽셀 한두 개 차이로 거의 붙어서
정렬 기반 크롭이나 연결된 덩어리(connected component) 크롭에 같이 딸려 들어옵니다.
잘라낸 뒤 반드시 가장자리를 눈으로 확인하세요. 화풍을 맞추려면 부위를 낱장으로 하나씩
뽑지 말고 같은 대화(같은 참조 이미지)에서 이어서 뽑는 쪽이 낫습니다.

### 그 밖에

- **후광이 그려져 있으면** — 젬처럼 빛나는 효과를 AI 가 그려 넣으면 체크무늬가 배어 나와
  사각형 자국이 남습니다. 게임이 발광을 따로 그리니 **후광 없이** 뽑는 게 낫습니다.
- **작게 줄이면 뭉개지면** — 세부를 줄이고 실루엣과 외곽선을 굵게. 화면에서는 몸통이
  15~105px 정도입니다 (위 표 참고).
- **어두워서 안 보이면** — 바닥이 짙은 남색입니다. 명도를 한 단계 올리세요.
- **팔다리가 걸을 때 관절에서 벗어나 보이면** — 이미지 위쪽에 여백이 남아 있을 가능성이
  높습니다. 위쪽 끝을 관절 지점까지 딱 붙여서 다시 잘라내세요.
- **팔다리가 배 한가운데에서 자란 것처럼 보이면** — 그림 문제가 아니라 관절 좌표 문제입니다.
  [../src/art.gd](../src/art.gd) 의 해당 캐릭터 `_cutout_body` 호출 바로 위에 있는
  어깨 간격(`shb`/`shf`)과 엉덩이 간격을 **몸통 그림 폭에 맞게** 벌리세요.
- **팔다리가 아예 안 보이면** — 관절과 끝점이 둘 다 몸통 그림 안에 들어가 있는 겁니다.
  몸통이 세로 `r * 1.7` 이면 반지름이 `0.85r` 이므로, 끝점을 그보다 밖으로 밀어야 나옵니다.
- **팔다리가 너무 가늘면** — `Spr.limb_tex` 가 길이에 맞춰 두께도 같이 늘립니다. 두께만 따로
  키우는 값은 없으니 **끝점을 더 멀리** 잡으세요.
