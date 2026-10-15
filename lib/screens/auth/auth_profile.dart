import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/remote_app_store.dart';
import '../../features/profile/profile_repository.dart';
import '../../features/addresses/address_repository.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../customer/customer_chatbot.dart';
import '../addresses/address_book_screen.dart';

class AuthProfileScreen extends StatefulWidget {
  final ProfileRepository? repository;
  final Future<XFile?> Function()? pickImage;
  final VoidCallback? onAddresses, onOrders, onSupport;
  final Future<void> Function(String orderId)? onOpenOrder;
  const AuthProfileScreen({
    super.key,
    this.repository,
    this.pickImage,
    this.onAddresses,
    this.onOrders,
    this.onSupport,
    this.onOpenOrder,
  });
  @override
  State<AuthProfileScreen> createState() => _AuthProfileScreenState();
}

class _AuthProfileScreenState extends State<AuthProfileScreen> {
  final _form = GlobalKey<FormState>(), _passwordForm = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _phone = TextEditingController(),
      _shop = TextEditingController();
  final _current = TextEditingController(),
      _next = TextEditingController(),
      _confirm = TextEditingController();
  late final RemoteAppStore _store;
  late final ProfileRepository _repo;
  late final String _accountId;
  late final String? _token;
  ProfileSnapshot? _profile;
  List<Map<String, dynamic>> _addresses = [], _orders = [];
  String? _addressError, _ordersError;
  String? _draftAvatar, _error, _passwordError;
  bool _loading = true, _saving = false, _uploading = false, _changing = false;
  bool _editing = false,
      _passwordOpen = false,
      _uncertainProfile = false,
      _uncertainPassword = false;
  bool get _working => _loading || _saving || _uploading || _changing;
  bool get _active =>
      mounted &&
      _store.currentUser?.id == _accountId &&
      _repo.api.token == _token;

  @override
  void initState() {
    super.initState();
    _store = context.read<AppStore>() as RemoteAppStore;
    _repo = widget.repository ?? ProfileRepository(_store.api);
    _accountId = _store.currentUser!.id;
    _token = _repo.api.token;
    unawaited(_load());
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_recoverImage()),
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _phone,
      _shop,
      _current,
      _next,
      _confirm,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _accept(ProfileSnapshot profile) {
    if (profile.id != _accountId) {
      throw const ApiException(
        'INVALID_RESPONSE',
        'Hồ sơ không khớp tài khoản đang đăng nhập.',
      );
    }
    _store.applyProfile(profile.data);
    _profile = profile;
  }

