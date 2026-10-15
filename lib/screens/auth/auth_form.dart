import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/remote_app_store.dart';
import '../../store.dart';
import 'auth_register.dart';

class AuthForm extends StatefulWidget {
  final bool register;
  const AuthForm({super.key, this.register = false});
  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _shop = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false, _hidden = true, _ops = false;
  String _role = 'bidder';
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _shop, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final store = context.read<AppStore>() as RemoteAppStore;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await store.authenticate(
        {
          'email': _email.text.trim().toLowerCase(),
          'password': _password.text,
          if (widget.register) ...{
            'fullName': _name.text.trim(),
            'role': _role,
            if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
            if (_role == 'seller' && _shop.text.trim().isNotEmpty)
              'shopName': _shop.text.trim(),
          },
        },
        register: widget.register,
        ops: _ops,
      );
      if (mounted && widget.register) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Không hoàn tất được đăng nhập. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
    TextInputType? keyboard,
    bool password = false,
    int? maxLength,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          controller: controller,
          enabled: !_busy,
          maxLength: maxLength,
          validator: validator,
          keyboardType: keyboard,
          obscureText: password && _hidden,
          autocorrect: !password,
          enableSuggestions: !password,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: password
                ? IconButton(
                    onPressed: () => setState(() => _hidden = !_hidden),
                    icon:
                        Icon(_hidden ? Icons.visibility : Icons.visibility_off),
                  )
                : null,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppStore>() as RemoteAppStore;
    final title = widget.register ? 'Tạo tài khoản' : 'Đăng nhập';
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: widget.register ? AppBar(title: Text(title)) : null,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _form,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.gavel_rounded, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'BidVibe',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(title, textAlign: TextAlign.center),
                        const SizedBox(height: 28),
                        if (widget.register) ...[
                          DropdownButtonFormField<String>(
                            initialValue: _role,
                            decoration: const InputDecoration(
                              labelText: 'Vai trò',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'bidder',
                                child: Text('Người mua'),
                              ),
                              DropdownMenuItem(
                                value: 'seller',
                                child: Text('Người bán'),
                              ),
                            ],
                            onChanged: _busy
                                ? null
                                : (v) => setState(() => _role = v!),
                          ),
                          const SizedBox(height: 16),
                          _field(
                            _name,
                            'Họ và tên',
                            maxLength: 100,
                            validator: (v) => v!.trim().isEmpty
                                ? 'Vui lòng nhập họ tên'
                                : null,
                          ),
                          _field(
                            _phone,
                            'Số điện thoại (không bắt buộc)',
                            keyboard: TextInputType.phone,
                            maxLength: 20,
                          ),
                          if (_role == 'seller')
                            _field(
                              _shop,
                              'Tên gian hàng (không bắt buộc)',
                              maxLength: 100,
                            ),
                        ],
                        _field(
                          _email,
                          'Email',
                          keyboard: TextInputType.emailAddress,
                          validator: (v) =>
                              RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                      .hasMatch(v!.trim())
                                  ? null
                                  : 'Email chưa hợp lệ',
                        ),
                        _field(
                          _password,
                          'Mật khẩu',
                          password: true,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Vui lòng nhập mật khẩu';
                            }
                            if (widget.register &&
                                (v.length < 6 || utf8.encode(v).length > 72)) {
                              return 'Tối thiểu 6 ký tự, tối đa 72 byte';
                            }
                            return null;
                          },
                        ),
                        if (widget.register)
                          _field(
                            _confirm,
                            'Nhập lại mật khẩu',
                            password: true,
                            validator: (v) => v == _password.text
                                ? null
                                : 'Mật khẩu chưa khớp',
                          ),
                        if (!widget.register)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Đăng nhập nhân viên / quản trị'),
                            value: _ops,
                            onChanged:
                                _busy ? null : (v) => setState(() => _ops = v!),
                          ),
                        if ((_error ?? session.sessionError) != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              _error ?? session.sessionError!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(title),
                          ),
                        ),
                        if (!widget.register)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const AuthRegisterScreen(),
                                      ),
                                    ),
                            child: const Text('Chưa có tài khoản? Đăng ký'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
