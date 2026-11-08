# game-project — 미니게임 모음

웹 브라우저에서 도는 미니게임 모음입니다(Godot 4 · GDScript). 허브 화면에서 하나를 골라 들어갑니다.

| 게임 | 장르 |
|---|---|
| 젤리팝 | 3매치 퍼즐 — 모험 200판 + 60초 타임 어택 |
| 스카이 어설트 | 세로 슈팅 — 기체 7종, 보스 부위 파괴 |
| 월드 러너 | 주사위 보드게임 — 세계 도시를 사고 지어 상대를 파산시키기 |
| 강호일생 | 무협 인생 시뮬레이션 — 누구로 태어날지는 고를 수 없다 |
| 아르카나 컬렉션 | 카드 보드게임 — 자원을 모아 성물을 갖추고 영웅을 부르기(스플렌더 규칙, AI 1~3명) |

- 소스 · 빌드 · 검사: [minigames/README.md](minigames/README.md)
- 작업 규칙: [CLAUDE.md](CLAUDE.md)

## 브랜치

- `main` — 배포. `minigames/` 가 바뀐 푸시가 들어오면 GitHub Actions 가 웹으로 내보내 GitHub Pages 에 올립니다.
- `minigames` — 작업 브랜치. 여기서 고치고, 다 되면 `main` 으로 병합합니다.

## 빌드 (로컬)

```
cd minigames
build.bat        정식판 → dist\web\
build-test.bat   테스트판 → dist\web-test\
serve.bat        dist\web 를 localhost 에 띄워 브라우저로 보기
```

예전에 있던 다른 게임(세계마뷸 · 빠칭코 · 좀비디펜스 · 갈루가 · 드래곤 대시 · 비트폴 · 푸야매 · 젤리팝 원본)은
11-08 에 저장소에서 뺐습니다. 코드는 git 기록에 남아 있습니다.
