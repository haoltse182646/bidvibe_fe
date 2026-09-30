import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../store.dart';
import '../../theme.dart';
import 'admin_dashboard.dart';
import 'admin_flags.dart';
import 'admin_disputes.dart';
import 'admin_report.dart';
import 'admin_accounts.dart';

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
    final store = context.watch<AppStore>();

    return Scaffold(
      body: IndexedStack(
        index: tab,
        children: const [
          AdminDashboardScreen(),
          AdminFlagsScreen(),
          AdminDisputesScreen(),
          AdminReportScreen(),
          AdminAccountsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.progressBg,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: 'Tổng quan'),
          NavigationDestination(
            icon: Badge(label: Text('${store.openFlagsCount}'), isLabelVisible: store.openFlagsCount > 0, child: const Icon(Icons.flag_outlined)),
            selectedIcon: Badge(label: Text('${store.openFlagsCount}'), isLabelVisible: store.openFlagsCount > 0, child: const Icon(Icons.flag)),
            label: 'Cờ',
          ),
          NavigationDestination(
            icon: Badge(label: Text('${store.openDisputesCount}'), isLabelVisible: store.openDisputesCount > 0, child: const Icon(Icons.gavel_outlined)),
            selectedIcon: Badge(label: Text('${store.openDisputesCount}'), isLabelVisible: store.openDisputesCount > 0, child: const Icon(Icons.gavel)),
            label: 'Tranh chấp',
          ),
          const NavigationDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description), label: 'Báo cáo'),
          const NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Tài khoản'),
        ],
      ),
    );
  }
}
