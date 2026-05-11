@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Set-HomeScreenImage.ps1" %*
set exit_code=%ERRORLEVEL%
if not "%exit_code%"=="0" goto :end
if exist "%LOCALAPPDATA%\Microsoft\Windows\Themes\CopilotCustom.theme" start "" "%LOCALAPPDATA%\Microsoft\Windows\Themes\CopilotCustom.theme"
:end
endlocal & exit /b %exit_code%
