import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/remote_app_store.dart';
import '../../features/ops/ops_repository.dart';
import '../../store.dart';
import '../../theme.dart';

OpsRepository _ops(BuildContext context) =>
    OpsRepository(
      (context.read<AppStore>() as RemoteAppStore).api,
      onAuthError: (context.read<AppStore>() as RemoteAppStore).handleApiException,
    );

class AdminOpsAccountsScreen extends StatefulWidget {
  const AdminOpsAccountsScreen({super.key});

  @override
  State<AdminOpsAccountsScreen> createState() => _AdminOpsAccountsScreenState();
}

class _AdminOpsAccountsScreenState extends State<AdminOpsAccountsScreen> {
  bool opsMode = false;
  String role = 'all';
  String status = 'all';
  final searchController = TextEditingController();
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() => opsMode
      ? _ops(context).opsAccounts(
          role: role == 'all' ? null : role,
          status: status == 'all' ? null : status,
        )
      : _ops(context).accounts(
          role: role == 'all' ? null : role,
          status: status == 'all' ? null : status,
          query: searchController.text,
        );

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  void _changeFilter({bool? nextOps, String? nextRole, String? nextStatus}) {
    setState(() {
      if (nextOps != null && nextOps != opsMode) {
        opsMode = nextOps;
        role = 'all';
      }
      if (nextRole != null) role = nextRole;
      if (nextStatus != null) status = nextStatus;
      _future = _load();
    });
  }

  Future<void> _changeAccountStatus(Map<String, dynamic> account) async {
    final nextStatus = account['status'] == 'active' ? 'suspended' : 'active';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(nextStatus == 'suspended' ? 'Tạm khoá tài khoản?' : 'Kích hoạt tài khoản?'),
        content: Text('${account['name'] ?? account['fullName'] ?? account['email']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Xác nhận')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      if (opsMode) {
        await _ops(context).updateOpsAccount('${account['id']}', status: nextStatus);
      } else {
        await _ops(context).updateAccount('${account['id']}', status: nextStatus);
      }
      if (mounted) await _refresh();
    } on ApiException catch (error) {
      if (mounted && !const {'UNAUTHORIZED', 'ACCOUNT_SUSPENDED'}.contains(error.code)) {
        _showError(context, error.message);
      }
    } catch (_) {
      if (mounted) _showError(context, 'Không cập nhật được tài khoản.');
    }
  }

  Future<void> _createOpsAccount() async {
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _OpsAccountForm(),
    );
    if (values == null || !mounted) return;
    try {
      await _ops(context).createOpsAccount(
        name: values['name']!,
        email: values['email']!,
        role: values['role']!,
        password: values['password']!,
      );
      if (mounted) await _refresh();
    } on ApiException catch (error) {
      if (mounted && !const {'UNAUTHORIZED', 'ACCOUNT_SUSPENDED'}.contains(error.code)) {
        _showError(context, error.message);
      }
    } catch (_) {
      if (mounted) _showError(context, 'Không tạo được tài khoản vận hành.');
    }
  }

  Future<void> _editOpsAccount(Map<String, dynamic> account) async {
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _OpsAccountForm(account: account),
    );
    if (values == null || !mounted) return;
    final changed = <String, String>{};
    if (values['name'] != account['name']) changed['name'] = values['name']!;
    if (values['role'] != account['role']) changed['role'] = values['role']!;
    if (values['password']!.isNotEmpty) changed['password'] = values['password']!;
    if (changed.isEmpty) return;
    try {
      await _ops(context).updateOpsAccount(
        '${account['id']}',
        name: changed['name'],
        role: changed['role'],
        password: changed['password'],
      );
      if (mounted) await _refresh();
    } on ApiException catch (error) {
      if (mounted && !const {'UNAUTHORIZED', 'ACCOUNT_SUSPENDED'}.contains(error.code)) {
        _showError(context, error.message);
      }
    } catch (_) {
      if (mounted) _showError(context, 'Không cập nhật được tài khoản vận hành.');
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('QUẢN TRỊ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
          const Text('Tài khoản', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Người dùng')),
              ButtonSegment(value: true, label: Text('Tài khoản ops')),
            ],
            selected: {opsMode},
            onSelectionChanged: (value) => _changeFilter(nextOps: value.first),
          ),
          const SizedBox(height: 10),
          if (!opsMode)
            TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _refresh(),
              decoration: InputDecoration(
                hintText: 'Tìm tên hoặc email',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(tooltip: 'Tìm', onPressed: _refresh, icon: const Icon(Icons.arrow_forward)),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Vai trò', isDense: true, border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('Tất cả')),
                  if (opsMode) ...[
                    const DropdownMenuItem(value: 'appraiser', child: Text('Thẩm định')),
                    const DropdownMenuItem(value: 'warehouse', child: Text('Kho vận')),
                    const DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ] else ...[
                    const DropdownMenuItem(value: 'bidder', child: Text('Người mua')),
                    const DropdownMenuItem(value: 'seller', child: Text('Người bán')),
                  ],
                ],
                onChanged: (value) => _changeFilter(nextRole: value),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Trạng thái', isDense: true, border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Tất cả')),
                  DropdownMenuItem(value: 'active', child: Text('Hoạt động')),
                  DropdownMenuItem(value: 'suspended', child: Text('Bị khoá')),
                ],
                onChanged: (value) => _changeFilter(nextStatus: value),
              ),
            ),
          ]),
          if (opsMode) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _createOpsAccount,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Tạo tài khoản ops'),
              ),
            ),
          ],
        ]),
      ),
      Expanded(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              final message = snapshot.error is ApiException
                  ? (snapshot.error as ApiException).message
                  : 'Không tải được danh sách tài khoản.';
              return _AccountsError(message: message, onRetry: _refresh);
            }
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (snapshot.data!.isEmpty) return const Center(child: Text('Không có tài khoản phù hợp.'));
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final account = snapshot.data![index];
                  final name = '${account[opsMode ? 'name' : 'fullName'] ?? ''}';
                  final active = account['status'] == 'active';
                  final roleLabel = switch ('${account['role']}') {
                    'bidder' => 'Người mua',
                    'seller' => 'Người bán',
                    'appraiser' => 'Thẩm định',
                    'warehouse' => 'Kho vận',
                    'admin' => 'Admin',
                    _ => '${account['role'] ?? '—'}',
                  };
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          CircleAvatar(child: Text(name.isEmpty ? '?' : name[0])),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('${account['email'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                          ])),
                          Icon(active ? Icons.check_circle : Icons.block, color: active ? AppColors.successStrong : AppColors.dangerStrong, size: 19),
                        ]),
                        const SizedBox(height: 8),
                        Text('$roleLabel${opsMode ? ' · ${account['weeklyLoad'] ?? 0} việc/tuần' : ''}', style: const TextStyle(fontSize: 12, color: AppColors.mutedStrong)),
                        const SizedBox(height: 8),
                        Row(children: [
                          if (opsMode)
                            TextButton.icon(onPressed: () => _editOpsAccount(account), icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Sửa')),
                          const Spacer(),
                          OutlinedButton(
                            onPressed: () => _changeAccountStatus(account),
                            child: Text(active ? 'Tạm khoá' : 'Kích hoạt'),
                          ),
                        ]),
                      ]),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ],
  );
}

