#!/usr/bin/env bash
# 고른 후보 목록(기본 art/sky_picks.txt)을 한꺼번에 후처리한다 — post.bat 을 한 장씩 부르는 것과 같다.
#   bash art/post_picks.sh [목록 파일]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
LIST="${1:-$HERE/sky_picks.txt}"
GODOT="${GODOT_BIN:-/c/tools/godot/Godot_v4.7.1-stable_win64_console.exe}"
ok=0; bad=0
while IFS='|' read -r name idx mode size; do
  name="$(echo "$name" | tr -d ' \r')"; idx="$(echo "$idx" | tr -d ' \r')"
  mode="$(echo "$mode" | tr -d ' \r')"; size="$(echo "${size:-}" | tr -d ' \r')"
  [ -z "$name" ] && continue
  case "$name" in \#*) continue ;; esac
  src="$(ls "$HERE"/source/"${name}"_[0-9][0-9][0-9][0-9]_[0-9][0-9][0-9][0-9][0-9][0-9]_"${idx}".jpg 2>/dev/null | tail -1)"
  if [ -z "$src" ]; then echo "없음  $name #$idx"; bad=$((bad + 1)); continue; fi
  if "$GODOT" --headless --path "$ROOT" --script res://tools/post.gd -- "$src" "$name" "$mode" $size 2>&1 | grep -q -- "->"; then
    echo "OK    $name"; ok=$((ok + 1))
  else
    echo "실패  $name"; bad=$((bad + 1))
  fi
done < "$LIST"
echo "끝: $ok 장 · 문제 $bad"
