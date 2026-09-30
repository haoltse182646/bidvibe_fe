import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/order_status.dart';
import '../bidder/bidder_done.dart';
import '../bidder/bidder_payment.dart';
import '../customer/customer_chatbot.dart';

/// Hồ sơ & bảo mật (Manage Profile & Security) cho khách hàng (Bidder và
/// Seller): sửa thông tin, đổi mật khẩu, xác thực 2 lớp, thiết bị đăng
/// nhập, đăng xuất. Bidder còn thấy "Đơn hàng của tôi"; cả hai có lối vào
/// chatbot hỗ trợ.
class AuthProfileScreen extends StatefulWidget {
  const AuthProfileScreen({super.key});

  @override
  State<AuthProfileScreen> createState() => _AuthProfileScreenState();
}

class _AuthProfileScreenState extends State<AuthProfileScreen> {
  bool editing = false;
  bool pwOpen = false;
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final addrCtrl = TextEditingController();
  final curPwCtrl = TextEditingController();
  final newPwCtrl = TextEditingController();
  String? pwError;
  String? pwOk;

  final List<(String, String)> sessions = [
    ('Thiết bị này', 'Đang hoạt động'),
    ('iPhone 13 · TP.HCM', 'Đăng nhập 2 ngày trước'),
    ('Chrome · macOS', 'Đăng nhập 1 tuần trước'),
  ];

