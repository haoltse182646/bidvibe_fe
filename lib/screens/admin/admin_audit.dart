import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Nhật ký giao dịch (View Transaction Audit Logs): mọi thao tác về ví,
/// đấu giá, thanh toán/ký quỹ và quản trị đều được store ghi lại, kể cả
/// các việc do bộ lập lịch hệ thống tự thực hiện (đóng phiên, hoàn cọc,
/// giải ngân ký quỹ, huỷ giao dịch quá hạn).
class AdminAuditScreen extends StatefulWidget {
  const AdminAuditScreen({super.key});

  @override
  State<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends State<AdminAuditScreen> {
  String filter = 'all';

  static const filters = [('all', 'Tất cả'), ('wallet', 'Ví'), ('auction', 'Đấu giá'), ('payment', 'Thanh toán'), ('admin', 'Quản trị'), ('system', 'Hệ thống')];

  (IconData, Color, Color) _style(String kind) => switch (kind) {
        'wallet' => (Icons.account_balance_wallet_outlined, AppColors.progressBg, AppColors.progressFg),
        'auction' => (Icons.gavel_outlined, AppColors.tileAntique, const Color(0xFF5C4322)),
        'payment' => (Icons.payments_outlined, AppColors.successBg, AppColors.successFg),
        'admin' => (Icons.admin_panel_settings_outlined, AppColors.dangerBg, AppColors.dangerFg),
        _ => (Icons.settings_suggest_outlined, AppColors.neutralBg, AppColors.neutralFg),
      };

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final rows = store.auditLogs.where((e) => filter == 'all' || e.kind == filter).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Nhật ký giao dịch', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: filters.map((f) => FilterChipButton(label: f.$2, selected: filter == f.$1, onTap: () => setState(() => filter = f.$1))).toList(),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('Chưa có bản ghi nào.', style: TextStyle(color: AppColors.muted)))),
          if (rows.isNotEmpty)
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
              child: Column(
                children: rows.asMap().entries.map((e) {
                  final AuditEntry x = e.value;
                  final (icon, bg, fg) = _style(x.kind);
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(border: e.key == 0 ? null : const Border(top: BorderSide(color: AppColors.border))),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(radius: 16, backgroundColor: bg, child: Icon(icon, size: 16, color: fg)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(x.action, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.35)),
                              if (x.ref != null) Text(x.ref!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.mutedStrong)),
                              const SizedBox(height: 2),
                              Text('${x.actor} · ${_when(x.at)}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                            ],
                          ),
                        ),
                        if (x.amount != null) Text(store.money(x.amount!), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
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

  String _when(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'Vừa xong';
    if (d.inHours < 1) return '${d.inMinutes} phút trước';
    if (d.inDays < 1) return '${d.inHours} giờ trước';
    return '${d.inDays} ngày trước';
  }
}
