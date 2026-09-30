import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../customer/customer_chatbot.dart';
import '../customer/customer_dispute.dart';
import 'seller_edit.dart';

/// Danh sách phiên ký gửi của gian hàng đang đăng nhập. Từ đây người bán
/// sửa tham số phiên (khi còn được phép), bổ sung hồ sơ theo yêu cầu của
/// thẩm định viên, và báo tranh chấp với đơn đã bán.
class SellerListScreen extends StatefulWidget {
  const SellerListScreen({super.key});

  @override
  State<SellerListScreen> createState() => _SellerListScreenState();
}

class _SellerListScreenState extends State<SellerListScreen> {
  String filter = 'all';

  static const _wait = ['appraisal', 'needinfo', 'rejected'];
  static const _process = ['unpaid', 'shipping', 'disputed'];
  static const _done = ['sold', 'cancelled'];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final items = store.myListings;
    final nLive = items.where((i) => i.status == 'live').length;
    final nWait = items.where((i) => i.status == 'appraisal' || i.status == 'needinfo').length;
    final nSold = items.where((i) => i.status == 'sold').length;

    final filtered = items.where((i) {
      switch (filter) {
        case 'live':
          return i.status == 'live';
        case 'wait':
          return _wait.contains(i.status);
        case 'process':
          return _process.contains(i.status);
        case 'done':
          return _done.contains(i.status);
        default:
          return true;
      }
    }).toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('KÝ GỬI · ${store.myShop.toUpperCase()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted, letterSpacing: 0.5)),
                    const Text('Phiên của tôi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CustomerChatbotScreen())),
                tooltip: 'Hỗ trợ',
                icon: const Icon(Icons.support_agent, color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatBox(n: nLive, label: 'Đang chạy')),
              const SizedBox(width: 8),
              Expanded(child: _StatBox(n: nWait, label: 'Chờ duyệt')),
              const SizedBox(width: 8),
              Expanded(child: _StatBox(n: nSold, label: 'Đã bán')),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChipButton(label: 'Tất cả', selected: filter == 'all', onTap: () => setState(() => filter = 'all')),
              FilterChipButton(label: 'Đang chạy', selected: filter == 'live', onTap: () => setState(() => filter = 'live')),
              FilterChipButton(label: 'Chờ duyệt', selected: filter == 'wait', onTap: () => setState(() => filter = 'wait')),
              FilterChipButton(label: 'Đang xử lý', selected: filter == 'process', onTap: () => setState(() => filter = 'process')),
              FilterChipButton(label: 'Hoàn tất', selected: filter == 'done', onTap: () => setState(() => filter = 'done')),
            ],
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('Chưa có phiên nào ở nhóm này.', style: TextStyle(color: AppColors.muted)))),
          ...filtered.map((it) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _ListingCard(item: it))),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final int n;
  final String label;
  const _StatBox({required this.n, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$n', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final SellerListing item;
  const _ListingCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final sh = store.myShipments.where((s) => s.id == item.id).toList();
    final shipAt = sh.isEmpty ? 0 : sh.first.at;
    final (pillText, tone) = switch (item.status) {
      'live' => ('Đang đấu giá', StatusTone.success),
      'appraisal' => ('Chờ thẩm định', StatusTone.pending),
      'needinfo' => ('Cần bổ sung hồ sơ', StatusTone.pending),
      'rejected' => ('Bị từ chối', StatusTone.danger),
      'unpaid' => ('Chờ người mua thanh toán', StatusTone.pending),
      'shipping' => switch (shipAt) {
          1 => ('Cần gửi hàng đến kho', StatusTone.pending),
          2 => ('Kho đang xử lý', StatusTone.progress),
          3 => ('Kho đang giao cho người mua', StatusTone.progress),
          _ => ('Đã giao · chờ người mua xác nhận', StatusTone.progress),
        },
      'disputed' => ('Đang tranh chấp', StatusTone.danger),
      'cancelled' => ('Đã huỷ', StatusTone.neutral),
      _ => ('Đã bán', StatusTone.success),
    };
    final canDispute = item.status == 'shipping' && shipAt >= 2 || item.status == 'sold';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CategoryThumb(cat: item.cat, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.35)),
                    const SizedBox(height: 6),
                    StatusPill(label: pillText, tone: tone),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 22),
          if (item.status == 'live')
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.count == 0 ? 'Giá khởi điểm' : 'Giá hiện tại', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                    Text(store.money(item.price), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                    Text(item.count == 0 ? 'Chưa có lượt đặt giá' : '${item.count} lượt đặt giá', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Còn lại', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                    if (item.endsAt != null) CountdownText(endsAt: item.endsAt!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                  ],
                ),
              ],
            )
          else if (item.status == 'sold' || item.status == 'unpaid' || item.status == 'shipping' || item.status == 'disputed')
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Giá chốt', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                Text(store.money(item.price), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            )
          else if (item.status == 'needinfo') ...[
            const Text('Thẩm định viên yêu cầu bổ sung:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ...item.requests.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.chevron_right, size: 16, color: AppColors.pendingFg),
                    Expanded(child: Text(r, style: const TextStyle(fontSize: 13, color: AppColors.mutedStrong))),
                  ]),
                )),
          ] else if (item.status == 'rejected' || item.status == 'cancelled')
            Text(item.note ?? 'Không có ghi chú.', style: TextStyle(fontSize: 13, height: 1.4, color: item.status == 'rejected' ? AppColors.dangerFg : AppColors.muted))
          else
            const Text('Chuyên gia đang thẩm định hồ sơ. Phiên sẽ công khai ngay khi được duyệt.', style: TextStyle(fontSize: 13, color: AppColors.muted)),

          if (item.status == 'shipping' && shipAt == 1) ...[
            const SizedBox(height: 8),
            const Text('Người mua đã thanh toán. Vào tab "Gửi kho" để xác nhận gửi hàng.', style: TextStyle(fontSize: 12, color: AppColors.pendingFg)),
          ],
          if (item.status == 'live' && !item.canEdit) ...[
            const SizedBox(height: 8),
            const Text('Đã có lượt đặt giá nên không thể chỉnh sửa tham số phiên.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
          if (item.canEdit || item.status == 'needinfo' || canDispute) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (item.canEdit)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SellerEditScreen(listingId: item.id))),
                      icon: Icon(item.status == 'needinfo' ? Icons.upload_file_outlined : Icons.edit_outlined, size: 16),
                      label: Text(item.status == 'needinfo' ? 'Bổ sung hồ sơ' : 'Chỉnh sửa phiên', style: const TextStyle(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                if (canDispute)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CustomerDisputeScreen(source: 'seller', title: item.title, listingId: item.id))),
                      icon: const Icon(Icons.gavel_outlined, size: 16),
                      label: const Text('Báo tranh chấp', style: TextStyle(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.dangerStrong, side: const BorderSide(color: AppColors.dangerStrong), minimumSize: const Size.fromHeight(44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