  bool _auth(Object error) {
    if (error is ApiException &&
        ['UNAUTHORIZED', 'ACCOUNT_SUSPENDED'].contains(error.code)) {
      _store.logout();
      _store.sessionError = error.message;
      Navigator.of(context).popUntil((route) => route.isFirst);
      return true;
    }
    return false;
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : 'Không thực hiện được yêu cầu. Vui lòng thử lại.';
  bool _rejected(Object error) =>
      error is ApiException &&
      [
        'VALIDATION_ERROR',
        'WRONG_PASSWORD',
        'FORBIDDEN',
        'NOT_FOUND',
      ].contains(error.code);
  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _load() async {
    if (_saving || _uploading || _changing) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _repo.fetch();
      if (!_active) {
        return;
      }
      _accept(profile);
      setState(() {
        _editing = false;
        _uncertainProfile = false;
      });
      if (profile.role == 'bidder') {
        await _loadRelated();
      }
    } catch (e) {
      if (_active && !_auth(e)) {
        setState(() => _error = _message(e));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadRelated() async {
    await Future.wait([
      (() async {
        try {
          final addresses = await _repo.addresses();
          if (_active) {
            setState(() {
              _addresses = addresses;
              _addressError = null;
            });
          }
        } catch (e) {
          if (_active && !_auth(e)) {
            setState(() => _addressError = 'Chưa tải được địa chỉ.');
          }
        }
      })(),
      (() async {
        try {
          final orders = await _repo.orders();
          if (_active) {
            setState(() {
              _orders = orders;
              _ordersError = null;
            });
          }
        } catch (e) {
          if (_active && !_auth(e)) {
            setState(() => _ordersError = 'Chưa tải được đơn hàng.');
          }
        }
      })(),
    ]);
  }

  Future<void> _support() async {
    if (_working) {
      return;
    }
    if (widget.onSupport != null) {
      widget.onSupport!();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CustomerChatbotScreen()),
    );
  }

  void _edit() {
    if (_working ||
        _profile == null ||
        _uncertainProfile ||
        _uncertainPassword ||
        _passwordOpen) {
      return;
    }
    _name.text = _profile!.fullName;
    _phone.text = _profile!.phone ?? '';
    _shop.text = _profile!.storeName ?? '';
    _draftAvatar = _profile!.avatarUrl;
    setState(() {
      _editing = true;
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_working || _uncertainProfile || !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    final profile = _profile!;
    final changes = <String, dynamic>{};
    final phone = _phone.text.trim();
    if (_name.text.trim() != profile.fullName) {
      changes['fullName'] = _name.text.trim();
    }
    if (phone != (profile.phone ?? '')) {
      changes['phone'] = phone.isEmpty ? null : phone;
    }
    if (_draftAvatar != profile.avatarUrl) {
      changes['avatarUrl'] = _draftAvatar;
    }
    if (profile.role == 'seller' && _shop.text.trim() != profile.storeName) {
      changes['shopName'] = _shop.text.trim();
    }
    if (changes.isEmpty) {
      _notice('Chưa có thay đổi.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await _repo.update(changes);
      if (!_active) {
        return;
      }
      _accept(updated);
      setState(() => _editing = false);
      _notice('Đã lưu thông tin hồ sơ.');
    } catch (e) {
      if (_active && !_auth(e)) {
        setState(() {
          _uncertainProfile = !_rejected(e);
          _error = _uncertainProfile
              ? 'Chưa xác nhận được kết quả lưu. Hãy tải lại hồ sơ để kiểm tra trước khi chỉnh sửa tiếp.'
              : _message(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _chooseAvatar() async {
    if (_working || !_editing || _uncertainProfile) {
      return;
    }
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final file =
          await (widget.pickImage?.call() ??
              ImagePicker().pickImage(
                source: ImageSource.gallery,
                requestFullMetadata: false,
              ));
      if (!_active || file == null) {
        return;
      }
      await _upload(file);
    } on PlatformException {
      if (_active) {
        setState(
          () => _error =
              'Không mở được thư viện ảnh. Hãy kiểm tra quyền truy cập ảnh.',
        );
      }
    } catch (e) {
      if (_active && !_auth(e)) {
        setState(() => _error = _message(e));
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  Future<void> _upload(XFile file) async {
    if (await file.length() > 5 * 1024 * 1024) {
      throw const ApiException('FILE_TOO_LARGE', 'Mỗi ảnh tối đa 5 MB.');
    }
    final bytes = await file.readAsBytes();
    if (!_active) {
      return;
    }
    final url = await _repo.uploadAvatar(bytes, file.name);
    if (_active) {
      setState(() => _draftAvatar = url);
    }
  }

  Future<void> _recoverImage() async {
    if (widget.pickImage != null ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      final result = await ImagePicker().retrieveLostData();
      if (!mounted || !_active || result.isEmpty) {
        return;
      }
      if (result.exception != null) {
        setState(
          () => _error = 'Không khôi phục được ảnh đã chọn. Vui lòng chọn lại.',
        );
        return;
      }
      final files = result.files;
      if (files == null || files.isEmpty) {
        return;
      }
      final use = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Ảnh đã chọn trước khi app khởi động lại'),
          content: const Text(
            'Dùng ảnh này cho hồ sơ của tài khoản đang đăng nhập?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Bỏ qua'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Dùng ảnh'),
            ),
          ],
        ),
      );
      if (!_active ||
          use != true ||
          _working ||
          _profile == null ||
          _passwordOpen) {
        return;
      }
      _edit();
      setState(() => _uploading = true);
      try {
        await _upload(files.first);
      } finally {
        if (mounted) {
          setState(() => _uploading = false);
        }
      }
    } on MissingPluginException {
      // No native picker in widget tests; ordinary selection is still available in the app.
    } catch (e) {
      if (_active && !_auth(e)) {
        setState(() => _error = _message(e));
      }
    }
  }

  void _clearPasswords() {
    _current.clear();
    _next.clear();
    _confirm.clear();
  }

  Future<void> _changePassword() async {
    if (_working ||
        _uncertainPassword ||
        !_passwordForm.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _changing = true;
      _passwordError = null;
    });
    try {
      await _repo.changePassword(_current.text, _next.text);
      if (!_active) {
        return;
      }
      _clearPasswords();
      setState(() => _passwordOpen = false);
      _notice(
        'Đổi mật khẩu thành công. Phiên đăng nhập hiện tại vẫn còn hiệu lực.',
      );
    } catch (e) {
      if (_active && !_auth(e)) {
        setState(() {
          _uncertainPassword = !_rejected(e);
          _passwordError = _uncertainPassword
              ? 'Chưa xác nhận được kết quả đổi mật khẩu. Hãy đăng xuất và thử đăng nhập bằng mật khẩu mới; nếu không được, thử mật khẩu cũ.'
              : _message(e);
          if (_uncertainPassword) {
            _clearPasswords();
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _changing = false);
      }
    }
  }

  Widget _field(
    String label,
    TextEditingController controller,
    String key, {
    String? Function(String?)? validator,
    bool obscure = false,
    int? maxLength,
    TextInputType? keyboardType,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        TextFormField(
          key: ValueKey(key),
          controller: controller,
          enabled: !_working && !_uncertainProfile && !_uncertainPassword,
          obscureText: obscure,
          autocorrect: !obscure,
          enableSuggestions: !obscure,
          maxLength: maxLength,
          keyboardType: keyboardType,
          decoration: appInputDecoration(null),
          validator: validator,
        ),
      ],
    ),
  );

  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(14),
  }) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
  Widget _kv(String name, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            name,
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
  Widget _heading(String title) => Text(
    title,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
  );
  Widget _errorBox(String message) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.dangerBg,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      message,
      style: const TextStyle(fontSize: 12, color: AppColors.dangerStrong),
    ),
  );
  Widget _avatar(String? url, String name) {
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').last.characters.first;
    final fallback = CircleAvatar(
      radius: 26,
      backgroundColor: AppColors.accent,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
    if (url == null || !ProfileRepository.validUrl(url)) {
      return fallback;
    }
    return ClipOval(
      child: Image.network(
        url,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }

  Future<void> _openAddresses() async {
    if (_working || !_active) {
      return;
    }
    if (widget.onAddresses != null) {
      widget.onAddresses!();
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AddressBookScreen(
          repository: AddressRepository(_repo.api),
          onSessionExpired: (error) {
            if (_active) {
              _auth(error);
            }
          },
        ),
      ),
    );
    if (_active) {
      await _load();
    }
  }

  String get _defaultAddress {
    if (_addressError != null) {
      return _addressError!;
    }
    if (_addresses.isEmpty) {
      return _loading ? 'Đang tải…' : 'Chưa cập nhật';
    }
    final address = _addresses.firstWhere(
      (item) => item['isDefault'] == true,
      orElse: () => _addresses.first,
    );
    return ['addressLine', 'ward', 'district', 'city']
        .map((key) => (address[key]?.toString() ?? '').trim())
        .where((value) => value.isNotEmpty)
        .join(', ');
  }

  String _money(dynamic value) =>
      '${NumberFormat.decimalPattern('vi_VN').format(value is num ? value : 0)} đ';
  String _paymentLabel(dynamic status) => switch (status) {
    'paid' => 'Đã thanh toán',
    'awaiting_payment' => 'Chờ thanh toán',
    'expired' => 'Quá hạn thanh toán',
    'refunded' => 'Đã hoàn tiền',
    'cancelled' => 'Đã hủy',
    _ => 'Đang cập nhật',
  };
  Future<void> _openOrder(Map<String, dynamic> order) async {
    if (widget.onOpenOrder != null) {
      await widget.onOpenOrder!(order['id'].toString());
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _heading('Đơn hàng #${order['id']}'),
              const SizedBox(height: 12),
              Text(order['title']?.toString() ?? 'Sản phẩm'),
              const SizedBox(height: 12),
              _kv('Trạng thái', _paymentLabel(order['paymentStatus'])),
              _kv('Giá chốt', _money(order['finalPrice'])),
              _kv('Cọc đã trừ', _money(order['depositApplied'])),
              _kv('Cần thanh toán', _money(order['amountToPay'])),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Đóng'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileFields(ProfileSnapshot profile) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(
          'Họ và tên',
          _name,
          'profile.name',
          maxLength: 100,
          validator: ProfileRepository.nameError,
        ),
        _field(
          'Số điện thoại',
          _phone,
          'profile.phone',
          maxLength: 20,
          validator: ProfileRepository.phoneError,
          keyboardType: TextInputType.phone,
        ),
        if (profile.role == 'seller')
          _field(
            'Tên gian hàng',
            _shop,
            'profile.shop',
            maxLength: 100,
            validator: ProfileRepository.nameError,
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _working || _uncertainProfile ? null : _chooseAvatar,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Chọn ảnh đại diện'),
              ),
            ),
            if (_draftAvatar != null)
              IconButton(
                tooltip: 'Xóa ảnh đại diện',
                onPressed: _working || _uncertainProfile
                    ? null
                    : () => setState(() => _draftAvatar = null),
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.dangerStrong,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'JPEG, PNG hoặc WEBP · tối đa 5 MB. Bấm Lưu để cập nhật ảnh.',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        if (_error != null) _errorBox(_error!),
        if (_uncertainProfile)
          TextButton(
            onPressed: _working ? null : _load,
            child: const Text('Kiểm tra hồ sơ đã lưu'),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _working || _uncertainProfile
                    ? null
                    : () => setState(() {
                        _editing = false;
                        _error = null;
                      }),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Huỷ'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: _working || _uncertainProfile ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _saving ? 'Đang lưu…' : 'Lưu',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  Widget _passwordFields() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: Form(
      key: _passwordForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(
            'Mật khẩu hiện tại',
            _current,
            'profile.currentPassword',
            obscure: true,
            validator: (value) => value == null || value.isEmpty
                ? 'Nhập mật khẩu hiện tại.'
                : null,
          ),
          _field(
            'Mật khẩu mới',
            _next,
            'profile.newPassword',
            obscure: true,
            validator: (value) =>
                value == null || value.length < 6 || value.length > 72
                ? 'Mật khẩu mới cần từ 6 đến 72 ký tự.'
                : null,
          ),
          _field(
            'Nhập lại mật khẩu mới',
            _confirm,
            'profile.confirmPassword',
            obscure: true,
            validator: (value) =>
                value != _next.text ? 'Mật khẩu nhập lại chưa khớp.' : null,
          ),
          if (_passwordError != null) _errorBox(_passwordError!),
          FilledButton(
            onPressed: _working || _uncertainPassword ? null : _changePassword,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Cập nhật mật khẩu',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppStore>().currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }
    final profile = _profile;
    final name = profile?.fullName ?? user.name;
    final email = profile?.email ?? user.email;
    final shop = profile?.storeName ?? user.shop;
    final isBidder = user.role == 'bidder';
    return Material(
      color: AppColors.bg,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _working || _editing || _passwordOpen
              ? () async {}
              : _load,
          child: ListView(
            key: const ValueKey('profile.scroll'),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Hồ sơ',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.3,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tải lại hồ sơ',
                    onPressed: _working
                        ? null
                        : () async {
                            if (_editing && !_uncertainProfile) {
                              final discard = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Tải lại hồ sơ?'),
                                  content: const Text(
                                    'Các thay đổi chưa lưu sẽ được bỏ.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, false),
                                      child: const Text('Hủy'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, true),
                                      child: const Text('Tải lại'),
                                    ),
                                  ],
                                ),
                              );
                              if (!_active || discard != true) {
                                return;
                              }
                            }
                            await _load();
                          },
                    icon: const Icon(
                      Icons.refresh,
                      size: 20,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              if (_working)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (_error != null && !_editing) _errorBox(_error!),
              _card(
                child: Row(
                  children: [
                    _avatar(_editing ? _draftAvatar : profile?.avatarUrl, name),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            email,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          StatusPill(
                            label: shop == null
                                ? user.roleLabel
                                : '${user.roleLabel} · $shop',
                            tone: StatusTone.progress,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: _heading('Thông tin cá nhân')),
                  if (!_editing)
                    TextButton.icon(
                      onPressed:
                          _working ||
                              profile == null ||
                              _uncertainProfile ||
                              _uncertainPassword ||
                              _passwordOpen
                          ? null
                          : _edit,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Sửa'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              _card(
                child: _editing && profile != null
                    ? _profileFields(profile)
                    : Column(
                        children: [
                          _kv('Họ và tên', name),
                          _kv(
                            'Số điện thoại',
                            (profile?.phone ?? user.phone).isEmpty
                                ? 'Chưa cập nhật'
                                : (profile?.phone ?? user.phone),
                          ),
                          if (isBidder) _kv('Địa chỉ', _defaultAddress),
                          if (!isBidder && user.role == 'seller')
                            _kv('Tên gian hàng', shop ?? 'Chưa cập nhật'),
                          if (isBidder)
                            TextButton(
                              onPressed: _working ? null : _openAddresses,
                              child: const Text('Quản lý địa chỉ giao hàng'),
                            ),
                        ],
                      ),
              ),
              if (isBidder) ...[
                const SizedBox(height: 22),
                _heading('Đơn hàng của tôi'),
                const SizedBox(height: 8),
                _card(
                  padding: EdgeInsets.zero,
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: Text(
                            'Đang tải đơn hàng…',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                          ),
                        )
                      : _ordersError != null
                      ? Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _ordersError!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.dangerStrong,
                                ),
                              ),
                              TextButton(
                                onPressed: _working ? null : _load,
                                child: const Text('Thử tải lại đơn hàng'),
                              ),
                            ],
                          ),
                        )
                      : _orders.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: Text(
                            'Bạn chưa thắng phiên nào.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            for (
                              var i = 0;
                              i < _orders.length && i < 3;
                              i++
                            ) ...[
                              if (i != 0) const Divider(height: 1),
                              ListTile(
                                contentPadding: const EdgeInsets.all(14),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.progressBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.inventory_2_outlined,
                                    color: AppColors.accent,
                                  ),
                                ),
                                title: Text(
                                  _orders[i]['title']?.toString() ??
                                      'Đơn hàng #${_orders[i]['id']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    StatusPill(
                                      label: _paymentLabel(
                                        _orders[i]['paymentStatus'],
                                      ),
                                      tone:
                                          _orders[i]['paymentStatus'] == 'paid'
                                          ? StatusTone.success
                                          : StatusTone.pending,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _money(_orders[i]['finalPrice']),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: AppColors.muted,
                                ),
                                onTap: _working
                                    ? null
                                    : () => _openOrder(_orders[i]),
                              ),
                            ],
                            if (widget.onOrders != null)
                              TextButton(
                                onPressed: _working ? null : widget.onOrders,
                                child: const Text('Xem tất cả đơn hàng'),
                              ),
                          ],
                        ),
                ),
              ],
              const SizedBox(height: 22),
              _heading('Hỗ trợ'),
              const SizedBox(height: 8),
              _card(
                padding: EdgeInsets.zero,
                child: ListTile(
                  onTap: _working ? null : _support,
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.progressBg,
                    child: Icon(Icons.support_agent, color: AppColors.accent),
                  ),
                  title: const Text(
                    'Trợ lý hỗ trợ BidVibe',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Hỏi về cọc, thanh toán, giao hàng, tranh chấp…',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
              const SizedBox(height: 22),
              _heading('Bảo mật'),
              const SizedBox(height: 8),
              _card(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    const SwitchListTile(
                      value: false,
                      onChanged: null,
                      title: Text(
                        'Xác thực 2 lớp',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Tính năng chưa khả dụng.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      onTap: _working || _editing || _uncertainPassword
                          ? null
                          : () => setState(() {
                              _passwordOpen = !_passwordOpen;
                              _passwordError = null;
                              _clearPasswords();
                            }),
                      title: const Text(
                        'Đổi mật khẩu',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Icon(
                        _passwordOpen ? Icons.expand_less : Icons.expand_more,
                      ),
                    ),
                    if (_passwordOpen) _passwordFields(),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _heading('Thiết bị đã đăng nhập'),
              const SizedBox(height: 8),
              _card(
                child: Row(
                  children: [
                    const Icon(Icons.smartphone, color: AppColors.neutralFg),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Phiên hiện tại',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Bạn đang đăng nhập trên ứng dụng này.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                          Text(
                            'Chưa hỗ trợ xem các thiết bị khác.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              OutlinedButton.icon(
                onPressed: _working
                    ? null
                    : () {
                        _clearPasswords();
                        _store.logout();
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      },
                icon: const Icon(Icons.logout, size: 18),
                label: const Text(
                  'Đăng xuất',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.dangerStrong,
                  side: const BorderSide(
                    color: AppColors.dangerStrong,
                    width: 1.5,
                  ),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
