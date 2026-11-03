@echo off
setlocal
cd /d "%~dp0"
node e2e\android\run.mjs business
set "BIDVIBE_ANDROID_EXIT=%ERRORLEVEL%"
pause
exit /b %BIDVIBE_ANDROID_EXIT%
