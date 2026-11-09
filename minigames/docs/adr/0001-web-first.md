# ADR-0001: 웹이 정식판 — Compatibility 렌더러 · 스레드 없는 내보내기

- **상태:** 채택 (지금 동작 기준으로 기록, 2026-11-09)
- **층:** Foundation

## 맥락
설치 없이 웹 브라우저에서 열려야 합니다([기둥 1](../pillars.md)). 대상은 데스크톱 브라우저이고 폰은 고려하지 않습니다([ADR-0012](0012-desktop-web-only.md)). GitHub Pages 같은 아무 정적 호스팅에 올릴 수 있어야 합니다.

## 결정
- 렌더러는 **Compatibility(WebGL2) 하나**. `hdr_2d` 블룸에 기대지 않습니다 — 빛은 가산 혼합 레이어로 냅니다.
  (예외: 스카이 어설트는 들어올 때 `hdr_2d` 를 켜고 허브가 닫을 때 끕니다.)
- 내보내기는 **스레드 끈 변형**(`variant/thread_support=false`) — COOP/COEP 헤더 없이 뜹니다.
- 글꼴(`font/Jua-Regular.ttf`)을 싣습니다 — 브라우저에는 한글 시스템 글꼴이 없습니다.
- 배포는 `main` 브랜치 푸시 → GitHub Actions → GitHub Pages. exe 는 손으로 확인하는 용도.

## 결과
- 스레드가 없으니 무거운 일(소리 굽기)은 프레임마다 나눠서 합니다([ADR-0006](0006-synth-audio.md)).
- `index.wasm` 39MB 는 Cloudflare Pages(파일당 25 MiB)에 그대로 못 올립니다.
- 웹만의 문제(소리 차단 · 로딩 · 글꼴)는 exe 로 안 보입니다 — 배포 전 `serve.bat` 으로 한 번 봅니다.
- 그림 용량 예산은 [ADR-0011](0011-texture-budget.md)(가져온 텍스처 40MB 이하).

## 근거
CLAUDE.md "웹이라서 지켜야 할 것" · "테스트", README "스카이 어설트".
