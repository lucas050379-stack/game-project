@echo off
setlocal enabledelayedexpansion
rem ==== proyamae (Godot 4) ====
rem Exports a single self-contained proyamae.exe, then copies the season
rem card data next to it. The game reads dist\data\players\ at runtime, so
rem adding a season does NOT require rebuilding -- just drop the file in.

set GODOT=%GODOT_BIN%
if "%GODOT%"=="" set GODOT=C:\tools\godot\Godot_v4.7.1-stable_win64_console.exe
if not exist "%GODOT%" (
  echo ERROR: Godot not found at "%GODOT%"
  echo Set GODOT_BIN to the Godot console executable, or install it there.
  pause
  exit /b 1
)

cd /d "%~dp0"
if not exist dist mkdir dist

rem ==== dist MUST carry a .gdignore ====
rem The output folder lives inside the project, so Godot scans it like any
rem other folder. Without this file it IMPORTS the 4855 photos we just copied
rem into dist\data\photos (84MB of .ctex under .godot\imported) and then PACKS
rem THEM INTO THE EXE -- the export filter only excludes "data/photos/*", and
rem "dist/data/photos/*" is a different path. That is how a 96MB exe became
rem 181MB and a build came to take 141 seconds.
rem
rem dist\ is git-ignored, so this file cannot be committed -- the build has to
rem lay it down itself, and it must exist BEFORE --import runs.
if not exist dist\.gdignore echo.> dist\.gdignore

echo Importing resources...
"%GODOT%" --headless --path "%CD%" --import

rem A leftover .tmp from an earlier run would make the checks below lie.
if exist dist\proyamae.tmp del /q dist\proyamae.tmp

rem Remember what we had, so a STALE exe cannot be reported as success.
set OLD=
if exist dist\proyamae.exe for %%F in (dist\proyamae.exe) do set OLD=%%~tF

echo Exporting...
"%GODOT%" --headless --path "%CD%" --export-release "Windows Desktop" "%CD%\dist\proyamae.exe"

if not exist dist\proyamae.exe (
  echo BUILD FAILED - no exe was produced
  pause
  exit /b 1
)

rem Godot writes proyamae.tmp and renames it over the exe. If the .tmp is
rem still here the rename FAILED -- almost always because the game is still
rem running and Windows has the exe locked. Without this check the build
rem prints "Done" while dist\proyamae.exe is the PREVIOUS build, and you go
rem on testing the old binary wondering why nothing changed.
if exist dist\proyamae.tmp (
  echo BUILD FAILED - could not replace dist\proyamae.exe
  echo The exe is locked. Close the running game and build again.
  pause
  exit /b 1
)

set NEW=
for %%F in (dist\proyamae.exe) do set NEW=%%~tF
if "!NEW!"=="!OLD!" (
  echo BUILD FAILED - dist\proyamae.exe did not change
  echo The exe is locked. Close the running game and build again.
  pause
  exit /b 1
)

echo Copying season data...
if not exist dist\data\players mkdir dist\data\players
copy /y data\players\*.json dist\data\players\ > nul 2>&1

rem Player photos sit NEXT TO the exe, not inside it -- 4855 JPEGs would add
rem ~85MB to the binary. They are optional: without them cards draw as vector
rem art. data\photos carries a .gdignore so Godot never imports them either,
rem so they are NOT part of the export -- they are just files being copied.
rem
rem USE ROBOCOPY, NOT "copy /y". "copy /y" rewrites all 84MB every single
rem build (measured: 19.8s) even when not one photo changed; robocopy skips
rem files that are already there with the same size and timestamp (0.3s).
rem That copy was most of the build. Robocopy exit codes below 8 are success
rem (0 = nothing to do, 1 = something was copied).
rem
rem "build.bat nophotos" skips the step entirely -- for when you only want a
rem new exe and dist already has the photos.
if /i "%~1"=="nophotos" goto :nophotos
if exist "data\photos\index.json" (
  echo Syncing player photos...
  if not exist dist\data\photos mkdir dist\data\photos
  robocopy data\photos dist\data\photos *.jpg index.json /NJH /NJS /NFL /NDL /NP > nul
  if errorlevel 8 echo WARNING: photo copy failed - cards will draw as vector art
)
:nophotos

echo.
echo Done: dist\proyamae.exe
endlocal
