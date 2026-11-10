# 보드게임 셋 (보관)

2026-11-10 사용자 결정("생각보다 보드게임이 재미가 없다")으로 `minigames/` 에서 뺀 게임들입니다. 지우지 않고 여기에 옮겨 두었습니다.

| 게임 | 코드 | 그림 | 기획서 | 검사 |
|---|---|---|---|---|
| 제국 연대기 | `src/empire/` (접두어 `Em`) | `art/empire/` | `docs/empire.md` | `tools/empire_check.gd` |
| 붉은 별 개척단 | `src/redstar/` (`Rs`) | `art/redstar/` | `docs/redstar.md` | `tools/redstar_check.gd` |
| 잿빛 요새의 용병단 | `src/ashkeep/` (`Ak`) | `art/ashkeep/` | `docs/ashkeep.md` | `tools/ashkeep_check.gd` |

## 되살리려면
1. `src/<게임>` · `art/<게임>` · `tools/<게임>_check.gd` 를 `minigames/` 의 같은 자리로 옮긴다.
2. `minigames/src/hub/hub.gd` 의 `GAMES` 에 칸을 다시 넣고(`git log -p -- minigames/src/hub/hub.gd` 에 예전 칸과 미리보기 함수가 있다), `Bgm.ORDER` 에 이름을 더한다.
3. `UiKit.theme()` · `FONTS` 의 세 게임 칸과 글꼴(`font/mg_empire_*` 등), 배경음(`Bgm._song_empire` 등)은 **남겨 두었다** — 그대로 쓴다.
4. `godot --headless --path . --import`.
