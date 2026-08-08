# art — 그림 파일 넣는 곳

여기에 PNG 를 넣으면 게임이 **자동으로** 그걸 씁니다.
**파일이 없으면 지금까지의 벡터 그림으로 그대로 돌아갑니다** — 하나만 넣어도 되고, 안 넣어도 됩니다.

넣은 뒤 `build.bat` 을 다시 돌리면 exe **안에** 들어갑니다. 배포 파일은 여전히 `zombie-defense.exe` 하나입니다.
런타임에 이 폴더를 읽는 게 아니라 빌드 때 PCK 로 묶이는 방식이라, exe 만 복사해도 그림이 따라갑니다.

## 파일 목록

| 파일 이름 | 무엇 | 화면에 그려지는 세로 크기 |
|---|---|---|
| `hero.png` | 플레이어 특공대원 | 약 65px |
| `zombie.png` | 기본 좀비 | 약 49px |
| `runner.png` | 질주 좀비 | 약 42px |
| `fat.png` | 비대 좀비 | 약 88px |
| `bomber.png` | 폭탄 좀비 | 약 56px |
| `spitter.png` | 침 뱉는 좀비 | 약 53px |
| `boss.png` | 변이체 (보스) | 약 182px |
| `gem.png` | 경험치 결정 | 약 21px |
| `drone.png` | 드론 | 약 34px |

**9장 모두 이미 들어가 있습니다.** 바꾸고 싶은 것만 같은 이름으로 덮어쓰면 됩니다.
원본 시트는 [source/](source/) 에 두었습니다 — 그 폴더에는 `.gdignore` 가 있어서
고도가 건너뛰므로 exe 에 들어가지 않습니다.

크기가 어색하면 그림을 다시 뽑을 필요 없이 [../src/art.gd](../src/art.gd) 의
`Spr.blit(...)` 배율만 고치면 됩니다 (적 `r * 3.5`, 플레이어 `r * 3.8`).

`<이름>_b.png` 를 같이 넣으면 **걸을 때 두 프레임이 번갈아** 나옵니다 (예: `zombie_b.png`).
없어도 되고, 없으면 몸이 위아래로 까딱이는 것으로 대신합니다.

## 만들 때 지켜야 할 것

이 네 가지만 맞으면 코드는 손댈 필요가 없습니다.

1. **배경 투명 PNG.** 흰 배경이 있으면 사각형이 그대로 보입니다.
2. **오른쪽을 보게.** 왼쪽으로 갈 때는 코드가 알아서 좌우로 뒤집습니다.
3. **캐릭터가 이미지 정중앙.** 위아래·좌우 여백을 비슷하게 두세요.
   가운데가 어긋나면 발이 그림자에서 떠 보입니다.
4. **정사각형, 512×512 권장.** 화면에서는 위 표의 크기로 줄여 그립니다.

스타일은 **두꺼운 검은 외곽선 + 평평한 셀 셰이딩**으로 통일하세요.
어두운 남색 바닥 위에 올라가므로 **색이 너무 어두우면 묻힙니다.**

## 이미지 AI 프롬프트

그대로 붙여 넣어 쓰시면 됩니다. 앞의 **공통 조건**을 매번 같이 넣어야 9장의 화풍이 맞습니다.

### 공통 조건 (매번 붙이기)

```
2D game sprite, single character, full body, facing right, side-scroller style,
flat cel shading with 2 tones, thick dark navy outline, bold readable silhouette,
lit from upper-left, centered in frame with even margins,
transparent background, no ground shadow, no text, no border,
square 512x512, mobile game art style
```

### 각 파일

**hero.png**
```
a determined soldier in a navy blue tactical uniform, blue combat helmet with a
glowing cyan visor, cyan chest strap, holding an assault rifle pointed to the right,
standing in a firing stance, heroic and clean
```

**zombie.png**
```
a shambling green zombie, hunched back, both arms stretched forward,
tattered clothes, pale green skin, dull white eyes, open jaw
```

**runner.png**
```
a lean fast zombie sprinting, body leaning far forward, arms swept back,
long stride, orange-tan skin, glowing red eyes, ragged clothing
```

**fat.png**
```
an obese bloated zombie, huge belly, tiny head, short stubby legs,
purple-grey mottled skin, a split gash across the belly, slow and heavy
```

**bomber.png**
```
a swollen red zombie with a glowing orange core bulging in its belly,
short arms and legs, cracks of orange light across the skin, about to explode
```

**spitter.png**
```
a zombie with a long stretched neck and a bloated green throat sac,
wide open mouth ready to spit acid, teal-cyan sickly skin, thin limbs
```

**boss.png**
```
a huge hulking mutant boss, massive asymmetric right arm ending in a giant fist,
raised shoulders, two white horns on the head, exposed white ribs,
magenta-crimson flesh, glowing golden eyes, menacing
```

**gem.png**
```
a glowing green hexagonal crystal, faceted like a gemstone,
bright emerald with a white highlight facet, simple and readable at small size
```

**drone.png**
```
a small green quadcopter combat drone seen from the front,
four rotors, a glowing cyan sensor eye in the center, compact and mechanical
```

## 잘 안 나올 때

### 투명 배경이라더니 체크무늬가 그려져 있다

**가장 자주 겪는 함정입니다.** 이미지 AI 는 "transparent background" 를 달라고 하면
알파 채널을 비우는 대신 **투명을 뜻하는 회색 체크무늬를 그림으로 그려 놓는** 경우가 많습니다.
파일은 멀쩡해 보이지만 알파는 전부 255 입니다.

지금 들어 있는 9장이 정확히 그랬습니다. 이렇게 처리했습니다.

1. **가장자리에서 안으로 번져 들어가며** 밝고 채도 낮은 픽셀을 지웁니다.
   캐릭터 안쪽의 흰색(보스 갈비뼈, 고글)은 어두운 외곽선에 막혀 살아남습니다.
2. 남은 **밝은 테두리 자국**을 두 겹 깎습니다 (안티에일리어싱 잔여물).
3. **팔 안쪽처럼 갇힌 체크무늬**는 1번이 못 들어갑니다. 채도가 거의 0 인 순회색 덩어리 중
   **일정 크기 이상**인 것만 따로 지웁니다 — 젬 반짝임 같은 작은 흰색은 남깁니다.

프롬프트에 `on a plain solid magenta background` 를 넣고 그 색을 빼는 쪽이 더 안정적일 때도 있습니다.

### 그 밖에

- **화풍이 제각각이면** — 한 번에 한 장씩 뽑지 말고, 같은 대화에서 이어서 뽑으세요.
  또는 잘 나온 한 장을 참조 이미지로 넣고 나머지를 뽑으세요.
  (지금 9장은 한 시트에 몰아서 뽑은 것이라 화풍이 맞습니다 — 이 방법을 권합니다.)
- **후광이 그려져 있으면** — 젬처럼 빛나는 효과를 AI 가 그려 넣으면 체크무늬가 배어 나와
  사각형 자국이 남습니다. 게임이 발광을 따로 그리니 **후광 없이** 뽑는 게 낫습니다.
- **작게 줄이면 뭉개지면** — 세부를 줄이고 실루엣과 외곽선을 굵게. 화면에서는 40~90px 입니다.
- **어두워서 안 보이면** — 바닥이 짙은 남색입니다. 명도를 한 단계 올리세요.
- **한 시트에 여러 장을 뽑았다면** — 알파(또는 배경 제거 후)의 빈 줄을 기준으로 가로·세로를
  번갈아 쪼개면 자동으로 나뉩니다. 라벨 글자는 높이가 낮아서 크기 필터로 걸러집니다.