class _OpsAccountForm extends StatefulWidget {
  final Map<String, dynamic>? account;
  const _OpsAccountForm({this.account});

  @override
  State<_OpsAccountForm> createState() => _OpsAccountFormState();
}

class _OpsAccountFormState extends State<_OpsAccountForm> {
  final formKey = GlobalKey<FormState>();
  late final nameController = TextEditingController(text: '${widget.account?['name'] ?? ''}');
  late final emailController = TextEditingController(text: '${widget.account?['email'] ?? ''}');
  final passwordController = TextEditingController();
  late String role = '${widget.account?['role'] ?? 'appraiser'}';

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.account == null ? 'Tạo tài khoản ops' : 'Sửa tài khoản ops'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: formKey,
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: nameController, decoration: const InputDecoration(labelText: 'Họ tên'), validator: (v) => v == null || v.trim().isEmpty ? 'Nhập họ tên' : null),
          if (widget.account == null)
            TextFormField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email'), validator: (v) => v == null || !v.contains('@') ? 'Email không hợp lệ' : null),
          DropdownButtonFormField<String>(
            initialValue: role,
            decoration: const InputDecoration(labelText: 'Vai trò'),
            items: const [
              DropdownMenuItem(value: 'appraiser', child: Text('Thẩm định')),
              DropdownMenuItem(value: 'warehouse', child: Text('Kho vận')),
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
            ],
            onChanged: (value) => setState(() => role = value ?? role),
          ),
          TextFormField(
            controller: passwordController,
            obscureText: true,
            decoration: InputDecoration(labelText: widget.account == null ? 'Mật khẩu' : 'Mật khẩu mới (tuỳ chọn)'),
            validator: (value) => widget.account == null && (value == null || value.length < 6) ? 'Mật khẩu tối thiểu 6 ký tự' : null,
          ),
        ])),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
      FilledButton(
        onPressed: () {
          if (!formKey.currentState!.validate()) return;
          Navigator.pop(context, {
            'name': nameController.text.trim(),
            'email': emailController.text.trim(),
            'role': role,
            'password': passwordController.text,
          });
        },
        child: const Text('Lưu'),
      ),
    ],
  );
}

class _AccountsError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _AccountsError({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Padding(padding: const EdgeInsets.all(20), child: Text(message, textAlign: TextAlign.center)),
    OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Thử lại')),
  ]));
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}