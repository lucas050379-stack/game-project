#!/usr/bin/env bash
# 여러 그림 후보를 **동시에** 뽑는다(gen.bat 은 한 장씩 차례로라 수십 개면 오래 걸린다).
#
#   bash art/gen_many.sh <이름 정규식> [보스 장수] [나머지 장수] [동시 요청 수]
#   예) bash art/gen_many.sh "^sky_" 4 2 8   → sky_ 로 시작하는 것 전부. 보스(sky_boss_* · sky_midboss) 4장, 나머지 2장
#
# prompts.txt 의 '@종류 공통문구' + '이름 | 종류 | 프롬프트' 를 gen.ps1 과 똑같이 읽는다.
# 결과는 art/source/<이름>_<월일_시각>_<번호>.jpg (gen.bat 과 같은 이름 꼴 — post.bat 에 그대로 넣는다).
# 계정 · 토큰은 gen.ps1 과 같은 곳(%USERPROFILE%\.cloudflare-ai 의 ACCOUNT_ID= · API_TOKEN=, 또는 환경 변수).
# Workers AI 의 선정성 필터(8007)는 같은 문구도 통과했다 거부했다 해서 실패하면 몇 번 다시 시도한다.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PREFIX="${1:-sky_}"
BOSS_N="${2:-4}"
REST_N="${3:-2}"
JOBS="${4:-8}"
MODEL="@cf/black-forest-labs/flux-1-schnell"

ACC="${CF_ACCOUNT_ID:-}"
TOK="${CF_API_TOKEN:-}"
KEYFILE="${USERPROFILE:-$HOME}/.cloudflare-ai"
if [ -f "$KEYFILE" ]; then
  [ -z "$ACC" ] && ACC="$(sed -n 's/^[[:space:]]*\(CF_\)\{0,1\}ACCOUNT_ID[[:space:]]*[=:][[:space:]]*//p' "$KEYFILE" | tr -d '\r"'"'" | head -1)"
  [ -z "$TOK" ] && TOK="$(sed -n 's/^[[:space:]]*\(CF_\)\{0,1\}API_TOKEN[[:space:]]*[=:][[:space:]]*//p' "$KEYFILE" | tr -d '\r"'"'" | head -1)"
  # API_TOKEN 줄에 curl 예시가 통째로 붙어 있으면 Bearer 헤더에서 읽는다(gen.ps1 과 같음)
  case "$TOK" in *[!A-Za-z0-9_-]*) TOK="$(grep -o 'Bearer [A-Za-z0-9_-]\{20,\}' "$KEYFILE" | head -1 | cut -d' ' -f2)" ;; esac
fi
if [ -z "$ACC" ] || [ -z "$TOK" ]; then
  echo "계정 ID · 토큰이 없습니다 ($KEYFILE 에 ACCOUNT_ID= · API_TOKEN=)"; exit 1
fi
STEPS="${STEPS:-4}"   # 공들일 그림은 STEPS=8 (flux-schnell 상한)
export ACC TOK MODEL STEPS
SRC="$HERE/source"
mkdir -p "$SRC"
export SRC

# 이름<TAB>전체 프롬프트<TAB>장수 목록
LIST="$(mktemp)"
awk -v pre="$PREFIX" -v bn="$BOSS_N" -v rn="$REST_N" '
  { sub(/\r$/, "") }
  /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
  /^@/ { k = substr($1, 2); v = $0; sub(/^@[^[:space:]]+[[:space:]]+/, "", v); P[k] = v; next }
  {
    n = split($0, f, "|"); if (n < 3) next
    name = f[1]; kind = f[2]; text = f[3]
    for (i = 4; i <= n; i++) text = text "|" f[i]
    gsub(/^[ \t]+|[ \t]+$/, "", name); gsub(/^[ \t]+|[ \t]+$/, "", kind); gsub(/^[ \t]+|[ \t]+$/, "", text)
    if (name !~ pre) next
    cnt = (name ~ /_boss_|_midboss|gangsin_shell/) ? bn : rn
    for (j = 1; j <= cnt; j++) printf "%s\t%s, %s\t%02d\n", name, P[kind], text, j
  }' "$HERE/prompts.txt" > "$LIST"

TOTAL=$(wc -l < "$LIST")
echo "요청 $TOTAL 장 · 동시 $JOBS 개 → $SRC"

one() {
  local name="$1" prompt="$2" idx="$3"
  local esc body out tmp try
  esc=$(printf '%s' "$prompt" | sed 's/\\/\\\\/g; s/"/\\"/g')
  body="{\"prompt\":\"$esc\",\"steps\":${STEPS:-4}}"
  out="$SRC/${name}_$(date +%m%d_%H%M%S)_${idx}.jpg"
  tmp="$(mktemp)"
  for try in 1 2 3 4; do
    curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/$ACC/ai/run/$MODEL" \
      -H "Authorization: Bearer $TOK" -H "Content-Type: application/json" --data-binary "$body" -o "$tmp"
    if grep -q '"image":"' "$tmp"; then
      sed 's/.*"image":"\([^"]*\)".*/\1/' "$tmp" | base64 -d > "$out" 2>/dev/null && { echo "OK   $name $idx"; rm -f "$tmp"; return 0; }
    fi
    sleep $((try * 2))
  done
  echo "FAIL $name $idx: $(head -c 200 "$tmp")"
  rm -f "$tmp"
  return 1
}
export -f one

tr '\t' '\034' < "$LIST" | xargs -d '\n' -P "$JOBS" -I{} bash -c 'IFS=$'"'"'\034'"'"' read -r n p i <<< "$1"; one "$n" "$p" "$i"' _ {}
rm -f "$LIST"
echo "끝. 고른 것은 post.bat <파일> <이름> <cut|tile|fx|plain>"
