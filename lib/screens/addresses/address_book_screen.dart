import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../features/addresses/address_repository.dart';
import '../../theme.dart';

/// In selection mode, returns a fresh ShippingAddress via Navigator.pop.
/// The caller attaches its ID to the order; this screen never changes an order.
class AddressBookScreen extends StatefulWidget {
  final AddressRepository repository;
  final bool selectionMode;
  final String? selectedAddressId;
  final void Function(ApiException error)? onSessionExpired;
  const AddressBookScreen({
    super.key,
    required this.repository,
    this.selectionMode = false,
    this.selectedAddressId,
    this.onSessionExpired,
  });
  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  List<ShippingAddress> _items = [];
  bool _loading = true, _busy = false, _authFailed = false;
  String? _error, _selected;
  late final String? _token;
  late final String _baseUrl;
  bool get _active =>
      mounted &&
      widget.repository.api.token == _token &&
      ApiClient.baseUrl == _baseUrl;
  bool get _enabled => !_loading && !_busy && !_authFailed && _error == null;
  @override
  void initState() {
    super.initState();
    _token = widget.repository.api.token;
    _baseUrl = ApiClient.baseUrl;
    _selected = widget.selectedAddressId;
    _load();
  }

  bool _auth(Object error) {
    if (error is ApiException &&
        ['UNAUTHORIZED', 'ACCOUNT_SUSPENDED'].contains(error.code)) {
      setState(() => _authFailed = true);
      widget.onSessionExpired?.call(error);
      return true;
    }
    return false;
  }

