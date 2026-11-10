#!/usr/bin/env bash
# 월드 러너 캐릭터 아바타 넷 × (평소 + 기분 넷)을 GPT 후보로 넣는다(11-10) — 그다음 lossy_big.gd · --import.
#   bash tools/redo_chars.sh        (minigames/ 에서)
# 평소 = art/source/runner3_char_N_g*_01.png, 기분 = art/source/runner4_char_N_<happy|sad|broke|win>_g1110_01.png(평소 그림을 참조로 뽑은 것).
# 끝에 tools/runner_art.gd 가 옷 마스크(_cloth) · 오라(_glow)를 다시 만든다. 스카이 아이템 둘(sky7_item_*)도 여기서 넣는다.
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT_BIN:-/c/tools/godot/Godot_v4.7.1-stable_win64_console.exe}"
put() {  # $1 = 원본, $2 = 이름, $3 = 크기
  [ -f "$1" ] || { echo "없음 $2"; return; }
  "$GODOT" --headless --path . --script res://tools/post.gd -- "$PWD/$1" "$2" sprite_shadow "$3" 2>&1 | grep -q -- "->" || echo "실패 $2"
}
for c in 0 1 2 3; do
  put "$(ls art/source/runner3_char_${c}_g*_01.png 2>/dev/null | tail -1)" runner_char_$c 512
  for m in happy sad broke win; do
    put "art/source/runner4_char_${c}_${m}_g1110_01.png" runner_char_${c}_$m 512
  done
done
"$GODOT" --headless --path . --script res://tools/runner_art.gd 2>&1 | grep "cloth" | tail -20
