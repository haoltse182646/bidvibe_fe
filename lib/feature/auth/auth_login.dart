import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'auth_register.dart';

/// Đăng nhập (Log In & Authenticate). Sau khi đăng nhập, vai trò của tài
/// khoản quyết định màn hình chính hiển thị (xem RootShell trong main.dart).
/// Danh sách "Tài khoản demo" bên dưới cho phép vào nhanh mà không cần gõ.
class AuthLoginScreen extends StatefulWidget {
  const AuthLoginScreen({super.key});

  @override
  State<AuthLoginScreen> createState() => _AuthLoginScreenState();
}

class _AuthLoginScreenState extends State<AuthLoginScreen> {
  final emailCtrl = TextEditingController(text: 'minhanh@gmail.com');
  final passCtrl = TextEditingController(text: '123456');
  bool hidePass = true;
  String? error;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final store = context.read<AppStore>();
    var err = store.login(emailCtrl.text, passCtrl.text);
    if (err == 'OTP_REQUIRED') {
      final otp = await _askOtp();
      if (!mounted) return;
      if (otp == null) {
        setState(() => error = null);
        return;
      }
      err = store.login(emailCtrl.text, passCtrl.text, otp: otp);
    }
    if (!mounted) return;
    setState(() => error = err);
  }

  Future<String?> _askOtp() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác thực 2 lớp', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nhập mã OTP gồm 6 chữ số đã gửi qua email của bạn.', style: TextStyle(fontSize: 13, color: AppColors.muted)),
            const SizedBox(height: 4),
            const Text('Mã demo: 123456', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 12),
            TextField(controller: ctrl, autofocus: true, keyboardType: TextInputType.number, maxLength: 6, decoration: appInputDecoration('Mã OTP')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Xác nhận')),
        ],
      ),
    );
  }

  void _quick(UserAccount u) {
    emailCtrl.text = u.email;
    passCtrl.text = u.password;
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    const roleOrder = ['bidder', 'seller', 'appraiser', 'warehouse', 'admin'];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
                  child: const Text('B', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                ),
                const SizedBox(width: 10),
                const Text('BidVibe', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
              ],
            ),
            const SizedBox(height: 28),
            const Text('Đăng nhập', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
            const SizedBox(height: 4),
            const Text('Đấu giá đồ cũ và sưu tầm đã được thẩm định.', style: TextStyle(fontSize: 14, color: AppColors.muted)),
            const SizedBox(height: 22),
            const FieldLabel('Email'),
            TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: appInputDecoration('ten@email.com')),
            const SizedBox(height: 14),
            const FieldLabel('Mật khẩu'),
            TextField(
              controller: passCtrl,
              obscureText: hidePass,
              onSubmitted: (_) => _submit(),
              decoration: appInputDecoration(
                'Nhập mật khẩu',
                suffixIcon: IconButton(onPressed: () => setState(() => hidePass = !hidePass), icon: Icon(hidePass ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20)),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.error_outline, size: 18, color: AppColors.dangerFg),
                  const SizedBox(width: 8),
                  Expanded(child: Text(error!, style: const TextStyle(fontSize: 13, color: AppColors.dangerFg))),
                ]),
              ),
            ],
            const SizedBox(height: 18),
            BigActionButton(label: 'Đăng nhập', onPressed: _submit),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Chưa có tài khoản?', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthRegisterScreen())),
                  child: const Text('Đăng ký', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.accent)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 12),
            const Text('TÀI KHOẢN DEMO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted, letterSpacing: 0.5)),
            const SizedBox(height: 2),
            const Text('Chạm để đăng nhập ngay · mật khẩu chung: 123456', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 10),
            for (final role in roleOrder) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 6, top: 6),
                child: Text(store.users.firstWhere((u) => u.role == role).roleLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: store.users.where((u) => u.role == role).map((u) {
                  final off = u.status != 'active';
                  return ActionChip(
                    onPressed: () => _quick(u),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.border),
                    avatar: CircleAvatar(
                      backgroundColor: off ? AppColors.dangerBg : AppColors.neutralBg,
                      child: Text(u.name.split(' ').last[0], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: off ? AppColors.dangerFg : AppColors.neutralFg)),
                    ),
                    label: Text(off ? '${u.name} (đã khoá)' : (u.shop ?? u.name), style: const TextStyle(fontSize: 12)),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
