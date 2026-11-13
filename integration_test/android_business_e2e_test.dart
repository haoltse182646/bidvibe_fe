import 'dart:convert';
import 'dart:ui' as ui;

import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/core/picked_image.dart';
import 'package:bidvibe/core/remote_app_store.dart';
import 'package:bidvibe/features/ops/ops_repository.dart';
import 'package:bidvibe/main.dart';
import 'package:bidvibe/screens/warehouse/warehouse_ops_screen.dart';
import 'package:bidvibe/screens/auth/auth_login.dart';
import 'package:bidvibe/screens/admin/admin_ops_cases.dart';
import 'package:bidvibe/screens/bidder/auction_bid_panel.dart';
import 'package:bidvibe/screens/bidder/bidder_home.dart';
import 'package:bidvibe/screens/bidder/bidder_notifications.dart';
import 'package:bidvibe/screens/bidder/bidder_wallet.dart';
import 'package:bidvibe/screens/orders/order_detail_screen.dart';
import 'package:bidvibe/screens/addresses/address_book_screen.dart';
import 'package:bidvibe/screens/seller/seller_create.dart';
import 'package:bidvibe/store.dart';
import 'package:bidvibe/widgets/photo_picker.dart';
import 'package:bidvibe/widgets/common.dart';
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
const _accounts = {
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
  'RESTRICTED': (
    'bidder',
    String.fromEnvironment('E2E_ANDROID_RESTRICTED_EMAIL'),
    String.fromEnvironment('E2E_ANDROID_RESTRICTED_PASSWORD')
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
final _s = <String, dynamic>{};

// RootShell remains mounted under detail routes. Include that offstage root
// when obtaining the real authenticated store; UI finders stay visible-only.
RemoteAppStore _store(WidgetTester t) =>
    t.element(find.byType(RootShell, skipOffstage: false)).read<AppStore>()
        as RemoteAppStore;
ApiClient _api(WidgetTester t) => _store(t).api;
Finder _text(String value) => find.text(value);
Duration _uiPause(int fast, int stable) => Duration(
    milliseconds:
        _caseEvidence['freshNavigationRequired'] == true ? stable : fast);

Future<void> _wait(WidgetTester t, bool Function() ready, String reason,
    {int seconds = 60}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (!ready() && DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 200));
  }
  expect(ready(), isTrue, reason: reason);
}

Future<void> _reveal(WidgetTester t, Finder target) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pump(_uiPause(60, 250));
  final scrolls = find.byType(Scrollable);
  if (target.evaluate().isEmpty && scrolls.evaluate().isEmpty) {
    await _wait(
        t,
        () => target.evaluate().isNotEmpty || scrolls.evaluate().isNotEmpty,
        'route content loaded before finding target');
  }
  if (target.evaluate().isEmpty && scrolls.evaluate().isNotEmpty) {
    // Lists lazily build their children on Android. Search only the visible
    // route; IndexedStack's offstage role tabs are excluded by the finder.
    try {
      await t.scrollUntilVisible(target, 280,
          scrollable: scrolls.first, maxScrolls: 65);
    } on StateError {
      // The target may be above the viewport after another action scrolled
      // down. Lazy lists remove those elements until we scroll back up.
      await t.scrollUntilVisible(target, -280,
          scrollable: scrolls.first, maxScrolls: 65);
    }
  }
  expect(target, findsOneWidget);
  await t.ensureVisible(target);
  await t.pump(_uiPause(40, 200));
}

bool _actionReady(Finder target) {
  if (target.hitTestable().evaluate().length != 1) return false;
  var enabled = true;
  bool inspect(Widget widget) {
    if (widget is ButtonStyleButton) {
      enabled = widget.onPressed != null;
      return false;
    }
    if (widget is IconButton) {
      enabled = widget.onPressed != null;
      return false;
    }
    if (widget is CheckboxListTile) {
      enabled = widget.onChanged != null;
      return false;
    }
    return true;
  }

  final element = target.evaluate().single;
  if (inspect(element.widget)) {
    element.visitAncestorElements((e) => inspect(e.widget));
  }
  return enabled;
}

Future<void> _tap(WidgetTester t, Finder target) async {
  await _reveal(t, target);
  await _wait(t, () => _actionReady(target),
      'target is enabled, unobscured and tappable');
  await t.tap(target);
  await t.pump(_uiPause(60, 250));
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
  await t.pump(_uiPause(40, 200));
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
          find.byTooltip('Đăng xuất').evaluate().isNotEmpty ||
          find.widgetWithText(TextButton, 'Về đăng nhập').evaluate().isNotEmpty,
      'initial application session');
  final recovery = find.widgetWithText(TextButton, 'Về đăng nhập');
  if (recovery.evaluate().isNotEmpty) {
    _caseEvidence['sessionSetupRecovery'] = {
      'action': 'Used application UI to return to login after restore failure',
      'error': _store(t).restoreError,
      'classification':
          'Authentication precondition recovery; no business mutation replay',
    };
    await _tap(t, recovery);
    await _wait(t, () => find.byType(AuthLoginScreen).evaluate().isNotEmpty,
        'return to login through application recovery action');
  }
}

// Auxiliary API actors reuse a previously authenticated token for the same
// role/email during this run. UI role switches still sign in through the app;
// every business request remains authenticated and authorized by the backend.
final _actorTokens = <String, String>{};
void _rememberActor((String, String, String) account, String? token) {
  if (token != null && token.isNotEmpty) {
    _actorTokens['${account.$1}|${account.$2}'] = token;
  }
}

Future<void> _login(WidgetTester t, String alias) async {
  if (alias == 'BUYER' && _s['validationBuyerAlias'] is String) {
    alias = _s['validationBuyerAlias'] as String;
  }
  final a = _accounts[alias]!;
  expect(a.$2.isNotEmpty && a.$3.isNotEmpty, isTrue,
      reason: 'Missing configured account $alias');
  if (find.byTooltip('Đăng xuất').evaluate().isNotEmpty) {
    if (_store(t).currentUser?.email.toLowerCase() == a.$2.toLowerCase() &&
        _store(t).currentUser?.role == a.$1 &&
        _caseEvidence['freshNavigationRequired'] != true) {
      _rememberActor(a, _api(t).token);
      _caseEvidence['sessionSetup'] =
          'Restored the same verified identity; no repeated login';
      return;
    }
    Navigator.of(t.element(find.byType(RootShell, skipOffstage: false)))
        .popUntil((r) => r.isFirst);
    await t.pump();
    await _tap(t, find.byTooltip('Đăng xuất'));
    await _wait(t, () => find.byType(AuthLoginScreen).evaluate().isNotEmpty,
        'switch authenticated role');
  }

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
  _rememberActor(a, _api(t).token);
}

Future<ApiClient> _actor(String alias) async {
  final a = _accounts[alias]!;
  final api = ApiClient();
  final cached = _actorTokens['${a.$1}|${a.$2}'];
  if (cached != null) {
    api.token = cached;
    return api;
  }
  try {
    final data = await api.request(
        '/api/auth/${['bidder', 'seller'].contains(a.$1) ? '' : 'ops/'}login',
        body: {'email': a.$2, 'password': a.$3});
    api.token = '${data['token']}';
    _rememberActor(a, api.token);
    return api;
  } catch (_) {
    api.close();
    rethrow;
  }
}

