import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'bidder_done.dart';

class BidderPaymentScreen extends StatefulWidget {
  final String auctionId;
  const BidderPaymentScreen({super.key, required this.auctionId});

  @override
  State<BidderPaymentScreen> createState() => _BidderPaymentScreenState();
}

class _BidderPaymentScreenState extends State<BidderPaymentScreen> {
  String method = 'qr';
  bool _paidHere = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final a = store.auctions.firstWhere((x) => x.id == widget.auctionId);
    // Vào lại từ thông báo/toast sau khi đã thanh toán → chuyển sang theo dõi đơn.
    if (a.paid && !_paidHere) return BidderDoneScreen(auctionId: a.id);
    final fee = a.fee;
    const ship = Auction.shipFee;
    final due = a.totalDue - a.hold;
    final walletOk = store.wallet >= due;
    final expired = a.paymentExpired;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Thanh toán', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Row(
              children: [
                CategoryThumb(cat: a.cat, size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bạn đã thắng phiên', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.successStrong)),
                      Text(a.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.35)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text('Chi tiết thanh toán', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(
              children: [
                _row('Giá thắng', store.money(a.price)),
                _row('Phí dịch vụ (5%)', store.money(fee)),
                _row('Vận chuyển từ kho', store.money(ship)),
                _row('Cọc đã đặt', '−${store.money(a.hold)}', color: AppColors.successStrong),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Cần thanh toán', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(store.money(due), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (expired)
            const Text('Đã quá hạn thanh toán — giao dịch bị huỷ.', style: TextStyle(fontSize: 12, color: AppColors.dangerStrong))
          else if (a.payBy != null)
            Row(children: [
              const Text('Còn lại để thanh toán: ', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              CountdownText(endsAt: a.payBy!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.pendingFg)),
            ])
          else
            const Text('Hạn thanh toán: 24 giờ kể từ khi phiên kết thúc.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 4),
          const Text('Tiền thanh toán được giữ ký quỹ, chỉ chuyển cho người bán sau khi bạn xác nhận nhận hàng.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 18),
          const Text('Phương thức', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _PayTile(title: 'VietQR', sub: 'Quét mã từ ứng dụng ngân hàng', selected: method == 'qr', enabled: true, onTap: () => setState(() => method = 'qr')),
          const SizedBox(height: 8),
          _PayTile(title: 'Thẻ nội địa', sub: 'Thanh toán qua cổng ngân hàng', selected: method == 'card', enabled: true, onTap: () => setState(() => method = 'card')),
          const SizedBox(height: 8),
          _PayTile(
            title: 'Ví BidVibe',
            sub: walletOk ? 'Số dư ${store.money(store.wallet)}' : 'Số dư ${store.money(store.wallet)} — không đủ, hãy nạp thêm',
            selected: method == 'wallet',
            enabled: walletOk,
            onTap: walletOk ? () => setState(() => method = 'wallet') : null,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: BigActionButton(
            label: 'Thanh toán ${store.money(due)}',
            onPressed: expired
                ? null
                : () {
                    _paidHere = true;
                    store.payForAuction(a.id, due: due, method: method == 'wallet' && !walletOk ? 'qr' : method);
                    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => BidderDoneScreen(auctionId: a.id, justPaid: true)));
                  },
          ),
        ),
      ),
    );
  }

  Widget _row(String k, String v, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
          Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
        ]),
      );
}

class _PayTile extends StatelessWidget {
  final String title;
  final String sub;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  const _PayTile({required this.title, required this.sub, required this.selected, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.75,
      child: Material(
        color: selected ? const Color(0xFFF1F3F8) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: selected ? AppColors.accent : AppColors.border)),
            child: Row(
              children: [
                Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? AppColors.accent : const Color(0xFF9AA0A9)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(sub, style: TextStyle(fontSize: 12, color: enabled ? AppColors.muted : AppColors.dangerFg)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
