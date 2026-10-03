import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'models.dart';

/// Store trung tâm, giữ toàn bộ dữ liệu giả lập của app và logic nghiệp
/// vụ dùng chung cho 5 vai trò (Bidder, Seller, Thẩm định, Kho vận,
/// Admin). Đây KHÔNG phải backend thật — mọi thứ chạy trong bộ nhớ của
/// app, mất khi tắt app. Một hành động ở vai trò này (ví dụ Kho báo cáo
/// sai lệch) phản ánh ngay sang vai trò khác (Admin thấy tranh chấp mới)
/// vì tất cả cùng đọc từ store này.
///
/// Luồng chính được nối end-to-end trong store:
///   Seller tạo phiếu → Thẩm định duyệt (công khai phiên) → Bidder đặt cọc
///   tham gia & đặt giá → hệ thống tự đóng phiên → thắng thì thanh toán
///   (tiền vào ký quỹ) → Seller gửi kho → Kho nhận/kiểm/gửi đi → Bidder
///   xác nhận nhận hàng → ký quỹ giải ngân cho Seller.
///
/// Phần "System Scheduler" (không có UI) nằm ở [_tick] và các hàm
/// `_autoCloseExpired`, `_processPaymentTimeouts`, `_autoReleaseEscrow`;
/// hoàn cọc người thua nằm trong [_closeAuction].
class AppStore extends ChangeNotifier {
  final _rnd = Random();
  Timer? _timer;

  static const _me = 'Bạn';
  static const _otpDemo = '123456';
  static const _bots = ['bidder_7f2a', 'bidder_c91d', 'bidder_2b8e', 'bidder_e40a', 'bidder_51fb'];

  /// Thông tin giao hàng giả lập của các bidder ẩn danh (khớp tài khoản mẫu).
  static const _fakeBuyers = {
    'bidder_7f2a': ('Trần Quốc Việt', '0912 445 566', '12 Phố Huế, Hai Bà Trưng, Hà Nội'),
    'bidder_c91d': ('Lê Bảo Châu', '0938 778 899', '27 Nguyễn Văn Linh, Hải Châu, Đà Nẵng'),
    'bidder_2b8e': ('Phan Đức Thịnh', '0977 300 121', '88 Lý Thường Kiệt, Q.10, TP.HCM'),
    'bidder_e40a': ('Hồ Thanh Mai', '0968 221 908', '5 Trần Phú, Nha Trang, Khánh Hoà'),
    'bidder_51fb': ('Vũ Anh Dũng', '0355 640 772', '41 Nguyễn Trãi, Thanh Xuân, Hà Nội'),
  };

  AppStore() {
    _seed();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _toastTimer?.cancel();
    super.dispose();
  }

  // ---------------- Tài khoản / phiên đăng nhập ----------------
  final List<UserAccount> users = [];
  UserAccount? currentUser;

  // ---------------- Bidder ----------------
  int wallet = 0;
  int walletHeld = 0;
  final List<WalletTx> walletTxs = [];
  final List<Auction> auctions = [];
  final List<AppNotification> notifications = [];
  String? toastId;
  String toastTitle = '';
  String toastBody = '';
  bool toastIsDanger = false;
  bool toastIsSuccess = false;
  String? toastTargetAuction;
  bool toastTargetIsPay = false;
  bool toastTargetIsWallet = false;
  bool toastTargetIsOrder = false;
  Timer? _toastTimer;

  // ---------------- Seller ----------------
  final List<SellerListing> sellerListings = [];
  final List<Shipment> sellerShipments = [];

  // ---------------- Appraiser ----------------
  final List<AppraisalItem> appraisalQueue = [];
  final List<AppraisalHistoryEntry> appraisalHistory = [];

  // ---------------- Warehouse ----------------
  final List<WarehouseShipment> warehouseShipments = [];

  // ---------------- Admin ----------------
  final List<FlaggedAuction> flags = [];
  final List<Dispute> disputes = [];
  final List<AuditEntry> auditLogs = [];

  int get unreadNotifications => notifications.where((n) => n.unread).length;
  int get openFlagsCount => flags.where((f) => f.status == 'open').length;
  int get openDisputesCount => disputes.where((d) => d.status == 'open').length;

  // Số liệu tổng hợp cho Dashboard/Báo cáo của Admin.
  int get liveAuctionsCount => auctions.where((a) => !a.ended).length;
  int get endingIn24hCount => auctions.where((a) => !a.ended && a.endsAt.difference(DateTime.now()).inHours < 24).length;
  int get appraisalPendingCount => appraisalQueue.length;
  int get whWaitingCount => warehouseShipments.where((w) => w.status == 'waiting').length;
  int get whToDeliverCount => warehouseShipments.where((w) => w.status == 'inspecting_done' || w.status == 'packed' || w.status == 'shipped').length;
  int get escrowHeldTotal {
    final inAuctions = auctions.fold<int>(0, (s, a) => s + a.escrow);
    final inOthers = sellerShipments.where((s) => s.at >= 1 && s.at <= 4 && !auctions.any((a) => a.listingId == s.id)).fold<int>(0, (s, x) => s + x.amount);
    return inAuctions + inOthers;
  }

  /// Tên gian hàng của tài khoản Seller đang đăng nhập.
  String get myShop => currentUser?.shop ?? 'Retro Audio HN';
  List<SellerListing> get myListings => sellerListings.where((l) => l.seller == myShop).toList();
  List<Shipment> get myShipments => sellerShipments.where((s) => s.seller == myShop).toList();

  /// Các phiên mà bidder demo đã thắng (dùng cho mục "Đơn hàng của tôi").
  List<Auction> get myOrders => auctions.where((a) => a.ended && a.won && a.joined).toList()..sort((x, y) => (y.endedAt ?? y.endsAt).compareTo(x.endedAt ?? x.endsAt));

  UserAccount get _demoBidder => currentUser?.role == 'bidder' ? currentUser! : users.firstWhere((u) => u.role == 'bidder');

