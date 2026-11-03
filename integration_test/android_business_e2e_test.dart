import 'dart:convert';
import 'dart:ui' as ui;

import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/core/picked_image.dart';
import 'package:bidvibe/core/remote_app_store.dart';
import 'package:bidvibe/features/ops/ops_repository.dart';
import 'package:bidvibe/main.dart';
import 'package:bidvibe/screens/auth/auth_login.dart';
import 'package:bidvibe/screens/admin/admin_ops_cases.dart';
import 'package:bidvibe/screens/bidder/auction_bid_panel.dart';
import 'package:bidvibe/screens/bidder/bidder_home.dart';
import 'package:bidvibe/screens/bidder/bidder_notifications.dart';
import 'package:bidvibe/screens/bidder/bidder_wallet.dart';
import 'package:bidvibe/screens/orders/order_detail_screen.dart';
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
  'BIDDER_A': ('bidder', String.fromEnvironment('E2E_BIDDER_A_EMAIL'), String.fromEnvironment('E2E_BIDDER_A_PASSWORD')),
  'BIDDER_B': ('bidder', String.fromEnvironment('E2E_BIDDER_B_EMAIL'), String.fromEnvironment('E2E_BIDDER_B_PASSWORD')),
  'BUYER': ('bidder', String.fromEnvironment('E2E_ANDROID_BUYER_EMAIL'), String.fromEnvironment('E2E_ANDROID_BUYER_PASSWORD')),
  'COMPETITOR': ('bidder', String.fromEnvironment('E2E_ANDROID_COMPETITOR_EMAIL'), String.fromEnvironment('E2E_ANDROID_COMPETITOR_PASSWORD')),
  'SELLER': ('seller', String.fromEnvironment('E2E_SELLER_EMAIL'), String.fromEnvironment('E2E_SELLER_PASSWORD')),
  'APPRAISER': ('appraiser', String.fromEnvironment('E2E_APPRAISER_EMAIL'), String.fromEnvironment('E2E_APPRAISER_PASSWORD')),
  'WAREHOUSE': ('warehouse', String.fromEnvironment('E2E_WAREHOUSE_EMAIL'), String.fromEnvironment('E2E_WAREHOUSE_PASSWORD')),
  'ADMIN': ('admin', String.fromEnvironment('E2E_ADMIN_EMAIL'), String.fromEnvironment('E2E_ADMIN_PASSWORD')),
};
final _s = <String, dynamic>{};

// RootShell remains mounted under detail routes. Include that offstage root
// when obtaining the real authenticated store; UI finders stay visible-only.
RemoteAppStore _store(WidgetTester t) => t.element(find.byType(RootShell,skipOffstage:false)).read<AppStore>() as RemoteAppStore;
ApiClient _api(WidgetTester t) => _store(t).api;
Finder _text(String value) => find.text(value);

Future<void> _wait(WidgetTester t, bool Function() ready, String reason, {int seconds = 60}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (!ready() && DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 200));
  }
  expect(ready(), isTrue, reason: reason);
}

Future<void> _reveal(WidgetTester t, Finder target) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pump(const Duration(milliseconds: 250));
  final scrolls = find.byType(Scrollable);
  if(target.evaluate().isEmpty&&scrolls.evaluate().isEmpty) {
    await _wait(t,()=>target.evaluate().isNotEmpty||scrolls.evaluate().isNotEmpty,'route content loaded before finding target');
  }
  if (target.evaluate().isEmpty && scrolls.evaluate().isNotEmpty) {
    // Lists lazily build their children on Android. Search only the visible
    // route; IndexedStack's offstage role tabs are excluded by the finder.
    try {
      await t.scrollUntilVisible(target, 280, scrollable: scrolls.first, maxScrolls: 65);
    } on StateError {
      // The target may be above the viewport after another action scrolled
      // down. Lazy lists remove those elements until we scroll back up.
      await t.scrollUntilVisible(target, -280, scrollable: scrolls.first, maxScrolls: 65);
    }
  }
  expect(target, findsOneWidget);
  await t.ensureVisible(target);
  await t.pump(const Duration(milliseconds: 200));
}

Future<void> _tap(WidgetTester t, Finder target) async {
  await _reveal(t, target);
  await _wait(t,()=>target.hitTestable().evaluate().length==1,'target is unobscured and tappable');
  await t.tap(target);
  await t.pump(const Duration(milliseconds: 250));
}

Future<void> _nav(WidgetTester t, String label) async {
  final destination = find.descendant(of: find.byType(NavigationBar), matching: find.text(label));
  await _tap(t, destination);
}

Finder _field(String label) => find.byWidgetPredicate((w) =>
  w is TextField && (w.decoration?.labelText ?? '').startsWith(label));

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

