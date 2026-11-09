# ADR-0005: 그림은 있으면 쓰고 없으면 벡터 — AI 는 개발 때만

- **상태:** 채택 (지금 동작 기준, 2026-11-09)
- **층:** Presentation

## 맥락
그림은 Cloudflare Workers AI(flux-schnell)로 뽑습니다. 하루 한도가 있고, 같은 그림을 다시 못 뽑고, "얼굴 없이" · "그림자 없이" 를 안 지킵니다.

## 결정
- 게임마다 `img(name)`/`art(name)` 이 `res://art/<게임>/<name>.png` 을 찾고, **없으면 null → 벡터로 그립니다.** `art/` 를 비워도 게임이 떠야 합니다.
- **실행 중에 AI API 를 부르지 않습니다**(토큰 노출 · 판마다 그림이 달라짐 · 복사만으로 안 돎).
- **얼굴 · 움직임 · 게임 정보가 담긴 표시는 코드.** 프레임 그림을 뽑지 않습니다(프레임마다 캐릭터가 달라져 떪).
  몬스터처럼 AI 가 얼굴을 그려 오면 후처리(`noface`)로 지우고 코드가 얹습니다.
- 흐름: `art/gen_many.sh` → `art/source/` 후보 → `tools/contact.gd` 로 고르기 → `post.bat` 후처리 → `godot --import`.

## 결과
- 그림을 넣은 뒤 `--import` 를 안 돌리면 **오류 없이 벡터로만** 나옵니다(조용한 실패).
- 그림 목록과 할 일은 `art/README.md` · `art/GEN_NEXT.md`.
- 큰 그림의 압축 · 용량 예산은 [ADR-0011](0011-texture-budget.md).

## 근거
CLAUDE.md "그림 — Cloudflare Workers AI 는 개발 때만", `art/README.md`.
