import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Đăng ký tài khoản khách hàng (Register Account). Khách hàng chọn là
/// Người mua hoặc Người bán; tài khoản Thẩm định/Kho vận/Admin do Admin cấp.
class AuthRegisterScreen extends StatefulWidget {
  const AuthRegisterScreen({super.key});

  @override
  State<AuthRegisterScreen> createState() => _AuthRegisterScreenState();
}

class _AuthRegisterScreenState extends State<AuthRegisterScreen> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final shopCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final pass2Ctrl = TextEditingController();
  String role = 'bidder';
  bool agree = false;
  bool hidePass = true;
  bool submitted = false;
  String? serverError;

  @override
  void dispose() {
    for (final c in [nameCtrl, emailCtrl, phoneCtrl, shopCtrl, passCtrl, pass2Ctrl]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _nameErr => submitted && nameCtrl.text.trim().length < 2 ? 'Vui lòng nhập họ tên' : null;
  String? get _emailErr => submitted && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(emailCtrl.text.trim()) ? 'Email chưa hợp lệ' : null;
  String? get _phoneErr => submitted && !RegExp(r'^0[0-9 ]{8,11}$').hasMatch(phoneCtrl.text.trim()) ? 'Số điện thoại chưa hợp lệ' : null;
  String? get _passErr => submitted && passCtrl.text.length < 6 ? 'Mật khẩu tối thiểu 6 ký tự' : null;
  String? get _pass2Err => submitted && pass2Ctrl.text != passCtrl.text ? 'Mật khẩu nhập lại chưa khớp' : null;

  void _submit() {
    setState(() {
      submitted = true;
      serverError = null;
    });
    if ([_nameErr, _emailErr, _phoneErr, _passErr, _pass2Err].any((e) => e != null) || !agree) return;
    final err = context.read<AppStore>().register(
          name: nameCtrl.text,
          email: emailCtrl.text,
          phone: phoneCtrl.text,
          password: passCtrl.text,
          role: role,
          shop: shopCtrl.text,
        );
    if (err != null) {
      setState(() => serverError = err);
      return;
    }
    // Đã tự đăng nhập: RootShell chuyển sang màn hình chính, đóng form đăng ký.
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Đăng ký tài khoản', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          const FieldLabel('Bạn muốn tham gia với vai trò'),
          Row(
            children: [
              Expanded(child: _RoleCard(icon: Icons.gavel_outlined, title: 'Người mua', sub: 'Đặt giá, thanh toán', selected: role == 'bidder', onTap: () => setState(() => role = 'bidder'))),
              const SizedBox(width: 10),
              Expanded(child: _RoleCard(icon: Icons.storefront_outlined, title: 'Người bán', sub: 'Ký gửi sản phẩm', selected: role == 'seller', onTap: () => setState(() => role = 'seller'))),
            ],
          ),
          const SizedBox(height: 16),
          const FieldLabel('Họ và tên'),
          TextField(controller: nameCtrl, onChanged: (_) => setState(() {}), decoration: appInputDecoration('Nguyễn Văn A', errorText: _nameErr)),
          if (role == 'seller') ...[
            const SizedBox(height: 14),
            const FieldLabel('Tên gian hàng'),
            TextField(controller: shopCtrl, decoration: appInputDecoration('Ví dụ: Sài Gòn Vintage (bỏ trống để dùng họ tên)')),
          ],
          const SizedBox(height: 14),
          const FieldLabel('Email'),
          TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, onChanged: (_) => setState(() {}), decoration: appInputDecoration('ten@email.com', errorText: _emailErr)),
          const SizedBox(height: 14),
          const FieldLabel('Số điện thoại'),
          TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, onChanged: (_) => setState(() {}), decoration: appInputDecoration('09xx xxx xxx', errorText: _phoneErr)),
          const SizedBox(height: 14),
          const FieldLabel('Mật khẩu'),
          TextField(
            controller: passCtrl,
            obscureText: hidePass,
            onChanged: (_) => setState(() {}),
            decoration: appInputDecoration(
              'Tối thiểu 6 ký tự',
              errorText: _passErr,
              suffixIcon: IconButton(onPressed: () => setState(() => hidePass = !hidePass), icon: Icon(hidePass ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20)),
            ),
          ),
          const SizedBox(height: 14),
          const FieldLabel('Nhập lại mật khẩu'),
          TextField(controller: pass2Ctrl, obscureText: hidePass, onChanged: (_) => setState(() {}), decoration: appInputDecoration('Nhập lại mật khẩu', errorText: _pass2Err)),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => setState(() => agree = !agree),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(value: agree, onChanged: (v) => setState(() => agree = v ?? false), activeColor: AppColors.accent),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('Tôi đồng ý với Điều khoản sử dụng và Chính sách bảo mật của BidVibe.', style: TextStyle(fontSize: 13, height: 1.4)),
                  ),
                ),
              ],
            ),
          ),
          if (submitted && !agree) const Padding(padding: EdgeInsets.only(left: 12, bottom: 4), child: Text('Bạn cần đồng ý điều khoản để tiếp tục.', style: TextStyle(fontSize: 12, color: AppColors.dangerStrong))),
          if (serverError != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(12)),
              child: Text(serverError!, style: const TextStyle(fontSize: 13, color: AppColors.dangerFg)),
            ),
          const SizedBox(height: 16),
          BigActionButton(label: 'Tạo tài khoản', onPressed: _submit),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final bool selected;
  final VoidCallback onTap;
  const _RoleCard({required this.icon, required this.title, required this.sub, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF1F3F8) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: selected ? AppColors.accent : AppColors.border, width: selected ? 1.5 : 1)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: selected ? AppColors.accent : AppColors.muted),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
