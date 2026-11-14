# Playwright E2E configuration check

## Summary

The Playwright runner is present at `e2e/playwright/runner`. Its package scripts,
configuration, and test discovery work from that directory: `npm run test:list`
successfully listed all 30 tests in 16 files on 2026-11-11. This does **not**
launch a browser or prove that the app/API setup is ready.

The most concrete configuration mismatch found was that the runner README
described copying/running files from `e2e/playwright`, while `package.json`, the
Playwright config, scripts, and expected local configuration files are under
`e2e/playwright/runner`. Following those old commands from the documented
location would fail to find the package or configuration; the README has since
been corrected.

## Mismatches and required corrections

1. **Use the actual runner directory.** Run npm commands from
   `e2e\playwright\runner`. The required private files are
   `runner.local.json` and `credentials.local.json` in that directory. The root
   `run-e2e-business.cmd` also checks for those exact paths.
   The workspace had local JSON files at `e2e/playwright/`; those are not the
   paths read by the runner. A root ignore rule now excludes those files. Keep
   credentials private and do not commit them.

2. **README paths corrected.** Use the existing `e2e/playwright/runner`
   directory. Its README and quick-start now show the proper working directory
   and safe copy-if-missing commands for the private example configs.

3. **Build the app with the intended API target.** The Flutter app reads
   `config/dev.json` when it is built. `BIDVIBE_API_URL` in the Playwright
   runner config does not override the API URL embedded in the Flutter build;
   it is used by test helpers and the fixture clock. The checked-in example
   URLs currently both point at the same Render API. Before each run, make sure
   `config/dev.json`, `runner.local.json`, `credentials.local.json`, and the
   backend checkout's local `.env` all target the intended, mutually compatible
   API/database. Rebuild Flutter Web after changing `config/dev.json`.

4. **Business tests are intentionally gated and mutate data.** The example
   runner config sets `BIDVIBE_ALLOW_SHARED_MUTATIONS` to `"false"`, so a
   business run will stop until it is explicitly set to the exact string
   `"true"`. Only do this for an authorized test target. The business wrapper
   also requires `BIDVIBE_BE_ROOT` to point to a backend checkout with
   dependencies installed and a local `.env`. The fixture clock uses that
   backend's database and validates fixtures against the configured API; a
   mismatch can stop the run and must not be bypassed.

5. **Provide system Chrome, or change the browser configuration deliberately.**
   `playwright.config.ts` selects `channel: 'chrome'`, which expects Google
   Chrome to be installed. The test-list check does not validate Chrome. Install
   Chrome before running, or remove the channel setting and install/use
   Playwright's bundled Chromium consistently.

6. **Keep the local configs out of version control.** The runner's own
   `.gitignore` covers `*.local.json` inside `runner`, but the workspace also
   reports untracked local JSON files one directory above it. Add an appropriate
   ignore rule at the project level (or otherwise ensure those files remain
   untracked) and commit only the `.example.json` templates. Never put passwords,
   tokens, or backend `.env` contents in the repository.

## Recommended Windows run sequence

From the repository root, after configuring the target safely:

```cmd
flutter build web --debug --no-web-resources-cdn
cd e2e\playwright\runner
npm ci
if not exist runner.local.json copy runner.local.example.json runner.local.json
if not exist credentials.local.json copy credentials.local.example.json credentials.local.json
npm run test:list
npm run test:auth -- --headed
```

Copy the example files only when the corresponding private config does not
already exist; do not overwrite populated local credentials. Fill in the local
config before running. Start with `test:list`, then the non-business auth suite.
Run `npm run test:business -- --headed` or the root
`run-e2e-business.cmd` only after confirming the mutation gate, API/database
alignment, Chrome, ports 8886/8891, and all test accounts. The business suite
creates backend test data and wallet transactions.

## What was verified and what remains

- Verified: Node.js `v22.16.0` satisfies the package's Node `>=20` requirement;
  npm `10.9.2` is available.
- Verified: `npm run test:list` succeeds from `e2e/playwright/runner` and
  discovers 30 tests.
- Not verified in the initial check: browser launch, app readiness, account login,
  backend connectivity, fixture-clock/database connectivity, or a full business
  run. `where chrome` did not find Chrome on PATH, but a Chrome executable was
  subsequently found in a standard Windows installation location.
