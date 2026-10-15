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
import 'package:bidvibe/screens/appraiser/appraiser_detail.dart';
import 'package:bidvibe/screens/warehouse/warehouse_board.dart';
import 'package:bidvibe/screens/warehouse/warehouse_detail.dart';
import 'package:bidvibe/screens/admin/admin_shell.dart';
import 'package:bidvibe/screens/admin/admin_flags.dart';
import 'package:bidvibe/screens/admin/admin_disputes.dart';
import 'package:bidvibe/screens/admin/admin_audit.dart';

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
    'anh.pham@bidvibe.vn': WarehouseBoardScreen,
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

  testWidgets('Appraiser & Warehouse: các màn prototype', (tester) async {
    viewport(tester);
    await show(tester, const AppraiserShell(), loginAs: 'khoa.tran@bidvibe.vn');
    await show(
      tester,
      const AppraiserDetailScreen(itemId: 'p1'),
      loginAs: 'khoa.tran@bidvibe.vn',
    );
    await show(
      tester,
      const AppraiserDetailScreen(itemId: 'p2'),
      loginAs: 'khoa.tran@bidvibe.vn',
    );
    await show(
      tester,
      const WarehouseBoardScreen(),
      loginAs: 'anh.pham@bidvibe.vn',
    );
    for (final shipment in store.warehouseShipments) {
      await show(
        tester,
        WarehouseDetailScreen(id: shipment.id),
        loginAs: 'anh.pham@bidvibe.vn',
      );
    }
  });

  testWidgets('Admin: shell, cờ, tranh chấp và nhật ký prototype', (
    tester,
  ) async {
    viewport(tester);
    await show(tester, const AdminShell(), loginAs: 'admin@bidvibe.vn');
    for (final flag in store.flags) {
      await show(
        tester,
        AdminFlagDetailScreen(flagId: flag.id),
        loginAs: 'admin@bidvibe.vn',
      );
    }
    for (final dispute in store.disputes) {
      await show(
        tester,
        AdminDisputeDetailScreen(disputeId: dispute.id),
        loginAs: 'admin@bidvibe.vn',
      );
    }
    await show(tester, const AdminAuditScreen(), loginAs: 'admin@bidvibe.vn');
  });
}
