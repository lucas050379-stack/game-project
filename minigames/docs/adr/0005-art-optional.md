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

## 새 게임을 만들 때 늘 같이 검토할 조합 (사용자 요청 11-09)
- **그림:** Cloudflare 로 뽑고(`art/gen_many.sh`, 무료 한도) → **sprite-gen 의 무료 도구**로 다듬기 — `cutout`(배경 지우기) · `breathe`(정지 그림에 숨쉬기 루프) · `recolor`.
  sprite-gen 의 유료 생성(codex · grok · openai)은 쓰지 않습니다(사용자가 따로 말하면 예외). 위치: `c:\work\hobby\.claude\skills\sprite-gen`.
- **이펙트:** pixelfx(코드로 그린 픽셀 이펙트 244종, 스프라이트 시트로 내보내기) — `c:\work\hobby\.claude\skills\pixelfx`.
- 기획서마다 "그림 · 이펙트" 줄에 어느 부분이 이 조합을 쓰고 어느 부분이 코드(벡터)인지 적습니다. 코드가 뼈대라는 결정은 그대로.

## 결과
- 그림을 넣은 뒤 `--import` 를 안 돌리면 **오류 없이 벡터로만** 나옵니다(조용한 실패).
- 그림 목록과 할 일은 `art/README.md` · `art/GEN_NEXT.md`.
- 큰 그림의 압축 · 용량 예산은 [ADR-0011](0011-texture-budget.md).

## 근거
CLAUDE.md "그림 — Cloudflare Workers AI 는 개발 때만", `art/README.md`.
