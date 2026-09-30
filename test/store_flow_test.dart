import 'package:flutter_test/flutter_test.dart';

import 'package:bidvibe/models.dart';
import 'package:bidvibe/store.dart';

/// Kiểm tra logic nghiệp vụ trong AppStore (không cần UI): xác thực, luồng
/// chính end-to-end và các việc của System Scheduler (tick chạy mỗi giây
/// nên các test dùng `Future.delayed` để chờ một nhịp).
void main() {
  late AppStore s;

  setUp(() => s = AppStore());
  tearDown(() => s.dispose());

  Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 1300));
  Auction auction(String id) => s.auctions.firstWhere((a) => a.id == id);

  group('Xác thực', () {
    test('đăng nhập đúng, sai mật khẩu và tài khoản bị khoá', () {
      expect(s.login('minhanh@gmail.com', 'sai'), isNotNull);
      expect(s.currentUser, isNull);
      expect(s.login('yen.vu@bidvibe.vn', '123456'), contains('khoá'));
      expect(s.login('minhanh@gmail.com', '123456'), isNull);
      expect(s.currentUser!.role, 'bidder');
    });

    test('tài khoản bật 2 lớp cần OTP', () {
      expect(s.login('chau.le@outlook.com', '123456'), 'OTP_REQUIRED');
      expect(s.login('chau.le@outlook.com', '123456', otp: '000000'), isNotNull);
      expect(s.login('chau.le@outlook.com', '123456', otp: '123456'), isNull);
    });

    test('đăng ký trùng email bị chặn, đăng ký mới tự đăng nhập', () {
      expect(s.register(name: 'A', email: 'minhanh@gmail.com', phone: '0900000000', password: '123456', role: 'bidder'), isNotNull);
      expect(s.register(name: 'Người Mới', email: 'moi@x.vn', phone: '0900000000', password: '123456', role: 'seller', shop: 'Shop Mới'), isNull);
      expect(s.currentUser!.shop, 'Shop Mới');
    });

    test('đổi mật khẩu', () {
      s.login('minhanh@gmail.com', '123456');
      expect(s.changePassword('sai', 'abcdef'), isNotNull);
      expect(s.changePassword('123456', 'abc'), isNotNull);
      expect(s.changePassword('123456', 'abcdef'), isNull);
      s.logout();
      expect(s.login('minhanh@gmail.com', 'abcdef'), isNull);
    });
  });

  group('Dữ liệu mẫu', () {
    test('mỗi vai trò có ít nhất 3 tài khoản và không màn hình nào rỗng', () {
      for (final r in ['bidder', 'seller', 'appraiser', 'warehouse', 'admin']) {
        expect(s.users.where((u) => u.role == r).length, greaterThanOrEqualTo(3), reason: r);
      }
      expect(s.auctions.length, greaterThanOrEqualTo(6));
      expect(s.auctions.every((a) => a.hist.length >= 3), isTrue);
      expect(s.appraisalQueue, isNotEmpty);
      expect(s.flags.length, greaterThanOrEqualTo(1));
      expect(s.openDisputesCount, greaterThanOrEqualTo(1));
      for (final st in ['waiting', 'inspecting', 'inspecting_done', 'packed', 'shipped', 'delivered', 'escalated']) {
        expect(s.warehouseShipments.any((w) => w.status == st), isTrue, reason: st);
      }
      for (final shop in s.users.where((u) => u.role == 'seller').map((u) => u.shop)) {
        expect(s.sellerListings.where((l) => l.seller == shop), isNotEmpty, reason: '$shop');
      }
    });

    test('ví khớp tổng cọc đang giữ trên các phiên', () {
      final held = s.auctions.fold<int>(0, (t, a) => t + a.hold);
      expect(s.walletHeld, held);
    });
  });

  group('Luồng chính', () {
    test('đặt cọc → đặt giá → thắng → thanh toán → gửi kho → kiểm → giao → xác nhận', () async {
      s.login('minhanh@gmail.com', '123456');
      final a = auction('a1');
      s.placeBid(a.id, 50000);
      expect(a.leading, isFalse, reason: 'chưa đặt cọc thì không được đặt giá');

      final w0 = s.wallet;
      s.joinAuction(a.id);
      expect(a.joined, isTrue);
      expect(s.wallet, w0 - a.deposit);
      s.placeBid(a.id, 50000);
      expect(a.leading, isTrue);

      a.botBudget = 0;
      a.endsAt = DateTime.now().subtract(const Duration(seconds: 1));
      await tick();
      expect(a.ended && a.won, isTrue);
      expect(a.payBy, isNotNull);

      s.payForAuction(a.id, due: a.totalDue - a.hold, method: 'wallet');
      expect(a.paid, isTrue);
      expect(a.escrow, a.totalDue);
      final sh = s.sellerShipments.firstWhere((x) => x.id == a.listingId);
      expect(sh.at, 1);

      s.sellerMarkShipped(sh.id);
      expect(sh.at, 2);
      final wh = s.warehouseShipments.firstWhere((x) => x.id == sh.id);
      expect(wh.status, 'waiting');
      s.whConfirmReceive(wh.id);
      expect(a.fulfil, 'inspecting');
      s.whConfirmInspect(wh.id, grade: 'Tốt', shelf: 'Kệ A1-01');
      s.whMarkPacked(wh.id);
      s.whMarkShipped(wh.id, carrier: 'GHN Express');
      expect(wh.tracking, isNotNull);
      expect(sh.at, 3);
      s.whMarkDelivered(wh.id);
      expect(a.fulfil, 'delivered');

      s.confirmDelivery(a.id);
      expect(a.fulfil, 'confirmed');
      expect(a.escrow, 0);
      expect(sh.at, 5);
      expect(s.sellerListings.firstWhere((l) => l.id == sh.id).status, 'sold');
    });

    test('Seller tạo phiếu → Thẩm định duyệt → phiên công khai cho Bidder', () {
      s.login('long@sneakersg.vn', '123456');
      s.createListing(title: 'Giày thử nghiệm', cat: 'shoes', start: 1000000, desc: 'mô tả', cond: 'Như mới', durationHours: 72, photos: 3);
      final l = s.myListings.first;
      expect(l.status, 'appraisal');
      final item = s.appraisalQueue.firstWhere((i) => i.listingId == l.id);
      s.requestMoreInfo(item.id, ['photos']);
      expect(l.status, 'needinfo');
      expect(s.updateListing(l.id, title: 'Giày thử nghiệm 2', desc: 'x', start: 1200000, durationHours: 24, cond: 'Mới'), isTrue);
      s.sellerSubmitMoreInfo(l.id);
      expect(l.status, 'appraisal');
      final n = s.auctions.length;
      s.approveAppraisal(item.id);
      expect(s.auctions.length, n + 1);
      expect(l.status, 'live');
      expect(l.auctionId, isNotNull);
      expect(s.updateListing(l.id, title: 'Sửa khi live, chưa có bid', desc: 'x', start: 1300000, durationHours: 24, cond: 'Mới'), isTrue);
    });
  });

  group('System Scheduler', () {
    test('tự đóng phiên và tự hoàn cọc người không thắng', () async {
      s.login('minhanh@gmail.com', '123456');
      final a = auction('a4'); // Bidder đã cọc nhưng đang bị vượt giá
      expect(a.joined && !a.leading, isTrue);
      final before = s.wallet;
      final held = a.hold;
      a.botBudget = 0;
      a.endsAt = DateTime.now().subtract(const Duration(seconds: 1));
      await tick();
      expect(a.ended, isTrue);
      expect(a.won, isFalse);
      expect(a.hold, 0);
      expect(s.wallet, before + held);
      expect(s.notifications.any((n) => n.kind == 'refund' && n.targetAuctionId == a.id), isTrue);
    });

    test('quá hạn thanh toán 24 giờ thì mất cọc và huỷ giao dịch', () async {
      s.login('minhanh@gmail.com', '123456');
      final a = auction('a7');
      final held = s.walletHeld;
      final dep = a.hold;
      s.demoExpirePayment(a.id);
      await tick();
      expect(a.paymentExpired, isTrue);
      expect(s.walletHeld, held - dep);
      expect(s.sellerListings.firstWhere((l) => l.id == a.listingId).status, 'cancelled');
    });

    test('tự giải ngân ký quỹ sau 72 giờ kể từ khi giao', () async {
      s.login('minhanh@gmail.com', '123456');
      final a = auction('a8');
      expect(a.fulfil, 'delivered');
      s.demoAutoRelease(a.id);
      await tick();
      expect(a.fulfil, 'confirmed');
      expect(a.escrow, 0);
    });

    test('người thắng khác tự thanh toán sau khi phiên đóng, Seller nhận phiếu gửi kho', () async {
      final a = auction('a5'); // Bidder không tham gia
      a.botBudget = 0;
      a.endsAt = DateTime.now().subtract(const Duration(seconds: 1));
      await tick();
      expect(a.ended, isTrue);
      expect(a.autoPayAt, isNotNull);
      a.autoPayAt = DateTime.now().subtract(const Duration(seconds: 1));
      await tick();
      expect(a.paid, isTrue);
      expect(s.sellerShipments.any((x) => x.id == a.listingId && x.at == 1), isTrue);
    });
  });

  group('Admin', () {
    test('tạm dừng đóng băng phiên, chấm dứt khẩn cấp hoàn cọc', () {
      s.login('admin@bidvibe.vn', '123456');
      final a = auction('a3'); // Bidder đang dẫn đầu, cọc 400.000
      final before = s.wallet;
      s.setFlagStatus('f3', 'paused');
      expect(a.paused, isTrue);
      s.emergencyTerminate('f3', 'Nghi thông đồng');
      expect(a.ended && a.terminated && !a.won, isTrue);
      expect(s.wallet, before + 400000);
      expect(s.flags.firstWhere((f) => f.id == 'f3').status, 'terminated');
      expect(s.auditLogs.first.action, contains('Chấm dứt khẩn cấp'));
    });

    test('phán quyết tranh chấp hoàn tiền người mua', () {
      s.login('admin@bidvibe.vn', '123456');
      final a = auction('a8');
      s.raiseDispute(source: 'bidder', auctionId: a.id, title: a.title, reason: 'Hàng không đúng mô tả');
      final d = s.disputes.first;
      expect(d.escrow, a.escrow);
      expect(a.disputed, isTrue);
      final before = s.wallet;
      final amt = a.escrow;
      s.resolveDispute(d.id, 'refund');
      expect(d.status, 'resolved');
      expect(s.wallet, before + amt);
      expect(a.fulfil, 'refunded');
    });

    test('báo cáo phiên đáng ngờ tạo cờ mới hoặc tăng số báo cáo', () {
      s.login('minhanh@gmail.com', '123456');
      final n = s.flags.length;
      s.reportSuspicious('a5', 'Nghi ngờ đặt giá ảo / thông đồng', '');
      expect(s.flags.length, n + 1);
      s.reportSuspicious('a5', 'Lý do khác', '');
      expect(s.flags.length, n + 1);
      expect(s.flags.firstWhere((f) => f.auctionId == 'a5').reports, 2);
    });
  });
}
