import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../store.dart';
import '../../theme.dart';
import 'bidder_detail.dart';
import 'bidder_payment.dart';
import 'bidder_done.dart';

class BidderNotificationsScreen extends StatelessWidget {
  const BidderNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          const Text('Thông báo', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(
              children: store.notifications.asMap().entries.map((e) {
                final n = e.value;
                final (icon, bg, fg) = switch (n.kind) {
                  'outbid' => (Icons.error_outline, AppColors.dangerBg, AppColors.dangerStrong),
                  'win' => (Icons.check_circle_outline, AppColors.successBg, AppColors.successStrong),
                  'refund' => (Icons.replay, AppColors.progressBg, AppColors.progressFg),
                  'order' => (Icons.local_shipping_outlined, AppColors.progressBg, AppColors.progressFg),
                  'warn' => (Icons.warning_amber_rounded, AppColors.pendingBg, AppColors.pendingFg),
                  _ => (Icons.info_outline, AppColors.neutralBg, AppColors.neutralFg),
                };
                return Material(
                  color: n.unread ? const Color(0xFFF7F9FC) : Colors.white,
                  child: InkWell(
                    onTap: () {
                      if (n.targetIsPay && n.targetAuctionId != null) {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => BidderPaymentScreen(auctionId: n.targetAuctionId!)));
                      } else if (n.targetIsOrder && n.targetAuctionId != null) {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => BidderDoneScreen(auctionId: n.targetAuctionId!)));
                      } else if (n.targetAuctionId != null) {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => BidderDetailScreen(auctionId: n.targetAuctionId!)));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(border: e.key == 0 ? null : const Border(top: BorderSide(color: AppColors.border))),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(radius: 18, backgroundColor: bg, child: Icon(icon, size: 18, color: fg)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(n.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                                    Text(_when(n.at), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(n.body, style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.mutedStrong)),
                                if (n.kind == 'outbid' || n.targetIsPay || n.targetIsOrder) ...[
                                  const SizedBox(height: 8),
                                  Text(n.targetIsPay ? 'Thanh toán ngay' : (n.targetIsOrder ? 'Xem đơn hàng' : 'Đặt giá lại'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accent)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _when(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'Vừa xong';
    if (d.inHours < 1) return '${d.inMinutes} phút trước';
    if (d.inDays < 1) return '${d.inHours} giờ trước';
    return '${d.inDays} ngày trước';
  }
}
