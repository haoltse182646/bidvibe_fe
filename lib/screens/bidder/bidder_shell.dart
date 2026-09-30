import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'bidder_home.dart';
import 'bidder_wallet.dart';
import 'bidder_notifications.dart';
import 'bidder_detail.dart';
import 'bidder_payment.dart';
import 'bidder_done.dart';
import '../auth/auth_profile.dart';

/// Khung điều hướng của vai trò Bidder: 4 tab dưới cùng (Khám phá, Ví,
/// Thông báo, Hồ sơ) cộng với toast nổi khi bị vượt giá / thắng phiên /
/// đơn hàng có tiến triển.
class BidderShell extends StatefulWidget {
  const BidderShell({super.key});

  @override
  State<BidderShell> createState() => _BidderShellState();
}

class _BidderShellState extends State<BidderShell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final unread = store.unreadNotifications;

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: tab,
            children: const [
              BidderHomeScreen(),
              BidderWalletScreen(),
              BidderNotificationsScreen(),
              AuthProfileScreen(),
            ],
          ),
          if (store.toastId != null)
            Positioned(
              left: 12,
              right: 12,
              top: 8,
              child: SafeArea(
                bottom: false,
                child: TopToast(
                  title: store.toastTitle,
                  body: store.toastBody,
                  danger: store.toastIsDanger,
                  success: store.toastIsSuccess,
                  onTap: () {
                    store.dismissToast();
                    if (store.toastTargetIsWallet == true) {
                      setState(() => tab = 1);
                    } else if (store.toastTargetIsOrder == true && store.toastTargetAuction != null) {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => BidderDoneScreen(auctionId: store.toastTargetAuction!)));
                    } else if (store.toastTargetIsPay == true && store.toastTargetAuction != null) {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => BidderPaymentScreen(auctionId: store.toastTargetAuction!)));
                    } else if (store.toastTargetAuction != null) {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => BidderDetailScreen(auctionId: store.toastTargetAuction!)));
                    }
                  },
                  onClose: store.dismissToast,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) {
          setState(() => tab = i);
          if (i == 2) store.markNotificationsRead();
        },
        backgroundColor: Colors.white,
        indicatorColor: AppColors.progressBg,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: 'Khám phá'),
          const NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Ví'),
          NavigationDestination(
            icon: Badge(label: Text('$unread'), isLabelVisible: unread > 0, child: const Icon(Icons.notifications_outlined)),
            selectedIcon: Badge(label: Text('$unread'), isLabelVisible: unread > 0, child: const Icon(Icons.notifications)),
            label: 'Thông báo',
          ),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Hồ sơ'),
        ],
      ),
    );
  }
}
