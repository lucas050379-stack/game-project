@echo off
setlocal
rem ==== Segyemabyul build - uses the C# compiler built into Windows (no install) ====

set CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe
if not exist "%CSC%" set CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe
if not exist "%CSC%" (
  echo ERROR: .NET Framework C# compiler not found.
  pause
  exit /b 1
)

cd /d "%~dp0"
if not exist dist mkdir dist

echo Building...
"%CSC%" /nologo /target:winexe /optimize+ /platform:anycpu /out:dist\segyemabyul.exe /reference:System.dll /reference:System.Drawing.dll /reference:System.Windows.Forms.dll src\*.cs

if errorlevel 1 (
  echo BUILD FAILED
  pause
  exit /b 1
)

echo.
echo OK -^> dist\segyemabyul.exe
endlocal
