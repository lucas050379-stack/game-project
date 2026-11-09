# 글꼴 출처와 라이선스

전부 **SIL Open Font License 1.1**(전문은 [OFL.txt](OFL.txt) — Jua 의 것이고, 조건은 아래 글꼴 모두 같습니다)이며 Google Fonts 저장소
(`https://github.com/google/fonts/tree/main/ofl/<폴더>`)에서 받았습니다. 게임에 싣는 것은 **필요한 글자만 남긴 서브셋**입니다
(`tools/font_subset.py` — 본문은 KS X 1001 한글 2350자 + ASCII + 기호 + 소스에 나오는 글자, 타이틀은 게임 이름 · 큰 제목 낱말).

OFL 은 고친 글꼴에 원래의 예약 이름(Reserved Font Name)을 못 쓰게 하므로 서브셋의 이름표를 `MG ...` 로 바꿨습니다.
저작권 · 라이선스 줄(name ID 0 · 13 · 14)은 원본 그대로 글꼴 파일 안에 남아 있습니다. 글꼴만 따로 팔지 않습니다.

| 파일 | 원본 글꼴 | 폴더 | 저작권자 | 쓰는 곳 |
|---|---|---|---|---|
| `Jua-Regular.ttf` | Jua | `jua` | The BM JUA Project Authors | 젤리팝 · 허브 · 러너 본문, 어디서든 빠진 글자 메우기 |
| `mg_sky_title.ttf` | Black Han Sans | `blackhansans` | The Black Han Sans Project Authors | 스카이 어설트 이름 |
| `mg_sky_body.ttf` | Do Hyeon | `dohyeon` | The Do Hyeon Project Authors | 스카이 어설트 본문 |
| `mg_runner_title.ttf` | Sunflower Bold | `sunflower` | The Sunflower Project Authors | 월드 러너 이름 |
| `mg_gangho_title.ttf` | Nanum Brush Script | `nanumbrushscript` | NHN Corporation (designed by Sandoll Communications) | 강호일생 이름 |
| `mg_serif_body.ttf` | Song Myung | `songmyung` | The Song Myung Project Authors | 강호일생 · 제국 연대기 본문 |
| `mg_arcana_title.ttf` | Hahmlet (wght 800 으로 굳힘) | `hahmlet` | The Hahmlet Project Authors | 아르카나 컬렉션 이름 |
| `mg_batang_body.ttf` | Gowun Batang Bold | `gowunbatang` | The Gowun Batang Project Authors | 아르카나 컬렉션 · 잿빛 요새 본문 |
| `mg_empire_title.ttf` | Nanum Myeongjo ExtraBold | `nanummyeongjo` | NHN Corporation (designed by FONTRIX) | 제국 연대기 이름 |
| `mg_redstar_title.ttf` · `mg_redstar_body.ttf` | IBM Plex Sans KR Bold · Medium | `ibmplexsanskr` | IBM Corp. | 붉은 별 개척단 |
| `mg_ashkeep_title.ttf` | Yeon Sung | `yeonsung` | The Yeon Sung Project Authors | 잿빛 요새의 용병단 이름 |

저작권자 이름은 각 글꼴 파일의 name ID 0 에서 읽은 것입니다(11-09 확인, fontTools).
