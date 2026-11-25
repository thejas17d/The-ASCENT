@echo off
rem Build the Android debug APK and install it on a USB-connected phone (USB debugging on).
set GODOT=%USERPROFILE%\.godot\Godot_v4.4.1-stable_win64_console.exe
set ADB=%USERPROFILE%\.android-toolchain\sdk\platform-tools\adb.exe
if not exist "%~dp0build" mkdir "%~dp0build"
"%GODOT%" --headless --path "%~dp0." --export-debug "Android" "%~dp0build\TheAscent.apk"
"%ADB%" devices
"%ADB%" install -r "%~dp0build\TheAscent.apk"
pause
