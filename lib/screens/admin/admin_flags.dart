import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

(String, Color, Color) _sev(String s) => switch (s) {
      'high' => ('Cao', AppColors.dangerBg, AppColors.dangerFg),
      'medium' => ('Trung bình', AppColors.pendingBg, AppColors.pendingFg),
      _ => ('Thấp', AppColors.neutralBg, AppColors.neutralFg),
    };

(String, Color, Color) _status(String s) => switch (s) {
      'paused' => ('Đã tạm dừng', AppColors.dangerBg, AppColors.dangerFg),
      'verify' => ('Chờ xác minh', AppColors.progressBg, AppColors.progressFg),
      'safe' => ('An toàn', AppColors.successBg, AppColors.successFg),
      'terminated' => ('Đã chấm dứt', AppColors.dangerBg, AppColors.dangerFg),
      _ => ('Chờ xử lý', AppColors.pendingBg, AppColors.pendingFg),
    };

class AdminFlagsScreen extends StatefulWidget {
  const AdminFlagsScreen({super.key});

  @override
  State<AdminFlagsScreen> createState() => _AdminFlagsScreenState();
}

class _AdminFlagsScreenState extends State<AdminFlagsScreen> {
  String filter = 'all';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final rows = store.flags.where((f) => filter == 'all' || f.severity == filter).toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          const Text('QUẢN TRỊ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted, letterSpacing: 0.5)),
          const Text('Phiên bị gắn cờ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          const SizedBox(height: 4),
          const Text('AI phát hiện mẫu đặt giá bất thường. Quyết định cuối cùng thuộc về bạn.', style: TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChipButton(label: 'Tất cả', selected: filter == 'all', onTap: () => setState(() => filter = 'all')),
              FilterChipButton(label: 'Mức cao', selected: filter == 'high', onTap: () => setState(() => filter = 'high')),
              FilterChipButton(label: 'Trung bình', selected: filter == 'medium', onTap: () => setState(() => filter = 'medium')),
              FilterChipButton(label: 'Thấp', selected: filter == 'low', onTap: () => setState(() => filter = 'low')),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('Không có phiên nào phù hợp bộ lọc.', style: TextStyle(color: AppColors.muted)))),
          ...rows.map((f) {
            final (sevLabel, sevBg, sevFg) = _sev(f.severity);
            final (stLabel, stBg, stFg) = _status(f.status);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminFlagDetailScreen(flagId: f.id))),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: sevBg, borderRadius: BorderRadius.circular(12)), child: Text(sevLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sevFg))),
                          const Spacer(),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: stBg, borderRadius: BorderRadius.circular(12)), child: Text(stLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: stFg))),
                        ]),
                        const SizedBox(height: 8),
                        Text(f.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.35)),
                        const SizedBox(height: 4),
                        Text(f.reason, style: const TextStyle(fontSize: 13, color: AppColors.mutedStrong)),
                        const SizedBox(height: 4),
                        Text('${f.code} · Độ tin cậy ${f.confidence}%${f.reports > 0 ? ' · ${f.reports} báo cáo từ người dùng' : ''}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
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

class AdminFlagDetailScreen extends StatelessWidget {
  final String flagId;
  const AdminFlagDetailScreen({super.key, required this.flagId});

  /// Chấm dứt khẩn cấp: đóng phiên ngay, không có người thắng, hoàn cọc mọi bên.
  Future<void> _confirmTerminate(BuildContext context, AppStore store, FlaggedAuction f) async {
    final ctrl = TextEditingController(text: f.reason);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chấm dứt khẩn cấp phiên?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Phiên sẽ đóng ngay, không có người thắng và toàn bộ cọc được hoàn cho người tham gia. Không thể hoàn tác.', style: TextStyle(fontSize: 13, height: 1.4)),
            const SizedBox(height: 12),
            TextField(controller: ctrl, maxLines: 2, decoration: appInputDecoration('Lý do chấm dứt')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Chấm dứt', style: TextStyle(color: AppColors.dangerStrong, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    final reason = ctrl.text.trim().isEmpty ? f.reason : ctrl.text.trim();
    ctrl.dispose();
    if (ok == true && context.mounted) {
      store.emergencyTerminate(f.id, reason);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final f = store.flags.firstWhere((x) => x.id == flagId);
    final (sevLabel, sevBg, sevFg) = _sev(f.severity);
    final (stLabel, _, _) = _status(f.status);
    final terminated = f.status == 'terminated';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Chi tiết phiên bị gắn cờ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: sevBg, borderRadius: BorderRadius.circular(12)), child: Text(sevLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sevFg))),
            const SizedBox(width: 8),
            Text(f.code, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
          const SizedBox(height: 10),
          Text(f.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: -0.2)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF7F9FD), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFC9D2E6))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI GIẢI THÍCH', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Text(f.explain, style: const TextStyle(fontSize: 14, height: 1.55)),
                const SizedBox(height: 8),
                Text('Độ tin cậy ${f.confidence}%', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bằng chứng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ...f.evidence.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Expanded(child: Text(e.$1, style: const TextStyle(fontSize: 13, color: AppColors.muted))),
                        Text(e.$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ]),
                    )),
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
        ],
      ),
      bottomNavigationBar: terminated
          ? null
          : SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BigActionButton(
                label: f.status == 'paused' ? 'Phiên đang tạm dừng' : 'Tạm dừng phiên',
                background: AppColors.dangerStrong,
                onPressed: f.status == 'paused'
                    ? null
                    : () {
                        store.setFlagStatus(f.id, 'paused');
                        Navigator.of(context).pop();
                      },
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmTerminate(context, store, f),
                  icon: const Icon(Icons.dangerous_outlined, size: 18),
                  label: const Text('Chấm dứt khẩn cấp', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.dangerStrong, side: const BorderSide(color: AppColors.dangerStrong, width: 1.5), minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      store.setFlagStatus(f.id, 'verify');
                      Navigator.of(context).pop();
                    },
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: const Text('Yêu cầu xác minh'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      store.setFlagStatus(f.id, 'safe');
                      Navigator.of(context).pop();
                    },
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: const Text('Đánh dấu an toàn'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
