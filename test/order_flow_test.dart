import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/features/orders/order_repository.dart';
import 'package:bidvibe/screens/orders/order_detail_screen.dart';
import 'package:bidvibe/screens/orders/orders_screen.dart';
import 'package:bidvibe/widgets/skeleton.dart';

http.Response ok(Map<String, dynamic> data) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response fail(String code, String message, int status) => http.Response(
  jsonEncode({
    'success': false,
    'error': {'code': code, 'message': message},
  }),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const address = {
  'id': '47',
  'recipientName': 'Nguyễn Minh Anh',
  'phone': '0903 112 233',
  'addressLine': '45 Võ Văn Tần',
  'ward': 'Phường 6',
  'district': 'Quận 3',
  'city': 'TP.HCM',
};

Map<String, dynamic> orderJson({
  String payment = 'awaiting_payment',
  Map<String, dynamic>? shippingAddress,
  Duration deadlineIn = const Duration(hours: 5),
}) => {
  'id': '120',
  'auctionId': '355',
  'title': 'Máy nghe nhạc cassette 1988',
  'finalPrice': 1200000,
  'fee': 60000,
  'shippingFee': 40000,
  'totalDue': 1300000,
  'depositApplied': 100000,
  'amountToPay': 1200000,
  'paymentStatus': payment,
  'paymentDeadline': DateTime.now()
      .add(deadlineIn)
      .toUtc()
      .toIso8601String(),
  'payoutStatus': 'pending',
  'seller': {'id': '18', 'storeName': 'Retro Camera HN'},
  'shippingAddress': shippingAddress,
};

Map<String, dynamic> trackingJson({
  required String stage,
  String payment = 'paid',
  String? shipment,
  String payout = 'pending',
}) => {
  'id': '120',
  'auctionId': '355',
  'title': 'Máy nghe nhạc cassette 1988',
  'finalPrice': 1200000,
  'paymentStatus': payment,
  'payoutStatus': payout,
  'stage': stage,
  'shippingAddress': address,
  'warehouse': {'orderCode': 'BV-101026-0120'},
  'shipment': shipment == null
      ? null
      : {'status': shipment, 'trackingCode': 'GHN1'},
  'events': <Object>[],
};

void main() {
  // Font của môi trường test rộng hơn thật nên nút dùng chung (widgets/common.dart,
  // của lead) báo tràn chữ. Chỉ bỏ qua lỗi tràn bắt nguồn từ file đó; tràn chữ ở
  // màn đơn hàng của ta vẫn làm test thất bại.
  void widgetTest(String name, Future<void> Function(WidgetTester t) body) {
    testWidgets(name, (t) async {
      final original = FlutterError.onError;
      FlutterError.onError = (d) {
        final text = d.toString();
        final sharedWidgetOnly = text.contains('overflowed') && text.contains('widgets/common.dart') && !text.contains('screens/orders/');
        if (!sharedWidgetOnly) original?.call(d);
      };
      try {
        await body(t);
      } finally {
        FlutterError.onError = original;
      }
    });
  }

  test('đọc đơn: tiền, địa chỉ và hạn thanh toán lấy từ BE', () {
    final o = Order.fromJson(orderJson(shippingAddress: address));
    expect(o.awaitingPayment, isTrue);
    expect(o.amountToPay, 1200000);
    expect(o.sellerName, 'Retro Camera HN');
    expect(o.shippingAddress?.fullAddress, contains('Quận 3'));
    expect(o.canChangeAddress, isTrue);
    expect(o.canConfirmDelivery, isFalse);
  });

  test('chỉ xác nhận nhận hàng khi đã giao và chưa giải ngân', () {
    final delivered = Order.fromJson(
      trackingJson(stage: 'delivered', shipment: 'delivered'),
    );
    expect(delivered.canConfirmDelivery, isTrue);
    expect(delivered.canChangeAddress, isFalse, reason: 'kho đã gửi đi');
    final shipped = Order.fromJson(
      trackingJson(stage: 'shipped', shipment: 'shipped'),
    );
    expect(shipped.canConfirmDelivery, isFalse);
    final done = Order.fromJson(
      trackingJson(stage: 'completed', shipment: 'delivered', payout: 'released'),
    );
    expect(done.canConfirmDelivery, isFalse);
  });

  test('mã đơn sai bị chặn trước khi gọi mạng', () async {
    var calls = 0;
    final api = ApiClient(
      client: MockClient((_) async {
        calls++;
        return ok({});
      }),
    );
    addTearDown(api.close);
    final repo = OrderRepository(api);
    await expectLater(repo.detail('../x'), throwsA(isA<ApiException>()));
    await expectLater(repo.pay('1', 'bitcoin'), throwsA(isA<ApiException>()));
    expect(calls, 0);
  });

  test('gắn địa chỉ, thanh toán, xác nhận nhận hàng gọi đúng endpoint', () async {
    final seen = <String>[];
    final api = ApiClient(
      client: MockClient((r) async {
        seen.add('${r.method} ${r.url.path} ${r.body}');
        return ok({});
      }),
    )..token = 't';
    addTearDown(api.close);
    final repo = OrderRepository(api);
    await repo.setAddress('120', '47');
    await repo.pay('120', 'wallet');
    await repo.confirmDelivery('120');
    expect(seen, [
      'POST /api/orders/120/shipping-address {"addressId":"47"}',
      'POST /api/orders/120/pay {"method":"wallet"}',
      'POST /api/orders/120/confirm-delivery ',
    ]);
  });

  Future<void> pump(WidgetTester t, Widget child) async {
    t.view.physicalSize = const Size(420, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: child));
    await t.pumpAndSettle();
  }

  widgetTest('danh sách đơn hiện đơn thật và mở đúng chi tiết', (t) async {
    final api = ApiClient(
      client: MockClient((r) async {
        if (r.url.path == '/api/orders/mine') {
          return ok({'orders': [orderJson(shippingAddress: address)]});
        }
        if (r.url.path == '/api/orders/120') return ok(orderJson(shippingAddress: address));
        if (r.url.path == '/api/orders/120/tracking') {
          return ok(trackingJson(stage: 'awaiting_payment', payment: 'awaiting_payment'));
        }
        if (r.url.path == '/api/wallet') return ok({'balance': 5000000, 'held': 0, 'available': 5000000});
        return fail('NOT_FOUND', 'x', 404);
      }),
    )..token = 't';
    addTearDown(api.close);
    await pump(t, OrdersScreen(api: api));
    expect(find.text('Máy nghe nhạc cassette 1988'), findsOneWidget);
    expect(find.text('Chờ thanh toán'), findsOneWidget);
    await t.tap(find.text('Máy nghe nhạc cassette 1988'));
    await t.pumpAndSettle();
    expect(find.text('Đơn hàng #120'), findsOneWidget);
    expect(find.textContaining('Thanh toán 1.200.000'), findsOneWidget);
  });

  widgetTest('chưa có địa chỉ: chặn thanh toán và không gọi /pay', (t) async {
    final paths = <String>[];
    final api = ApiClient(
      client: MockClient((r) async {
        paths.add(r.url.path);
        if (r.url.path == '/api/orders/120') return ok(orderJson());
        if (r.url.path == '/api/orders/120/tracking') {
          return ok({...trackingJson(stage: 'awaiting_payment', payment: 'awaiting_payment'), 'shippingAddress': null});
        }
        if (r.url.path == '/api/wallet') return ok({'balance': 5000000, 'held': 0, 'available': 5000000});
        return fail('NOT_FOUND', 'x', 404);
      }),
    )..token = 't';
    addTearDown(api.close);
    await pump(t, OrderDetailScreen(api: api, orderId: '120'));
    expect(find.textContaining('Chưa có địa chỉ nhận hàng'), findsOneWidget);
    await t.tap(find.textContaining('Thanh toán 1.200.000'));
    await t.pump();
    expect(find.text('Hãy chọn địa chỉ nhận hàng trước khi thanh toán.'), findsOneWidget);
    expect(paths, isNot(contains('/api/orders/120/pay')));
  });

  widgetTest('thanh toán thiếu tiền: hiện lý do tiếng Việt và tải lại đơn', (t) async {
    var detailLoads = 0;
    final api = ApiClient(
      client: MockClient((r) async {
        switch (r.url.path) {
          case '/api/orders/120':
            detailLoads++;
            return ok(orderJson(shippingAddress: address));
          case '/api/orders/120/tracking':
            return ok(trackingJson(stage: 'awaiting_payment', payment: 'awaiting_payment'));
          case '/api/wallet':
            return ok({'balance': 5000000, 'held': 0, 'available': 5000000});
          case '/api/orders/120/pay':
            return fail('INSUFFICIENT_FUNDS', 'Số dư không đủ', 402);
        }
        return fail('NOT_FOUND', 'x', 404);
      }),
    )..token = 't';
    addTearDown(api.close);
    await pump(t, OrderDetailScreen(api: api, orderId: '120'));
    await t.tap(find.textContaining('Thanh toán 1.200.000'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextButton, 'Thanh toán'));
    await t.pumpAndSettle();
    expect(find.textContaining('Ví không đủ số dư'), findsOneWidget);
    expect(detailLoads, 2, reason: 'tải lại sau thao tác ghi để biết trạng thái thật');
  });

  widgetTest('đơn đã giao: có nút xác nhận, có hộp xác nhận trước khi gửi', (t) async {
    var confirmed = false;
    final api = ApiClient(
      client: MockClient((r) async {
        switch (r.url.path) {
          case '/api/orders/120':
            return ok(orderJson(payment: 'paid', shippingAddress: address));
          case '/api/orders/120/tracking':
            return ok(trackingJson(
              stage: confirmed ? 'completed' : 'delivered',
              shipment: 'delivered',
              payout: confirmed ? 'released' : 'pending',
            ));
          case '/api/orders/120/confirm-delivery':
            confirmed = true;
            return ok(trackingJson(stage: 'completed', shipment: 'delivered', payout: 'released'));
        }
        return fail('NOT_FOUND', 'x', 404);
      }),
    )..token = 't';
    addTearDown(api.close);
    await pump(t, OrderDetailScreen(api: api, orderId: '120'));
    await t.tap(find.text('Đã nhận hàng'));
    await t.pumpAndSettle();
    expect(confirmed, isFalse, reason: 'chưa gọi khi chưa bấm xác nhận trong hộp thoại');
    await t.tap(find.widgetWithText(TextButton, 'Đã nhận hàng'));
    await t.pumpAndSettle();
    expect(confirmed, isTrue);
    expect(find.text('Đã nhận hàng'), findsNothing, reason: 'hết nút sau khi hoàn tất');
  });

  widgetTest('hết phiên (401) báo cho màn cha, không hiện lỗi thô', (t) async {
    ApiException? expired;
    final api = ApiClient(
      client: MockClient((_) async => fail('UNAUTHORIZED', 'Hết hạn', 401)),
    )..token = 't';
    addTearDown(api.close);
    await pump(t, OrderDetailScreen(api: api, orderId: '120', onSessionExpired: (e) => expired = e));
    expect(expired?.code, 'UNAUTHORIZED');
  });

  test('JSON sai kiểu không ném TypeError: trường lạ thành null, danh sách vẫn đọc được', () {
    final o = Order.fromJson({
      ...orderJson(),
      'coverUrl': 123, // không phải chuỗi
      'stage': {'x': 1},
      'seller': {'storeName': 5, 'name': 'Shop'},
      'warehouse': {'orderCode': 7},
      'shipment': {'status': 1, 'trackingCode': []},
      'events': [
        {'step': 'packing', 'note': 99, 'at': 'không phải ngày'},
      ],
    });
    expect(o.coverUrl, isNull);
    expect(o.stage, isNull);
    expect(o.sellerName, 'Shop');
    expect(o.warehouseCode, isNull);
    expect(o.events.single.note, isNull);
    expect(o.events.single.at, isNull);
  });

  test('đơn đang tranh chấp không cho xác nhận nhận hàng (BE sẽ trả DISPUTE_OPEN)', () {
    final o = Order.fromJson(trackingJson(stage: 'delivered', shipment: 'delivered', payout: 'disputed'));
    expect(o.disputed, isTrue);
    expect(o.canConfirmDelivery, isFalse);
    expect(o.canDispute, isFalse);
  });

  widgetTest('lỗi gọi số dư ví không làm mất màn chi tiết: vẫn thanh toán được bằng QR', (t) async {
    final api = ApiClient(
      client: MockClient((r) async {
        switch (r.url.path) {
          case '/api/orders/120':
            return ok(orderJson(shippingAddress: address));
          case '/api/orders/120/tracking':
            return ok(trackingJson(stage: 'awaiting_payment', payment: 'awaiting_payment'));
          case '/api/wallet':
            return fail('SERVER_ERROR', 'Lỗi máy chủ', 500);
        }
        return fail('NOT_FOUND', 'x', 404);
      }),
    )..token = 't';
    addTearDown(api.close);
    await pump(t, OrderDetailScreen(api: api, orderId: '120'));
    expect(find.text('Đơn hàng #120'), findsOneWidget);
    expect(find.textContaining('Thanh toán 1.200.000'), findsOneWidget);
    expect(find.text('Không tải được đơn.'), findsNothing);
    await t.drag(find.byType(ListView).first, const Offset(0, -600)); // ô "Ví" nằm dưới màn hình
    await t.pump();
    expect(find.textContaining('Không tải được số dư'), findsOneWidget);
  });

  widgetTest('đơn tranh chấp đã giao: hiện thông báo tranh chấp, không có nút "Đã nhận hàng"', (t) async {
    final api = ApiClient(
      client: MockClient((r) async {
        switch (r.url.path) {
          case '/api/orders/120':
            return ok(orderJson(payment: 'paid', shippingAddress: address));
          case '/api/orders/120/tracking':
            return ok(trackingJson(stage: 'delivered', shipment: 'delivered', payout: 'disputed'));
        }
        return fail('NOT_FOUND', 'x', 404);
      }),
    )..token = 't';
    addTearDown(api.close);
    await pump(t, OrderDetailScreen(api: api, orderId: '120'));
    expect(find.text('Đã nhận hàng'), findsNothing);
    expect(find.textContaining('Đơn đang có tranh chấp'), findsOneWidget);
  });

  widgetTest('đồng hồ tự chạy: hết hạn thì khoá nút thanh toán, không còn Timer treo', (t) async {
    final api = ApiClient(
      client: MockClient((r) async {
        switch (r.url.path) {
          case '/api/orders/120':
            return ok(orderJson(shippingAddress: address, deadlineIn: const Duration(seconds: 2)));
          case '/api/orders/120/tracking':
            return ok(trackingJson(stage: 'awaiting_payment', payment: 'awaiting_payment'));
          case '/api/wallet':
            return ok({'balance': 5000000, 'held': 0, 'available': 5000000});
        }
        return fail('NOT_FOUND', 'x', 404);
      }),
    )..token = 't';
    addTearDown(api.close);
    await pump(t, OrderDetailScreen(api: api, orderId: '120'));
    expect(find.textContaining('Thanh toán 1.200.000'), findsOneWidget);
    final clock = find.byWidgetPredicate((w) => w is Text && RegExp(r'^00:00:0[0-2]$').hasMatch(w.data ?? ''));
    expect(clock, findsOneWidget, reason: 'đồng hồ đang đếm');

    // DateTime.now() không chạy theo đồng hồ giả của test: chờ thời gian thật rồi cho Timer nổ.
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2300)));
    await t.pump(const Duration(seconds: 1)); // Timer 1 giây phát hiện hết hạn
    await t.pump(); // frame sau: onExpired -> setState
    expect(find.text('Đã quá hạn thanh toán'), findsOneWidget, reason: 'nút bị khoá khi hết hạn');
    expect(find.textContaining('Thanh toán 1.200.000'), findsNothing);
    await t.pumpWidget(const SizedBox()); // huỷ màn: nếu còn Timer, test báo "Timer is still pending"
  });

  widgetTest('đang tải: hiện khung chờ thay vòng xoay; tải xong thì thay bằng dữ liệu', (t) async {
    final gate = Completer<http.Response>();
    final api = ApiClient(
      client: MockClient((r) => gate.future),
    )..token = 't';
    addTearDown(api.close);
    t.view.physicalSize = const Size(420, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: OrdersScreen(api: api)));
    await t.pump();
    expect(find.byType(SkeletonTileList), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    gate.complete(ok({'orders': [orderJson(shippingAddress: address)]}));
    await t.pumpAndSettle();
    expect(find.byType(SkeletonTileList), findsNothing);
    expect(find.text('Máy nghe nhạc cassette 1988'), findsOneWidget);
  });

  widgetTest('bật "giảm chuyển động": khung chờ đứng yên (không có animation lặp)', (t) async {
    final gate = Completer<http.Response>();
    final api = ApiClient(client: MockClient((r) => gate.future))..token = 't';
    addTearDown(api.close);
    t.view.physicalSize = const Size(420, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: true), child: child!),
        home: OrdersScreen(api: api),
      ),
    );
    await t.pump();
    expect(find.byType(SkeletonTileList), findsOneWidget);
    // Nếu khung chờ còn animation lặp, pumpAndSettle sẽ không bao giờ kết thúc.
    await t.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 2));
    gate.complete(ok({'orders': <Object>[]}));
    await t.pumpAndSettle();
  });

  widgetTest('thanh toán xong: khối "Phương thức" được thay bằng "Theo dõi đơn"', (t) async {
    var paid = false;
    final api = ApiClient(
      client: MockClient((r) async {
        switch (r.url.path) {
          case '/api/orders/120':
            return ok(orderJson(payment: paid ? 'paid' : 'awaiting_payment', shippingAddress: address));
          case '/api/orders/120/tracking':
            return ok(trackingJson(stage: paid ? 'awaiting_seller_shipment' : 'awaiting_payment', payment: paid ? 'paid' : 'awaiting_payment'));
          case '/api/wallet':
            return ok({'balance': 5000000, 'held': 0, 'available': 5000000});
          case '/api/orders/120/pay':
            paid = true;
            return ok({});
        }
        return fail('NOT_FOUND', 'x', 404);
      }),
    )..token = 't';
    addTearDown(api.close);
    await pump(t, OrderDetailScreen(api: api, orderId: '120'));
    await t.drag(find.byType(ListView).first, const Offset(0, -500));
    await t.pump();
    expect(find.text('Phương thức'), findsOneWidget);
    expect(find.text('Theo dõi đơn'), findsNothing);
    await t.tap(find.textContaining('Thanh toán 1.200.000'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextButton, 'Thanh toán'));
    await t.pumpAndSettle();
    await t.drag(find.byType(ListView).first, const Offset(0, -500));
    await t.pumpAndSettle();
    expect(find.text('Phương thức'), findsNothing);
    expect(find.text('Theo dõi đơn'), findsOneWidget);
  });

  widgetTest('đơn hoàn tất: mọi bước theo dõi đều có dấu tích, không còn bước "đang ở"', (t) async {
    final api = ApiClient(
      client: MockClient((r) async {
        switch (r.url.path) {
          case '/api/orders/120':
            return ok(orderJson(payment: 'paid', shippingAddress: address));
          case '/api/orders/120/tracking':
            return ok(trackingJson(stage: 'completed', shipment: 'delivered', payout: 'released'));
        }
        return fail('NOT_FOUND', 'x', 404);
      }),
    )..token = 't';
    addTearDown(api.close);
    await pump(t, OrderDetailScreen(api: api, orderId: '120'));
    await t.drag(find.byType(ListView).first, const Offset(0, -500));
    await t.pump();
    expect(find.byIcon(Icons.check_circle), findsNWidgets(8), reason: '8 bước, tất cả đã xong');
    expect(find.byIcon(Icons.radio_button_checked), findsNothing);
  });

  widgetTest('đơn đang tranh chấp: nhãn đầu trang là "Đang tranh chấp", không phải giai đoạn giao hàng', (t) async {
    final api = ApiClient(
      client: MockClient((r) async {
        switch (r.url.path) {
          case '/api/orders/120':
            return ok(orderJson(payment: 'paid', shippingAddress: address));
          case '/api/orders/120/tracking':
            return ok(trackingJson(stage: 'awaiting_seller_shipment', payout: 'disputed'));
        }
        return fail('NOT_FOUND', 'x', 404);
      }),
    )..token = 't';
    addTearDown(api.close);
    await pump(t, OrderDetailScreen(api: api, orderId: '120'));
    expect(find.text('Đang tranh chấp'), findsOneWidget);
    expect(find.text('Chờ người bán gửi kho'), findsOneWidget, reason: 'vẫn còn trong khối theo dõi, không còn là nhãn đầu trang');
  });
}
