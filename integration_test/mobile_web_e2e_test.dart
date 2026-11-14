import 'dart:convert';
import 'dart:ui' as ui;

import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/features/ops/ops_repository.dart';
import 'package:bidvibe/screens/orders/dispute_detail_screen.dart';
import 'package:bidvibe/core/picked_image.dart';
import 'package:bidvibe/core/remote_app_store.dart';

import 'package:bidvibe/main.dart';
import 'package:bidvibe/screens/auth/auth_login.dart';

import 'package:bidvibe/screens/bidder/auction_bid_panel.dart';
import 'package:bidvibe/screens/bidder/bidder_home.dart';
import 'package:bidvibe/screens/bidder/bidder_notifications.dart';
import 'package:bidvibe/screens/bidder/bidder_wallet.dart';
import 'package:bidvibe/features/auctions/auction_live_controller.dart';
import 'package:bidvibe/screens/orders/order_detail_screen.dart';
import 'package:bidvibe/screens/orders/orders_screen.dart';
import 'package:bidvibe/screens/seller/seller_create.dart';
import 'package:bidvibe/store.dart';
import 'package:bidvibe/widgets/photo_picker.dart';
import 'package:bidvibe/widgets/common.dart';
import 'package:bidvibe/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

const _url = String.fromEnvironment('BIDVIBE_API_BASE_URL');
const _control = String.fromEnvironment('E2E_ANDROID_CONTROL_URL');
const _key = String.fromEnvironment('E2E_ANDROID_CONTROL_KEY');
const _prefix = String.fromEnvironment('E2E_ANDROID_PREFIX');
const _allow = bool.fromEnvironment('E2E_ANDROID_ALLOW_BUSINESS');
const _configuredAccounts = {
  'BIDDER_A': (
    'bidder',
    String.fromEnvironment('E2E_BIDDER_A_EMAIL'),
    String.fromEnvironment('E2E_BIDDER_A_PASSWORD')
  ),
  'BIDDER_B': (
    'bidder',
    String.fromEnvironment('E2E_BIDDER_B_EMAIL'),
    String.fromEnvironment('E2E_BIDDER_B_PASSWORD')
  ),
  'BUYER': (
    'bidder',
    String.fromEnvironment('E2E_ANDROID_BUYER_EMAIL'),
    String.fromEnvironment('E2E_ANDROID_BUYER_PASSWORD')
  ),
  'COMPETITOR': (
    'bidder',
    String.fromEnvironment('E2E_ANDROID_COMPETITOR_EMAIL'),
    String.fromEnvironment('E2E_ANDROID_COMPETITOR_PASSWORD')
  ),
  'SELLER': (
    'seller',
    String.fromEnvironment('E2E_SELLER_EMAIL'),
    String.fromEnvironment('E2E_SELLER_PASSWORD')
  ),
  'APPRAISER': (
    'appraiser',
    String.fromEnvironment('E2E_APPRAISER_EMAIL'),
    String.fromEnvironment('E2E_APPRAISER_PASSWORD')
  ),
  'WAREHOUSE': (
    'warehouse',
    String.fromEnvironment('E2E_WAREHOUSE_EMAIL'),
    String.fromEnvironment('E2E_WAREHOUSE_PASSWORD')
  ),
  'ADMIN': (
    'admin',
    String.fromEnvironment('E2E_ADMIN_EMAIL'),
    String.fromEnvironment('E2E_ADMIN_PASSWORD')
  ),
};
final _accounts = {..._configuredAccounts};
final _s = <String, dynamic>{};
final _branches = <String, Map<String, dynamic>>{};
final _evidence = <String, dynamic>{};
String _caseId = '';
final _refundEvents = <Map<String, dynamic>>[];

// RootShell remains mounted under detail routes. Include that offstage root
// when obtaining the real authenticated store; UI finders stay visible-only.
RemoteAppStore _store(WidgetTester t) =>
    t.element(find.byType(RootShell, skipOffstage: false)).read<AppStore>()
        as RemoteAppStore;
ApiClient _api(WidgetTester t) => _store(t).api;
Finder _text(String value) => find.text(value);

Future<void> _wait(WidgetTester t, bool Function() ready, String reason,
    {int seconds = 60}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (!ready() && DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 200));
  }
  expect(ready(), isTrue, reason: reason);
}

AuctionLiveController? _panelController(WidgetTester t, Finder panel) {
  if (panel.evaluate().length != 1) return null;
  return t.widget<AuctionBidPanel>(panel).controller;
}

Future<AuctionLiveController> _waitPanel(
  WidgetTester t,
  Finder panel,
  bool Function(AuctionLiveController) ready,
  String reason, {
  int seconds = 60,
}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  Map<String, dynamic> last = {};
  while (DateTime.now().isBefore(deadline)) {
    final controller = _panelController(t, panel);
    last = {
      'panelMatches': panel.evaluate().length,
      'dataLoaded': controller?.data != null,
      'loading': controller?.loading,
      'posting': controller?.posting,
      'connected': controller?.connected,
      'dirty': controller?.dirty,
      'paused': controller?.data?['paused'],
      'terminated': controller?.data?['terminated'],
      'leading': controller?.data?['leading'],
      'notice': controller?.notice,
      'error': controller?.error,
    };
    if (controller != null && ready(controller)) return controller;
    await t.pump(const Duration(milliseconds: 200));
  }
  fail('$reason; last panel state: ${jsonEncode(last)}');
}

Future<void> _reveal(WidgetTester t, Finder target) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pump(const Duration(milliseconds: 250));
  final scrolls = find.byType(Scrollable);
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (target.evaluate().isEmpty &&
      scrolls.evaluate().isEmpty &&
      DateTime.now().isBefore(deadline)) {
    await t.pump(const Duration(milliseconds: 200));
  }
  final errors = <String>[];
  if (target.evaluate().isEmpty) {
    final scrollableElements = scrolls.evaluate().toList();
    for (final element in scrollableElements) {
      final scrollable = find.byElementPredicate(
        (candidate) => identical(candidate, element),
      );
      for (final delta in [280.0, -280.0]) {
        try {
          await t.scrollUntilVisible(
            target,
            delta,
            scrollable: scrollable,
            maxScrolls: 65,
          );
        } on StateError catch (error) {
          errors.add(error.toString());
        }
        if (target.evaluate().isNotEmpty) break;
      }
      if (target.evaluate().isNotEmpty) break;
    }
  }
  final matches = target.evaluate().length;
  if (matches != 1) {
    final visibleText = find
        .byType(Text)
        .evaluate()
        .map((element) {
          final widget = element.widget as Text;
          return widget.data ?? widget.textSpan?.toPlainText() ?? '';
        })
        .where((value) => value.isNotEmpty)
        .take(60)
        .toList();
    final routes = {
      'BidderHomeScreen': find.byType(BidderHomeScreen).evaluate().length,
      'BidderWalletScreen': find.byType(BidderWalletScreen).evaluate().length,
      'OrdersScreen': find.byType(OrdersScreen).evaluate().length,
      'OrderDetailScreen': find.byType(OrderDetailScreen).evaluate().length,
    };
    fail(
      'Could not reveal target; matches=$matches, '
      'scrollables=${scrolls.evaluate().length}, routes=$routes, '
      'scrollErrors=${jsonEncode(errors.take(8).toList())}, '
      'visibleText=${jsonEncode(visibleText)}',
    );
  }
  await t.ensureVisible(target);
  await t.pump(const Duration(milliseconds: 200));
}

Future<void> _tap(WidgetTester t, Finder target) async {
  await _reveal(t, target);
  await _wait(t, () => target.hitTestable().evaluate().length == 1,
      'target is unobscured and tappable');
  await t.tap(target);
  await t.pump(const Duration(milliseconds: 250));
}

Future<Finder> _waitForDialog(WidgetTester t, String title) async {
  final dialog = find.byType(AlertDialog);
  final dialogTitle = find.descendant(of: dialog, matching: _text(title));
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while ((dialog.evaluate().length != 1 || dialogTitle.evaluate().isEmpty) &&
      DateTime.now().isBefore(deadline)) {
    await t.pump(const Duration(milliseconds: 200));
  }
  if (dialog.evaluate().length != 1 || dialogTitle.evaluate().isEmpty) {
    final visible = find
        .byType(Text)
        .evaluate()
        .map((element) {
          final widget = element.widget as Text;
          return widget.data ?? widget.textSpan?.toPlainText() ?? '';
        })
        .where((value) => value.isNotEmpty)
        .take(80)
        .toList();
    final exception = t.takeException();
    fail('Expected one AlertDialog titled "$title"; '
        'alertDialogs=${dialog.evaluate().length}; '
        'matchingTitleTexts=${dialogTitle.evaluate().length}; '
        'visibleText=${jsonEncode(visible)}; '
        'flutterException=${exception?.toString()}');
  }
  return dialog;
}

Future<Finder> _openDialog(WidgetTester t, Finder trigger, String title) async {
  await _tap(t, trigger);
  return _waitForDialog(t, title);
}

Finder _dialogAction(Finder dialog, String label) {
  final filled = find.descendant(
      of: dialog, matching: find.widgetWithText(FilledButton, label));
  if (filled.evaluate().isNotEmpty) return filled;
  return find.descendant(
      of: dialog, matching: find.widgetWithText(TextButton, label));
}

