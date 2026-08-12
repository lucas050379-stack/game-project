# ==== 유닛 아이콘 내려받기 ====
#
# ORDR 조합 도우미가 쓰는 아이콘을 유닛 id 별로 받아 art/icons/<id>.png 에 둔다.
# 주소는 원본 페이지(docs/onerand.txt)에 그대로 들어 있다.
#
#   powershell -ExecutionPolicy Bypass -File tools\fetch_icons.ps1
#
# 이미 받은 파일은 건너뛰므로 여러 번 돌려도 된다. 한 장이 실패해도 나머지는 계속 받는다 —
# 그림이 없는 유닛은 게임에서 벡터 없이 이름만 나올 뿐 아무것도 안 깨진다.
#
# 받은 PNG 는 빌드 때 PCK 로 묶이므로 **배포 파일은 여전히 exe 하나**다.

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$units = Join-Path $root 'src\units.gd'
$outDir = Join-Path $root 'art\icons'
$base = 'https://ordsearch.b-cdn.net/images/units/ord/icons/'

if (-not (Test-Path $units)) { throw "src\units.gd 가 없다. 먼저 tools\gen_units.ps1 을 돌려라." }
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }

$ids = [regex]::Matches([IO.File]::ReadAllText($units), '"i":(\d+)') |
	ForEach-Object { [int]$_.Groups[1].Value } | Sort-Object -Unique

$got = 0
$skip = 0
$fail = @()
$n = 0
foreach ($id in $ids) {
	$n++
	$dst = Join-Path $outDir "$id.png"
	if ((Test-Path $dst) -and (Get-Item $dst).Length -gt 0) { $skip++; continue }
	try {
		Invoke-WebRequest -Uri "$base$id.png" -OutFile $dst -UseBasicParsing -TimeoutSec 20
		$got++
	} catch {
		if (Test-Path $dst) { Remove-Item $dst -Force }
		$fail += $id
	}
	if ($n % 40 -eq 0) { Write-Host ("  {0}/{1} …" -f $n, $ids.Count) }
}

Write-Host ("아이콘 {0}종 — 새로 받음 {1} · 이미 있음 {2} · 실패 {3}" -f `
	$ids.Count, $got, $skip, $fail.Count)
if ($fail.Count -gt 0) { Write-Host ("  실패한 id: " + ($fail -join ', ')) }
