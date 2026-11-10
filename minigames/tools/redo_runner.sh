#!/usr/bin/env bash
# 월드 러너 그림을 GPT 후보(art/source/<이름>_g<월일>_*.png, 가장 최근 것)로 다시 넣는다(11-10).
#   bash tools/redo_runner.sh        (minigames/ 에서)   그다음 lossy_big.gd · --import
# art/runner_picks.txt 의 이름 · 후처리 · 크기를 그대로 쓰고(후보 번호만 무시), 끝에 tools/runner_art.gd 로 소유자 색 마스크(_tint) · 옷 마스크(_cloth) · 오라(_glow)를 다시 만든다.
# 새 후보가 없는 이름은 건드리지 않는다.
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT_BIN:-/c/tools/godot/Godot_v4.7.1-stable_win64_console.exe}"
ok=0
while IFS='|' read -r name idx mode size; do
  name="$(echo "$name" | tr -d ' \r')"; mode="$(echo "$mode" | tr -d ' \r')"; size="$(echo "${size:-}" | tr -d ' \r')"
  [ -z "$name" ] && continue
  case "$name" in \#*) continue ;; esac
  src="$(ls art/source/"${name}"_g[0-9][0-9][0-9][0-9]_[0-9][0-9][0-9][0-9][0-9][0-9]_01.png 2>/dev/null | tail -1)"
  [ -z "$src" ] && continue
  rm -f "art/runner/${name}_tint.png" "art/runner/${name}_cloth.png" "art/runner/${name}_glow.png"   # 예전 마스크는 새 그림과 안 맞는다
  if "$GODOT" --headless --path . --script res://tools/post.gd -- "$PWD/$src" "$name" "$mode" $size 2>&1 | grep -q -- "->"; then
    ok=$((ok + 1))
  else
    echo "실패  $name"
  fi
done < <(sort -u -t'|' -k1,1 art/runner_picks.txt)
echo "넣음 $ok 장"
"$GODOT" --headless --path . --script res://tools/runner_art.gd 2>&1 | tail -3