Future<void> _tapDialogAction(
    WidgetTester t, Finder dialog, String label) async {
  final action = _dialogAction(dialog, label);
  await _wait(
      t,
      () =>
          dialog.evaluate().length == 1 &&
          action.evaluate().length == 1 &&
          action.hitTestable().evaluate().length == 1,
      'dialog action "$label" is uniquely visible and tappable',
      seconds: 10);
  await t.tap(action);
  await t.pump(const Duration(milliseconds: 250));
  await _wait(t, () => dialog.evaluate().isEmpty, 'dialog "$label" closes',
      seconds: 10);
}

Future<void> _confirmDialog(
    WidgetTester t, Finder trigger, String title, String action) async {
  final dialog = await _openDialog(t, trigger, title);
  await _tapDialogAction(t, dialog, action);
}

Future<void> _enterDialogField(
    WidgetTester t, Finder dialog, String label, String value) async {
  final field = find.descendant(of: dialog, matching: _field(label));
  await _wait(
      t,
      () => dialog.evaluate().length == 1 && field.evaluate().length == 1,
      'dialog field "$label" is available',
      seconds: 10);
  await t.enterText(field, value);
  await t.pump(const Duration(milliseconds: 100));
}

Future<void> _nav(WidgetTester t, String label) async {
  final destination = find.descendant(
      of: find.byType(NavigationBar), matching: find.text(label));
  await _tap(t, destination);
}

Finder _field(String label) => find.byWidgetPredicate(
    (w) => w is TextField && (w.decoration?.labelText ?? '').startsWith(label));

class _SkipCase implements Exception {
  final String reason;
  const _SkipCase(this.reason);
}

Future<void> _enter(WidgetTester t, Finder field, String value) async {
  await _reveal(t, field);
  await t.enterText(field, value);
  await t.pump();
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pump(const Duration(milliseconds: 200));
}

Future<void> _waitFilledButtonEnabled(
    WidgetTester t, Finder button, String reason) async {
  await _wait(
      t,
      () =>
          button.evaluate().length == 1 &&
          t.widget<FilledButton>(button).onPressed != null,
      reason);
}

Future<void> _boot(WidgetTester t) async {
  expect(_allow, isTrue,
      reason: 'Use the Android runner with explicit business opt-in.');
  expect(_url, 'https://bidvibe-be.onrender.com');
  expect(_prefix.startsWith('E2E_ANDROID_'), isTrue);
  await ApiClient.loadConfig();
  await t.pumpWidget(const BidVibeApp());
  await _wait(
      t,
      () =>
          find.byType(AuthLoginScreen).evaluate().isNotEmpty ||
          find.byTooltip('Đăng xuất').evaluate().isNotEmpty,
      'initial application session');
  if (find.byTooltip('Đăng xuất').evaluate().isNotEmpty) {
    await t.tap(find.byTooltip('Đăng xuất'));
    await _wait(t, () => find.byType(AuthLoginScreen).evaluate().isNotEmpty,
        'clear previous session');
  }
}

Future<void> _login(WidgetTester t, String alias) async {
  final a = _accounts[alias]!;
  expect(a.$2.isNotEmpty && a.$3.isNotEmpty, isTrue,
      reason: 'Missing configured account $alias');
  final fields = find.byType(TextFormField);
  expect(fields, findsNWidgets(2));
  await t.enterText(fields.at(0), a.$2);
  await t.enterText(fields.at(1), a.$3);
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pump(const Duration(milliseconds: 250));
  final check = find.byType(CheckboxListTile);
  final ops = !['bidder', 'seller'].contains(a.$1);
  if (t.widget<CheckboxListTile>(check).value != ops) {
    await _tap(t, check);
  }
  await _tap(t, find.widgetWithText(FilledButton, 'Đăng nhập'));
  await _wait(t, () => find.byTooltip('Đăng xuất').evaluate().isNotEmpty,
      'sign in $alias');
  expect(
      _store(t).currentUser?.email.toLowerCase() == a.$2.toLowerCase(), isTrue,
      reason: 'Authenticated identity mismatch');
  expect(_store(t).currentUser?.role, a.$1);
}

Future<Map<String, dynamic>> _host(
    String endpoint, Map<String, dynamic> data) async {
  final response = await http
      .post(Uri.parse('$_control$endpoint'),
          headers: {'Content-Type': 'application/json', 'x-control-key': _key},
          body: jsonEncode(data))
      .timeout(const Duration(seconds: 90));
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  expect(response.statusCode, 200,
      reason: 'Local control $endpoint: ${body['error'] ?? ''}');
  return body;
}

Future<void> _record(
    String id, String status, Map<String, dynamic> evidence) async {
  final event = {'id': id, 'status': status, 'evidence': evidence};
  debugPrint('ANDROID_E2E_EVENT ${jsonEncode(event)}');
  await _host('/checkpoint', event);
}

