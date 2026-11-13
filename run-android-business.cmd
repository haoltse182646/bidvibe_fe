@echo off
setlocal
cd /d "%~dp0"
echo Android business tests now run through the shared dashboard for reports and cleanup.
echo Select Android mobile on the dashboard, then start the test run.
node e2e\system\dashboard.mjs
set "BIDVIBE_ANDROID_EXIT=%ERRORLEVEL%"
pause
exit /b %BIDVIBE_ANDROID_EXIT%
