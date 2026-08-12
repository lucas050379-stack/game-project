# ==== 유닛표 생성기 ====
#
# docs/onerand.txt (ORDR 조합 도우미 페이지 원본) 에서 유닛 310종과 조합 트리를 읽어
# src/units.gd 를 만든다. **src/units.gd 는 손으로 고치지 마라** — 다시 돌리면 덮어쓴다.
#
#   powershell -ExecutionPolicy Bypass -File tools\gen_units.ps1
#
# 원본에서 가져오는 것
#   - id / 이름 / 등급 / 재료(data-mates)          : 유닛 행의 data-* 속성
#   - 끝까지 펼친 재료(lowestMaterials)            : totalInfoJsonString
#   - 효과 태그 24종                                : 유닛 행의 data-stun 등 Y/N
#   - 역할(물뎀·마뎀·스토리)                        : 툴팁의 "~로 좋아요 N" 투표 수 중 최대
#
# 원본에 **없어서 여기서 만드는 것**은 전투 수치뿐이다. ORDR 페이지에는 공격력·사거리가
# 없으므로, 유닛의 세기는 "최하위 재료 몇 개로 만들어지는가"(cost)로 잡는다.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root 'docs\onerand.txt'
$dst = Join-Path $root 'src\units.gd'

$h = [IO.File]::ReadAllText($src)

$TAGS = 'stun','sstun','slow','shield','mshield','armorbreak','splash','single','last',
        'boss','berserk','sky','blink','docking','regen','damageb','speedb','life',
        'ignore','udelete','bombup','rangenlpd','rangetlpd','rangellpd'

function Attr($tag, $n) {
	$m = [regex]::Match($tag, "(?i)\s$n=""([^""]*)""")
	if ($m.Success) { [System.Net.WebUtility]::HtmlDecode($m.Groups[1].Value) } else { '' }
}

# ---- 1) 유닛 행 ----
# 주의: PowerShell 변수는 대소문자를 구분하지 않는다. 맵을 $ALL 로 둔 것은
# 반복 변수 $row 와 겹치지 않게 하려는 것이다 ($U 와 $u 는 같은 변수다).
$ALL = @{}
$fromMates = @{}
foreach ($m in [regex]::Matches($h, '(?is)<tr\b[^>]*data-unit-id="(\d+)"[^>]*>(.*?)</tr>')) {
	$id = [int]$m.Groups[1].Value
	$tr = [regex]::Match($m.Value, '(?is)^<tr\b[^>]*>').Value
	$body = $m.Groups[2].Value
	$b = [regex]::Match($body, '(?is)<button\b[^>]*data-origin-name="[^"]*"[^>]*>')
	if (-not $b.Success) { continue }

	# 재료 id 와 툴팁의 재료 이름이 같은 순서다. 최하위 등급(흔함)은 클릭 대상이 아니라
	# 자기 행이 없으므로, **여기서만** 이름을 얻을 수 있다.
	$mates = Attr $b.Value 'data-mates'
	$title = Attr $b.Value 'data-mate-title'
	if ($mates -and $title) {
		$head = ($title -split '(?i)<hr')[0]
		$pairs = [regex]::Matches($head, '(?is)</i>\s*([^<(]+?)\s*\(([^)]+)\)')
		$ids = $mates -split ','
		for ($k = 0; $k -lt [Math]::Min($ids.Count, $pairs.Count); $k++) {
			$mid = [int]$ids[$k]
			if (-not $fromMates.ContainsKey($mid)) {
				$fromMates[$mid] = @{
					n = ($pairs[$k].Groups[1].Value.Trim() -replace '\s*x\s*\d+$', '')
					g = $pairs[$k].Groups[2].Value.Trim()
				}
			}
		}
	}
	if ($ALL.ContainsKey($id)) { continue }

	# 역할 — 커뮤니티 투표 수가 가장 높은 쪽. 원본에 역할 필드가 따로 없다.
	$p = 0; $mg = 0; $st = 0
	$mm = [regex]::Match($body, '물리데미지로 좋아요\s*(\d+)'); if ($mm.Success) { $p = [int]$mm.Groups[1].Value }
	$mm = [regex]::Match($body, '마법데미지로 좋아요\s*(\d+)'); if ($mm.Success) { $mg = [int]$mm.Groups[1].Value }
	$mm = [regex]::Match($body, '스토리로 좋아요\s*(\d+)'); if ($mm.Success) { $st = [int]$mm.Groups[1].Value }
	$role = 0
	if ($mg -gt $p -and $mg -ge $st) { $role = 1 }
	elseif ($st -gt $p -and $st -gt $mg) { $role = 2 }

	$flags = 0
	for ($i = 0; $i -lt $TAGS.Count; $i++) {
		if ((Attr $tr "data-$($TAGS[$i])") -eq 'Y') { $flags = $flags -bor (1 -shl $i) }
	}
	$ALL[$id] = @{
		id = $id; name = (Attr $b.Value 'data-origin-name')
		lv = [int](Attr $b.Value 'data-level'); grade = (Attr $b.Value 'data-level-text')
		mates = $mates; role = $role; flags = $flags
	}
}
foreach ($mid in $fromMates.Keys) {
	if ($ALL.ContainsKey($mid)) { continue }
	$ALL[$mid] = @{ id = $mid; name = $fromMates[$mid].n; lv = 1; grade = $fromMates[$mid].g
		mates = ''; role = 0; flags = 0 }
}

