@echo off
rem Serves the web build and opens the browser.
rem   serve.bat         dist\web       on http://localhost:8060
rem   serve.bat test    dist\web-test  on http://localhost:8061
rem Opening index.html as a file does not work - browsers block .wasm from file://.
cd /d "%~dp0"
set DIR=web
set PORT=8060
if "%1"=="test" (
  set DIR=web-test
  set PORT=8061
)
if not exist dist\%DIR%\index.html (
  echo dist\%DIR% is empty. Run build.bat first.
  exit /b 1
)
start "" http://localhost:%PORT%/
powershell -NoProfile -ExecutionPolicy Bypass -File tools\serve.ps1 -Root "%CD%\dist\%DIR%" -Port %PORT%
