# Latest connected E2E report: findings and corrective plan

Report: `e2e/system/reports/2026-11-11T03-09-24-578Z-67aa9b/`

Evidence reviewed:

- `results.json`
- `connected-execution.log`
- `PRE-CLEANUP-RESULTS.json`
- `cleanup-result.json`
- failure screenshots under `evidence/`
- the run's source snapshot under `source/`
- the prior diagnosis and implementation notes in `e2efix.md`

## Run summary

| Result | Count |
|---|---:|
| PASS | 14 |
| FAIL | 5 |
| SKIP | 28 |

Cleanup passed. It removed the owned run fixtures, made a backup, and reports
no held deposits released or ledger rows preserved/detached. The five failures
are not five independent application defects: two are the same broken bid
dialog assertion, and three are the same incorrect order-row selector. The 28
skips are blocked dependents of these earlier failures, not 28 additional
observed failures.

## Findings

| First failing case(s) | Report evidence | Cause | Corrective action |
|---|---|---|---|
| X-S04, X-N03 | Both fail with `Bid confirmation dialog did not open`. Diagnostics simultaneously show `alertDialogs: 1`, the dialog title/content, both `Xác nhận đặt giá` texts, an enabled realtime controller, valid amount `60000`, and `flutterException: null`. | The UI dialog did open. The new helper uses `find.widgetWithText(AlertDialog, 'Xác nhận đặt giá')` and requires exactly one match, although the same label appears in both the dialog title and its confirmation button. This makes the widget-with-text finder cardinality unsuitable; the helper reports a test-finder failure as a missing UI dialog. No failed API bid or Flutter exception is evidenced. | Find the unique dialog with `find.byType(AlertDialog)` and verify its title/action as descendants. Do not require a single widget-with-text match for a string repeated in the dialog. Continue tapping the `FilledButton` scoped to that dialog and retain post-submit UI/API checks. |
| X-R01, X-K01, X-N04 | Each fails waiting for `exact owned order tile <id>`. The stack points to `_openOrder`; screenshots show the `Hồ sơ` profile page. | `_openOrder` navigates to `Hồ sơ`, whose recent-order rows are built by `AuthProfileScreen`. The stable `order-$id` key added in the prior fix is on the different `OrdersScreen` full-list rows, not on the profile's recent-order rows. Consequently the requested key cannot appear on the current route. | From `Hồ sơ`, tap `Xem tất cả đơn hàng`, wait for `OrdersScreen`, then locate its `ValueKey('order-$id')`. Alternatively, add the same stable key to the profile's order `ListTile`; whichever route is used, wait for the exact order ID before tapping. |

### The 28 skips

The skip reasons in the report name missing prerequisite flags. They are
downstream of the five failures above:

- **Main auction flow:** X-S04 failed, so X-S05 and X-M01–X-M05 could not run;
  their dependent X-S06–X-S15 chain was also blocked. This is X-S05 plus the
  15 cases previously audited, not 16 new failures.
- **Refund flow:** X-R01 failed before creating its UI-visible dispute;
  X-R02–X-R07 were skipped.
- **Keep-resolution flow:** X-K01 failed before creating its UI-visible
  dispute; X-K02–X-K04 were skipped.
- **Payment-negative flow:** X-N04 failed while opening the owned order;
  X-N05, X-N06, and X-N08 were skipped.

These skipped cases have no execution evidence in this run. They should not be
reported as individually failed.

The run did pass X-M06–X-M08, X-N01–X-N02, X-N07, and the setup cases
X-S01–X-S03, among others. This confirms some independent moderation and
negative-case branches work; it does not validate the skipped cases.

## Why the previous attempt appeared to make more tests fail

The previous `e2efix.md` recommendations correctly sought to avoid the old
generic-scroll exception, but two implementation details introduced false
failures:

1. The bid helper converted a visible dialog into a failure because it treated
   an exact text finder as a unique dialog identity. In the bid dialog, the
   title and submit button intentionally have the same text. The report's
   `alertDialogs: 1` and visible title/body/button prove this was a test
   assertion problem, not evidence that the app failed to open the dialog.
