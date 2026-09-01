@echo off
setlocal
rem ==== Beatfall song import ====
rem   import.bat <video-or-audio-file> [folder-name]
rem
rem Pulls the audio out of an mp4 (or any media file ffmpeg can read),
rem splits it into two layers, analyses it, and writes chart.json.
rem The result lands in songs\<folder-name>\ and shows up in the game.
rem
rem The two layers are what makes keysounds work (see src/keys.gd):
rem   bed.ogg   low frequencies only - always plays, and drives the clock
rem   keys.ogg  everything else - sliced at note times, only sounds when you hit
rem A FIRST-ORDER crossover is used on purpose: a 1-pole lowpass plus a 1-pole
rem highpass at the same corner sum back to the original signal exactly.
rem Steeper filters would leak less between layers but would NOT reconstruct,
rem so a perfect play would no longer sound like the original song.
rem
rem Video is ignored on purpose - Godot only plays Ogg Theora, and
rem re-encoding a music video would cost far more than it is worth.

if "%~1"=="" (
  echo Usage: import.bat ^<video-or-audio-file^> [folder-name]
  echo   e.g. import.bat "C:\Users\me\Music\song.mp4"
  exit /b 1
)
if not exist "%~1" (
  echo ERROR: file not found: %~1
  exit /b 1
)

where ffmpeg >nul 2>nul
if errorlevel 1 (
  echo ERROR: ffmpeg is not on PATH.
  echo   winget install Gyan.FFmpeg
  echo   - or download from https://ffmpeg.org/download.html and add it to PATH
  exit /b 1
)

set GODOT=%GODOT_BIN%
if "%GODOT%"=="" set GODOT=C:\tools\godot\Godot_v4.7.1-stable_win64_console.exe
if not exist "%GODOT%" (
  echo ERROR: Godot not found at "%GODOT%"
  exit /b 1
)

cd /d "%~dp0"
set NAME=%~2
if "%NAME%"=="" set NAME=%~n1
set OUT=%CD%\songs\%NAME%
if not exist "%OUT%" mkdir "%OUT%"

rem Crossover corner in Hz. Below this stays in the bed and keeps playing.
set XOVER=180

echo [1/4] Extracting audio...
ffmpeg -y -v error -i "%~1" -vn -ac 2 -ar 44100 -c:a libvorbis -q:a 5 "%OUT%\audio.ogg"
if errorlevel 1 goto :ffail

echo [2/4] Splitting into bed + keys layers...
ffmpeg -y -v error -i "%~1" -vn -af "lowpass=f=%XOVER%:poles=1" -ac 2 -ar 44100 -c:a libvorbis -q:a 5 "%OUT%\bed.ogg"
if errorlevel 1 goto :ffail
ffmpeg -y -v error -i "%~1" -vn -af "highpass=f=%XOVER%:poles=1" -ac 2 -ar 44100 -c:a libvorbis -q:a 5 "%OUT%\keys.ogg"
if errorlevel 1 goto :ffail

echo [3/4] Extracting mono PCM for analysis...
rem 22050 Hz mono 16-bit is exactly what analyze.gd expects.
ffmpeg -y -v error -i "%~1" -vn -ac 1 -ar 22050 -c:a pcm_s16le "%OUT%\_analyze.wav"
if errorlevel 1 goto :ffail
ffmpeg -y -v error -i "%~1" -vn -af "lowpass=f=%XOVER%:poles=1" -ac 1 -ar 22050 -c:a pcm_s16le "%OUT%\_bed.wav"
if errorlevel 1 goto :ffail
ffmpeg -y -v error -i "%~1" -vn -af "highpass=f=%XOVER%:poles=1" -ac 1 -ar 22050 -c:a pcm_s16le "%OUT%\_keys.wav"
if errorlevel 1 goto :ffail

echo [4/4] Building the chart...
"%GODOT%" --headless --path "%CD%" --script src/tool.gd -- import --wav="%OUT%\_analyze.wav" --bed-wav="%OUT%\_bed.wav" --keys-wav="%OUT%\_keys.wav" --out="%OUT%" --audio=audio.ogg --bed=bed.ogg --keys=keys.ogg --title="%NAME%"
if errorlevel 1 (
  echo ERROR: chart generation failed.
  exit /b 1
)

del "%OUT%\_analyze.wav" "%OUT%\_bed.wav" "%OUT%\_keys.wav"
echo.
echo Done. Run run.bat and pick "%NAME%".
exit /b 0

:ffail
echo ERROR: ffmpeg failed.
exit /b 1
