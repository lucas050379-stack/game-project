# 스테이지 튜닝을 여러 코어로 나눠 돌리고, 결과(MOVES · STARS)를 src\stages.gd 표에 합친다.
#   tune.bat                  전부(1 ~ 끝), 코어 수에 맞춰 나눈다
#   tune.bat 101              101 부터 끝까지
#   tune.bat 41 60            41 ~ 60
#   tune.bat 1 120 4          4 개로 나눠서
#
# 한 판을 봇 80번(이동 수 40 + 별 문턱 40) 돌리므로 120개를 한 코어로 돌리면 30분이 넘는다.
# 나눠 돌린 결과는 범위별 로그(tools\tune_logs\)에 남고, 끝나면 표에 합친다 — 범위 밖 번호는 그대로 둔다.
param([int]$From = 1, [int]$To = 0, [int]$Jobs = 0)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$godot = $(if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'C:\tools\godot\Godot_v4.7.1-stable_win64_console.exe' })
$stages = Join-Path $root 'src\stages.gd'

if ($To -le 0) {
  # 스테이지 수는 표의 길이가 아니라 실제 목록에서 센다 — 헤드리스로 한 번 물어본다
  $probe = Join-Path $env:TEMP 'jellypop_count.gd'
  Set-Content -Path $probe -Encoding UTF8 -Value "extends SceneTree`nfunc _init():`n`tprint(""COUNT="", Stages.count())`n`tquit()"
  $out = & $godot --headless --path $root --script $probe 2>$null
  $To = [int](($out | Select-String 'COUNT=(\d+)').Matches[0].Groups[1].Value)
  Remove-Item $probe -ErrorAction SilentlyContinue
}
if ($Jobs -le 0) { $Jobs = [Math]::Max(1, [Math]::Min(8, [Environment]::ProcessorCount - 2)) }
$n = $To - $From + 1
$Jobs = [Math]::Min($Jobs, $n)
$logs = Join-Path $root 'tools\tune_logs'
New-Item -ItemType Directory -Force $logs | Out-Null
Write-Host "튜닝 $From ~ $To ($n 판) 을 $Jobs 개로 나눠 돌립니다..."

& $godot --headless --path $root --import 2>$null | Out-Null
$procs = @()
$step = [int][Math]::Ceiling($n / $Jobs)
for ($k = 0; $k -lt $Jobs; $k++) {
  [int]$a = $From + $k * $step
  [int]$b = [Math]::Min($To, $a + $step - 1)
  if ($a -gt $b) { break }
  $log = Join-Path $logs ("tune_{0:D3}_{1:D3}.txt" -f $a, $b)
  $procs += Start-Process -FilePath $godot -PassThru -NoNewWindow -RedirectStandardOutput $log `
    -RedirectStandardError ($log + '.err') `
    -ArgumentList @('--headless', '--path', "`"$root`"", '--script', 'res://tools/check.gd', '--', 'tune', "from=$a", "to=$b")
}
$t0 = Get-Date
while (($procs | Where-Object { -not $_.HasExited }).Count -gt 0) {
  Start-Sleep -Seconds 10
  $done = 0
  foreach ($f in Get-ChildItem $logs -Filter 'tune_*.txt') { $done += (Select-String -Path $f.FullName -Pattern '^\s+\d+\s+이동' -ErrorAction SilentlyContinue).Count }
  Write-Host ("  {0}/{1} 판  ({2:N0}초)" -f $done, $n, ((Get-Date) - $t0).TotalSeconds)
}

# 결과 합치기 — 범위별 로그의 MOVES · STARS 를 모아 표에 덮어쓴다(범위 밖 번호는 그대로)
$moves = @{}
$stars = @{}
foreach ($f in Get-ChildItem $logs -Filter 'tune_*.txt') {
  foreach ($line in Get-Content $f.FullName -Encoding UTF8) {
    if ($line -match '^const MOVES := \{(.*)\}') {
      foreach ($m in [regex]::Matches($Matches[1], '(\d+): (\d+)')) { $moves[[int]$m.Groups[1].Value] = $m.Groups[2].Value }
    }
    if ($line -match '^const STARS := \{(.*)\}') {
      foreach ($m in [regex]::Matches($Matches[1], '(\d+): \[(\d+), (\d+)\]')) { $stars[[int]$m.Groups[1].Value] = "[$($m.Groups[2].Value), $($m.Groups[3].Value)]" }
    }
  }
}
if ($moves.Count -eq 0) { Write-Host '결과가 없습니다 — tools\tune_logs 의 .err 를 보세요.'; exit 1 }

$text = [IO.File]::ReadAllText($stages, [Text.Encoding]::UTF8)
foreach ($pair in @(@('MOVES', $moves), @('STARS', $stars))) {
  $name = $pair[0]; $add = $pair[1]
  $cur = @{}
  $m0 = [regex]::Match($text, "(?m)^const $name := \{(.*)\}\s*$")
  $pat = $(if ($name -eq 'MOVES') { '(\d+): (\d+)' } else { '(\d+): (\[\d+, \d+\])' })
  foreach ($m in [regex]::Matches($m0.Groups[1].Value, $pat)) { $cur[[int]$m.Groups[1].Value] = $m.Groups[2].Value }
  foreach ($key in $add.Keys) { $cur[$key] = $add[$key] }
  $body = ($cur.Keys | Sort-Object | ForEach-Object { "${_}: $($cur[$_])" }) -join ', '
  $text = $text.Substring(0, $m0.Groups[1].Index) + $body + $text.Substring($m0.Groups[1].Index + $m0.Groups[1].Length)
}
[IO.File]::WriteAllText($stages, $text, (New-Object Text.UTF8Encoding($false)))
Write-Host ("합쳤습니다: 이동 {0}개 · 별 {1}개 → src\stages.gd  ({2:N0}초)" -f $moves.Count, $stars.Count, ((Get-Date) - $t0).TotalSeconds)
