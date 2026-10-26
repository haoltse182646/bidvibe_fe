# Flutter Unit and Widget Test Report

## Latest validation — 2026-10-26

**Environment:** branch `testing_branch`, commit `fd1d169`; Flutter 3.47.4 / Dart 3.13.3.

| Command | Result |
|---|---|
| `flutter analyze` | **PASS** — no issues found |
| `flutter test --coverage` | **PASS** — 244 passed, 2 skipped, no test failures |

The two skips are the live-order cases in `test/order_live_test.dart`. Their required backend environment variables were not supplied, so neither test body made a backend request. Current LCOV line coverage is **5,985 / 7,839 (76.35%)** across 65 source-file records. The report does not contain function-level coverage data, so this does not prove that every source function has a test. See [e2e_test_result.md](./e2e_test_result.md) for the separate Android E2E failure.

## Earlier run — 2026-10-24

**Date:** 2026-10-24  
**Scope:** Flutter unit/widget tests only. No backend, database, hosted API, or Android E2E requests were made.

## Results

| Command | Result |
|---|---|
| `flutter test test\address_repository_test.dart test\my_disputes_screen_test.dart` | **PASS** — all 9 added tests passed |
| `flutter analyze` | **PASS** — no issues found |
| `flutter test --coverage` | **PASS** — 244 passed, 2 skipped |
| `git diff --check` | **PASS** — no whitespace errors |

The two skips are the existing live-order tests, which require the environment variables `BACKEND_URL`, `TEST_PASSWORD`, `TEST_BIDDER_EMAIL`, and `TEST_BUYER_EMAIL`. They were not supplied; those tests did not contact a backend.

## Added coverage

- [address_repository_test.dart](../test/address_repository_test.dart): address parsing/formatting, validation, and list/create/update/default/delete request contracts, including malformed responses and invalid IDs.
- [my_disputes_screen_test.dart](../test/my_disputes_screen_test.dart): loading and empty states, rendered dispute labels, error/retry, and expired-session notification.
- [testing.md](./testing.md): updated focused-test commands and coverage description.

## Coverage and completeness limits

The generated LCOV report records **5,985 of 7,839 executable lines hit (76.35%)** across 65 source-file records. It contains no `FN`, `FNDA`, `FNF`, or `FNH` records, so it cannot establish function-level coverage or prove that every function has a test.

Two files in the LCOV report had no covered executable lines: `lib/screens/addresses/address_book_screen.dart` and `lib/features/notifications/notification_events.dart`. Other functions and branches may also be uncovered. Therefore, **this run does not establish that every existing function is unit-tested**; complete function-by-function coverage remains unverified.

See [testing.md](./testing.md) for test conventions and safe full-stack E2E prerequisites.
