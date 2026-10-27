# Android E2E Test Result

## Latest configured run — 2026-10-26

- **Environment:** branch `testing_branch`, commit `30ea7b2`; Flutter 3.47.4 / Dart 3.13.3; `emulator-5554` (Android 16 / API 36).
- **Configuration:** User supplied all five required defines. Credential and fixture values are intentionally omitted from this report.
- **Build/install:** **PASS** — Android debug APK built and installed.
- **E2E result:** **FAIL** — sign-in, fixture discovery, and details passed; the test timed out waiting for discovery after back navigation.

| Test | Result | Detail |
|---|---|---|
| `integration_test/auction_e2e_test.dart` | **FAIL** | Reached details for the configured auction. After `tester.pageBack()`, `_pumpUntil` failed with “Back navigation should return to bidder discovery.” Failure reported at `auction_e2e_test.dart:135`; wait helper at line 35. |
| `integration_test/bidder_discovery_test.dart` | **NOT RUN** | Not part of this configured run. It remains unchanged. |

### Journey reached and effects

The test signed in, reached discovery, found the configured title and ID, tapped the matching card, and verified the auction detail screen. It then invoked `tester.pageBack()` but did not observe the discovery heading within the 45-second wait. Logout was not reached. The journey contains no deposit or bid action; neither was attempted. The test may have left the emulator authenticated, so inspect the app and sign out before reusing that emulator.

### Failure analysis and suspected causes

This is an observed test failure, but the log alone does not establish whether the Navigator failed to pop or the app returned to a different state. The exact failing expectation only establishes that the discovery title was not found after `tester.pageBack()`. No screenshot, current route, login-form state, or backend response was captured at failure time.

Likely causes to investigate, in order:

1. **Navigation did not pop the detail route.** Check the route stack and whether the Android back event is handled by the detail route or an overlay. The detail assertions passed, so the test had reached the detail page before issuing back.
2. **The app returned to login or another shell state.** The bidder shell and detail screen automatically log out on some authentication errors. On returning, `BidderHomeScreen` starts a fresh auction load, and the shell queues notification/data refresh work; an expired/invalid session or unauthorized response could therefore replace the shell before the discovery assertion. This is plausible, not proven—the run did not record whether login fields or logout action were present afterward.
3. **The discovery screen returned but its expected heading was absent/not rendered.** Verify the active tab, widget tree, and visible state; the test currently treats only the heading as proof that it returned.

The earlier hit-test issue at the auction button did **not** recur: `ensureVisible`, `hitTestable()`, and the subsequent details assertion all passed in this run. The new blocker is back navigation, not discovery tapping or loading details.

For the next diagnostic run:

1. At the back-navigation failure, capture a screenshot and inspect the widget tree, presence of the discovery heading, login fields, and logout button. Avoid logging credentials or personal data.
2. Check whether the detail route remains current. If it did pop, check whether the RootShell still has the bidder session and whether a refresh/notification request returned an auth error.
3. If login is shown, inspect backend/session expiry and the API responses triggered by returning to the bidder shell. If detail remains shown, inspect back-event dispatch and any active dialog/route overlay.
4. After fixing or identifying the cause, rerun the full journey and confirm it returns to discovery **and completes logout**.
5. The account/password were supplied directly in a test command, which may be retained in shell/process history. Rotate the test password if that command history is shared or exposed. Keep it and the fixture values out of reports and repository files.

### Next steps

`bidder_discovery_test.dart` covers the same main login → discovery → detail → back → logout journey. It remains unchanged and was not run with the supplied configuration.

## Related automated checks — 2026-10-26

| Command / check | Result |
|---|---|
| `flutter pub get` | **PASS** — dependencies resolved. Pub reported 28 newer package versions incompatible with current constraints; no upgrades were made. |
| `flutter analyze` | **PASS** — no issues found. |
| Auction tests | **PASS** — 45 tests. |
| Wallet/notification tests | **PASS** — 21 tests. |
| Profile/chat tests | **PASS** — 66 tests. |
| Address/disputes tests | **PASS** — 9 tests. |
| Documented QA business suite | **PASS** — 141 tests. |
| `flutter test --coverage` | **PASS** — 244 passed, 2 skipped, no failures. The skipped live-order tests require backend environment variables and sent no requests. |

See [unit_test_report.md](./unit_test_report.md) for the recorded coverage report and its limitations. The integration journey results above are separate from the unit/widget/API suite.

## Earlier Android attempts

- **2026-10-26, missing-defines run:** both integration APKs built and installed, but both test bodies skipped because the required defines were absent; no login or API requests occurred.
- **2026-10-24, `bidder_discovery_test.dart`:** **SKIPPED** because required defines were absent; the test body did not run.
- **2026-10-24, `auction_e2e_test.dart`:** **BLOCKED/SKIPPED** because local test configuration was unavailable; no E2E assertions ran.
- **2026-10-25:** **SKIPPED** because no E2E define values were available. No test API requests were made.
- **2026-10-26, initial auction fixture:** **FAIL** — the configured title/ID did not match a discovery result; the journey stopped before details or logout.
- **2026-10-26, updated auction fixture:** **FAIL** — discovery found the matching card, but the detail button tap was not hit-testable and the detail assertion timed out. No deposit or bid was attempted. This prompted the scroll-into-view/tappability guard; see the analysis above.

The report intentionally contains no credential values, tokens, or personal account information.
