import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Sửa tham số phiên đấu giá (Edit Auction Parameters). Chỉ mở được khi
/// phiếu còn ở trạng thái chờ thẩm định / cần bổ sung, hoặc đang công
/// khai nhưng chưa có ai đặt giá. Khi thẩm định viên yêu cầu bổ sung hồ
/// sơ, màn này cũng là nơi người bán gửi thêm ảnh/giấy tờ.
class SellerEditScreen extends StatefulWidget {
  final String listingId;
  const SellerEditScreen({super.key, required this.listingId});

  @override
  State<SellerEditScreen> createState() => _SellerEditScreenState();
}

class _SellerEditScreenState extends State<SellerEditScreen> {
  late final TextEditingController titleCtrl;
  late final TextEditingController descCtrl;
  late final TextEditingController startCtrl;
  late String cond;
  late int hours;
  int extraPhotos = 0;

  static const durations = [(24, '24 giờ'), (72, '3 ngày'), (168, '7 ngày')];
  static const conds = ['Mới', 'Như mới', 'Đã qua sử dụng'];

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    final l = store.sellerListings.firstWhere((x) => x.id == widget.listingId);
    titleCtrl = TextEditingController(text: l.title);
    descCtrl = TextEditingController(text: l.desc);
    startCtrl = TextEditingController(text: store.fmt(l.start));
    cond = conds.contains(l.cond) ? l.cond : 'Đã qua sử dụng';
    hours = durations.any((d) => d.$1 == l.durationHours) ? l.durationHours : 24;
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    startCtrl.dispose();
    super.dispose();
  }

  int? get _start => int.tryParse(startCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final l = store.sellerListings.firstWhere((x) => x.id == widget.listingId);
    final needInfo = l.status == 'needinfo';
    final valid = titleCtrl.text.trim().isNotEmpty && (_start ?? 0) > 0 && (!needInfo || extraPhotos > 0);
    final editable = l.canEdit;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(needInfo ? 'Bổ sung hồ sơ' : 'Chỉnh sửa phiên', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          if (!editable)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.neutralBg, borderRadius: BorderRadius.circular(12)),
              child: const Text('Phiên này không còn chỉnh sửa được (đã có lượt đặt giá hoặc đã qua giai đoạn thẩm định).', style: TextStyle(fontSize: 13, height: 1.4)),
            ),
          if (needInfo) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.pendingBg, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Thẩm định viên yêu cầu bổ sung', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.pendingFg)),
                  const SizedBox(height: 6),
                  ...l.requests.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.chevron_right, size: 16, color: AppColors.pendingFg),
                          Expanded(child: Text(r, style: const TextStyle(fontSize: 13, color: AppColors.pendingFg))),
                        ]),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text('Ảnh/giấy tờ bổ sung ($extraPhotos/4)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: List.generate(4, (i) {
                final filled = i < extraPhotos;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == 3 ? 0 : 8),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Material(
                        color: filled ? categoryTileColor(l.cat) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => extraPhotos = filled ? extraPhotos - 1 : extraPhotos + 1),
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
            const SizedBox(height: 18),
          ],
          if (l.status == 'live' && l.count == 0)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.pendingBg, borderRadius: BorderRadius.circular(12)),
              child: const Text('Phiên đang công khai nhưng chưa có ai đặt giá. Lưu thay đổi sẽ đặt lại giờ kết thúc theo thời lượng bạn chọn.', style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.pendingFg)),
            ),
          const FieldLabel('Tên sản phẩm'),
          TextField(controller: titleCtrl, enabled: editable, onChanged: (_) => setState(() {}), decoration: appInputDecoration(null)),
          const SizedBox(height: 16),
          const FieldLabel('Tình trạng'),
          Wrap(spacing: 8, children: conds.map((c) => _chip(c, cond == c, editable ? () => setState(() => cond = c) : null)).toList()),
          const SizedBox(height: 16),
          const FieldLabel('Mô tả'),
          TextField(controller: descCtrl, enabled: editable, maxLines: 4, decoration: appInputDecoration(null)),
          const SizedBox(height: 16),
          const FieldLabel('Giá khởi điểm (₫)'),
          TextField(controller: startCtrl, enabled: editable, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: appInputDecoration('Nhập giá khởi điểm')),
          const SizedBox(height: 6),
          Text('Cọc tham gia của người mua: ${store.money(_start == null ? 0 : ((_start! * 0.1) / 1000).round() * 1000)} (10% giá khởi điểm).', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 16),
          const FieldLabel('Thời lượng phiên'),
          Wrap(spacing: 8, children: durations.map((d) => _chip(d.$2, hours == d.$1, editable ? () => setState(() => hours = d.$1) : null)).toList()),
        ],
      ),
      bottomNavigationBar: editable
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: BigActionButton(
                  label: needInfo ? 'Gửi bổ sung cho thẩm định' : 'Lưu thay đổi',
                  onPressed: valid
                      ? () {
                          final messenger = ScaffoldMessenger.of(context);
                          final ok = store.updateListing(l.id, title: titleCtrl.text.trim(), desc: descCtrl.text.trim(), start: _start!, durationHours: hours, cond: cond);
                          if (ok && needInfo) store.sellerSubmitMoreInfo(l.id, extraPhotos: extraPhotos);
                          messenger.showSnackBar(SnackBar(content: Text(needInfo ? 'Đã gửi bổ sung. Hồ sơ quay lại hàng chờ thẩm định.' : 'Đã lưu thay đổi phiên.')));
                          Navigator.of(context).pop();
                        }
                      : null,
                ),
              ),
            )
          : null,
    );
  }

  Widget _chip(String label, bool on, VoidCallback? onTap) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: on ? AppColors.accent : Colors.white,
          foregroundColor: on ? Colors.white : AppColors.ink,
          side: BorderSide(color: on ? AppColors.accent : const Color(0xFFCFCCC3)),
          shape: const StadiumBorder(),
        ),
        child: Text(label),
      );
}
