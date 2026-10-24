# Android E2E Test Result

- Date: 2026-10-24
- Target: `emulator-5554` (Android 16, API 36)
- Test: `integration_test/bidder_discovery_test.dart`
- Command: `flutter test integration_test/bidder_discovery_test.dart -d emulator-5554`
- Result: **SKIPPED** — 1 test skipped; no E2E assertions ran.

The test reported these required defines as missing: `BIDVIBE_API_BASE_URL`, `BIDVIBE_E2E_EMAIL`, `BIDVIBE_E2E_PASSWORD`, `BIDVIBE_E2E_AUCTION_TITLE`, and `BIDVIBE_E2E_AUCTION_ID`. With the defines absent, the test callback did not run and no login, auction, or other backend requests were made.

The configured backend `.env` was classified as targeting hosted Supabase. The running backend process's effective environment was not independently verified, and hosted database access for this E2E was not approved. The authenticated flow was therefore not attempted.

To proceed, supply the five values through a secure local mechanism and confirm that reads against the running backend's effective database target are approved. Do not record the password or other secrets in this file.

## Retry attempt — 2026-10-24

- Emulator: **Available** (`emulator-5554`, Android 16 / API 36).
- Backend: **Started** using the documented `npm run dev` command after confirming `.env` targets localhost and there is no process, user, or machine `DATABASE_URL` override. The backend startup message indicated its scheduler was active.
- E2E result: **BLOCKED — test not run**. The five required `BIDVIBE_*` Dart defines were not available in the local process/user/machine environment. The supplied auction title and ID were blank in the response; the strings used were example-style placeholders, not verified fixture values.
- Cleanup: The backend process was stopped without running the E2E test. No test login or auction requests were made.

Before retrying, make the five Dart defines available through a secure local mechanism, provide the actual live fixture title and ID, and verify the local disposable database still contains those fixtures. Do not store passwords or other secrets in this report.

## Retry attempt — 2026-10-24 (latest)

- Target: `emulator-5554` (Android 16 / API 36); device was online.
- Backend: Not running on port 5000 when checked. It was not started for this attempt because the harness had no required inputs and would skip before executing its test callback.
- Input check: **BLOCKED** — none of `BIDVIBE_API_BASE_URL`, `BIDVIBE_E2E_EMAIL`, `BIDVIBE_E2E_PASSWORD`, `BIDVIBE_E2E_AUCTION_TITLE`, or `BIDVIBE_E2E_AUCTION_ID` were available to the Flutter process. No values were printed or recorded.
- Command: `flutter test integration_test\bidder_discovery_test.dart -d emulator-5554`
- Build/install: **PASS** — debug APK built and installed on the emulator.
- Test result: **SKIPPED** — Flutter reported the single test skipped because all five required defines were missing. The test callback and its login, discovery, detail, and logout assertions did not execute.
- Network/data effects: **None from this test** — no API request or login was attempted.
- Overall E2E status: **BLOCKED**, not passed.

Next safe step: supply the five defines locally through the approved secure mechanism, including the exact live test auction title and ID. Confirm the local backend is running against the verified disposable database, then rerun the same command with those defines supplied as `--dart-define` values. Do not place credentials in this report or source control.
