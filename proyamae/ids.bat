@echo off
rem ==== proyamae -- fetch KBO player numbers (for photos) ====
rem   ids.bat             2000-2026 (already-fetched years are skipped)
rem   ids.bat 2016 2026   a range
rem
rem Only the two basic tables are scanned, so this is about three times
rem faster than a full fetch. Writes data\ids\<year>.json.
setlocal
cd /d "%~dp0"

set GODOT=%GODOT_BIN%
if "%GODOT%"=="" set GODOT=C:\tools\godot\Godot_v4.7.1-stable_win64_console.exe
if not exist "%GODOT%" echo ERROR: Godot not found. Set GODOT_BIN. & exit /b 1

set CHROME=%CHROME_BIN%
if "%CHROME%"=="" set CHROME=C:\Program Files\Google\Chrome\Application\chrome.exe
if not exist "%CHROME%" set CHROME=C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe
if not exist "%CHROME%" echo ERROR: Chrome/Edge not found. Set CHROME_BIN. & exit /b 1

set PROF=%TEMP%\proyamae-cdp

echo Launching headless browser...
powershell -NoProfile -Command "Start-Process -FilePath '%CHROME%' -ArgumentList '--headless=new','--disable-gpu','--remote-debugging-port=9222','--user-data-dir=%PROF%','--no-first-run','--no-default-browser-check','about:blank'"
powershell -NoProfile -Command "Start-Sleep -Seconds 4"

"%GODOT%" --headless --path "%CD%" --script tools/fetch.gd -- --ids %1 %2

echo Cleaning up browser...
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*proyamae-cdp*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"
endlocal
