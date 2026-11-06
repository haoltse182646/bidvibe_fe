import 'dart:convert';
import 'dart:ui' as ui;

import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/core/picked_image.dart';
import 'package:bidvibe/core/remote_app_store.dart';

import 'package:bidvibe/main.dart';
import 'package:bidvibe/screens/auth/auth_login.dart';

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

Future<Map<String, dynamic>> _host(String endpoint, Map<String, dynamic> data) async {
  final response = await http.post(Uri.parse('$_control$endpoint'), headers: {'Content-Type':'application/json','x-control-key':_key}, body: jsonEncode(data)).timeout(const Duration(seconds: 90));
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
    await _record(id, 'RUNNING', {'description':description});
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  _scenario('X-REGISTER','Android registers the buyer used throughout the connected journey',(t) async {
    await _tap(t,_text('Chưa có tài khoản? Đăng ký'));
    await _enter(t,_field('Họ và tên'),'E2E Android Buyer');
    await _enter(t,_field('Email'),_accounts['BUYER']!.$2);
    await _enter(t,_field('Mật khẩu'),_accounts['BUYER']!.$3);
    await _enter(t,_field('Nhập lại mật khẩu'),_accounts['BUYER']!.$3);
    await _tap(t,find.widgetWithText(FilledButton,'Tạo tài khoản'));
    await _wait(t,()=>find.byTooltip('Đăng xuất').evaluate().isNotEmpty,'buyer registration');
    expect(_store(t).currentUser?.email==_accounts['BUYER']!.$2,isTrue);_s['buyerReady']=true;
  });

  _scenario('X-LISTING','Seller submits the connected listing through Android UI',(t) async {
    await _login(t,'SELLER');_s['sellerId']=_store(t).currentUser!.id;_s['mainTitle']='${_prefix}_Connected';
    await _nav(t,'Tạo mới');final scope=find.byType(SellerCreateScreen);
    final recorder=ui.PictureRecorder();final canvas=Canvas(recorder);canvas.drawRect(const Rect.fromLTWH(0,0,32,32),Paint()..color=Colors.blue);
    final image=await recorder.endRecording().toImage(32,32);final bytes=(await image.toByteData(format:ui.ImageByteFormat.png))!.buffer.asUint8List();image.dispose();
    final picker=find.descendant(of:scope,matching:find.byType(PhotoPicker));await _reveal(t,picker);
    t.widget<PhotoPicker>(picker).onChanged([PickedImage(bytes,'connected-e2e.png')]);await t.pump();
    await _enter(t,find.byWidgetPredicate((w)=>w is TextField&&w.decoration?.hintText=='Ví dụ: Giày da thủ công, size 41'),_s['mainTitle'] as String);
    await _enter(t,find.byWidgetPredicate((w)=>w is TextField&&w.decoration?.hintText=='Nhập giá khởi điểm'),'10000');await _tap(t,_text('Gửi để thẩm định'));
    final rows=await _readUntil(t,_api(t),'/api/listings/mine?limit=100',(d)=>(d['listings'] as List).any((r)=>r['title']==_s['mainTitle']&&r['status']=='pending_appraisal'));
    final row=(rows['listings'] as List).singleWhere((r)=>r['title']==_s['mainTitle']);_s['listingId']='${row['id']}';
  },requires:['buyerReady']);

  _scenario('X-APPRAISE','Appraiser approves the connected listing through Android UI',(t) async {
    await _login(t,'APPRAISER');await _tap(t,_text(_s['mainTitle'] as String));await _tap(t,_text('Duyệt và mở phiên'));await _tap(t,find.widgetWithText(FilledButton,'Duyệt'));
    await _wait(t,()=>find.text('Hàng chờ').evaluate().isNotEmpty,'appraiser returns to queue');
    final rows=await _api(t).request('/api/auctions?status=live&q=${Uri.encodeQueryComponent(_s['mainTitle'] as String)}');
    final list=rows['auctions'] as List;expect(list.length,1);_s['auctionId']='${list.single['id']}';
  },requires:['listingId']);

  _scenario('X-BID','Android buyer tops up, deposits and bids on the connected auction',(t) async {
    await _login(t,'BUYER');await _topup(t,500000);await _openAuction(t,_s['mainTitle'] as String,_s['auctionId'] as String);
    await _join(t,_s['auctionId'] as String);await _bid(t,_s['auctionId'] as String);_s['bidReady']=true;
  },requires:['auctionId','buyerReady']);

  _scenario('X-REPORT','Android report creates the flag subsequently handled on React Web',(t) async {
    await _login(t,'BUYER');await _openAuction(t,_s['mainTitle'] as String,_s['auctionId'] as String);
    await _tap(t,find.byTooltip('Báo cáo phiên'));await _enter(t,_field('Lý do báo cáo'),'Connected Android to React Admin E2E');
    await _tap(t,_text('Gửi báo cáo'));await _tap(t,_text('Xác nhận gửi'));
    await _wait(t,()=>find.textContaining('Báo cáo đã được ghi nhận').evaluate().isNotEmpty,'mobile report committed');
    await _host('/register',{'auctionId':_s['auctionId'],'sellerId':_s['sellerId'],'title':_s['mainTitle'],'token':_api(t).token});_s['reported']=true;
  },requires:['bidReady']);

  for(final action in [('pause',true,'X-PAUSE','Web Admin pauses the auction while Android receives the live blocked state'),('safe',false,'X-RESUME','Web Admin marks the flag safe while Android receives the live resumed state')]) {
    _scenario(action.$3,action.$4,(t) async {
      await _login(t,'BUYER');await _openAuction(t,_s['mainTitle'] as String,_s['auctionId'] as String);
      final panel=find.byType(AuctionBidPanel);await _reveal(t,panel);
      await _wait(t,()=>panel.evaluate().isNotEmpty&&t.widget<AuctionBidPanel>(panel).controller.connected,'live auction connected');
      await _host('/web-action',{'action':action.$1,'title':_s['mainTitle'],..._publicState()});
      await _wait(t,()=>panel.evaluate().isNotEmpty&&t.widget<AuctionBidPanel>(panel).controller.data?['paused']==action.$2,'Web action reflected through Socket.IO without manual refresh');
      expect((await _api(t).request('/api/auctions/${_s['auctionId']}'))['paused'],action.$2);
      await _reveal(t,find.widgetWithText(Chip,action.$2?'Tạm dừng':'Đang diễn ra'));
      _s[action.$1=='pause'?'pausedVerified':'resumedVerified']=true;
    },requires:[action.$1=='pause'?'reported':'pausedVerified']);
  }

  _scenario('X-WINNER','Controlled fixture expiry creates the exact winner order on Android',(t) async {
    await _login(t,'BUYER');await _openAuction(t,_s['mainTitle'] as String,_s['auctionId'] as String);
    await _end(t,_api(t),_s['mainTitle'] as String,_s['auctionId'] as String);await _reveal(t,find.text('Bạn đã thắng phiên này'));
    final rows=await _api(t).request('/api/orders/mine');final order=(rows['orders'] as List).singleWhere((o)=>'${o['auctionId']}'==_s['auctionId']);_s['orderId']='${order['id']}';
  },requires:['resumedVerified']);

  _scenario('X-PAYMENT','Android buyer creates an address and pays the connected order from the wallet',(t) async {
    await _login(t,'BUYER');await _openOrder(t,_s['mainTitle'] as String,_s['orderId'] as String);
    await _tap(t,find.textContaining('Chưa có địa chỉ nhận hàng'));await _tap(t,_text('Thêm địa chỉ mới'));
    for(final value in [('Họ và tên người nhận','E2E Android Buyer'),('Số điện thoại','0900000000'),('Tỉnh / thành phố','Ho Chi Minh'),('Địa chỉ cụ thể','E2E test only - 1 Connected Street')]){await _enter(t,_field(value.$1),value.$2);}
    await _tap(t,_text('Lưu địa chỉ'));await _wait(t,()=>find.byTooltip('Chọn địa chỉ của E2E Android Buyer').evaluate().isNotEmpty,'address saved');
    await _tap(t,find.byTooltip('Chọn địa chỉ của E2E Android Buyer'));await _tap(t,_text('Dùng địa chỉ này'));
    await _wait(t,()=>find.byType(OrderDetailScreen).evaluate().isNotEmpty,'return to order');await _readUntil(t,_api(t),'/api/orders/${_s['orderId']}',(o)=>o['shippingAddress']!=null);
    final walletTile=find.ancestor(of:find.text('Ví BidVibe'),matching:find.byType(InkWell));await _reveal(t,walletTile);
    await _wait(t,()=>walletTile.evaluate().isNotEmpty&&t.widget<InkWell>(walletTile).onTap!=null,'wallet enabled');await _tap(t,walletTile);
    final before=await _api(t).request('/api/wallet');final order=await _api(t).request('/api/orders/${_s['orderId']}');
    await _tap(t,find.byWidgetPredicate((w)=>w is BigActionButton&&w.label.startsWith('Thanh toán ')));await _tap(t,find.widgetWithText(TextButton,'Thanh toán'));
    await _wait(t,()=>find.textContaining('Thanh toán thành công').evaluate().isNotEmpty,'UI payment success');
    expect((await _api(t).request('/api/orders/${_s['orderId']}'))['paymentStatus'],'paid');expect((await _api(t).request('/api/wallet'))['balance'],(before['balance'] as num)-(order['amountToPay'] as num));_s['paid']=true;
  },requires:['orderId']);

  _scenario('X-DISPUTE','Android buyer opens the dispute subsequently resolved on React Web',(t) async {
    await _login(t,'BUYER');await _openOrder(t,_s['mainTitle'] as String,_s['orderId'] as String);
    await _tap(t,_text('Hàng có vấn đề? Mở tranh chấp'));await _tap(t,_text('Hàng không đúng mô tả'));
    await _enter(t,find.byWidgetPredicate((w)=>w is TextField&&w.decoration?.hintText=='Mô tả cụ thể vấn đề bạn gặp phải…'),'Connected E2E item does not match description');await _tap(t,_text('Gửi tranh chấp'));
    final data=await _readUntil(t,_api(t),'/api/disputes/mine',(d)=>(d['disputes'] as List).any((o)=>'${o['orderId']}'==_s['orderId']));
    final d=(data['disputes'] as List).singleWhere((d)=>'${d['orderId']}'==_s['orderId']);_s['disputeId']='${d['id']}';
  },requires:['paid']);

  _scenario('X-REFUND','React Admin refunds while Android receives the matching live notification and wallet credit',(t) async {
    await _login(t,'BUYER');await _nav(t,'Thông báo');final screen=find.byType(BidderNotificationsScreen);
    await _wait(t,()=>screen.evaluate().isNotEmpty,'notification screen');final controller=t.widget<BidderNotificationsScreen>(screen).controller;
    await _wait(t,()=>controller.connected,'notification Socket.IO connected');final events=<Map<String,dynamic>>[];
    final subscription=controller.events!.stream.listen((e){if(e.type=='notification:new')events.add(e.data);});
    try {
      final before=await _api(t).request('/api/wallet');await _host('/web-action',{'action':'refund','title':_s['mainTitle'],..._publicState()});
      await _wait(t,()=>events.any((n)=>n['type']=='refund'&&'${n['data']?['disputeId']}'==_s['disputeId']),'matching refund event without refresh or re-login');
      await _wait(t,()=>controller.items.any((n)=>n.type=='refund'&&'${n.data?['disputeId']}'==_s['disputeId']),'matching refund in Android notification controller');
      final after=await _api(t).request('/api/wallet');expect(after['balance'],greaterThan(before['balance'] as num));
    }finally{await subscription.cancel();}
  },requires:['disputeId']);
}
