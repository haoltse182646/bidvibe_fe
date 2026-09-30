// Các model dữ liệu dùng chung — tất cả là dữ liệu giả lập trong app,
// chưa nối backend thật. Xem AppStore (store.dart) để biết cách
// chúng được tạo, cập nhật theo thời gian và chia sẻ giữa các vai trò.

class Bid {
  final String who;
  final int amount;
  final DateTime at;
  final bool me;
  Bid({required this.who, required this.amount, required this.at, this.me = false});
}

enum AuctionStatus { live, endedWon, endedLost, endedOther }

class Auction {
  final String id;
  String title;
  final String cat; // shoes | elec | antique
  int price;
  int start;
  int count;
  DateTime endsAt;
  final int step;

  /// Bidder (người dùng đang demo) đã đặt cọc tham gia phiên này chưa.
  bool joined;
  bool leading;
  int myBid;

  /// Tiền cọc tham gia đang được giữ cho phiên này (0 nếu chưa cọc/đã hoàn).
  int hold;
  bool ended;
  bool won;
  DateTime? endedAt;
  DateTime? lastBidAt;
  DateTime? outbidAt;
  int botBudget;
  List<Bid> hist;
  String cond;
  final String seller;
  final String rating;
  String appraised;
  String desc;

  // ----- Sau khi thắng -----
  bool paid;
  DateTime? payBy;
  bool paymentExpired;
  DateTime? autoPayAt; // người thắng khác (bot) tự thanh toán sau ít giây
  int escrow; // tiền nền tảng đang giữ hộ, chờ giải ngân cho người bán
  /// none | paid | transit | inspecting | shipping | delivered | confirmed | refunded
  String fulfil;
  DateTime? deliveredAt;
  bool disputed;

  // ----- Kiểm soát của Admin -----
  bool paused;
  bool terminated;
  String? terminatedReason;

  /// Liên kết tới phiếu ký gửi của người bán (nếu có).
  String? listingId;

  Auction({
    required this.id,
    required this.title,
    required this.cat,
    required this.price,
    required this.start,
    required this.count,
    required this.endsAt,
    this.step = 50000,
    this.joined = false,
    this.leading = false,
    this.myBid = 0,
    this.hold = 0,
    this.ended = false,
    this.won = false,
    this.endedAt,
    this.lastBidAt,
    this.outbidAt,
    this.botBudget = 60,
    List<Bid>? hist,
    required this.cond,
    required this.seller,
    required this.rating,
    required this.appraised,
    required this.desc,
    this.paid = false,
    this.payBy,
    this.paymentExpired = false,
    this.autoPayAt,
    this.escrow = 0,
    this.fulfil = 'none',
    this.deliveredAt,
    this.disputed = false,
    this.paused = false,
    this.terminated = false,
    this.terminatedReason,
    this.listingId,
  }) : hist = hist ?? [];

  /// Tiền cọc tham gia = 10% giá khởi điểm, làm tròn đến nghìn đồng.
  static int depositFor(int start) => ((start * 0.1) / 1000).round() * 1000;
  int get deposit => depositFor(start);

  /// Phí dịch vụ 5% và phí vận chuyển cố định cho đơn thắng đấu giá.
  int get fee => ((price * 0.05) / 1000).round() * 1000;
  static const int shipFee = 40000;
  int get totalDue => price + fee + shipFee;

  Duration remaining(DateTime now) {
    final d = endsAt.difference(now);
    return d.isNegative ? Duration.zero : d;
  }
}

class WalletTx {
  final String id;
  final String kind; // topup | hold | release | pay | forfeit | refund
  final String label;
  final int amount; // âm là trừ
  final DateTime at;
  WalletTx({required this.id, required this.kind, required this.label, required this.amount, required this.at});
}

class AppNotification {
  final String id;
  final String kind; // outbid | win | info | refund | order | warn
  final String title;
  final String body;
  final DateTime at;
  bool unread;
  final String? targetAuctionId;
  final bool targetIsPay;
  final bool targetIsWallet;
  final bool targetIsOrder;
  AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.at,
    this.unread = true,
    this.targetAuctionId,
    this.targetIsPay = false,
    this.targetIsWallet = false,
    this.targetIsOrder = false,
  });
}

class SellerListing {
  final String id;
  String title;
  final String cat;
  final String seller; // tên gian hàng (shop) của người ký gửi

  /// appraisal | needinfo | rejected | live | unpaid | shipping | sold | disputed | cancelled
  String status;
  int price; // giá hiện tại (khi live) hoặc giá chốt
  int start;
  int count;
  String desc;
  String cond;
  int durationHours;
  DateTime? endsAt;
  DateTime? lastBidAt;
  String? auctionId;
  String? note; // lý do từ chối / ghi chú của thẩm định viên
  List<String> requests; // yêu cầu bổ sung đang chờ người bán xử lý

  SellerListing({
    required this.id,
    required this.title,
    required this.cat,
    required this.seller,
    required this.status,
    required this.price,
    int? start,
    this.count = 0,
    this.desc = '',
    this.cond = 'Đã qua sử dụng',
    this.durationHours = 24,
    this.endsAt,
    this.lastBidAt,
    this.auctionId,
    this.note,
    List<String>? requests,
  })  : start = start ?? price,
        requests = requests ?? [];

  /// Người bán chỉ được sửa tham số phiên trước khi có người đặt giá.
  bool get canEdit => status == 'appraisal' || status == 'needinfo' || (status == 'live' && count == 0);
}

