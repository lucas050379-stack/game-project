#!/usr/bin/env bash
# GPT(ChatGPT 구독 · codex 로그인)로 그림 후보를 뽑는다 — Cloudflare 한도가 찼거나 화풍 일관성이 중요할 때(11-10).
#
#   bash art/gen_gpt.sh <이름 정규식> [장수=1] [동시=2] [--ref 그림 ...]
#   예) bash art/gen_gpt.sh '^gh_face_' 1 2
#       bash art/gen_gpt.sh '^ak_c_0_' 1 2 --ref art/ashkeep/ak_h_0.png     # 같은 인물로
#
# prompts.txt 의 '@종류 공통문구' + '이름 | 종류 | 프롬프트' 를 gen_many.sh 와 똑같이 읽는다.
# 결과는 art/source/<이름>_g<월일_시각>_<번호>.png (post.bat · apply_art.py 가 그대로 받는다).
# 한도(ChatGPT 사용량 창)에 걸리면 sprite-gen 이 종료 코드 1 로 멈춘다 — 몇 시간 뒤 다시.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PREFIX="${1:-^$}"; N="${2:-1}"; JOBS="${3:-2}"; shift 3 2>/dev/null || shift $#
REFS=("$@")
SG="/c/dev/tools/sprite-gen/.venv/Scripts/sprite-gen.exe"   # 11-09 C:dev 로 옮김(예전 /c/work/hobby/...)
SRC="$HERE/source"; mkdir -p "$SRC"; touch "$SRC/.gdignore"
export SG SRC
LIST="$(mktemp)"
awk -v pre="$PREFIX" -v n="$N" '
  { sub(/\r$/, "") }
  /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
  /^@/ { k = substr($1, 2); v = $0; sub(/^@[^[:space:]]+[[:space:]]+/, "", v); P[k] = v; next }
  {
    c = split($0, f, "|"); if (c < 3) next
    name = f[1]; kind = f[2]; text = f[3]
    for (i = 4; i <= c; i++) text = text "|" f[i]
    gsub(/^[ \t]+|[ \t]+$/, "", name); gsub(/^[ \t]+|[ \t]+$/, "", kind); gsub(/^[ \t]+|[ \t]+$/, "", text)
    if (name !~ pre) next
    for (j = 1; j <= n; j++) printf "%s\t%s, %s\t%02d\n", name, P[kind], text, j
  }' "$HERE/prompts.txt" > "$LIST"
echo "요청 $(wc -l < "$LIST") 장 · 동시 $JOBS 개 · 참조 ${#REFS[@]} 장 → $SRC"
REFARGS=""
for r in "${REFS[@]}"; do REFARGS="$REFARGS --ref $(cd "$(dirname "$r")" && pwd)/$(basename "$r")"; done
export REFARGS
one() {
  local name="$1" prompt="$2" idx="$3"
  local out="$SRC/${name}_g$(date +%m%d_%H%M%S)_${idx}.png"
  if "$SG" gen --provider codex --prompt "$prompt" --out "$out" $REFARGS > "$out.log" 2>&1; then
    echo "OK   $name $idx"; rm -f "$out.log"
  else
    echo "FAIL $name $idx: $(grep -i "error\|usage\|limit" "$out.log" | head -1 | cut -c1-160)"
  fi
}
export -f one
tr '\t' '\034' < "$LIST" | xargs -d '\n' -P "$JOBS" -I{} bash -c 'IFS=$'"'"'\034'"'"' read -r n p i <<< "$1"; one "$n" "$p" "$i"' _ {}
rm -f "$LIST"
echo "끝. 고른 것은 post.bat <파일> <이름> <plain|key> 또는 python tools/apply_art.py"
