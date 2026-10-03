import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/order_status.dart';
import 'bidder_done.dart';
import 'bidder_payment.dart';

/// Chi tiết phiên đấu giá. Gồm 3 hành động chính của Bidder theo use case:
/// xem phiên trực tiếp (View Live Auction), đặt cọc tham gia (Place Auction
/// Deposit) và đặt giá (Place Bid), cộng với báo cáo phiên đáng ngờ.
class BidderDetailScreen extends StatelessWidget {
  final String auctionId;
  const BidderDetailScreen({super.key, required this.auctionId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final a = store.auctions.firstWhere((x) => x.id == auctionId);
    final now = DateTime.now();
    final rem = a.endsAt.difference(now).inSeconds;
    final urgent = !a.ended && !a.paused && rem <= 30;
    final isLeading = a.leading && !a.ended;
    final isOutbid = a.myBid > 0 && !a.leading && !a.ended;
    final isWon = a.ended && a.won;
    final isEndedOther = a.ended && !a.won;
    final leader = a.hist.isEmpty ? null : a.hist.first;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Phiên đấu giá', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: a.terminated ? null : () => _openReport(context, a),
            tooltip: 'Báo cáo phiên đáng ngờ',
            icon: const Icon(Icons.flag_outlined),
          ),
          const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.bookmark_border)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(color: categoryTileColor(a.cat), borderRadius: BorderRadius.circular(18)),
                    alignment: Alignment.center,
                    child: Icon(_iconFor(a.cat), size: 72, color: AppColors.neutralFg),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.verified_outlined, size: 14, color: AppColors.successStrong),
                      SizedBox(width: 6),
                      Text('Đã thẩm định', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.successStrong)),
                    ]),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(12)),
                    child: const Text('Ảnh 1/4 · ảnh minh hoạ', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(labelForCategory(a.cat), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(a.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: -0.2)),

          if (a.paused && !a.ended) const _Banner(success: null, title: 'Phiên đang tạm dừng', body: 'Admin đang xem xét phiên này. Đồng hồ và việc đặt giá được tạm dừng cho tới khi có kết luận.'),
          if (isLeading) _Banner(success: true, title: 'Bạn đang dẫn đầu', body: 'Giá của bạn ${store.money(a.myBid)} đang cao nhất. Cọc ${store.money(a.hold)} đang được giữ.'),
          if (isOutbid) _Banner(success: false, title: 'Bạn đã bị vượt giá', body: '${leader?.who ?? 'Người khác'} vừa đặt ${store.money(a.price)}. Cọc ${store.money(a.hold)} vẫn được giữ — đặt lại để giành vị trí dẫn đầu.'),
          if (!a.ended && a.joined && !isLeading && !isOutbid && !a.paused) _Banner(success: null, title: 'Bạn đã đặt cọc tham gia', body: 'Cọc ${store.money(a.hold)} đang được giữ. Đặt giá để bắt đầu cạnh tranh.'),
          if (isWon && !a.paid)
            _Banner(success: true, title: 'Chúc mừng, bạn đã thắng phiên này', body: 'Giá chốt ${store.money(a.price)}. Thanh toán trong 24 giờ, cọc ${store.money(a.hold)} sẽ được trừ vào tổng tiền.'),
          if (isWon && a.paid) _Banner(success: true, title: 'Bạn đã thắng và đã thanh toán', body: 'Trạng thái đơn: ${orderStatus(a).$1}. Chạm "Theo dõi đơn hàng" để xem hành trình.'),
          if (isEndedOther && a.terminated) _Banner(success: false, title: 'Phiên đã bị chấm dứt', body: 'Admin đã chấm dứt khẩn cấp phiên này${a.terminatedReason == null ? '' : ': ${a.terminatedReason}'}. ${a.joined ? 'Cọc đã hoàn về ví.' : ''}'),
          if (isEndedOther && a.paymentExpired) const _Banner(success: false, title: 'Quá hạn thanh toán', body: 'Bạn không thanh toán trong 24 giờ nên giao dịch bị huỷ và khoản cọc không được hoàn.'),
          if (isEndedOther && !a.terminated && !a.paymentExpired) _Banner(success: null, title: 'Phiên đã kết thúc', body: a.joined ? 'Bạn không thắng phiên này. Cọc đã được hoàn về ví.' : 'Phiên này đã có người thắng.'),

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isOutbid ? AppColors.dangerStrong : (isLeading ? AppColors.successStrong : AppColors.border)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.ended ? (isWon ? 'Giá chốt' : 'Giá cuối') : 'Giá hiện tại', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      Text(store.money(a.price), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
                      const SizedBox(height: 6),
                      Text(leader == null ? 'Chưa có lượt đặt giá' : '${leader.who == 'Bạn' ? 'Bạn' : leader.who} ${a.ended ? 'đã dẫn đầu' : 'đang dẫn đầu'}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(a.ended ? 'Trạng thái' : (a.paused ? 'Đang tạm dừng' : 'Còn lại'), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    CountdownText(
                      endsAt: a.endsAt,
                      ended: a.ended,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: urgent ? AppColors.dangerStrong : AppColors.ink),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (urgent && !a.ended) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppColors.pendingBg, borderRadius: BorderRadius.circular(10)),
              child: const Text('Đặt giá trong 30 giây cuối sẽ gia hạn phiên thêm 30 giây.', style: TextStyle(fontSize: 12, color: Color(0xFF7A4B00))),
            ),
          ],
          if (!a.ended && !a.paused) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFBDBAB0), style: BorderStyle.solid), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Expanded(child: Text('DEMO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted, letterSpacing: 0.5))),
                  OutlinedButton(onPressed: () => store.demoForceOutbid(a.id), child: const Text('Mô phỏng bị vượt giá', style: TextStyle(fontSize: 12))),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: () => store.demoEndSoon(a.id), child: const Text('Còn 10 giây', style: TextStyle(fontSize: 12))),
                ],
              ),
            ),
          ],
          if (isWon && !a.paid) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFBDBAB0)), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Expanded(child: Text('DEMO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted, letterSpacing: 0.5))),
                  OutlinedButton(onPressed: () => store.demoExpirePayment(a.id), child: const Text('Mô phỏng quá hạn 24 giờ', style: TextStyle(fontSize: 12))),
                ],
              ),
            ),
          ],

          const SizedBox(height: 22),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Lịch sử đặt giá', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text('${a.count} lượt đặt', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: a.hist.isEmpty
                ? const Padding(padding: EdgeInsets.all(18), child: Center(child: Text('Chưa có lượt đặt giá nào. Hãy là người đầu tiên!', style: TextStyle(fontSize: 13, color: AppColors.muted))))
                : Column(
                    children: a.hist.take(5).toList().asMap().entries.map((e) {
                      final h = e.value;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: h.me ? const Color(0xFFF0F8F3) : null,
                          border: e.key == 0 ? null : const Border(top: BorderSide(color: AppColors.border)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: h.me ? AppColors.successStrong : AppColors.neutralBg,
                              child: Text(h.me ? 'B' : h.who.substring(7).toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: h.me ? Colors.white : AppColors.neutralFg)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(h.me ? 'Bạn' : h.who, style: TextStyle(fontSize: 14, fontWeight: e.key == 0 ? FontWeight.w700 : FontWeight.w500)),
                                  Text(_ago(h.at), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                ],
                              ),
                            ),
                            Text(store.money(h.amount), style: TextStyle(fontSize: 15, fontWeight: e.key == 0 ? FontWeight.w700 : FontWeight.w500)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),

          const SizedBox(height: 22),
          const Text('Thông tin sản phẩm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.desc, style: const TextStyle(fontSize: 14, height: 1.5)),
                const Divider(height: 24),
                _kv('Tình trạng', a.cond),
                _kv('Giá khởi điểm', store.money(a.start)),
                _kv('Bước giá tối thiểu', store.money(a.step)),
                _kv('Cọc tham gia (10%)', store.money(a.deposit)),
                _kv('Người bán', a.rating == 'Chưa có' ? '${a.seller} · người bán mới' : '${a.seller} · ${a.rating}/5'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(10)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.verified_outlined, size: 16, color: AppColors.successFg),
                    const SizedBox(width: 8),
                    Expanded(child: Text(a.appraised, style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.successFg))),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text('Sau khi thắng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('1. Thanh toán trong 24 giờ; khoản cọc tham gia được trừ vào tổng tiền. Nếu không thắng, cọc tự động hoàn về ví.', style: TextStyle(fontSize: 13, height: 1.45)),
              SizedBox(height: 8),
              Text('2. Người bán gửi hàng đến kho BidVibe; kho kiểm tra đối chiếu với hồ sơ thẩm định.', style: TextStyle(fontSize: 13, height: 1.45)),
              SizedBox(height: 8),
              Text('3. Kho giao đến địa chỉ của bạn, có theo dõi hành trình. Bạn xác nhận nhận hàng để tiền được giải ngân cho người bán.', style: TextStyle(fontSize: 13, height: 1.45)),
            ]),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 14), child: _bottom(context, store, a, isLeading: isLeading, isWon: isWon))),
    );
  }

  Widget _bottom(BuildContext context, AppStore store, Auction a, {required bool isLeading, required bool isWon}) {
    if (a.ended) {
      if (isWon && !a.paid) {
        return BigActionButton(label: 'Thanh toán ngay', background: AppColors.successStrong, onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BidderPaymentScreen(auctionId: a.id))));
      }
      if (isWon && a.paid) {
        return BigActionButton(label: 'Theo dõi đơn hàng', icon: Icons.local_shipping_outlined, onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BidderDoneScreen(auctionId: a.id))));
      }
      return BigActionButton(label: 'Xem phiên khác', onPressed: () => Navigator.of(context).pop());
    }
    if (a.paused) {
      return const BigActionButton(label: 'Phiên đang tạm dừng', onPressed: null);
    }
    if (!a.joined) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cần đặt cọc ${store.money(a.deposit)} (10% giá khởi điểm) để tham gia. Số dư ví: ${store.money(store.wallet)}. Cọc tự động hoàn nếu bạn không thắng.', style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4)),
          const SizedBox(height: 8),
          BigActionButton(label: 'Đặt cọc ${store.money(a.deposit)} để tham gia', icon: Icons.lock_outline, onPressed: () => store.joinAuction(a.id)),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isLeading ? 'Bạn đang dẫn đầu. Nút đặt giá sẽ mở lại nếu có người vượt giá.' : 'Đã cọc ${store.money(a.hold)} — hoàn tự động nếu bạn không thắng.',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _BidButton(label: '+50.000', to: a.price + 50000, disabled: isLeading, onTap: () => store.placeBid(a.id, 50000), money: store.money)),
            const SizedBox(width: 10),
            Expanded(child: _BidButton(label: '+100.000', to: a.price + 100000, disabled: isLeading, onTap: () => store.placeBid(a.id, 100000), money: store.money)),
          ],
        ),
      ],
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          Flexible(child: Text(v, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ]),
      );

  IconData _iconFor(String cat) {
    switch (cat) {
      case 'shoes':
        return Icons.directions_walk;
      case 'elec':
        return Icons.camera_alt_outlined;
      default:
        return Icons.emoji_objects_outlined;
    }
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t).inSeconds;
    if (d < 3) return 'Vừa xong';
    if (d < 60) return '$d giây trước';
    if (d < 3600) return '${d ~/ 60} phút trước';
    if (d < 86400) return '${d ~/ 3600} giờ trước';
    return '${d ~/ 86400} ngày trước';
  }

  void _openReport(BuildContext context, Auction a) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ReportSheet(auction: a),
    );
  }
}

