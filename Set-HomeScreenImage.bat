@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Set-HomeScreenImage.ps1" %*
set exit_code=%ERRORLEVEL%
if not "%exit_code%"=="0" goto :end
if exist "%LOCALAPPDATA%\Microsoft\Windows\Themes\67Custom.theme" start "" "%LOCALAPPDATA%\Microsoft\Windows\Themes\67Custom.theme"
:end
endlocal & exit /b %exit_code%
