@echo off
rem Stage tuning in parallel, then merge MOVES/STARS into src\stages.gd
rem   tune.bat              all stages
rem   tune.bat 101          from 101 to the end
rem   tune.bat 41 60        41..60
rem   tune.bat 1 120 4      using 4 processes
set F=%1
set T=%2
set J=%3
if "%F%"=="" set F=1
if "%T%"=="" set T=0
if "%J%"=="" set J=0
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\tune.ps1" -From %F% -To %T% -Jobs %J%
