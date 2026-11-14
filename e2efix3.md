# E2E report findings and next steps

Report reviewed: `e2e/system/reports/2026-11-12T16-48-10-490Z-0ec68b/`

Evidence reviewed:

- `results.json`
- `connected-execution.log`
- the failure screenshots for X-S04, X-M08, and X-N01
- `cleanup-result.json`
- `e2efix2.md` and the relevant test/UI source

## Result summary

| Result | Count |
|---|---:|
| PASS | 24 |
| FAIL | 3 |
| SKIP | 20 |

Cleanup passed, a backup was stored, and the report lists no held deposits
released. The three failures are localized test/UI synchronization failures.
They do not establish three backend business-rule defects. The 20 skips are
cases whose prerequisites did not complete; they are not additional failures.

The report's passing cases include X-S01–X-S03, X-R01–X-R07, X-K01–X-K04,
X-U01–X-U05, and X-N04–X-N08. These show that registration/listing/appraisal,
the refund and keep dispute paths, account administration, and the later
payment-negative cases completed in this run. They do not validate the skipped
bid/moderation/auction-shipping flows.

## Findings

### X-S04 — competitor wallet top-up never became editable

The failing assertion is `wallet editable` in `_topup`. X-S04 first topped up
the original buyer, opened the auction, joined, and successfully placed a bid.
It then logged in the competitor and started a second top-up; that second
wallet step is where the failure occurred. The `bidUiDiagnostics` showing
`"Đặt giá thành công."` and `bidCount: 1` therefore describe the already
completed original-buyer bid, not a failed competitor bid.

`BidderWalletScreen` renders its top-up `TextFormField` later in a `ListView`,
below the visible wallet header and balance card. The screenshot is at the top
of that wallet screen. `_topup` waits for the field to exist and be enabled,
but does not reveal/scroll to it first. Because `ListView` builds children
lazily, the off-screen field may not exist in the widget tree yet; the wait
cannot make it appear by itself. The assertion also does not record whether
the field was absent or present-but-disabled, so the report cannot rule out a
wallet load error as a secondary cause.

**What to do**

1. Reveal the top-up field before waiting for its enabled state; prefer a
   stable key for the field rather than relying on its position in the list.
2. Wait for wallet loading to finish and require the field to exist exactly
   once and be enabled before entering the amount.
3. If it remains disabled, report the wallet screen state (`_loading`,
   `_posting`, `_loadingMore`, `_uncertain`, whether `_wallet` loaded, and
   `_error`) and the wallet/transaction load result. Do not bypass the UI by
   directly crediting the wallet through an API call.
4. Preserve the existing post-top-up API balance assertion.

### X-M08 and X-N01 — `_openAuction` selects an off-screen lazy dropdown

Both failures have the same stack: `_openAuction` calls `_tap` on
`find.byType(DropdownButtonFormField<String>).first`, and `_reveal` throws
`Bad state: No element`. The cases stop before the intended action:

- X-M08 does not reach its invalid termination request.
- X-N01 does not reach the join/deposit check.

`BidderHomeScreen` builds the auction-status dropdown after the search and
category controls in a `ListView`. At the top of the Explore screen the
dropdown is below the viewport and may not yet be built. The `.first` finder
throws when evaluated with no current match, rather than yielding an empty
finder that `_reveal` can scroll into view. The `_reveal` target evaluation
therefore fails before its scroll logic can run. Both screenshots show Explore
at the top, consistent with this lazy-list timing issue. The report does not
show that the termination or insufficient-deposit business rules themselves
failed.

**What to do**

1. Give the status dropdown a stable key and use a non-throwing keyed finder.
2. Reveal/scroll the status filter into view before tapping it, then wait for
   the filter selection and the matching auction results.
3. Harden `_reveal` so a target absent from a lazy list is handled as a bounded
   scroll-and-wait, not as an exception from `.first`. Avoid `.first` on
   finders whose widgets may not yet be mounted; if multiple controls match,
   disambiguate them with keys or a scoped finder after revealing the section.
4. Include route, scrollable count, target count, and visible screen state in
   timeout diagnostics. Do not convert an absent target into a successful
   fallback.
5. Once the common navigation helper is corrected, rerun the non-mutating
   checks first. In the later manually authorized connected run, verify that
   X-M08 reaches the invalid-termination assertion and X-N01 reaches its
   insufficient-funds/no-deposit assertions.

## Why 20 cases were skipped

The skips are all blocked by the first failures:

- **18 skips from X-S04/X-M08:** X-S04 blocks X-S05 and X-M01–X-M05; those
  missing prerequisites block X-S06–X-S15. X-M08 blocks X-M06 and X-M07.
- **2 skips from X-N01:** X-N01 blocks X-N02 and X-N03.

These cases did not execute their test bodies. Their UI and business outcomes
remain unverified. Fix the earliest prerequisite failure in each chain before
interpreting downstream results.

## Relationship to earlier findings

`e2efix2.md` documents the previous run's profile-order lazy-list issue and the
X-S06 winner-panel lookup issue. The current report shows X-R01 and X-K01 now
pass, so the earlier order-navigation failure is not reproduced here. This
run does not execute X-S06 because X-S04 prevents its prerequisite chain from
completing; the current result therefore says nothing new about the X-S06
winner UI correction.

The previous missing database-column failure is also not present in this
report. No backend migration change is indicated by these three new failures.

## Explicit manual-test boundary — do not run the dashboard

The connected test is to be performed manually after the implementation fixes.
Until that manual test is requested and authorized:

**Do not run or launch the dashboard or connected E2E runner. Do not open or
send requests to the configured backend/API or local web URL.**

In particular, **do not execute**:

```powershell
node e2e\system\dashboard.mjs
```

Do not use a dashboard launch script, start the connected suite, call its
connected-run/control endpoints, or open the configured API/web URLs from the
report. Those actions can access the live service and create or mutate shared
business fixtures. Review the saved local report files only; any later manual
connected run should happen after the fixes are implemented and with explicit
authorization.

## Implementation and local validation

Implemented without starting the dashboard, connected runner, or accessing the
configured URLs:

- Added stable keys for the auction status filter, auction search field, and
  wallet top-up amount field. `_openAuction` now reveals and selects the keyed
  filter safely, and no longer relies on `.first` for the dropdown/search
  controls.
- Hardened `_reveal` to wait for route scrollables, search visible scrollable
  elements in both directions, and report route counts, visible text, scroll
  count, and scroll errors if the target remains unavailable.
- `_topup` now reveals the keyed amount field before waiting for it to be
  enabled. If it stays disabled, diagnostics include whether the wallet and
  snapshot loaded and explicit wallet loading, posting, loading-more,
  uncertain-result, and error state markers. The existing balance verification
  remains unchanged; no API top-up bypass was added.
- Added zero-size state markers to the wallet widget for test diagnostics;
  they do not change the rendered UI.

Local validation:

- `flutter analyze integration_test/mobile_web_e2e_test.dart lib/screens/bidder/bidder_home.dart lib/screens/bidder/bidder_wallet.dart` — passed.
- `flutter test test/wallet_api_test.dart test/auction_detail_test.dart test/auction_bidding_test.dart` — passed.
- `git diff --check` — passed.
- Hot restart was attempted, but no Flutter app is connected to the Dart Tooling
  Daemon.

The connected tests remain unrun by design. The manually operated connected
suite should verify X-S04, X-M08, and X-N01 after these changes; downstream
cases remain unverified until their prerequisites pass.
