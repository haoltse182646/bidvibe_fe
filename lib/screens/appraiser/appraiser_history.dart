import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../store.dart';
import '../../theme.dart';

class AppraiserHistoryScreen extends StatelessWidget {
  const AppraiserHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          const Text('THẨM ĐỊNH', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted, letterSpacing: 0.5)),
          const Text('Đã xử lý', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(
              children: store.appraisalHistory.asMap().entries.map((e) {
                final h = e.value;
                final approved = h.result == 'approved';
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(border: e.key == 0 ? null : const Border(top: BorderSide(color: AppColors.border))),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: approved ? AppColors.successBg : AppColors.dangerBg,
                        child: Icon(approved ? Icons.check : Icons.close, size: 16, color: approved ? AppColors.successStrong : AppColors.dangerStrong),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(h.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.35)),
                            Text('${h.seller} · ${h.when}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                            if (h.note != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(h.note!, style: const TextStyle(fontSize: 12, color: AppColors.dangerFg))),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: approved ? AppColors.successBg : AppColors.dangerBg, borderRadius: BorderRadius.circular(11)),
                        child: Text(approved ? 'Đã duyệt' : 'Đã từ chối', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: approved ? AppColors.successFg : AppColors.dangerFg)),
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
}
