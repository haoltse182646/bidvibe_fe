import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Mở tranh chấp (Raise Dispute) — dùng chung cho Người mua và Người bán.
/// Tranh chấp được đưa vào mục "Tranh chấp" của Admin, đồng thời khoản ký
/// quỹ của đơn được giữ lại cho tới khi Admin phán quyết.
class CustomerDisputeScreen extends StatefulWidget {
  final String source; // bidder | seller
  final String title;
  final String? auctionId;
  final String? listingId;
  const CustomerDisputeScreen({super.key, required this.source, required this.title, this.auctionId, this.listingId});

  @override
  State<CustomerDisputeScreen> createState() => _CustomerDisputeScreenState();
}

class _CustomerDisputeScreenState extends State<CustomerDisputeScreen> {
  final detailCtrl = TextEditingController();
  String? reason;
  int photos = 0;

  static const _bidderReasons = ['Hàng không đúng mô tả', 'Hàng bị hư hỏng khi vận chuyển', 'Thiếu phụ kiện so với mô tả', 'Giao hàng quá chậm', 'Lý do khác'];
  static const _sellerReasons = ['Người mua từ chối nhận hàng', 'Người mua đòi huỷ đơn không lý do', 'Người mua không thanh toán đúng hạn', 'Thông tin giao hàng sai', 'Lý do khác'];

  @override
  void dispose() {
    detailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reasons = widget.source == 'bidder' ? _bidderReasons : _sellerReasons;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Báo vấn đề / Tranh chấp', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Text(widget.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.35)),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.pendingBg, borderRadius: BorderRadius.circular(12)),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.lock_outline, size: 16, color: AppColors.pendingFg),
              SizedBox(width: 8),
              Expanded(child: Text('Khi bạn gửi tranh chấp, khoản ký quỹ của đơn sẽ được giữ lại và chưa chuyển cho người bán cho tới khi Admin phán quyết.', style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.pendingFg))),
            ]),
          ),
          const SizedBox(height: 18),
          const Text('Lý do', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...reasons.map((r) {
            final on = reason == r;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: on ? const Color(0xFFF1F3F8) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => reason = r),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: on ? AppColors.accent : AppColors.border)),
                    child: Row(children: [
                      Icon(on ? Icons.radio_button_checked : Icons.radio_button_off, size: 20, color: on ? AppColors.accent : const Color(0xFF9AA0A9)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(r, style: const TextStyle(fontSize: 14))),
                    ]),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
          const FieldLabel('Mô tả chi tiết'),
          TextField(controller: detailCtrl, maxLines: 4, decoration: appInputDecoration('Mô tả cụ thể vấn đề bạn gặp phải…')),
          const SizedBox(height: 16),
          Text('Ảnh/bằng chứng ($photos/4)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: List.generate(4, (i) {
              final filled = i < photos;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 3 ? 0 : 8),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Material(
                      color: filled ? AppColors.neutralBg : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => photos = filled ? photos - 1 : photos + 1),
                        child: Container(
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: filled ? null : Border.all(color: const Color(0xFF9AA0A9), width: 1.5)),
                          child: Icon(filled ? Icons.image_outlined : Icons.add, color: filled ? AppColors.neutralFg : AppColors.muted),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: BigActionButton(
            label: 'Gửi tranh chấp',
            background: AppColors.dangerStrong,
            onPressed: reason == null
                ? null
                : () {
                    final messenger = ScaffoldMessenger.of(context);
                    context.read<AppStore>().raiseDispute(
                          source: widget.source,
                          auctionId: widget.auctionId,
                          listingId: widget.listingId,
                          title: widget.title,
                          reason: reason!,
                          detail: detailCtrl.text,
                        );
                    messenger.showSnackBar(const SnackBar(content: Text('Đã gửi tranh chấp. Ký quỹ được giữ lại cho tới khi Admin phán quyết.')));
                    Navigator.of(context).pop();
                  },
          ),
        ),
      ),
    );
  }
}