void _scenario(
    String id, String description, Future<void> Function(WidgetTester) body,
    {List<String> requires = const []}) {
  testWidgets('$id: $description', (t) async {
    final missing =
        requires.where((key) => _s[key] == null || _s[key] == false).toList();
    if (missing.isNotEmpty) {
      final reason =
          'BLOCKED: missing completed prerequisites ${missing.join(', ')}';
      markTestSkipped(reason);
      await _record(id, 'SKIP', {'reason': reason});
      return;
    }
    await _record(id, 'RUNNING', {'description': description});
    final watch = Stopwatch()..start();
    try {
      _caseId = id;
      _evidence.clear();
      await _boot(t);
      await body(t);
      final error = t.takeException();
      expect(error == null, isTrue,
          reason: 'Flutter framework exception; inspect execution log');
      await _record(id, 'PASS', {
        'description': description,
        'elapsedMs': watch.elapsedMilliseconds,
        ..._publicState(),
        ..._evidence
      });
    } on _SkipCase catch (skip) {
      markTestSkipped(skip.reason);
      await _record(id, 'SKIP', {'reason': skip.reason});
    } catch (error) {
      try {
        await _record(id, 'FAIL', {
          'description': description,
          'elapsedMs': watch.elapsedMilliseconds,
          'error': error.toString(),
          ..._publicState(),
          ..._evidence
        });
      } catch (reportError) {
        debugPrint('Android report transport error: $reportError');
      }
      rethrow;
    } finally {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 400));
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

Map<String, dynamic> _publicState() => {
      for (final key in [
        'listingId',
        'auctionId',
        'orderId',
        'adminAuctionId',
        'adminOrderId',
        'disputeId',
        'rtAuctionId',
        'rtOrderId',
        'rtDisputeId'
      ])
        if (_s[key] != null) key: _s[key],
    };

Future<void> _openAuction(WidgetTester t, String title, String id) async {
  final detail = await _api(t).request('/api/auctions/$id');
  await _nav(t, 'Khám phá');
  final filter = detail['status'] == 'ended' || detail['terminated'] == true
      ? 'Đã kết thúc / hủy'
      : 'Đang diễn ra';
  final filterControl = find.byKey(const ValueKey('auction.status-filter'));
  await _reveal(t, filterControl);
  final currentFilter =
      t.widget<DropdownButtonFormField<String>>(filterControl).initialValue;
  if (currentFilter != filter) {
    await _tap(t, filterControl);
    final option = find.text(filter);
    await _wait(t, () => option.evaluate().length == 1,
        'auction status option "$filter" is visible');
    await _tap(t, option);
  }
  final field = find.byKey(const ValueKey('auction.search'));
  await _enter(t, field, title);
  await _tap(t, find.byTooltip('Tìm kiếm'));
  final marker = find.textContaining('Mã phiên $id');
  await _wait(t, () => marker.evaluate().isNotEmpty, 'filtered auction $id');
  final card = find.ancestor(of: marker, matching: find.byType(Card));
  expect(card, findsOneWidget);
  await _tap(
      t, find.descendant(of: card, matching: find.text('Xem chi tiết phiên')));
  await _wait(
      t,
      () =>
          find.text('Phiên #$id').evaluate().isNotEmpty &&
          find.text('Thông tin sản phẩm').evaluate().isNotEmpty,
      'auction detail $id');
}

Future<void> _topup(WidgetTester t, int amount) async {
  final api = _api(t);
  final before = await api.request('/api/wallet');
  await _nav(t, 'Ví');
  final field = find.byKey(const ValueKey('wallet.topup-amount'));
  await _reveal(t, field);
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while ((field.evaluate().length != 1 ||
          !t.widget<TextFormField>(field).enabled) &&
      DateTime.now().isBefore(deadline)) {
    await t.pump(const Duration(milliseconds: 200));
  }
  if (field.evaluate().length != 1 || !t.widget<TextFormField>(field).enabled) {
    final wallet = find.byType(BidderWalletScreen);
    final available = find.byKey(const ValueKey('wallet-available'));
    final progress = find.descendant(
      of: wallet,
      matching: find.byType(LinearProgressIndicator),
    );
    final errors = find
        .descendant(of: wallet, matching: find.byType(Text))
        .evaluate()
        .map((element) => (element.widget as Text).data ?? '')
        .where((text) => text.isNotEmpty)
        .toList();
    final reload = find.text('Tải lại ví và lịch sử');
    bool hasWalletState(String state) =>
        find.byKey(ValueKey('wallet.state.$state')).evaluate().isNotEmpty;
    final reloadButton =
        find.ancestor(of: reload, matching: find.byType(TextButton));
    final reloadEnabled = reloadButton.evaluate().length == 1 &&
        t.widget<TextButton>(reloadButton).onPressed != null;
    final loading = hasWalletState('loading');
    final posting = hasWalletState('posting');
    final loadingMore = hasWalletState('loading-more');
    final uncertain = hasWalletState('uncertain');
    final missingSnapshot = hasWalletState('missing-snapshot');
    final hasError = hasWalletState('error');
    fail(
      'Wallet top-up field did not become editable; '
      'screenMatches=${wallet.evaluate().length}, '
      'fieldMatches=${field.evaluate().length}, '
      'enabled=${field.evaluate().length == 1 ? t.widget<TextFormField>(field).enabled : null}, '
      'walletLoaded=${available.evaluate().length == 1}, '
      'loading=$loading, '
      'posting=$posting, '
      'loadingMore=$loadingMore, '
      'uncertain=$uncertain, '
      'missingSnapshot=$missingSnapshot, '
      'hasError=$hasError, '
      'progressIndicators=${progress.evaluate().length}, '
      'reloadEnabled=$reloadEnabled, '
      'visibleErrors=${jsonEncode(errors)}',
    );
  }
  await _enter(t, field, '$amount');
  await _tap(t, find.widgetWithText(FilledButton, 'Nạp tiền'));
  await _tap(t, find.widgetWithText(FilledButton, 'Xác nhận'));
  await _wait(t, () => t.widget<TextFormField>(field).controller!.text.isEmpty,
      'UI top-up accepted');
  final after = await api.request('/api/wallet');
  expect(after['balance'], (before['balance'] as num) + amount);
}

Future<void> _join(WidgetTester t, String id) async {
  final button = find.widgetWithText(FilledButton, 'Đặt cọc tham gia');
  await _reveal(t, button);
  await _wait(
      t,
      () =>
          button.evaluate().isNotEmpty &&
          t.widget<FilledButton>(button).onPressed != null,
      'join enabled');
  await _confirmDialog(t, button, 'Đặt cọc tham gia phiên', 'Xác nhận đặt cọc');
  await _wait(
      t,
      () => find
          .text('Bạn đã đặt cọc tham gia phiên này. Không cần đặt cọc lại.')
          .evaluate()
          .isNotEmpty,
      'UI deposit confirmed');
  expect((await _api(t).request('/api/auctions/$id'))['joined'], true);
}

Map<String, dynamic> _bidDialogDiagnostics(
    WidgetTester t, Finder panel, String id) {
  final matches = panel.evaluate().length;
  final fields =
      find.descendant(of: panel, matching: find.byType(TextFormField));
  final texts = find
      .byType(Text)
      .evaluate()
      .map((element) {
        final widget = element.widget as Text;
        return widget.data ?? widget.textSpan?.toPlainText() ?? '';
      })
      .where((value) => value.isNotEmpty)
      .take(80)
      .toList();
  final exception = t.takeException();
  final diagnostics = <String, dynamic>{
    'panelMatches': matches,
    'loginVisible': find.byType(AuthLoginScreen).evaluate().isNotEmpty,
    'auctionDetailVisible': find.text('Phiên #$id').evaluate().isNotEmpty,
    'alertDialogs': find.byType(AlertDialog).evaluate().length,
    'visibleText': texts,
    'flutterException': exception?.toString(),
  };
  if (matches == 1) {
    final controller = t.widget<AuctionBidPanel>(panel).controller;
    diagnostics.addAll({
      'dataLoaded': controller.data != null,
      'loading': controller.loading,
      'posting': controller.posting,
      'connected': controller.connected,
      'dirty': controller.dirty,
      'leading': controller.data?['leading'],
      'paused': controller.data?['paused'],
      'uncertainBid': controller.uncertainBid,
      'notice': controller.notice,
      'error': controller.error,
    });
  }
  if (fields.evaluate().length == 1) {
    final field = t.widget<TextFormField>(fields);
    diagnostics['amountValue'] = field.controller?.text;
    diagnostics['amountEnabled'] = field.enabled;
    diagnostics['amountError'] =
        t.state<FormFieldState<String>>(fields).errorText;
  }
  return diagnostics;
}

Future<void> _bid(WidgetTester t, String id) async {
  final panel = find.byType(AuctionBidPanel);
  final minimum = find.widgetWithText(TextButton, 'Dùng giá tối thiểu');
  await _reveal(t, minimum);
  await _wait(
      t,
      () =>
          minimum.evaluate().isNotEmpty &&
          t.widget<TextButton>(minimum).onPressed != null,
      'bid enabled / realtime connected');
  await _tap(t, minimum);
  final submit = find.descendant(
      of: panel, matching: find.widgetWithText(FilledButton, 'Đặt giá'));
  await _wait(
      t,
      () =>
          panel.evaluate().length == 1 &&
          submit.evaluate().length == 1 &&
          t.widget<FilledButton>(submit).onPressed != null,
      'bid submit action is uniquely present and enabled');
  await _tap(t, submit);
  final dialog = find.byType(AlertDialog);
  final dialogTitle = find.descendant(
    of: dialog,
    matching: _text('Xác nhận đặt giá'),
  );
  final dialogDeadline = DateTime.now().add(const Duration(seconds: 10));
  while ((dialog.evaluate().length != 1 || dialogTitle.evaluate().isEmpty) &&
      DateTime.now().isBefore(dialogDeadline)) {
    await t.pump(const Duration(milliseconds: 200));
  }
  if (dialog.evaluate().length != 1 || dialogTitle.evaluate().isEmpty) {
    _evidence['bidDialogDiagnostics'] = _bidDialogDiagnostics(t, panel, id);
    fail(
        'Bid confirmation dialog did not open: ${jsonEncode(_evidence['bidDialogDiagnostics'])}');
  }
  await _tapDialogAction(t, dialog, 'Xác nhận đặt giá');
  var leading = false;
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(deadline)) {
    final controller = _panelController(t, panel);
    final diagnostics = <String, dynamic>{
      'panelMatches': panel.evaluate().length,
      'loginVisible': find.byType(AuthLoginScreen).evaluate().isNotEmpty,
      'auctionDetailVisible': find.text('Phiên #$id').evaluate().isNotEmpty,
    };
    if (controller != null) {
      leading = controller.data?['leading'] == true;
      diagnostics.addAll({
        'dataLoaded': controller.data != null,
        'loading': controller.loading,
        'posting': controller.posting,
        'connected': controller.connected,
        'dirty': controller.dirty,
        'uncertainBid': controller.uncertainBid,
        'hasNotice': controller.notice != null,
        if (controller.notice != null) 'notice': controller.notice,
      });
    }
    _evidence['bidUiDiagnostics'] = diagnostics;
    if (leading) break;
    await t.pump(const Duration(milliseconds: 200));
  }
  final rootShell = find.byType(RootShell, skipOffstage: false);
  var apiLeading = false;
  if (rootShell.evaluate().isNotEmpty) {
    final auction = await _api(t).request('/api/auctions/$id');
    apiLeading = auction['leading'] == true;
    _evidence['bidApiDiagnostics'] = {
      'leading': auction['leading'],
      'status': auction['status'],
      'bidCount': auction['bidCount'],
    };
  } else {
    _evidence['bidApiDiagnostics'] = {'available': false};
  }
  expect(leading, isTrue,
      reason:
          'UI winning bid was not confirmed; diagnostics: ${jsonEncode(_evidence['bidUiDiagnostics'])}');
  expect(apiLeading, isTrue,
      reason:
          'API did not confirm the bidder as leading; diagnostics: ${jsonEncode(_evidence['bidApiDiagnostics'])}');
}

Future<void> _end(
    WidgetTester t, ApiClient api, String title, String id) async {
  await _host('/register', {
    'auctionId': id,
    'sellerId': _s['sellerId'],
    'title': title,
    'token': api.token
  });
  await _host('/end-soon', {'auctionId': id});
  final end = DateTime.now().add(const Duration(seconds: 45));
  while (DateTime.now().isBefore(end)) {
    await _host('/close-expired', {'auctionId': id});
    if ((await api.request('/api/auctions/$id'))['status'] == 'ended') return;
    await t.pump(const Duration(seconds: 1));
  }
  fail('Fixture $id did not end');
}

Future<Map<String, dynamic>> _readUntil(WidgetTester t, ApiClient api,
    String endpoint, bool Function(Map<String, dynamic>) ready) async {
  return _poll(t, () => api.request(endpoint), ready, endpoint);
}

Future<Map<String, dynamic>> _poll(
    WidgetTester t,
    Future<Map<String, dynamic>> Function() read,
    bool Function(Map<String, dynamic>) ready,
    String description) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(deadline)) {
    final data = await read();
    if (ready(data)) return data;
    await t.pump(const Duration(milliseconds: 300));
  }
  fail('Expected committed state not observed: $description');
}

