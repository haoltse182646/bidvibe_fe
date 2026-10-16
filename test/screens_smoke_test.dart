import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/core/remote_app_store.dart';
import 'package:bidvibe/features/auctions/auction_events.dart';
import 'package:bidvibe/features/auctions/auction_repository.dart';
import 'package:bidvibe/features/notifications/notification_controller.dart';
import 'package:bidvibe/features/notifications/notification_repository.dart';
import 'package:bidvibe/main.dart';
import 'package:bidvibe/store.dart';
import 'package:bidvibe/screens/auth/auth_login.dart';
import 'package:bidvibe/screens/auth/auth_register.dart';
import 'package:bidvibe/screens/auth/auth_profile.dart';
import 'package:bidvibe/screens/bidder/bidder_shell.dart';
import 'package:bidvibe/screens/bidder/auction_detail_screen.dart';
import 'package:bidvibe/screens/bidder/bidder_detail.dart';
import 'package:bidvibe/screens/bidder/bidder_payment.dart';
import 'package:bidvibe/screens/bidder/bidder_done.dart';
import 'package:bidvibe/screens/customer/customer_chatbot.dart';
import 'package:bidvibe/screens/customer/customer_dispute.dart';
import 'package:bidvibe/screens/seller/seller_shell.dart';
import 'package:bidvibe/screens/seller/seller_edit.dart';
import 'package:bidvibe/screens/appraiser/appraiser_shell.dart';
import 'package:bidvibe/screens/appraiser/appraiser_ops_screen.dart';
import 'package:bidvibe/screens/warehouse/warehouse_ops_screen.dart';
import 'package:bidvibe/screens/admin/admin_shell.dart';
import 'package:bidvibe/screens/admin/admin_ops_cases.dart';

// Real API screens receive a RemoteAppStore with a mock HTTP client.
// Remaining prototype screens still use the seeded data inherited from AppStore.
// No FlutterError handler is replaced, and no layout exception is suppressed.
class _SmokeStore extends RemoteAppStore {
  final ApiClient testApi;
  _SmokeStore(this.testApi) : super(restoreOnStart: false);
  @override
  ApiClient get api => testApi;
}

class _SmokeEvents implements AuctionEvents {
  final _controller = StreamController<AuctionEvent>.broadcast(sync: true);
  bool _disposed = false;
  @override
  Stream<AuctionEvent> get stream => _controller.stream;
  @override
  void connect() {
    if (!_disposed) {
      _controller.add(const AuctionEvent('connected', {}));
    }
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    unawaited(_controller.close());
  }
}

