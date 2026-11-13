@echo off
setlocal
cd /d "%~dp0"
node e2e\system\dashboard.mjs
pause
