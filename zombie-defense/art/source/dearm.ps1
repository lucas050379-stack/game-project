# 몸통 PNG 에 인쇄된 양팔을 지운다.
#
# 이미지 AI 가 "torso only, no arms" 를 무시하고 팔을 같이 그려 오면, 그대로 쓸 경우
# _arm_b/_arm_f 조각이 그 위에 또 얹혀 팔이 두 벌 보인다. 이 스크립트가 팔만 도려낸다.
#
#   원본: torso_original\<이름>_torso.png   (건드리지 않는다)
#   결과: ..\<이름>_torso.png               (게임이 실제로 쓰는 파일)
#
# 아래 표만 고쳐서 다시 돌리면 된다. 경계 폴리라인은 "x,y;x,y;…" (위->아래) 이고
# 실루엣 위/아래로 넉넉히 넘겨야(-6, H+6) 어깨 위로 팔이 몸통과 이어지는 걸 끊을 수 있다.
# 팔과 몸이 외곽선으로 갈라지는 캐릭터(zombie·runner·spitter)는 대충 그어도 되고,
# 같은 색으로 붙어 있는 캐릭터(fat·bomber·boss)는 실제 경계에 맞춰 그어야 한다.

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$orig = Join-Path $here "torso_original"
$art  = Split-Path -Parent $here

# 이름 = 외곽선 밝기, 왼쪽 경계, 오른쪽 경계, 지우지 말 씨앗점("-" 면 없음)
$cfg = [ordered]@{
  zombie  = @(45, "46,-6;46,30;42,60;40,95;42,130",                     "104,-6;106,30;108,60;108,95;104,130", "-")
  runner  = @(45, "42,-6;40,30;38,60;36,95;38,126",                     "88,-6;90,30;92,60;94,95;92,126",      "-")
  spitter = @(45, "40,-6;38,30;36,60;34,90;36,111",                     "90,-6;90,14;96,40;100,66;96,94;96,111", "-")
  fat     = @(45, "56,-6;60,22;55,40;46,52;38,66;32,86;30,106;32,133",  "112,-6;112,16;124,38;132,58;145,70;200,78", "-")
  bomber  = @(45, "54,-6;50,24;46,42;38,56;32,68;34,84;40,100;42,119",  "98,-6;100,18;108,38;114,55;125,66;200,74",  "-")
  boss    = @(45, "68,-6;68,10;54,36;48,66;52,96;60,122",               "150,-6;144,20;148,45;152,72;150,95;146,122", "-")
}

$csc = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$exe = Join-Path $here "DeArm.exe"
& $csc /nologo /target:exe /out:"$exe" /reference:System.Drawing.dll (Join-Path $here "DeArm.cs")
if (-not $?) { throw "DeArm.cs 컴파일 실패" }

foreach ($n in $cfg.Keys) {
  $c = $cfg[$n]
  & $exe (Join-Path $orig "${n}_torso.png") (Join-Path $art "${n}_torso.png") $c[0] $c[1] $c[2] $c[3]
}

Write-Output ""
Write-Output "끝났습니다. art\<이름>_torso.png 를 눈으로 확인한 뒤 build.bat 을 돌리세요."