  @override
  void dispose() {
    for (final c in [nameCtrl, phoneCtrl, addrCtrl, curPwCtrl, newPwCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _startEdit() {
    final u = context.read<AppStore>().currentUser!;
    nameCtrl.text = u.name;
    phoneCtrl.text = u.phone;
    addrCtrl.text = u.address;
    setState(() => editing = true);
  }

  void _save() {
    if (nameCtrl.text.trim().isEmpty) return;
    context.read<AppStore>().updateProfile(name: nameCtrl.text, phone: phoneCtrl.text, address: addrCtrl.text);
    setState(() => editing = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu thông tin hồ sơ.')));
  }

  void _changePassword() {
    final err = context.read<AppStore>().changePassword(curPwCtrl.text, newPwCtrl.text);
    setState(() {
      pwError = err;
      pwOk = err == null ? 'Đã đổi mật khẩu thành công.' : null;
      if (err == null) {
        curPwCtrl.clear();
        newPwCtrl.clear();
        pwOpen = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final u = store.currentUser;
    if (u == null) return const SizedBox.shrink();
    final isBidder = u.role == 'bidder';
    final orders = isBidder ? store.myOrders : const [];

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          const Text('Hồ sơ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          const SizedBox(height: 12),
          _card(
            child: Row(
              children: [
                CircleAvatar(radius: 26, backgroundColor: AppColors.accent, child: Text(u.name.split(' ').last[0], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white))),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(u.email, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                      const SizedBox(height: 6),
                      StatusPill(label: u.shop == null ? u.roleLabel : '${u.roleLabel} · ${u.shop}', tone: StatusTone.progress),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(child: Text('Thông tin cá nhân', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
              if (!editing) TextButton.icon(onPressed: _startEdit, icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Sửa')),
            ],
          ),
          const SizedBox(height: 4),
          _card(
            child: editing
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FieldLabel('Họ và tên'),
                      TextField(controller: nameCtrl, decoration: appInputDecoration(null)),
                      const SizedBox(height: 12),
                      const FieldLabel('Số điện thoại'),
                      TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: appInputDecoration(null)),
                      const SizedBox(height: 12),
                      const FieldLabel('Địa chỉ nhận hàng'),
                      TextField(controller: addrCtrl, maxLines: 2, decoration: appInputDecoration(null)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: OutlinedButton(onPressed: () => setState(() => editing = false), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Huỷ'))),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _save,
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              child: const Text('Lưu', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Column(children: [_kv('Họ và tên', u.name), _kv('Số điện thoại', u.phone.isEmpty ? 'Chưa cập nhật' : u.phone), _kv('Địa chỉ', u.address.isEmpty ? 'Chưa cập nhật' : u.address)]),
          ),

          if (isBidder) ...[
            const SizedBox(height: 22),
            const Text('Đơn hàng của tôi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (orders.isEmpty)
              _card(child: const Text('Bạn chưa thắng phiên nào.', style: TextStyle(fontSize: 13, color: AppColors.muted)))
            else
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                child: Column(
                  children: orders.asMap().entries.map((e) {
                    final a = e.value;
                    final (label, tone) = orderStatus(a);
                    return InkWell(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => a.paid ? BidderDoneScreen(auctionId: a.id) : BidderPaymentScreen(auctionId: a.id))),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(border: e.key == 0 ? null : const Border(top: BorderSide(color: AppColors.border))),
                        child: Row(
                          children: [
                            CategoryThumb(cat: a.cat, size: 44, radius: 10),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Row(children: [StatusPill(label: label, tone: tone), const SizedBox(width: 8), Text(store.money(a.price), style: const TextStyle(fontSize: 12, color: AppColors.muted))]),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.muted),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],

          const SizedBox(height: 22),
          const Text('Hỗ trợ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _card(
            padding: EdgeInsets.zero,
            child: ListTile(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CustomerChatbotScreen())),
              leading: const CircleAvatar(backgroundColor: AppColors.progressBg, child: Icon(Icons.support_agent, color: AppColors.accent)),
              title: const Text('Trợ lý hỗ trợ BidVibe', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text('Hỏi về cọc, thanh toán, giao hàng, tranh chấp…', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),

          const SizedBox(height: 22),
          const Text('Bảo mật', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _card(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  value: u.twoFactor,
                  onChanged: store.setTwoFactor,
                  activeThumbColor: AppColors.accent,
                  title: const Text('Xác thực 2 lớp', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Yêu cầu mã OTP qua email mỗi lần đăng nhập.', style: TextStyle(fontSize: 12)),
                ),
                const Divider(height: 1),
                ListTile(
                  onTap: () => setState(() {
                    pwOpen = !pwOpen;
                    pwError = null;
                    pwOk = null;
                  }),
                  title: const Text('Đổi mật khẩu', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: pwOk != null ? Text(pwOk!, style: const TextStyle(fontSize: 12, color: AppColors.successFg)) : null,
                  trailing: Icon(pwOpen ? Icons.expand_less : Icons.expand_more),
                ),
                if (pwOpen)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(controller: curPwCtrl, obscureText: true, decoration: appInputDecoration('Mật khẩu hiện tại')),
                        const SizedBox(height: 10),
                        TextField(controller: newPwCtrl, obscureText: true, decoration: appInputDecoration('Mật khẩu mới (tối thiểu 6 ký tự)')),
                        if (pwError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(pwError!, style: const TextStyle(fontSize: 12, color: AppColors.dangerStrong))),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _changePassword,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('Cập nhật mật khẩu', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 22),
          const Text('Thiết bị đã đăng nhập', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(
              children: sessions.asMap().entries.map((e) {
                final (name, sub) = e.value;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(border: e.key == 0 ? null : const Border(top: BorderSide(color: AppColors.border))),
                  child: Row(
                    children: [
                      Icon(e.key == 0 ? Icons.smartphone : Icons.devices_other_outlined, color: AppColors.neutralFg),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                          ],
                        ),
                      ),
                      if (e.key != 0) TextButton(onPressed: () => setState(() => sessions.removeAt(e.key)), child: const Text('Đăng xuất')),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: store.logout,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.dangerStrong,
              side: const BorderSide(color: AppColors.dangerStrong, width: 1.5),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.all(14)}) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        // Material trong suốt để ListTile/Switch bên trong vẫn hiện hiệu ứng chạm.
        child: Material(type: MaterialType.transparency, child: child),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Text(k, style: const TextStyle(fontSize: 13, color: AppColors.muted))),
            Expanded(child: Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          ],
        ),
      );
}
