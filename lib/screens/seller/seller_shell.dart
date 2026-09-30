import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../store.dart';
import '../../theme.dart';
import '../auth/auth_profile.dart';
import 'seller_list.dart';
import 'seller_create.dart';
import 'seller_shipping.dart';

/// Khung điều hướng Seller: 4 tab (Phiên của tôi, Tạo mới, Gửi kho, Hồ sơ).
class SellerShell extends StatefulWidget {
  const SellerShell({super.key});

  @override
  State<SellerShell> createState() => _SellerShellState();
}

class _SellerShellState extends State<SellerShell> {
  int tab = 0;

  void goTab(int i) => setState(() => tab = i);

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    // Số đơn đang chờ người bán gửi hàng đến kho — hiện trên tab Gửi kho.
    final toShip = store.myShipments.where((s) => s.at == 1).length;

    return Scaffold(
      body: IndexedStack(
        index: tab,
        children: [
          const SellerListScreen(),
          SellerCreateScreen(onDone: () => goTab(0)),
          const SellerShippingScreen(),
          const AuthProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: goTab,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.progressBg,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'Phiên của tôi'),
          const NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'Tạo mới'),
          NavigationDestination(
            icon: Badge(label: Text('$toShip'), isLabelVisible: toShip > 0, child: const Icon(Icons.local_shipping_outlined)),
            selectedIcon: Badge(label: Text('$toShip'), isLabelVisible: toShip > 0, child: const Icon(Icons.local_shipping)),
            label: 'Gửi kho',
          ),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Hồ sơ'),
        ],
      ),
    );
  }
}
