@echo off
rem ==== proyamae -- download KBO player photos ====
rem Needs data\ids\ (ids.bat) and data\players\ (convert.bat) first.
rem Already-downloaded photos are skipped, so re-running is cheap.
rem
rem Photos only exist from 2016 on; older cards borrow the same player's
rem later photo, and players who never appear after 2016 stay as vector art.
rem
rem curl does the downloading -- Godot headless cannot initialise TLS in
rem --script mode ("SSL module failed to initialize"). curl ships with
rem Windows 10 and up.
setlocal
cd /d "%~dp0"

set GODOT=%GODOT_BIN%
if "%GODOT%"=="" set GODOT=C:\tools\godot\Godot_v4.7.1-stable_win64_console.exe
if not exist "%GODOT%" echo ERROR: Godot not found. Set GODOT_BIN. & exit /b 1
where curl >nul 2>&1 || (echo ERROR: curl not found. & exit /b 1)

echo Building download list...
"%GODOT%" --headless --path "%CD%" --script tools/photos.gd
if not exist "data\photos\_urls.txt" exit /b 1

echo Downloading...
curl -sS -Z --parallel-max 6 --retry 2 -A "Mozilla/5.0" -e "https://www.koreabaseball.com/" -K "data\photos\_urls.txt"

echo Indexing...
"%GODOT%" --headless --path "%CD%" --script tools/photos.gd -- --index
endlocal
