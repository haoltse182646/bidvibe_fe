import 'package:flutter/material.dart';
import '../../theme.dart';
import 'appraiser_queue.dart';
import 'appraiser_history.dart';

class AppraiserShell extends StatefulWidget {
  const AppraiserShell({super.key});

  @override
  State<AppraiserShell> createState() => _AppraiserShellState();
}

class _AppraiserShellState extends State<AppraiserShell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: tab, children: const [AppraiserQueueScreen(), AppraiserHistoryScreen()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.progressBg,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: 'Hàng chờ'),
          NavigationDestination(icon: Icon(Icons.history), selectedIcon: Icon(Icons.history), label: 'Đã xử lý'),
        ],
      ),
    );
  }
}
