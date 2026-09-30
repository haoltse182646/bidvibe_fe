import '../models.dart';
import '../theme.dart';

/// Nhãn trạng thái đơn hàng (sau khi thắng đấu giá) dùng chung cho danh
/// sách "Đơn hàng của tôi", chi tiết phiên và màn theo dõi đơn.
(String, StatusTone) orderStatus(Auction a) {
  if (a.disputed) return ('Đang tranh chấp', StatusTone.danger);
  if (!a.paid) return ('Chờ thanh toán', StatusTone.pending);
  return switch (a.fulfil) {
    'paid' => ('Chờ người bán gửi kho', StatusTone.progress),
    'transit' => ('Đang chuyển đến kho', StatusTone.progress),
    'inspecting' => ('Kho đang kiểm hàng', StatusTone.progress),
    'shipping' => ('Đang giao đến bạn', StatusTone.progress),
    'delivered' => ('Chờ bạn xác nhận', StatusTone.pending),
    'confirmed' => ('Hoàn tất', StatusTone.success),
    'refunded' => ('Đã hoàn tiền', StatusTone.neutral),
    _ => ('Đã thanh toán', StatusTone.progress),
  };
}
