import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/order_status.dart';
import '../customer/customer_dispute.dart';

/// Theo dõi đơn hàng sau thanh toán và xác nhận đã nhận hàng (Confirm Item
/// Delivery). Hành trình cập nhật theo thời gian thực từ các bước của
/// Seller (gửi kho) và Kho vận (nhận, kiểm, giao). Khi hàng đã giao, người
/// mua xác nhận để giải ngân ký quỹ, hoặc mở tranh chấp nếu có vấn đề.
class BidderDoneScreen extends StatelessWidget {
  final String auctionId;
  final bool justPaid;
  const BidderDoneScreen({super.key, required this.auctionId, this.justPaid = false});

  static const stepLabels = ['Đã thanh toán', 'Người bán gửi hàng đến kho', 'Kho kiểm hàng', 'Giao đến bạn', 'Bạn xác nhận nhận hàng'];

  /// Chỉ số bước đang chờ xử lý (>= độ dài = tất cả đã xong).
  int _current(Auction a) => switch (a.fulfil) {
        'paid' || 'transit' => 1,
        'inspecting' => 2,
        'shipping' => 3,
        'delivered' => 4,
        'confirmed' || 'refunded' => stepLabels.length,
        _ => 1,
      };

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final a = store.auctions.firstWhere((x) => x.id == auctionId);
    final wh = store.warehouseShipments.where((w) => w.auctionId == a.id).toList();
    final w = wh.isEmpty ? null : wh.first;
    final cur = _current(a);
    final (statusLabel, statusTone) = orderStatus(a);
    final delivered = a.fulfil == 'delivered' && !a.disputed;

    final subs = <String>[
      'Vừa xong',
      a.fulfil == 'transit' ? 'Đang vận chuyển đến kho' : 'Dự kiến trong 2–3 ngày',
      w?.grade != null ? 'Tình trạng ghi nhận: ${w!.grade}' : 'Đối chiếu với kết quả thẩm định',
      w?.tracking != null ? '${w!.carrier} · mã vận đơn ${w.tracking}' : 'Có mã vận đơn theo dõi',
      delivered && a.deliveredAt != null ? 'Tự động xác nhận sau ${_autoLeft(a)}' : 'Ký quỹ giải ngân cho người bán',
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: justPaid ? null : AppBar(title: const Text('Theo dõi đơn hàng', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, justPaid ? 48 : 4, 16, 16),
          children: [
            if (justPaid) ...[
              const CircleAvatar(radius: 32, backgroundColor: AppColors.successStrong, child: Icon(Icons.check, color: Colors.white, size: 32)),
              const SizedBox(height: 16),
              const Center(child: Text('Thanh toán thành công', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3))),
              const SizedBox(height: 6),
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text('Tiền được giữ ký quỹ. Người bán sẽ gửi hàng đến kho BidVibe và bạn nhận thông báo ở mỗi bước.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.45)),
                ),
              ),
              const SizedBox(height: 24),
            ],
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
              child: Row(
                children: [
                  CategoryThumb(cat: a.cat, size: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.35)),
                        const SizedBox(height: 4),
                        Text('${store.money(a.price)} · người bán ${a.seller}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                        const SizedBox(height: 6),
                        StatusPill(label: statusLabel, tone: statusTone),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (a.disputed)
              const _Note(color: AppColors.dangerBg, fg: AppColors.dangerFg, icon: Icons.gavel_outlined, text: 'Đơn đang có tranh chấp. Khoản ký quỹ được giữ lại cho tới khi Admin phán quyết.'),
            if (a.fulfil == 'confirmed') const _Note(color: AppColors.successBg, fg: AppColors.successFg, icon: Icons.check_circle_outline, text: 'Đơn hàng đã hoàn tất. Ký quỹ đã được giải ngân cho người bán.'),
            if (a.fulfil == 'refunded') const _Note(color: AppColors.neutralBg, fg: AppColors.mutedStrong, icon: Icons.replay, text: 'Admin đã hoàn tiền cho bạn theo phán quyết tranh chấp.'),
            if (delivered)
              const _Note(color: AppColors.pendingBg, fg: AppColors.pendingFg, icon: Icons.inventory_2_outlined, text: 'Hàng đã giao. Hãy kiểm tra sản phẩm trước khi xác nhận — sau khi xác nhận, tiền sẽ được chuyển cho người bán.'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
              child: Column(
                children: List.generate(stepLabels.length, (i) {
                  final done = i < cur;
                  final isCur = i == cur;
                  final last = i == stepLabels.length - 1;
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            CircleAvatar(
                              radius: 11,
                              backgroundColor: done ? AppColors.successStrong : (isCur ? Colors.white : AppColors.neutralBg),
                              child: done
                                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                                  : Text('${i + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isCur ? AppColors.accent : AppColors.neutralFg)),
                            ),
                            if (!last) Expanded(child: Container(width: 2, color: done ? AppColors.successStrong : AppColors.border)),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(stepLabels[i], style: TextStyle(fontSize: 14, fontWeight: isCur ? FontWeight.w700 : FontWeight.w600, color: i > cur ? AppColors.muted : AppColors.ink)),
                                Text(isCur ? 'Đang ở bước này · ${subs[i]}' : subs[i], style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            if (w != null && w.address.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18, color: AppColors.neutralFg),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Địa chỉ nhận hàng', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                          const SizedBox(height: 2),
                          Text(w.address, style: const TextStyle(fontSize: 13, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (delivered) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFBDBAB0)), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Expanded(child: Text('DEMO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted, letterSpacing: 0.5))),
                    OutlinedButton(onPressed: () => store.demoAutoRelease(a.id), child: const Text('Mô phỏng quá 72 giờ', style: TextStyle(fontSize: 12))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: delivered
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BigActionButton(label: 'Xác nhận đã nhận hàng', icon: Icons.check, background: AppColors.successStrong, onPressed: () => store.confirmDelivery(a.id)),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CustomerDisputeScreen(source: 'bidder', title: a.title, auctionId: a.id))),
                      child: const Text('Báo vấn đề / Tranh chấp', style: TextStyle(color: AppColors.dangerStrong, fontWeight: FontWeight.w600)),
                    ),
                  ],
                )
              : SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                    child: const Text('Về trang chủ', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
        ),
      ),
    );
  }

  String _autoLeft(Auction a) {
    final left = const Duration(hours: 72) - DateTime.now().difference(a.deliveredAt!);
    if (left.isNegative) return 'ít phút';
    if (left.inHours >= 24) return '${left.inDays} ngày ${left.inHours % 24} giờ';
    return '${left.inHours} giờ ${left.inMinutes % 60} phút';
  }
}

class _Note extends StatelessWidget {
  final Color color;
  final Color fg;
  final IconData icon;
  final String text;
  const _Note({required this.color, required this.fg, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, height: 1.45, color: fg))),
        ],
      ),
    );
  }
}