  Future<void> _load() async {
    if (!_active) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.repository.list();
      if (!_active) {
        return;
      }
      setState(() {
        _items = items;
        if (!_items.any((a) => a.id == _selected)) {
          _selected = null;
        }
      });
    } catch (error) {
      if (!_active) {
        return;
      }
      if (!_auth(error)) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Chưa tải được địa chỉ. Vui lòng thử lại.',
        );
      }
    } finally {
      if (_active) {
        setState(() => _loading = false);
      }
    }
  }

  void _message(String message) {
    if (!_active) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _edit([ShippingAddress? address]) async {
    if (!_enabled) {
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _AddressEditor(
          repository: widget.repository,
          address: address,
          first: _items.isEmpty,
          onSessionExpired: widget.onSessionExpired,
        ),
      ),
    );
    if (_active) {
      await _load();
    }
  }

  Future<void> _mutate(Future<void> Function() action, String success) async {
    if (!_enabled) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
      if (_active) {
        _message(success);
      }
    } catch (error) {
      if (!_active) {
        return;
      }
      if (_auth(error)) {
        return;
      }
      final unknown =
          error is! ApiException ||
          [
            'NETWORK',
            'TIMEOUT',
            'INVALID_RESPONSE',
            'INTERNAL_ERROR',
          ].contains(error.code);
      _message(
        unknown
            ? 'Chưa xác định được kết quả. Đang tải lại danh sách; vui lòng kiểm tra trước khi thao tác tiếp.'
            : error.message,
      );
    } finally {
      if (_active) {
        await _load();
        if (_active) {
          setState(() => _busy = false);
        }
      }
    }
  }

  Future<void> _delete(ShippingAddress address) async {
    if (!_enabled) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa địa chỉ này?'),
        content: Text(
          'Địa chỉ của ${address.recipientName} sẽ bị xóa khỏi sổ địa chỉ. Đơn chưa gửi đang dùng địa chỉ này sẽ cần chọn lại địa chỉ giao hàng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Giữ lại'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Xóa địa chỉ',
              style: TextStyle(color: AppColors.dangerFg),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && _active) {
      await _mutate(
        () => widget.repository.remove(address.id),
        'Đã xóa địa chỉ.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final active =
        widget.repository.api.token == _token && ApiClient.baseUrl == _baseUrl;
    final enabled = _enabled && active;
    ShippingAddress? selected;
    for (final item in _items) {
      if (item.id == _selected) {
        selected = item;
      }
    }
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: Text(
            widget.selectionMode
                ? 'Chọn địa chỉ giao hàng'
                : 'Địa chỉ giao hàng',
          ),
          actions: [
            IconButton(
              tooltip: 'Tải lại địa chỉ',
              onPressed: _loading || _busy || _authFailed || !active
                  ? null
                  : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: !active || _authFailed
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Phiên đăng nhập đã thay đổi. Vui lòng quay lại và đăng nhập.',
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  if (!_busy && !_loading) {
                    await _load();
                  }
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _panel(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.progressBg,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.location_on_outlined,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Giao đến đúng nơi',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  widget.selectionMode
                                      ? 'Chọn nơi nhận hàng cho đơn của bạn.'
                                      : 'Lưu địa chỉ để chọn nhanh khi thanh toán.',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${_items.length}/10 địa chỉ',
                                  style: const TextStyle(
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
                    const SizedBox(height: 18),
                    if (_loading || _busy)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    if (_error != null)
                      _panel(
                        child: Column(
                          children: [
                            Text(
                              _error!,
                              style: const TextStyle(color: AppColors.dangerFg),
                            ),
                            TextButton.icon(
                              onPressed: _loading || _busy ? null : _load,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    if (!_loading && _error == null && _items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.add_location_alt_outlined,
                              size: 64,
                              color: AppColors.accent,
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Bạn chưa có địa chỉ nào',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Thêm nơi nhận hàng đầu tiên của bạn.',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                    for (final address in _items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _panel(
                          selected:
                              widget.selectionMode && address.id == _selected,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (widget.selectionMode)
                                    IconButton(
                                      tooltip:
                                          'Chọn địa chỉ của ${address.recipientName}',
                                      onPressed: enabled
                                          ? () => setState(
                                              () => _selected = address.id,
                                            )
                                          : null,
                                      icon: Icon(
                                        address.id == _selected
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_off,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          address.recipientName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          address.phone,
                                          style: const TextStyle(
                                            color: AppColors.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (address.isDefault)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.progressBg,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'Mặc định',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.accent,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                address.fullAddress,
                                style: const TextStyle(
                                  height: 1.6,
                                  color: AppColors.mutedStrong,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                children: [
                                  TextButton.icon(
                                    onPressed: enabled
                                        ? () => _edit(address)
                                        : null,
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 17,
                                    ),
                                    label: const Text('Sửa'),
                                  ),
                                  if (!address.isDefault)
                                    TextButton(
                                      onPressed: enabled
                                          ? () => _mutate(() async {
                                              await widget.repository
                                                  .setDefault(address.id);
                                            }, 'Đã đặt địa chỉ mặc định.')
                                          : null,
                                      child: const Text('Đặt mặc định'),
                                    ),
                                  TextButton(
                                    onPressed: enabled
                                        ? () => _delete(address)
                                        : null,
                                    child: const Text(
                                      'Xóa',
                                      style: TextStyle(
                                        color: AppColors.dangerFg,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_items.length >= 10)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Bạn đã lưu tối đa 10 địa chỉ.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: enabled && _items.length < 10
                        ? () => _edit()
                        : null,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Thêm địa chỉ mới'),
                  ),
                ),
                if (widget.selectionMode) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: enabled && selected != null
                          ? () =>
                                Navigator.of(context)
                                    .pop<ShippingAddress>(selected)
                          : null,
                      child: const Text('Dùng địa chỉ này'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _panel({required Widget child, bool selected = false}) => Material(
  color: AppColors.surface,
  clipBehavior: Clip.antiAlias,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: BorderSide(
      color: selected ? AppColors.accent : AppColors.border,
      width: selected ? 1.5 : 1,
    ),
  ),
  child: Padding(padding: const EdgeInsets.all(16), child: child),
);

class _AddressEditor extends StatefulWidget {
  final AddressRepository repository;
  final ShippingAddress? address;
  final bool first;
  final void Function(ApiException)? onSessionExpired;
  const _AddressEditor({
    required this.repository,
    this.address,
    required this.first,
    this.onSessionExpired,
  });
  @override
  State<_AddressEditor> createState() => _AddressEditorState();
}

class _AddressEditorState extends State<_AddressEditor> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  bool _saving = false,
      _default = false,
      _uncertain = false,
      _authFailed = false;
  String? _error;
  late final String? _token;
  late final String _baseUrl;
  bool get _active =>
      mounted &&
      widget.repository.api.token == _token &&
      ApiClient.baseUrl == _baseUrl;
  @override
  void initState() {
    super.initState();
    _token = widget.repository.api.token;
    _baseUrl = ApiClient.baseUrl;
    for (final key in [
      'recipientName',
      'phone',
      'city',
      'district',
      'ward',
      'addressLine',
    ]) {
      _fields[key] = TextEditingController(
        text: widget.address?.fields[key] as String? ?? '',
      );
    }
    _default = widget.first;
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving ||
        _uncertain ||
        _authFailed ||
        !_active ||
        !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    final fields = {
      for (final entry in _fields.entries) entry.key: entry.value.text.trim(),
    };
    final address = widget.address;
    final changes = {
      for (final entry in fields.entries)
        if (entry.value != (address?.fields[entry.key] ?? ''))
          entry.key: entry.value,
    };
    if (address != null && changes.isEmpty) {
      Navigator.pop(context, false);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (address == null) {
        await widget.repository.create(fields, isDefault: _default);
      } else {
        await widget.repository.update(address.id, changes);
      }
      if (mounted && _active) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (!_active) {
        return;
      }
      if (error is ApiException &&
          ['UNAUTHORIZED', 'ACCOUNT_SUSPENDED'].contains(error.code)) {
        setState(() {
          _authFailed = true;
          _error = error.message;
        });
        widget.onSessionExpired?.call(error);
      } else {
        setState(() {
          _uncertain =
              error is! ApiException ||
              [
                'NETWORK',
                'TIMEOUT',
                'INVALID_RESPONSE',
                'INTERNAL_ERROR',
              ].contains(error.code);
          _error = _uncertain
              ? 'Chưa xác định được kết quả lưu. Hãy quay về danh sách để kiểm tra trước khi thêm hoặc sửa lại.'
              : (error as ApiException).message;
        });
      }
    } finally {
      if (_active) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _input(
    String key,
    String label, {
    String? hint,
    TextInputType? keyboard,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey('address.$key'),
      controller: _fields[key],
      enabled: !_saving && !_uncertain && !_authFailed,
      keyboardType: keyboard,
      maxLines: maxLines,
      textCapitalization: key == 'phone'
          ? TextCapitalization.none
          : TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) => AddressRepository.fieldError(key, value),
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          widget.address == null ? 'Thêm địa chỉ mới' : 'Sửa địa chỉ',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Thông tin người nhận',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Nhập thông tin chính xác để nhận hàng thuận tiện.',
                style: TextStyle(color: AppColors.muted, height: 1.5),
              ),
              const SizedBox(height: 18),
              _panel(
                child: Column(
                  children: [
                    _input('recipientName', 'Họ và tên người nhận *'),
                    _input(
                      'phone',
                      'Số điện thoại *',
                      keyboard: TextInputType.phone,
                    ),
                    _input('city', 'Tỉnh / thành phố *'),
                    _input('district', 'Quận / huyện (không bắt buộc)'),
                    _input('ward', 'Phường / xã (không bắt buộc)'),
                    _input(
                      'addressLine',
                      'Địa chỉ cụ thể *',
                      hint: 'Số nhà, tên đường, tòa nhà…',
                      maxLines: 3,
                    ),
                    if (widget.address == null)
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Đặt làm địa chỉ mặc định'),
                        subtitle: Text(
                          widget.first
                              ? 'Địa chỉ đầu tiên tự động là mặc định.'
                              : 'Ưu tiên hiển thị trong Hồ sơ.',
                        ),
                        value: _default,
                        onChanged: _saving || widget.first || _uncertain
                            ? null
                            : (value) => setState(() => _default = value),
                      ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.dangerFg,
                      height: 1.5,
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _saving || _uncertain || _authFailed ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_saving ? 'Đang lưu…' : 'Lưu địa chỉ'),
              ),
              if (_uncertain)
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Về danh sách và kiểm tra'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
