import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

(String, Color, Color) _src(String s) => switch (s) {
      'bidder' => ('Người mua báo', AppColors.progressBg, AppColors.progressFg),
      'seller' => ('Người bán báo', const Color(0xFFEEE6D9), const Color(0xFF5C4322)),
      _ => ('Kho báo cáo', AppColors.neutralBg, AppColors.neutralFg),
    };

(String, Color, Color) _st(String s) => s == 'open' ? ('Chờ xử lý', AppColors.pendingBg, AppColors.pendingFg) : ('Đã xử lý', AppColors.successBg, AppColors.successFg);

class AdminDisputesScreen extends StatefulWidget {
  const AdminDisputesScreen({super.key});

  @override
  State<AdminDisputesScreen> createState() => _AdminDisputesScreenState();
}

class _AdminDisputesScreenState extends State<AdminDisputesScreen> {
  String filter = 'all';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final rows = store.disputes.where((d) => filter == 'all' || d.status == filter).toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          const Text('QUẢN TRỊ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted, letterSpacing: 0.5)),
          const Text('Tranh chấp', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          const SizedBox(height: 4),
          const Text('Báo cáo từ người mua, người bán và kho vận. Bạn quyết định hoàn tiền hoặc giữ nguyên giao dịch.', style: TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilterChipButton(label: 'Tất cả', selected: filter == 'all', onTap: () => setState(() => filter = 'all')),
            FilterChipButton(label: 'Chờ xử lý', selected: filter == 'open', onTap: () => setState(() => filter = 'open')),
            FilterChipButton(label: 'Đã xử lý', selected: filter == 'resolved', onTap: () => setState(() => filter = 'resolved')),
          ]),
          const SizedBox(height: 12),
          if (rows.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('Không có tranh chấp nào phù hợp bộ lọc.', style: TextStyle(color: AppColors.muted)))),
          ...rows.map((d) {
            final (srcLabel, srcBg, srcFg) = _src(d.source);
            final (stLabel, stBg, stFg) = _st(d.status);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminDisputeDetailScreen(disputeId: d.id))),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: srcBg, borderRadius: BorderRadius.circular(12)), child: Text(srcLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: srcFg))),
                          const Spacer(),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: stBg, borderRadius: BorderRadius.circular(12)), child: Text(stLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: stFg))),
                        ]),
                        const SizedBox(height: 8),
                        Text(d.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.35)),
                        const SizedBox(height: 4),
                        Text(d.summary, style: const TextStyle(fontSize: 13, color: AppColors.mutedStrong)),
                        const SizedBox(height: 4),
                        Text('${d.code} · ${d.when}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class AdminDisputeDetailScreen extends StatelessWidget {
  final String disputeId;
  const AdminDisputeDetailScreen({super.key, required this.disputeId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final d = store.disputes.firstWhere((x) => x.id == disputeId);
    final (stLabel, _, _) = _st(d.status);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Chi tiết tranh chấp', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(d.code, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 6),
          Text(d.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: -0.2)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Diễn biến', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ...d.timeline.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        CircleAvatar(radius: 11, backgroundColor: AppColors.neutralBg, child: Text(e.$1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.neutralFg))),
                        const SizedBox(width: 10),
                        Expanded(child: Text(e.$2, style: const TextStyle(fontSize: 13, height: 1.4))),
                      ]),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF7F9FD), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFC9D2E6))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SỐ TIỀN LIÊN QUAN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                if (d.amount > 0) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Giá chốt phiên', style: TextStyle(fontSize: 14, color: AppColors.muted)), Text(store.money(d.amount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))]),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Đang giữ (ký quỹ)', style: TextStyle(fontSize: 14, color: AppColors.muted)), Text(store.money(d.escrow), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
            child: Text.rich(TextSpan(text: 'Trạng thái hiện tại: ', style: const TextStyle(fontSize: 13, color: AppColors.mutedStrong), children: [TextSpan(text: stLabel, style: const TextStyle(fontWeight: FontWeight.w700))])),
          ),
          if (d.resolution != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(10)),
              child: Text('Phán quyết: ${d.resolution}', style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.successFg)),
            ),
          ],
          if (d.status == 'open') ...[
            const SizedBox(height: 10),
            const Text('Hoàn tiền: ký quỹ trả về ví người mua. Cưỡng chế giải ngân: ký quỹ chuyển ngay cho người bán, bất kể người mua đã xác nhận nhận hàng hay chưa.', style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4)),
          ],
        ],
      ),
      bottomNavigationBar: d.status == 'open'
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BigActionButton(
                      label: 'Hoàn tiền người mua',
                      background: AppColors.dangerStrong,
                      onPressed: () {
                        store.resolveDispute(d.id, 'refund');
                        Navigator.of(context).pop();
                      },
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          store.resolveDispute(d.id, 'release');
                          Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        child: const Text('Cưỡng chế giải ngân cho người bán'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
