# BidVibe — Playwright E2E Test Report

Execution window: 30–31 October 2026, Asia/Ho_Chi_Minh (UTC+7). Final verification: 31 October 2026. Original run IDs retain the UTC date 2026-10-30.

## Result and interpretation

**Overall UI E2E result: FAIL — application defects remain.** Across the latest executed outcome of each of 30 unique case IDs: **19 PASS, 11 FAIL**. This is a consolidated report of staged executions, not a claim that one uninterrupted full-suite run passed.

The 30 IDs consist of 27 UI-oriented cases (16 PASS, 11 FAIL), one browser-readiness check (PASS), and two explicitly labelled API setup cases (PASS). Earlier development attempts are retained below. FAIL is preserved even when the business operation committed successfully.

The main order completed delivery and payout; the second order was refunded after a dispute. Successful backend outcomes do not override failed UI assertions. No application fix was applied.

## Environment and reproducibility

- FE snapshot: 55cf07405e8610c9ffe573c961e20fdffc2fbc78 (PR #18 merge). Application source was copied to an isolated directory and left unchanged.
- Flutter Web debug build; Flutter 3.47.6 / Dart 3.13.5. Local static server on 127.0.0.1:8886. No Netlify deployment was changed.
- Runner: Node.js 24.21.0, @playwright/test 1.64.1, installed Google Chrome channel, Windows, one worker, no automatic retries.
- API: https://bidvibe-be.onrender.com; shared team Supabase database, not an isolated test database.
- Local BE modules used for fixture timing: 15d3308493a82f49abde8d0656ce8456c0410767. The commit deployed on Render was not independently verified.
- Six supplied accounts cover five roles. The original bidder B was already JOIN_BLOCKED; a new UI-registered bidder was used for the positive bidding path. Credentials and tokens are excluded.
- Final source check: FE remained clean at the same commit; BE retained only its pre-existing package-lock.json modification.

## Approach and actual coverage

Scenario-based testing means selecting realistic business journeys and their expected outcomes. It is the test design approach; Playwright is the execution tool. ChatGPT assisted with scripting, execution and interpretation. It does not replace assertions or evidence.

Playwright operated public controls through browser accessibility semantics, real keyboard/mouse interaction and a real file chooser. Two isolated browser contexts represented competing bidders and simultaneous buyer/Admin sessions. No UI action was replaced by an API call and then claimed as UI coverage.

The main UI journey was registration → seller listing/upload/submit → appraisal approval → wallet top-ups → deposits → competing bids/realtime → winner/order → address → wallet payment → seller shipment → warehouse receive/inspect/pack/ship/deliver → buyer confirmation/payout. A separate journey covered report/moderation → dispute/refund → notification and wallet assertions.

API requests were additionally used for state verification and two clearly marked setup cases. Auction expiry was accelerated by a localhost-only controller calling existing BE services for newly created, allowlisted fixtures. It checked prefix, seller/title, age under six hours and correspondence with the API record. It used one DB connection and did not start a global scheduler, seed or reset. The timing service was stopped after testing.

## Latest result per case

| Case | Result | Observed outcome | Source |
|---|---|---|---|
| WEB-READY-01 | PASS | Accessible login form exposed without changing application source. | [01-browser-readiness.spec.ts](../runner/tests/01-browser-readiness.spec.ts) |
| PW-AUTH-01 | PASS | UI sign-in, correct role screen, /api/me verification and sign-out. | [02-auth-roles.spec.ts](../runner/tests/02-auth-roles.spec.ts) |
| PW-AUTH-02 | PASS | UI sign-in, correct role screen, /api/me verification and sign-out. | [02-auth-roles.spec.ts](../runner/tests/02-auth-roles.spec.ts) |
| PW-AUTH-03 | PASS | UI sign-in, correct role screen, /api/me verification and sign-out. | [02-auth-roles.spec.ts](../runner/tests/02-auth-roles.spec.ts) |
| PW-AUTH-04 | PASS | UI sign-in, correct role screen, /api/me verification and sign-out. | [02-auth-roles.spec.ts](../runner/tests/02-auth-roles.spec.ts) |
| PW-AUTH-05 | PASS | UI sign-in, correct role screen, /api/me verification and sign-out. | [02-auth-roles.spec.ts](../runner/tests/02-auth-roles.spec.ts) |
| PW-AUTH-06 | PASS | UI sign-in, correct role screen, /api/me verification and sign-out. | [02-auth-roles.spec.ts](../runner/tests/02-auth-roles.spec.ts) |
| PW-LIST-01 | PASS | Actual browser file chooser uploaded fixture image; listing submitted. | [03-registration-listing.spec.ts](../runner/tests/03-registration-listing.spec.ts) |
| PW-REG-01 | PASS | New bidder registered through UI. | [03-registration-listing.spec.ts](../runner/tests/03-registration-listing.spec.ts) |
| PW-APP-01 | FAIL | BE approved and started auction 5517; returning to queue raised a Flutter runtime error. | [04-appraisal.spec.ts](../runner/tests/04-appraisal.spec.ts) |
| PW-BID-01 | PASS | UI top-ups, both deposits, competing bids, realtime update, correct winner and loser deposit refund. | [05-bidding-winner.spec.ts](../runner/tests/05-bidding-winner.spec.ts) |
| PW-PAY-01 | PASS | Winner created/selected address and paid via wallet through UI. | [06-payment.spec.ts](../runner/tests/06-payment.spec.ts) |
| PW-SHIP-01 | PASS | Seller sent the paid test order to the warehouse. | [07-seller-shipment.spec.ts](../runner/tests/07-seller-shipment.spec.ts) |
| PW-WH-01 | FAIL | BE transition succeeded; UI incorrectly displayed “Không cập nhật được đơn hàng.” | [08-warehouse.spec.ts](../runner/tests/08-warehouse.spec.ts) |
| PW-WH-02 | FAIL | BE transition succeeded; UI incorrectly displayed “Không cập nhật được đơn hàng.” | [08-warehouse.spec.ts](../runner/tests/08-warehouse.spec.ts) |
| PW-WH-03 | FAIL | BE transition succeeded; UI incorrectly displayed “Không cập nhật được đơn hàng.” | [08-warehouse.spec.ts](../runner/tests/08-warehouse.spec.ts) |
| PW-WH-04 | FAIL | BE transition succeeded; UI incorrectly displayed “Không cập nhật được đơn hàng.” | [08-warehouse.spec.ts](../runner/tests/08-warehouse.spec.ts) |
| PW-WH-05 | FAIL | BE transition succeeded; UI incorrectly displayed “Không cập nhật được đơn hàng.” | [08-warehouse.spec.ts](../runner/tests/08-warehouse.spec.ts) |
| PW-DELIVERY-01 | PASS | Buyer confirmed receipt; payout status released. | [09-confirm-delivery.spec.ts](../runner/tests/09-confirm-delivery.spec.ts) |
| PW-ADMIN-01 | PASS | Dashboard, flags, disputes, weekly report and accounts opened. | [10-admin-readonly.spec.ts](../runner/tests/10-admin-readonly.spec.ts) |
| SETUP-ADM-01 | PASS | API-only setup of a separate moderation/dispute auction; not UI E2E coverage. | [11-admin-fixture.spec.ts](../runner/tests/11-admin-fixture.spec.ts) |
| PW-MOD-pause | FAIL | BE moderation action succeeded; Admin queue refresh raised a Flutter runtime error. | [12-report-moderation.spec.ts](../runner/tests/12-report-moderation.spec.ts) |
| PW-MOD-safe | FAIL | BE moderation action succeeded; Admin queue refresh raised a Flutter runtime error. | [12-report-moderation.spec.ts](../runner/tests/12-report-moderation.spec.ts) |
| PW-MOD-verify | FAIL | BE moderation action succeeded; Admin queue refresh raised a Flutter runtime error. | [12-report-moderation.spec.ts](../runner/tests/12-report-moderation.spec.ts) |
| PW-REPORT-01 | PASS | Bidder submitted a report through UI. | [12-report-moderation.spec.ts](../runner/tests/12-report-moderation.spec.ts) |
| PW-BLOCK-01 | FAIL | BE correctly returned 403 JOIN_BLOCKED; UI failed to show the supplied business reason. | [13-blocked-bidder.spec.ts](../runner/tests/13-blocked-bidder.spec.ts) |
| SETUP-DISP-01 | PASS | API-only join/bid/expiry/order/QR-simulated-payment setup; not UI payment coverage. | [14-dispute-fixture.spec.ts](../runner/tests/14-dispute-fixture.spec.ts) |
| PW-DISPUTE-01 | PASS | Buyer submitted a dispute through UI; payout became disputed. | [15-dispute-refund-notification.spec.ts](../runner/tests/15-dispute-refund-notification.spec.ts) |
| PW-REFUND-01 | FAIL | Refund, wallet credit, resolved dispute and live buyer notification succeeded; Admin refresh runtime assertion failed. | [15-dispute-refund-notification.spec.ts](../runner/tests/15-dispute-refund-notification.spec.ts) |
| PW-NOTIFY-01 | PASS | Saved shipping notifications loaded after login; selecting one opened order 1754. | [16-notifications.spec.ts](../runner/tests/16-notifications.spec.ts) |

## Application findings

| Finding | Affected cases | Observation and supporting source inspection |
|---|---|---|
| FE-01: Appraiser queue refresh | PW-APP-01 | Approval returned success and auction 5517 existed, but refresh produced a Flutter runtime error. appraiser_ops_screen.dart:49 uses a setState callback that returns the assigned Future. |
| FE-02: Warehouse misleading failure | PW-WH-01 through PW-WH-05 | Each HTTP update succeeded and stage advanced, but UI displayed a failure message. warehouse_ops_screen.dart:166 returns Future.value(updated) inside setState; assertion is caught as a failed operation. |
| FE-03: Admin flag refresh | PW-MOD-pause / verify / safe | Each BE action succeeded; the UI refresh raised a runtime error. admin_ops_cases.dart:47 has the same Future-returning setState pattern. |
| FE-04: JOIN_BLOCKED reason handling | PW-BLOCK-01 | BE correctly rejected a restricted account. UI displayed an uncertain/generic failure instead of the returned business reason. auction_join_panel.dart around line 145 omits JOIN_BLOCKED from the known rejection handling. |
| FE-05: Admin dispute refresh | PW-REFUND-01 | Refund and realtime buyer notification succeeded, then the Admin runtime-error assertion failed. admin_ops_cases.dart:250 has the same refresh pattern. |

Source patterns support the diagnosis; this report does not claim an applied or validated fix. The debug build makes Flutter assertions visible. A release build hiding an assertion would not prove the underlying refresh pattern has been corrected.

Warehouse example: [failure screenshot](evidence/PW-WH-01-failure.png) and [persisted transition](evidence/PW-WH-01-warehouse-transition.json). They show why a transaction must not be repeated blindly after a UI error.

## Notifications: exactly what was demonstrated

During the refund case, the buyer remained signed in in a separate browser context. A real incoming Socket.IO notification:new event matched dispute 217; the notification UI updated without a manual reload, and the wallet balance increased. The overall refund case remains FAIL because of the Admin-side refresh error.

Separately, PW-NOTIFY-01 signed in again, loaded the saved notification history for order 1754 and opened the correct order from the UI. This verifies persisted shipping notifications and navigation. It does not claim live delivery of every warehouse/shipping event or reconnect/offline push coverage. Signed-in realtime reception and persisted history after sign-in are different assertions.

## Final data and side effects

Read-only final verification is saved in [final-state.json](evidence/final-state.json).

- Main listing 5549, auction 5517, order 1754: auction ended, winner 2717, payment paid, payout released after buyer confirmation.
- Secondary listing 5550, auction 5518, order 1755: auction ended, payment paid, dispute 217 resolved with refund. The order API still returned payoutStatus disputed; the dispute record independently confirmed resolved/refund. No additional claim about payout-status normalization is made.
- Both auctions were new E2E fixtures. No existing unrelated auction was shortened or reset.
- Supplied bidder A received a UI test top-up of 10,000; the new bidder received 200,000. These are application test-wallet operations, not real bank transfers. Final balances: A 220,000, new bidder 146,000, original restricted B 198,000; all held amounts 0 at snapshot time.
- Address 509 and test shipment tracking data were created. No real parcel was sent. QR payment for the dispute setup was simulated through API; the main wallet payment was performed through UI.
- Created data was retained as evidence on the shared DB. Other team activity can change subsequent results. Re-running a full business journey creates fresh records and additional test-wallet transactions.

## Evidence traceability

Use case ID → test source → run ID → checkpoint JSON / screenshot. [results-summary.json](results-summary.json) contains the normalized outcomes, source file/line and run IDs. [attempt-history.json](attempt-history.json) retains earlier failures. [execution-summary.log](execution-summary.log) is a derived summary, not the raw terminal log.

| Case | Original run | Selected evidence |
|---|---|---|
| PW-LIST-01 | 2026-10-30-listing-02 | [PW-LIST-01-submitted-listing.json](evidence/PW-LIST-01-submitted-listing.json) |
| PW-REG-01 | 2026-10-30-listing-01 | [PW-REG-01-registration-result.json](evidence/PW-REG-01-registration-result.json) |
| PW-APP-01 | 2026-10-30-appraisal-01 | [PW-APP-01-approval-backend-result.json](evidence/PW-APP-01-approval-backend-result.json), [PW-APP-01-runtime-errors.json](evidence/PW-APP-01-runtime-errors.json) |
| PW-BID-01 | 2026-10-30-bidding-03 | [PW-BID-01-wallet-topups.json](evidence/PW-BID-01-wallet-topups.json), [PW-BID-01-deposits.json](evidence/PW-BID-01-deposits.json), [PW-BID-01-competing-bids.json](evidence/PW-BID-01-competing-bids.json), [PW-BID-01-fixture-time-adjustment.json](evidence/PW-BID-01-fixture-time-adjustment.json), [PW-BID-01-winner-order.json](evidence/PW-BID-01-winner-order.json), [PW-BID-01-loser-deposit-refund.json](evidence/PW-BID-01-loser-deposit-refund.json) |
| PW-PAY-01 | 2026-10-30-payment-02 | [PW-PAY-01-wallet-payment.json](evidence/PW-PAY-01-wallet-payment.json) |
| PW-SHIP-01 | 2026-10-30-fulfilment-01 | [PW-SHIP-01-seller-shipment.json](evidence/PW-SHIP-01-seller-shipment.json) |
| PW-WH-01 | 2026-10-30-fulfilment-01 | [PW-WH-01-warehouse-transition.json](evidence/PW-WH-01-warehouse-transition.json) |
| PW-WH-02 | 2026-10-30-fulfilment-01 | [PW-WH-02-warehouse-transition.json](evidence/PW-WH-02-warehouse-transition.json) |
| PW-WH-03 | 2026-10-30-fulfilment-01 | [PW-WH-03-warehouse-transition.json](evidence/PW-WH-03-warehouse-transition.json) |
| PW-WH-04 | 2026-10-30-fulfilment-01 | [PW-WH-04-warehouse-transition.json](evidence/PW-WH-04-warehouse-transition.json) |
| PW-WH-05 | 2026-10-30-fulfilment-01 | [PW-WH-05-warehouse-transition.json](evidence/PW-WH-05-warehouse-transition.json) |
| PW-DELIVERY-01 | 2026-10-30-fulfilment-01 | [PW-DELIVERY-01-buyer-receipt.json](evidence/PW-DELIVERY-01-buyer-receipt.json) |
| SETUP-ADM-01 | 2026-10-30-moderation-01 | [SETUP-ADM-01-API-fixture-setup.json](evidence/SETUP-ADM-01-API-fixture-setup.json) |
| PW-MOD-pause | 2026-10-30-moderation-01 | [PW-MOD-pause-moderation-result.json](evidence/PW-MOD-pause-moderation-result.json) |
| PW-MOD-safe | 2026-10-30-moderation-01 | [PW-MOD-safe-moderation-result.json](evidence/PW-MOD-safe-moderation-result.json) |
| PW-MOD-verify | 2026-10-30-moderation-01 | [PW-MOD-verify-moderation-result.json](evidence/PW-MOD-verify-moderation-result.json) |
| PW-REPORT-01 | 2026-10-30-moderation-01 | [PW-REPORT-01-report-created.json](evidence/PW-REPORT-01-report-created.json) |
| PW-BLOCK-01 | 2026-10-30-dispute-01 | [PW-BLOCK-01-known-business-rejection.json](evidence/PW-BLOCK-01-known-business-rejection.json) |
| SETUP-DISP-01 | 2026-10-30-dispute-01 | [SETUP-DISP-01-dispute-fixture-preparation.json](evidence/SETUP-DISP-01-dispute-fixture-preparation.json) |
| PW-DISPUTE-01 | 2026-10-30-dispute-01 | [PW-DISPUTE-01-opened-dispute.json](evidence/PW-DISPUTE-01-opened-dispute.json) |
| PW-REFUND-01 | 2026-10-30-dispute-01 | [PW-REFUND-01-refund-wallet-and-live-notification.json](evidence/PW-REFUND-01-refund-wallet-and-live-notification.json), [PW-REFUND-01-admin-runtime-errors.json](evidence/PW-REFUND-01-admin-runtime-errors.json) |
| PW-NOTIFY-01 | 2026-10-30-notifications-01 | [PW-NOTIFY-01-saved-shipping-notifications.json](evidence/PW-NOTIFY-01-saved-shipping-notifications.json) |

Raw Playwright HTML reports, results.json, JUnit output and traces remain in the private runner reports/<run-id>/ folders. Open the HTML with playwright show-report. Raw files may include authentication details or network tokens; they are deliberately excluded from the shareable package. Selected JSON evidence is redacted; the warehouse image was inspected before inclusion.

## Execution history and harness corrections

| Run ID | Passed | Failed/timed out |
|---|---|---|
| 2026-10-30-readiness-01 | 0 | 1 |
| 2026-10-30-readiness-02 | 1 | 0 |
| 2026-10-30-auth-01 | 6 | 0 |
| 2026-10-30-listing-01 | 1 | 1 |
| 2026-10-30-listing-02 | 1 | 0 |
| 2026-10-30-appraisal-01 | 0 | 1 |
| 2026-10-30-bidding-01 | 0 | 1 |
| 2026-10-30-bidding-02 | 0 | 1 |
| 2026-10-30-bidding-03 | 1 | 0 |
| 2026-10-30-payment-01 | 0 | 1 |
| 2026-10-30-payment-02 | 1 | 0 |
| 2026-10-30-fulfilment-01 | 3 | 5 |
| 2026-10-30-moderation-01 | 2 | 3 |
| 2026-10-30-dispute-01 | 2 | 2 |
| 2026-10-30-notifications-01 | 1 | 0 |
| 2026-10-30T17-09-56-255Z-e3a482 | 7 | 0 |

The initial readiness attempt clicked an off-viewport accessibility placeholder; keyboard focus/Enter corrected the harness. Initial listing/payment attempts failed to deliver some field input and left forms invalid. Two initial bidding attempts failed on an input accessible-name change/background-page typing. Foregrounding the page, actual keyboard input and assertions on field values corrected these harness problems. Their later passing results did not erase the original artifacts. No application source change was used to make these pass.

Business mutations were executed in staged, ordered runs. After runner packaging was refactored for portable configuration and fresh per-run data, all 30 tests were discovered successfully, the fixture controller startup/shutdown was checked with --list, and readiness + all six authentication cases were run again headed: 7/7 PASS. The entire mutating journey has not been re-executed from scratch after packaging changes; its recorded business evidence is from the staged runs above.

## How to rerun and limits

Follow [runner README](../runner/README.md). Use npm run test:auth -- --headed for a non-mutating classroom demonstration. Use npm run test:business -- --headed for a fresh full run against an authorized database. The wrapper creates a unique prefix/state directory, loads private local configuration and stops its timing service afterward.

Existing application bugs can produce FAIL again; re-running does not repair them or guarantee PASS. Build the new FE snapshot after fixes. A previously committed payment/refund must not be replayed just to satisfy a UI assertion. Cases without preconditions are SKIP/not covered, never automatically PASS. The JOIN_BLOCKED negative case is only applicable while the supplied restricted account still has an active restriction.

Not covered: every feature/branch, load/performance, security, real banking, real logistics, native Android E2E, other browser engines, network loss/reconnect, or all dispute resolutions. This report describes the tested snapshot and environment, not a certification of the deployed release.