2. The order helper switched from title selection to a stable key but did not
   follow the app's actual navigation route. It went to the profile page while
   looking for a key only present on the full orders page. The screenshot and
   `_openOrder` stack confirm a route/key mismatch, not a missing backend order.

The new waits made the test stop at these exact assertions, so previously
blocked branches now appear as skips. The report does not show that fixing one
app defect caused 28 new application failures.

## Recommended fixes and rerun order

1. Correct `_waitForDialog`: identify one `AlertDialog` by type, then verify the
   expected title is present within it without requiring a single text-match
   ancestor. Keep the final action finder scoped to the dialog and button type.
2. Correct `_openOrder`: navigate from `Hồ sơ` to `Xem tất cả đơn hàng` before
   using `order-$id`, or key the profile's recent-order tile and confirm the
   target order is among the displayed rows. Include route and matching IDs in
   timeout diagnostics.
3. Run focused, non-business-mutating widget tests for the dialog finder and
   both order-navigation paths. Confirm that duplicate title/action text still
   resolves to one dialog and one scoped submit button.
4. Run the connected suite on an explicitly authorized target with fresh
   fixtures. Verify the earliest previously failing cases first: X-S04, X-R01,
   X-K01, X-N03, and X-N04. Check API state before retrying any bid or payment
   action after an ambiguous result.
5. Only after these prerequisites pass, evaluate X-S05/X-M01–X-S15,
   X-R02–X-R07, X-K02–X-K04, and X-N05/X-N06/X-N08. Report a downstream case
   as failed only if it actually runs and emits a failure event.

## Validation and safety notes

This document records analysis only; no test or application code was changed
for this report review. Use `results.json` and `connected-execution.log` as the
authoritative status/stack evidence, and the screenshots to verify the route
shown. Cleanup succeeded and retained a backup. The connected suite mutates
business fixtures, so reruns should use fresh owned fixtures and the project's
explicit business-test authorization.

## Implementation update (2026-11-12)

Applied the two test-helper corrections in
`integration_test/mobile_web_e2e_test.dart`:

- Dialog waits now identify a unique `AlertDialog` and check for the expected
  descendant title, allowing the bid title and confirmation action to share
  the same label. The bid confirmation action remains scoped to that dialog.
- `_openOrder` now selects “Xem tất cả đơn hàng” from the profile, waits for
  `OrdersScreen` to finish loading, reveals the keyed order row, and then opens
  it. This supports orders outside the profile's three recent-order entries.

Validation completed: `flutter analyze integration_test/mobile_web_e2e_test.dart`
reported no issues, `flutter test test/order_flow_test.dart` passed all 19
tests, and `git diff --check` passed. The connected suite was not rerun because
it mutates shared business fixtures. Hot restart was attempted, but no Flutter
app was connected to the active Dart Tooling Daemon.

## New connected report analysis (2026-11-12)

Report: `e2e/system/reports/2026-11-12T15-52-28-642Z-c79399/`

The run completed with **20 PASS, 6 FAIL, and 21 SKIP**. Cleanup passed and
stored a backup. The failures are different from the earlier finder issues:
the bid/dialog path now passes (including X-S04 and X-M05), but the order
navigation change is not fully validated because several order-related cases
fail during fixture setup, before they reach `_openOrder`.

### Failures and causes

