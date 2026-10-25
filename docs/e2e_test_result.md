# Android E2E Test Result

## Latest run — 2026-10-25

- **Test:** `integration_test/auction_e2e_test.dart`
- **Device:** `emulator-5554` (Android 16 / API 36)
- **Backend check:** Port 5000 was listening. The configured `.env` database host was classified as local; no process, user, or machine `DATABASE_URL` override was found.
- **Build:** **PASS** — the Android debug APK was built and installed.
- **E2E result:** **FAIL** — the app reached auction discovery, but the configured auction card was not found before the test timed out.

### Failure explanation

After entering the configured title and tapping Search, the test waits up to 45 seconds for an auction card that contains **both** the exact configured title and auction ID. That condition was not met:

> Discovery should show the configured live auction title and ID.

The failure was reported by `_pumpUntil` at `auction_e2e_test.dart:35`, called from the discovery check at line 107. In plain language, the app did not show a card matching the two configured fixture values during the wait.

The command copied into the test log shows example-style replacement strings for the title and ID. If those strings were passed literally, instead of being replaced with the real live auction title and ID, the test would search for a fixture that does not exist. However, the actual define values were deliberately censored, so this report cannot confirm whether that is what happened.

Other possibilities that cannot be distinguished from this log alone:

- The title or ID does not exactly match the same auction.
- The auction is not live or is not visible to the bidder.
- The API search returned no matching auction.
- The returned auction data did not match the UI's exact title/ID locator.

### Journey reached and effects

The test did not skip for missing defines and progressed to the discovery step. It failed before confirming/opening auction details, navigating back, or logging out. No deposit or bid action is part of this journey, and neither was attempted. The run reached backend-dependent discovery, but the captured output has no sanitized request/response details to identify what the API returned.

The report intentionally contains no credential values, tokens, or unredacted personal information.

### Recommended next steps

1. Locally confirm the compile-time defines contain the real dedicated bidder account and the exact title and ID of the **same** live test auction; do not add these values to this report.
2. Confirm that the auction is live and visible to that bidder on the backend addressed through `http://10.0.2.2:5000`.
3. Re-run the documented command with the real values substituted for the examples.
4. If it still fails, capture only sanitized evidence such as result count and returned auction title/ID. Do not include passwords, JWTs, or personal data.

## Earlier attempts

- **2026-10-24, `bidder_discovery_test.dart`:** **SKIPPED** because required defines were absent. The test body did not run.
- **2026-10-24, `auction_e2e_test.dart`:** **BLOCKED/SKIPPED** because the required local test configuration was unavailable. APK build/install succeeded in the later attempt; no E2E assertions ran.
- **2026-10-25, before the latest run:** **SKIPPED** because no E2E define file/values were available. The emulator was online and port 5000 was listening; no test API requests were made in that skipped run.
