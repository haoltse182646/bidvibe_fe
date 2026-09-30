import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../store.dart';
import '../../theme.dart';

class BidderWalletScreen extends StatefulWidget {
  const BidderWalletScreen({super.key});

  @override
  State<BidderWalletScreen> createState() => _BidderWalletScreenState();
}

class _BidderWalletScreenState extends State<BidderWalletScreen> {
  bool topupOpen = false;
  int topupAmt = 1000000;
  String method = 'qr';

  static const amounts = [500000, 1000000, 2000000, 5000000];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          const Text('Ví của tôi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Số dư khả dụng', style: TextStyle(color: Colors.white70, fontSize: 13)),
                Text(store.money(store.wallet), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                const Divider(color: Colors.white24, height: 28),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Đang giữ cọc', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          Text(store.money(store.walletHeld), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => topupOpen = !topupOpen),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.ink, shape: const StadiumBorder()),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Nạp tiền'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text('Mỗi phiên bạn tham gia, BidVibe giữ cọc 10% giá khởi điểm. Cọc tự động hoàn về ví nếu bạn không thắng, hoặc được trừ vào tổng tiền nếu bạn thắng.', style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4)),

          if (topupOpen) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Chọn số tiền nạp', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.6,
                    children: amounts.map((v) {
                      final on = topupAmt == v;
                      return OutlinedButton(
                        onPressed: () => setState(() => topupAmt = v),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: on ? AppColors.accent : Colors.white,
                          foregroundColor: on ? Colors.white : AppColors.ink,
                          side: BorderSide(color: on ? AppColors.accent : AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(store.money(v), style: const TextStyle(fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text('Phương thức', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  _MethodTile(title: 'VietQR', sub: 'Quét mã từ ứng dụng ngân hàng', selected: method == 'qr', onTap: () => setState(() => method = 'qr')),
                  const SizedBox(height: 8),
                  _MethodTile(title: 'Thẻ nội địa', sub: 'Thanh toán qua cổng ngân hàng', selected: method == 'card', onTap: () => setState(() => method = 'card')),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      onPressed: () {
                        store.topUp(topupAmt, method);
                        setState(() => topupOpen = false);
                      },
                      child: Text('Nạp ${store.money(topupAmt)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 22),
          const Text('Lịch sử giao dịch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(
              children: store.walletTxs.asMap().entries.map((e) {
                final x = e.value;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(border: e.key == 0 ? null : const Border(top: BorderSide(color: AppColors.border))),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 18, backgroundColor: AppColors.neutralBg, child: Icon(_iconFor(x.kind), size: 18, color: AppColors.neutralFg)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(x.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            Text(_when(x.at), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                          ],
                        ),
                      ),
                      Text(
                        x.kind == 'forfeit' ? 'Không hoàn' : '${x.amount > 0 ? '+' : '−'}${store.money(x.amount.abs())}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: x.kind == 'forfeit' ? AppColors.dangerStrong : (x.amount > 0 ? AppColors.successStrong : AppColors.ink)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String kind) {
    switch (kind) {
      case 'topup':
        return Icons.add;
      case 'hold':
        return Icons.lock_outline;
      case 'release':
      case 'refund':
        return Icons.replay;
      case 'forfeit':
        return Icons.block;
      default:
        return Icons.arrow_outward;
    }
  }

  String _when(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'Vừa xong';
    if (d.inHours < 1) return '${d.inMinutes} phút trước';
    if (d.inDays < 1) return '${d.inHours} giờ trước';
    return '${d.inDays} ngày trước';
  }
}

class _MethodTile extends StatelessWidget {
  final String title;
  final String sub;
  final bool selected;
  final VoidCallback onTap;
  const _MethodTile({required this.title, required this.sub, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF1F3F8) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: selected ? AppColors.accent : AppColors.border)),
          child: Row(
            children: [
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, size: 20, color: selected ? AppColors.accent : const Color(0xFF9AA0A9)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