Future<void> _boot(WidgetTester t) async {
  expect(_allow, isTrue, reason: 'Use the Android runner with explicit business opt-in.');
  expect(_url, 'https://bidvibe-be.onrender.com');
  expect(_prefix.startsWith('E2E_ANDROID_'), isTrue);
  await ApiClient.loadConfig();
  await t.pumpWidget(const BidVibeApp());
  await _wait(t, () => find.byType(AuthLoginScreen).evaluate().isNotEmpty || find.byTooltip('Đăng xuất').evaluate().isNotEmpty, 'initial application session');
  if (find.byTooltip('Đăng xuất').evaluate().isNotEmpty) {
    await t.tap(find.byTooltip('Đăng xuất'));
    await _wait(t, () => find.byType(AuthLoginScreen).evaluate().isNotEmpty, 'clear previous session');
  }
}

Future<void> _login(WidgetTester t, String alias) async {
  final a = _accounts[alias]!;
  expect(a.$2.isNotEmpty && a.$3.isNotEmpty, isTrue, reason: 'Missing configured account $alias');
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
  await _wait(t, () => find.byTooltip('Đăng xuất').evaluate().isNotEmpty, 'sign in $alias');
  expect(_store(t).currentUser?.email.toLowerCase() == a.$2.toLowerCase(), isTrue, reason: 'Authenticated identity mismatch');
  expect(_store(t).currentUser?.role, a.$1);
}

Future<ApiClient> _actor(String alias) async {
  final a = _accounts[alias]!;
  final api = ApiClient();
  try {
    final data = await api.request('/api/auth/${['bidder', 'seller'].contains(a.$1) ? '' : 'ops/'}login', body: {'email': a.$2, 'password': a.$3});
    api.token = '${data['token']}';
    return api;
  } catch (_) {
    api.close();
    rethrow;
  }
}

Future<Map<String, dynamic>> _host(String endpoint, Map<String, dynamic> data) async {
  final response = await http.post(Uri.parse('$_control$endpoint'), headers: {'Content-Type':'application/json','x-control-key':_key}, body: jsonEncode(data)).timeout(const Duration(seconds: 35));
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  expect(response.statusCode, 200, reason: 'Local control $endpoint: ${body['error'] ?? ''}');
  return body;
}

Future<void> _record(String id, String status, Map<String, dynamic> evidence) async {
  final event = {'id':id,'status':status,'evidence':evidence};
  debugPrint('ANDROID_E2E_EVENT ${jsonEncode(event)}');
  await _host('/checkpoint', event);
}

