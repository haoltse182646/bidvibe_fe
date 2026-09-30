import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../store.dart';
import '../../theme.dart';
import 'admin_flags.dart';
import 'admin_audit.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int barSel = 5;

  static const vals = [17.2, 19.8, 16.4, 21.5, 20.1, 26.7, 20.6];
  static const _wd = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  /// Nhãn thứ của 7 ngày gần nhất, ngày cuối là hôm nay.
  List<String> get days {
    final now = DateTime.now();
    return List.generate(7, (i) => _wd[now.subtract(Duration(days: 6 - i)).weekday - 1]);
  }

  String _range() {
    final now = DateTime.now();
    String f(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    return '${f(now.subtract(const Duration(days: 6)))} – ${f(now)}/${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final topFlags = store.flags.where((f) => f.severity == 'high').toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          const Text('QUẢN TRỊ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted, letterSpacing: 0.5)),
          const Text('Tổng quan', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          const SizedBox(height: 4),
          Row(children: [
            Text('7 ngày gần nhất · ${_range()}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          ]),
          const SizedBox(height: 6),
          Row(children: const [
            Icon(Icons.circle, size: 8, color: AppColors.successStrong),
            SizedBox(width: 6),
            Text('Dữ liệu trực tiếp', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.successStrong)),
          ]),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              const _Kpi(label: 'Doanh thu nền tảng', value: '142,3 tr ₫', delta: '+12,4% so tuần trước', color: AppColors.successStrong),
              _Kpi(label: 'Phiên đang hoạt động', value: '${store.liveAuctionsCount}', delta: '${store.endingIn24hCount} phiên kết thúc 24h tới', color: AppColors.muted),
              _Kpi(label: 'Tranh chấp đang mở', value: '${store.openDisputesCount}', delta: 'Tỷ lệ tranh chấp 1,8% (−0,8 điểm)', color: store.openDisputesCount > 0 ? AppColors.dangerStrong : AppColors.successStrong),
              _Kpi(label: 'Chờ thẩm định', value: '${store.appraisalPendingCount}', delta: 'TB chờ 31 giờ', color: const Color(0xFF7A4B00)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Doanh thu nền tảng theo ngày', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                const Text('Đơn vị: triệu ₫ · chạm một cột để xem', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 170,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(vals.length, (i) {
                      final on = barSel == i;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: GestureDetector(
                            onTap: () => setState(() => barSel = i),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (on) Text(vals[i].toStringAsFixed(1).replaceAll('.', ','), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Container(
                                  height: vals[i] / 26.7 * 120,
                                  decoration: BoxDecoration(color: on ? AppColors.accent : const Color(0xFFC3CADB), borderRadius: const BorderRadius.vertical(top: Radius.circular(6))),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const Divider(height: 20),
                Row(
                  children: days.map((d) => Expanded(child: Text(d, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.muted)))).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Phiên nghi vấn', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ...topFlags.map((f) => InkWell(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminFlagDetailScreen(flagId: f.id))),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(11)),
                                child: const Text('Cao', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.dangerFg)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(f.reason, style: const TextStyle(fontSize: 12, color: AppColors.muted), overflow: TextOverflow.ellipsis)),
                            ]),
                          ],
                        ),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hàng đợi vận hành', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                _QueueRow(label: 'Chờ thẩm định', n: store.appraisalPendingCount),
                _QueueRow(label: 'Chờ nhập kho', n: store.whWaitingCount),
                _QueueRow(label: 'Chờ giao cho người mua', n: store.whToDeliverCount),
                _QueueRow(label: 'Tranh chấp chờ xử lý', n: store.openDisputesCount),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminAuditScreen())),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                child: Row(
                  children: [
                    const CircleAvatar(backgroundColor: AppColors.progressBg, child: Icon(Icons.receipt_long_outlined, color: AppColors.accent)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Nhật ký giao dịch', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          Text('${store.auditLogs.length} bản ghi · ví, đấu giá, thanh toán, quản trị', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final String delta;
  final Color color;
  const _Kpi({required this.label, required this.value, required this.delta, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          const SizedBox(height: 4),
          Text(delta, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  final String label;
  final int n;
  const _QueueRow({required this.label, required this.n});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Text('$n', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
