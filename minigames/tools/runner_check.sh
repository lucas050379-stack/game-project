#!/usr/bin/env bash
# 월드 러너 검산 — 창 없이 AI 넷이 끝까지 두는 판을 여러 번 돌려 자리별 승률 · 라운드 분포를 본다.
# 규칙은 main.gd 의 차례 진행(await)에 그대로 있으므로, 자동 주행(--runner-auto)을 큰 배속으로 돌린다.
#
#   bash tools/runner_check.sh [판 수 40] [동시 실행 4] [배속 400]
#
# 실패(종료 코드 1): 판이 안 끝남(시간 초과) · 비정상 종료 · 결과 줄이 없음.
# 볼 것: 자리별 승률이 한쪽으로 쏠리지 않는가(원본 세계마뷸과 같은 규칙 · AI), 라운드 분포(40 라운드 상한에 붙는 비율).
set -u
cd "$(dirname "$0")/.."
N="${1:-40}"
JOBS="${2:-4}"
SPEED="${3:-400}"
GODOT="${GODOT_BIN:-/c/tools/godot/Godot_v4.7.1-stable_win64_console.exe}"
OUT="$(mktemp -d)"

run_one() {
  timeout 300 "$GODOT" --headless --path . -- --game=runner --runner-auto --runner-speed="$SPEED" > "$OUT/$1.log" 2>&1
  echo "rc=$?" >> "$OUT/$1.log"
}
export -f run_one
export GODOT SPEED OUT

seq 1 "$N" | xargs -P "$JOBS" -I{} bash -c 'run_one {}'

ok=0; fail=0
declare -a seat=(0 0 0 0)
rounds=()
for f in "$OUT"/*.log; do
  line="$(grep -a 'RUNNER AUTO OK' "$f" | tail -1)"
  if [ -z "$line" ] || ! grep -q '^rc=0$' "$f"; then
    fail=$((fail + 1))
    echo "FAIL $(basename "$f"): $(tail -3 "$f" | tr '\n' ' ')"
    continue
  fi
  ok=$((ok + 1))
  s="$(sed -n 's/.*자리 \(-\?[0-9]\+\).*/\1/p' <<< "$line")"
  r="$(sed -n 's/.*라운드 \([0-9]\+\).*/\1/p' <<< "$line")"
  [ "$s" -ge 0 ] 2>/dev/null && seat[$s]=$((seat[$s] + 1))
  rounds+=("$r")
done

echo "판 $N  끝남 $ok  실패 $fail"
if [ "$ok" -gt 0 ]; then
  printf '자리별 승률  '; for i in 0 1 2 3; do printf '%d번 %d%%  ' "$i" $((seat[i] * 100 / ok)); done; echo
  sorted="$(printf '%s\n' "${rounds[@]}" | sort -n)"
  cap="$(printf '%s\n' "${rounds[@]}" | awk '$1 >= 40' | wc -l)"
  echo "라운드  최소 $(head -1 <<< "$sorted")  중앙 $(sed -n "$(( (ok + 1) / 2 ))p" <<< "$sorted")  최대 $(tail -1 <<< "$sorted")  상한(40)까지 간 판 $((cap * 100 / ok))%"
fi
rm -rf "$OUT"
[ "$fail" -eq 0 ] && echo "RUNNER CHECK OK" || { echo "RUNNER CHECK FAILED"; exit 1; }
