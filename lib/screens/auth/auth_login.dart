import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../store.dart';
import '../../theme.dart';

class AuthLoginScreen extends StatelessWidget {
  const AuthLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const roles = [
      (
        role: 'bidder',
        title: 'Người mua',
        detail: 'Đấu giá và quản lý đơn hàng',
        icon: Icons.gavel_outlined
      ),
      (
        role: 'seller',
        title: 'Người bán',
        detail: 'Quản lý gian hàng và ký gửi',
        icon: Icons.storefront_outlined
      ),
      (
        role: 'appraiser',
        title: 'Thẩm định',
        detail: 'Duyệt và đánh giá sản phẩm',
        icon: Icons.fact_check_outlined
      ),
      (
        role: 'warehouse',
        title: 'Kho vận',
        detail: 'Tiếp nhận và xử lý giao hàng',
        icon: Icons.inventory_2_outlined
      ),
      (
        role: 'admin',
        title: 'Admin',
        detail: 'Quản trị và theo dõi hệ thống',
        icon: Icons.admin_panel_settings_outlined
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
              shrinkWrap: true,
              children: [
                const Text('BidVibe',
                    style:
                        TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Chọn vai trò để mở prototype',
                    style: TextStyle(fontSize: 15, color: AppColors.muted)),
                const SizedBox(height: 24),
                for (final option in roles) ...[
                  Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () =>
                          context.read<AppStore>().switchDemoRole(option.role),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 15),
                        child: Row(
                          children: [
                            Icon(option.icon,
                                color: AppColors.accent, size: 24),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(option.title,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 3),
                                  Text(option.detail,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.muted)),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded,
                                size: 16, color: AppColors.muted),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
