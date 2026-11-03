# 내보낸 웹 빌드를 로컬에서 띄우는 아주 작은 정적 서버. 의존성 없이 윈도우 기본 기능만 쓴다.
# 스레드를 끈 빌드라 COOP/COEP 헤더가 필요 없다. 확인용이지 배포용이 아니다.
param([string]$Root, [int]$Port = 8060)

$types = @{
  '.html' = 'text/html; charset=utf-8'; '.js' = 'application/javascript'
  '.wasm' = 'application/wasm'; '.pck' = 'application/octet-stream'
  '.png' = 'image/png'; '.svg' = 'image/svg+xml'; '.json' = 'application/json'
}
$http = [System.Net.HttpListener]::new()
$http.Prefixes.Add("http://localhost:$Port/")
$http.Start()
Write-Host "Serving $Root on http://localhost:$Port/  (Ctrl+C to stop)"
try {
  while ($http.IsListening) {
    $ctx = $http.GetContext()
    # 요청 하나가 실패해도(브라우저가 끊는 등) 서버는 계속 돈다
    try {
    $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart('/'))
    if ($rel -eq '') { $rel = 'index.html' }
    $full = [IO.Path]::GetFullPath((Join-Path $Root $rel))
    # 루트 밖을 가리키는 경로(../)는 거절한다
    if ($full.StartsWith([IO.Path]::GetFullPath($Root)) -and (Test-Path $full -PathType Leaf)) {
      $bytes = [IO.File]::ReadAllBytes($full)
      $ext = [IO.Path]::GetExtension($full).ToLower()
      $ctx.Response.ContentType = $(if ($types[$ext]) { $types[$ext] } else { 'application/octet-stream' })
      $ctx.Response.ContentLength64 = $bytes.Length
      # HEAD 에 본문을 쓰면 예외가 난다
      if ($ctx.Request.HttpMethod -ne 'HEAD') { $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length) }
    } else {
      $ctx.Response.StatusCode = 404
    }
    $ctx.Response.Close()
    } catch { Write-Host "request failed: $_" }
  }
} finally { $http.Stop() }
