@echo off
setlocal
rem ==== Jellypop (Godot 4) - release build ====
rem   build.bat        dist\web\ + dist\jellypop.exe
rem   build-test.bat   dist\web-test\ + dist\jellypop-test.exe  (every stage unlocked, separate save)
rem The web build is what we ship. The exe is for checking by hand (double-click, no server).
rem Threads are OFF in the web presets, so no COOP/COEP headers are needed.

set GODOT=%GODOT_BIN%
if "%GODOT%"=="" set GODOT=C:\tools\godot\Godot_v4.7.1-stable_win64_console.exe
if not exist "%GODOT%" (
  echo ERROR: Godot not found at "%GODOT%"
  echo Set GODOT_BIN to the Godot console executable, or install it there.
  exit /b 1
)

cd /d "%~dp0"
rem build-test.bat calls this with "test" - one script, so the two builds cannot drift apart.
set WEB_PRESET=Web
set WEB_DIR=web
set EXE_PRESET=Windows Desktop
set EXE_NAME=jellypop
if "%1"=="test" (
  set WEB_PRESET=Web Test
  set WEB_DIR=web-test
  set EXE_PRESET=Windows Test
  set EXE_NAME=jellypop-test
)

rem dist is inside the project: without .gdignore Godot imports the built pngs as resources.
if not exist dist mkdir dist
if not exist dist\.gdignore type nul > dist\.gdignore

echo Importing resources...
"%GODOT%" --headless --path "%CD%" --import

call :export "%WEB_PRESET%" %WEB_DIR%
if errorlevel 1 exit /b 1
call :exe1 "%EXE_PRESET%" %EXE_NAME%
if errorlevel 1 exit /b 1

echo.
echo OK -^> dist\%WEB_DIR%\index.html
echo OK -^> dist\%EXE_NAME%.exe
if "%1"=="test" (echo      serve.bat test  to open the web build) else (echo      serve.bat  to open the web build)
endlocal
exit /b 0

:export
rem Old files would make a failed export look like a success.
if exist dist\%2 rmdir /s /q dist\%2
mkdir dist\%2
echo Exporting %~1 ...
"%GODOT%" --headless --path "%CD%" --export-release %1 "%CD%\dist\%2\index.html"
if not exist dist\%2\index.pck (
  echo.
  echo BUILD FAILED ^(%~1^) - needs export templates 4.7.1 with web_nothreads_release.zip
  exit /b 1
)
exit /b 0

:exe1
rem Delete first: if the game is running, Godot's rename fails and the OLD exe stays, looking like success.
if not exist dist mkdir dist
if exist dist\%2.exe del /q dist\%2.exe
if exist dist\%2.exe (
  echo BUILD FAILED ^(%~1^) - dist\%2.exe is in use. Close the game and run again.
  exit /b 1
)
echo Exporting %~1 ...
"%GODOT%" --headless --path "%CD%" --export-release %1 "%CD%\dist\%2.exe"
if not exist dist\%2.exe (
  echo.
  echo BUILD FAILED ^(%~1^) - needs export templates 4.7.1 for Windows
  exit /b 1
)
exit /b 0
