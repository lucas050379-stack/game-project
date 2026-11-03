# Cloudflare Workers AI 로 그림 후보를 뽑는다. 개발할 때 한 번만 돌리는 도구다 —
# 게임은 실행 중에 이 API 를 부르지 않는다(토큰이 브라우저에 노출되고, 판마다 그림이 달라진다).
#
#   gen.bat block_0            후보 4장 → art\source\block_0_01_s<시드>.jpg ...
#   gen.bat block_0 -Count 8
#   (flux-1-schnell 은 seed 를 받지 않는다 — 보내면 400. 같은 그림을 다시 뽑을 수는 없다)
#
# 계정 ID 와 토큰은 저장소에 적지 않는다. 찾는 순서:
#   1) 환경 변수  CF_ACCOUNT_ID · CF_API_TOKEN
#   2) 홈 폴더의 .cloudflare-ai 파일  ACCOUNT_ID=... · API_TOKEN=...  (키=값, 한 줄에 하나)
# 토큰은 "Workers AI" 권한(Read) 이 있어야 한다.
param(
  [Parameter(Mandatory = $true)][string]$Name,
  [int]$Count = 4,
  [string]$Model = '@cf/black-forest-labs/flux-1-schnell',
  [int]$Steps = 8
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$account = $env:CF_ACCOUNT_ID
$token = $env:CF_API_TOKEN
$keyfile = Join-Path $env:USERPROFILE '.cloudflare-ai'
if ((-not $account -or -not $token) -and (Test-Path $keyfile)) {
  $bearer = $null
  foreach ($line in Get-Content $keyfile) {
    if ($line -match '^\s*(ACCOUNT_ID|CF_ACCOUNT_ID)\s*[=:]\s*(.+)$') { $account = $Matches[2].Trim().Trim('"', "'") }
    if ($line -match '^\s*(API_TOKEN|CF_API_TOKEN)\s*[=:]\s*(.+)$') { $token = $Matches[2].Trim().Trim('"', "'") }
    # 대시보드에서 복사한 curl 예시를 그대로 붙여 두는 경우가 있다 — Authorization 헤더에서도 찾는다
    if ($line -match 'Bearer\s+([A-Za-z0-9_\-]{20,})') { $bearer = $Matches[1] }
  }
  # API_TOKEN 줄에 토큰이 아닌 것(curl 주소 등)이 들어 있으면 Bearer 쪽을 쓴다
  if ($bearer -and ($token -notmatch '^[A-Za-z0-9_\-]{20,}$')) { $token = $bearer }
}
if (-not $account -or -not $token) {
  Write-Host '계정 ID / 토큰을 못 찾았습니다. 둘 중 하나로 넣어 주세요.'
  Write-Host '  환경 변수:  setx CF_ACCOUNT_ID <계정ID>   setx CF_API_TOKEN <토큰>   (새 터미널에서 적용)'
  Write-Host "  파일:       $keyfile  에  ACCOUNT_ID=...  API_TOKEN=...  두 줄"
  exit 1
}

# prompts.txt 읽기 — '@종류 공통문구' 와 '이름 | 종류 | 프롬프트'
$prefix = @{}
$item = $null
foreach ($line in Get-Content (Join-Path $here 'prompts.txt') -Encoding UTF8) {
  $l = $line.Trim()
  if ($l -eq '' -or $l.StartsWith('#')) { continue }
  if ($l.StartsWith('@')) {
    $k, $v = $l.Substring(1) -split '\s+', 2
    $prefix[$k] = $v
    continue
  }
  $parts = $l -split '\|', 3 | ForEach-Object { $_.Trim() }
  if ($parts[0] -eq $Name) { $item = $parts }
}
if (-not $item) { Write-Host "prompts.txt 에 '$Name' 이 없습니다."; exit 1 }
$prompt = "$($prefix[$item[1]]), $($item[2])"
Write-Host "[$Name] $prompt"

$src = Join-Path $here 'source'
New-Item -ItemType Directory -Force $src | Out-Null
$uri = "https://api.cloudflare.com/client/v4/accounts/$account/ai/run/$Model"
$headers = @{ Authorization = "Bearer $token" }

for ($i = 1; $i -le $Count; $i++) {
  $stamp = Get-Date -Format 'MMdd_HHmmss'
  $body = @{ prompt = $prompt; steps = $Steps } | ConvertTo-Json
  $r = $null
  # Workers AI 의 선정성 필터(코드 8007)는 같은 문구도 통과했다 거부했다 한다 — 몇 번 다시 시도한다
  for ($try = 1; $try -le 4 -and -not $r; $try++) {
    try {
      # 한글이 없어도 본문은 UTF-8 바이트로 보낸다(PowerShell 5 의 기본 인코딩 문제를 피한다)
      $r = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType 'application/json' `
        -Body ([Text.Encoding]::UTF8.GetBytes($body))
    } catch {
      $detail = $(if ($_.ErrorDetails) { $_.ErrorDetails.Message } else { '' })
      if ($detail -match '"code":8007' -and $try -lt 4) {
        Write-Host "  필터 오판(8007) — 다시 시도 $try"
        continue
      }
      Write-Host "  실패: $($_.Exception.Message)"
      if ($detail) { Write-Host "  $detail" }
      exit 1
    }
  }
  $b64 = $(if ($r.result.image) { $r.result.image } else { $r.image })
  $out = Join-Path $src ('{0}_{1}_{2:D2}.jpg' -f $Name, $stamp, $i)
  [IO.File]::WriteAllBytes($out, [Convert]::FromBase64String($b64))
  Write-Host "  -> $out"
}
Write-Host ''
Write-Host "마음에 드는 것을 골라:  post.bat <파일> $Name $($item[1])"