Future<Map<String, dynamic>> _host(
    String endpoint, Map<String, dynamic> data) async {
  final response = await http
      .post(Uri.parse('$_control$endpoint'),
          headers: {'Content-Type': 'application/json', 'x-control-key': _key},
          body: jsonEncode(data))
      .timeout(const Duration(seconds: 35));
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

class _BusinessCase {
  final String id, description;
  final Future<void> Function(WidgetTester) body;
  final List<String> requires;
  const _BusinessCase(this.id, this.description, this.body, this.requires);
}

final _definitions = <_BusinessCase>[];
const _mainFlow = <String>[
  'A-LIST-01',
  'A-APP-01',
  'A-BID-A',
  'A-BID-B',
  'A-RT-BID',
  'A-WIN-01',
  'A-PAY-01',
  'A-SHIP-01',
  'A-WH-1',
  'A-WH-2',
  'A-WH-3',
  'A-WH-4',
  'A-WH-5',
  'A-RECEIPT',
  'A-NOTIFY',
  'A-WALLET-LEDGER',
];
void _scenario(
    String id, String description, Future<void> Function(WidgetTester) body,
    {List<String> requires = const []}) {
  _definitions.add(_BusinessCase(id, description, body, requires));
}

void _registerScenarios() {
  if (_definitions.map((c) => c.id).toSet().length != _definitions.length) {
    throw StateError('Duplicate business case IDs');
  }
  final ordered = [
    for (final id in _mainFlow) _definitions.singleWhere((c) => c.id == id),
    ..._definitions.where((c) => !_mainFlow.contains(c.id)),
  ];
  for (final c in ordered) {
    _runScenario(c.id, c.description, c.body, requires: c.requires);
  }
}

void _runScenario(
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
    _caseEvidence.clear();
    _caseEvidence['freshNavigationRequired'] = id.startsWith('A-ADDR-');
    final watch = Stopwatch()..start();
    const primaryKeys = [
      'mainTitle',
      'listingId',
      'auctionId',
      'orderId',
      'validationBuyerAlias'
    ];
    final originalContext = {for (final key in primaryKeys) key: _s[key]};
    var usingValidationContext = false;
    try {
      // Use the existing integration binding and mock only its text-input channel.
      // HTTP, the app widgets and all business services remain real.
      t.testTextInput.register();
      await _boot(t);
      final validation = await _validationContext(t, id);
      if (validation != null) {
        usingValidationContext = true;
        _s.addAll(validation);
        _caseEvidence['fixturePreparation'] =
            'Separate run-owned API fixture; main UI journey is not replayed or mutated';
      }
      _caseEvidence['phase'] =
          _mainFlow.contains(id) ? 'main-flow' : 'additional-cases';
      await body(t);
      final error = t.takeException();
      expect(error == null, isTrue,
          reason: 'Flutter framework exception; inspect execution log');
      await _record(id, 'PASS', {
        'description': description,
        'elapsedMs': watch.elapsedMilliseconds,
        ..._publicState(),
        ..._caseEvidence
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
          ..._caseEvidence
        });
      } catch (reportError) {
        debugPrint('Android report transport error: $reportError');
      }
      rethrow;
    } finally {
      if (usingValidationContext) {
        for (final key in primaryKeys) {
          if (originalContext[key] == null) {
            _s.remove(key);
          } else {
            _s[key] = originalContext[key];
          }
        }
      }
      try {
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump(_uiPause(100, 400));
      } finally {
        t.testTextInput.unregister();
      }
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
  await _nav(t, 'Khám phá');
  final detail = await _api(t).request('/api/auctions/$id');
  if (detail['status'] == 'ended' || detail['status'] == 'cancelled') {
    await _tap(t, find.byType(DropdownButtonFormField<String>).first);
    await _tap(t, find.text('Đã kết thúc / hủy').last);
  }
  final field = find
      .descendant(
          of: find.byType(BidderHomeScreen), matching: find.byType(TextField))
      .first;
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

Future<void> _openWarehouseDetail(WidgetTester t) async {
  await _tap(t, _text(_s['mainTitle'] as String));
  final detail = find.byType(WarehouseOpsDetailScreen);
  await _wait(
      t,
      () =>
          detail.evaluate().length == 1 &&
          t.widget<WarehouseOpsDetailScreen>(detail).orderId == _s['orderId'] &&
          find
              .descendant(
                  of: detail, matching: find.byType(CircularProgressIndicator))
              .evaluate()
              .isEmpty &&
          find
              .descendant(
                  of: detail, matching: find.text(_s['mainTitle'] as String))
              .evaluate()
              .isNotEmpty,
      'exact warehouse order data loaded, not just its route heading');
}

Future<void> _topup(WidgetTester t, int amount) async {
  final api = _api(t);
  final before = await api.request('/api/wallet');
  await _nav(t, 'Ví');
  final field = find.descendant(
      of: find.byType(BidderWalletScreen),
      matching: find.byType(TextFormField));
  await _wait(
      t,
      () =>
          field.evaluate().isNotEmpty &&
          t.widget<TextFormField>(field).enabled == true,
      'wallet editable');
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
  await _tap(t, button);
  await _tap(t, find.widgetWithText(FilledButton, 'Xác nhận đặt cọc'));
  await _wait(
      t,
      () => find
          .text('Bạn đã đặt cọc tham gia phiên này. Không cần đặt cọc lại.')
          .evaluate()
          .isNotEmpty,
      'UI deposit confirmed');
  expect((await _api(t).request('/api/auctions/$id'))['joined'], true);
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
  await _tap(
      t,
      find.descendant(
          of: panel, matching: find.widgetWithText(FilledButton, 'Đặt giá')));
  await _tap(t, find.widgetWithText(FilledButton, 'Xác nhận đặt giá'));
  await _wait(
      t,
      () =>
          t.widget<AuctionBidPanel>(panel).controller.data?['leading'] == true,
      'UI winning bid accepted');
  expect((await _api(t).request('/api/auctions/$id'))['leading'], true);
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
  await _nav(t, 'Hồ sơ');
  final target = find.text(title);
  await _wait(
      t, () => target.evaluate().isNotEmpty, 'profile order list loads');
  await _tap(t, target);
  await _wait(t, () => find.text('Đơn hàng #$id').evaluate().isNotEmpty,
      'order detail $id');
}

Future<void> _createApiFixture(WidgetTester t, String kind,
    {int startingPrice = 10000}) async {
  final seller = await _actor('SELLER');
  final appraiser = await _actor('APPRAISER');
  try {
    final title = '${_prefix}_$kind';
    final draft = await seller.request('/api/listings', body: {
      'title': title,
      'categoryCode': 'shoes',
      'startingPrice': startingPrice,
      'durationHours': 1,
      'description': 'Android E2E setup only',
      'condition': 'Test fixture'
    });
    final id = '${draft['id']}';
    await seller
        .request('/api/listings/$id/photos', body: {'url': _s['photoUrl']});
    await seller.request('/api/listings/$id/submit', method: 'POST');
    final approved = await appraiser.request('/api/appraisals/$id/decision',
        body: {'decision': 'approve', 'reason': 'Android E2E fixture'});
    _s['${kind}Title'] = title;
    _s['${kind}ListingId'] = id;
    _s['${kind}AuctionId'] = '${approved['auctionId']}';
  } finally {
    seller.close();
    appraiser.close();
  }
}

Future<void> _preparePaid(WidgetTester t, String kind) async {
  final buyer = await _actor('BUYER');
  try {
    final id = _s['${kind}AuctionId'] as String;
    final detail = await buyer.request('/api/auctions/$id');
    expect(detail['status'], 'active');
    final wallet = await buyer.request('/api/wallet');
    if ((wallet['available'] as num) < (detail['depositRequired'] as num)) {
      await buyer.request('/api/wallet/topup', body: {'amount': 10000});
    }
    final addresses =
        (await buyer.request('/api/addresses'))['addresses'] as List;
    final candidates =
        [_s['addressId'], _s['setupAddressId']].whereType<String>().toList();
    final owned =
        addresses.where((a) => candidates.contains('${a['id']}')).toList();
    final address = owned.isNotEmpty
        ? owned.first
        : await buyer.request('/api/addresses', body: {
            'recipientName': 'E2E Android API Setup',
            'phone': '0900000000',
            'city': 'Ho Chi Minh',
            'addressLine': 'E2E test only - 1 Setup Street'
          });
    _s['setupAddressId'] = '${address['id']}';
    await buyer.request('/api/auctions/$id/join', method: 'POST');
    await buyer.request('/api/bids',
        body: {'auctionId': id, 'amount': detail['minNextBid']});
    await _end(t, buyer, _s['${kind}Title'] as String, id);
    final orders = await buyer.request('/api/orders/mine');
    final order = (orders['orders'] as List)
        .singleWhere((o) => '${o['auctionId']}' == id);
    _s['${kind}OrderId'] = '${order['id']}';
    await buyer.request('/api/orders/${order['id']}/shipping-address',
        body: {'addressId': _s['setupAddressId']});
    await buyer
        .request('/api/orders/${order['id']}/pay', body: {'method': 'qr'});
    expect((await buyer.request('/api/orders/${order['id']}'))['paymentStatus'],
        'paid');
  } finally {
    buyer.close();
  }
}

// UI actions remain Android actions. API checks are tagged separately in evidence.
final _caseEvidence = <String, dynamic>{};
Future<void> _reject(ApiClient api, String endpoint, String code,
    {Map<String, dynamic> body = const {}, String method = 'POST'}) async {
  ApiException? rejection;
  try {
    await api.request(endpoint, method: method, body: body);
  } on ApiException catch (error) {
    rejection = error;
  }
  expect(rejection, isNotNull, reason: 'Expected rejection at $endpoint');
  expect(rejection!.code, code);
  (_caseEvidence['apiAssertions'] ??= <Map<String, dynamic>>[]).add({
    'endpoint': endpoint,
    'expectedCode': code,
    'classification':
        'Authenticated API business assertion; not an Android UI action',
  });
}

Future<void> _addresses(WidgetTester t) async {
  await _nav(t, 'Hồ sơ');
  await _wait(
      t,
      () =>
          find
              .byWidgetPredicate(
                  (w) => w.runtimeType.toString() == 'AuthProfileScreen')
              .evaluate()
              .isNotEmpty &&
          find.byType(LinearProgressIndicator).evaluate().isEmpty,
      'profile data loaded before scrolling');
  final open = find.text('Quản lý địa chỉ giao hàng');
  await _reveal(t, open);
  await Scrollable.ensureVisible(t.element(open), alignment: 0.5);
  await t.pump(const Duration(milliseconds: 200));
  await _wait(
      t, () => _actionReady(open), 'address action ready in the viewport');
  await t.tap(open);
  await t.pump(const Duration(milliseconds: 200));
  await _wait(
      t,
      () =>
          find.byType(AddressBookScreen).evaluate().isNotEmpty &&
          find.text('Thêm địa chỉ mới').evaluate().isNotEmpty &&
          find.byType(LinearProgressIndicator).evaluate().isEmpty,
      'address book ready');
}

Future<Map<String, dynamic>> _listingStatus(
    WidgetTester t, ApiClient api, String id, String status) async {
  final data = await _readUntil(
      t,
      api,
      '/api/listings/mine?limit=100',
      (d) => (d['listings'] as List)
          .any((l) => '${l['id']}' == id && l['status'] == status));
  return Map<String, dynamic>.from(
      (data['listings'] as List).singleWhere((l) => '${l['id']}' == id));
}

Future<void> _pending(WidgetTester t, String kind) async {
  final api = await _actor('SELLER');
  try {
    final title = '${_prefix}_$kind';
    final listing = await api.request('/api/listings', body: {
      'title': title,
      'categoryCode': 'shoes',
      'startingPrice': 10000,
      'durationHours': 1,
      'description': 'Android business scenario fixture',
      'condition': 'Test fixture',
    });
    final id = '${listing['id']}';
    await api
        .request('/api/listings/$id/photos', body: {'url': _s['photoUrl']});
    await api.request('/api/listings/$id/submit', method: 'POST');
    _s['${kind}ListingId'] = id;
    _s['${kind}Title'] = title;
    _caseEvidence['setup'] =
        'Pending listing prepared by API; decision exercised through Android UI';
  } finally {
    api.close();
  }
}

Future<void> _refreshAppraisalQueue(WidgetTester t) async {
  // Reused sessions can display a queue fetched before the API fixture changed.
  await _tap(t, _text('Chờ bổ sung'));
  await _tap(t, _text('Chờ duyệt'));
}

Future<void> _disputeRow(WidgetTester t, String title) async {
  await _nav(t, 'Tranh chấp');
  final row = find.descendant(
      of: find.byType(AdminOpsDisputesScreen),
      matching: find.byWidgetPredicate((w) =>
          w is ListTile && w.title is Text && (w.title as Text).data == title));
  await _tap(t, row);
}

final _validationFixtures = <String, Map<String, dynamic>>{};
Future<Map<String, dynamic>?> _validationContext(
    WidgetTester t, String id) async {
  final kind = switch (id) {
    'A-JOIN-POOR' => 'validationPoor',
    'A-BID-NODEPOSIT' ||
    'A-BID-LOW' ||
    'A-BID-CANCEL' ||
    'A-BID-SELF' =>
      'validationBid',
    'A-PAY-NOADDRESS' ||
    'A-SHIP-UNPAID' ||
    'A-RECEIPT-EARLY' =>
      'validationUnpaid',
    'A-WH-MISMATCH-EMPTY' ||
    'A-WH-PACK-EARLY' ||
    'A-WH-SHIP-EMPTY' =>
      'validationWarehouse',
    _ => null,
  };
  if (kind == null) return null;
  if (!_validationFixtures.containsKey(kind)) {
    await _createApiFixture(t, kind,
        startingPrice: kind == 'validationPoor' ? 100000000 : 10000);
    if (kind == 'validationUnpaid') {
      final buyer = await _actor('COMPETITOR');
      try {
        final auctionId = _s['${kind}AuctionId'] as String;
        final d = await buyer.request('/api/auctions/$auctionId');
        await buyer.request('/api/auctions/$auctionId/join', method: 'POST');
        await buyer.request('/api/bids',
            body: {'auctionId': auctionId, 'amount': d['minNextBid']});
        await _end(t, buyer, _s['${kind}Title'] as String, auctionId);
        final rows =
            (await buyer.request('/api/orders/mine'))['orders'] as List;
        _s['${kind}OrderId'] =
            '${rows.singleWhere((o) => '${o['auctionId']}' == auctionId)['id']}';
      } finally {
        buyer.close();
      }
    }
    if (kind == 'validationWarehouse') {
      await _preparePaid(t, kind);
      final seller = await _actor('SELLER'),
          warehouse = await _actor('WAREHOUSE');
      try {
        final orderId = _s['${kind}OrderId'];
        await seller.request('/api/orders/$orderId/ship-to-warehouse',
            method: 'POST');
        await warehouse.request('/api/warehouse/orders/$orderId/receive',
            method: 'POST');
      } finally {
        seller.close();
        warehouse.close();
      }
    }
    _validationFixtures[kind] = {
      'mainTitle': _s['${kind}Title'],
      'listingId': _s['${kind}ListingId'],
      'auctionId': _s['${kind}AuctionId'],
      'orderId': _s['${kind}OrderId'],
      if (kind == 'validationUnpaid') 'validationBuyerAlias': 'COMPETITOR',
    };
  }
  final f = _validationFixtures[kind]!;
  if (id == 'A-BID-SELF') {
    final buyer = await _actor('BUYER');
    try {
      final d = await buyer.request('/api/auctions/${f['auctionId']}');
      if (d['leading'] != true) {
        await buyer.request('/api/bids',
            body: {'auctionId': f['auctionId'], 'amount': d['minNextBid']});
      }
    } finally {
      buyer.close();
    }
  }
  if (id == 'A-WH-SHIP-EMPTY') {
    final warehouse = await _actor('WAREHOUSE');
    try {
      await warehouse.request('/api/warehouse/orders/${f['orderId']}/inspect',
          body: {'result': 'match'});
      await warehouse
          .request('/api/warehouse/orders/${f['orderId']}/pack', body: {});
    } finally {
      warehouse.close();
    }
  }
  return f;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    expect(_allow, isTrue);
    expect(_prefix.startsWith('E2E_ANDROID_'), isTrue);
    await ApiClient.loadConfig();
    expect(_url, 'https://bidvibe-be.onrender.com');
    for (final alias in ['COMPETITOR', 'BUYER']) {
      final account = _accounts[alias]!;
      final api = ApiClient();
      try {
        await api.request('/api/auth/register', body: {
          'fullName': 'E2E Android $alias',
          'email': account.$2,
          'password': account.$3,
          'role': 'bidder',
        });
      } finally {
        api.close();
      }
    }
    _s['competitorReady'] = true;
    _s['buyerReady'] = true;
  });

  _scenario('A-SELL-EMPTY',
      'Seller cannot submit a listing without required title, price and image',
      (t) async {
    await _login(t, 'SELLER');
    await _nav(t, 'Tạo mới');
    final button = find.byWidgetPredicate(
        (w) => w is BigActionButton && w.label == 'Gửi để thẩm định');
    await _reveal(t, button);
    expect(t.widget<BigActionButton>(button).onPressed, isNull);
  });

  final invalidTopups = [
    ('EMPTY', ''),
    ('ZERO', '0'),
    ('NEGATIVE', '-1'),
    ('DECIMAL', '1.5'),
    ('OVERMAX', '100000001')
  ];
  for (final input in invalidTopups) {
    _scenario(
        'A-WALLET-${input.$1}', 'Wallet UI rejects invalid top-up: ${input.$1}',
        (t) async {
      await _login(t, 'BUYER');
      final before = await _api(t).request('/api/wallet');
      await _nav(t, 'Ví');
      final field = find.descendant(
          of: find.byType(BidderWalletScreen),
          matching: find.byType(TextFormField));
      await _wait(
          t,
          () =>
              field.evaluate().isNotEmpty &&
              t.widget<TextFormField>(field).enabled == true,
          'wallet loaded');
      await _enter(t, field, input.$2);
      await _tap(t, find.widgetWithText(FilledButton, 'Nạp tiền'));
      expect(
          find.text(
              'Nhập số nguyên từ 1 đến 100.000.000 đồng, không có dấu phân cách.'),
          findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      final after = await _api(t).request('/api/wallet');
      expect(after['balance'], before['balance']);
      expect(after['held'], before['held']);
    }, requires: ['buyerReady']);
  }

  _scenario('A-LIST-01',
      'Seller submits a listing; selected image bytes are injected, upload is real',
      (t) async {
    await _login(t, 'SELLER');
    _s['sellerId'] = _store(t).currentUser!.id;
    _s['mainTitle'] = '${_prefix}_Main';
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
        .onChanged([PickedImage(bytes, 'android-e2e.png')]);
    await t.pump();
    await _enter(
        t,
        find.byWidgetPredicate((w) =>
            w is TextField &&
            w.decoration?.hintText == 'Ví dụ: Bình gốm men rạn thế kỷ XIX'),
        _s['mainTitle'] as String);
    await _enter(
        t,
        find.byWidgetPredicate((w) =>
            w is TextField && w.decoration?.hintText == 'Nhập giá khởi điểm'),
        '10000');
    await _tap(t, _text('Gửi để thẩm định'));
    Map<String, dynamic>? row;
    for (var n = 0; n < 45; n++) {
      await t.pump(const Duration(seconds: 1));
      final data = await _api(t).request('/api/listings/mine?limit=100');
      final matches = (data['listings'] as List)
          .where((o) => o['title'] == _s['mainTitle'])
          .toList();
      if (matches.isNotEmpty &&
          matches.single['status'] == 'pending_appraisal') {
        row = Map<String, dynamic>.from(matches.single);
        break;
      }
    }
    expect(row, isNotNull);
    _s['listingId'] = '${row!['id']}';
    _s['photoUrl'] = row['photos'][0]['url'];
  });

  _scenario('A-APP-INFO',
      'Appraiser requests more information with mandatory reason through Android',
      (t) async {
    await _pending(t, 'info');
    await _login(t, 'APPRAISER');
    await _refreshAppraisalQueue(t);
    await _tap(t, _text(_s['infoTitle'] as String));
    await _tap(t, _text('Yêu cầu bổ sung'));
    await _enter(t, _field('Lý do bắt buộc'), 'E2E: add condition details');
    await _tap(t, find.widgetWithText(FilledButton, 'Tiếp tục'));
    final seller = await _actor('SELLER');
    try {
      await _listingStatus(
          t, seller, _s['infoListingId'] as String, 'needs_info');
    } finally {
      seller.close();
    }
    _s['needsInfo'] = true;
  }, requires: ['photoUrl']);
  _scenario('A-APP-RESUBMIT',
      'Seller API resubmission returns the exact needs-info listing to Android appraisal queue',
      (t) async {
    final seller = await _actor('SELLER');
    try {
      await seller.request('/api/listings/${_s['infoListingId']}',
          method: 'PATCH',
          body: {'description': 'E2E additional condition details'});
      await seller.request('/api/listings/${_s['infoListingId']}/resubmit',
          method: 'POST');
    } finally {
      seller.close();
    }
    _caseEvidence['classification'] =
        'API seller resubmission plus Android queue observation';
    await _login(t, 'APPRAISER');
    await _refreshAppraisalQueue(t);
    await _tap(t, _text(_s['infoTitle'] as String));
    await _tap(t, _text('Duyệt và mở phiên'));
    await _tap(t, find.widgetWithText(FilledButton, 'Duyệt'));
    final seller2 = await _actor('SELLER');
    try {
      await _listingStatus(t, seller2, _s['infoListingId'] as String, 'live');
    } finally {
      seller2.close();
    }
  }, requires: ['needsInfo']);
  _scenario('A-APP-REJECT',
      'Appraiser rejects a separate pending listing with a recorded reason',
      (t) async {
    await _pending(t, 'reject');
    await _login(t, 'APPRAISER');
    await _refreshAppraisalQueue(t);
    await _tap(t, _text(_s['rejectTitle'] as String));
    await _tap(t, find.widgetWithText(OutlinedButton, 'Từ chối'));
    await _enter(t, _field('Lý do bắt buộc'), 'E2E: item not eligible');
    await _tap(t, find.widgetWithText(FilledButton, 'Tiếp tục'));
    final seller = await _actor('SELLER');
    try {
      await _listingStatus(
          t, seller, _s['rejectListingId'] as String, 'rejected');
    } finally {
      seller.close();
    }
  }, requires: ['photoUrl']);

  _scenario('A-APP-01', 'Appraiser approves the exact listing through UI',
      (t) async {
    await _login(t, 'APPRAISER');
    await _tap(t, _text(_s['mainTitle'] as String));
    await _tap(t, _text('Duyệt và mở phiên'));
    await _tap(t, find.widgetWithText(FilledButton, 'Duyệt'));
    await _wait(t, () => find.text('Hàng chờ').evaluate().isNotEmpty,
        'return to queue');
    final rows = await _api(t).request(
        '/api/auctions?status=live&q=${Uri.encodeQueryComponent(_s['mainTitle'] as String)}');
    final list = rows['auctions'] as List;
    expect(list.length, 1);
    _s['auctionId'] = '${list.single['id']}';
  }, requires: ['listingId']);

  _scenario('A-JOIN-POOR',
      'Insufficient available balance prevents deposit without holding money',
      (t) async {
    await _login(t, 'BUYER');
    await _openAuction(t, _s['mainTitle'] as String, _s['auctionId'] as String);
    await _reveal(
        t, _text('Ví chưa đủ tiền cọc. Hãy nạp ví rồi tải lại phiên.'));
    expect(find.widgetWithText(FilledButton, 'Đặt cọc tham gia'), findsNothing);
    final before = await _api(t).request('/api/wallet');
    await _reject(
        _api(t), '/api/auctions/${_s['auctionId']}/join', 'INSUFFICIENT_FUNDS');
    expect((await _api(t).request('/api/wallet'))['held'], before['held']);
  }, requires: ['auctionId', 'buyerReady']);
  _scenario('A-BID-NODEPOSIT',
      'Android disables bidding until the buyer has deposited', (t) async {
    await _login(t, 'BUYER');
    await _openAuction(t, _s['mainTitle'] as String, _s['auctionId'] as String);
    await _reveal(t, find.byType(AuctionBidPanel));
    final button = find.descendant(
        of: find.byType(AuctionBidPanel),
        matching: find.widgetWithText(FilledButton, 'Đặt giá'));
    expect(t.widget<FilledButton>(button).onPressed, isNull);
    expect(
        (await _api(t).request('/api/auctions/${_s['auctionId']}'))['joined'],
        false);
  }, requires: ['auctionId', 'buyerReady']);

  _scenario('A-BID-A', 'Bidder A tops up, joins and bids through UI',
      (t) async {
    await _login(t, 'COMPETITOR');
    final w = await _api(t).request('/api/wallet');
    expect(w['joinBlockedUntil'], isNull);
    _s['aHeldBefore'] = w['held'];
    await _topup(t, 10000);
    await _openAuction(t, _s['mainTitle'] as String, _s['auctionId'] as String);
    await _join(t, _s['auctionId'] as String);
    await _bid(t, _s['auctionId'] as String);
    _s['bidA'] = true;
  }, requires: ['auctionId', 'competitorReady']);

  _scenario('A-BID-LOW',
      'Android rejects a below-minimum bid without inserting another bid',
      (t) async {
    await _login(t, 'BUYER');
    final wallet = await _api(t).request('/api/wallet');
    final d = await _api(t).request('/api/auctions/${_s['auctionId']}');
    if ((wallet['available'] as num) < (d['depositRequired'] as num)) {
      await _topup(t, 100000);
    }
    _s['buyerFunded'] = true;
    await _openAuction(t, _s['mainTitle'] as String, _s['auctionId'] as String);
    await _join(t, _s['auctionId'] as String);
    final before = await _api(t).request('/api/auctions/${_s['auctionId']}');
    final minimum = find.widgetWithText(TextButton, 'Dùng giá tối thiểu');
    await _reveal(t, minimum);
    await _wait(
        t, () => t.widget<TextButton>(minimum).onPressed != null, 'bid ready');
    await _enter(t, _field('Giá muốn đặt'), '1');
    await _tap(
        t,
        find.descendant(
            of: find.byType(AuctionBidPanel),
            matching: find.widgetWithText(FilledButton, 'Đặt giá')));
    expect(find.textContaining('Tối thiểu '), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
        (await _api(t).request('/api/auctions/${_s['auctionId']}'))['bidCount'],
        before['bidCount']);
    _s['buyerJoined'] = true;
  }, requires: ['bidA', 'buyerReady']);
  _scenario('A-BID-CANCEL',
      'Cancelling the bid confirmation leaves price and bid count unchanged',
      (t) async {
    await _login(t, 'BUYER');
    await _openAuction(t, _s['mainTitle'] as String, _s['auctionId'] as String);
    final before = await _api(t).request('/api/auctions/${_s['auctionId']}');
    await _tap(t, find.widgetWithText(TextButton, 'Dùng giá tối thiểu'));
    await _tap(
        t,
        find.descendant(
            of: find.byType(AuctionBidPanel),
            matching: find.widgetWithText(FilledButton, 'Đặt giá')));
    await _tap(t, find.widgetWithText(TextButton, 'Hủy'));
    final after = await _api(t).request('/api/auctions/${_s['auctionId']}');
    expect(after['bidCount'], before['bidCount']);
    expect(after['currentPrice'], before['currentPrice']);
  }, requires: ['buyerJoined']);

  _scenario('A-BID-B', 'Fresh buyer tops up, joins and outbids A through UI',
      (t) async {
    await _login(t, 'BUYER');
    if (_s['buyerFunded'] != true) {
      await _topup(t, 500000);
    }
    await _openAuction(t, _s['mainTitle'] as String, _s['auctionId'] as String);
    if ((await _api(t).request('/api/auctions/${_s['auctionId']}'))['joined'] !=
        true) {
      await _join(t, _s['auctionId'] as String);
    }
    await _bid(t, _s['auctionId'] as String);
    _s['bidB'] = true;
  }, requires: ['bidA', 'buyerReady']);

  _scenario(
      'A-BID-SELF', 'Leading bidder cannot outbid themselves through Android',
      (t) async {
    await _login(t, 'BUYER');
    await _openAuction(t, _s['mainTitle'] as String, _s['auctionId'] as String);
    await _reveal(t, _text('Bạn đang dẫn đầu, không cần tự vượt giá mình.'));
    final button = find.descendant(
        of: find.byType(AuctionBidPanel),
        matching: find.widgetWithText(FilledButton, 'Đặt giá'));
    expect(t.widget<FilledButton>(button).onPressed, isNull);
  }, requires: ['bidB']);

  _scenario('A-RT-BID',
      'Android buyer receives an API actor bid live, then outbids through UI',
      (t) async {
    await _login(t, 'BUYER');
    await _openAuction(t, _s['mainTitle'] as String, _s['auctionId'] as String);
    final panel = find.byType(AuctionBidPanel);
    await _reveal(t, panel);
    await _wait(
        t,
        () =>
            panel.evaluate().isNotEmpty &&
            t.widget<AuctionBidPanel>(panel).controller.connected,
        'auction Socket.IO connected');
    final actor = await _actor('COMPETITOR');
    try {
      final d = await actor.request('/api/auctions/${_s['auctionId']}');
      await actor.request('/api/bids',
          body: {'auctionId': _s['auctionId'], 'amount': d['minNextBid']});
      await _wait(
          t,
          () =>
              panel.evaluate().isNotEmpty &&
              t
                      .widget<AuctionBidPanel>(panel)
                      .controller
                      .data?['currentPrice'] ==
                  d['minNextBid'] &&
              t.widget<AuctionBidPanel>(panel).controller.data?['leading'] ==
                  false,
          'external bid appears without manual refresh');
    } finally {
      actor.close();
    }
    await _bid(t, _s['auctionId'] as String);
    _s['realtimeBid'] = true;
  }, requires: ['bidB']);

  _scenario('A-WIN-01',
      'Expire only the new fixture; verify winner/order and loser deposit refund',
      (t) async {
    await _login(t, 'BUYER');
    await _openAuction(t, _s['mainTitle'] as String, _s['auctionId'] as String);
    await _end(
        t, _api(t), _s['mainTitle'] as String, _s['auctionId'] as String);
    await _reveal(t, find.text('Bạn đã thắng phiên này'));
    final rows = await _api(t).request('/api/orders/mine');
    final order = (rows['orders'] as List)
        .singleWhere((o) => '${o['auctionId']}' == _s['auctionId']);
    _s['orderId'] = '${order['id']}';
    final a = await _actor('COMPETITOR');
    try {
      expect((await a.request('/api/wallet'))['held'], _s['aHeldBefore']);
    } finally {
      a.close();
    }
  }, requires: ['bidB']);

  _scenario('A-PAY-NOADDRESS',
      'Android blocks payment before a shipping address is selected',
      (t) async {
    await _login(t, 'BUYER');
    await _openOrder(t, _s['mainTitle'] as String, _s['orderId'] as String);
    await _tap(
        t,
        find.byWidgetPredicate(
            (w) => w is BigActionButton && w.label.startsWith('Thanh toán ')));
    final warning = find.descendant(
        of: find.byType(SnackBar),
        matching:
            find.text('Hãy chọn địa chỉ nhận hàng trước khi thanh toán.'));
    await _wait(t, () => warning.evaluate().isNotEmpty,
        'missing-address payment warning');
    expect(find.byType(AlertDialog), findsNothing);
    expect(
        (await _api(t)
            .request('/api/orders/${_s['orderId']}'))['shippingAddress'],
        isNull);
    expect(
        (await _api(t)
            .request('/api/orders/${_s['orderId']}'))['paymentStatus'],
        'awaiting_payment');
  }, requires: ['orderId']);
  _scenario('A-SHIP-UNPAID',
      'Seller API cannot send the owned unpaid order to the warehouse',
      (t) async {
    await _login(t, 'SELLER');
    await _reject(_api(t), '/api/orders/${_s['orderId']}/ship-to-warehouse',
        'INVALID_STATE');
  }, requires: ['orderId']);
  _scenario('A-ORDER-OWNERSHIP',
      'Other bidder API cannot read or pay the winning buyers order',
      (t) async {
    await _login(t, 'COMPETITOR');
    await _reject(_api(t), '/api/orders/${_s['orderId']}', 'NOT_FOUND',
        method: 'GET');
    await _reject(_api(t), '/api/orders/${_s['orderId']}/pay', 'NOT_FOUND',
        body: {'method': 'wallet'});
  }, requires: ['orderId']);

  _scenario('A-PAY-01',
      'Buyer creates/selects address and pays from wallet through UI',
      (t) async {
    await _login(t, 'BUYER');
    await _openOrder(t, _s['mainTitle'] as String, _s['orderId'] as String);
    await _tap(t, find.textContaining('Chưa có địa chỉ nhận hàng'));
    await _tap(t, _text('Thêm địa chỉ mới'));
    for (final value in [
      ('Họ và tên người nhận', 'E2E Android Buyer'),
      ('Số điện thoại', '0900000000'),
      ('Tỉnh / thành phố', 'Ho Chi Minh'),
      ('Địa chỉ cụ thể', 'E2E test only - 1 Android Street')
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
            walletTile.evaluate().isNotEmpty &&
            t.widget<InkWell>(walletTile).onTap != null,
        'wallet method enabled after address save');
    await _tap(t, walletTile);
    expect(
        find.descendant(
            of: walletTile, matching: find.byIcon(Icons.radio_button_checked)),
        findsOneWidget);
    final before = await _api(t).request('/api/wallet');
    final order = await _api(t).request('/api/orders/${_s['orderId']}');
    _s['addressId'] = '${order['shippingAddress']['id']}';
    await _tap(
        t,
        find.byWidgetPredicate(
            (w) => w is BigActionButton && w.label.startsWith('Thanh toán ')));
    await _tap(t, find.widgetWithText(TextButton, 'Thanh toán'));
    await _wait(
        t,
        () =>
            find.textContaining('Thanh toán thành công').evaluate().isNotEmpty,
        'wallet payment UI feedback');
    final paid = await _api(t).request('/api/orders/${_s['orderId']}');
    expect(paid['paymentStatus'], 'paid');
    final after = await _api(t).request('/api/wallet');
    expect(after['balance'],
        (before['balance'] as num) - (order['amountToPay'] as num));
    _s['paid'] = true;
  }, requires: ['orderId']);

  _scenario('A-PAY-DUPLICATE',
      'API rejects paying a paid order again without another wallet debit',
      (t) async {
    await _login(t, 'BUYER');
    final before = await _api(t).request('/api/wallet');
    await _reject(_api(t), '/api/orders/${_s['orderId']}/pay', 'ALREADY_PAID',
        body: {'method': 'wallet'});
    expect(
        (await _api(t).request('/api/wallet'))['balance'], before['balance']);
  }, requires: ['paid']);
  _scenario(
      'A-RECEIPT-EARLY', 'API rejects receipt confirmation before delivery',
      (t) async {
    await _login(t, 'BUYER');
    await _reject(_api(t), '/api/orders/${_s['orderId']}/confirm-delivery',
        'NOT_DELIVERED');
    expect(
        (await _api(t).request('/api/orders/${_s['orderId']}'))['payoutStatus'],
        'pending');
  }, requires: ['paid']);

  _scenario(
      'A-SHIP-01', 'Seller sends only the test order to warehouse through UI',
      (t) async {
    await _login(t, 'SELLER');
    await _nav(t, 'Gửi kho');
    final title = find.text(_s['mainTitle'] as String);
    await _reveal(t, title);
    final card = find.ancestor(
        of: title,
        matching: find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_ShipmentCard'));
    expect(card, findsOneWidget);
    await _tap(
        t,
        find.descendant(
            of: card, matching: find.text('Tôi đã gửi hàng đến kho')));
    await _readUntil(
        t,
        _api(t),
        '/api/orders/selling?limit=100',
        (data) => (data['orders'] as List).any((o) =>
            '${o['id']}' == _s['orderId'] &&
            o['stage'] == 'in_transit_to_warehouse'));
    _s['shipped'] = true;
  }, requires: ['paid']);

  _scenario(
      'A-SHIP-DUPLICATE', 'API rejects a repeated seller shipment announcement',
      (t) async {
    await _login(t, 'SELLER');
    await _reject(_api(t), '/api/orders/${_s['orderId']}/ship-to-warehouse',
        'ALREADY_SHIPPED');
  }, requires: ['shipped']);

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

    if (step.$1 == 'inspect') {
      _scenario('A-WH-MISMATCH-EMPTY',
          'Warehouse mismatch inspection requires notes before saving',
          (t) async {
        await _login(t, 'WAREHOUSE');
        await _openWarehouseDetail(t);
        await _tap(t, _text('Không khớp, mở tranh chấp'));
        final button =
            find.widgetWithText(FilledButton, 'Lưu kết quả kiểm định');
        await _reveal(t, button);
        expect(t.widget<FilledButton>(button).onPressed, isNull);
        expect(
            (await OpsRepository(_api(t))
                .warehouseOrder(_s['orderId'] as String))['stage'],
            'inspecting');
      }, requires: ['wh-receive']);
      _scenario('A-WH-PACK-EARLY',
          'Warehouse API refuses packing before inspection passes', (t) async {
        await _login(t, 'WAREHOUSE');
        await _reject(_api(t), '/api/warehouse/orders/${_s['orderId']}/pack',
            'INVALID_STATE');
      }, requires: ['wh-receive']);
    }
    if (step.$1 == 'ship') {
      _scenario('A-WH-SHIP-EMPTY',
          'Warehouse cannot ship without carrier and tracking code', (t) async {
        await _login(t, 'WAREHOUSE');
        await _openWarehouseDetail(t);
        await _tap(t, _text('Gửi cho đơn vị vận chuyển'));
        final button = find.widgetWithText(FilledButton, 'Xác nhận gửi');
        expect(t.widget<FilledButton>(button).onPressed, isNull);
        await _tap(t, find.widgetWithText(TextButton, 'Huỷ'));
        expect(
            (await OpsRepository(_api(t))
                .warehouseOrder(_s['orderId'] as String))['stage'],
            'packed');
      }, requires: ['wh-pack']);
    }
    _scenario('A-WH-${i + 1}', 'Warehouse ${step.$1} through UI', (t) async {
      await _login(t, 'WAREHOUSE');
      await _openWarehouseDetail(t);
      await _wait(t, () => find.text('Chi tiết đơn kho').evaluate().isNotEmpty,
          'warehouse detail');
      if (step.$1 == 'inspect') {
        await _tap(t, _text('Khớp mô tả'));
      }
      await _tap(t, _text(step.$2));
      if (step.$1 == 'ship') {
        await _enter(t, _field('Đơn vị vận chuyển'), 'E2E simulated carrier');
        await _enter(t, _field('Mã vận đơn'), 'ANDROID-${_s['orderId']}');
        await _tap(t, _text('Xác nhận gửi'));
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

  _scenario('A-RECEIPT', 'Buyer confirms delivery; verify payout released',
      (t) async {
    await _login(t, 'BUYER');
    await _openOrder(t, _s['mainTitle'] as String, _s['orderId'] as String);
    await _tap(t, _text('Đã nhận hàng'));
    await _tap(t, find.widgetWithText(TextButton, 'Đã nhận hàng'));
    await _readUntil(t, _api(t), '/api/orders/${_s['orderId']}',
        (o) => o['payoutStatus'] == 'released');
    _s['completed'] = true;
  }, requires: ['wh-deliver']);

  final adminTabs = [
    ('OVERVIEW', 'Tổng quan', '/api/admin/dashboard', 'accounts'),
    ('FLAGS', 'Cờ', '/api/admin/flags', 'flags'),
    ('DISPUTES', 'Tranh chấp', '/api/admin/disputes', 'disputes'),
    ('REPORT', 'Báo cáo', '/api/admin/report/weekly', 'period'),
    ('ACCOUNTS', 'Tài khoản', '/api/admin/accounts', 'accounts')
  ];
  for (final tab in adminTabs) {
    _scenario('A-ADMIN-${tab.$1}',
        'Android Admin opens ${tab.$2} and reads real backend data', (t) async {
      await _login(t, 'ADMIN');
      await _nav(t, tab.$2);
      final result = await _api(t).request(tab.$3);
      expect(result, isNotEmpty);
      final screenName = switch (tab.$1) {
        'OVERVIEW' => 'AdminOpsDashboardScreen',
        'FLAGS' => 'AdminOpsFlagsScreen',
        'DISPUTES' => 'AdminOpsDisputesScreen',
        'REPORT' => 'AdminOpsReportScreen',
        _ => 'AdminOpsAccountsScreen',
      };
      final screen =
          find.byWidgetPredicate((w) => w.runtimeType.toString() == screenName);
      await _wait(
          t,
          () =>
              screen.evaluate().isNotEmpty &&
              find
                  .descendant(
                      of: screen,
                      matching: find.byType(CircularProgressIndicator))
                  .evaluate()
                  .isEmpty,
          'Admin business view loaded: $screenName');
      expect(
          find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_OpsError'),
          findsNothing);
      expect(
          find.text('Bạn không có quyền thực hiện thao tác này'), findsNothing);
    });
  }

  _scenario(
      'A-ADDR-EMPTY', 'Android address form rejects empty required fields',
      (t) async {
    await _login(t, 'BUYER');
    await _addresses(t);
    await _tap(t, _text('Thêm địa chỉ mới'));
    await _tap(t, _text('Lưu địa chỉ'));
    expect(find.text('Vui lòng nhập thông tin này.'), findsWidgets);
  }, requires: ['paid']);
  _scenario('A-ADDR-CREATE',
      'Buyer adds an independent second address through Android', (t) async {
    await _login(t, 'BUYER');
    await _addresses(t);
    await _tap(t, _text('Thêm địa chỉ mới'));
    for (final value in [
      ('Họ và tên người nhận', 'E2E Second Address'),
      ('Số điện thoại', '0900000001'),
      ('Tỉnh / thành phố', 'Ha Noi'),
      ('Địa chỉ cụ thể', 'E2E test only - Second Street')
    ]) {
      await _enter(t, _field(value.$1), value.$2);
    }
    await _tap(t, _text('Lưu địa chỉ'));
    await _wait(t, () => find.text('E2E Second Address').evaluate().isNotEmpty,
        'second address visible');
    final rows = (await _api(t).request('/api/addresses'))['addresses'] as List;
    _s['secondAddressId'] =
        '${rows.singleWhere((a) => a['recipientName'] == 'E2E Second Address')['id']}';
  }, requires: ['paid']);
  _scenario(
      'A-ADDR-EDIT', 'Buyer edits only the second address through Android',
      (t) async {
    await _login(t, 'BUYER');
    await _addresses(t);
    final card = find.ancestor(
        of: _text('E2E Second Address'),
        matching: find.byWidgetPredicate((w) =>
            w is Material &&
            w.shape is RoundedRectangleBorder &&
            w.clipBehavior == Clip.antiAlias));
    await _tap(t, find.descendant(of: card, matching: find.text('Sửa')));
    await _wait(t, () => find.text('Sửa địa chỉ').evaluate().isNotEmpty,
        'address editor route is ready');
    final input = find.byKey(const ValueKey('address.addressLine'));
    await _reveal(t, input);
    final controller = t.widget<TextFormField>(input).controller!;
    const updated = 'E2E test only - Updated Street';
    await t.enterText(input, updated);
    await t.pump(const Duration(milliseconds: 300));
    expect(controller.text, updated,
        reason: 'Edited field contains the new address');
    final save = _text('Lưu địa chỉ');
    await _reveal(t, save);
    expect(controller.text, updated,
        reason: 'Address survives scrolling before save');
    _caseEvidence['inputBeforeSave'] = controller.text;
    await t.tap(save);
    await t.pump(const Duration(milliseconds: 300));
    final committed = await _readUntil(
        t,
        _api(t),
        '/api/addresses',
        (d) => (d['addresses'] as List).any((a) =>
            '${a['id']}' == _s['secondAddressId'] &&
            a['addressLine'] == updated));
    await _wait(
        t,
        () =>
            find.byType(AddressBookScreen).evaluate().isNotEmpty &&
            find
                .byWidgetPredicate(
                    (w) => w.runtimeType.toString() == '_AddressEditor')
                .evaluate()
                .isEmpty &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty,
        'return to loaded address book');
    await _reveal(
        t,
        find.byWidgetPredicate(
            (w) => w is Text && (w.data ?? '').contains('Updated Street')));
    final rows = committed['addresses'] as List;
    expect(
        rows.singleWhere(
            (a) => '${a['id']}' == _s['secondAddressId'])['addressLine'],
        'E2E test only - Updated Street');
  }, requires: ['secondAddressId']);
  _scenario('A-ADDR-DEFAULT',
      'Buyer sets exactly one default address through Android', (t) async {
    await _login(t, 'BUYER');
    await _addresses(t);
    final card = find.ancestor(
        of: _text('E2E Second Address'),
        matching: find.byWidgetPredicate((w) =>
            w is Material &&
            w.shape is RoundedRectangleBorder &&
            w.clipBehavior == Clip.antiAlias));
    await _tap(
        t, find.descendant(of: card, matching: find.text('Đặt mặc định')));
    final data = await _poll(
        t,
        () => _api(t).request('/api/addresses'),
        (d) => (d['addresses'] as List).any((a) =>
            '${a['id']}' == _s['secondAddressId'] && a['isDefault'] == true),
        'default address persisted');
    expect((data['addresses'] as List).where((a) => a['isDefault'] == true),
        hasLength(1));
    _s['secondDefault'] = true;
  }, requires: ['secondAddressId']);
  _scenario(
      'A-ADDR-OWNERSHIP', 'Other bidder API cannot edit the buyers address',
      (t) async {
    await _login(t, 'COMPETITOR');
    await _reject(
        _api(t), '/api/addresses/${_s['secondAddressId']}', 'NOT_FOUND',
        method: 'PATCH', body: {'city': 'E2E unauthorized'});
  }, requires: ['secondAddressId']);
  _scenario('A-ADDR-DELETE',
      'Buyer deletes the second address while retaining the order address',
      (t) async {
    await _login(t, 'BUYER');
    await _addresses(t);
    final card = find.ancestor(
        of: _text('E2E Second Address'),
        matching: find.byWidgetPredicate((w) =>
            w is Material &&
            w.shape is RoundedRectangleBorder &&
            w.clipBehavior == Clip.antiAlias));
    await _tap(t, find.descendant(of: card, matching: find.text('Xóa')));
    await _tap(t, find.widgetWithText(TextButton, 'Xóa địa chỉ'));
    final data = await _poll(
        t,
        () => _api(t).request('/api/addresses'),
        (d) => (d['addresses'] as List)
            .every((a) => '${a['id']}' != _s['secondAddressId']),
        'second address deleted');
    expect(
        (data['addresses'] as List).any((a) => '${a['id']}' == _s['addressId']),
        true);
  }, requires: ['secondAddressId']);
  _scenario('A-WALLET-LEDGER',
      'Android wallet displays committed transaction history and consistent available balance',
      (t) async {
    await _login(t, 'BUYER');
    await _nav(t, 'Ví');
    final api = _api(t);
    final wallet = await api.request('/api/wallet');
    expect(wallet['available'], wallet['balance']);
    final tx = await api.request('/api/wallet/transactions?limit=100');
    expect(tx['transactions'], isNotEmpty);
    await _wait(t, () => find.textContaining('Đã tải ').evaluate().isNotEmpty,
        'wallet transaction count rendered');
  }, requires: ['paid']);

  _scenario('A-REPORT', 'Bidder reports the exact admin fixture through UI',
      (t) async {
    await _createApiFixture(t, 'admin');
    _caseEvidence['setup'] = 'Separate moderation auction prepared by API';
    await _login(t, 'BIDDER_A');
    await _openAuction(
        t, _s['adminTitle'] as String, _s['adminAuctionId'] as String);
    await _tap(t, find.byTooltip('Báo cáo phiên'));
    await _enter(t, _field('Lý do báo cáo'), 'Android E2E report');
    await _tap(t, _text('Gửi báo cáo'));
    await _tap(t, _text('Xác nhận gửi'));
    await _wait(
        t,
        () => find
            .textContaining('Báo cáo đã được ghi nhận')
            .evaluate()
            .isNotEmpty,
        'report accepted');
    _s['reported'] = true;
  }, requires: ['photoUrl']);

  for (final action in [
    ('pause', 'Tạm dừng phiên'),
    ('verify', 'Yêu cầu xác minh'),
    ('safe', 'Đánh dấu an toàn')
  ]) {
    _scenario(
        'A-MOD-${action.$1}', 'Admin ${action.$1} exact report through UI',
        (t) async {
      await _login(t, 'ADMIN');
      await _nav(t, 'Cờ');
      await _tap(t, _text(_s['adminTitle'] as String));
      await _tap(t, _text(action.$2));
      await t.pump(const Duration(seconds: 1));
      final flags = await _api(t).request('/api/admin/flags?limit=100');
      final flag = (flags['flags'] as List).singleWhere((f) =>
          '${f['auctionId'] ?? f['auction']?['id']}' == _s['adminAuctionId']);
      expect(
          flag['status'],
          action.$1 == 'pause'
              ? 'paused'
              : action.$1 == 'verify'
                  ? 'verify'
                  : 'safe');
      _s['mod-${action.$1}'] = true;
    }, requires: [
      action.$1 == 'pause'
          ? 'reported'
          : action.$1 == 'verify'
              ? 'mod-pause'
              : 'mod-verify'
    ]);
  }

  _scenario(
      'A-BLOCKED', 'Restricted bidder sees JOIN_BLOCKED reason through UI',
      (t) async {
    await _login(
        t, _accounts['RESTRICTED']!.$2.isNotEmpty ? 'RESTRICTED' : 'BIDDER_B');
    final wallet = await _api(t).request('/api/wallet');
    final until = DateTime.tryParse('${wallet['joinBlockedUntil']}');
    if (until == null || !until.isAfter(DateTime.now())) {
      throw const _SkipCase(
          'No active JOIN_BLOCKED restriction; no violation created to force this scenario.');
    }
    await _openAuction(
        t, _s['adminTitle'] as String, _s['adminAuctionId'] as String);
    final join = find.widgetWithText(FilledButton, 'Đặt cọc tham gia');
    await _reveal(t, join);
    await _wait(
        t,
        () =>
            join.evaluate().isNotEmpty &&
            t.widget<FilledButton>(join).onPressed != null,
        'restriction-check join button ready');
    await _tap(t, join);
    await _tap(t, _text('Xác nhận đặt cọc'));
    await _wait(
        t,
        () => find
            .textContaining('Bạn tạm thời không được tham gia phiên mới')
            .evaluate()
            .isNotEmpty,
        'business restriction shown');
    expect(find.textContaining('Chưa xác định được kết quả đặt cọc'),
        findsNothing);
  }, requires: ['mod-safe']);

  _scenario('A-DISPUTE', 'Buyer opens a dispute through Android UI', (t) async {
    await _preparePaid(t, 'admin');
    _caseEvidence['setup'] =
        'Moderation fixture closed and QR-paid by API; not Android payment coverage';
    await _login(t, 'BUYER');
    await _openOrder(
        t, _s['adminTitle'] as String, _s['adminOrderId'] as String);
    await _tap(t, _text('Hàng có vấn đề? Mở tranh chấp'));
    await _tap(t, _text('Hàng không đúng mô tả'));
    await _enter(
        t,
        find.byWidgetPredicate((w) =>
            w is TextField &&
            w.decoration?.hintText == 'Mô tả cụ thể vấn đề bạn gặp phải…'),
        'Android E2E test item does not match description.');
    await _tap(t, _text('Gửi tranh chấp'));
    final data = await _readUntil(
        t,
        _api(t),
        '/api/disputes/mine',
        (d) => (d['disputes'] as List)
            .any((o) => '${o['orderId']}' == _s['adminOrderId']));
    final list = data['disputes'] as List;
    final dispute =
        list.singleWhere((d) => '${d['orderId']}' == _s['adminOrderId']);
    _s['disputeId'] = '${dispute['id']}';
    expect(
        (await _api(t)
            .request('/api/orders/${_s['adminOrderId']}'))['payoutStatus'],
        'disputed');
  }, requires: ['mod-safe', 'buyerReady']);

  _scenario('A-REFUND', 'Admin refunds exact dispute through Android UI',
      (t) async {
    final buyer = await _actor('BUYER');
    final before = await buyer.request('/api/wallet');
    _s['refundBefore'] = before['balance'];
    try {
      await _login(t, 'ADMIN');
      await _nav(t, 'Tranh chấp');
      // The row's title and subtitle may both contain the item title. Select
      // the actionable ListTile, then verify the dispute/order identity.
      final disputeRow = find.descendant(
          of: find.byType(AdminOpsDisputesScreen),
          matching: find.byWidgetPredicate((w) =>
              w is ListTile &&
              w.title is Text &&
              (w.title as Text).data == _s['adminTitle']));
      await _tap(t, disputeRow);
      await _wait(
          t,
          () => find
              .textContaining(
                  'Tranh chấp #${_s['disputeId']} · Đơn #${_s['adminOrderId']} ·')
              .evaluate()
              .isNotEmpty,
          'exact dispute and order detail');
      await _tap(t, _text('Hoàn tiền người mua'));
      await _tap(t, find.widgetWithText(FilledButton, 'Xác nhận'));
      final data = await _readUntil(
          t,
          _api(t),
          '/api/admin/disputes',
          (d) => (d['disputes'] as List).any((o) =>
              '${o['id']}' == _s['disputeId'] && o['status'] == 'resolved'));
      final d = (data['disputes'] as List)
          .singleWhere((d) => '${d['id']}' == _s['disputeId']);
      expect(d['status'], 'resolved');
      expect((await buyer.request('/api/wallet'))['balance'],
          (before['balance'] as num) + (d['escrowAmount'] as num));
      _s['refundAmount'] = d['escrowAmount'];
      _s['refundAfter'] = (await buyer.request('/api/wallet'))['balance'];
      _s['refunded'] = true;
    } finally {
      buyer.close();
    }
  }, requires: ['disputeId']);

  _scenario('A-REFUND-DUPLICATE',
      'API refuses resolving the refunded dispute twice; balance remains unchanged',
      (t) async {
    await _login(t, 'ADMIN');
    await _reject(_api(t), '/api/admin/disputes/${_s['disputeId']}/resolve',
        'ALREADY_RESOLVED',
        body: {'resolution': 'refund'});
    final buyer = await _actor('BUYER');
    try {
      expect(
          (await buyer.request('/api/wallet'))['balance'], _s['refundAfter']);
    } finally {
      buyer.close();
    }
  }, requires: ['refunded']);
  _scenario('A-KEEP-OPEN',
      'Buyer opens an independent keep-decision dispute through Android',
      (t) async {
    await _createApiFixture(t, 'keep');
    await _preparePaid(t, 'keep');
    _caseEvidence['setup'] =
        'Separate paid order prepared through API; dispute opened through Android';
    await _login(t, 'BUYER');
    await _openOrder(t, _s['keepTitle'] as String, _s['keepOrderId'] as String);
    await _tap(t, _text('Hàng có vấn đề? Mở tranh chấp'));
    await _tap(t, _text('Hàng không đúng mô tả'));
    await _enter(
        t,
        find.byWidgetPredicate((w) =>
            w is TextField &&
            w.decoration?.hintText == 'Mô tả cụ thể vấn đề bạn gặp phải…'),
        'E2E Android independent keep scenario');
    await _tap(t, _text('Gửi tranh chấp'));
    final data = await _readUntil(
        t,
        _api(t),
        '/api/disputes/mine',
        (d) => (d['disputes'] as List)
            .any((x) => '${x['orderId']}' == _s['keepOrderId']));
    _s['keepDisputeId'] =
        '${(data['disputes'] as List).singleWhere((x) => '${x['orderId']}' == _s['keepOrderId'])['id']}';
  }, requires: ['photoUrl', 'buyerReady']);
  _scenario('A-KEEP-RESOLVE',
      'Android Admin keeps the transaction and releases payout without refunding buyer',
      (t) async {
    final buyer = await _actor('BUYER');
    try {
      final before = await buyer.request('/api/wallet');
      await _login(t, 'ADMIN');
      await _disputeRow(t, _s['keepTitle'] as String);
      await _tap(t, _text('Giữ nguyên, giải ngân người bán'));
      await _tap(t, find.widgetWithText(FilledButton, 'Xác nhận'));
      await _readUntil(t, buyer, '/api/orders/${_s['keepOrderId']}',
          (o) => o['payoutStatus'] == 'released');
      final disputes = await buyer.request('/api/disputes/mine');
      expect(
          (disputes['disputes'] as List).singleWhere(
              (d) => '${d['id']}' == _s['keepDisputeId'])['resolution'],
          'keep');
      expect(
          (await buyer.request('/api/wallet'))['balance'], before['balance']);
      _s['kept'] = true;
    } finally {
      buyer.close();
    }
  }, requires: ['keepDisputeId']);

  _scenario('A-NOTIFY',
      'Buyer loads persisted shipping notifications and opens the correct order',
      (t) async {
    await _login(t, 'BUYER');
    await _nav(t, 'Thông báo');
    final screen = find.byType(BidderNotificationsScreen);
    await _wait(t, () => screen.evaluate().isNotEmpty, 'notification screen');
    final controller = t.widget<BidderNotificationsScreen>(screen).controller;
    await _wait(t, () => !controller.loading, 'notifications loaded');
    final notes = controller.items
        .where((n) => '${n.data?['orderId']}' == _s['orderId'])
        .toList();
    expect(notes, isNotEmpty);
    final note = notes.firstWhere((n) => n.type == 'order');
    await _tap(t, _text(note.title));
    await _wait(
        t,
        () => find.text('Đơn hàng #${_s['orderId']}').evaluate().isNotEmpty,
        'notification opens exact order');
  }, requires: ['completed']);

  _scenario('A-RT-REFUND',
      'Logged-in Android buyer receives refund event from external Admin API actor',
      (t) async {
    await _createApiFixture(t, 'rt');
    await _preparePaid(t, 'rt');
    final buyer = await _actor('BUYER');
    try {
      final d = await buyer.request('/api/disputes', body: {
        'orderId': _s['rtOrderId'],
        'source': 'bidder',
        'title': 'Android E2E realtime refund',
        'reason': 'Hàng không đúng mô tả',
        'detail': 'API setup for realtime observation'
      });
      _s['rtDisputeId'] = '${d['id']}';
    } finally {
      buyer.close();
    }
    await _login(t, 'BUYER');
    await _nav(t, 'Thông báo');
    final screen = find.byType(BidderNotificationsScreen);
    await _wait(
        t, () => screen.evaluate().isNotEmpty, 'notification screen mounted');
    final controller = t.widget<BidderNotificationsScreen>(screen).controller;
    await _wait(
        t, () => controller.connected, 'notification Socket.IO connected');
    final events = <Map<String, dynamic>>[];
    final subscription = controller.events!.stream.listen((e) {
      if (e.type == 'notification:new') events.add(e.data);
    });
    final before = await _api(t).request('/api/wallet');
    final admin = await _actor('ADMIN');
    try {
      await admin.request('/api/admin/disputes/${_s['rtDisputeId']}/resolve',
          body: {'resolution': 'refund', 'note': 'Android E2E realtime actor'});
      await _wait(
          t,
          () => events.any((n) =>
              n['type'] == 'refund' &&
              '${n['data']?['disputeId']}' == _s['rtDisputeId']),
          'real refund event without re-login or refresh');
      await _wait(
          t,
          () => controller.items.any((n) =>
              n.type == 'refund' &&
              '${n.data?['disputeId']}' == _s['rtDisputeId']),
          'refund appears in notification controller');
      expect((await _api(t).request('/api/wallet'))['balance'],
          greaterThan(before['balance'] as num));
    } finally {
      await subscription.cancel();
      admin.close();
    }
  }, requires: ['photoUrl', 'buyerReady']);

  _scenario('A-NOTIFY-READALL',
      'Android buyer marks persisted notifications read and unread count reaches zero',
      (t) async {
    await _login(t, 'BUYER');
    await _nav(t, 'Thông báo');
    final screen = find.byType(BidderNotificationsScreen);
    await _wait(t, () => screen.evaluate().isNotEmpty, 'notification view');
    final c = t.widget<BidderNotificationsScreen>(screen).controller;
    await _wait(t, () => !c.loading, 'notifications loaded');
    expect(c.items, isNotEmpty);
    await _tap(t, _text('Đánh dấu tất cả đã đọc'));
    await _wait(t, () => c.unreadCount == 0, 'read-all reflected in Android');
    expect(
        (await _api(t).request('/api/notifications?limit=100'))['unreadCount'],
        0);
  }, requires: ['completed']);
  final deniedRoles = [
    ('BUYER', 'BIDDER', '/api/admin/dashboard'),
    ('SELLER', 'SELLER', '/api/admin/accounts'),
    ('APPRAISER', 'APPRAISER', '/api/warehouse/orders'),
    ('WAREHOUSE', 'WAREHOUSE', '/api/appraisals/queue')
  ];
  for (final role in deniedRoles) {
    _scenario('A-RBAC-${role.$2}',
        'Authenticated ${role.$2} API is denied another roles protected business endpoint',
        (t) async {
      await _login(t, role.$1);
      await _reject(_api(t), role.$3, 'FORBIDDEN', method: 'GET');
    });
  }
  _registerScenarios();
}