| Case(s) | Evidence | Finding and next action |
|---|---|---|
| X-M07, X-R01, X-K01, X-N04, X-N07 | X-R01/X-K01/X-N04/X-N07 fail while the local connected control command is setting up a branch. Its error says `GET /api/orders/mine: HTTP 500 42703`, wrapped as control `HTTP 409`. X-M07's stack reaches the test's `/api/orders/mine` request and `ApiClient._decode`, which returns `Lỗi hệ thống`. | PostgreSQL SQLSTATE `42703` means an undefined column. A read-only check of the configured backend database later confirmed `010_runner_up_offer.sql` was unapplied and `orders.is_runner_up_offer` was absent. The existing backend query selects that column. Applying the existing migration is the direct fix; do not hide the 500 by returning an empty order list or weakening the setup assertion. |
| X-S06 | Test waits for `Bạn đã thắng phiên này` after the fixture is ended and times out. Its screenshot shows the Android system “bidvibe isn't responding” dialog over the auction page. | The screenshot alone does not establish an ANR during X-S06. A later bug report dated the saved ANR at 22:54:24 local time, during X-S01 (22:54:17–22:54:51), several minutes before X-S06 (22:58:03–22:59:22). The same stale system dialog was captured in later screenshots. The X-S06 failure itself does not record the backend winner/order state. The updated test now verifies API status, winner identity and order first, then refreshes the UI controller before asserting the winner text. Re-run it to distinguish stale UI state from a backend/winner mismatch. |

The X-M07 screenshot also contains the Android “isn't responding” dialog, but
the saved ANR timestamp is from X-S01, not X-M07. X-M07's direct code failure
is still the `/api/orders/mine` request returning the undefined-column error.
The ANR trace's Java main thread was in the normal Android message-loop wait;
the bug report also recorded substantial emulator CPU and memory pressure.
It did not identify a blocked Flutter/Dart stack. Treat this as a possible
emulator resource/startup issue, not as evidence for an unverified app-code
change.

### The 21 skips

These are blocked dependents, not additional observed failures:

- X-S06 blocks X-S07 through X-S15 (**9 skips**) because the winner/order
  prerequisite was not recorded. Consequently the address, payment, seller,
  and warehouse steps did not run.
- X-R01 blocks X-R02 through X-R07 (**6 skips**) because refund-dispute setup
  failed before the Android dispute flow began.
- X-K01 blocks X-K02 through X-K04 (**3 skips**) because keep-dispute setup
  failed before the Android dispute flow began.
- X-N04 blocks X-N05 and X-N06 (**2 skips**) because payment fixture setup
  failed; X-N08 is also blocked (**1 skip**) because its `expiredReady`
  prerequisite depends on the uncompleted payment-expiry path.

X-N07 is a further independent failure with the same `/api/orders/mine`
backend error; it does not add another downstream skip in this report.

### Recommended order of work

1. **Backend:** apply the outstanding migration and verify authenticated
   `GET /api/orders/mine` returns HTTP 200 with the expected response shape.
   Then check connected fixture setup for refund, keep, payment, and
   restricted-bidder branches.
2. **X-S06:** use the test's API winner/order assertions and explicit
   controller refresh to distinguish a realtime/UI race from a wrong winner.
   If it still fails, inspect the fresh API diagnostics and only then change
   app behavior.
3. **Emulator ANR:** the saved report points to X-S01 and resource pressure,
   not a captured blocked Dart stack. Reproduce separately on a responsive
   emulator with adequate CPU/RAM; capture a fresh ANR trace if it recurs.
4. **Revalidate in bounded steps:** rerun the non-mutating dialog/order widget
   tests; then run the connected cases with fresh authorized fixtures. Confirm
   X-S06 reaches the winner UI and owned order, then exercise X-S07–X-S15.
   Re-run X-R01, X-K01, X-N04, and X-N07 only after the backend endpoint
   returns successfully, and then evaluate their dependent cases.
5. Report skips as blocked until their prerequisites execute; do not count them
   as independent failures.

Run evidence confirms X-S04/X-M05 passed with the updated dialog matching.
It does **not** yet validate the new full-orders navigation path: X-R01,
X-K01, and X-N04 failed in fixture setup before `_openOrder`, and X-S06 failed
at the winner-state wait before any order-opening flow.

### Implementation follow-up (2026-11-12)

- The backend database configured for this workspace had migrations 001–009
  applied, while `010_runner_up_offer.sql` was pending. Applied it with
  `npm run db:migrate`; the migration adds `orders.is_runner_up_offer` and
  updates the effective-order uniqueness rule. A follow-up read-only schema
  check confirmed the migration is recorded, the column exists, and no
  migrations remain pending. The backend checkout's pre-existing
  `package-lock.json` modification was left untouched.