Future<void> _openOrder(WidgetTester t, String title, String id) async {
  final order = await _api(t).request('/api/orders/$id');
  expect('${order['id']}', id, reason: 'API returned the owned order');
  expect(order['title'], title, reason: 'owned order title matches fixture');
  await _nav(t, 'Hồ sơ');
  final allOrders = _text('Xem tất cả đơn hàng');
  await _reveal(t, _text('Đơn hàng của tôi'));
  final emptyOrders = _text('Bạn chưa thắng phiên nào.');
  final retryOrders = _text('Thử tải lại đơn hàng');
  await _wait(
      t,
      () =>
          allOrders.evaluate().isNotEmpty ||
          emptyOrders.evaluate().isNotEmpty ||
          retryOrders.evaluate().isNotEmpty,
      'profile order section loaded before opening owned order $id');
  expect(allOrders, findsOneWidget,
      reason: 'profile lists the owned order and all-orders navigation');
  await _reveal(t, allOrders);
  await _wait(t, () => allOrders.evaluate().length == 1,
      'profile shows all-orders navigation for owned order $id');
  await _tap(t, allOrders);
  await _wait(t, () => find.byType(OrdersScreen).evaluate().length == 1,
      'full orders route opened for owned order $id');
  await _wait(t, () => find.byType(SkeletonTileList).evaluate().isEmpty,
      'full orders list finished loading for order $id');
  final target = find.byKey(ValueKey('order-$id'));
  await _reveal(t, target);
  await _wait(t, () => target.evaluate().length == 1,
      'exact owned order tile $id on OrdersScreen');
  await _tap(t, target);
  await _wait(t, () => find.text('Đơn hàng #$id').evaluate().isNotEmpty,
      'order detail $id');
}

Future<Map<String, dynamic>> _openWarehouseOrder(
    WidgetTester t, String id, String expectedStage) async {
  final order = await OpsRepository(_api(t)).warehouseOrder(id);
  expect(order['stage'], expectedStage, reason: 'owned warehouse order stage');
  final warehouse = order['warehouse'];
  final marker = warehouse is Map &&
          warehouse['orderCode'] is String &&
          (warehouse['orderCode'] as String).isNotEmpty
      ? '${warehouse['orderCode']}'
      : 'Đơn #$id';
  final row = find.byKey(ValueKey('warehouse-order-$id'));
  await _wait(t, () => row.evaluate().length == 1, 'exact warehouse order $id');
  await _tap(t, row);
  await _wait(
      t,
      () =>
          find.text('Chi tiết đơn kho').evaluate().isNotEmpty &&
          find.text(marker).evaluate().isNotEmpty &&
          find.text('${order['title']}').evaluate().isNotEmpty,
      'warehouse detail is for order $id ($marker)');
  return order;
}

Future<Map<String, dynamic>> _cmd(String op,
    {Map<String, dynamic> data = const {}}) async {
  final result =
      await _host('/connected-command', {'op': op, 'caseId': _caseId, ...data});
  if (result['classification'] != null) {
    _evidence['setupClassification'] = result['classification'];
  }
  if (result['webScreenshot'] != null || result['completed'] == true) {
    final safe = Map<String, dynamic>.from(result)
      ..remove('account')
      ..remove('fixture');
    (_evidence['webActions'] ??= <Map<String, dynamic>>[]).add(safe);
  }
  return result;
}

void _select(String kind) {
  final f = _branches[kind]!;
  for (final k in ['listingId', 'auctionId', 'orderId', 'disputeId']) {
    _s.remove(k);
    if (f[k] != null) _s[k] = f[k];
  }
  _s['mainTitle'] = f['title'];
  _evidence['branch'] = kind;
}

Future<void> _branch(WidgetTester t, String kind) async {
  if (!_branches.containsKey(kind)) {
    final result = await _cmd('setup', data: {'kind': kind});
    final f = Map<String, dynamic>.from(result['fixture']);
    final buyer = f.remove('buyer') as Map;
    _accounts[kind] = ('bidder', '${buyer['email']}', '${buyer['password']}');
    _branches[kind] = f;
  }
  _select(kind);
  await _login(t, kind);
}

Future<ApiClient> _actor(String alias) async {
  final a = _accounts[alias]!;
  final api = ApiClient();
  try {
    final d = await api.request(
        '/api/auth/${['bidder', 'seller'].contains(a.$1) ? '' : 'ops/'}login',
        body: {'email': a.$2, 'password': a.$3});
    api.token = '${d['token']}';
    return api;
  } catch (_) {
    api.close();
    rethrow;
  }
}

Future<void> _register(WidgetTester t, String alias, String name) async {
  await _tap(t, _text('Chưa có tài khoản? Đăng ký'));
  for (final pair in [
    ('Họ và tên', name),
    ('Email', _accounts[alias]!.$2),
    ('Mật khẩu', _accounts[alias]!.$3),
    ('Nhập lại mật khẩu', _accounts[alias]!.$3)
  ]) {
    await _enter(t, _field(pair.$1), pair.$2);
  }
  await _tap(t, find.widgetWithText(FilledButton, 'Tạo tài khoản'));
  await _wait(t, () => find.byTooltip('Đăng xuất').evaluate().isNotEmpty,
      'fresh registration');
  expect(_store(t).currentUser?.email, _accounts[alias]!.$2);
}

Future<void> _logout(WidgetTester t) async {
  Navigator.of(t.element(find.byType(RootShell, skipOffstage: false)))
      .popUntil((r) => r.isFirst);
  await t.pump(const Duration(milliseconds: 350));
  if (find.byTooltip('Đăng xuất').evaluate().isNotEmpty) {
    await _tap(t, find.byTooltip('Đăng xuất'));
  }
  await _wait(t, () => find.byType(AuthLoginScreen).evaluate().isNotEmpty,
      'sign out prerequisite');
}

Future<void> _reject(ApiClient api, String path, String code,
    {Map<String, dynamic> body = const {}}) async {
  ApiException? rejected;
  try {
    await api.request(path, body: body);
  } on ApiException catch (e) {
    rejected = e;
  }
  expect(rejected, isNotNull, reason: 'Expected API rejection for $path');
  expect(rejected!.code, code);
  (_evidence['apiRejections'] ??= <Map<String, dynamic>>[]).add({
    'endpoint': path,
    'code': code,
    'classification': 'API assertion, not an Android UI mutation'
  });
}

Future<void> _chooseNewAddress(WidgetTester t) async {
  await _tap(t, find.textContaining('Chưa có địa chỉ nhận hàng'));
  await _tap(t, _text('Thêm địa chỉ mới'));
  await _wait(t, () => find.text('Thêm địa chỉ mới').evaluate().isNotEmpty,
      'new address form opened');
  for (final p in [
    ('Họ và tên người nhận', 'E2E Android Buyer'),
    ('Số điện thoại', '0900000000'),
    ('Tỉnh / thành phố', 'Ho Chi Minh'),
    ('Địa chỉ cụ thể', 'E2E test only - Connected Street')
  ]) {
    await _enter(t, _field(p.$1), p.$2);
  }
  await _tap(t, _text('Lưu địa chỉ'));
  await _wait(
      t,
      () => find
          .byTooltip('Chọn địa chỉ của E2E Android Buyer')
          .evaluate()
          .isNotEmpty,
      'address saved');
  await _tap(t, find.byTooltip('Chọn địa chỉ của E2E Android Buyer'));
  await _tap(t, _text('Dùng địa chỉ này'));
  await _wait(t, () => find.byType(OrderDetailScreen).evaluate().isNotEmpty,
      'return to exact order');
  await _readUntil(t, _api(t), '/api/orders/${_s['orderId']}',
      (o) => o['shippingAddress'] != null);
}

Future<void> _openDispute(WidgetTester t, String kind) async {
  await _branch(t, kind);
  await _openOrder(t, _s['mainTitle'] as String, _s['orderId'] as String);
  await _tap(t, _text('Hàng có vấn đề? Mở tranh chấp'));
  await _tap(t, _text('Hàng không đúng mô tả'));
  await _enter(
      t,
      find.byWidgetPredicate((w) =>
          w is TextField &&
          w.decoration?.hintText == 'Mô tả cụ thể vấn đề bạn gặp phải…'),
      'Connected E2E owned $kind dispute');
  await _tap(t, _text('Gửi tranh chấp'));
  final data = await _readUntil(
      t,
      _api(t),
      '/api/disputes/mine',
      (d) => (d['disputes'] as List)
          .any((o) => '${o['orderId']}' == _s['orderId']));
  final d = (data['disputes'] as List)
      .singleWhere((d) => '${d['orderId']}' == _s['orderId']);
  _s['disputeId'] = '${d['id']}';
  _branches[kind]!['disputeId'] = _s['disputeId'];
  final web = await _cmd('inspect-dispute',
      data: {'kind': kind, 'disputeId': _s['disputeId']});
  _branches[kind]!['escrowAmount'] = web['escrowAmount'];
}

Future<void> _notification(WidgetTester t, String type) async {
  await _nav(t, 'Thông báo');
  final screen = find.byType(BidderNotificationsScreen);
  await _wait(t, () => screen.evaluate().isNotEmpty, 'notifications mounted');
  final c = t.widget<BidderNotificationsScreen>(screen).controller;
  await _wait(t, () => !c.loading, 'notifications loaded');
  await _wait(
      t,
      () => c.items.any(
          (n) => n.type == type && '${n.data?['orderId']}' == _s['orderId']),
      'owned notification');
  final note = c.items.firstWhere(
      (n) => n.type == type && '${n.data?['orderId']}' == _s['orderId']);
  final target = find.byKey(ValueKey('notification-${note.id}'));
  await _wait(t, () => target.evaluate().length == 1,
      'unique owned notification ${note.id}');
  await _tap(t, target);
}