/// Báo cáo phiên đáng ngờ (Report Suspicious Auction).
class _ReportSheet extends StatefulWidget {
  final Auction auction;
  const _ReportSheet({required this.auction});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  static const reasons = ['Nghi ngờ đặt giá ảo / thông đồng', 'Sản phẩm có dấu hiệu hàng giả', 'Mô tả hoặc ảnh không đúng thực tế', 'Người bán có hành vi đáng ngờ', 'Lý do khác'];
  String? reason;
  final noteCtrl = TextEditingController();

  @override
  void dispose() {
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Báo cáo phiên đáng ngờ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(widget.auction.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            const SizedBox(height: 12),
            ...reasons.map((r) {
              final on = reason == r;
              return InkWell(
                onTap: () => setState(() => reason = r),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Icon(on ? Icons.radio_button_checked : Icons.radio_button_off, size: 20, color: on ? AppColors.accent : const Color(0xFF9AA0A9)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(r, style: const TextStyle(fontSize: 14))),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 8),
            TextField(controller: noteCtrl, maxLines: 2, decoration: appInputDecoration('Ghi chú thêm (không bắt buộc)')),
            const SizedBox(height: 14),
            BigActionButton(
              label: 'Gửi báo cáo',
              background: AppColors.dangerStrong,
              onPressed: reason == null
                  ? null
                  : () {
                      context.read<AppStore>().reportSuspicious(widget.auction.id, reason!, noteCtrl.text);
                      Navigator.of(context).pop();
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final bool? success; // true=xanh, false=đỏ, null=xám
  final String title;
  final String body;
  const _Banner({required this.success, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final Color bg = success == true ? AppColors.successBg : (success == false ? AppColors.dangerBg : AppColors.neutralBg);
    final Color fg = success == true ? AppColors.successFg : (success == false ? AppColors.dangerFg : AppColors.mutedStrong);
    final Color border = success == true ? const Color(0xFFB9DCCA) : (success == false ? AppColors.dangerStrong : AppColors.border);
    final IconData icon = success == true ? Icons.check_circle : (success == false ? Icons.error_outline : Icons.info_outline);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: 14, backgroundColor: success == null ? AppColors.neutralFg : fg, child: Icon(icon, size: 16, color: Colors.white)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fg)),
                  const SizedBox(height: 2),
                  Text(body, style: TextStyle(fontSize: 13, height: 1.4, color: fg)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BidButton extends StatelessWidget {
  final String label;
  final int to;
  final bool disabled;
  final VoidCallback onTap;
  final String Function(num) money;
  const _BidButton({required this.label, required this.to, required this.disabled, required this.onTap, required this.money});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ElevatedButton(
        onPressed: disabled ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          disabledBackgroundColor: const Color(0xFFD9D8D2),
          foregroundColor: Colors.white,
          disabledForegroundColor: AppColors.muted,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text('→ ${money(to)}', style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
