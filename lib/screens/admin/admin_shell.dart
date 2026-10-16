import 'package:flutter/material.dart';
import '../../theme.dart';
import 'admin_ops_overview.dart';
import 'admin_ops_cases.dart';
import 'admin_ops_accounts.dart';

/// Khung điều hướng Admin: 5 tab dưới cùng (Tổng quan, Cờ, Tranh chấp,
/// Báo cáo, Tài khoản) — cùng kiểu điều hướng bottom-nav như 4 vai trò
/// còn lại, thay cho sidebar desktop trước đây.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: tab,
        children: const [
          AdminOpsDashboardScreen(),
          AdminOpsFlagsScreen(),
          AdminOpsDisputesScreen(),
          AdminOpsReportScreen(),
          AdminOpsAccountsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.progressBg,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: 'Tổng quan'),
          const NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: 'Cờ'),
          const NavigationDestination(icon: Icon(Icons.gavel_outlined), selectedIcon: Icon(Icons.gavel), label: 'Tranh chấp'),
          const NavigationDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description), label: 'Báo cáo'),
          const NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Tài khoản'),
        ],
      ),
    );
  }
}