void _scenario(String id, String description, Future<void> Function(WidgetTester) body, {List<String> requires = const []}) {
  testWidgets('$id: $description', (t) async {
    final missing = requires.where((key) => _s[key] == null || _s[key] == false).toList();
    if (missing.isNotEmpty) {
      final reason = 'BLOCKED: missing completed prerequisites ${missing.join(', ')}';
      markTestSkipped(reason);
      await _record(id, 'SKIP', {'reason':reason});
      return;
    }
    final watch = Stopwatch()..start();
    try {
      await _boot(t);
      await body(t);
      final error = t.takeException();
      expect(error == null, isTrue, reason: 'Flutter framework exception; inspect execution log');
      await _record(id, 'PASS', {'description':description,'elapsedMs':watch.elapsedMilliseconds,..._publicState()});
    } on _SkipCase catch (skip) {
      markTestSkipped(skip.reason);
      await _record(id, 'SKIP', {'reason':skip.reason});
    } catch (error) {
      try {
        await _record(id, 'FAIL', {'description':description,'elapsedMs':watch.elapsedMilliseconds,'error':error.toString(),..._publicState()});
      } catch(reportError) {
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
  for (final key in ['listingId','auctionId','orderId','adminAuctionId','adminOrderId','disputeId','rtAuctionId','rtOrderId','rtDisputeId'])
    if (_s[key] != null) key:_s[key],
};

Future<void> _openAuction(WidgetTester t, String title, String id) async {
  await _nav(t, 'Khám phá');
  final field = find.descendant(of: find.byType(BidderHomeScreen), matching: find.byType(TextField)).first;
  await _enter(t, field, title);
  await _tap(t, find.byTooltip('Tìm kiếm'));
  final marker = find.textContaining('Mã phiên $id');
  await _wait(t, () => marker.evaluate().isNotEmpty, 'filtered auction $id');
  final card = find.ancestor(of: marker, matching: find.byType(Card));
  expect(card, findsOneWidget);
  await _tap(t, find.descendant(of: card, matching: find.text('Xem chi tiết phiên')));
  await _wait(t, () => find.text('Phiên #$id').evaluate().isNotEmpty && find.text('Thông tin sản phẩm').evaluate().isNotEmpty, 'auction detail $id');
}

Future<void> _topup(WidgetTester t, int amount) async {
  final api = _api(t);
  final before = await api.request('/api/wallet');
  await _nav(t, 'Ví');
  final field = find.descendant(of: find.byType(BidderWalletScreen), matching: find.byType(TextFormField));
  await _wait(t, () => field.evaluate().isNotEmpty && t.widget<TextFormField>(field).enabled == true, 'wallet editable');
  await _enter(t, field, '$amount');
  await _tap(t, find.widgetWithText(FilledButton, 'Nạp tiền'));
  await _tap(t, find.widgetWithText(FilledButton, 'Xác nhận'));
  await _wait(t, () => t.widget<TextFormField>(field).controller!.text.isEmpty, 'UI top-up accepted');
  final after = await api.request('/api/wallet');
  expect(after['balance'], (before['balance'] as num) + amount);
}

Future<void> _join(WidgetTester t, String id) async {
  final button = find.widgetWithText(FilledButton, 'Đặt cọc tham gia');
  await _reveal(t, button);
  await _wait(t, () => button.evaluate().isNotEmpty && t.widget<FilledButton>(button).onPressed != null, 'join enabled');
  await _tap(t, button);
  await _tap(t, find.widgetWithText(FilledButton, 'Xác nhận đặt cọc'));
  await _wait(t, () => find.text('Bạn đã đặt cọc tham gia phiên này. Không cần đặt cọc lại.').evaluate().isNotEmpty, 'UI deposit confirmed');
  expect((await _api(t).request('/api/auctions/$id'))['joined'], true);
}

Future<void> _bid(WidgetTester t, String id) async {
  final panel = find.byType(AuctionBidPanel);
  final minimum = find.widgetWithText(TextButton, 'Dùng giá tối thiểu');
  await _reveal(t, minimum);
  await _wait(t, () => minimum.evaluate().isNotEmpty && t.widget<TextButton>(minimum).onPressed != null, 'bid enabled / realtime connected');
  await _tap(t, minimum);
  await _tap(t, find.descendant(of: panel, matching: find.widgetWithText(FilledButton, 'Đặt giá')));
  await _tap(t, find.widgetWithText(FilledButton, 'Xác nhận đặt giá'));
  await _wait(t, () => t.widget<AuctionBidPanel>(panel).controller.data?['leading'] == true, 'UI winning bid accepted');
  expect((await _api(t).request('/api/auctions/$id'))['leading'], true);
}

Future<void> _end(WidgetTester t, ApiClient api, String title, String id) async {
  await _host('/register', {'auctionId':id,'sellerId':_s['sellerId'],'title':title,'token':api.token});
  await _host('/end-soon', {'auctionId':id});
  final end = DateTime.now().add(const Duration(seconds: 45));
  while (DateTime.now().isBefore(end)) {
    await _host('/close-expired', {'auctionId':id});
    if ((await api.request('/api/auctions/$id'))['status'] == 'ended') return;
    await t.pump(const Duration(seconds: 1));
  }
  fail('Fixture $id did not end');
}

Future<Map<String,dynamic>> _readUntil(WidgetTester t, ApiClient api, String endpoint, bool Function(Map<String,dynamic>) ready) async {
  return _poll(t,()=>api.request(endpoint),ready,endpoint);
}

Future<Map<String,dynamic>> _poll(WidgetTester t, Future<Map<String,dynamic>> Function() read, bool Function(Map<String,dynamic>) ready, String description) async {
  final deadline=DateTime.now().add(const Duration(seconds:60));
  while(DateTime.now().isBefore(deadline)) {
    final data=await read();
    if(ready(data))return data;
    await t.pump(const Duration(milliseconds:300));
  }
  fail('Expected committed state not observed: $description');
}

Future<void> _openOrder(WidgetTester t, String title, String id) async {
  await _nav(t, 'Hồ sơ');
  final target = find.text(title);
  await _wait(t, () => target.evaluate().isNotEmpty, 'profile order list loads');
  await _tap(t, target);
  await _wait(t, () => find.text('Đơn hàng #$id').evaluate().isNotEmpty, 'order detail $id');
}

Future<void> _createApiFixture(WidgetTester t, String kind) async {
  final seller = await _actor('SELLER');
  final appraiser = await _actor('APPRAISER');
  try {
    final title = '${_prefix}_$kind';
    final draft = await seller.request('/api/listings', body: {'title':title,'categoryCode':'shoes','startingPrice':10000,'durationHours':1,'description':'Android E2E setup only','condition':'Test fixture'});
    final id = '${draft['id']}';
    await seller.request('/api/listings/$id/photos', body: {'url':_s['photoUrl']});
    await seller.request('/api/listings/$id/submit', method:'POST');
    final approved = await appraiser.request('/api/appraisals/$id/decision', body: {'decision':'approve','reason':'Android E2E fixture'});
    _s['${kind}Title'] = title;
    _s['${kind}AuctionId'] = '${approved['auctionId']}';
  } finally {seller.close();appraiser.close();}
}

Future<void> _preparePaid(WidgetTester t, String kind) async {
  final buyer = await _actor('BUYER');
  try {
    final id = _s['${kind}AuctionId'] as String;
    final detail = await buyer.request('/api/auctions/$id');
    expect(detail['status'], 'active');
    final wallet=await buyer.request('/api/wallet');
    if((wallet['available'] as num)<(detail['depositRequired'] as num)) {
      await buyer.request('/api/wallet/topup',body:{'amount':10000});
    }
    final addresses=(await buyer.request('/api/addresses'))['addresses'] as List;
    final candidates=[_s['addressId'],_s['setupAddressId']].whereType<String>().toList();
    final owned=addresses.where((a)=>candidates.contains('${a['id']}')).toList();
    final address=owned.isNotEmpty?owned.first:await buyer.request('/api/addresses',body:{'recipientName':'E2E Android API Setup','phone':'0900000000','city':'Ho Chi Minh','addressLine':'E2E test only - 1 Setup Street'});
    _s['setupAddressId']='${address['id']}';
    await buyer.request('/api/auctions/$id/join', method:'POST');
    await buyer.request('/api/bids', body: {'auctionId':id,'amount':detail['minNextBid']});
    await _end(t,buyer,_s['${kind}Title'] as String,id);
    final orders = await buyer.request('/api/orders/mine');
    final order = (orders['orders'] as List).singleWhere((o) => '${o['auctionId']}' == id);
    _s['${kind}OrderId'] = '${order['id']}';
    await buyer.request('/api/orders/${order['id']}/shipping-address', body: {'addressId':_s['setupAddressId']});
    await buyer.request('/api/orders/${order['id']}/pay', body: {'method':'qr'});
    expect((await buyer.request('/api/orders/${order['id']}'))['paymentStatus'], 'paid');
  } finally {buyer.close();}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final alias in ['BIDDER_A','BIDDER_B','SELLER','APPRAISER','WAREHOUSE','ADMIN']) {
    _scenario('A-AUTH-$alias', 'UI login / identity / logout', (t) async {
      await _login(t,alias);
      await _tap(t,find.byTooltip('Đăng xuất'));
      await _wait(t,()=>find.byType(AuthLoginScreen).evaluate().isNotEmpty,'logout $alias');
    });
  }

  for(final registration in [('COMPETITOR','A-REG-A','competitorReady'),('BUYER','A-REG-01','buyerReady')]) {
  _scenario(registration.$2,'Register a fresh bidder through Android UI',(t) async {
    await _tap(t,_text('Chưa có tài khoản? Đăng ký'));
    await _enter(t,_field('Họ và tên'),'E2E Android Buyer');
    await _enter(t,_field('Email'),_accounts[registration.$1]!.$2);
    await _enter(t,_field('Mật khẩu'),_accounts[registration.$1]!.$3);
    await _enter(t,_field('Nhập lại mật khẩu'),_accounts[registration.$1]!.$3);
    await _tap(t,find.widgetWithText(FilledButton,'Tạo tài khoản'));
    await _wait(t,()=>find.byTooltip('Đăng xuất').evaluate().isNotEmpty,'registration completes');
    expect(_store(t).currentUser?.email == _accounts[registration.$1]!.$2,isTrue);
    _s[registration.$3]=true;
  });
  }

  _scenario('A-LIST-01','Seller submits a listing; selected image bytes are injected, upload is real',(t) async {
    await _login(t,'SELLER');
    _s['sellerId']=_store(t).currentUser!.id;
    _s['mainTitle']='${_prefix}_Main';
    await _nav(t,'Tạo mới');
    final scope=find.byType(SellerCreateScreen);
    final recorder=ui.PictureRecorder();final canvas=Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0,0,32,32),Paint()..color=Colors.blue);
    final image=await recorder.endRecording().toImage(32,32);
    final bytes=(await image.toByteData(format:ui.ImageByteFormat.png))!.buffer.asUint8List();image.dispose();
    final picker=find.descendant(of:scope,matching:find.byType(PhotoPicker));
    await _reveal(t,picker);
    t.widget<PhotoPicker>(picker).onChanged([PickedImage(bytes,'android-e2e.png')]);await t.pump();
    await _enter(t,find.byWidgetPredicate((w)=>w is TextField&&w.decoration?.hintText=='Ví dụ: Giày da thủ công, size 41'),_s['mainTitle'] as String);
    await _enter(t,find.byWidgetPredicate((w)=>w is TextField&&w.decoration?.hintText=='Nhập giá khởi điểm'),'10000');
    await _tap(t,_text('Gửi để thẩm định'));
    Map<String,dynamic>? row;
    for(var n=0;n<45;n++) {
      await t.pump(const Duration(seconds:1));
      final data=await _api(t).request('/api/listings/mine?limit=100');
      final matches=(data['listings'] as List).where((o)=>o['title']==_s['mainTitle']).toList();
      if(matches.isNotEmpty&&matches.single['status']=='pending_appraisal'){row=Map<String,dynamic>.from(matches.single);break;}
    }
    expect(row,isNotNull);_s['listingId']='${row!['id']}';_s['photoUrl']=row['photos'][0]['url'];
  });

  _scenario('A-APP-01','Appraiser approves the exact listing through UI',(t) async {
    await _login(t,'APPRAISER');await _tap(t,_text(_s['mainTitle'] as String));
    await _tap(t,_text('Duyệt và mở phiên'));await _tap(t,find.widgetWithText(FilledButton,'Duyệt'));
    await _wait(t,()=>find.text('Hàng chờ').evaluate().isNotEmpty,'return to queue');
    final rows=await _api(t).request('/api/auctions?status=live&q=${Uri.encodeQueryComponent(_s['mainTitle'] as String)}');
    final list=rows['auctions'] as List;expect(list.length,1);_s['auctionId']='${list.single['id']}';
  },requires:['listingId']);

  _scenario('A-BID-A','Bidder A tops up, joins and bids through UI',(t) async {
    await _login(t,'COMPETITOR');final w=await _api(t).request('/api/wallet');
    expect(w['joinBlockedUntil'],isNull);_s['aHeldBefore']=w['held'];
    await _topup(t,10000);await _openAuction(t,_s['mainTitle'] as String,_s['auctionId'] as String);
    await _join(t,_s['auctionId'] as String);await _bid(t,_s['auctionId'] as String);_s['bidA']=true;
  },requires:['auctionId','competitorReady']);

  _scenario('A-BID-B','Fresh buyer tops up, joins and outbids A through UI',(t) async {
    await _login(t,'BUYER');await _topup(t,500000);
    await _openAuction(t,_s['mainTitle'] as String,_s['auctionId'] as String);
    await _join(t,_s['auctionId'] as String);await _bid(t,_s['auctionId'] as String);_s['bidB']=true;
  },requires:['bidA','buyerReady']);

  _scenario('A-RT-BID','Android buyer receives an API actor bid live, then outbids through UI',(t) async {
    await _login(t,'BUYER');await _openAuction(t,_s['mainTitle'] as String,_s['auctionId'] as String);
    final panel=find.byType(AuctionBidPanel);
    await _reveal(t,panel);
    await _wait(t,()=>panel.evaluate().isNotEmpty&&t.widget<AuctionBidPanel>(panel).controller.connected,'auction Socket.IO connected');
    final actor=await _actor('COMPETITOR');
    try {
      final d=await actor.request('/api/auctions/${_s['auctionId']}');
      await actor.request('/api/bids',body:{'auctionId':_s['auctionId'],'amount':d['minNextBid']});
      await _wait(t,()=>panel.evaluate().isNotEmpty&&t.widget<AuctionBidPanel>(panel).controller.data?['currentPrice']==d['minNextBid']&&t.widget<AuctionBidPanel>(panel).controller.data?['leading']==false,'external bid appears without manual refresh');
    } finally {actor.close();}
    await _bid(t,_s['auctionId'] as String);_s['realtimeBid']=true;
  },requires:['bidB']);

  _scenario('A-WIN-01','Expire only the new fixture; verify winner/order and loser deposit refund',(t) async {
    await _login(t,'BUYER');await _openAuction(t,_s['mainTitle'] as String,_s['auctionId'] as String);
    await _end(t,_api(t),_s['mainTitle'] as String,_s['auctionId'] as String);
    await _reveal(t,find.text('Bạn đã thắng phiên này'));
    final rows=await _api(t).request('/api/orders/mine');
    final order=(rows['orders'] as List).singleWhere((o)=>'${o['auctionId']}'==_s['auctionId']);_s['orderId']='${order['id']}';
    final a=await _actor('COMPETITOR');try{expect((await a.request('/api/wallet'))['held'],_s['aHeldBefore']);}finally{a.close();}
  },requires:['bidB']);

  _scenario('A-PAY-01','Buyer creates/selects address and pays from wallet through UI',(t) async {
    await _login(t,'BUYER');await _openOrder(t,_s['mainTitle'] as String,_s['orderId'] as String);
    await _tap(t,find.textContaining('Chưa có địa chỉ nhận hàng'));
    await _tap(t,_text('Thêm địa chỉ mới'));
    for(final value in [('Họ và tên người nhận','E2E Android Buyer'),('Số điện thoại','0900000000'),('Tỉnh / thành phố','Ho Chi Minh'),('Địa chỉ cụ thể','E2E test only - 1 Android Street')]){await _enter(t,_field(value.$1),value.$2);}
    await _tap(t,_text('Lưu địa chỉ'));
    await _wait(t,()=>find.byTooltip('Chọn địa chỉ của E2E Android Buyer').evaluate().isNotEmpty,'address saved');
    await _tap(t,find.byTooltip('Chọn địa chỉ của E2E Android Buyer'));
    await _tap(t,_text('Dùng địa chỉ này'));
    await _wait(t,()=>find.byType(OrderDetailScreen).evaluate().isNotEmpty,'return to order');
    await _readUntil(t,_api(t),'/api/orders/${_s['orderId']}',(o)=>o['shippingAddress']!=null);
    final walletTile=find.ancestor(of:find.text('Ví BidVibe'),matching:find.byType(InkWell));
    await _reveal(t,walletTile);
    await _wait(t,()=>walletTile.evaluate().isNotEmpty&&t.widget<InkWell>(walletTile).onTap!=null,'wallet method enabled after address save');
    await _tap(t,walletTile);
    expect(find.descendant(of:walletTile,matching:find.byIcon(Icons.radio_button_checked)),findsOneWidget);
    final before=await _api(t).request('/api/wallet');final order=await _api(t).request('/api/orders/${_s['orderId']}');
    _s['addressId']='${order['shippingAddress']['id']}';
    await _tap(t,find.byWidgetPredicate((w)=>w is BigActionButton&&w.label.startsWith('Thanh toán ')));
    await _tap(t,find.widgetWithText(TextButton,'Thanh toán'));
    await _wait(t,()=>find.textContaining('Thanh toán thành công').evaluate().isNotEmpty,'wallet payment UI feedback');
    final paid=await _api(t).request('/api/orders/${_s['orderId']}');expect(paid['paymentStatus'],'paid');
    final after=await _api(t).request('/api/wallet');expect(after['balance'],(before['balance'] as num)-(order['amountToPay'] as num));
    _s['paid']=true;
  },requires:['orderId']);

  _scenario('A-SHIP-01','Seller sends only the test order to warehouse through UI',(t) async {
    await _login(t,'SELLER');await _nav(t,'Gửi kho');
    final title=find.text(_s['mainTitle'] as String);await _reveal(t,title);
    final card=find.ancestor(of:title,matching:find.byWidgetPredicate((w)=>w.runtimeType.toString()=='_ShipmentCard'));
    expect(card,findsOneWidget);await _tap(t,find.descendant(of:card,matching:find.text('Tôi đã gửi hàng đến kho')));
    await _readUntil(t,_api(t),'/api/orders/selling?limit=100',(data)=>(data['orders'] as List).any((o)=>'${o['id']}'==_s['orderId']&&o['stage']=='in_transit_to_warehouse'));_s['shipped']=true;
  },requires:['paid']);

  final warehouseSteps=[('receive','Xác nhận kho đã nhận hàng','inspecting'),('inspect','Lưu kết quả kiểm định','inspected'),('pack','Xác nhận đóng gói','packed'),('ship','Gửi cho đơn vị vận chuyển','shipped'),('deliver','Xác nhận đã giao','delivered')];
  for(var i=0;i<warehouseSteps.length;i++) {
    final step=warehouseSteps[i];final previous=i==0?'shipped':'wh-${warehouseSteps[i-1].$1}';
    _scenario('A-WH-${i+1}','Warehouse ${step.$1} through UI',(t) async {
      await _login(t,'WAREHOUSE');await _tap(t,_text(_s['mainTitle'] as String));
      await _wait(t,()=>find.text('Chi tiết đơn kho').evaluate().isNotEmpty,'warehouse detail');
      if(step.$1=='inspect'){await _tap(t,_text('Khớp mô tả'));}
      await _tap(t,_text(step.$2));
      if(step.$1=='ship'){
        await _enter(t,_field('Đơn vị vận chuyển'),'E2E simulated carrier');
        await _enter(t,_field('Mã vận đơn'),'ANDROID-${_s['orderId']}');await _tap(t,_text('Xác nhận gửi'));
      }
      final order=await _poll(t,()=>OpsRepository(_api(t)).warehouseOrder(_s['orderId'] as String),(o)=>o['stage']==step.$3,'warehouse stage ${step.$3}');
      expect(order['stage'],step.$3);
      expect(find.text('Không cập nhật được đơn hàng.'),findsNothing);_s['wh-${step.$1}']=true;
    },requires:[previous]);
  }

  _scenario('A-RECEIPT','Buyer confirms delivery; verify payout released',(t) async {
    await _login(t,'BUYER');await _openOrder(t,_s['mainTitle'] as String,_s['orderId'] as String);
    await _tap(t,_text('Đã nhận hàng'));await _tap(t,find.widgetWithText(TextButton,'Đã nhận hàng'));
    await _readUntil(t,_api(t),'/api/orders/${_s['orderId']}',(o)=>o['payoutStatus']=='released');_s['completed']=true;
  },requires:['wh-deliver']);

  _scenario('A-ADMIN-READ','Admin opens all five operational tabs',(t) async {
    await _login(t,'ADMIN');for(final tab in ['Tổng quan','Cờ','Tranh chấp','Báo cáo','Tài khoản']){await _nav(t,tab);await t.pump(const Duration(milliseconds:500));}
    expect((await _api(t).request('/api/admin/accounts'))['accounts'],isA<List>());
  });

  _scenario('A-SETUP-ADMIN','API prepares a separate moderation fixture; not UI coverage',(t) async {
    await _createApiFixture(t,'admin');
  },requires:['photoUrl']);

  _scenario('A-REPORT','Bidder reports the exact admin fixture through UI',(t) async {
    await _login(t,'BIDDER_A');await _openAuction(t,_s['adminTitle'] as String,_s['adminAuctionId'] as String);
    await _tap(t,find.byTooltip('Báo cáo phiên'));await _enter(t,_field('Lý do báo cáo'),'Android E2E report');
    await _tap(t,_text('Gửi báo cáo'));await _tap(t,_text('Xác nhận gửi'));
    await _wait(t,()=>find.textContaining('Báo cáo đã được ghi nhận').evaluate().isNotEmpty,'report accepted');_s['reported']=true;
  },requires:['adminAuctionId']);

  for(final action in [('pause','Tạm dừng phiên'),('verify','Yêu cầu xác minh'),('safe','Đánh dấu an toàn')]) {
    _scenario('A-MOD-${action.$1}','Admin ${action.$1} exact report through UI',(t) async {
      await _login(t,'ADMIN');await _nav(t,'Cờ');await _tap(t,_text(_s['adminTitle'] as String));await _tap(t,_text(action.$2));
      await t.pump(const Duration(seconds:1));final flags=await _api(t).request('/api/admin/flags?limit=100');
      final flag=(flags['flags'] as List).singleWhere((f)=>'${f['auctionId']??f['auction']?['id']}'==_s['adminAuctionId']);
      expect(flag['status'],action.$1=='pause'?'paused':action.$1=='verify'?'verify':'safe');_s['mod-${action.$1}']=true;
    },requires:[action.$1=='pause'?'reported':action.$1=='verify'?'mod-pause':'mod-verify']);
  }

  _scenario('A-BLOCKED','Restricted bidder sees JOIN_BLOCKED reason through UI',(t) async {
    await _login(t,'BIDDER_B');final wallet=await _api(t).request('/api/wallet');
    final until=DateTime.tryParse('${wallet['joinBlockedUntil']}');
    if(until==null||!until.isAfter(DateTime.now())){throw const _SkipCase('No active JOIN_BLOCKED restriction; no violation created to force this scenario.');}
    await _openAuction(t,_s['adminTitle'] as String,_s['adminAuctionId'] as String);
    final join=find.widgetWithText(FilledButton,'Đặt cọc tham gia');
    await _reveal(t,join);
    await _wait(t,()=>join.evaluate().isNotEmpty&&t.widget<FilledButton>(join).onPressed!=null,'restriction-check join button ready');
    await _tap(t,join);await _tap(t,_text('Xác nhận đặt cọc'));
    await _wait(t,()=>find.textContaining('Bạn tạm thời không được tham gia phiên mới').evaluate().isNotEmpty,'business restriction shown');
    expect(find.textContaining('Chưa xác định được kết quả đặt cọc'),findsNothing);
  },requires:['mod-safe']);

  _scenario('A-SETUP-DISPUTE','API closes and QR-pays admin fixture; not UI payment coverage',(t) async {
    await _preparePaid(t,'admin');
  },requires:['mod-safe','buyerReady']);

  _scenario('A-DISPUTE','Buyer opens a dispute through Android UI',(t) async {
    await _login(t,'BUYER');await _openOrder(t,_s['adminTitle'] as String,_s['adminOrderId'] as String);
    await _tap(t,_text('Hàng có vấn đề? Mở tranh chấp'));await _tap(t,_text('Hàng không đúng mô tả'));
    await _enter(t,find.byWidgetPredicate((w)=>w is TextField&&w.decoration?.hintText=='Mô tả cụ thể vấn đề bạn gặp phải…'),'Android E2E test item does not match description.');
    await _tap(t,_text('Gửi tranh chấp'));
    final data=await _readUntil(t,_api(t),'/api/disputes/mine',(d)=>(d['disputes'] as List).any((o)=>'${o['orderId']}'==_s['adminOrderId']));final list=data['disputes'] as List;
    final dispute=list.singleWhere((d)=>'${d['orderId']}'==_s['adminOrderId']);_s['disputeId']='${dispute['id']}';
    expect((await _api(t).request('/api/orders/${_s['adminOrderId']}'))['payoutStatus'],'disputed');
  },requires:['adminOrderId']);

  _scenario('A-REFUND','Admin refunds exact dispute through Android UI',(t) async {
    final buyer=await _actor('BUYER');final before=await buyer.request('/api/wallet');
    try {
      await _login(t,'ADMIN');await _nav(t,'Tranh chấp');
      // The row's title and subtitle may both contain the item title. Select
      // the actionable ListTile, then verify the dispute/order identity.
      final disputeRow=find.descendant(of:find.byType(AdminOpsDisputesScreen),matching:find.byWidgetPredicate((w)=>w is ListTile&&w.title is Text&&(w.title as Text).data==_s['adminTitle']));
      await _tap(t,disputeRow);
      await _wait(t,()=>find.textContaining('Tranh chấp #${_s['disputeId']} · Đơn #${_s['adminOrderId']} ·').evaluate().isNotEmpty,'exact dispute and order detail');
      await _tap(t,_text('Hoàn tiền người mua'));await _tap(t,find.widgetWithText(FilledButton,'Xác nhận'));
      final data=await _readUntil(t,_api(t),'/api/admin/disputes',(d)=>(d['disputes'] as List).any((o)=>'${o['id']}'==_s['disputeId']&&o['status']=='resolved'));
      final d=(data['disputes'] as List).singleWhere((d)=>'${d['id']}'==_s['disputeId']);expect(d['status'],'resolved');
      expect((await buyer.request('/api/wallet'))['balance'],greaterThan(before['balance'] as num));_s['refunded']=true;
    }finally{buyer.close();}
  },requires:['disputeId']);

  _scenario('A-NOTIFY','Buyer loads persisted shipping notifications and opens the correct order',(t) async {
    await _login(t,'BUYER');await _nav(t,'Thông báo');
    final screen=find.byType(BidderNotificationsScreen);await _wait(t,()=>screen.evaluate().isNotEmpty,'notification screen');
    final controller=t.widget<BidderNotificationsScreen>(screen).controller;
    await _wait(t,()=>!controller.loading,'notifications loaded');
    final notes=controller.items.where((n)=>'${n.data?['orderId']}'==_s['orderId']).toList();expect(notes,isNotEmpty);
    final note=notes.firstWhere((n)=>n.type=='order');await _tap(t,_text(note.title));
    await _wait(t,()=>find.text('Đơn hàng #${_s['orderId']}').evaluate().isNotEmpty,'notification opens exact order');
  },requires:['completed']);

  _scenario('A-RT-REFUND','Logged-in Android buyer receives refund event from external Admin API actor',(t) async {
    await _createApiFixture(t,'rt');await _preparePaid(t,'rt');
    final buyer=await _actor('BUYER');
    try {
      final d=await buyer.request('/api/disputes',body:{'orderId':_s['rtOrderId'],'source':'bidder','title':'Android E2E realtime refund','reason':'Hàng không đúng mô tả','detail':'API setup for realtime observation'});
      _s['rtDisputeId']='${d['id']}';
    } finally {buyer.close();}
    await _login(t,'BUYER');await _nav(t,'Thông báo');
    final screen=find.byType(BidderNotificationsScreen);
    await _wait(t,()=>screen.evaluate().isNotEmpty,'notification screen mounted');
    final controller=t.widget<BidderNotificationsScreen>(screen).controller;
    await _wait(t,()=>controller.connected,'notification Socket.IO connected');
    final events=<Map<String,dynamic>>[];
    final subscription=controller.events!.stream.listen((e){if(e.type=='notification:new')events.add(e.data);});
    final before=await _api(t).request('/api/wallet');final admin=await _actor('ADMIN');
    try {
      await admin.request('/api/admin/disputes/${_s['rtDisputeId']}/resolve',body:{'resolution':'refund','note':'Android E2E realtime actor'});
      await _wait(t,()=>events.any((n)=>n['type']=='refund'&&'${n['data']?['disputeId']}'==_s['rtDisputeId']),'real refund event without re-login or refresh');
      await _wait(t,()=>controller.items.any((n)=>n.type=='refund'&&'${n.data?['disputeId']}'==_s['rtDisputeId']),'refund appears in notification controller');
      expect((await _api(t).request('/api/wallet'))['balance'],greaterThan(before['balance'] as num));
    } finally {await subscription.cancel();admin.close();}
  },requires:['photoUrl','buyerReady']);
}