- Updated X-S06 in `integration_test/mobile_web_e2e_test.dart` to assert the
  ended auction and signed-in winner from the API, locate the exact owned
  order, refresh the mounted live controller, and then assert the winner UI.
  This should resolve a missed realtime refresh if that caused the old failure;
  it also fails explicitly if the API winner differs.
- The emulator bug report dates the ANR to 22:54:24 local, overlapping X-S01
  registration. The captured Java main thread was waiting in the normal
  `Looper` message queue, with high emulator CPU/memory pressure; no blocked
  Dart stack was available. No speculative app performance change was made.
- Validation: `flutter test test/order_flow_test.dart` passed all 19 tests.
  `flutter analyze integration_test/mobile_web_e2e_test.dart` reported no
  issues, and `git diff --check` passed. Hot restart could not run because no
  Flutter app was connected. The connected suite has not been rerun: it creates
  and deletes business fixtures, so fresh test authorization is required. The
  migration fix is applied to the configured backend database, but the prior
  six-case run's outcome is not claimed as resolved until that rerun completes.

## Latest connected run and follow-up (2026-11-12)

Report: `e2e/system/reports/2026-11-12T16-26-00-797Z-d0b616/`

The connected run completed with **22 PASS, 4 FAIL, and 21 SKIP**. Cleanup
passed, a backup was stored, and no held deposits were released. The previous
`/api/orders/mine` undefined-column error did not recur; X-M07 and X-N07 passed,
consistent with migration 010 being applied.

### Failures

| Case(s) | Report evidence | Cause |
|---|---|---|
| X-S06 | The test confirmed the auction API was `ended`, the signed-in bidder was the winner (`won: true`), and found owned order 2179. It then failed because `_panelController` returned null. | `AuctionDetailScreen` uses a lazy `ListView`; `AuctionBidPanel` is not guaranteed to be mounted while off-screen. The null controller is a test-finder/lifecycle issue, not evidence that the API winner or order creation failed. The saved screenshot still showing “Đang diễn ra” is not reliable proof of stale state because each scenario unmounts its widget tree in `finally`, while the device screenshot can retain the last rendered frame. No ANR dialog was present in this run. |
| X-R01, X-K01, X-N04 | Each timed out waiting for “Xem tất cả đơn hàng” on the profile screen, after the backend fixture/order setup succeeded. Screenshots show the profile at its top. | `AuthProfileScreen` uses a lazy `ListView`; the order section and its navigation button are not built until scrolling reaches them. The helper waited for the button before revealing the order section. This is a test navigation/scroll-order issue, not a missing order/API setup failure. |

The **21 skips** are blocked dependents, not separate observed failures:
X-S06 blocks X-S07–X-S15 (9), X-R01 blocks X-R02–X-R07 (6), X-K01 blocks
X-K02–X-K04 (3), and X-N04 blocks X-N05, X-N06, and X-N08 (3).

### Test-helper corrections made

- `_openOrder` now reveals “Đơn hàng của tôi” first, waits for the profile's
  order section to reach a populated, empty, or error state, then reveals and
  selects “Xem tất cả đơn hàng”. It continues to open the exact keyed order
  row from `OrdersScreen`.
- X-S06 now taps the existing “Làm mới phiên” action instead of reading a
  controller from the potentially unmounted bid panel. It waits until the
  detail screen reports “Đã kết thúc”, reveals the lazy winner message, and
  then verifies that message. Backend winner and exact-order assertions remain
  in place.
- No production UI or backend behavior was changed for these failures.

### Validation and remaining work

- `flutter analyze integration_test/mobile_web_e2e_test.dart`: passed.
- `flutter test test/order_flow_test.dart`: all 19 tests passed.
- `git diff --check`: passed.
- Hot restart was attempted, but no Flutter app was registered with the active
  Dart Tooling Daemon.
- A connected rerun is still needed to verify X-S06, X-R01, X-K01, and X-N04
  and then exercise their dependents; do not treat the skipped cases as
  passed. The connected runner creates and cleans up shared business fixtures,
  so get fresh authorization before another run.
