import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Quản lý tài khoản vận hành (Thẩm định, Kho vận): xem tải công việc,
/// tạm khoá / kích hoạt lại, và mời tài khoản mới.
class AdminAccountsScreen extends StatefulWidget {
  const AdminAccountsScreen({super.key});

  @override
  State<AdminAccountsScreen> createState() => _AdminAccountsScreenState();
}

class _AdminAccountsScreenState extends State<AdminAccountsScreen> {
  String filter = 'all';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final rows = store.users.where((a) {
      // Màn hình này chỉ quản lý tài khoản vận hành.
      if (a.role != 'appraiser' && a.role != 'warehouse') return false;
      if (filter == 'all') return true;
      return a.role == filter;
    }).toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          const Text('QUẢN TRỊ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted, letterSpacing: 0.5)),
          const Text('Tài khoản vận hành', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          const SizedBox(height: 4),
          const Text('Quản lý quyền truy cập của đội Thẩm định và Kho vận.', style: TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã gửi lời mời (mô phỏng) — chưa kết nối email thật.')),
                );
              },
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
              label: const Text('Mời tài khoản'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilterChipButton(label: 'Tất cả', selected: filter == 'all', onTap: () => setState(() => filter = 'all')),
            FilterChipButton(label: 'Thẩm định', selected: filter == 'appraiser', onTap: () => setState(() => filter = 'appraiser')),
            FilterChipButton(label: 'Kho vận', selected: filter == 'warehouse', onTap: () => setState(() => filter = 'warehouse')),
          ]),
          const SizedBox(height: 12),
          if (rows.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('Không có tài khoản nào phù hợp bộ lọc.', style: TextStyle(color: AppColors.muted)))),
          ...rows.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AccountCard(a: a, onToggle: () => store.toggleAccount(a.id)),
              )),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final UserAccount a;
  final VoidCallback onToggle;
  const _AccountCard({required this.a, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final active = a.status == 'active';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.neutralBg,
                child: Text(a.name.isNotEmpty ? a.name[0] : '?', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.neutralFg)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(a.email, style: const TextStyle(fontSize: 12, color: AppColors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: active ? AppColors.successBg : AppColors.dangerBg, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  active ? 'Đang hoạt động' : 'Đã tạm khoá',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: active ? AppColors.successFg : AppColors.dangerFg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Vai trò', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                    const SizedBox(height: 2),
                    Text(a.roleLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tải công việc', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                    const SizedBox(height: 2),
                    Text(active ? '${a.load} việc / tuần' : '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onToggle,
              style: OutlinedButton.styleFrom(
                foregroundColor: active ? AppColors.dangerStrong : AppColors.successStrong,
                side: BorderSide(color: active ? AppColors.dangerStrong : AppColors.successStrong),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(active ? 'Tạm khoá' : 'Kích hoạt lại', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
