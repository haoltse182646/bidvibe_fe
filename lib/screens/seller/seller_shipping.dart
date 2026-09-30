import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../customer/customer_dispute.dart';

/// Gửi hàng đến kho (Ship Item to Warehouse) và theo dõi đơn sau bán.
/// Đơn chỉ xuất hiện khi người mua đã thanh toán; tiền nằm trong ký quỹ
/// cho tới khi người mua xác nhận nhận hàng (hoặc tự giải ngân sau 72 giờ).
class SellerShippingScreen extends StatelessWidget {
  const SellerShippingScreen({super.key});

  static const stepLabels = ['Người mua đã thanh toán', 'Gửi hàng đến kho', 'Kho nhận và kiểm hàng', 'Kho giao đến người mua', 'Người mua xác nhận · giải ngân'];
  static const stepSubs = ['Tiền vào ký quỹ của BidVibe', 'Bạn đóng gói và gửi đến kho', 'Đối chiếu với hồ sơ thẩm định', 'Có mã vận đơn theo dõi', 'Tiền được chuyển cho bạn'];
  static const warehouseAddress = 'Kho BidVibe · 128 Nguyễn Văn Quá, P. Đông Hưng Thuận, Q.12, TP.HCM';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final list = store.myShipments..sort((a, b) => (a.at == 1 ? 0 : a.at == 5 ? 9 : a.at).compareTo(b.at == 1 ? 0 : b.at == 5 ? 9 : b.at));

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          const Text('KÝ GỬI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted, letterSpacing: 0.5)),
          const Text('Gửi hàng đến kho', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          const SizedBox(height: 4),
          const Text('Các đơn đã có người thắng và thanh toán. Gửi hàng đến kho để được giải ngân.', style: TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 12),
          if (list.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('Chưa có đơn nào cần gửi kho.', style: TextStyle(color: AppColors.muted)))),
          ...list.map((sh) => Padding(padding: const EdgeInsets.only(bottom: 14), child: _ShipmentCard(sh: sh))),
          const SizedBox(height: 4),
          const Text('Bạn không cần tự kiểm tra hàng lần cuối — kho sẽ đối chiếu với ảnh và mô tả bạn đã đăng.', style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4)),
        ],
      ),
    );
  }
}

class _ShipmentCard extends StatelessWidget {
  final Shipment sh;
  const _ShipmentCard({required this.sh});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final wh = store.warehouseShipments.where((w) => w.id == sh.id).toList();
    final w = wh.isEmpty ? null : wh.first;
    final listing = store.sellerListings.where((l) => l.id == sh.id).toList();
    final disputed = listing.isNotEmpty && listing.first.status == 'disputed';
    final subs = List<String>.of(SellerShippingScreen.stepSubs);
    if (w?.tracking != null) subs[3] = '${w!.carrier} · ${w.tracking}';
    if (sh.at == 2 && w != null) {
      subs[2] = switch (w.status) {
        'waiting' => 'Đang chờ kho nhận hàng',
        'inspecting' => 'Kho đang kiểm hàng',
        'escalated' => 'Kho đã báo sai lệch lên Admin',
        _ => 'Kiểm đạt, chuẩn bị gửi cho người mua',
      };
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: sh.at == 1 ? AppColors.pendingFg : AppColors.border, width: sh.at == 1 ? 1.5 : 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sh.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.35)),
          Text('Mã phiếu ${sh.code} · người mua ${sh.buyer}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 4),
          Text(sh.at >= 5 ? 'Đã nhận ${store.money(sh.amount)}' : 'Ký quỹ đang giữ ${store.money(sh.amount)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sh.at >= 5 ? AppColors.successStrong : AppColors.pendingFg)),
          if (disputed) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(10)),
              child: const Text('Đơn đang có tranh chấp. Ký quỹ được giữ lại cho tới khi Admin phán quyết.', style: TextStyle(fontSize: 12, color: AppColors.dangerFg)),
            ),
          ],
          const SizedBox(height: 12),
          ...SellerShippingScreen.stepLabels.asMap().entries.map((e) {
            final done = e.key < sh.at;
            final cur = e.key == sh.at;
            final last = e.key == SellerShippingScreen.stepLabels.length - 1;
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: done ? AppColors.successStrong : (cur ? Colors.white : AppColors.neutralBg),
                        child: done
                            ? const Icon(Icons.check, size: 13, color: Colors.white)
                            : Text('${e.key + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cur ? AppColors.accent : AppColors.neutralFg)),
                      ),
                      if (!last) Expanded(child: Container(width: 2, color: done ? AppColors.successStrong : AppColors.border)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.value, style: TextStyle(fontSize: 14, fontWeight: cur ? FontWeight.w700 : FontWeight.w500, color: e.key > sh.at ? AppColors.muted : AppColors.ink)),
                          Text(cur ? 'Đang ở bước này · ${subs[e.key]}' : subs[e.key], style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (sh.at == 1) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.pendingBg, borderRadius: BorderRadius.circular(12)),
              child: const Text('Ghi mã phiếu lên kiện hàng và gửi về:\n${SellerShippingScreen.warehouseAddress}', style: TextStyle(fontSize: 12, height: 1.45, color: AppColors.pendingFg)),
            ),
            const SizedBox(height: 10),
            BigActionButton(label: 'Tôi đã gửi hàng đến kho', icon: Icons.local_shipping_outlined, onPressed: () => store.sellerMarkShipped(sh.id)),
          ],
          if (sh.at >= 2 && sh.at <= 4 && !disputed)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CustomerDisputeScreen(source: 'seller', title: sh.title, listingId: sh.id))),
                icon: const Icon(Icons.gavel_outlined, size: 16),
                label: const Text('Báo tranh chấp'),
                style: TextButton.styleFrom(foregroundColor: AppColors.dangerStrong),
              ),
            ),
        ],
      ),
    );
  }
}
