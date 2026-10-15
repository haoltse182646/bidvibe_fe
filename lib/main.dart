import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'store.dart';
import 'theme.dart';
import 'core/remote_app_store.dart';
import 'screens/auth/auth_login.dart';
import 'screens/bidder/bidder_shell.dart';
import 'screens/seller/seller_shell.dart';
import 'screens/appraiser/appraiser_shell.dart';
import 'screens/warehouse/warehouse_shell.dart';
import 'screens/admin/admin_shell.dart';
import 'core/api_client.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ApiClient.loadConfig();

  runApp(const BidVibeApp());
}

class BidVibeApp extends StatelessWidget {
  const BidVibeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppStore>(
      create: (_) => RemoteAppStore(),
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
/// chỉ phục vụ trình diễn: hiện vai trò đang xem và nút đăng xuất để quay về
/// màn chọn vai trò (trong sản phẩm thật sẽ không có thanh này).
class RootShell extends StatelessWidget {
  const RootShell({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final auth = store as RemoteAppStore;
    if (auth.restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (auth.restoreError != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(auth.restoreError!),
              ),
              FilledButton(
                onPressed: auth.restoreSession,
                child: const Text('Thử lại'),
              ),
              TextButton(
                onPressed: () {
                  auth.restoreError = null;
                  auth.logout();
                },
                child: const Text('Về đăng nhập'),
              ),
            ],
          ),
        ),
      );
    }
    final user = store.currentUser;
    if (user == null) return const AuthLoginScreen();

    return Scaffold(
      appBar: AppBar(
        title: Text(user.roleLabel),
        actions: [
          IconButton(
            onPressed: store.logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
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
