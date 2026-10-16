import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../features/orders/order_repository.dart';
import '../../theme.dart';

String orderMoney(num value) =>
    '${NumberFormat.decimalPattern('vi_VN').format(value)} đ';

String orderTime(DateTime? t) =>
    t == null ? '—' : DateFormat('HH:mm dd/MM/yyyy').format(t);

/// Giai đoạn đơn theo BE, đúng thứ tự để vẽ tiến trình.
const orderStages = [
  'awaiting_payment',
  'awaiting_seller_shipment',
  'in_transit_to_warehouse',
  'inspecting',
  'inspected',
  'packed',
  'shipped',
  'delivered',
  'completed',
];

String stageLabel(String? stage) => switch (stage) {
  'awaiting_payment' => 'Chờ thanh toán',
  'payment_expired' => 'Quá hạn thanh toán',
  'awaiting_seller_shipment' => 'Chờ người bán gửi kho',
  'in_transit_to_warehouse' => 'Đang gửi về kho',
  'inspecting' => 'Kho đang kiểm tra',
  'inspection_failed' => 'Không khớp mô tả',
  'inspected' => 'Kiểm đạt, chờ đóng gói',
  'packed' => 'Đã đóng gói',
  'shipped' => 'Đang giao',
  'delivered' => 'Đã giao, chờ bạn xác nhận',
  'completed' => 'Hoàn tất',
  _ => 'Đang cập nhật',
};

/// Trạng thái hiển thị trong danh sách khi chưa có giai đoạn chi tiết.
String orderStatusLabel(Order o) {
  // Tranh chấp lấn át giai đoạn giao hàng: đơn đang bị giữ ký quỹ chờ Admin.
  if (o.paid && o.disputed) return 'Đang tranh chấp';
  if (o.stage != null) return stageLabel(o.stage);
  // Danh sách đơn không có giai đoạn: đơn đã trả thì dựa vào trạng thái giải ngân.
  if (o.paid) {
    if (o.payoutStatus == 'released') return 'Hoàn tất';
    if (o.payoutStatus == 'disputed') return 'Đang tranh chấp';
  }
  return switch (o.paymentStatus) {
    'awaiting_payment' => 'Chờ thanh toán',
    'paid' => 'Đã thanh toán',
    'expired' => 'Quá hạn thanh toán',
    'cancelled' => 'Đã hủy',
    'refunded' => 'Đã hoàn tiền',
    _ => 'Đang cập nhật',
  };
}

({Color bg, Color fg}) orderStatusColors(Order o) {
  if (o.expired || o.stage == 'inspection_failed' || o.payoutStatus == 'disputed') {
    return (bg: AppColors.dangerBg, fg: AppColors.dangerFg);
  }
  if (o.awaitingPayment || o.canConfirmDelivery) {
    return (bg: AppColors.pendingBg, fg: AppColors.pendingFg);
  }
  if (o.completed) {
    return (bg: AppColors.successBg, fg: AppColors.successFg);
  }
  return (bg: AppColors.progressBg, fg: AppColors.progressFg);
}

String eventLabel(String step) => switch (step) {
  'packing' => 'Đóng gói',
  'shipped' => 'Bàn giao vận chuyển',
  'delivered' => 'Đã giao',
  _ => step,
};

class OrderStatusPill extends StatelessWidget {
  final Order order;
  const OrderStatusPill(this.order, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = orderStatusColors(order);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        orderStatusLabel(order),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: c.fg,
        ),
      ),
    );
  }
}

class OrderCover extends StatelessWidget {
  final String? url;
  final double size;
  const OrderCover(this.url, {super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: AppColors.neutralBg,
      child: const Icon(Icons.image_outlined, color: AppColors.muted),
    );
    // Thumbnail nhỏ: giải mã đúng kích thước hiển thị thay vì cả ảnh gốc (đỡ bộ nhớ cache ảnh).
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: url == null || url!.isEmpty
          ? placeholder
          : Image.network(
              url!,
              width: size,
              height: size,
              cacheWidth: px,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => placeholder,
            ),
    );
  }
}

/// Đếm ngược tới [deadline], tự cập nhật mỗi giây và báo [onExpired] đúng một lần
/// khi hết hạn. Timer chỉ chạy khi còn thời gian và được huỷ trong dispose.
class LiveCountdown extends StatefulWidget {
  final DateTime deadline;
  final TextStyle? style;
  final VoidCallback? onExpired;
  const LiveCountdown({super.key, required this.deadline, this.style, this.onExpired});

  @override
  State<LiveCountdown> createState() => _LiveCountdownState();
}

class _LiveCountdownState extends State<LiveCountdown> {
  Timer? _timer;
  bool _fired = false;

  Duration get _left => widget.deadline.difference(DateTime.now());

  @override
  void initState() {
    super.initState();
    if (_left > Duration.zero) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } else {
      _expire();
    }
  }

  @override
  void didUpdateWidget(LiveCountdown old) {
    super.didUpdateWidget(old);
    // Hạn mới (sau khi tải lại đơn): chạy lại bộ đếm nếu còn thời gian.
    if (old.deadline != widget.deadline) {
      _fired = false;
      _timer?.cancel();
      _timer = _left > Duration.zero ? Timer.periodic(const Duration(seconds: 1), (_) => _tick()) : null;
    }
  }

  void _tick() {
    if (!mounted) return;
    if (_left <= Duration.zero) {
      _timer?.cancel();
      _expire();
    }
    setState(() {});
  }

  void _expire() {
    if (_fired) return;
    _fired = true;
    // Gọi sau khung hình hiện tại: onExpired thường gọi setState của widget cha.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onExpired?.call();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sec = _left.isNegative ? 0 : _left.inSeconds;
    final h = sec ~/ 3600, m = (sec % 3600) ~/ 60, s = sec % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return Text('${two(h)}:${two(m)}:${two(s)}', style: widget.style);
  }
}
