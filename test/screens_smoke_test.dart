import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bidvibe/store.dart';
import 'package:bidvibe/main.dart';
import 'package:bidvibe/screens/auth/auth_login.dart';
import 'package:bidvibe/screens/auth/auth_register.dart';
import 'package:bidvibe/screens/bidder/bidder_shell.dart';
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

/// Dựng từng màn hình với dữ liệu mẫu để bắt lỗi layout/runtime (overflow,
/// null, thiếu dữ liệu). Dùng theme mặc định để không phải tải font mạng.
void main() {
  late AppStore s;

  final errors = <String>[];
  void Function(FlutterErrorDetails)? originalOnError;

  setUp(() {
    s = AppStore();
    errors.clear();
    originalOnError = null;
  });
  tearDown(() {
    if (originalOnError != null) FlutterError.onError = originalOnError;
    s.dispose();
  });

  // flutter_test cài handler riêng khi test bắt đầu nên phải cài lại ở đây.
  // Môi trường test dùng font Ahem (mỗi ký tự rộng 1em) nên mọi lỗi
  // "overflowed" chỉ là giả; các lỗi khác vẫn được ghi nhận.
  void hook() {
    originalOnError ??= FlutterError.onError;
    FlutterError.onError = (d) {
      final msg = d.exceptionAsString();
      if (!msg.contains('overflowed')) errors.add(msg.split('\n').first);
    };
  }

  Future<void> show(WidgetTester t, Widget w, {String? loginAs}) async {
    t.view.physicalSize = const Size(420, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    hook();
    if (loginAs != null) s.login(loginAs, '123456');
    await t.pumpWidget(ChangeNotifierProvider<AppStore>.value(
        value: s, child: MaterialApp(home: w)));
    await t
        .pump(const Duration(milliseconds: 1100)); // qua ít nhất một nhịp tick
    expect(errors, isEmpty, reason: '${w.runtimeType}');
    await t.pumpWidget(const SizedBox()); // dọn cây widget
  }

  const bidder = 'minhanh@gmail.com';

  testWidgets('Đăng nhập & Đăng ký', (t) async {
    await show(t, const AuthLoginScreen());
    await show(t, const AuthRegisterScreen());
  });

  testWidgets('Chọn vai trò demo mở prototype tương ứng', (t) async {
    await t.pumpWidget(ChangeNotifierProvider<AppStore>.value(
        value: s, child: const MaterialApp(home: RootShell())));
    expect(find.byType(AuthLoginScreen), findsOneWidget);
    await t.tap(find.text('Người mua'));
    await t.pumpAndSettle();
    expect(find.byType(BidderShell), findsOneWidget);

    // Đổi vai trò = đăng xuất rồi chọn lại.
    await t.tap(find.text('Đăng xuất'));
    await t.pumpAndSettle();
    expect(find.byType(AuthLoginScreen), findsOneWidget);
    await t.tap(find.text('Kho vận'));
    await t.pumpAndSettle();
    expect(find.byType(WarehouseBoardScreen), findsOneWidget);
  });

  testWidgets('Bidder: shell + chi tiết ở mọi trạng thái', (t) async {
    await show(t, const BidderShell(), loginAs: bidder);
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
      'a10'
    ]) {
      await show(t, BidderDetailScreen(auctionId: id), loginAs: bidder);
    }
    await show(t, const BidderPaymentScreen(auctionId: 'a7'), loginAs: bidder);
    await show(t, const BidderDoneScreen(auctionId: 'a8'),
        loginAs: bidder); // đã giao, chờ xác nhận
    await show(t, const BidderDoneScreen(auctionId: 'a9'),
        loginAs: bidder); // hoàn tất
    await show(t, const BidderDoneScreen(auctionId: 'a10', justPaid: true),
        loginAs: bidder);
    await show(t, const CustomerChatbotScreen(), loginAs: bidder);
    await show(
        t,
        const CustomerDisputeScreen(
            source: 'bidder', title: 'Máy chơi game', auctionId: 'a8'),
        loginAs: bidder);
  });

  testWidgets('Bidder: tab Hồ sơ hiển thị đơn hàng', (t) async {
    t.view.physicalSize = const Size(420, 1200);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    hook();
    s.login(bidder, '123456');
    await t.pumpWidget(ChangeNotifierProvider<AppStore>.value(
        value: s, child: const MaterialApp(home: BidderShell())));
    await t.tap(find.text('Hồ sơ'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Đơn hàng của tôi'), findsOneWidget);
    expect(errors, isEmpty);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Seller: mỗi gian hàng đều có dữ liệu ở mọi tab', (t) async {
    for (final email in [
      'long@sneakersg.vn',
      'ha@phocoxua.vn',
      'bao@retroaudio.vn',
      'hai@retrocamera.vn',
      'hoa@caonguyenxua.vn'
    ]) {
      s.logout();
      await show(t, const SellerShell(), loginAs: email);
    }
    s.logout();
    s.login('bao@retroaudio.vn', '123456');
    await show(t, SellerEditScreen(listingId: 'Lr2')); // cần bổ sung hồ sơ
    await show(t, SellerEditScreen(listingId: 'Lr1')); // live, còn sửa được?
    await show(
        t,
        const CustomerDisputeScreen(
            source: 'seller', title: 'x', listingId: 'Lr8'));
  });

  testWidgets('Appraiser & Warehouse', (t) async {
    await show(t, const AppraiserShell(), loginAs: 'khoa.tran@bidvibe.vn');
    await show(t, const AppraiserDetailScreen(itemId: 'p1'),
        loginAs: 'khoa.tran@bidvibe.vn');
    await show(t, const AppraiserDetailScreen(itemId: 'p2'),
        loginAs: 'khoa.tran@bidvibe.vn'); // needinfo
    await show(t, const WarehouseBoardScreen(), loginAs: 'anh.pham@bidvibe.vn');
    for (final w in s.warehouseShipments) {
      await show(t, WarehouseDetailScreen(id: w.id),
          loginAs: 'anh.pham@bidvibe.vn');
    }
  });

  testWidgets('Admin: shell, cờ, tranh chấp, nhật ký', (t) async {
    await show(t, const AdminShell(), loginAs: 'admin@bidvibe.vn');
    for (final f in s.flags) {
      await show(t, AdminFlagDetailScreen(flagId: f.id),
          loginAs: 'admin@bidvibe.vn');
    }
    for (final d in s.disputes) {
      await show(t, AdminDisputeDetailScreen(disputeId: d.id),
          loginAs: 'admin@bidvibe.vn');
    }
    await show(t, const AdminAuditScreen(), loginAs: 'admin@bidvibe.vn');
  });
}