void main() {
  late _SmokeStore store;
  late ApiClient api;
  late List<String> requests;
  late List<String> unexpectedRequests;

  Never unexpected(String request) {
    unexpectedRequests.add(request);
    throw StateError('Unmocked request: $request');
  }

  Map<String, dynamic> detail(String id) => {
    'id': id,
    'listingId': '2115',
    'title': 'Bình gốm kiểm thử',
    'category': 'antique',
    'description': 'Dữ liệu HTTP giả lập',
    'condition': 'Nguyên vẹn',
    'seller': {'name': 'Cửa hàng kiểm thử', 'rating': 4.9},
    'startPrice': 1000000,
    'currentPrice': 1000000,
    'bidStep': 50000,
    'minNextBid': 1050000,
    'depositRequired': 100000,
    'depositAffordable': true,
    'bidCount': 0,
    'status': id == '1109' ? 'ended' : 'active',
    'isLive': id == '1107',
    'paused': id == '1108',
    'remainingSeconds': id == '1109' ? 0 : 600,
    'joined': false,
    'leading': false,
    'won': false,
    'photos': [],
    'bids': [],
  };

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    requests = [];
    unexpectedRequests = [];
    api = ApiClient(
      client: MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        if (request.method != 'GET') {
          unexpected('${request.method} ${request.url}');
        }
        final user = store.currentUser;
        final data = switch (request.url.path) {
          '/api/me' => {
            'id': user!.id,
            'fullName': user.name,
            'email': user.email,
            'phone': user.phone,
            'role': user.role,
            'storeName': user.shop,
            'avatarUrl': null,
            'status': 'active',
          },
          '/api/categories' => {'categories': []},
          '/api/auctions' => {'auctions': [], 'total': 0},
          '/api/wallet' => {
            'balance': 1000000,
            'available': 1000000,
            'held': 0,
          },
          '/api/wallet/transactions' => {'transactions': [], 'total': 0},
          '/api/notifications' => {'notifications': [], 'unreadCount': 0},
          '/api/addresses' => {'addresses': []},
          '/api/orders/mine' => {'orders': []},
          '/api/admin/dashboard' => {
            'auctions': {'live': 0, 'endingIn24h': 0},
            'appraisal': {'pending': 0, 'needsInfo': 0},
            'orders': {
              'awaitingPayment': 0,
              'awaitingSellerShipment': 0,
              'inTransitToWarehouse': 0,
              'inspecting': 0,
              'outbound': 0,
              'deliveredAwaitingConfirm': 0,
            },
            'flags': {'open': 0, 'paused': 0},
            'disputes': {'open': 0},
            'users': {'bidders': 0, 'sellers': 0, 'ops': 0, 'suspended': 0},
            'escrowHeld': 0,
          },
          '/api/admin/report/weekly' => {
            'period': {'from': '2026-10-09T00:00:00Z', 'to': '2026-10-16T00:00:00Z'},
            'auctions': {'ended': 0, 'sold': 0, 'cancelled': 0},
            'sales': {'orders': 0, 'gmv': 0, 'estimatedFees': 0},
            'payments': {'paid': 0, 'expired': 0},
            'newAccounts': {'bidder': 0, 'seller': 0},
            'appraisals': {'approve': 0, 'reject': 0, 'more_info': 0},
            'disputes': {'opened': 0, 'resolved': 0},
            'walletTopups': {'count': 0, 'total': 0},
            'topCategories': [],
          },
          '/api/admin/flags' => {
            'flags': [
              {
                'id': '1',
                'auction': {'id': '9', 'title': 'Phiên kiểm thử'},
                'severity': 'high',
                'confidence': 90,
                'reason': 'Tín hiệu bất thường',
                'aiExplanation': 'Mô tả kiểm thử',
                'status': 'pending',
                'evidence': [
                  {'label': 'Tần suất', 'value': 'Cao'},
                ],
              },
            ],
          },
          '/api/admin/disputes' => {'disputes': []},
          '/api/admin/accounts' => {'accounts': []},
          '/api/admin/ops-accounts' => {'accounts': []},
          '/api/appraisals/queue' => {'items': []},
          '/api/appraisals/31' => {
            'listingId': '31',
            'title': 'Tin thẩm định kiểm thử',
            'description': 'Mô tả thử nghiệm',
            'condition': 'Tốt',
            'category': 'elec',
            'startingPrice': 1000000,
            'durationHours': 24,
            'status': 'pending_appraisal',
            'seller': {'storeName': 'Cửa hàng thử', 'rating': 4.8},
            'photos': [],
            'history': [],
          },
          '/api/warehouse/orders' => {
            'orders': [
              {
                'id': '42',
                'title': 'Đơn kho kiểm thử',
                'stage': 'inspecting',
                'paymentStatus': 'paid',
                'seller': {'storeName': 'Cửa hàng thử'},
                'buyer': {'name': 'Người mua thử', 'phone': '0900000000'},
                'shippingAddress': {
                  'addressLine': '1 Đường thử',
                  'city': 'TP.HCM',
                },
                'warehouse': {'orderCode': 'BV-161026-0042'},
                'shipment': null,
              },
            ],
          },
          '/api/auctions/1107' => detail('1107'),
          '/api/auctions/1108' => detail('1108'),
          '/api/auctions/1109' => detail('1109'),
          _ => unexpected('${request.method} ${request.url}'),
        };
        return http.Response(
          jsonEncode({'success': true, 'data': data}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..token = 'smoke-test-token';
    store = _SmokeStore(api);
  });

  tearDown(() {
    store.dispose();
    expect(
      unexpectedRequests,
      isEmpty,
      reason: 'Every API used by a screen must have an explicit fixture.',
    );
  });

  void viewport(WidgetTester tester, {Size size = const Size(1440, 1800)}) {
    // Wide smoke viewport for prototype screens and Ahem test font.
    // Phone layout/keyboard coverage remains in the feature-specific test files.
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> mount(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppStore>.value(
        value: store,
        child: MaterialApp(home: Scaffold(body: widget)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '${widget.runtimeType}');
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  Future<void> show(
    WidgetTester tester,
    Widget widget, {
    String? loginAs,
  }) async {
    if (loginAs != null) {
      store.logout();
      expect(store.login(loginAs, '123456'), isNull);
      api.token = 'smoke-test-token';
    }
    try {
      await mount(tester, widget);
    } finally {
      await unmount(tester);
    }
  }

  testWidgets('Đăng nhập & Đăng ký', (tester) async {
    viewport(tester, size: const Size(600, 1200));
    try {
      await mount(tester, const AuthLoginScreen());
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Mật khẩu'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await tester.pump();
      expect(find.text('Email chưa hợp lệ'), findsOneWidget);
      expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
      final register = find.text('Chưa có tài khoản? Đăng ký');
      await tester.ensureVisible(register);
      await tester.tap(register);
      await tester.pumpAndSettle();
      expect(find.byType(AuthRegisterScreen), findsOneWidget);
      expect(find.text('Họ và tên'), findsOneWidget);
      expect(find.text('Nhập lại mật khẩu'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(
        requests,
        isEmpty,
        reason: 'Invalid form must not call a real login API.',
      );
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('RootShell: chưa đăng nhập hiển thị form xác thực', (
    tester,
  ) async {
    viewport(tester);
    try {
      await mount(tester, const RootShell());
      expect(find.byType(AuthLoginScreen), findsOneWidget);
      expect(find.byType(BidderShell), findsNothing);
    } finally {
      await unmount(tester);
    }
  });

  for (final entry in <String, Type>{
    'long@sneakersg.vn': SellerShell,
    'khoa.tran@bidvibe.vn': AppraiserShell,
    'anh.pham@bidvibe.vn': WarehouseOpsScreen,
    'admin@bidvibe.vn': AdminShell,
  }.entries) {
    testWidgets('RootShell: mở shell theo role của ${entry.value}', (
      tester,
    ) async {
      viewport(tester);
      expect(store.login(entry.key, '123456'), isNull);
      try {
        await mount(tester, const RootShell());
        expect(find.byType(entry.value), findsOneWidget);
        await tester.tap(find.byTooltip('Đăng xuất').first);
        await tester.pumpAndSettle();
        expect(find.byType(AuthLoginScreen), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });
  }

  testWidgets('Bidder: shell API và các tab dùng RemoteAppStore', (
    tester,
  ) async {
    viewport(tester);
    expect(store.login('minhanh@gmail.com', '123456'), isNull);
    final events = _SmokeEvents();
    final notifications = NotificationController(
      repository: NotificationRepository(api),
      events: events,
    );
    try {
      await mount(tester, BidderShell(notifications: notifications));
      expect(find.text('Khám phá phiên đấu giá'), findsOneWidget);
      await tester.tap(find.text('Ví').last);
      await tester.pumpAndSettle();
      expect(requests, contains('GET /api/wallet'));
      await tester.tap(find.text('Thông báo').last);
      await tester.pumpAndSettle();
      expect(requests, contains('GET /api/notifications'));
      await tester.tap(find.text('Hồ sơ').last);
      await tester.pumpAndSettle();
      expect(find.text('Đơn hàng của tôi'), findsOneWidget);
      expect(requests, contains('GET /api/me'));
      expect(requests, contains('GET /api/orders/mine'));
      expect(tester.takeException(), isNull);
    } finally {
      await unmount(tester);
      notifications.dispose();
    }
  });

  testWidgets('Bidder: chi tiết API live, paused và ended', (tester) async {
    viewport(tester);
    expect(store.login('minhanh@gmail.com', '123456'), isNull);
    for (final id in ['1107', '1108', '1109']) {
      final events = _SmokeEvents();
      try {
        await mount(
          tester,
          AuctionDetailScreen(
            auctionId: id,
            repository: AuctionRepository(api),
            events: events,
          ),
        );
        expect(find.text('Bình gốm kiểm thử'), findsOneWidget);
        expect(requests, contains('GET /api/auctions/$id'));
      } finally {
        await unmount(tester);
        events.dispose();
      }
    }
  });

  testWidgets('Bidder: giữ kiểm tra các màn prototype còn lại', (tester) async {
    viewport(tester);
    for (final id in [
      'a1',
      'a2',
      'a3',
      'a4',
      'a5',
      'a6',
      'a7',
      'a8',
      'a9',
      'a10',
    ]) {
      await show(
        tester,
        BidderDetailScreen(auctionId: id),
        loginAs: 'minhanh@gmail.com',
      );
    }
    await show(
      tester,
      const BidderPaymentScreen(auctionId: 'a7'),
      loginAs: 'minhanh@gmail.com',
    );
    await show(
      tester,
      const BidderDoneScreen(auctionId: 'a8'),
      loginAs: 'minhanh@gmail.com',
    );
    await show(
      tester,
      const BidderDoneScreen(auctionId: 'a9'),
      loginAs: 'minhanh@gmail.com',
    );
    await show(
      tester,
      const BidderDoneScreen(auctionId: 'a10', justPaid: true),
      loginAs: 'minhanh@gmail.com',
    );
    await show(
      tester,
      const CustomerDisputeScreen(
        source: 'bidder',
        title: 'Máy chơi game',
        auctionId: 'a8',
      ),
      loginAs: 'minhanh@gmail.com',
    );
  });

  testWidgets('Bidder: chatbot và Hồ sơ dùng phiên hiện tại', (tester) async {
    viewport(tester);
    await show(
      tester,
      const CustomerChatbotScreen(),
      loginAs: 'minhanh@gmail.com',
    );
    await show(tester, const AuthProfileScreen(), loginAs: 'minhanh@gmail.com');
    expect(requests, contains('GET /api/me'));
    expect(requests.where((path) => path.startsWith('POST')), isEmpty);
  });

  testWidgets('Seller: shell và các màn prototype của từng gian hàng', (
    tester,
  ) async {
    viewport(tester);
    for (final email in [
      'long@sneakersg.vn',
      'ha@phocoxua.vn',
      'bao@retroaudio.vn',
      'hai@retrocamera.vn',
      'hoa@caonguyenxua.vn',
    ]) {
      await show(tester, const SellerShell(), loginAs: email);
    }
    await show(
      tester,
      const SellerEditScreen(listingId: 'Lr2'),
      loginAs: 'bao@retroaudio.vn',
    );
    await show(
      tester,
      const SellerEditScreen(listingId: 'Lr1'),
      loginAs: 'bao@retroaudio.vn',
    );
    await show(
      tester,
      const CustomerDisputeScreen(
        source: 'seller',
        title: 'x',
        listingId: 'Lr8',
      ),
      loginAs: 'bao@retroaudio.vn',
    );
  });

  testWidgets('Appraiser & Warehouse: màn ops tải dữ liệu API', (tester) async {
    viewport(tester);
    await show(tester, const AppraiserOpsScreen(), loginAs: 'khoa.tran@bidvibe.vn');
    await show(
      tester,
      const AppraiserOpsDetailScreen(listingId: '31'),
      loginAs: 'khoa.tran@bidvibe.vn',
    );
    await show(
      tester,
      const WarehouseOpsScreen(),
      loginAs: 'anh.pham@bidvibe.vn',
    );
    await show(tester, const WarehouseOpsDetailScreen(orderId: '42'), loginAs: 'anh.pham@bidvibe.vn');
  });

  testWidgets('Admin: shell, cờ và tranh chấp dùng API', (
    tester,
  ) async {
    viewport(tester);
    await show(tester, const AdminShell(), loginAs: 'admin@bidvibe.vn');
    await show(tester, const AdminOpsFlagDetailScreen(flagId: '1'), loginAs: 'admin@bidvibe.vn');
  });
}
