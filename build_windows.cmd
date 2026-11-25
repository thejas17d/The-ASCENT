@echo off
rem Build the standalone Windows game into build\windows (TheAscent.exe + TheAscent.pck).
set GODOT=%USERPROFILE%\.godot\Godot_v4.4.1-stable_win64_console.exe
if not exist "%~dp0build\windows" mkdir "%~dp0build\windows"
"%GODOT%" --headless --path "%~dp0." --export-release "Windows Desktop" "%~dp0build\windows\TheAscent.exe"
echo.
echo Done: build\windows\TheAscent.exe  (keep TheAscent.pck next to it)
pause
