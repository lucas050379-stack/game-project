@echo off
setlocal enabledelayedexpansion
rem ==== proyamae -- TEST BUILD ====
rem Same game as build.bat, but exported with the "Windows Test" preset, which
rem stamps the custom feature tag "testbuild" into the binary. Save.gd sees it
rem via OS.has_feature("testbuild") and starts with EVERY card owned.
rem
rem Why: tuning the order screen, team colours and skill blocks needs a full
rem collection. Collecting 10,000 cards by playing takes hours and has nothing
rem to do with the thing being tested.
rem
rem The unlock is NOT written to the save file -- it only changes what has()
rem and owned_cards() answer. A save touched by the test build therefore does
rem not carry extra cards back into the normal build.

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

echo Importing resources...
"%GODOT%" --headless --path "%CD%" --import

rem A leftover .tmp from an earlier run would make the checks below lie.
if exist dist\proyamae-test.tmp del /q dist\proyamae-test.tmp

rem Remember what we had, so a STALE exe cannot be reported as success.
set OLD=
if exist dist\proyamae-test.exe for %%F in (dist\proyamae-test.exe) do set OLD=%%~tF

echo Exporting test build...
"%GODOT%" --headless --path "%CD%" --export-release "Windows Test" "%CD%\dist\proyamae-test.exe"

if not exist dist\proyamae-test.exe (
  echo BUILD FAILED - no exe was produced
  pause
  exit /b 1
)

rem Godot writes a .tmp and renames it over the exe. If the .tmp is still here
rem the rename FAILED -- almost always because the game is still running and
rem Windows has the exe locked. See build.bat for the full story.
if exist dist\proyamae-test.tmp (
  echo BUILD FAILED - could not replace dist\proyamae-test.exe
  echo The exe is locked. Close the running game and build again.
  pause
  exit /b 1
)

set NEW=
for %%F in (dist\proyamae-test.exe) do set NEW=%%~tF
if "!NEW!"=="!OLD!" (
  echo BUILD FAILED - dist\proyamae-test.exe did not change
  echo The exe is locked. Close the running game and build again.
  pause
  exit /b 1
)

echo Copying season data...
if not exist dist\data\players mkdir dist\data\players
copy /y data\players\*.json dist\data\players\ > nul 2>&1

if exist "data\photos\index.json" (
  if not exist dist\data\photos mkdir dist\data\photos
  copy /y data\photos\*.jpg dist\data\photos\ > nul 2>&1
  copy /y data\photos\index.json dist\data\photos\ > nul 2>&1
)

echo.
echo Done: dist\proyamae-test.exe  (all cards unlocked)
endlocal
