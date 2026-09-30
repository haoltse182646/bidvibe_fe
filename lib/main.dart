import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'store.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'screens/auth/auth_login.dart';
import 'screens/bidder/bidder_shell.dart';
import 'screens/seller/seller_shell.dart';
import 'screens/appraiser/appraiser_shell.dart';
import 'screens/warehouse/warehouse_shell.dart';
import 'screens/admin/admin_shell.dart';

void main() {
  runApp(const BidVibeApp());
}

class BidVibeApp extends StatelessWidget {
  const BidVibeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppStore(),
      child: MaterialApp(
        title: 'BidVibe',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const RootShell(),
      ),
    );
  }
}

/// Vỏ ngoài cùng: chưa đăng nhập thì hiện màn Đăng nhập; đã đăng nhập thì
/// vai trò của tài khoản quyết định màn hình chính. Thanh DEMO phía trên
/// chỉ phục vụ trình diễn: chuyển nhanh sang tài khoản mẫu của vai trò khác
/// hoặc đăng xuất (trong sản phẩm thật sẽ không có thanh này).
class RootShell extends StatelessWidget {
  const RootShell({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final user = store.currentUser;
    if (user == null) return const AuthLoginScreen();

    return Scaffold(
      appBar: RoleSwitcherBar(current: user.role, onSelect: store.switchDemoRole, onLogout: store.logout),
      body: SafeArea(top: false, child: _body(user.role)),
    );
  }

  Widget _body(String role) {
    switch (role) {
      case 'seller':
        return const SellerShell();
      case 'appraiser':
        return const AppraiserShell();
      case 'warehouse':
        return const WarehouseShell();
      case 'admin':
        return const AdminShell();
      case 'bidder':
      default:
        return const BidderShell();
    }
  }
}