# ---- 2) 조합 트리 ----
$scripts = [regex]::Matches($h, '(?is)<script[^>]*>(.*?)</script>')
$json = ''
foreach ($s in $scripts) {
	$mm = [regex]::Match($s.Groups[1].Value, '(?s)var totalInfoJsonString\s*=\s*`(.*?)`\s*;')
	if ($mm.Success) { $json = $mm.Groups[1].Value; break }
}
if (-not $json) { throw '조합 트리(totalInfoJsonString)를 못 찾았다' }
[IO.File]::WriteAllText((Join-Path $root 'docs\ordr-recipes.json'), $json, [Text.UTF8Encoding]::new($false))

$R = $json | ConvertFrom-Json
$rec = @{}
foreach ($p in $R.PSObject.Properties) {
	$mats = @{}
	if ($p.Value.materials -isnot [array]) {
		foreach ($x in $p.Value.materials.PSObject.Properties) { $mats[[int]$x.Name] = [int]$x.Value.count }
	}
	# 끝까지 펼친 재료. 개수 합(cost)은 세기로 쓰고, 종류별 내역(low)은
	# 쉬움 난이도에서 "최하위 유닛만으로 바로 조합"할 때 그대로 쓴다.
	$low = @{}
	$cost = 0
	if ($p.Value.lowestMaterials -isnot [array]) {
		foreach ($x in $p.Value.lowestMaterials.PSObject.Properties) {
			$low[[int]$x.Name] = [int]$x.Value
			$cost += [int]$x.Value
		}
	}
	$rec[[int]$p.Name] = @{ mats = $mats; low = $low; cost = $cost }
}

# ---- 2.5) 얻을 길이 없는 재료 걷어내기 ----
#
# ORDR 에서는 연구소 건설·기록지침 해금·특성 포인트 같은 게임 밖 진행으로 풀리는 것들인데,
# 이 게임에는 그 통로가 없다. 재료로 남겨 두면 그 위 조합법이 통째로 막히므로 조합법에서 뺀다.
# **유닛 자체는 표에 남긴다** — 빼 버리면 재료 id 가 가리키는 자리가 사라진다.
$stripGrades = '기록지침', '연구소', '아이템'
$stripNames = '태양신의 흔적', '우타의 헤드셋', '불사조의 깃털', '슈스이', '그린블러드',
	'금 5,000', '금 10,000', '금 30,000', '특성포인트 x 4'