- The existing `e2e/playwright/report/REPORT.html` records a previous run with
  19 PASS and 11 FAIL across 30 cases and identifies UI failures. Treat those
  as application/test assertion failures, not configuration fixes; the report
  is historical and does not establish the result for the current source.

## Separate system dashboard startup error

The root `run-e2e-dashboard.cmd` starts `e2e/system/dashboard.mjs`. This is a
separate test harness from the Playwright runner under
`e2e/playwright/runner`.

The reported `TypeError [ERR_INVALID_ARG_TYPE]` at `dashboard.mjs:18` is a
configuration error, not a Playwright/browser failure. Startup resolves five
path settings from `e2e/system/runner.local.json`:
`frontendRoot`, `webRoot`, `backendRoot`, `credentialsFile`, and
`playwrightRoot`. Initially, `webRoot` and `playwrightRoot` were missing, so
`path.resolve(here, config[key])` received `undefined`. `webRoot` was encountered
first and caused the reported crash; `playwrightRoot` would also have failed.

### Fix

1. Edit **`e2e/system/runner.local.json`**, not
   `e2e/playwright/runner/runner.local.json`. Ensure all five path settings
   above exist and are non-empty strings. Paths may be absolute or relative to
   `e2e/system` (the dashboard script's directory).
2. Set `webRoot` to the actual local React `bidvibe-web` checkout and
   `playwrightRoot` to this repository's `e2e/playwright/runner` directory.
   The original example file had machine-specific absolute paths; it now uses
   relative sibling paths. Keep `frontendRoot` pointing to this Flutter repository,
   `backendRoot` to the intended backend checkout, and `credentialsFile` to the
   private Playwright credentials file.
3. Before starting the dashboard, validate required keys without printing
   config values:

   ```cmd
   node -e "const c=require('./e2e/system/runner.local.json');for(const k of ['frontendRoot','webRoot','backendRoot','credentialsFile','playwrightRoot'])if(typeof c[k]!=='string'||!c[k].trim())console.error('Missing or empty:',k)"
   ```

4. Confirm each configured path exists and points to the right project, then
   run `run-e2e-dashboard.cmd` again.

This fixes the observed startup exception only. Subsequent startup may still
report missing dependencies, invalid credentials/API configuration, or backend
connectivity problems. Dashboard suites can mutate shared database state and
require `allowSharedDatabaseMutations: true` before starting a run; only enable
that for an explicitly authorized test database.

### Applied fixes (2026-11-11)

- Added required non-empty and path-type validation to `dashboard.mjs`; missing
  paths now produce a named configuration error rather than Node's
  `ERR_INVALID_ARG_TYPE`.
- Added `webRoot` and `playwrightRoot` to the machine-local system dashboard
  config, pointing at the sibling React checkout and this runner respectively.
  Other local settings, including the database-mutation gate, were preserved.
- The React repository `haoltse182646/bidvibe-web` was absent locally, so it was
  cloned to the sibling `bidvibe-web` directory and its npm dependencies were
  installed from `package-lock.json`.
- Updated the committed system config example to use relative sibling paths,
  updated the system E2E setup instructions with the clone command, corrected
  the Playwright runner README/quick-start paths, and ignored top-level local
  Playwright JSON configs.
- Verified the dashboard config paths resolve, the React tests pass (17/17),
  its production build succeeds, and the system harness tests pass (14/14).
  No browser E2E or database-mutating dashboard suite was run.

## Latest connected-suite report analysis — 2026-11-11

Report: `e2e/system/reports/2026-11-11T01-33-05-895Z-2d48d6/REPORT-connected.html`
and its `connected-execution.log`, `results.json`, and
`evidence/connected_X-S04_FAIL.png`.

### Results

- **30 PASS, 1 FAIL, 16 SKIP.** The run is correctly marked FAIL.
- The only failed case is **X-S04 — “Two isolated Android bidders fund, deposit
  and compete.”**
- The 16 SKIPs are dependent main-auction cases, not separate observed defects.
  X-S04 did not set its `competed` prerequisite, so X-S05 skipped; without
  X-S05's `bidReady`, report/moderation cases skipped; the same missing auction
  progress then prevented the winner, payment, warehouse, delivery and receipt
  cases from running. Independent termination, dispute, account, and negative
  scenarios did run and account for the 30 PASS results.
- Database cleanup is **PASS**. The report records a backup, no held deposits
  released, and cleanup of this run's fixtures.

### Confirmed failure cause

The execution log provides a Dart stack, not just the summary `Bad state: No
element`:

```text
Iterable.single
WidgetController.widget
_bid.<anonymous closure> (mobile_web_e2e_test.dart:249)
_wait (mobile_web_e2e_test.dart:58)
_bid (mobile_web_e2e_test.dart:249)
X-S04 (mobile_web_e2e_test.dart:385)
```

In `_bid`, after tapping the bid confirmation, the polling predicate calls
`t.widget<AuctionBidPanel>(panel).controller.data` without first confirming
that `panel` has exactly one match. `WidgetController.widget` uses a single
match; when the finder has zero matches it throws `StateError: No element`.
That exception escapes immediately from the predicate, so `_wait` cannot wait
for the panel to appear or report a useful readiness timeout.

X-S04 reaches its first bidder's `_bid` call after registration, listing
submission, appraisal, top-up, auction navigation, and deposit. The failure
stack points at the first bid's UI-state predicate, before the test logs out
or registers the competing bidder. The failure screenshot shows the auction
detail and deposit confirmation. Thus the failure is **not evidence that the
React dashboard or test configuration failed**, nor does this report prove an
API bid rejection.

The exact underlying reason is not directly logged. However, the failure
screenshot shows the auction detail scrolled to the deposit section, immediately
above the bid panel. `AuctionDetailScreen` uses a `ListView`, whose children are
lazily mounted as they enter the viewport. The most likely explanation is that
the confirmation/action caused a rebuild or scroll-position change that
unmounted the offscreen bid panel; the test then queried its finder without
scrolling it back into view. The report does not record scroll position,
controller state, or whether the bid committed, so this remains a strong
evidence-based hypothesis rather than a proven UI/runtime defect.

### Fixes and next steps

1. After bid confirmation, scroll the `Dùng giá tối thiểu` control back into
   view so the lazy `ListView` mounts `AuctionBidPanel`. Keep the post-submit
   readiness check safe: verify `panel.evaluate().length == 1` before reading
   the widget, then wait for the UI's leading state. If the panel never returns,
   fail with a targeted message rather than `Iterable.single`. Do not silently
   interpret a missing panel as a successful bid.
2. At the end of the wait, capture diagnostic evidence for the auction detail
   route: visible screen/route, whether the panel exists, controller
   `loading`/`posting`/`connected`/`dirty`/`notice` values when available,
   visible UI errors, and uncaught Flutter errors. Redact credentials, tokens,
   and personal account data.
3. Check backend/API state for the owned auction and bidder after the failed
   attempt to distinguish “UI assertion failed after a successful bid” from
   “bid did not commit.” Use the run's fixture IDs and existing API/state
   verification; do not retry a possibly committed bid against the old fixture.
4. Re-run the connected suite using a fresh run and fixture after the predicate
   and diagnostics are corrected. X-S04 must complete both bidder UI flows and
   verify each deposit/bid state; then confirm X-S05, moderation, winner,
   payment and fulfillment cases proceed. Review all SKIPs and cleanup status
   before calling the run successful.
5. Keep the existing API/database alignment and mutation authorization checks.
   The report's successful cleanup is useful evidence but does not make it safe
   to rerun business mutations on an unauthorized target.

### Applied X-S04 test fix — 2026-11-11

- Updated `integration_test/mobile_web_e2e_test.dart` so the post-bid poll checks
  the `AuctionBidPanel` finder count before reading its controller. A temporary
  missing/offstage panel no longer throws `Iterable.single` immediately; the
  test waits up to 60 seconds for the UI to report the current bidder leading.
- The test now scrolls the bid control back into view after the confirmation.
  This should remount the lazy `ListView` child before polling its controller.
- The test now records panel count, login/detail visibility, controller loading,
  posting, socket connection, dirty/uncertain state, and notice presence/text in
  failure evidence. It also reads the owned auction from the API after the UI
  wait, recording leading/status/bid count to distinguish an accepted API bid
  from a missing UI update. The test still fails if the UI does not confirm the
  leading state; API success alone cannot turn it into a pass.
- `flutter analyze integration_test/mobile_web_e2e_test.dart` passes. A targeted
  `flutter test` invocation built and loaded the integration test but was not a
  valid E2E run: without the system runner's local control URL and prerequisites,
  X-S04 was correctly blocked and direct test reporting then failed because
  `/checkpoint` had no host. It did not exercise the bidding flow or mutate
  backend data.
- Hot restart could not be performed because no Flutter app was connected to
  the workspace DTD.
- **Still required:** rerun the `connected` dashboard suite using an authorized
  database and fresh fixtures. Confirm X-S04 passes both bidders and review the
  recorded UI/API diagnostics plus downstream case statuses. If it still fails,
  use those diagnostics to investigate the missing panel or bid outcome; this
  code change fixes the premature finder exception but cannot prove the
  underlying transient UI condition is resolved without that run.

## Latest connected-suite rerun — 2026-11-11 02:04Z

Report: `e2e/system/reports/2026-11-11T02-04-02-660Z-4053c4/REPORT-connected.html`
and `results.json` / `connected-execution.log`.

### Results and exact blocker

- **31 PASS, 1 FAIL, 15 SKIP.** Cleanup passed, with a backup and no held
  deposits released.
- **X-S04 now passes** after the prior `_bid` safe-poll/scroll change. The
  report shows the UI confirmed the buyer leading and API `bidCount: 2`.
- **X-S05 is now the sole failure.** It performs a buyer bid, successfully
  submits an external competitor bid, and observes the Android UI no longer
  leading. It then fails before completing the buyer's final outbid.
- The new stack is different from the earlier X-S04 failure:

  ```text
  WidgetController.element
  WidgetController.dragUntilVisible
  WidgetController.scrollUntilVisible
  _reveal (mobile_web_e2e_test.dart:79)
  _tap (mobile_web_e2e_test.dart:88)
  _bid (mobile_web_e2e_test.dart:248)
  X-S05 (mobile_web_e2e_test.dart:442)
  ```

  In the exact source saved with this run, `_bid:248` taps the
  **“Xác nhận đặt giá”** button. That `_tap` calls `_reveal`, which calls
  `scrollUntilVisible` while the confirmation button is absent. Its first
  scroll raises `StateError`; the catch retries in the reverse direction, but
  that also cannot find the element and throws `Bad state: No element`.
- The prior `bidUiDiagnostics` in the X-S05 result belong to the last completed
  `_bid` call: UI and API both confirmed the buyer leading with `bidCount: 3`.
  They are not a post-failure snapshot. The external competitor action and
  realtime update were reached, but the result does not establish whether the
  final buyer bid was submitted.
- The screenshot shows the auction detail near its top, not an open confirmation
  dialog. This proves the test could not find the dialog's confirmation button;
  it does not establish why the dialog was absent. Possibilities include the
  “Đặt giá” action being disabled/no-op after a transient socket state, a
  validation or Flutter exception preventing the dialog, or a stale/out-of-view
  control. Capture the reason rather than assuming it is another lazy-panel
  unmount.

### Fix the shared bid-confirmation flow before continuing

1. Change `_bid` to keep the second tap from masking the real problem:
   - Verify the `FilledButton('Đặt giá')` is uniquely present and has a non-null
     `onPressed` before tapping it.
   - After tapping it, wait directly for the confirmation `AlertDialog` and its
     “Xác nhận đặt giá” button to appear. Do **not** call `_reveal` or scroll the
     background list to search for a modal control.
   - If the dialog does not appear within a short bounded wait, record the
     current screen, panel/controller state, amount-field value/validation,
     visible error text, and `WidgetTester.takeException()` before failing with
     a targeted “bid confirmation dialog did not open” message.
   - Confirm through the button scoped to that dialog; then use the existing
     post-submit UI and API verification.
2. Harden `_reveal`: a missing modal/dialog element should not trigger scrolling
   an unrelated page. Select the intended vertical scrollable on the current
   route and make any reverse-direction retry conditional on that scrollable
   and target still existing. Preserve a clear failure if the target remains
   absent; do not swallow the `StateError`.
3. Keep the API state check after the final UI bid. If the test fails after an
   action, query only the owned auction/bidder before deciding whether a retry
   is safe. Always use a new run/fixture for a rerun.

### Audit of the 15 skipped cases

All 15 are dependency-blocked downstream of X-S05, not independent failures:

| Cases | Required chain | Review / next risk |
|---|---|---|
| X-M01 | X-S05 `bidReady` | Creates the main-auction report in Android, then registers/checks the exact flag in React. |
| X-M02 | X-M01 `reported` | React pauses the live auction and waits for Android Socket.IO state. Its `_wait` reads `t.widget<AuctionBidPanel>(p)` without checking that the finder still has one match. |
| X-M03 | X-M02 `pausedVerified` | Checks UI bid disabled plus `AUCTION_PAUSED` API rejection. It also directly reads the panel/button; retain panel-presence and tappability guards. |
| X-M04 | X-M02 `pausedVerified` | React verify action must clear the pause per the backend policy. It uses another unguarded panel lookup during live state updates. |
| X-M05 | X-M04 `verification` | React safe action, external competitor bid, then Android bid. It reuses both `_outbidExternally` and `_bid`, so it is directly exposed to the X-S05 confirmation/reveal problem. |
| X-S06 | X-M05 `resumedVerified` | Ends the owned auction, checks winner order and loser deposit refund. Confirm the local clock fixture is registered, UI observes the ended/winner state, and loser wallet assertions match actual account balances. |
| X-S07 | X-S06 `winnerReady` | Creates/selects address and pays by wallet; checks exact balance change. Verify address validation, payment confirmation, and wallet sufficient funds. |
| X-S08 | X-S07 `paid` | Seller sends the exact paid order to warehouse; ensure seller shipment card is found by exact order/title and API stage advances. |
| X-S09 | X-S08 `shipped` | Warehouse receive action; API must reach `inspecting`. |
| X-S10 | X-S09 `wh-receive` | “Khớp mô tả” inspection; API must reach `inspected`. |
| X-S11 | X-S10 `wh-inspect` | Pack action; API must reach `packed`. |
| X-S12 | X-S11 `wh-pack` | Ship action requires carrier/tracking inputs; API must reach `shipped`. |
| X-S13 | X-S12 `wh-ship` | Delivery action; API must reach `delivered`. |
| X-S14 | X-S13 `wh-deliver` | Buyer notification must reference the exact order and open it. |
| X-S15 | X-S13 `wh-deliver` | Buyer receipt must complete and API payout reach `released`; runs independently of X-S14 once delivery passes. |

The plan's prerequisite edges match the code's state flags for this chain.
Source review found no basis to call these 15 cases failed, and the report has
no execution evidence for them. Before the rerun, harden the common UI helpers
rather than changing the dependency plan: in addition to the bid dialog fix,
guard the direct `AuctionBidPanel` reads in X-M02–X-M06 so a transient finder
absence becomes a bounded, diagnostic wait. The repeated `_reveal`/`_tap`
helpers are used by the address, shipment and warehouse actions too; keep their
scroll target scoped and add specific readiness assertions where a dialog or
modal must open.

### Recommended next run

1. Implement and analyze the shared bid-dialog and panel-lookup hardening.
2. Run the complete connected suite on an explicitly authorized target with
   fresh fixtures; do not rerun only a possibly committed bid against old data.
3. Review results in sequence: X-S05 buyer outbid and API bid count; X-M01–M05
   report/pause/verify/safe and bidding; X-S06 winner/refund; X-S07 payment;
   X-S08–S13 each warehouse transition; X-S14 notification navigation;
   X-S15 payout release.
4. If a case fails, stop treating later SKIPs as new errors. Fix the earliest
   failed prerequisite, preserve report evidence, and check cleanup/financial
   state before the next fresh-fixture run.

## Source audit of the 15 skipped cases — 2026-11-11

The report contains no execution evidence for X-M01–X-M05 or X-S06–X-S15:
they were skipped because X-S05 did not set `bidReady`. The following are
source-level risks, not claims that these cases have failed. The common
failure pattern to prevent is a target that is absent (or temporarily
unmounted) being passed to `_tap`/`_reveal`, whose generic scroll retry can
throw `Bad state: No element` and hide the original UI condition.

| Case | Source-level UI risk | Potential fix before rerunning |
|---|---|---|
| X-M01 | Report submission taps `Xác nhận gửi` by global text without first waiting for or scoping to the confirmation `AlertDialog`. If the dialog does not open, `_reveal` may search the page instead. | After tapping `Gửi báo cáo`, wait for the expected `AlertDialog` and tap its descendant confirmation button. On timeout, capture the form error and visible screen state. |
| X-M02 | The `connected` and paused-state `_wait` predicates call `t.widget<AuctionBidPanel>(p)` without checking that the panel finder still has exactly one match. A transient route/list rebuild can throw instead of waiting. | Use a bounded panel-ready wait that checks `p.evaluate().length == 1` before reading the controller; include route visibility and controller flags in timeout diagnostics. |
| X-M03 | The paused-state poll has the same unguarded panel lookup. The test then reads the `Đặt giá` button without asserting it exists uniquely; the intended disabled button can be absent while the panel is rebuilding. | Guard panel access, then wait for exactly one bid button and assert its `onPressed` is null. Keep the existing API rejection and unchanged-bid-count assertions. |
| X-M04 | Both the socket-ready and resumed-state polls directly read the panel controller, so a temporary missing panel can fail immediately instead of allowing the existing bounded wait to recover. | Apply the same guarded panel/controller wait as X-M02 and report the last observed `connected`, `paused`, `loading`, and `notice` values on timeout. |
| X-M05 | It uses the same unguarded panel polls in `_outbidExternally`, then reuses `_bid`, the helper that failed in X-S05. A missing confirmation dialog or transient panel can therefore reproduce the prior failure. | Fix the shared `_bid` dialog flow first; also guard `_outbidExternally` panel reads and wait for `leading == false` only while the panel is present. |
| X-S06 | `_end` returns as soon as the API says `ended`, then the test immediately searches for the winner text. The UI/socket may not yet have updated; `_reveal` is not a state wait and may mask an absent result. | Wait with a deadline for the winner state in the auction UI (and retain the exact order API check); report controller data if the UI does not converge. |
| X-S07 | Address creation/selection and payment use global text taps. Payment opens an `AlertDialog`, but the confirmation `TextButton('Thanh toán')` is not scoped to it. Missing routes/dialogs can be misreported by `_reveal`; the wallet selection can also be disabled while balance loads or is insufficient. | Wait for the address form and saved-address selector; assert the wallet option is enabled and selected. Wait for the payment dialog and tap its descendant confirmation button, then preserve the existing order/wallet API checks. |
| X-S08 | The seller shipment card is located by product title and private runtime type, not by the exact order. Duplicate titles can make the card finder ambiguous or select the wrong row. | Identify the row using a stable order/fixture identifier displayed in the shipment card, assert exactly one matching card, then verify the exact order's stage as the test already does. |
| X-S09 | Warehouse list navigation taps the product title only; duplicate titles can open the wrong order. The expected receive control exists on the active `WarehouseOpsDetailScreen`, but its stage-specific presence/enabled state is not checked before tapping. | Match the list row with the owned order's stable code/identifier, assert the detail belongs to that order, then wait for the receive action before tapping and verify `inspecting`. |
| X-S10 | It relies on the default `match` radio choice and taps `Khớp mô tả` without asserting the owned detail or radio is visible/selected. A list/detail mismatch or delayed API screen can make the generic tap fail. | Select or assert the `Khớp mô tả` radio within the owned order detail; wait for `Lưu kết quả kiểm định` to be enabled, then verify `inspected`. |
| X-S11 | The pack action is conditional on the API-backed detail reaching `inspected`; the test taps the title/action without a UI readiness assertion. | Assert the exact order detail stage is `inspected`, then wait for the pack button before tapping and verify `packed`. |
| X-S12 | The ship action opens an `AlertDialog`; the test searches for carrier/tracking fields and `Xác nhận gửi` globally. If the dialog does not open, `_enter`/`_tap` can scroll the background rather than diagnose it. | Wait for the ship dialog, scope both labeled fields and the enabled confirm button to it, and capture dialog validation errors if it does not open. Then verify `shipped`. |
| X-S13 | The delivery action is stage-gated and the list title is not a unique order key. A stale or wrong detail can leave `Xác nhận đã giao` absent. | Verify the owned order identifier and `shipped` stage in the detail before tapping; then verify the API reaches `delivered`. |
| X-S14 | `_notification` correctly waits for a matching notification type and `orderId`, but taps `find.text(note.title)` globally. Repeated notification titles can make the target ambiguous or open the wrong notification. | Tap the `ListTile`/card for the matching notification item, ideally keyed by notification ID; retain the exact order-detail destination assertion. |
| X-S15 | `_openOrder` locates an order by title, and the delivery confirmation uses the global `TextButton('Đã nhận hàng')` rather than the confirmation dialog. Duplicate titles or a missing dialog can trigger the same generic scroll failure. | Locate the exact order, wait for the delivery-confirmation `AlertDialog`, tap its descendant button, and verify payout release as already implemented. |

### Warehouse selector cross-check

The connected Android route is `WarehouseShell` → `WarehouseOpsScreen` →
`WarehouseOpsDetailScreen`. In that active route, the test's labels match the
widgets: `Xác nhận kho đã nhận hàng`, `Khớp mô tả`, `Lưu kết quả kiểm định`,
`Xác nhận đóng gói`, `Gửi cho đơn vị vận chuyển`, and `Xác nhận đã giao`.
Do not “fix” these strings based on the separate local/demo
`WarehouseDetailScreen`, which is not the connected ops route. The remaining
warehouse risk is identifying the exact owned order and waiting for the
stage-specific action/dialog, not a confirmed label mismatch.

### Priority and next action

1. Fix and verify the X-S05 shared bid confirmation flow; it is the prerequisite
   for all 15 skipped cases.
2. Before the full connected run, add guarded controller waits for X-M02–X-M05
   and scope confirmation controls for X-M01, X-S07, X-S12, and X-S15.
3. Make shipment/order/notification selection unique to the owned fixture, then
   add stage/action readiness checks for X-S06 and X-S08–X-S14.
4. Run with fresh fixtures and preserve the first failing case's screenshot,
   visible UI, controller state, and API stage. A source-level risk becomes a
   confirmed issue only if that case executes and produces evidence.

## Implemented UI hardening — 2026-11-11

Applied the fixes to `integration_test/mobile_web_e2e_test.dart` and added
stable widget keys to the owned order, seller shipment, warehouse order, and
notification rows so tests can select a fixture by ID instead of ambiguous
product/title text.

- `_bid` now checks that the submit button is unique and enabled, waits for the
  bid-confirmation dialog without scrolling the page, and taps only the action
  inside that dialog. A missing dialog fails with visible text, amount-field,
  panel/controller, and pending Flutter-exception diagnostics. Post-bid
  verification still checks both Android UI state and the exact auction API.
- `_reveal` retries in reverse only while the same scrollable still exists and
  includes both scroll errors when neither direction reveals the target.
- Auction-panel polling in X-M02–X-M05 and the termination cases now checks
  finder cardinality before reading controller state and includes the last
  controller snapshot on timeout. The external-bid wait uses the same guard.
- Confirmation dialogs for deposit, report, payment, bid, warehouse shipment,
  and delivery are now explicitly awaited and action taps are scoped to the
  dialog. Missing dialogs include visible UI text and a pending Flutter
  exception where available.
- X-S06 waits for the ended-winner UI before continuing. Order and warehouse
  detail navigation verifies the owned fixture ID; seller shipment and
  notification rows use stable keys. X-S09–X-S13 assert the expected starting
  API stage and wait for the corresponding enabled action before mutating.
- Warehouse selector labels remain unchanged because they were verified
  against the connected ops route.

Validation: targeted `flutter analyze` on the changed test and UI surfaces
passed. The focused order, notification, seller, and screen regression tests
passed (**46 passed, 2 skipped**). The connected Android suite was not rerun
because it performs business mutations against configured live fixtures; use
fresh authorized fixtures to validate X-S05 and the 15 downstream cases.
No Flutter app was active in DTD, so the requested hot restart could not be
performed; the Flutter unit tests and analyzer were run instead.
