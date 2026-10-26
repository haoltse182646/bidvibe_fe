# Android E2E Test Result

## Latest run — 2026-10-26 (updated auction fixture)

- **Test:** `integration_test/auction_e2e_test.dart`
- **Environment:** branch `testing_branch`, commit `fd1d169`; Flutter 3.47.4 / Dart 3.13.3; `emulator-5554` (Android 16 / API 36).
- **Safety prerequisite:** The user confirmed the bidder account is dedicated to E2E and the backend uses an isolated, disposable test database. This was not independently inspected.
- **Build/install:** **PASS** — the Android debug APK was built and installed.
- **E2E result:** **FAIL** — discovery found the configured auction card, but the test did not open its details.

### Failure explanation

The updated fixture was found: the test located a card matching both the configured title and auction ID. The failure occurred at the next step, when it tried to tap **“Xem chi tiết phiên”**. Flutter emitted a hit-test warning: the button's tap position would not hit the button, possibly because the widget was off-screen or obscured. The following details assertion then timed out:

> The selected auction details should match the configured ID.

The warning occurred at the tap in `auction_e2e_test.dart:116`; the assertion was reported by `_pumpUntil` at line 35, called from line 117. The most likely cause based on the output is that the matching card/button was outside the visible viewport (or covered) and the integration test tapped without first scrolling it into view. The test output alone does not prove which condition prevented the hit. The supplied credentials and fixture strings are intentionally not repeated here.

### Journey reached and effects

The test signed in, reached discovery, submitted the search, and found the matching card. It failed before verifying details, navigating back, or reaching logout. No deposit or bid action is part of this journey, and neither was attempted. Because the run ended before logout, check the emulator session and sign out manually before reusing it if the app retained the login.

The report intentionally contains no credential values, tokens, or personal account information.

### Recommended next steps

1. Update the E2E test to scroll the matching card/button into view before tapping it (or otherwise ensure the button is visible and hittable).
2. Rerun the test and verify that details, back navigation, and logout all complete.

## Related automated checks — 2026-10-26

| Command | Result |
|---|---|
| `flutter analyze` | **PASS** — no issues found |
| `flutter test --coverage` | **PASS** — 244 passed, 2 skipped, no test failures |

The two skipped tests are live-order tests that require backend environment variables; they made no backend requests. See [unit_test_report.md](./unit_test_report.md) for the line coverage result and coverage limitations.

## Earlier attempts

- **2026-10-24, `bidder_discovery_test.dart`:** **SKIPPED** because required defines were absent. The test body did not run.
- **2026-10-24, `auction_e2e_test.dart`:** **BLOCKED/SKIPPED** because the required local test configuration was unavailable. APK build/install succeeded in the later attempt; no E2E assertions ran.
- **2026-10-25, before the latest run:** **SKIPPED** because no E2E define file/values were available. The emulator was online and port 5000 was listening; no test API requests were made in that skipped run.
- **2026-10-26, earlier `auction_e2e_test.dart` run:** **FAIL** — the first fixture did not produce a matching title/ID card in discovery; the test stopped before details or logout.