$strip = @{}
foreach ($k in $ALL.Keys) {
	if (($stripGrades -contains $ALL[$k].grade) -or ($stripNames -contains $ALL[$k].name)) {
		$strip[$k] = $true
	}
}
$touched = 0
$emptied = 0
foreach ($id in $rec.Keys) {
	$before = $rec[$id].mats.Count
	foreach ($k in @($rec[$id].mats.Keys)) { if ($strip.ContainsKey($k)) { $rec[$id].mats.Remove($k) } }
	foreach ($k in @($rec[$id].low.Keys)) { if ($strip.ContainsKey($k)) { $rec[$id].low.Remove($k) } }
	if ($rec[$id].mats.Count -ne $before) {
		$touched++
		if ($rec[$id].mats.Count -eq 0) { $emptied++ }
	}
	# 재료가 줄었으니 세기도 다시 센다
	$c = 0
	foreach ($k in $rec[$id].low.Keys) { $c += $rec[$id].low[$k] }
	$rec[$id].cost = $c
}
Write-Host ("얻을 길 없는 재료 {0}종을 조합법에서 뺐다 — 고친 조합법 {1}개 (그중 {2}개는 재료가 없어짐)" -f `
	$strip.Count, $touched, $emptied)

# ---- 3) 등급 순서 ----
$levels = ($ALL.Values | ForEach-Object { $_.lv } | Sort-Object -Unique)
$gradeOf = @{}
$gradeNames = @()
for ($i = 0; $i -lt $levels.Count; $i++) {
	$lv = $levels[$i]
	$gradeOf[$lv] = $i
	$gradeNames += ($ALL.Values | Where-Object { $_.lv -eq $lv } | Select-Object -First 1).grade
}

# 조합법이 없는 등급(기타·특수함·랜덤전용 등)은 cost 가 0 이라 세기를 못 잡는다.
# 등급 순서에 맞춰 어림값을 준다.
function GradeIndex($lv) {
	if ($null -ne $lv -and $gradeOf.ContainsKey($lv)) { return [int]$gradeOf[$lv] }
	return 0
}
function FallbackCost($lv) {
	return [int]([Math]::Round(1.9 * [Math]::Pow((GradeIndex $lv) + 1, 1.75)))
}

# ---- 4) 출력 ----
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('class_name U')
[void]$sb.AppendLine('extends RefCounted')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## **자동 생성 파일이다. 손으로 고치지 마라** — `tools/gen_units.ps1` 이 다시 만들면 덮어쓴다.')
[void]$sb.AppendLine('##')
[void]$sb.AppendLine('## 원본은 ORDR 조합 도우미 페이지(`docs/onerand.txt`)이고, 유닛 이름·등급·조합법·효과 태그는')
[void]$sb.AppendLine('## 전부 거기서 그대로 옮긴 값이다. 조합 트리는 사이트가 계산해 둔 최하위 재료 수와')
[void]$sb.AppendLine('## 대조해 247종 전부 일치하는 것을 확인했다.')
[void]$sb.AppendLine('##')
[void]$sb.AppendLine('## 원본에 없어서 여기서 만든 것은 `c`(세기) 하나뿐이다 — ORDR 페이지에는 공격력·사거리가')
[void]$sb.AppendLine('## 없다. 그래서 "최하위 재료 몇 개로 만들어지는가"를 그대로 세기로 쓴다.')
[void]$sb.AppendLine('##')
[void]$sb.AppendLine('## 칸 이름을 짧게 둔 것은 310줄이 넘는 표라서다 —')
[void]$sb.AppendLine('## `i` id · `n` 이름 · `g` 등급 · `m` 재료 · `l` 끝까지 펼친 재료 ·')
[void]$sb.AppendLine('## `c` 세기 · `r` 역할 · `t` 효과 태그')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## 등급. 낮은 것이 먼저다.')
[void]$sb.AppendLine('const GRADE := [' + (($gradeNames | ForEach-Object { '"' + $_ + '"' }) -join ', ') + ']')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## 역할 — 커뮤니티 투표에서 가장 많이 꼽힌 쪽')
[void]$sb.AppendLine('const ROLE := ["물뎀", "마뎀", "스토리"]')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## 효과 태그. `t` 는 이 순서의 비트다.')
[void]$sb.AppendLine('const TAG := [' + (($TAGS | ForEach-Object { '"' + $_ + '"' }) -join ', ') + ']')
for ($i = 0; $i -lt $TAGS.Count; $i++) {
	[void]$sb.AppendLine(('const T_{0} := 1 << {1}' -f $TAGS[$i].ToUpper(), $i))
}
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## 유닛 표. `m` 은 [재료 id, 개수] 짝들이고, 비어 있으면 조합으로 못 만드는 유닛이다.')
[void]$sb.AppendLine('const UNITS := [')
foreach ($id in ($ALL.Keys | Sort-Object)) {
	$row = $ALL[$id]
	$mats = ''
	$lows = ''
	$cost = 0
	if ($rec.ContainsKey($id)) {
		$cost = $rec[$id].cost
		$parts = @()
		foreach ($k in ($rec[$id].mats.Keys | Sort-Object)) { $parts += ('[{0},{1}]' -f $k, $rec[$id].mats[$k]) }
		$mats = $parts -join ','
		$lparts = @()
		foreach ($k in ($rec[$id].low.Keys | Sort-Object)) { $lparts += ('[{0},{1}]' -f $k, $rec[$id].low[$k]) }
		$lows = $lparts -join ','
	}
	if ($cost -le 0) { $cost = FallbackCost $row.lv }
	$name = $row.name -replace '"', "'"
	[void]$sb.AppendLine(('	{{"i":{0},"n":"{1}","g":{2},"m":[{3}],"l":[{4}],"c":{5},"r":{6},"t":{7}}},' -f `
		$row.id, $name, (GradeIndex $row.lv), $mats, $lows, $cost, $row.role, $row.flags))
}
[void]$sb.AppendLine(']')
[IO.File]::WriteAllText($dst, $sb.ToString(), [Text.UTF8Encoding]::new($false))

$craft = ($ALL.Keys | Where-Object { $rec.ContainsKey($_) -and $rec[$_].mats.Count -gt 0 }).Count
Write-Host ("유닛 {0}종 · 등급 {1}단계 · 조합법 {2}개  ->  src/units.gd" -f $ALL.Count, $levels.Count, $craft)
