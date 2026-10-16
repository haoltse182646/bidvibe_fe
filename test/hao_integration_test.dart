import 'dart:async';
import 'dart:convert';

import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/core/remote_app_store.dart';
import 'package:bidvibe/features/auctions/auction_events.dart';
import 'package:bidvibe/features/auctions/auction_repository.dart';
import 'package:bidvibe/features/notifications/notification_controller.dart';
import 'package:bidvibe/features/notifications/notification_repository.dart';
import 'package:bidvibe/features/profile/profile_repository.dart';
import 'package:bidvibe/features/wallet/wallet_repository.dart';
import 'package:bidvibe/models.dart';
import 'package:bidvibe/screens/auth/auth_profile.dart';
import 'package:bidvibe/screens/bidder/auction_detail_screen.dart';
import 'package:bidvibe/screens/bidder/bidder_shell.dart';
import 'package:bidvibe/screens/bidder/bidder_wallet.dart';
import 'package:bidvibe/screens/orders/dispute_detail_screen.dart';
import 'package:bidvibe/screens/orders/order_detail_screen.dart';
import 'package:bidvibe/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

http.Response ok(Map<String, dynamic> data) => http.Response(
      jsonEncode({'success': true, 'data': data}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
http.Response denied() => http.Response(
    jsonEncode({
      'success': false,
      'error': {'code': 'UNAUTHORIZED', 'message': 'Hết phiên'},
    }),
    401,
    headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> profile() => {
      'id': '123',
      'fullName': 'Hào',
      'email': 'hao@example.com',
      'role': 'bidder',
      'kind': 'account',
      'status': 'active',
    };
Map<String, dynamic> order({String id = '120', String auctionId = '355'}) => {
      'id': id,
      'auctionId': auctionId,
      'title': 'Đơn kiểm thử',
      'paymentStatus': 'awaiting_payment',
      'payoutStatus': 'pending',
      'finalPrice': 1000000,
      'totalDue': 1100000,
      'amountToPay': 1000000,
      'depositApplied': 100000,
      'paymentDeadline': DateTime.now()
          .add(const Duration(hours: 1))
          .toUtc()
          .toIso8601String(),
    };
Map<String, dynamic> dispute({String resolution = 'refund'}) => {
      'id': '7',
      'orderId': '120',
      'itemTitle': 'Đơn kiểm thử',
      'title': 'Sản phẩm không đúng mô tả',
      'source': 'bidder',
      'status': resolution == 'none' ? 'open' : 'resolved',
      'resolution': resolution,
      'escrowAmount': 1100000,
      'timeline': [
        {'note': 'Đã tiếp nhận yêu cầu', 'at': '2026-10-15T07:00:00Z'}
      ],
    };
Map<String, dynamic> auction({bool won = true}) => {
      'id': '355',
      'listingId': '999',
      'title': 'Phiên kiểm thử',
      'status': 'ended',
      'isLive': false,
      'paused': false,
      'remainingSeconds': 0,
      'won': won,
      'winnerId': '123',
      'currentPrice': 1000000,
      'bidCount': 1,
      'bidStep': 10000,
      'minNextBid': 1010000,
      'depositRequired': 100000,
      'joined': true,
      'myDeposit': 100000,
      'photos': [],
      'bids': [],
    };

class IntegrationStore extends RemoteAppStore {
  final ApiClient testApi;
  bool loggedOut = false;
  IntegrationStore(this.testApi) : super(restoreOnStart: false) {
    currentUser = UserAccount(
        id: '123', name: 'Hào', email: 'hao@example.com', role: 'bidder');
  }
  @override
  ApiClient get api => testApi;
  @override
  void logout() {
    loggedOut = true;
    api.token = null;
    currentUser = null;
    notifyListeners();
  }
}

class IntegrationEvents implements AuctionEvents {
  final controller = StreamController<AuctionEvent>.broadcast(sync: true);
  bool closed = false;
  @override
  Stream<AuctionEvent> get stream => controller.stream;
  @override
  void connect() {}
  void send(String type, Map<String, dynamic> data) =>
      controller.add(AuctionEvent(type, data));
  @override
  void dispose() {
    if (!closed) {
      closed = true;
      unawaited(controller.close());
    }
  }
}

Future<void> show(WidgetTester tester, Widget child,
    {IntegrationStore? store}) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  Widget app = MaterialApp(home: Scaffold(body: child));
  if (store != null) {
    app = ChangeNotifierProvider<AppStore>.value(value: store, child: app);
  }
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  for (final resolution in ['refund', 'keep', 'none']) {
    testWidgets(
        'Dispute detail reads mine and renders $resolution without writes',
        (tester) async {
      final calls = <String>[];
      String? opened;
      final api = ApiClient(client: MockClient((r) async {
        calls.add('${r.method} ${r.url.path}');
        expect(r.headers['Authorization'], 'Bearer A');
        return ok({
          'disputes': [dispute(resolution: resolution)]
        });
      }))
        ..token = 'A';
      addTearDown(api.close);
      await show(
          tester,
          DisputeDetailScreen(
              api: api,
              disputeId: '7',
              onOpenOrder: (id) async {
                opened = id;
              }));
      expect(find.text('Đã tiếp nhận yêu cầu'), findsOneWidget);
      expect(
          find.text(switch (resolution) {
            'refund' => 'Đã hoàn tiền cho người mua',
            'keep' => 'Giữ nguyên, giải ngân cho người bán',
            _ => 'Đang chờ xem xét',
          }),
          findsOneWidget);
      await tap(tester, 'Xem đơn liên quan');
      expect(opened, '120');
      expect(calls, everyElement('GET /api/disputes/mine'));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
      'Missing dispute cannot open an unrelated order; retry finds it later',
      (tester) async {
    var found = false;
    final api = ApiClient(
        client: MockClient((_) async => ok({
              'disputes': found ? [dispute()] : []
            })));
    addTearDown(api.close);
    await show(tester, DisputeDetailScreen(api: api, disputeId: '7'));
    expect(find.textContaining('Không tìm thấy tranh chấp'), findsOneWidget);
    expect(find.text('Xem đơn liên quan'), findsNothing);
    found = true;
    await tap(tester, 'Thử lại');
    expect(find.text('Đã hoàn tiền cho người mua'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Invalid dispute ID sends no HTTP', (tester) async {
    var calls = 0;
    final api = ApiClient(client: MockClient((_) async {
      calls++;
      return ok({});
    }));
    addTearDown(api.close);
    await show(tester, DisputeDetailScreen(api: api, disputeId: '../7'));
    expect(calls, 0);
    expect(find.text('Mã tranh chấp không hợp lệ.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Won CTA resolves auction ID to actual order ID', (tester) async {
    final paths = <String>[];
    String? opened;
    final api = ApiClient(client: MockClient((r) async {
      paths.add('${r.method} ${r.url.path}');
      return ok(r.url.path == '/api/orders/mine'
          ? {
              'orders': [order(id: '999', auctionId: '999'), order()]
            }
          : auction());
    }));
    addTearDown(api.close);
    await show(
        tester,
        AuctionDetailScreen(
            auctionId: '355',
            repository: AuctionRepository(api),
            onOpenOrder: (id) async {
              opened = id;
            }));
    await tap(tester, 'Xem đơn thắng');
    expect(opened, '120');
    expect(paths, contains('GET /api/orders/mine'));
    expect(paths.any((p) => p.startsWith('POST')), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Award scheduler delay can be retried without creating orders',
      (tester) async {
    var ready = false, gets = 0;
    String? opened;
    final api = ApiClient(client: MockClient((r) async {
      expect(r.method, 'GET');
      if (r.url.path == '/api/orders/mine') {
        gets++;
        return ok({
          'orders': ready ? [order()] : []
        });
      }
      return ok(auction());
    }));
    addTearDown(api.close);
    await show(
        tester,
        AuctionDetailScreen(
            auctionId: '355',
            repository: AuctionRepository(api),
            onOpenOrder: (id) async {
              opened = id;
            }));
    await tap(tester, 'Xem đơn thắng');
    expect(opened, isNull);
    expect(find.textContaining('Đơn thắng đang được cập nhật'), findsOneWidget);
    ready = true;
    await tap(tester, 'Xem đơn thắng');
    expect(opened, '120');
    expect(gets, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Non-winner cannot open a won order', (tester) async {
    final api =
        ApiClient(client: MockClient((_) async => ok(auction(won: false))));
    addTearDown(api.close);
    await show(
        tester,
        AuctionDetailScreen(
            auctionId: '355', repository: AuctionRepository(api)));
    expect(find.text('Xem đơn thắng'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Profile defers refresh and preserves an edited draft',
      (tester) async {
    final signal = ValueNotifier(0);
    var gets = 0;
    final api = ApiClient(client: MockClient((r) async {
      expect(r.method, 'GET');
      if (r.url.path == '/api/me') {
        gets++;
        return ok(profile());
      }
      return ok(
          r.url.path == '/api/addresses' ? {'addresses': []} : {'orders': []});
    }))
      ..token = 'A';
    final store = IntegrationStore(api);
    addTearDown(signal.dispose);
    await show(
        tester,
        AuthProfileScreen(
            repository: ProfileRepository(api),
            refreshSignal: signal,
            pickImage: () async => null),
        store: store);
    await tap(tester, 'Sửa');
    final name = find.byKey(const ValueKey('profile.name'));
    await tester.enterText(name, 'Bản nháp chưa lưu');
    signal.value++;
    signal.value++;
    await tester.pumpAndSettle();
    expect(gets, 1);
    expect(tester.widget<TextFormField>(name).controller!.text,
        'Bản nháp chưa lưu');
    await tap(tester, 'Huỷ');
    expect(gets, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });

  testWidgets('Wallet ignores late unauthorized response from an older token',
      (tester) async {
    final pending = Completer<http.Response>();
    final api = ApiClient(
        client: MockClient((r) async => r.url.path == '/api/wallet'
            ? await pending.future
            : ok({'transactions': [], 'total': 0})))
      ..token = 'A';
    addTearDown(api.close);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: BidderWalletScreen(repository: WalletRepository(api)))));
    await tester.pump();
    api.token = 'B';
    pending.complete(denied());
    await tester.pumpAndSettle();
    expect(api.token, 'B');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'Order refresh failure locks payment after authentication rejection',
      (tester) async {
    final signal = ValueNotifier(0);
    var fail = false, expired = 0, posts = 0;
    final api = ApiClient(client: MockClient((r) async {
      if (r.method == 'POST') posts++;
      if (fail) return denied();
      if (r.url.path == '/api/wallet') {
        return ok({'balance': 2000000, 'held': 0, 'available': 2000000});
      }
      return ok(order());
    }))
      ..token = 'A';
    addTearDown(api.close);
    addTearDown(signal.dispose);
    await show(
        tester,
        OrderDetailScreen(
            api: api,
            orderId: '120',
            refreshSignal: signal,
            onSessionExpired: (_) {
              expired++;
            }));
    fail = true;
    signal.value++;
    await tester.pumpAndSettle();
    expect(expired, 1);
    expect(find.text('Hết phiên'), findsOneWidget);
    final pay = find.widgetWithText(InkWell, 'Thanh toán 1.000.000 đ');
    expect(tester.widget<InkWell>(pay).onTap, isNull);
    expect(posts, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'Refund event refreshes hidden wallet/profile once; dispute target has priority',
      (tester) async {
    final events = IntegrationEvents();
    var refunded = false, walletGets = 0, profileGets = 0, disputeGets = 0;
    var read = false;
    Map<String, dynamic> notification() => {
          'id': '77',
          'title': 'Đã xử lý tranh chấp',
          'type': 'order',
          'isRead': read,
          'createdAt': '2026-10-16T07:00:00Z',
          'data': {'disputeId': '7', 'orderId': '120', 'auctionId': '355'},
        };
    final api = ApiClient(client: MockClient((r) async {
      final path = r.url.path;
      if (r.method == 'POST') {
        expect(path, '/api/notifications/77/read');
        read = true;
        return ok({'id': '77', 'isRead': true});
      }
      if (path == '/api/wallet') {
        walletGets++;
        return ok({
          'balance': refunded ? 1100000 : 0,
          'held': 0,
          'available': refunded ? 1100000 : 0
        });
      }
      if (path == '/api/me') {
        profileGets++;
        return ok(profile());
      }
      if (path == '/api/disputes/mine') {
        disputeGets++;
        return ok({
          'disputes': [dispute()]
        });
      }
      return ok(switch (path) {
        '/api/categories' => {'categories': []},
        '/api/auctions' => {'auctions': [], 'total': 0},
        '/api/orders/mine' => {'orders': []},
        '/api/addresses' => {'addresses': []},
        '/api/wallet/transactions' => {'transactions': [], 'total': 0},
        '/api/notifications' => {
            'notifications': refunded ? [notification()] : [],
            'unreadCount': refunded && !read ? 1 : 0
          },
        _ => throw StateError('Unexpected API $path'),
      });
    }))
      ..token = 'A';
    final store = IntegrationStore(api);
    final controller = NotificationController(
        repository: NotificationRepository(api), events: events);
    await show(tester, BidderShell(notifications: controller), store: store);
    expect(walletGets, 1);
    expect(profileGets, 1);
    refunded = true;
    events.send('notification:new', notification());
    await tester.pumpAndSettle();
    expect(walletGets, 2);
    expect(profileGets, 2);
    events.send('notification:new', notification());
    await tester.pumpAndSettle();
    expect(walletGets, 2);
    ScaffoldMessenger.of(tester.element(find.byType(BidderShell)))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await tap(tester, 'Ví');
    expect(find.textContaining('1.100.000'), findsWidgets);
    final afterTab = walletGets;
    await tester.pump(const Duration(seconds: 2));
    expect(walletGets,
        afterTab); // no fetch loop from notification controller changes
    events.send('connected', {});
    await tester.pumpAndSettle();
    expect(walletGets, afterTab + 1);
    events.send('disconnected', {});
    events.send('connected', {});
    await tester.pumpAndSettle();
    expect(walletGets, afterTab + 2);
    await tap(tester, 'Thông báo');
    await tap(tester, 'Đã xử lý tranh chấp');
    expect(find.byType(DisputeDetailScreen), findsOneWidget);
    expect(find.byType(OrderDetailScreen), findsNothing);
    expect(disputeGets, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    store.dispose();
  });

  testWidgets(
      'Wallet defers signals while fetching and performs one follow-up GET',
      (tester) async {
    final signal = ValueNotifier(0);
    final pending = Completer<http.Response>();
    var gets = 0;
    final api = ApiClient(client: MockClient((r) async {
      expect(r.method, 'GET');
      if (r.url.path == '/api/wallet') {
        gets++;
        if (gets == 1) return pending.future;
        return ok({'balance': 600000, 'held': 0, 'available': 600000});
      }
      return ok({'transactions': [], 'total': 0});
    }));
    addTearDown(api.close);
    addTearDown(signal.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: BidderWalletScreen(
                repository: WalletRepository(api), refreshSignal: signal))));
    await tester.pump();
    signal.value++;
    signal.value++;
    expect(gets, 1);
    pending.complete(ok({'balance': 0, 'held': 0, 'available': 0}));
    await tester.pumpAndSettle();
    expect(gets, 2);
    expect(find.textContaining('600.000'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Order ignores a late 401 after the login token changes',
      (tester) async {
    final pending = Completer<http.Response>();
    var expired = 0;
    final api = ApiClient(client: MockClient((_) async => pending.future))
      ..token = 'A';
    addTearDown(api.close);
    await tester.pumpWidget(MaterialApp(
        home: OrderDetailScreen(
            api: api,
            orderId: '120',
            onSessionExpired: (_) {
              expired++;
            })));
    await tester.pump();
    api.token = 'B';
    pending.complete(denied());
    await tester.pumpAndSettle();
    expect(expired, 0);
    expect(api.token, 'B');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'Foreground reloads dispute resolution without reopening the screen',
      (tester) async {
    var resolution = 'none', gets = 0;
    final api = ApiClient(client: MockClient((_) async {
      gets++;
      return ok({
        'disputes': [dispute(resolution: resolution)]
      });
    }));
    addTearDown(api.close);
    await show(tester, DisputeDetailScreen(api: api, disputeId: '7'));
    expect(find.text('Đang chờ xem xét'), findsOneWidget);
    resolution = 'refund';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(gets, 2);
    expect(find.text('Đã hoàn tiền cho người mua'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'Paying a real order route refreshes wallet and profile on return',
      (tester) async {
    var paid = false, posts = 0, walletGets = 0, orderGets = 0;
    final events = IntegrationEvents();
    final api = ApiClient(client: MockClient((r) async {
      final path = r.url.path;
      if (r.method == 'POST') {
        expect(path, '/api/orders/120/pay');
        expect(jsonDecode(r.body), {'method': 'qr'});
        posts++;
        paid = true;
        return ok({'id': '120', 'paymentStatus': 'paid'});
      }
      final data = {
        ...order(),
        'paymentStatus': paid ? 'paid' : 'awaiting_payment',
        'shippingAddress': {
          'id': '47',
          'recipientName': 'Hào',
          'phone': '0901234567',
          'addressLine': '12 Nguyễn Huệ',
          'ward': '',
          'district': '',
          'city': 'TP.HCM'
        }
      };
      if (path == '/api/wallet') {
        walletGets++;
        return ok({
          'balance': paid ? 1000000 : 2000000,
          'held': 0,
          'available': paid ? 1000000 : 2000000
        });
      }
      if (path == '/api/orders/mine') {
        orderGets++;
        return ok({
          'orders': [data]
        });
      }
      if (path == '/api/orders/120' || path == '/api/orders/120/tracking') {
        return ok(
            {...data, 'stage': paid ? 'awaiting_seller' : 'awaiting_payment'});
      }
      return ok(switch (path) {
        '/api/me' => profile(),
        '/api/categories' => {'categories': []},
        '/api/auctions' => {'auctions': [], 'total': 0},
        '/api/addresses' => {'addresses': []},
        '/api/wallet/transactions' => {'transactions': [], 'total': 0},
        '/api/notifications' => {'notifications': [], 'unreadCount': 0},
        _ => throw StateError('Unexpected API $path'),
      });
    }))
      ..token = 'A';
    final store = IntegrationStore(api);
    final controller = NotificationController(
        repository: NotificationRepository(api), events: events);
    try {
      await show(tester, BidderShell(notifications: controller), store: store);
      await tap(tester, 'Hồ sơ');
      await tap(tester, 'Đơn kiểm thử');
      expect(find.byType(OrderDetailScreen), findsOneWidget);
      await tap(tester, 'Thanh toán 1.000.000 đ');
      await tap(tester, 'Thanh toán');
      expect(posts, 1);
      final beforeReturn = walletGets;
      final ordersBeforeReturn = orderGets;
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(walletGets, greaterThan(beforeReturn));
      expect(orderGets, greaterThan(ordersBeforeReturn));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tap(tester, 'Ví');
      expect(find.textContaining('1.000.000'), findsWidgets);
      expect(posts, 1);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      store.dispose();
    }
  });
}
