@echo off
setlocal
title BidVibe - Playwright Business E2E
cd /d "%~dp0"
set "BIDVIBE_TEST_EXIT=1"

if not exist "pubspec.yaml" goto :wrong_folder
if not exist "e2e\playwright\runner\package.json" goto :missing_runner
if not exist "e2e\playwright\runner\runner.local.json" goto :missing_config
if not exist "e2e\playwright\runner\credentials.local.json" goto :missing_config

where flutter >nul 2>&1
if errorlevel 1 goto :missing_flutter
where npm >nul 2>&1
if errorlevel 1 goto :missing_npm

echo This run creates test data on the API configured in runner.local.json.
echo Close other BidVibe E2E runs before starting this one.
echo.
echo [1/3] Building the current saved Flutter Web source...
call flutter build web --debug --no-web-resources-cdn
if errorlevel 1 goto :failed

pushd "e2e\playwright\runner"
if errorlevel 1 goto :failed
set "BIDVIBE_IN_RUNNER=1"
echo.
echo [2/3] Installing dependencies from package-lock.json...
call npm ci
if errorlevel 1 goto :failed

echo.
echo [3/3] Running Playwright business tests in Chrome...
call npm run test:business -- --headed
set "BIDVIBE_TEST_EXIT=%ERRORLEVEL%"
popd
set "BIDVIBE_IN_RUNNER="
goto :finish

:wrong_folder
echo ERROR: Put this CMD file in the bidvibe_fe root, beside pubspec.yaml.
goto :finish
:missing_runner
echo ERROR: The e2e\playwright\runner folder is missing from this checkout.
goto :finish
:missing_config
echo ERROR: Create runner.local.json and credentials.local.json in the runner folder first.
goto :finish
:missing_flutter
echo ERROR: Flutter was not found in PATH. Check flutter --version in a new terminal.
goto :finish
:missing_npm
echo ERROR: npm was not found in PATH. Install Node.js and reopen this window.
goto :finish
:failed
set "BIDVIBE_TEST_EXIT=1"
if defined BIDVIBE_IN_RUNNER popd
set "BIDVIBE_IN_RUNNER="
echo.
echo Stopped because a step above failed. Review the first error before retrying.
:finish
echo.
if "%BIDVIBE_TEST_EXIT%"=="0" echo Finished. Review the PASS and SKIP counts above.
if not "%BIDVIBE_TEST_EXIT%"=="0" echo The run did not complete successfully. Review the error above.
echo Test reports are stored in e2e\playwright\runner\reports.
pause
exit /b %BIDVIBE_TEST_EXIT%