  String fmt(num n) {
    final s = n.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write('.');
    }
    return buf.toString();
  }

  String money(num n) => '${fmt(n)} ₫';

  String _dm(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  // ---------------- Tra cứu nhanh ----------------
  Auction? _auction(String? id) {
    if (id == null) return null;
    for (final a in auctions) {
      if (a.id == id) return a;
    }
    return null;
  }

  SellerListing? _listing(String? id) {
    if (id == null) return null;
    for (final l in sellerListings) {
      if (l.id == id) return l;
    }
    return null;
  }

  Shipment? _shipment(String? listingId) {
    if (listingId == null) return null;
    for (final s in sellerShipments) {
      if (s.id == listingId) return s;
    }
    return null;
  }

  WarehouseShipment? _wh(String? id) {
    if (id == null) return null;
    for (final w in warehouseShipments) {
      if (w.id == id) return w;
    }
    return null;
  }

  AppraisalItem? _appraisalOfListing(String? listingId) {
    if (listingId == null) return null;
    for (final i in appraisalQueue) {
      if (i.listingId == listingId) return i;
    }
    return null;
  }

  void _log(String kind, String action, {String? actor, String? ref, int? amount}) {
    final now = DateTime.now();
    auditLogs.insert(0, AuditEntry(id: 'log${now.microsecondsSinceEpoch}', at: now, kind: kind, actor: actor ?? 'Hệ thống', action: action, ref: ref, amount: amount));
    if (auditLogs.length > 300) auditLogs.removeRange(300, auditLogs.length);
  }

  void _showToast({
    required String title,
    required String body,
    bool danger = false,
    bool success = false,
    String? targetAuction,
    bool targetIsPay = false,
    bool targetIsWallet = false,
    bool targetIsOrder = false,
    int seconds = 4,
  }) {
    toastId = '${DateTime.now().microsecondsSinceEpoch}';
    toastTitle = title;
    toastBody = body;
    toastIsDanger = danger;
    toastIsSuccess = success;
    toastTargetAuction = targetAuction;
    toastTargetIsPay = targetIsPay;
    toastTargetIsWallet = targetIsWallet;
    toastTargetIsOrder = targetIsOrder;
    _toastTimer?.cancel();
    _toastTimer = Timer(Duration(seconds: seconds), () {
      toastId = null;
      notifyListeners();
    });
  }

  void dismissToast() {
    toastId = null;
    _toastTimer?.cancel();
    notifyListeners();
  }

  // ================= Xác thực tài khoản =================

  /// Trả về `null` nếu đăng nhập thành công, `'OTP_REQUIRED'` nếu tài khoản
  /// bật xác thực 2 lớp và chưa nhập mã, hoặc thông báo lỗi để hiển thị.
  String? login(String email, String password, {String? otp}) {
    final e = email.trim().toLowerCase();
    UserAccount? u;
    for (final x in users) {
      if (x.email.toLowerCase() == e) u = x;
    }
    if (u == null || u.password != password) return 'Email hoặc mật khẩu không đúng.';
    if (u.status != 'active') return 'Tài khoản đã bị tạm khoá. Vui lòng liên hệ bộ phận hỗ trợ.';
    if (u.twoFactor) {
      if (otp == null) return 'OTP_REQUIRED';
      if (otp != _otpDemo) return 'Mã OTP không đúng.';
    }
    currentUser = u;
    _log('system', 'Đăng nhập', actor: u.name, ref: u.roleLabel);
    notifyListeners();
    return null;
  }

  void loginAs(UserAccount u) {
    currentUser = u;
    _log('system', 'Đăng nhập nhanh (demo)', actor: u.name, ref: u.roleLabel);
    notifyListeners();
  }

  void logout() {
    if (currentUser != null) _log('system', 'Đăng xuất', actor: currentUser!.name);
    currentUser = null;
    notifyListeners();
  }

  /// Trả về `null` nếu thành công (và tự đăng nhập), hoặc thông báo lỗi.
  String? register({required String name, required String email, required String phone, required String password, required String role, String? shop}) {
    final e = email.trim().toLowerCase();
    if (users.any((u) => u.email.toLowerCase() == e)) return 'Email này đã được đăng ký.';
    final u = UserAccount(
      id: 'u${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      email: e,
      phone: phone.trim(),
      role: role,
      password: password,
      shop: role == 'seller' ? (shop?.trim().isNotEmpty == true ? shop!.trim() : name.trim()) : null,
    );
    users.add(u);
    currentUser = u;
    _log('system', 'Đăng ký tài khoản mới', actor: u.name, ref: u.roleLabel);
    notifyListeners();
    return null;
  }

  /// Chuyển nhanh sang một tài khoản mẫu của vai trò khác (thanh DEMO).
  void switchDemoRole(String role) {
    if (currentUser?.role == role) return;
    for (final u in users) {
      if (u.role == role && u.status == 'active') {
        currentUser = u;
        notifyListeners();
        return;
      }
    }
  }

  void updateProfile({required String name, required String phone, required String address}) {
    final u = currentUser;
    if (u == null) return;
    u.name = name.trim();
    u.phone = phone.trim();
    u.address = address.trim();
    _log('system', 'Cập nhật hồ sơ', actor: u.name);
    notifyListeners();
  }

  String? changePassword(String current, String next) {
    final u = currentUser;
    if (u == null) return 'Bạn chưa đăng nhập.';
    if (u.password != current) return 'Mật khẩu hiện tại không đúng.';
    if (next.length < 6) return 'Mật khẩu mới cần tối thiểu 6 ký tự.';
    u.password = next;
    _log('system', 'Đổi mật khẩu', actor: u.name);
    notifyListeners();
    return null;
  }

  void setTwoFactor(bool on) {
    final u = currentUser;
    if (u == null) return;
    u.twoFactor = on;
    _log('system', on ? 'Bật xác thực 2 lớp' : 'Tắt xác thực 2 lớp', actor: u.name);
    notifyListeners();
  }

  // ================= Bidder actions =================

  /// Đặt cọc tham gia phiên (Place Auction Deposit). Chỉ khi đã cọc mới
  /// được đặt giá. Cọc được giữ tới khi phiên đóng: người thua được tự
  /// động hoàn, người thắng được trừ vào tổng tiền thanh toán.
  void joinAuction(String auctionId) {
    final a = _auction(auctionId);
    if (a == null || a.ended || a.joined || a.paused) return;
    final dep = a.deposit;
    if (dep > wallet) {
      _showToast(
        title: 'Số dư chưa đủ để đặt cọc',
        body: 'Cần thêm ${money(dep - wallet)} — chạm để nạp tiền',
        danger: true,
        targetIsWallet: true,
      );
      notifyListeners();
      return;
    }
    final now = DateTime.now();
    wallet -= dep;
    walletHeld += dep;
    a.hold = dep;
    a.joined = true;
    walletTxs.insert(0, WalletTx(id: 'h${now.microsecondsSinceEpoch}', kind: 'hold', label: 'Đặt cọc tham gia · ${a.title}', amount: -dep, at: now));
    _log('wallet', 'Đặt cọc tham gia phiên', actor: _demoBidder.name, ref: a.title, amount: dep);
    _showToast(title: 'Đã đặt cọc tham gia', body: 'Giữ ${money(dep)} cho phiên này. Bạn có thể đặt giá ngay.', success: true, seconds: 3);
    notifyListeners();
  }

  void placeBid(String auctionId, int inc) {
    final a = _auction(auctionId);
    if (a == null || a.ended || a.leading || a.paused) return;
    if (!a.joined) {
      _showToast(title: 'Cần đặt cọc trước', body: 'Đặt cọc tham gia để bắt đầu đặt giá.', danger: true, seconds: 3);
      notifyListeners();
      return;
    }
    final now = DateTime.now();
    final amt = a.price + inc;
    bool extended = false;
    if (a.endsAt.difference(now).inSeconds <= 30) {
      a.endsAt = now.add(const Duration(seconds: 30));
      extended = true;
    }
    a.price = amt;
    a.count += 1;
    a.leading = true;
    a.myBid = amt;
    a.lastBidAt = now;
    a.hist.insert(0, Bid(who: _me, amount: amt, at: now, me: true));
    if (a.hist.length > 8) a.hist.removeRange(8, a.hist.length);
    _log('auction', 'Đặt giá', actor: _demoBidder.name, ref: a.title, amount: amt);

    _showToast(
      title: 'Đặt giá thành công',
      body: extended ? 'Phiên được gia hạn thêm 30 giây.' : 'Bạn đang dẫn đầu với ${money(amt)}.',
      success: true,
      seconds: 3,
    );
    notifyListeners();
  }

  void topUp(int amount, String method) {
    final now = DateTime.now();
    wallet += amount;
    walletTxs.insert(
      0,
      WalletTx(id: 'u${now.microsecondsSinceEpoch}', kind: 'topup', label: 'Nạp tiền qua ${method == 'qr' ? 'VietQR' : 'thẻ nội địa'}', amount: amount, at: now),
    );
    _log('wallet', 'Nạp tiền vào ví', actor: _demoBidder.name, ref: method == 'qr' ? 'VietQR' : 'Thẻ nội địa', amount: amount);
    _showToast(title: 'Nạp tiền thành công', body: 'Đã cộng ${money(amount)} vào ví.', success: true, seconds: 3);
    notifyListeners();
  }

  /// Thanh toán khoản còn lại. Toàn bộ tiền (giá + phí + vận chuyển) đi
  /// vào ký quỹ; chỉ được giải ngân cho người bán khi bidder xác nhận nhận
  /// hàng (hoặc hệ thống tự giải ngân sau 72 giờ).
  void payForAuction(String auctionId, {required int due, required String method}) {
    final a = _auction(auctionId);
    if (a == null || a.paid) return;
    final now = DateTime.now();
    final held = a.hold;
    walletHeld -= held;
    a.hold = 0;
    if (method == 'wallet') {
      wallet -= due;
      walletTxs.insert(0, WalletTx(id: 'p${now.microsecondsSinceEpoch}', kind: 'pay', label: 'Thanh toán · ${a.title} (đã trừ cọc ${money(held)})', amount: -due, at: now));
    }
    _log('payment', 'Thanh toán đơn thắng đấu giá (vào ký quỹ)', actor: _demoBidder.name, ref: a.title, amount: a.totalDue);
    _startFulfilment(a);
    notifyListeners();
  }

  void markNotificationsRead() {
    for (final n in notifications) {
      n.unread = false;
    }
    notifyListeners();
  }

  /// Xác nhận đã nhận hàng (Confirm Item Delivery) → giải ngân ký quỹ.
  void confirmDelivery(String auctionId) {
    final a = _auction(auctionId);
    if (a == null || a.fulfil != 'delivered') return;
    _releaseEscrow(a, auto: false);
    notifyListeners();
  }

  /// Bidder báo cáo phiên đáng ngờ (Report Suspicious Auction) → tạo/nâng
  /// một mục trong "Phiên bị gắn cờ" của Admin.
  void reportSuspicious(String auctionId, String reason, String note) {
    final a = _auction(auctionId);
    if (a == null) return;
    FlaggedAuction? f;
    for (final x in flags) {
      if (x.auctionId == auctionId) f = x;
    }
    if (f != null) {
      f.reports += 1;
      if (f.status == 'safe') f.status = 'open';
    } else {
      flags.insert(
        0,
        FlaggedAuction(
          id: 'f${DateTime.now().microsecondsSinceEpoch}',
          code: '#A-${2050 + flags.length}',
          title: a.title,
          severity: 'medium',
          status: 'open',
          confidence: 45,
          reason: 'Người dùng báo cáo: $reason',
          explain:
              'Một người dùng báo cáo phiên này với lý do "$reason"${note.trim().isEmpty ? '' : ' (ghi chú: ${note.trim()})'}. AI đang đối chiếu lịch sử đặt giá, thiết bị và địa chỉ IP của các bên; hiện chưa đủ dữ liệu để kết luận, cần Admin xem xét.',
          evidence: [('Lý do báo cáo', reason), ('Số báo cáo từ người dùng', '1'), ('Số lượt đặt giá', '${a.count}')],
          auctionId: a.id,
          reports: 1,
        ),
      );
    }
    _log('auction', 'Báo cáo phiên đáng ngờ', actor: _demoBidder.name, ref: a.title);
    _showToast(title: 'Đã gửi báo cáo', body: 'Cảm ơn bạn. Admin sẽ xem xét phiên này.', success: true, seconds: 3);
    notifyListeners();
  }

  /// Bidder hoặc Seller mở tranh chấp (Raise Dispute).
  void raiseDispute({
    required String source, // bidder | seller
    String? auctionId,
    String? listingId,
    required String title,
    required String reason,
    String detail = '',
  }) {
    final now = DateTime.now();
    final a = _auction(auctionId);
    final l = _listing(listingId ?? a?.listingId);
    final sh = _shipment(l?.id);
    final amount = a?.price ?? sh?.amount ?? 0;
    final escrow = a?.escrow ?? sh?.amount ?? 0;
    final who = source == 'bidder' ? 'Người mua' : 'Người bán';
    disputes.insert(
      0,
      Dispute(
        id: 'd${now.microsecondsSinceEpoch}',
        code: '#TC-${120 + disputes.length}',
        source: source,
        title: title,
        status: 'open',
        summary: detail.trim().isEmpty ? reason : '$reason — ${detail.trim()}',
        when: 'Vừa xong',
        amount: amount,
        escrow: escrow,
        auctionId: a?.id,
        listingId: l?.id,
        timeline: [('1', '$who mở tranh chấp: $reason.'), if (detail.trim().isNotEmpty) ('2', detail.trim()), ('3', 'Khoản ký quỹ được giữ lại cho tới khi Admin phán quyết.')],
      ),
    );
    if (a != null) a.disputed = true;
    if (l != null) l.status = 'disputed';
    _log('admin', 'Mở tranh chấp', actor: who, ref: title);
    _showToast(title: 'Đã gửi tranh chấp', body: 'Ký quỹ được giữ lại. Admin sẽ phản hồi sớm.', success: true, seconds: 3);
    notifyListeners();
  }

  // ================= Seller actions =================

  void createListing({
    required String title,
    required String cat,
    required int start,
    String desc = '',
    String cond = 'Đã qua sử dụng',
    int durationHours = 24,
    int photos = 2,
  }) {
    final now = DateTime.now();
    final id = 'L${now.microsecondsSinceEpoch}';
    final l = SellerListing(id: id, title: title, cat: cat, seller: myShop, status: 'appraisal', price: start, start: start, desc: desc, cond: cond, durationHours: durationHours);
    sellerListings.insert(0, l);
    appraisalQueue.insert(
      0,
      AppraisalItem(
        id: 'p$id',
        title: title,
        cat: cat,
        seller: myShop,
        ago: 'vừa xong',
        start: start,
        photos: photos,
        desc: desc.isEmpty ? 'Người bán chưa nhập mô tả.' : desc,
        cond: cond,
        sellerRating: '4,8',
        sellerStats: '${8 + _rnd.nextInt(30)} phiên đã bán',
        durationHours: durationHours,
        listingId: id,
      ),
    );
    _log('auction', 'Tạo phiên ký gửi', actor: myShop, ref: title, amount: start);
    notifyListeners();
  }

  /// Sửa tham số phiên (Edit Auction Parameters) — chỉ khi [SellerListing.canEdit].
  bool updateListing(String id, {required String title, required String desc, required int start, required int durationHours, required String cond}) {
    final l = _listing(id);
    if (l == null || !l.canEdit) return false;
    l.title = title;
    l.desc = desc;
    l.start = start;
    l.price = start;
    l.durationHours = durationHours;
    l.cond = cond;
    final it = _appraisalOfListing(id);
    if (it != null) {
      it.title = title;
      it.desc = desc.isEmpty ? it.desc : desc;
      it.start = start;
      it.durationHours = durationHours;
      it.cond = cond;
    }
    final a = _auction(l.auctionId);
    if (a != null && l.status == 'live' && a.count == 0) {
      a.title = title;
      a.desc = desc.isEmpty ? a.desc : desc;
      a.start = start;
      a.price = start;
      a.cond = cond;
      a.endsAt = DateTime.now().add(Duration(hours: durationHours));
      l.endsAt = a.endsAt;
    }
    _log('auction', 'Sửa tham số phiên', actor: l.seller, ref: title, amount: start);
    notifyListeners();
    return true;
  }

  /// Người bán bổ sung ảnh/giấy tờ theo yêu cầu của thẩm định viên.
  void sellerSubmitMoreInfo(String listingId, {int extraPhotos = 1}) {
    final l = _listing(listingId);
    final it = _appraisalOfListing(listingId);
    if (l == null) return;
    l.status = 'appraisal';
    l.requests = [];
    l.note = null;
    if (it != null) {
      it.status = 'pending';
      it.requests = [];
      it.photos += extraPhotos;
    }
    _log('auction', 'Bổ sung hồ sơ theo yêu cầu thẩm định', actor: l.seller, ref: l.title);
    notifyListeners();
  }

  /// Người bán xác nhận đã gửi hàng đến kho (Ship Item to Warehouse).
  void sellerMarkShipped(String listingId) {
    final l = _listing(listingId);
    final sh = _shipment(listingId);
    if (l == null || sh == null || sh.at != 1) return;
    sh.at = 2;
    final a = _auction(l.auctionId);
    warehouseShipments.insert(
      0,
      WarehouseShipment(
        id: l.id,
        title: l.title,
        cat: l.cat,
        code: sh.code,
        seller: l.seller,
        status: 'waiting',
        buyer: sh.buyer,
        address: _addressFor(a, sh.buyer),
        auctionId: a?.id,
      ),
    );
    if (a != null) {
      a.fulfil = 'transit';
      _notifyOrder(a, 'Người bán đã gửi hàng đến kho', '${a.title} đang được chuyển đến kho BidVibe để kiểm tra.');
    }
    _log('payment', 'Người bán gửi hàng đến kho', actor: l.seller, ref: l.title);
    notifyListeners();
  }

  // ================= Appraiser actions =================

  /// Duyệt hồ sơ → công khai phiên đấu giá cho Bidder.
  void approveAppraisal(String id) {
    final it = appraisalQueue.firstWhere((x) => x.id == id);
    appraisalQueue.removeWhere((x) => x.id == id);
    final now = DateTime.now();
    appraisalHistory.insert(0, AppraisalHistoryEntry(id: 'h${now.microsecondsSinceEpoch}', title: it.title, seller: it.seller, when: 'Vừa xong', result: 'approved'));

    final a = Auction(
      id: 'a${now.microsecondsSinceEpoch}',
      title: it.title,
      cat: it.cat,
      price: it.start,
      start: it.start,
      count: 0,
      endsAt: now.add(Duration(hours: it.durationHours)),
      botBudget: 10,
      cond: it.cond,
      seller: it.seller,
      rating: it.sellerRating,
      appraised: 'Thẩm định ngày ${_dm(now)} bởi chuyên gia BidVibe: hồ sơ, ảnh và mô tả khớp với thực tế.',
      desc: it.desc,
      listingId: it.listingId,
    );
    auctions.add(a);
    final l = _listing(it.listingId);
    if (l != null) {
      l.status = 'live';
      l.auctionId = a.id;
      l.endsAt = a.endsAt;
      l.price = a.price;
      l.count = 0;
    }
    _log('auction', 'Duyệt thẩm định, công khai phiên', actor: currentUser?.name ?? 'Thẩm định viên', ref: it.title, amount: it.start);
    notifyListeners();
  }

  void rejectAppraisal(String id, String reason) {
    final it = appraisalQueue.firstWhere((x) => x.id == id);
    appraisalQueue.removeWhere((x) => x.id == id);
    appraisalHistory.insert(0, AppraisalHistoryEntry(id: 'h${DateTime.now().microsecondsSinceEpoch}', title: it.title, seller: it.seller, when: 'Vừa xong', result: 'rejected', note: reason));
    final l = _listing(it.listingId);
    if (l != null) {
      l.status = 'rejected';
      l.note = reason;
    }
    _log('auction', 'Từ chối thẩm định', actor: currentUser?.name ?? 'Thẩm định viên', ref: it.title);
    notifyListeners();
  }

  static const requestLabels = {
    'photos': 'Chụp thêm ảnh chi tiết/vết hư hỏng',
    'receipt': 'Cung cấp hoá đơn hoặc giấy tờ mua',
    'serial': 'Ảnh cận số seri / mã sản phẩm',
  };

  /// Yêu cầu người bán bổ sung ảnh/giấy tờ (Request Additional Docs/Photos).
  void requestMoreInfo(String id, List<String> keys) {
    final it = appraisalQueue.firstWhere((x) => x.id == id);
    final labels = keys.map((k) => requestLabels[k] ?? k).toList();
    it.status = 'needinfo';
    it.requests = labels;
    final l = _listing(it.listingId);
    if (l != null) {
      l.status = 'needinfo';
      l.requests = labels;
    }
    _log('auction', 'Yêu cầu bổ sung hồ sơ', actor: currentUser?.name ?? 'Thẩm định viên', ref: it.title);
    notifyListeners();
  }

  // ================= Warehouse actions =================

  void whAddPhoto(String id) {
    final w = _wh(id)!;
    w.recvPhotos = min(w.recvPhotos + 1, 4);
    notifyListeners();
  }

  void whConfirmReceive(String id) {
    final w = _wh(id)!;
    w.status = 'inspecting';
    final a = _auction(w.auctionId);
    if (a != null) {
      a.fulfil = 'inspecting';
      _notifyOrder(a, 'Kho đã nhận hàng', '${a.title} đã đến kho và đang được kiểm tra.');
    }
    _log('payment', 'Kho nhận hàng', actor: currentUser?.name ?? 'Kho vận', ref: w.title);
    notifyListeners();
  }

  void whSetCheck(String id, String key, WarehouseCheck v) {
    final w = _wh(id)!;
    w.checks[key] = v;
    notifyListeners();
  }

  void whSetNote(String id, String note) {
    final w = _wh(id)!;
    w.note = note;
    notifyListeners();
  }

  /// Kiểm hàng xong và cập nhật tồn kho: tình trạng ghi nhận + vị trí kệ.
  void whConfirmInspect(String id, {required String grade, required String shelf}) {
    final w = _wh(id)!;
    w.status = 'inspecting_done';
    w.grade = grade;
    w.shelf = shelf.trim().isEmpty ? 'Kệ chờ gửi' : shelf.trim();
    _log('payment', 'Kiểm hàng đạt, cập nhật tồn kho ($grade · ${w.shelf})', actor: currentUser?.name ?? 'Kho vận', ref: w.title);
    notifyListeners();
  }

  void whEscalate(String id) {
    final w = _wh(id)!;
    w.status = 'escalated';
    final now = DateTime.now();
    final a = _auction(w.auctionId);
    final sh = _shipment(id);
    if (a != null) a.disputed = true;
    final l = _listing(id);
    if (l != null) l.status = 'disputed';
    disputes.insert(
      0,
      Dispute(
        id: 'd${now.microsecondsSinceEpoch}',
        code: '#TC-${120 + disputes.length}',
        source: 'warehouse',
        title: w.title,
        status: 'open',
        summary: w.note.isEmpty ? 'Kho ghi nhận sai lệch khi kiểm hàng.' : w.note,
        when: 'Vừa xong',
        amount: a?.price ?? sh?.amount ?? 0,
        escrow: a?.escrow ?? sh?.amount ?? 0,
        auctionId: a?.id,
        listingId: id,
        timeline: [('1', 'Kho phát hiện sai lệch khi đối chiếu: ${w.note}'), ('2', 'Kho tạm giữ, báo cáo lên Admin.')],
      ),
    );
    _log('admin', 'Kho báo sai lệch, mở tranh chấp', actor: currentUser?.name ?? 'Kho vận', ref: w.title);
    notifyListeners();
  }

  void whMarkPacked(String id) {
    final w = _wh(id)!;
    w.status = 'packed';
    notifyListeners();
  }

  /// Bàn giao cho đơn vị vận chuyển (Dispatch to Winning Bidder).
  void whMarkShipped(String id, {String carrier = 'GHN Express'}) {
    final w = _wh(id)!;
    w.status = 'shipped';
    w.carrier = carrier;
    w.tracking = '${carrier.split(' ').first.toUpperCase()}${7000000000 + _rnd.nextInt(999999999)}';
    final a = _auction(w.auctionId);
    final sh = _shipment(id);
    if (sh != null) sh.at = 3;
    if (a != null) {
      a.fulfil = 'shipping';
      _notifyOrder(a, 'Đơn hàng đang được giao', '${a.title} đã bàn giao cho $carrier · mã vận đơn ${w.tracking}.');
    }
    _log('payment', 'Kho gửi hàng cho người thắng ($carrier)', actor: currentUser?.name ?? 'Kho vận', ref: w.title);
    notifyListeners();
  }

  void whMarkDelivered(String id) {
    final w = _wh(id)!;
    w.status = 'delivered';
    final now = DateTime.now();
    final a = _auction(w.auctionId);
    final sh = _shipment(id);
    if (sh != null) sh.at = 4;
    if (a != null) {
      a.fulfil = 'delivered';
      a.deliveredAt = now;
      _notifyOrder(a, 'Đơn hàng đã giao', '${a.title} đã giao thành công. Hãy kiểm tra và xác nhận đã nhận hàng.', toast: true);
    }
    _log('payment', 'Giao hàng thành công', actor: currentUser?.name ?? 'Kho vận', ref: w.title);
    notifyListeners();
  }

  // ================= Admin actions =================

  /// Đổi trạng thái xử lý của phiên bị gắn cờ. "Tạm dừng" đóng băng thật
  /// đồng hồ và chặn đặt giá của phiên tương ứng.
  void setFlagStatus(String id, String status) {
    final f = flags.firstWhere((f) => f.id == id);
    f.status = status;
    final a = _auction(f.auctionId);
    if (a != null && !a.ended) {
      if (status == 'paused') a.paused = true;
      if (status == 'safe') a.paused = false;
    }
    _log('admin', switch (status) {
      'paused' => 'Tạm dừng phiên bị gắn cờ',
      'verify' => 'Yêu cầu xác minh phiên bị gắn cờ',
      _ => 'Đánh dấu phiên an toàn',
    }, actor: currentUser?.name ?? 'Admin', ref: f.code);
    notifyListeners();
  }

  /// Chấm dứt khẩn cấp phiên (Execute Emergency Auction Termination):
  /// đóng phiên ngay, không có người thắng, hoàn cọc mọi bên.
  void emergencyTerminate(String flagId, String reason) {
    final f = flags.firstWhere((x) => x.id == flagId);
    f.status = 'terminated';
    final now = DateTime.now();
    final a = _auction(f.auctionId);
    if (a != null && !a.ended) {
      a.ended = true;
      a.endedAt = now;
      a.paused = false;
      a.terminated = true;
      a.terminatedReason = reason;
      a.won = false;
      a.leading = false;
      if (a.joined && a.hold > 0) {
        final rel = a.hold;
        wallet += rel;
        walletHeld -= rel;
        a.hold = 0;
        walletTxs.insert(0, WalletTx(id: 'r${now.microsecondsSinceEpoch}', kind: 'release', label: 'Hoàn cọc (phiên bị chấm dứt) · ${a.title}', amount: rel, at: now));
        notifications.insert(
          0,
          AppNotification(id: 'x${now.microsecondsSinceEpoch}', kind: 'warn', title: 'Phiên đã bị chấm dứt', body: '${a.title} bị Admin chấm dứt khẩn cấp. Cọc ${money(rel)} đã hoàn về ví.', at: now, targetAuctionId: a.id),
        );
      }
      final l = _listing(a.listingId);
      if (l != null) {
        l.status = 'cancelled';
        l.note = 'Phiên bị Admin chấm dứt khẩn cấp: $reason';
      }
    }
    _log('admin', 'Chấm dứt khẩn cấp phiên — $reason', actor: currentUser?.name ?? 'Admin', ref: f.code);
    notifyListeners();
  }

  /// Phán quyết tranh chấp (Arbitrate Dispute & Force Settlement).
  /// [decision] = 'refund' (hoàn tiền người mua) | 'release' (cưỡng chế
  /// giải ngân cho người bán).
  void resolveDispute(String id, String decision) {
    final d = disputes.firstWhere((x) => x.id == id);
    final now = DateTime.now();
    final refund = decision == 'refund';
    final a = _auction(d.auctionId);
    final l = _listing(d.listingId ?? a?.listingId);
    final amount = d.escrow;
    d.status = 'resolved';
    d.resolution = refund ? 'Admin hoàn ${money(amount)} cho người mua.' : 'Admin cưỡng chế giải ngân ${money(amount)} cho người bán.';
    d.timeline.add(('${d.timeline.length + 1}', d.resolution!));
    d.escrow = 0;
    d.when = 'Vừa xong';
    if (a != null) {
      if (refund && a.escrow > 0) {
        wallet += a.escrow;
        walletTxs.insert(0, WalletTx(id: 'f${now.microsecondsSinceEpoch}', kind: 'refund', label: 'Hoàn tiền tranh chấp · ${a.title}', amount: a.escrow, at: now));
        notifications.insert(
          0,
          AppNotification(id: 'd${now.microsecondsSinceEpoch}', kind: 'refund', title: 'Tranh chấp được giải quyết', body: 'Admin hoàn ${money(a.escrow)} cho bạn · ${a.title}.', at: now, targetAuctionId: a.id, targetIsOrder: true),
        );
      }
      a.escrow = 0;
      a.disputed = false;
      a.fulfil = refund ? 'refunded' : 'confirmed';
    }
    final sh = _shipment(d.listingId ?? a?.listingId);
    if (sh != null) sh.at = refund ? sh.at : 5;
    if (l != null) {
      l.status = refund ? 'cancelled' : 'sold';
      l.note = refund ? 'Đã hoàn tiền người mua theo phán quyết của Admin.' : null;
    }
    _log('admin', refund ? 'Phán quyết: hoàn tiền người mua' : 'Phán quyết: giải ngân cho người bán', actor: currentUser?.name ?? 'Admin', ref: d.code, amount: amount);
    notifyListeners();
  }

  void toggleAccount(String id) {
    final a = users.firstWhere((x) => x.id == id);
    a.status = a.status == 'active' ? 'suspended' : 'active';
    _log('admin', a.status == 'suspended' ? 'Tạm khoá tài khoản' : 'Kích hoạt lại tài khoản', actor: currentUser?.name ?? 'Admin', ref: a.name);
    notifyListeners();
  }

  // ================= Demo helpers (chỉ phục vụ trình diễn) =================

  /// Ép một lượt đặt giá đối thủ để minh hoạ phản hồi "bị vượt giá".
  void demoForceOutbid(String auctionId) {
    final a = _auction(auctionId);
    if (a == null || a.ended || a.paused) return;
    _botBid(a, DateTime.now(), force: true);
    notifyListeners();
  }

  /// Rút thời gian còn lại xuống 10 giây và dừng bot của phiên này, để người
  /// demo không bị vượt giá vào phút chót (nút "Còn 10 giây").
  void demoEndSoon(String auctionId) {
    final a = _auction(auctionId);
    if (a == null || a.ended || a.paused) return;
    a.botBudget = 0;
    a.endsAt = DateTime.now().add(const Duration(seconds: 10));
    notifyListeners();
  }

  /// Ép quá hạn thanh toán 24 giờ để demo "Process Payment Timeout".
  void demoExpirePayment(String auctionId) {
    final a = _auction(auctionId);
    if (a == null) return;
    a.payBy = DateTime.now().subtract(const Duration(seconds: 1));
    notifyListeners();
  }

  /// Ép quá 72 giờ sau khi giao để demo "Auto-release Escrow".
  void demoAutoRelease(String auctionId) {
    final a = _auction(auctionId);
    if (a == null) return;
    a.deliveredAt = DateTime.now().subtract(const Duration(hours: 73));
    notifyListeners();
  }

  // ================= Logic dùng chung =================

  String _addressFor(Auction? a, String buyer) {
    if (a != null && a.joined) {
      final u = _demoBidder;
      return '${u.name} · ${u.phone} · ${u.address}';
    }
    for (final e in _fakeBuyers.entries) {
      if (e.value.$1 == buyer) return '${e.value.$1} · ${e.value.$2} · ${e.value.$3}';
    }
    return buyer;
  }

  void _notifyOrder(Auction a, String title, String body, {bool toast = false}) {
    if (!a.joined || !a.won) return;
    final now = DateTime.now();
    notifications.insert(
      0,
      AppNotification(id: 'o${now.microsecondsSinceEpoch}${_rnd.nextInt(999)}', kind: 'order', title: title, body: body, at: now, targetAuctionId: a.id, targetIsOrder: true),
    );
    if (toast) _showToast(title: title, body: '${a.title} · chạm để xác nhận', success: true, targetAuction: a.id, targetIsOrder: true, seconds: 8);
  }

  int _codeSeq = 20;
  String _nextCode() {
    final now = DateTime.now();
    _codeSeq += 1;
    return 'BV-${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}26-$_codeSeq';
  }

  /// Sau khi phiên thắng được thanh toán: tiền vào ký quỹ và người bán
  /// nhận phiếu gửi kho.
  void _startFulfilment(Auction a) {
    a.paid = true;
    a.fulfil = 'paid';
    a.escrow = a.totalDue;
    a.autoPayAt = null;
    final l = _listing(a.listingId);
    if (l != null) {
      l.status = 'shipping';
      l.price = a.price;
      l.count = a.count;
      final buyer = a.joined ? _demoBidder.name : (_fakeBuyers[a.hist.isNotEmpty ? a.hist.first.who : '']?.$1 ?? 'Người mua');
      sellerShipments.insert(0, Shipment(id: l.id, title: l.title, cat: l.cat, code: _nextCode(), seller: l.seller, buyer: buyer, amount: a.price, at: 1));
    }
  }

  /// Giải ngân ký quỹ cho người bán (Auto-release Escrow khi [auto]).
  void _releaseEscrow(Auction a, {required bool auto}) {
    final now = DateTime.now();
    final amt = a.escrow;
    a.escrow = 0;
    a.fulfil = 'confirmed';
    final sh = _shipment(a.listingId);
    if (sh != null) sh.at = 5;
    final l = _listing(a.listingId);
    if (l != null) l.status = 'sold';
    _log('payment', auto ? 'Tự động giải ngân ký quỹ cho người bán (quá 72 giờ)' : 'Giải ngân ký quỹ cho người bán (người mua xác nhận)', ref: a.title, amount: amt);
    if (a.joined && a.won) {
      notifications.insert(
        0,
        AppNotification(
          id: 'e${now.microsecondsSinceEpoch}',
          kind: 'info',
          title: auto ? 'Đơn hàng tự động hoàn tất' : 'Đơn hàng hoàn tất',
          body: auto ? '${a.title}: quá 72 giờ không phản hồi, hệ thống đã giải ngân cho người bán.' : 'Cảm ơn bạn đã xác nhận. ${a.title} đã hoàn tất.',
          at: now,
          targetAuctionId: a.id,
          targetIsOrder: true,
        ),
      );
      _showToast(title: auto ? 'Đơn hàng tự động hoàn tất' : 'Đã xác nhận nhận hàng', body: 'Ký quỹ đã được giải ngân cho người bán.', success: true, seconds: 4);
    }
  }

  // ================= System Scheduler: mô phỏng real-time =================

  void _tick() {
    final now = DateTime.now();
    _freezePaused();
    _botBids(now);
    _autoCloseExpired(now);
    _processOtherWinnerPayments(now);
    _processPaymentTimeouts(now);
    _autoReleaseEscrow(now);
    _syncListings();
    notifyListeners();
  }

  void _freezePaused() {
    for (final a in auctions) {
      if (a.paused && !a.ended) a.endsAt = a.endsAt.add(const Duration(seconds: 1));
    }
  }

  void _botBids(DateTime now) {
    if (_rnd.nextDouble() >= 0.35) return;
    final live = auctions.where((a) => !a.ended && !a.paused && a.botBudget > 0 && a.endsAt.difference(now).inSeconds > 3).toList();
    if (live.isEmpty) return;
    _botBid(live[_rnd.nextInt(live.length)], now);
  }

  void _botBid(Auction a, DateTime now, {bool force = false}) {
    final who = _bots[_rnd.nextInt(_bots.length)];
    a.price += a.step * (force || _rnd.nextDouble() < 0.7 ? 1 : 2);
    a.count += 1;
    if (!force) a.botBudget -= 1;
    a.lastBidAt = now;
    a.hist.insert(0, Bid(who: who, amount: a.price, at: now));
    if (a.hist.length > 8) a.hist.removeRange(8, a.hist.length);
    if (a.endsAt.difference(now).inSeconds < 20) a.endsAt = now.add(const Duration(seconds: 20));
    if (a.leading) {
      // Bị vượt giá: cọc VẪN được giữ tới khi phiên đóng (hoàn tự động nếu thua).
      a.leading = false;
      a.outbidAt = now;
      notifications.insert(
        0,
        AppNotification(
          id: 'n${now.microsecondsSinceEpoch}',
          kind: 'outbid',
          title: 'Bạn đã bị vượt giá',
          body: '${a.title}: $who vừa đặt ${money(a.price)}. Cọc vẫn được giữ, bạn có thể đặt lại.',
          at: now,
          targetAuctionId: a.id,
        ),
      );
      _showToast(title: 'Bạn đã bị vượt giá', body: '${a.title} · ${money(a.price)} — chạm để đặt lại', danger: true, targetAuction: a.id, seconds: 6);
    }
  }

  /// Auto-close Expired Sessions.
  void _autoCloseExpired(DateTime now) {
    for (final a in auctions) {
      if (!a.ended && !a.paused && a.endsAt.difference(now).inSeconds <= 0) _closeAuction(a, now);
    }
  }

  void _closeAuction(Auction a, DateTime now) {
    a.ended = true;
    a.endedAt = now;
    a.won = a.leading && a.joined;
    final l = _listing(a.listingId);
    _log('system', 'Tự động đóng phiên hết giờ', ref: a.title, amount: a.price);
    if (a.won) {
      a.payBy = now.add(const Duration(hours: 24));
      if (l != null) {
        l.status = 'unpaid';
        l.price = a.price;
        l.count = a.count;
      }
      notifications.insert(
        0,
        AppNotification(
          id: 'w${now.microsecondsSinceEpoch}',
          kind: 'win',
          title: 'Bạn đã thắng phiên đấu giá',
          body: '${a.title} — giá chốt ${money(a.price)}. Thanh toán trong 24 giờ, cọc ${money(a.hold)} sẽ được trừ vào tổng tiền.',
          at: now,
          targetAuctionId: a.id,
          targetIsPay: true,
        ),
      );
      _showToast(title: 'Bạn đã thắng phiên', body: '${a.title} · chạm để thanh toán', success: true, targetAuction: a.id, targetIsPay: true, seconds: 8);
      return;
    }
    // Auto-refund Losing Bidders: hoàn cọc người tham gia nhưng không thắng.
    if (a.joined && a.hold > 0) {
      final rel = a.hold;
      wallet += rel;
      walletHeld -= rel;
      a.hold = 0;
      walletTxs.insert(0, WalletTx(id: 'r${now.microsecondsSinceEpoch}', kind: 'release', label: 'Hoàn cọc (không thắng phiên) · ${a.title}', amount: rel, at: now));
      notifications.insert(
        0,
        AppNotification(
          id: 'rf${now.microsecondsSinceEpoch}',
          kind: 'refund',
          title: 'Đã hoàn cọc',
          body: '${a.title} đã kết thúc, bạn không thắng. Cọc ${money(rel)} đã hoàn về ví.',
          at: now,
          targetAuctionId: a.id,
          targetIsWallet: true,
        ),
      );
      _log('system', 'Tự động hoàn cọc người không thắng', actor: _demoBidder.name, ref: a.title, amount: rel);
    }
    if (a.count > 0) {
      // Người thắng khác (ẩn danh) sẽ thanh toán sau ít giây để demo luồng tiếp theo.
      a.autoPayAt = now.add(const Duration(seconds: 12));
      if (l != null) {
        l.status = 'unpaid';
        l.price = a.price;
        l.count = a.count;
      }
    } else if (l != null) {
      l.status = 'cancelled';
      l.note = 'Phiên kết thúc mà không có lượt đặt giá nào.';
    }
  }

  void _processOtherWinnerPayments(DateTime now) {
    for (final a in auctions) {
      if (a.ended && !a.won && !a.paid && !a.terminated && a.autoPayAt != null && !now.isBefore(a.autoPayAt!)) {
        _startFulfilment(a);
        _log('payment', 'Người thắng thanh toán (vào ký quỹ)', ref: a.title, amount: a.totalDue);
      }
    }
  }

  /// Process Payment Timeout: quá 24 giờ chưa thanh toán → mất cọc, huỷ giao dịch.
  void _processPaymentTimeouts(DateTime now) {
    for (final a in auctions) {
      if (a.ended && a.won && !a.paid && !a.paymentExpired && a.payBy != null && now.isAfter(a.payBy!)) {
        a.paymentExpired = true;
        a.won = false;
        final lost = a.hold;
        walletHeld -= lost;
        a.hold = 0;
        // Số tiền cọc đã bị trừ khỏi ví từ lúc đặt cọc nên dòng này chỉ ghi nhận (amount 0).
        walletTxs.insert(0, WalletTx(id: 'ft${now.microsecondsSinceEpoch}', kind: 'forfeit', label: 'Mất cọc ${money(lost)} do quá hạn thanh toán · ${a.title}', amount: 0, at: now));
        final l = _listing(a.listingId);
        if (l != null) {
          l.status = 'cancelled';
          l.note = 'Người thắng không thanh toán trong 24 giờ, giao dịch đã bị huỷ.';
        }
        notifications.insert(
          0,
          AppNotification(
            id: 'pt${now.microsecondsSinceEpoch}',
            kind: 'warn',
            title: 'Quá hạn thanh toán',
            body: '${a.title}: giao dịch bị huỷ và khoản cọc ${money(lost)} không được hoàn.',
            at: now,
            targetAuctionId: a.id,
          ),
        );
        _showToast(title: 'Quá hạn thanh toán', body: 'Giao dịch bị huỷ, cọc ${money(lost)} bị giữ lại.', danger: true, targetAuction: a.id, seconds: 6);
        _log('system', 'Quá hạn thanh toán 24 giờ, huỷ giao dịch và giữ cọc', actor: _demoBidder.name, ref: a.title, amount: lost);
      }
    }
  }

  /// Auto-release Escrow: quá 72 giờ sau khi giao mà bidder không phản hồi.
  void _autoReleaseEscrow(DateTime now) {
    for (final a in auctions) {
      if (a.fulfil == 'delivered' && !a.disputed && a.deliveredAt != null && now.difference(a.deliveredAt!).inHours >= 72) {
        _releaseEscrow(a, auto: true);
      }
    }
  }

  void _syncListings() {
    for (final l in sellerListings) {
      if (l.status != 'live') continue;
      final a = _auction(l.auctionId);
      if (a == null) continue;
      l.price = a.price;
      l.count = a.count;
      l.endsAt = a.endsAt;
      l.lastBidAt = a.lastBidAt;
    }
  }

  // ================= Dữ liệu khởi tạo (mock) =================

  void _seed() {
    final now = DateTime.now();
    DateTime ago({int d = 0, int h = 0, int m = 0, int s = 0}) => now.subtract(Duration(days: d, hours: h, minutes: m, seconds: s));
    DateTime inn({int d = 0, int h = 0, int m = 0, int s = 0}) => now.add(Duration(days: d, hours: h, minutes: m, seconds: s));

    // ---------- Tài khoản ----------
    users.addAll([
      UserAccount(id: 'ub1', name: 'Nguyễn Minh Anh', email: 'minhanh@gmail.com', role: 'bidder', phone: '0903 112 233', address: '45 Võ Văn Tần, P.6, Q.3, TP.HCM', load: 23),
      UserAccount(id: 'ub2', name: 'Trần Quốc Việt', email: 'viet.tran@gmail.com', role: 'bidder', phone: '0912 445 566', address: '12 Phố Huế, Hai Bà Trưng, Hà Nội', load: 41),
      UserAccount(id: 'ub3', name: 'Lê Bảo Châu', email: 'chau.le@outlook.com', role: 'bidder', phone: '0938 778 899', address: '27 Nguyễn Văn Linh, Hải Châu, Đà Nẵng', load: 9, twoFactor: true),
      UserAccount(id: 'us1', name: 'Nguyễn Hoàng Long', email: 'long@sneakersg.vn', role: 'seller', shop: 'Sneaker Sài Gòn', phone: '0908 556 120', address: '210 Nguyễn Thị Minh Khai, Q.3, TP.HCM', load: 47),
      UserAccount(id: 'us2', name: 'Lê Thu Hà', email: 'ha@phocoxua.vn', role: 'seller', shop: 'Phố Cổ Collectibles', phone: '0983 220 415', address: '36 Hàng Bạc, Hoàn Kiếm, Hà Nội', load: 63),
      UserAccount(id: 'us3', name: 'Phạm Quốc Bảo', email: 'bao@retroaudio.vn', role: 'seller', shop: 'Retro Audio HN', phone: '0972 665 308', address: '9 Tô Hiến Thành, Hai Bà Trưng, Hà Nội', load: 31),
      UserAccount(id: 'us4', name: 'Đinh Văn Hải', email: 'hai@retrocamera.vn', role: 'seller', shop: 'Retro Camera HN', phone: '0945 118 763', address: '58 Lê Thái Tổ, Hoàn Kiếm, Hà Nội', load: 18),
      UserAccount(id: 'us5', name: 'Nông Thị Hoa', email: 'hoa@caonguyenxua.vn', role: 'seller', shop: 'Cao Nguyên Xưa', phone: '0916 440 297', address: '14 Hùng Vương, Buôn Ma Thuột, Đắk Lắk', load: 3),
      UserAccount(id: 'ua1', name: 'Trần Minh Khoa', email: 'khoa.tran@bidvibe.vn', role: 'appraiser', load: 34),
      UserAccount(id: 'ua2', name: 'Lê Thị Ngọc', email: 'ngoc.le@bidvibe.vn', role: 'appraiser', load: 28),
      UserAccount(id: 'ua3', name: 'Đỗ Quang Huy', email: 'huy.do@bidvibe.vn', role: 'appraiser', load: 19),
      UserAccount(id: 'uw1', name: 'Phạm Đức Anh', email: 'anh.pham@bidvibe.vn', role: 'warehouse', load: 41),
      UserAccount(id: 'uw2', name: 'Vũ Hải Yến', email: 'yen.vu@bidvibe.vn', role: 'warehouse', status: 'suspended', load: 0),
      UserAccount(id: 'uw3', name: 'Ngô Thanh Sơn', email: 'son.ngo@bidvibe.vn', role: 'warehouse', load: 37),
      UserAccount(id: 'ud1', name: 'Hoàng Gia Bảo', email: 'admin@bidvibe.vn', role: 'admin', load: 0),
      UserAccount(id: 'ud2', name: 'Đặng Thu Trang', email: 'trang.dang@bidvibe.vn', role: 'admin', load: 0),
      UserAccount(id: 'ud3', name: 'Võ Minh Tuấn', email: 'tuan.vo@bidvibe.vn', role: 'admin', load: 0),
    ]);

    // ---------- Phiên đấu giá (Bidder thấy) ----------
    Bid b(String who, int amount, DateTime at) => Bid(who: who, amount: amount, at: at, me: who == _me);

    auctions.addAll([
      // 1) Sắp hết giờ, Bidder chưa tham gia.
      Auction(
        id: 'a1',
        title: 'Giày retro cao cổ "Chicago" 1985 — size 42',
        cat: 'shoes',
        price: 4250000,
        start: 3000000,
        count: 11,
        endsAt: inn(m: 3, s: 10),
        botBudget: 6,
        cond: 'Chưa qua sử dụng, đủ hộp',
        seller: 'Sneaker Sài Gòn',
        rating: '4,9',
        appraised: 'Thẩm định ngày 25/09 bởi chuyên gia BidVibe: chính hãng, khớp mã sản xuất.',
        desc: 'Phối màu đỏ – trắng – đen kinh điển, đế chưa xuống màu. Kèm hộp gốc và thẻ giấy.',
        listingId: 'Ls1',
        hist: [
          b('bidder_7f2a', 4250000, ago(s: 40)),
          b('bidder_c91d', 4200000, ago(s: 75)),
          b('bidder_7f2a', 4150000, ago(s: 130)),
          b('bidder_c91d', 4100000, ago(m: 3)),
          b('bidder_2b8e', 4000000, ago(m: 6)),
        ],
      ),
      // 2) Đang công khai, nhiều lượt đặt.
      Auction(
        id: 'a2',
        title: 'Máy ảnh film rangefinder 1984, kèm ống kính 35mm',
        cat: 'elec',
        price: 12800000,
        start: 9000000,
        count: 8,
        endsAt: inn(h: 2, m: 25),
        cond: 'Hoạt động tốt, màn trập chuẩn',
        seller: 'Retro Camera HN',
        rating: '4,8',
        appraised: 'Thẩm định ngày 24/09: kiểm tra màn trập, kính ngắm và ống kính.',
        desc: 'Thân máy kim loại, bọc da nguyên bản. Ống kính không nấm, không xước.',
        listingId: 'Lc1',
        hist: [
          b('bidder_e40a', 12800000, ago(m: 5)),
          b('bidder_51fb', 12700000, ago(m: 12)),
          b('bidder_e40a', 12550000, ago(m: 25)),
          b('bidder_2b8e', 12400000, ago(m: 48)),
          b('bidder_c91d', 12200000, ago(h: 1)),
        ],
      ),
      // 3) Sắp hết giờ, Bidder đang dẫn đầu.
      Auction(
        id: 'a3',
        title: 'Bình gốm men rạn thời Nguyễn, cao 32cm',
        cat: 'antique',
        price: 6500000,
        start: 4000000,
        count: 15,
        endsAt: inn(m: 7, s: 40),
        botBudget: 3,
        joined: true,
        leading: true,
        myBid: 6500000,
        hold: 400000,
        cond: 'Nguyên vẹn, không sứt mẻ',
        seller: 'Phố Cổ Collectibles',
        rating: '4,9',
        appraised: 'Thẩm định ngày 23/09: men và niên đại phù hợp mô tả.',
        desc: 'Men rạn tự nhiên, đáy có dấu hiệu lò. Đi kèm giấy chứng nhận của người bán.',
        listingId: 'Lp1',
        hist: [
          b(_me, 6500000, ago(m: 1, s: 30)),
          b('bidder_c91d', 6450000, ago(m: 3)),
          b('bidder_7f2a', 6400000, ago(m: 6)),
          b('bidder_c91d', 6300000, ago(m: 11)),
          b('bidder_2b8e', 6200000, ago(m: 20)),
        ],
      ),
      // 4) Bidder đã tham gia nhưng bị vượt giá.
      Auction(
        id: 'a4',
        title: 'Tai nghe hi-fi Đức thập niên 90, còn hộp',
        cat: 'elec',
        price: 2350000,
        start: 1500000,
        count: 6,
        endsAt: inn(h: 1, m: 30),
        joined: true,
        myBid: 2300000,
        hold: 150000,
        outbidAt: ago(m: 25),
        cond: 'Đã qua sử dụng, còn hộp',
        seller: 'Retro Audio HN',
        rating: '4,7',
        appraised: 'Thẩm định ngày 26/09: đo trở kháng và độ cân bằng hai bên.',
        desc: 'Đệm tai mới thay, dây cáp nguyên bản. Âm thanh cân bằng.',
        listingId: 'Lr1',
        hist: [
          b('bidder_51fb', 2350000, ago(m: 25)),
          b(_me, 2300000, ago(m: 40)),
          b('bidder_51fb', 2250000, ago(m: 55)),
          b('bidder_e40a', 2150000, ago(h: 1, m: 20)),
          b('bidder_51fb', 2050000, ago(h: 2)),
        ],
      ),
      Auction(
        id: 'a5',
        title: 'Giày chạy bộ bản giới hạn, size 43',
        cat: 'shoes',
        price: 1900000,
        start: 1200000,
        count: 5,
        endsAt: inn(h: 4, m: 20),
        cond: 'Mới 95%, đã đi 2 lần',
        seller: 'Sneaker Sài Gòn',
        rating: '4,9',
        appraised: 'Thẩm định ngày 26/09: chính hãng, đế còn nguyên gai.',
        desc: 'Bản phối màu giới hạn, upper không nhăn. Kèm hộp.',
        listingId: 'Ls2',
        hist: [
          b('bidder_e40a', 1900000, ago(m: 15)),
          b('bidder_2b8e', 1850000, ago(m: 40)),
          b('bidder_e40a', 1750000, ago(h: 1)),
          b('bidder_c91d', 1600000, ago(h: 2)),
          b('bidder_51fb', 1450000, ago(h: 3)),
        ],
      ),
      Auction(
        id: 'a6',
        title: 'Đồng hồ cơ Nhật Bản 1972, dây da nguyên bản',
        cat: 'antique',
        price: 5200000,
        start: 3000000,
        count: 9,
        endsAt: inn(h: 7),
        cond: 'Chạy chuẩn, mặt số nguyên bản',
        seller: 'Phố Cổ Collectibles',
        rating: '4,9',
        appraised: 'Thẩm định ngày 25/09: bộ máy chạy ổn định, mặt số chưa thay.',
        desc: 'Vỏ thép có vài vết xước nhỏ đúng tuổi. Máy lên cót tay, trữ cót tốt.',
        listingId: 'Lp2',
        hist: [
          b('bidder_7f2a', 5200000, ago(m: 20)),
          b('bidder_c91d', 5100000, ago(m: 45)),
          b('bidder_2b8e', 4950000, ago(h: 1, m: 10)),
          b('bidder_7f2a', 4700000, ago(h: 2)),
          b('bidder_e40a', 4400000, ago(h: 3)),
        ],
      ),
      // 5) Đã kết thúc, Bidder thắng, chờ thanh toán (còn 22 giờ).
      Auction(
        id: 'a7',
        title: 'Radio bóng đèn Philips 1960, vỏ gỗ óc chó',
        cat: 'elec',
        price: 3650000,
        start: 2000000,
        count: 12,
        endsAt: ago(h: 2),
        endedAt: ago(h: 2),
        ended: true,
        won: true,
        joined: true,
        leading: true,
        myBid: 3650000,
        hold: 200000,
        payBy: inn(h: 22),
        botBudget: 0,
        cond: 'Hoạt động tốt, vỏ gỗ còn nguyên',
        seller: 'Retro Audio HN',
        rating: '4,7',
        appraised: 'Thẩm định ngày 21/09: đèn còn sáng, loa không rè.',
        desc: 'Radio bóng đèn đời 1960, bắt sóng AM rõ. Có vài vết xước nhẹ trên vỏ gỗ.',
        listingId: 'Lr3',
        hist: [
          b(_me, 3650000, ago(h: 2, m: 1)),
          b('bidder_2b8e', 3600000, ago(h: 2, m: 6)),
          b(_me, 3550000, ago(h: 2, m: 20)),
          b('bidder_2b8e', 3450000, ago(h: 3)),
          b('bidder_7f2a', 3300000, ago(h: 5)),
        ],
      ),
      // 6) Đã thắng, đã thanh toán, đã giao — chờ Bidder xác nhận nhận hàng.
      Auction(
        id: 'a8',
        title: 'Máy chơi game cầm tay đời đầu, đủ hộp',
        cat: 'elec',
        price: 1850000,
        start: 1000000,
        count: 14,
        endsAt: ago(d: 4),
        endedAt: ago(d: 4),
        ended: true,
        won: true,
        joined: true,
        leading: true,
        myBid: 1850000,
        paid: true,
        escrow: 1983000,
        fulfil: 'delivered',
        deliveredAt: ago(h: 5),
        botBudget: 0,
        cond: 'Chạy tốt, kèm hộp và sách hướng dẫn',
        seller: 'Retro Audio HN',
        rating: '4,7',
        appraised: 'Thẩm định ngày 18/09: kiểm tra nút bấm, màn hình và pin.',
        desc: 'Máy còn nguyên tem, màn hình không ố. Đủ hộp và hướng dẫn tiếng Nhật.',
        listingId: 'Lr4',
        hist: [
          b(_me, 1850000, ago(d: 4, m: 1)),
          b('bidder_c91d', 1800000, ago(d: 4, m: 8)),
          b(_me, 1700000, ago(d: 4, h: 1)),
          b('bidder_e40a', 1600000, ago(d: 4, h: 3)),
          b('bidder_c91d', 1500000, ago(d: 5)),
        ],
      ),
      // 7) Đã hoàn tất: đã nhận hàng, ký quỹ đã giải ngân.
      Auction(
        id: 'a9',
        title: 'Giày da Oxford thủ công, size 41',
        cat: 'shoes',
        price: 2150000,
        start: 1200000,
        count: 7,
        endsAt: ago(d: 8),
        endedAt: ago(d: 8),
        ended: true,
        won: true,
        joined: true,
        leading: true,
        myBid: 2150000,
        paid: true,
        fulfil: 'confirmed',
        deliveredAt: ago(d: 3),
        botBudget: 0,
        cond: 'Như mới, đã đi 2 lần',
        seller: 'Sneaker Sài Gòn',
        rating: '4,9',
        appraised: 'Thẩm định ngày 12/09: da thật, đường khâu tay, đế còn dày.',
        desc: 'Da bò thật, đế khâu tay, có hộp và túi vải.',
        listingId: 'Ls4',
        hist: [
          b(_me, 2150000, ago(d: 8, m: 1)),
          b('bidder_51fb', 2100000, ago(d: 8, m: 9)),
          b(_me, 2000000, ago(d: 8, h: 1)),
          b('bidder_7f2a', 1900000, ago(d: 8, h: 4)),
          b('bidder_51fb', 1750000, ago(d: 9)),
        ],
      ),
      // 8) Đã kết thúc, Bidder không thắng (cọc đã tự hoàn).
      Auction(
        id: 'a10',
        title: 'Ấm tử sa Nghi Hưng thập niên 70, dáng tây thi',
        cat: 'antique',
        price: 3300000,
        start: 2500000,
        count: 10,
        endsAt: ago(d: 1),
        endedAt: ago(d: 1),
        ended: true,
        joined: true,
        myBid: 3100000,
        paid: true,
        fulfil: 'paid',
        botBudget: 0,
        cond: 'Nguyên vẹn, có dấu ấn dưới đáy',
        seller: 'Phố Cổ Collectibles',
        rating: '4,9',
        appraised: 'Thẩm định ngày 20/09: chất đất và dấu ấn phù hợp niên đại.',
        desc: 'Ấm dáng tây thi, dung tích khoảng 200ml, nắp khít, vòi rót gọn.',
        listingId: 'Lp4',
        hist: [
          b('bidder_c91d', 3300000, ago(d: 1, m: 1)),
          b(_me, 3100000, ago(d: 1, m: 6)),
          b('bidder_c91d', 3000000, ago(d: 1, h: 1)),
          b('bidder_7f2a', 2900000, ago(d: 1, h: 3)),
          b('bidder_2b8e', 2700000, ago(d: 1, h: 6)),
        ],
      ),
    ]);

    // ---------- Ví ----------
    // Số dư khớp với các giao dịch bên dưới: 12.000.000 nạp − 5.031.000 đã chi/đang cọc.
    wallet = 6969000;
    walletHeld = 750000;
    WalletTx tx(String id, String kind, String label, int amount, DateTime at) => WalletTx(id: id, kind: kind, label: label, amount: amount, at: at);
    walletTxs.addAll([
      tx('t11', 'hold', 'Đặt cọc tham gia · Tai nghe hi-fi Đức thập niên 90', -150000, ago(h: 20)),
      tx('t10', 'hold', 'Đặt cọc tham gia · Bình gốm men rạn thời Nguyễn', -400000, ago(d: 1)),
      tx('t9', 'release', 'Hoàn cọc (không thắng phiên) · Ấm tử sa Nghi Hưng', 250000, ago(d: 1)),
      tx('t8', 'hold', 'Đặt cọc tham gia · Ấm tử sa Nghi Hưng', -250000, ago(d: 2)),
      tx('t7', 'hold', 'Đặt cọc tham gia · Radio bóng đèn Philips 1960', -200000, ago(d: 3)),
      tx('t6', 'topup', 'Nạp tiền qua thẻ nội địa', 2000000, ago(d: 3, h: 2)),
      tx('t5', 'pay', 'Thanh toán · Máy chơi game cầm tay (đã trừ cọc 100.000 ₫)', -1883000, ago(d: 4)),
      tx('t4', 'hold', 'Đặt cọc tham gia · Máy chơi game cầm tay đời đầu', -100000, ago(d: 5)),
      tx('t3', 'pay', 'Thanh toán · Giày da Oxford (đã trừ cọc 120.000 ₫)', -2178000, ago(d: 7)),
      tx('t2', 'hold', 'Đặt cọc tham gia · Giày da Oxford thủ công', -120000, ago(d: 9)),
      tx('t1', 'topup', 'Nạp tiền qua VietQR', 10000000, ago(d: 10)),
    ]);

    // ---------- Thông báo của Bidder (mới nhất trước) ----------
    notifications.addAll([
      AppNotification(id: 'n5', kind: 'order', title: 'Đơn hàng đã giao', body: 'Máy chơi game cầm tay đời đầu đã giao thành công. Hãy kiểm tra và xác nhận đã nhận hàng.', at: ago(h: 5), targetAuctionId: 'a8', targetIsOrder: true),
      AppNotification(id: 'n4', kind: 'win', title: 'Bạn đã thắng phiên đấu giá', body: 'Radio bóng đèn Philips 1960 — giá chốt 3.650.000 ₫. Thanh toán trong 24 giờ, cọc 200.000 ₫ sẽ được trừ vào tổng tiền.', at: ago(h: 2), targetAuctionId: 'a7', targetIsPay: true),
      AppNotification(id: 'n3', kind: 'outbid', title: 'Bạn đã bị vượt giá', body: 'Tai nghe hi-fi Đức thập niên 90: bidder_51fb vừa đặt 2.350.000 ₫. Cọc vẫn được giữ, bạn có thể đặt lại.', at: ago(m: 25), targetAuctionId: 'a4'),
      AppNotification(id: 'n2', kind: 'refund', title: 'Đã hoàn cọc', body: 'Ấm tử sa Nghi Hưng thập niên 70 đã kết thúc, bạn không thắng. Cọc 250.000 ₫ đã hoàn về ví.', at: ago(d: 1), unread: false, targetAuctionId: 'a10', targetIsWallet: true),
      AppNotification(id: 'n1', kind: 'info', title: 'Đơn hàng hoàn tất', body: 'Cảm ơn bạn đã xác nhận. Giày da Oxford thủ công, size 41 đã hoàn tất.', at: ago(d: 3), unread: false, targetAuctionId: 'a9', targetIsOrder: true),
      AppNotification(
        id: 'n0',
        kind: 'info',
        title: 'Chào mừng đến BidVibe',
        body: 'Đặt cọc 10% giá khởi điểm để tham gia một phiên. Cọc được hoàn tự động nếu bạn không thắng, hoặc trừ vào tổng tiền nếu bạn thắng.',
        at: ago(d: 10),
        unread: false,
      ),
    ]);

    // ---------- Phiếu ký gửi, phiếu gửi kho và kho vận ----------
    // Helper dựng một đơn "đã bán": phiếu ký gửi + phiếu gửi kho (+ đơn ở kho khi đã gửi).
    void sold({
      required String id,
      required String title,
      required String cat,
      required String seller,
      required String buyerHandle,
      required int price,
      required int at, // 1..5, xem Shipment.at
      required String code,
      String? whStatus,
      int recvPhotos = 0,
      String? grade,
      String shelf = '',
      String? carrier,
      String? tracking,
      String note = '',
      String listingStatus = '',
      String? auctionId,
      bool allMatch = false,
    }) {
      final info = _fakeBuyers[buyerHandle];
      final buyerName = buyerHandle == _me ? 'Nguyễn Minh Anh' : (info?.$1 ?? buyerHandle);
      final address = buyerHandle == _me ? 'Nguyễn Minh Anh · 0903 112 233 · 45 Võ Văn Tần, P.6, Q.3, TP.HCM' : (info == null ? buyerHandle : '${info.$1} · ${info.$2} · ${info.$3}');
      sellerListings.add(SellerListing(
        id: id,
        title: title,
        cat: cat,
        seller: seller,
        status: listingStatus.isNotEmpty ? listingStatus : (at >= 5 ? 'sold' : 'shipping'),
        price: price,
        count: 6 + (price ~/ 900000) % 9,
        auctionId: auctionId,
      ));
      sellerShipments.add(Shipment(id: id, title: title, cat: cat, code: code, seller: seller, buyer: buyerName, amount: price, at: at));
      if (whStatus != null) {
        warehouseShipments.add(WarehouseShipment(
          id: id,
          title: title,
          cat: cat,
          code: code,
          seller: seller,
          status: whStatus,
          recvPhotos: recvPhotos,
          note: note,
          buyer: buyerName,
          address: address,
          auctionId: auctionId,
          grade: grade,
          shelf: shelf,
          carrier: carrier,
          tracking: tracking,
          checks: allMatch ? {'desc': WarehouseCheck.match, 'accessories': WarehouseCheck.match, 'damage': WarehouseCheck.match} : null,
        ));
      }
    }

    // Phiếu ký gửi còn ở giai đoạn thẩm định / đang công khai / đã bị từ chối.
    SellerListing pre(String id, String title, String cat, String seller, String status, int start, {String desc = '', String cond = 'Đã qua sử dụng', int count = 0, String? auctionId, DateTime? endsAt, String? note, List<String>? requests}) =>
        SellerListing(id: id, title: title, cat: cat, seller: seller, status: status, price: start, start: start, count: count, desc: desc, cond: cond, auctionId: auctionId, endsAt: endsAt, note: note, requests: requests);

    sellerListings.addAll([
      // Sneaker Sài Gòn
      pre('Ls1', 'Giày retro cao cổ "Chicago" 1985 — size 42', 'shoes', 'Sneaker Sài Gòn', 'live', 3000000, count: 11, auctionId: 'a1', endsAt: auctions[0].endsAt, cond: 'Chưa qua sử dụng, đủ hộp'),
      pre('Ls2', 'Giày chạy bộ bản giới hạn, size 43', 'shoes', 'Sneaker Sài Gòn', 'live', 1200000, count: 5, auctionId: 'a5', endsAt: auctions[4].endsAt, cond: 'Mới 95%, đã đi 2 lần'),
      pre('Ls3', 'Giày bóng rổ cổ điển, size 44', 'shoes', 'Sneaker Sài Gòn', 'appraisal', 2900000, cond: 'Như mới'),
      pre('Ls6', 'Giày thể thao phối màu "Mexico 66", size 40', 'shoes', 'Sneaker Sài Gòn', 'rejected', 2400000, note: 'Ảnh không thấy rõ tem size và mã sản xuất, không xác thực được hàng chính hãng.'),
      // Phố Cổ Collectibles
      pre('Lp1', 'Bình gốm men rạn thời Nguyễn, cao 32cm', 'antique', 'Phố Cổ Collectibles', 'live', 4000000, count: 15, auctionId: 'a3', endsAt: auctions[2].endsAt, cond: 'Nguyên vẹn, không sứt mẻ'),
      pre('Lp2', 'Đồng hồ cơ Nhật Bản 1972, dây da nguyên bản', 'antique', 'Phố Cổ Collectibles', 'live', 3000000, count: 9, auctionId: 'a6', endsAt: auctions[5].endsAt, cond: 'Chạy chuẩn, mặt số nguyên bản'),
      pre('Lp3', 'Chén trà men ngọc thời Nguyễn', 'antique', 'Phố Cổ Collectibles', 'appraisal', 3500000, cond: 'Nguyên vẹn'),
      // Retro Audio HN
      pre('Lr1', 'Tai nghe hi-fi Đức thập niên 90, còn hộp', 'elec', 'Retro Audio HN', 'live', 1500000, count: 6, auctionId: 'a4', endsAt: auctions[3].endsAt, cond: 'Đã qua sử dụng, còn hộp'),
      pre('Lr2', 'Máy nghe nhạc cassette Nhật Bản, 1988', 'elec', 'Retro Audio HN', 'needinfo', 1800000, requests: [requestLabels['photos']!, requestLabels['serial']!]),
      pre('Lr3', 'Radio bóng đèn Philips 1960, vỏ gỗ óc chó', 'elec', 'Retro Audio HN', 'unpaid', 2000000, count: 12, auctionId: 'a7'),
      pre('Lr7', 'Tai nghe không dây phiên bản giới hạn', 'elec', 'Retro Audio HN', 'appraisal', 3100000, cond: 'Như mới'),
      // Cao Nguyên Xưa
      pre('Ln1', 'Vòng cổ bạc chạm khắc dân tộc', 'antique', 'Cao Nguyên Xưa', 'appraisal', 2200000),
      // Retro Camera HN
      pre('Lc1', 'Máy ảnh film rangefinder 1984, kèm ống kính 35mm', 'elec', 'Retro Camera HN', 'live', 9000000, count: 8, auctionId: 'a2', endsAt: auctions[1].endsAt, cond: 'Hoạt động tốt, màn trập chuẩn'),
    ]);

    // Đơn đã bán ở các giai đoạn khác nhau của luồng sau bán.
    sold(id: 'Lp5', title: 'Đồng hồ treo tường cổ, vỏ gỗ', cat: 'antique', seller: 'Phố Cổ Collectibles', buyerHandle: 'bidder_7f2a', price: 2600000, at: 1, code: 'BV-290926-01');
    sold(id: 'Lp4', title: 'Ấm tử sa Nghi Hưng thập niên 70, dáng tây thi', cat: 'antique', seller: 'Phố Cổ Collectibles', buyerHandle: 'bidder_c91d', price: 3300000, at: 2, code: 'BV-280926-02', whStatus: 'inspecting', recvPhotos: 2, auctionId: 'a10');
    sold(id: 'Lp6', title: 'Bộ ly pha lê Bohemia (6 chiếc)', cat: 'antique', seller: 'Phố Cổ Collectibles', buyerHandle: 'bidder_e40a', price: 3200000, at: 2, code: 'BV-260926-03', whStatus: 'escalated', recvPhotos: 3, listingStatus: 'disputed', note: 'Thiếu 1 chiếc so với mô tả (nhận 5/6), một chiếc có vết mẻ ở miệng ly.');
    sold(id: 'Lp7', title: 'Đèn dầu hoả Đức cổ, chụp thuỷ tinh nguyên bản', cat: 'antique', seller: 'Phố Cổ Collectibles', buyerHandle: 'bidder_51fb', price: 1700000, at: 2, code: 'BV-300926-04', whStatus: 'waiting');
    sold(id: 'Ls5', title: 'Giày cao cổ da lộn, size 40', cat: 'shoes', seller: 'Sneaker Sài Gòn', buyerHandle: 'bidder_2b8e', price: 2750000, at: 2, code: 'BV-270926-01', whStatus: 'inspecting_done', recvPhotos: 3, grade: 'Tốt', shelf: 'Kệ B2-04', allMatch: true);
    sold(id: 'Ls4', title: 'Giày da Oxford thủ công, size 41', cat: 'shoes', seller: 'Sneaker Sài Gòn', buyerHandle: _me, price: 2150000, at: 5, code: 'BV-160926-04', whStatus: 'delivered', recvPhotos: 2, grade: 'Như mới', shelf: 'Kệ B1-01', carrier: 'GHN Express', tracking: 'GHN7104418826', auctionId: 'a9', allMatch: true);
    sold(id: 'Lr4', title: 'Máy chơi game cầm tay đời đầu, đủ hộp', cat: 'elec', seller: 'Retro Audio HN', buyerHandle: _me, price: 1850000, at: 4, code: 'BV-220926-02', whStatus: 'delivered', recvPhotos: 3, grade: 'Tốt', shelf: 'Kệ C3-02', carrier: 'Giao Hàng Nhanh', tracking: 'GHN7290365512', auctionId: 'a8', allMatch: true);
    sold(id: 'Lr5', title: 'Bàn phím cơ retro 1989', cat: 'elec', seller: 'Retro Audio HN', buyerHandle: 'bidder_2b8e', price: 3400000, at: 5, code: 'BV-100926-01');
    sold(id: 'Lr6', title: 'Loa bookshelf Đức thập niên 80 (cặp)', cat: 'elec', seller: 'Retro Audio HN', buyerHandle: 'bidder_7f2a', price: 4500000, at: 2, code: 'BV-250926-05', whStatus: 'packed', recvPhotos: 3, grade: 'Như mới', shelf: 'Kệ A1-02', allMatch: true);
    sold(id: 'Lr8', title: 'Đầu đĩa than Sanyo 1979', cat: 'elec', seller: 'Retro Audio HN', buyerHandle: 'bidder_e40a', price: 3900000, at: 3, code: 'BV-240926-02', whStatus: 'shipped', recvPhotos: 2, grade: 'Tốt', shelf: 'Kệ A2-05', carrier: 'Viettel Post', tracking: 'VIETTEL5081127390', allMatch: true);
    sold(id: 'Lc2', title: 'Ống kính Helios 44-2 58mm f/2', cat: 'elec', seller: 'Retro Camera HN', buyerHandle: 'bidder_c91d', price: 1450000, at: 2, code: 'BV-300926-02', whStatus: 'waiting');
    sold(id: 'Lc3', title: 'Máy ảnh compact Olympus XA 1979', cat: 'elec', seller: 'Retro Camera HN', buyerHandle: 'bidder_51fb', price: 6800000, at: 4, code: 'BV-200926-01', whStatus: 'delivered', recvPhotos: 3, grade: 'Tốt', shelf: 'Kệ C1-03', carrier: 'GHN Express', tracking: 'GHN7188204471', listingStatus: 'disputed', allMatch: true);
    sold(id: 'Ln2', title: 'Vòng tay bạc dân tộc Mông (cặp)', cat: 'antique', seller: 'Cao Nguyên Xưa', buyerHandle: 'bidder_c91d', price: 2800000, at: 5, code: 'BV-050926-01');
    sold(id: 'Ln3', title: 'Bộ chén bạc chạm khắc hoạ tiết', cat: 'antique', seller: 'Cao Nguyên Xưa', buyerHandle: 'bidder_7f2a', price: 2300000, at: 1, code: 'BV-300926-05');

    // ---------- Hàng chờ thẩm định ----------
    appraisalQueue.addAll([
      AppraisalItem(id: 'p1', listingId: 'Lp3', title: 'Chén trà men ngọc thời Nguyễn', cat: 'antique', seller: 'Phố Cổ Collectibles', ago: '20 phút trước', start: 3500000, photos: 3, desc: 'Chén trà men ngọc, đường kính 8cm. Người bán khai báo nguyên vẹn, không sứt mẻ.', cond: 'Nguyên vẹn', sellerRating: '4,9', sellerStats: '63 phiên đã bán'),
      AppraisalItem(id: 'p2', listingId: 'Lr2', title: 'Máy nghe nhạc cassette Nhật Bản, 1988', cat: 'elec', seller: 'Retro Audio HN', ago: '1 giờ trước', start: 1800000, photos: 4, desc: 'Còn chạy băng, cửa băng hơi lỏng. Đủ dây sạc gốc.', cond: 'Đã qua sử dụng', sellerRating: '4,7', sellerStats: '31 phiên đã bán', status: 'needinfo', requests: [requestLabels['photos']!, requestLabels['serial']!]),
      AppraisalItem(id: 'p3', listingId: 'Ls3', title: 'Giày bóng rổ cổ điển, size 44', cat: 'shoes', seller: 'Sneaker Sài Gòn', ago: '2 giờ trước', start: 2900000, photos: 2, desc: 'Đế có dấu hiệu ố vàng nhẹ theo thời gian, chưa qua sửa chữa.', cond: 'Như mới', sellerRating: '4,9', sellerStats: '47 phiên đã bán'),
      AppraisalItem(id: 'p4', listingId: 'Ln1', title: 'Vòng cổ bạc chạm khắc dân tộc', cat: 'antique', seller: 'Cao Nguyên Xưa', ago: 'hôm qua', start: 2200000, photos: 3, desc: 'Người bán mới có ít phiên, đây là phiên ký gửi vòng cổ đầu tiên.', cond: 'Đã qua sử dụng', sellerRating: 'Chưa có', sellerStats: 'Tài khoản mới'),
      AppraisalItem(id: 'p5', listingId: 'Lr7', title: 'Tai nghe không dây phiên bản giới hạn', cat: 'elec', seller: 'Retro Audio HN', ago: 'hôm qua', start: 3100000, photos: 4, desc: 'Còn bảo hành hãng 3 tháng, hộp hơi móp góc.', cond: 'Như mới', sellerRating: '4,7', sellerStats: '31 phiên đã bán'),
    ]);
    appraisalHistory.addAll([
      AppraisalHistoryEntry(id: 'h1', title: 'Giày retro cao cổ "Chicago" 1985', seller: 'Sneaker Sài Gòn', when: 'Hôm qua', result: 'approved'),
      AppraisalHistoryEntry(id: 'h2', title: 'Bình gốm men rạn thời Nguyễn', seller: 'Phố Cổ Collectibles', when: '2 ngày trước', result: 'approved'),
      AppraisalHistoryEntry(id: 'h3', title: 'Giày thể thao phối màu "Mexico 66", size 40', seller: 'Sneaker Sài Gòn', when: '2 ngày trước', result: 'rejected', note: 'Ảnh không thấy rõ tem size và mã sản xuất, không xác thực được hàng chính hãng.'),
      AppraisalHistoryEntry(id: 'h4', title: 'Đồng hồ điện tử nhái thương hiệu', seller: 'Tài khoản mới', when: '3 ngày trước', result: 'rejected', note: 'Nghi vấn hàng nhái, không có giấy tờ chứng minh.'),
      AppraisalHistoryEntry(id: 'h5', title: 'Đồng hồ cơ Nhật Bản 1972', seller: 'Phố Cổ Collectibles', when: '4 ngày trước', result: 'approved'),
    ]);

    // ---------- Admin ----------
    flags.addAll([
      FlaggedAuction(
        id: 'f1', code: '#A-2041', title: 'Giày retro cao cổ "Chicago" 1985 — size 42', severity: 'high', status: 'open', confidence: 91, auctionId: 'a1', reports: 2,
        reason: 'Hai tài khoản đặt giá luân phiên',
        explain: 'Hai tài khoản bidder_7f2a và bidder_c91d dùng chung thiết bị và địa chỉ IP, chiếm 9/11 lượt đặt của phiên và luôn nâng giá đúng một bước. Đây là mẫu điển hình của tăng giá ảo nhằm đẩy giá lên. Đã có 2 báo cáo từ người dùng.',
        evidence: [('Thiết bị dùng chung', '2 tài khoản'), ('Tỷ lệ lượt đặt của cặp tài khoản', '9/11 (82%)'), ('Tuổi tài khoản', '3 ngày'), ('Bước giá mỗi lần nâng', '50.000 ₫'), ('Báo cáo từ người dùng', '2')],
      ),
      FlaggedAuction(
        id: 'f2', code: '#A-2037', title: 'Máy ảnh film rangefinder 1984, kèm ống kính 35mm', severity: 'high', status: 'open', confidence: 87, auctionId: 'a2',
        reason: 'Đặt giá dồn dập theo nhịp đều',
        explain: 'Một tài khoản đặt giá 14 lần trong 3 phút với khoảng cách gần như đều nhau, nhanh hơn thao tác thông thường của người dùng. Có khả năng đang dùng công cụ tự động.',
        evidence: [('Khoảng cách trung bình giữa hai lượt', '1,2 giây'), ('Số lượt trong 3 phút', '14'), ('Tương tác cảm ứng trên thiết bị', 'Không ghi nhận')],
      ),
      FlaggedAuction(
        id: 'f3', code: '#A-2029', title: 'Bình gốm men rạn thời Nguyễn, cao 32cm', severity: 'medium', status: 'open', confidence: 68, auctionId: 'a3', reports: 1,
        reason: 'Giá thấp hơn mặt bằng chung',
        explain: 'Giá hiện tại thấp hơn 38% so với trung vị của các phiên gốm cùng niên đại, và một trong các tài khoản đặt giá từng thắng 3 phiên của cùng người bán trong 30 ngày. Chưa đủ chắc chắn để kết luận thông đồng, nên cần xác minh thêm.',
        evidence: [('So với trung vị nhóm tương tự', '−38%'), ('Số phiên cùng người bán đã thắng', '3 / 30 ngày'), ('Số người đặt giá khác nhau', '4')],
      ),
      FlaggedAuction(
        id: 'f4', code: '#A-2018', title: 'Đồng hồ cơ Nhật Bản 1972, dây da nguyên bản', severity: 'low', status: 'verify', confidence: 54, auctionId: 'a6',
        reason: 'Người bán huỷ nhiều phiên liên tiếp',
        explain: 'Người bán đã huỷ 3 phiên trong 7 ngày, đều sau khi giá vượt 150% mức khởi điểm. Có thể là thử giá thị trường rồi huỷ. Nên nhắc nhở trước khi xem là vi phạm.',
        evidence: [('Số phiên huỷ trong 7 ngày', '3'), ('Giá lúc huỷ so với khởi điểm', '> 150%'), ('Khiếu nại từ người mua', '0')],
      ),
    ]);

    disputes.addAll([
      Dispute(
        id: 'd1', code: '#TC-118', source: 'bidder', title: 'Máy ảnh compact Olympus XA 1979 — hàng nhận không đúng mô tả', status: 'open',
        summary: 'Người mua báo ống kính có vết xước không được nêu trong mô tả.', when: '2 giờ trước', amount: 6800000, escrow: 6800000, listingId: 'Lc3',
        timeline: [('1', 'Người mua nhận hàng, gửi ảnh vết xước ở ống kính.'), ('2', 'Kho đối chiếu: vết xước không có trong ảnh thẩm định gốc.'), ('3', 'Người bán phản hồi: vết xước có sẵn nhưng ảnh chụp thiếu góc đó.')],
      ),
      Dispute(
        id: 'd2', code: '#TC-121', source: 'seller', title: 'Bộ chén bạc chạm khắc hoạ tiết — người mua đòi huỷ sau khi thanh toán', status: 'open',
        summary: 'Người bán báo người mua yêu cầu huỷ đơn không có lý do chính đáng, trong khi đã thanh toán.', when: '5 giờ trước', amount: 2300000, escrow: 2300000, listingId: 'Ln3',
        timeline: [('1', 'Người mua thanh toán, khoản tiền vào ký quỹ.'), ('2', 'Người mua nhắn yêu cầu huỷ vì "đổi ý".'), ('3', 'Người bán từ chối huỷ và mở tranh chấp.')],
      ),
      Dispute(
        id: 'd5', code: '#TC-124', source: 'warehouse', title: 'Bộ ly pha lê Bohemia (6 chiếc) — thiếu hàng so với mô tả', status: 'open',
        summary: 'Kho ghi nhận nhận 5/6 chiếc, một chiếc có vết mẻ ở miệng ly.', when: '1 giờ trước', amount: 3200000, escrow: 3200000, listingId: 'Lp6',
        timeline: [('1', 'Kho phát hiện sai lệch khi đối chiếu: thiếu 1 chiếc, một chiếc có vết mẻ.'), ('2', 'Kho tạm giữ, báo cáo lên Admin.')],
      ),
      Dispute(
        id: 'd3', code: '#TC-109', source: 'seller', title: 'Giày chạy bộ bản giới hạn, size 42 — người mua không thanh toán', status: 'resolved',
        summary: 'Người bán báo người thắng phiên không thanh toán trong 24 giờ.', when: '4 ngày trước', amount: 1900000, escrow: 0,
        resolution: 'Admin cưỡng chế giải ngân tiền cọc cho người bán và cảnh cáo tài khoản người mua.',
        timeline: [('1', 'Quá hạn thanh toán 24 giờ, hệ thống tự huỷ giao dịch.'), ('2', 'Admin đã giữ tiền cọc chuyển cho người bán và cảnh cáo tài khoản người mua.')],
      ),
      Dispute(
        id: 'd4', code: '#TC-104', source: 'bidder', title: 'Máy nghe nhạc Walkman Sony 1985 — giao hàng chậm', status: 'resolved',
        summary: 'Người mua báo đơn giao trễ 3 ngày so với dự kiến.', when: '1 tuần trước', amount: 2350000, escrow: 0,
        resolution: 'Admin hoàn phí vận chuyển cho người mua, giao dịch giữ nguyên.',
        timeline: [('1', 'Đơn vị vận chuyển báo chậm do thời tiết.'), ('2', 'Admin đã hoàn phí vận chuyển cho người mua, giao dịch giữ nguyên.')],
      ),
    ]);

    // ---------- Nhật ký giao dịch (mới nhất trước) ----------
    void log(int minutesAgo, String kind, String actor, String action, {String? ref, int? amount}) {
      auditLogs.add(AuditEntry(id: 'seed${auditLogs.length}', at: now.subtract(Duration(minutes: minutesAgo)), kind: kind, actor: actor, action: action, ref: ref, amount: amount));
    }

    log(2, 'system', 'Hệ thống', 'Quét bất thường định kỳ: gắn cờ 1 phiên mới', ref: '#A-2041');
    log(8, 'auction', 'bidder_7f2a', 'Đặt giá', ref: 'Giày retro cao cổ "Chicago" 1985', amount: 4250000);
    log(9, 'auction', 'bidder_c91d', 'Đặt giá', ref: 'Giày retro cao cổ "Chicago" 1985', amount: 4200000);
    log(25, 'auction', 'bidder_51fb', 'Đặt giá', ref: 'Tai nghe hi-fi Đức thập niên 90', amount: 2350000);
    log(90, 'system', 'Hệ thống', 'Tự động đóng phiên hết giờ', ref: 'Radio bóng đèn Philips 1960', amount: 3650000);
    log(300, 'payment', 'Phạm Đức Anh', 'Giao hàng thành công', ref: 'Máy chơi game cầm tay đời đầu');
    log(420, 'admin', 'Kho vận', 'Kho báo sai lệch, mở tranh chấp', ref: 'Bộ ly pha lê Bohemia');
    log(600, 'payment', 'Hệ thống', 'Người thắng thanh toán (vào ký quỹ)', ref: 'Đầu đĩa than Sanyo 1979', amount: 4070000);
    log(1400, 'system', 'Hệ thống', 'Tự động hoàn cọc người không thắng', ref: 'Ấm tử sa Nghi Hưng', amount: 250000);
    log(1500, 'wallet', 'Nguyễn Minh Anh', 'Đặt cọc tham gia phiên', ref: 'Bình gốm men rạn thời Nguyễn', amount: 400000);
    log(2500, 'wallet', 'Nguyễn Minh Anh', 'Nạp tiền vào ví', ref: 'Thẻ nội địa', amount: 2000000);
    log(4300, 'payment', 'Hệ thống', 'Tự động giải ngân ký quỹ cho người bán (quá 72 giờ)', ref: 'Bàn phím cơ retro 1989', amount: 3400000);
    log(4400, 'admin', 'Hoàng Gia Bảo', 'Phán quyết: giải ngân cho người bán', ref: '#TC-109', amount: 1900000);
    log(6000, 'admin', 'Đặng Thu Trang', 'Đánh dấu phiên an toàn', ref: '#A-2003');
  }
}