Future<void> _outbidExternally(WidgetTester t) async {
  final other = await _actor('COMPETITOR');
  try {
    final d = await other.request('/api/auctions/${_s['auctionId']}');
    await other.request('/api/bids',
        body: {'auctionId': _s['auctionId'], 'amount': d['minNextBid']});
  } finally {
    other.close();
  }
  final p = find.byType(AuctionBidPanel);
  await _waitPanel(t, p, (controller) => controller.data?['leading'] == false,
      'external bid reflected without refresh');
  _evidence['externalActor'] =
      'Authenticated bidder API triggers Socket.IO; Android observes and bids through UI';
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  _scenario(
      'X-S01', 'Android buyer registration is discoverable in React Admin',
      (t) async {
    await _register(t, 'BUYER', 'E2E Android Buyer');
    await _cmd('register-buyer',
        data: {'email': _accounts['BUYER']!.$2, 'token': _api(t).token});
    _s['buyerReady'] = true;
  });
  _scenario('X-S02', 'Seller submits the connected listing through Android UI',
      (t) async {
    await _login(t, 'SELLER');
    _s['sellerId'] = _store(t).currentUser!.id;
    _s['mainTitle'] = '${_prefix}_Connected';
    await _nav(t, 'Tạo mới');
    final scope = find.byType(SellerCreateScreen);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
        const Rect.fromLTWH(0, 0, 32, 32), Paint()..color = Colors.blue);
    final image = await recorder.endRecording().toImage(32, 32);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    image.dispose();
    final picker =
        find.descendant(of: scope, matching: find.byType(PhotoPicker));
    await _reveal(t, picker);
    t
        .widget<PhotoPicker>(picker)
        .onChanged([PickedImage(bytes, 'connected-e2e.png')]);
    await t.pump();
    await _enter(
        t,
        find.byWidgetPredicate((w) =>
            w is TextField &&
            w.decoration?.hintText == 'Ví dụ: Giày da thủ công, size 41'),
        _s['mainTitle'] as String);
    await _enter(
        t,
        find.byWidgetPredicate((w) =>
            w is TextField && w.decoration?.hintText == 'Nhập giá khởi điểm'),
        '10000');
    await _tap(t, _text('Gửi để thẩm định'));
    final rows = await _readUntil(
        t,
        _api(t),
        '/api/listings/mine?limit=100',
        (d) => (d['listings'] as List).any((r) =>
            r['title'] == _s['mainTitle'] &&
            r['status'] == 'pending_appraisal'));
    final row = (rows['listings'] as List)
        .singleWhere((r) => r['title'] == _s['mainTitle']);
    _s['listingId'] = '${row['id']}';
  }, requires: ['buyerReady']);

  _scenario(
      'X-S03', 'Appraiser approves the connected listing through Android UI',
      (t) async {
    await _login(t, 'APPRAISER');
    await _tap(t, _text(_s['mainTitle'] as String));
    await _tap(t, _text('Duyệt và mở phiên'));
    await _tap(t, find.widgetWithText(FilledButton, 'Duyệt'));
    await _wait(t, () => find.text('Hàng chờ').evaluate().isNotEmpty,
        'appraiser returns to queue');
    final rows = await _api(t).request(
        '/api/auctions?status=live&q=${Uri.encodeQueryComponent(_s['mainTitle'] as String)}');
    final list = rows['auctions'] as List;
    expect(list.length, 1);
    _s['auctionId'] = '${list.single['id']}';
    _branches['main'] = {
      'title': _s['mainTitle'],
      'listingId': _s['listingId'],
      'auctionId': _s['auctionId']
    };
  }, requires: ['listingId']);

  _scenario('X-S04', 'Two isolated Android bidders fund, deposit and compete',
      (t) async {
    _select('main');
    await _login(t, 'BUYER');
    await _topup(t, 500000);
    await _openAuction(t, _s['mainTitle'] as String, _s['auctionId'] as String);
    await _join(t, _s['auctionId'] as String);
    await _bid(t, _s['auctionId'] as String);
    final a = await _api(t).request('/api/auctions/${_s['auctionId']}');
    _s['deposit'] = a['depositRequired'];
    await _logout(t);
    await _register(t, 'COMPETITOR', 'E2E Android Competitor');
    await _topup(t, 500000);
    await _openAuction(t, _s['mainTitle'] as String, _s['auctionId'] as String);
    await _join(t, _s['auctionId'] as String);
    await _bid(t, _s['auctionId'] as String);
    expect(
        (await _api(t).request('/api/wallet'))['held'], a['depositRequired']);
    _s['competed'] = true;
  }, requires: ['auctionId', 'buyerReady']);
  _scenario('X-S05', 'Android receives an external bid live and outbids it',
      (t) async {
    _select('main');
    await _login(t, 'BUYER');
    await _openAuction(t, _s['mainTitle'] as String, _s['auctionId'] as String);
    await _bid(t, _s['auctionId'] as String);
    await _outbidExternally(t);
    await _bid(t, _s['auctionId'] as String);
    _s['bidReady'] = true;
  }, requires: ['competed']);
  _scenario('X-M01',
      'Android report creates the flag subsequently handled on React Web',
      (t) async {
    await _login(t, 'BUYER');
    await _openAuction(t, _s['mainTitle'] as String, _s['auctionId'] as String);
    await _tap(t, find.byTooltip('Báo cáo phiên'));
    await _enter(
        t, _field('Lý do báo cáo'), 'Connected Android to React Admin E2E');
    await _tap(t, _text('Gửi báo cáo'));
    final dialog = await _waitForDialog(t, 'Xác nhận gửi báo cáo');
    await _tapDialogAction(t, dialog, 'Xác nhận gửi');
    await _wait(
        t,
        () => find
            .textContaining('Báo cáo đã được ghi nhận')
            .evaluate()
            .isNotEmpty,
        'mobile report committed');
    await _host('/register', {
      'auctionId': _s['auctionId'],
      'sellerId': _s['sellerId'],
      'title': _s['mainTitle'],
      'token': _api(t).token
    });
    await _cmd('main-flag-read',
        data: {'auctionId': _s['auctionId'], 'title': _s['mainTitle']});
    _s['reported'] = true;
  }, requires: ['bidReady']);

  _scenario('X-M02', 'React pause reaches the signed-in Android auction live',
      (t) async {
    _select('main');
    await _login(t, 'BUYER');
    await _openAuction(t, _s['mainTitle'] as String, _s['auctionId'] as String);
    final p = find.byType(AuctionBidPanel);
    await _reveal(t, p);
    await _waitPanel(
        t, p, (controller) => controller.connected, 'auction socket connected');
    await _cmd('main-flag', data: {
      'action': 'pause',
      'auctionId': _s['auctionId'],
      'title': _s['mainTitle']
    });
    await _waitPanel(
        t, p, (controller) => controller.data?['paused'] == true, 'live pause');
    await _reveal(t, find.widgetWithText(Chip, 'Tạm dừng'));
    _s['pausedVerified'] = true;
  }, requires: ['reported']);
  _scenario('X-M03', 'Paused auction blocks UI bidding and rejects API bidding',
      (t) async {
    _select('main');
    await _login(t, 'BUYER');
    await _openAuction(t, _s['mainTitle'] as String, _s['auctionId'] as String);
    final p = find.byType(AuctionBidPanel);
    await _reveal(t, p);
    await _waitPanel(t, p, (controller) => controller.data?['paused'] == true,
        'paused detail');
    final b = find.descendant(
        of: p, matching: find.widgetWithText(FilledButton, 'Đặt giá'));
    await _wait(t, () => b.evaluate().length == 1,
        'paused bid button is uniquely present');
    expect(t.widget<FilledButton>(b).onPressed, isNull);
    final before = await _api(t).request('/api/auctions/${_s['auctionId']}');
    await _reject(_api(t), '/api/bids', 'AUCTION_PAUSED',
        body: {'auctionId': _s['auctionId'], 'amount': before['minNextBid']});
    expect(
        (await _api(t).request('/api/auctions/${_s['auctionId']}'))['bidCount'],
        before['bidCount']);
  }, requires: ['pausedVerified']);
  _scenario('X-M04', 'React verification follows the backend resume policy',
      (t) async {
    _select('main');
    await _login(t, 'BUYER');
    await _openAuction(t, _s['mainTitle'] as String, _s['auctionId'] as String);
    final p = find.byType(AuctionBidPanel);
    await _reveal(t, p);
    await _waitPanel(
        t, p, (controller) => controller.connected, 'socket connected');
    await _cmd('main-flag', data: {
      'action': 'verify',
      'auctionId': _s['auctionId'],
      'title': _s['mainTitle']
    });
    await _waitPanel(t, p, (controller) => controller.data?['paused'] == false,
        'verification removes paused flag under current BE policy');
    _s['verification'] = true;
  }, requires: ['pausedVerified']);
  _scenario('X-M05', 'React safe decision permits a valid Android bid',
      (t) async {
    _select('main');
    await _login(t, 'BUYER');
    await _openAuction(t, _s['mainTitle'] as String, _s['auctionId'] as String);
    final p = find.byType(AuctionBidPanel);
    await _reveal(t, p);
    await _waitPanel(
        t, p, (controller) => controller.connected, 'socket connected');
    await _cmd('main-flag', data: {
      'action': 'safe',
      'auctionId': _s['auctionId'],
      'title': _s['mainTitle']
    });
    await _outbidExternally(t);
    await _bid(t, _s['auctionId'] as String);
    _s['resumedVerified'] = true;
  }, requires: ['verification']);
  _scenario('X-M08',
      'React rejects termination without a reason before sending a mutation',
      (t) async {
    await _branch(t, 'terminate');
    await _openAuction(t, _s['mainTitle'] as String, _s['auctionId'] as String);
    await _cmd('term-invalid', data: {'kind': 'terminate'});
    expect(
        (await _api(t)
            .request('/api/auctions/${_s['auctionId']}'))['terminated'],
        false);
    _s['termReady'] = true;
  });
  _scenario('X-M06',
      'React terminates an isolated auction and Android receives the cancellation and deposit refund',
      (t) async {
    await _branch(t, 'terminate');
    await _openAuction(t, _s['mainTitle'] as String, _s['auctionId'] as String);
    final p = find.byType(AuctionBidPanel);
    await _reveal(t, p);
    await _waitPanel(t, p, (controller) => controller.connected,
        'termination socket connected');
    final before = await _api(t).request('/api/wallet');
    final auction = await _api(t).request('/api/auctions/${_s['auctionId']}');
    await _cmd('terminate', data: {'kind': 'terminate'});
    await _waitPanel(
        t,
        p,
        (controller) => controller.data?['terminated'] == true,
        'cancelled event');
    final after = await _api(t).request('/api/wallet');
    expect(after['balance'],
        (before['balance'] as num) + (auction['depositRequired'] as num));
    expect(after['held'], 0);
    _s['terminated'] = true;
  }, requires: ['termReady']);
  _scenario('X-M07', 'Terminated state persists with no winner order',
      (t) async {
    await _branch(t, 'terminate');
    await _openAuction(t, _s['mainTitle'] as String, _s['auctionId'] as String);
    final d = await _api(t).request('/api/auctions/${_s['auctionId']}');
    expect(d['terminated'], true);
    expect(d['winnerId'], isNull);
    final orders = await _api(t).request('/api/orders/mine');
    expect(
        (orders['orders'] as List)
            .where((o) => '${o['auctionId']}' == _s['auctionId']),
        isEmpty);
    final p = find.byType(AuctionBidPanel);
    await _reveal(t, p);
    expect(
        (await _waitPanel(
                t,
                p,
                (controller) => controller.data?['terminated'] == true,
                'terminated panel loaded'))
            .canBid,
        false);
  }, requires: ['terminated']);
  _scenario('X-S06',
      'Controlled fixture expiry creates the exact winner order on Android',
      (t) async {
    _select('main');
    await _login(t, 'BUYER');
    await _openAuction(t, _s['mainTitle'] as String, _s['auctionId'] as String);
    await _end(
        t, _api(t), _s['mainTitle'] as String, _s['auctionId'] as String);
    final auction = await _api(t).request('/api/auctions/${_s['auctionId']}');
    final winnerId = _store(t).currentUser!.id;
    expect(auction['status'], 'ended',
        reason: 'backend closed the connected auction');
    expect('${auction['winnerId']}', winnerId,
        reason: 'backend winner matches the signed-in bidder');
    expect(auction['won'], true,
        reason: 'backend confirms the signed-in bidder won');
    final rows = await _api(t).request('/api/orders/mine');
    final order = (rows['orders'] as List)
        .singleWhere((o) => '${o['auctionId']}' == _s['auctionId']);
    _s['orderId'] = '${order['id']}';
    _branches['main']!['orderId'] = _s['orderId'];
    await _tap(t, find.byTooltip('Làm mới phiên'));
    final ended = find.text('Đã kết thúc');
    await _wait(t, () => ended.evaluate().length == 1,
        'auction detail refreshed to ended state');
    final winner = find.text('Bạn đã thắng phiên này');
    await _reveal(t, winner);
    await _wait(t, () => winner.evaluate().length == 1,
        'ended auction UI shows the signed-in winner');
    final loser = await _actor('COMPETITOR');
    try {
      final wallet = await loser.request('/api/wallet');
      expect(wallet['held'], 0);
      expect(wallet['balance'], 500000);
    } finally {
      loser.close();
    }
    _s['winnerReady'] = true;
  }, requires: ['resumedVerified']);

  _scenario('X-S07',
      'Android buyer creates an address and pays the connected order from the wallet',
      (t) async {
    _select('main');
    await _login(t, 'BUYER');
    await _openOrder(t, _s['mainTitle'] as String, _s['orderId'] as String);
    await _tap(t, find.textContaining('Chưa có địa chỉ nhận hàng'));
    await _tap(t, _text('Thêm địa chỉ mới'));
    await _wait(t, () => find.text('Thêm địa chỉ mới').evaluate().isNotEmpty,
        'new address form opened');
    for (final value in [
      ('Họ và tên người nhận', 'E2E Android Buyer'),
      ('Số điện thoại', '0900000000'),
      ('Tỉnh / thành phố', 'Ho Chi Minh'),
      ('Địa chỉ cụ thể', 'E2E test only - 1 Connected Street')
    ]) {
      await _enter(t, _field(value.$1), value.$2);
    }
    await _tap(t, _text('Lưu địa chỉ'));
    await _wait(
        t,
        () => find
            .byTooltip('Chọn địa chỉ của E2E Android Buyer')
            .evaluate()
            .isNotEmpty,
        'address saved');
    await _tap(t, find.byTooltip('Chọn địa chỉ của E2E Android Buyer'));
    await _tap(t, _text('Dùng địa chỉ này'));
    await _wait(t, () => find.byType(OrderDetailScreen).evaluate().isNotEmpty,
        'return to order');
    await _readUntil(t, _api(t), '/api/orders/${_s['orderId']}',
        (o) => o['shippingAddress'] != null);
    final walletTile = find.ancestor(
        of: find.text('Ví BidVibe'), matching: find.byType(InkWell));
    await _reveal(t, walletTile);
    await _wait(
        t,
        () =>
            walletTile.evaluate().length == 1 &&
            t.widget<InkWell>(walletTile).onTap != null,
        'wallet enabled');
    await _tap(t, walletTile);
    await _wait(
        t,
        () =>
            find
                .descendant(
                    of: walletTile,
                    matching: find.byIcon(Icons.radio_button_checked))
                .evaluate()
                .length ==
            1,
        'wallet method selected');
    final before = await _api(t).request('/api/wallet');
    final order = await _api(t).request('/api/orders/${_s['orderId']}');
    final pay = find.byWidgetPredicate(
        (w) => w is BigActionButton && w.label.startsWith('Thanh toán '));
    await _wait(
        t,
        () =>
            pay.evaluate().length == 1 &&
            t.widget<BigActionButton>(pay).onPressed != null,
        'wallet payment action enabled');
    await _confirmDialog(t, pay, 'Xác nhận thanh toán', 'Thanh toán');
    await _wait(
        t,
        () =>
            find.textContaining('Thanh toán thành công').evaluate().isNotEmpty,
        'UI payment success');
    expect(
        (await _api(t)
            .request('/api/orders/${_s['orderId']}'))['paymentStatus'],
        'paid');
    expect((await _api(t).request('/api/wallet'))['balance'],
        (before['balance'] as num) - (order['amountToPay'] as num));
    _s['paid'] = true;
  }, requires: ['winnerReady']);

  _scenario('X-S08', 'Seller sends only the test order to warehouse through UI',
      (t) async {
    _select('main');
    await _login(t, 'SELLER');
    await _nav(t, 'Gửi kho');
    final card = find.byKey(ValueKey('shipment-${_s['listingId']}'));
    await _wait(t, () => card.evaluate().length == 1,
        'shipment card for owned listing ${_s['listingId']}');
    final action = find.descendant(
        of: card, matching: find.text('Tôi đã gửi hàng đến kho'));
    await _wait(t, () => action.evaluate().length == 1,
        'owned shipment action visible');
    await _tap(t, action);
    await _readUntil(
        t,
        _api(t),
        '/api/orders/selling?limit=100',
        (data) => (data['orders'] as List).any((o) =>
            '${o['id']}' == _s['orderId'] &&
            o['stage'] == 'in_transit_to_warehouse'));
    _s['shipped'] = true;
  }, requires: ['paid']);

  final warehouseSteps = [
    ('receive', 'Xác nhận kho đã nhận hàng', 'inspecting'),
    ('inspect', 'Lưu kết quả kiểm định', 'inspected'),
    ('pack', 'Xác nhận đóng gói', 'packed'),
    ('ship', 'Gửi cho đơn vị vận chuyển', 'shipped'),
    ('deliver', 'Xác nhận đã giao', 'delivered')
  ];
  for (var i = 0; i < warehouseSteps.length; i++) {
    final step = warehouseSteps[i];
    final previous = i == 0 ? 'shipped' : 'wh-${warehouseSteps[i - 1].$1}';
    _scenario('X-S${(i + 9).toString().padLeft(2, '0')}',
        'Warehouse ${step.$1} through UI', (t) async {
      const previousStages = {
        'receive': 'in_transit_to_warehouse',
        'inspect': 'inspecting',
        'pack': 'inspected',
        'ship': 'packed',
        'deliver': 'shipped'
      };
      _select('main');
      await _login(t, 'WAREHOUSE');
      await _openWarehouseOrder(
          t, _s['orderId'] as String, previousStages[step.$1]!);
      if (step.$1 == 'inspect') {
        final match = find.widgetWithText(RadioListTile<String>, 'Khớp mô tả');
        await _wait(t, () => match.evaluate().length == 1,
            'matching inspection choice visible');
        await _tap(t, match);
      }
      final action = find.widgetWithText(FilledButton, step.$2);
      await _waitFilledButtonEnabled(
          t, action, 'warehouse ${step.$1} action enabled');
      if (step.$1 == 'ship') {
        final dialog =
            await _openDialog(t, action, 'Xác nhận bàn giao vận chuyển');
        await _enterDialogField(
            t, dialog, 'Đơn vị vận chuyển', 'E2E simulated carrier');
        await _enterDialogField(
            t, dialog, 'Mã vận đơn', 'ANDROID-${_s['orderId']}');
        final confirm = find.descendant(
            of: dialog,
            matching: find.widgetWithText(FilledButton, 'Xác nhận gửi'));
        await _wait(
            t,
            () =>
                confirm.evaluate().length == 1 &&
                t.widget<FilledButton>(confirm).onPressed != null,
            'shipment confirmation enabled after carrier and tracking are entered');
        await _tapDialogAction(t, dialog, 'Xác nhận gửi');
      } else {
        await _tap(t, action);
      }
      final order = await _poll(
          t,
          () => OpsRepository(_api(t)).warehouseOrder(_s['orderId'] as String),
          (o) => o['stage'] == step.$3,
          'warehouse stage ${step.$3}');
      expect(order['stage'], step.$3);
      expect(find.text('Không cập nhật được đơn hàng.'), findsNothing);
      _s['wh-${step.$1}'] = true;
    }, requires: [previous]);
  }

  _scenario('X-S14', 'Android shipping notification opens the exact order',
      (t) async {
    _select('main');
    await _login(t, 'BUYER');
    await _notification(t, 'order');
    await _wait(
        t,
        () => find.text('Đơn hàng #${_s['orderId']}').evaluate().isNotEmpty,
        'shipping notification target');
  }, requires: ['wh-deliver']);
  _scenario('X-S15', 'Buyer confirms delivery; verify payout released',
      (t) async {
    _select('main');
    await _login(t, 'BUYER');
    await _openOrder(t, _s['mainTitle'] as String, _s['orderId'] as String);
    final receive = find.widgetWithText(BigActionButton, 'Đã nhận hàng');
    await _wait(
        t,
        () =>
            receive.evaluate().length == 1 &&
            t.widget<BigActionButton>(receive).onPressed != null,
        'delivery confirmation action enabled');
    await _confirmDialog(t, receive, 'Xác nhận đã nhận hàng', 'Đã nhận hàng');
    await _readUntil(t, _api(t), '/api/orders/${_s['orderId']}',
        (o) => o['payoutStatus'] == 'released');
    await _cmd('overview');
    _s['completed'] = true;
  }, requires: ['wh-deliver']);

  _scenario('X-R01', 'Android opens a refund dispute visible in React Admin',
      (t) async {
    await _openDispute(t, 'refund');
    _s['refundDispute'] = true;
  });
  _scenario('X-R02', 'React resolves the exact Android dispute as refund',
      (t) async {
    await _branch(t, 'refund');
    await _nav(t, 'Thông báo');
    final screen = find.byType(BidderNotificationsScreen);
    await _wait(t, () => screen.evaluate().isNotEmpty, 'notification screen');
    final c = t.widget<BidderNotificationsScreen>(screen).controller;
    await _wait(t, () => c.connected, 'notification socket');
    final sub = c.events!.stream.listen((e) {
      if (e.type == 'notification:new') _refundEvents.add(e.data);
    });
    try {
      final before = await _api(t).request('/api/wallet');
      _branches['refund']!['beforeBalance'] = before['balance'];
      await _cmd('resolve', data: {
        'kind': 'refund',
        'disputeId': _s['disputeId'],
        'resolution': 'refund'
      });
      await _wait(
          t,
          () => _refundEvents.any((n) =>
              n['type'] == 'refund' &&
              '${n['data']?['disputeId']}' == _s['disputeId']),
          'same logged-in Android receives matching event without refresh');
      await _wait(
          t,
          () => c.items.any((n) =>
              n.type == 'refund' &&
              '${n.data?['disputeId']}' == _s['disputeId']),
          'live notification rendered');
      _s['refundResolved'] = true;
    } finally {
      await sub.cancel();
    }
  }, requires: ['refundDispute']);
  _scenario('X-R03',
      'Logged-in Android receives the matching live refund notification',
      (t) async {
    // The listener and no-refresh observation run during X-R02. This checkpoint
    // asserts the captured event; it does not claim a new event after remount.
    expect(
        _refundEvents.where((n) =>
            n['type'] == 'refund' &&
            '${n['data']?['disputeId']}' == _branches['refund']!['disputeId']),
        isNotEmpty);
    _evidence['liveObservationCase'] = 'X-R02';
    _evidence['disputeId'] = _branches['refund']!['disputeId'];
  }, requires: ['refundResolved']);
  _scenario('X-R04', 'Refund credits the exact escrow amount once', (t) async {
    await _branch(t, 'refund');
    final f = _branches['refund']!;
    final w = await _api(t).request('/api/wallet');
    expect(
        w['balance'], (f['beforeBalance'] as num) + (f['escrowAmount'] as num));
    f['afterBalance'] = w['balance'];
    final tx = await _api(t).request('/api/wallet/transactions?limit=100');
    final refunds = (tx['transactions'] as List)
        .where((x) =>
            x['kind'] == 'refund' &&
            '${x['relatedAuctionId'] ?? x['auctionId']}' == _s['auctionId'])
        .toList();
    expect(refunds, hasLength(1));
    expect(refunds.single['amount'], f['escrowAmount']);
    _s['refundChecked'] = true;
  }, requires: ['refundResolved']);
  _scenario('X-R05',
      'Refund state and notification persist after remount without a second credit',
      (t) async {
    await _branch(t, 'refund');
    await _nav(t, 'Thông báo');
    final c = t
        .widget<BidderNotificationsScreen>(
            find.byType(BidderNotificationsScreen))
        .controller;
    await _wait(t, () => !c.loading, 'persisted notifications');
    expect(
        c.items.any((n) =>
            n.type == 'refund' && '${n.data?['disputeId']}' == _s['disputeId']),
        true);
    expect((await _api(t).request('/api/wallet'))['balance'],
        _branches['refund']!['afterBalance']);
    final d = await _api(t).request('/api/disputes/mine');
    expect(
        (d['disputes'] as List)
            .singleWhere((x) => '${x['id']}' == _s['disputeId'])['resolution'],
        'refund');
  }, requires: ['refundChecked']);
  _scenario('X-R06', 'Android refund notification opens the correct dispute',
      (t) async {
    await _branch(t, 'refund');
    await _notification(t, 'refund');
    await _wait(t, () => find.byType(DisputeDetailScreen).evaluate().isNotEmpty,
        'refund opens dispute');
    expect(
        t
            .widget<DisputeDetailScreen>(find.byType(DisputeDetailScreen))
            .disputeId,
        _s['disputeId']);
  }, requires: ['refundResolved']);
  _scenario(
      'X-R07', 'API rejects a second resolution with no extra wallet credit',
      (t) async {
    await _branch(t, 'refund');
    await _cmd('repeat-resolve', data: {'kind': 'refund'});
    expect((await _api(t).request('/api/wallet'))['balance'],
        _branches['refund']!['afterBalance']);
  }, requires: ['refundChecked']);
  _scenario('X-K01',
      'Android opens an independent keep-decision dispute visible on React',
      (t) async {
    await _openDispute(t, 'keep');
    _s['keepDispute'] = true;
  });
  _scenario(
      'X-K02', 'React keep decision resolves the dispute and releases payout',
      (t) async {
    await _branch(t, 'keep');
    _branches['keep']!['beforeBalance'] =
        (await _api(t).request('/api/wallet'))['balance'];
    await _cmd('resolve', data: {
      'kind': 'keep',
      'disputeId': _s['disputeId'],
      'resolution': 'keep'
    });
    expect(
        (await _api(t).request('/api/orders/${_s['orderId']}'))['payoutStatus'],
        'released');
    _s['kept'] = true;
  }, requires: ['keepDispute']);
  _scenario('X-K03', 'Android reads the keep resolution without a buyer refund',
      (t) async {
    await _branch(t, 'keep');
    await _openOrder(t, _s['mainTitle'] as String, _s['orderId'] as String);
    final d = await _api(t).request('/api/disputes/mine');
    expect(
        (d['disputes'] as List)
            .singleWhere((x) => '${x['id']}' == _s['disputeId'])['resolution'],
        'keep');
    expect((await _api(t).request('/api/wallet'))['balance'],
        _branches['keep']!['beforeBalance']);
  }, requires: ['kept']);
  _scenario(
      'X-K04', 'Repeated resolution cannot duplicate the keep financial effect',
      (t) async {
    await _branch(t, 'keep');
    await _cmd('repeat-resolve', data: {'kind': 'keep'});
    expect(
        (await _api(t).request('/api/orders/${_s['orderId']}'))['payoutStatus'],
        'released');
    expect((await _api(t).request('/api/wallet'))['balance'],
        _branches['keep']!['beforeBalance']);
  }, requires: ['kept']);
  _scenario('X-U01', 'React searches the exact buyer registered on Android',
      (t) async {
    await _login(t, 'BUYER');
    final d = await _cmd('search-buyer');
    expect(d['accountId'], _store(t).currentUser!.id);
  }, requires: ['buyerReady']);
  _scenario('X-U02',
      'React suspends the owned buyer; Android handles the protected-request rejection',
      (t) async {
    await _login(t, 'BUYER');
    await _nav(t, 'Thông báo');
    final screen = find.byType(BidderNotificationsScreen);
    await _wait(
        t, () => screen.evaluate().isNotEmpty, 'notification screen ready');
    final c = t.widget<BidderNotificationsScreen>(screen).controller;
    await _wait(
        t, () => c.connected, 'active account socket before suspension');
    final snapshot = ApiClient()..token = _api(t).token;
    try {
      await _cmd('suspend-buyer');
      await _rejectGet(snapshot, '/api/wallet', 'ACCOUNT_SUSPENDED');
    } finally {
      snapshot.close();
    }
    await _wait(t, () => find.byType(AuthLoginScreen).evaluate().isNotEmpty,
        'Android handles suspended session without a stale navigation tap');
    _s['buyerSuspended'] = true;
  }, requires: ['buyerReady']);
  _scenario('X-U03',
      'React reactivates the owned buyer; Android can resume after signing in',
      (t) async {
    await _cmd('activate-buyer');
    await _login(t, 'BUYER');
    expect((await _api(t).request('/api/wallet'))['balance'], isA<num>());
  }, requires: ['buyerSuspended']);
  _scenario(
      'X-U04', 'React creates a fresh Appraiser usable in the Android queue',
      (t) async {
    final r = await _cmd('create-ops');
    final a = r['account'] as Map;
    _accounts['NEWOPS'] = ('appraiser', '${a['email']}', '${a['password']}');
    await _login(t, 'NEWOPS');
    await _wait(
        t, () => find.text('Hàng chờ').evaluate().isNotEmpty, 'new ops queue');
    _s['opsReady'] = true;
  });
  _scenario('X-U05',
      'React edits and suspends the created ops account; Android sees suspended authorization',
      (t) async {
    await _login(t, 'NEWOPS');
    final api = _api(t);
    await _cmd('suspend-ops');
    await _rejectGet(api, '/api/appraisals/queue', 'ACCOUNT_SUSPENDED');
    _evidence['classification'] =
        'Web ops edit/suspend UI plus protected API assertion from the active Android session';
  }, requires: ['opsReady']);
  _scenario('X-N01',
      'Insufficient deposit funds prevent Android joining without holding money',
      (t) async {
    await _branch(t, 'poor');
    await _openAuction(t, _s['mainTitle'] as String, _s['auctionId'] as String);
    await _reveal(
        t, _text('Ví chưa đủ tiền cọc. Hãy nạp ví rồi tải lại phiên.'));
    expect(find.widgetWithText(FilledButton, 'Đặt cọc tham gia'), findsNothing);
    final before = await _api(t).request('/api/wallet');
    await _reject(
        _api(t), '/api/auctions/${_s['auctionId']}/join', 'INSUFFICIENT_FUNDS');
    expect((await _api(t).request('/api/wallet'))['held'], before['held']);
    _s['poorReady'] = true;
  });
  _scenario(
      'X-N02', 'Android rejects a below-minimum bid without inserting a bid',
      (t) async {
    await _branch(t, 'poor');
    await _topup(t, 100000);
    await _openAuction(t, _s['mainTitle'] as String, _s['auctionId'] as String);
    await _join(t, _s['auctionId'] as String);
    final before = await _api(t).request('/api/auctions/${_s['auctionId']}');
    await _enter(t, _field('Giá muốn đặt'), '1');
    await _tap(
        t,
        find.descendant(
            of: find.byType(AuctionBidPanel),
            matching: find.widgetWithText(FilledButton, 'Đặt giá')));
    await _reveal(t, find.textContaining('Tối thiểu'));
    expect(
        (await _api(t).request('/api/auctions/${_s['auctionId']}'))['bidCount'],
        before['bidCount']);
    _s['lowBidChecked'] = true;
  }, requires: ['poorReady']);
  _scenario(
      'X-N03', 'The leading bidder cannot self-outbid through Android or API',
      (t) async {
    await _branch(t, 'poor');
    await _openAuction(t, _s['mainTitle'] as String, _s['auctionId'] as String);
    await _bid(t, _s['auctionId'] as String);
    final d = await _api(t).request('/api/auctions/${_s['auctionId']}');
    final b = find.descendant(
        of: find.byType(AuctionBidPanel),
        matching: find.widgetWithText(FilledButton, 'Đặt giá'));
    expect(t.widget<FilledButton>(b).onPressed, isNull);
    await _reject(_api(t), '/api/bids', 'ALREADY_LEADING',
        body: {'auctionId': _s['auctionId'], 'amount': d['minNextBid']});
    expect(
        (await _api(t).request('/api/auctions/${_s['auctionId']}'))['bidCount'],
        d['bidCount']);
  }, requires: ['lowBidChecked']);
  _scenario(
      'X-N04', 'Android prevents paying an order without a shipping address',
      (t) async {
    await _branch(t, 'payment');
    await _openOrder(t, _s['mainTitle'] as String, _s['orderId'] as String);
    final before = await _api(t).request('/api/wallet');
    await _tap(
        t,
        find.byWidgetPredicate(
            (w) => w is BigActionButton && w.label.startsWith('Thanh toán ')));
    await _wait(
        t,
        () => find
            .text('Hãy chọn địa chỉ nhận hàng trước khi thanh toán.')
            .evaluate()
            .isNotEmpty,
        'address UI prevention');
    expect(
        (await _api(t)
            .request('/api/orders/${_s['orderId']}'))['paymentStatus'],
        'awaiting_payment');
    expect(
        (await _api(t).request('/api/wallet'))['balance'], before['balance']);
    _s['paymentReady'] = true;
  });
  _scenario('X-N05',
      'Insufficient wallet funds disable wallet payment and reject API payment',
      (t) async {
    await _branch(t, 'payment');
    await _openOrder(t, _s['mainTitle'] as String, _s['orderId'] as String);
    await _chooseNewAddress(t);
    final tile =
        find.ancestor(of: _text('Ví BidVibe'), matching: find.byType(InkWell));
    await _reveal(t, tile);
    expect(t.widget<InkWell>(tile).onTap, isNull);
    final before = await _api(t).request('/api/wallet');
    await _reject(
        _api(t), '/api/orders/${_s['orderId']}/pay', 'INSUFFICIENT_FUNDS',
        body: {'method': 'wallet'});
    expect(
        (await _api(t).request('/api/wallet'))['balance'], before['balance']);
    expect(
        (await _api(t)
            .request('/api/orders/${_s['orderId']}'))['paymentStatus'],
        'awaiting_payment');
  }, requires: ['paymentReady']);
  _scenario('X-N06',
      'Only the owned unpaid order expires under the normal Render scheduler',
      (t) async {
    await _branch(t, 'payment');
    await _cmd('expire-payment', data: {'kind': 'payment'});
    final d = await _readUntil(t, _api(t), '/api/orders/${_s['orderId']}',
        (o) => o['paymentStatus'] == 'expired');
    expect(d['paymentStatus'], 'expired');
    expect(
        (await _api(t)
            .request('/api/auctions/${_s['auctionId']}'))['myDepositStatus'],
        'forfeited');
    await _openOrder(t, _s['mainTitle'] as String, _s['orderId'] as String);
    await _reveal(t, find.text('Đã quá hạn thanh toán — giao dịch bị huỷ.'));
    _s['expiredReady'] = true;
  }, requires: ['paymentReady']);
  _scenario('X-N07',
      'A dedicated restricted bidder sees JOIN_BLOCKED; React identifies that exact account',
      (t) async {
    final r = await _cmd('setup-restricted');
    final a = r['account'] as Map;
    _accounts['RESTRICTED'] = ('bidder', '${a['email']}', '${a['password']}');
    _evidence['negativeSetup'] = r['evidence'];
    await _login(t, 'RESTRICTED');
    _select('poor');
    await _openAuction(t, _s['mainTitle'] as String, _s['auctionId'] as String);
    await _topupFromDetail(t);
    await _reject(
        _api(t), '/api/auctions/${_s['auctionId']}/join', 'JOIN_BLOCKED');
    await _cmd('search-restricted');
  });
  _scenario('X-N08',
      'Expired-order payment and ended-auction bids cannot create a financial effect',
      (t) async {
    await _branch(t, 'payment');
    final before = await _api(t).request('/api/wallet');
    await _reject(
        _api(t), '/api/orders/${_s['orderId']}/pay', 'PAYMENT_EXPIRED',
        body: {'method': 'wallet'});
    await _reject(_api(t), '/api/bids', 'AUCTION_ENDED',
        body: {'auctionId': _s['auctionId'], 'amount': 20000});
    expect(
        (await _api(t).request('/api/wallet'))['balance'], before['balance']);
    expect(
        (await _api(t)
            .request('/api/orders/${_s['orderId']}'))['paymentStatus'],
        'expired');
  }, requires: ['expiredReady']);
}

Future<void> _rejectGet(ApiClient api, String endpoint, String code) async {
  ApiException? rejected;
  try {
    await api.request(endpoint);
  } on ApiException catch (e) {
    rejected = e;
  }
  expect(rejected?.code, code);
  _evidence['protectedRequest'] = {'endpoint': endpoint, 'code': code};
}

Future<void> _topupFromDetail(WidgetTester t) async {
  // The restricted fixture is already funded. Exercise the real Join UI and
  // assert its business error rather than navigating to a new wallet route.
  final button = find.widgetWithText(FilledButton, 'Đặt cọc tham gia');
  await _tap(t, button);
  await _tap(t, find.widgetWithText(FilledButton, 'Xác nhận đặt cọc'));
  await _wait(
      t,
      () => find
          .textContaining('tạm thời không được tham gia phiên mới')
          .evaluate()
          .isNotEmpty,
      'JOIN_BLOCKED reason rendered');
}