class Shipment {
  final String id; // trùng id phiếu ký gửi
  final String title;
  final String cat;
  final String code;
  final String seller;
  final String buyer;
  final int amount;

  /// Bước hiện tại của luồng sau bán: 1 = chờ người bán gửi kho,
  /// 2 = đã gửi/kho đang xử lý, 3 = kho đang giao, 4 = đã giao (chờ người
  /// mua xác nhận), 5 = hoàn tất và đã giải ngân.
  int at;
  Shipment({required this.id, required this.title, required this.cat, required this.code, required this.seller, required this.buyer, required this.amount, this.at = 1});
}

class AppraisalItem {
  final String id;
  String title;
  final String cat;
  final String seller;
  final String ago;
  int start;
  int photos;
  String desc;
  String cond;
  final String sellerRating;
  final String sellerStats;
  int durationHours;
  String? listingId;
  String status; // pending | needinfo
  List<String> requests;
  AppraisalItem({
    required this.id,
    required this.title,
    required this.cat,
    required this.seller,
    required this.ago,
    required this.start,
    required this.photos,
    required this.desc,
    required this.cond,
    required this.sellerRating,
    required this.sellerStats,
    this.durationHours = 24,
    this.listingId,
    this.status = 'pending',
    List<String>? requests,
  }) : requests = requests ?? [];
}

class AppraisalHistoryEntry {
  final String id;
  final String title;
  final String seller;
  final String when;
  final String result; // approved | rejected
  final String? note;
  AppraisalHistoryEntry({required this.id, required this.title, required this.seller, required this.when, required this.result, this.note});
}

enum WarehouseCheck { unknown, match, mismatch }

class WarehouseShipment {
  final String id;
  final String title;
  final String cat;
  final String code;
  final String seller;
  String status; // waiting | inspecting | inspecting_done | packed | shipped | delivered | escalated
  int recvPhotos;
  Map<String, WarehouseCheck> checks;
  String note;

  // Thông tin người nhận (Dispatch to Winning Bidder)
  final String buyer;
  final String address;
  final String? auctionId;

  // Cập nhật tồn kho & tình trạng (Update Inventory & Condition)
  String? grade; // Như mới | Tốt | Khá
  String shelf;

  // Vận chuyển
  String? carrier;
  String? tracking;

  WarehouseShipment({
    required this.id,
    required this.title,
    required this.cat,
    required this.code,
    required this.seller,
    required this.status,
    this.recvPhotos = 0,
    Map<String, WarehouseCheck>? checks,
    this.note = '',
    this.buyer = 'Người mua',
    this.address = '',
    this.auctionId,
    this.grade,
    this.shelf = '',
    this.carrier,
    this.tracking,
  }) : checks = checks ?? {'desc': WarehouseCheck.unknown, 'accessories': WarehouseCheck.unknown, 'damage': WarehouseCheck.unknown};
}

class FlaggedAuction {
  final String id;
  final String code;
  final String title;
  final String severity; // high | medium | low
  String status; // open | paused | verify | safe | terminated
  final int confidence;
  final String reason;
  final String explain;
  final List<(String, String)> evidence;
  final String? auctionId;
  int reports; // số báo cáo từ người dùng
  FlaggedAuction({
    required this.id,
    required this.code,
    required this.title,
    required this.severity,
    required this.status,
    required this.confidence,
    required this.reason,
    required this.explain,
    required this.evidence,
    this.auctionId,
    this.reports = 0,
  });
}

class Dispute {
  final String id;
  final String code;
  final String source; // bidder | seller | warehouse
  final String title;
  String status; // open | resolved
  final String summary;
  String when;
  final int amount;
  int escrow;
  final List<(String, String)> timeline;
  final String? auctionId;
  final String? listingId;
  String? resolution;
  Dispute({
    required this.id,
    required this.code,
    required this.source,
    required this.title,
    required this.status,
    required this.summary,
    required this.when,
    required this.amount,
    required this.escrow,
    required this.timeline,
    this.auctionId,
    this.listingId,
    this.resolution,
  });
}

/// Tài khoản đăng nhập (mọi vai trò). Admin dùng cùng danh sách này ở
/// màn Quản lý tài khoản.
class UserAccount {
  final String id;
  String name;
  final String email;
  String phone;
  String address;
  String password;
  final String role; // bidder | seller | appraiser | warehouse | admin
  final String? shop; // tên gian hàng (chỉ Seller)
  String status; // active | suspended
  final int load; // tải công việc / số phiên tham gia tuỳ vai trò
  bool twoFactor;
  UserAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone = '',
    this.address = '',
    this.password = '123456',
    this.shop,
    this.status = 'active',
    this.load = 0,
    this.twoFactor = false,
  });

  String get roleLabel => switch (role) {
        'bidder' => 'Người mua',
        'seller' => 'Người bán',
        'appraiser' => 'Thẩm định',
        'warehouse' => 'Kho vận',
        _ => 'Admin',
      };
}

/// Một dòng trong nhật ký giao dịch/hệ thống mà Admin xem được.
class AuditEntry {
  final String id;
  final DateTime at;
  final String kind; // wallet | auction | payment | admin | system
  final String actor;
  final String action;
  final String? ref;
  final int? amount;
  AuditEntry({required this.id, required this.at, required this.kind, required this.actor, required this.action, this.ref, this.amount});
}
