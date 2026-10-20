import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/remote_app_store.dart';
import '../../features/ops/ops_repository.dart';
import '../../features/profile/profile_repository.dart';
import '../../store.dart';
import '../../theme.dart';

OpsRepository _ops(BuildContext context) =>
    OpsRepository(
      (context.read<AppStore>() as RemoteAppStore).api,
      onAuthError: (context.read<AppStore>() as RemoteAppStore).handleApiException,
    );

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

String _string(dynamic value, [String fallback = '—']) =>
    value is String && value.isNotEmpty ? value : fallback;

String _money(dynamic value) {
  final digits = (value is num ? value.toInt() : 0).toString();
  return '${digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')} đ';
}

class AdminOpsFlagsScreen extends StatefulWidget {
  const AdminOpsFlagsScreen({super.key});

  @override
  State<AdminOpsFlagsScreen> createState() => _AdminOpsFlagsScreenState();
}

class _AdminOpsFlagsScreenState extends State<AdminOpsFlagsScreen> {
  String severity = 'all';
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _ops(context).flags();
  }

  Future<void> _refresh() async {
    final next = _ops(context).flags();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _CaseError(error: snapshot.error!, onRetry: _refresh);
      }
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final rows = snapshot.data!
          .where((row) => severity == 'all' || row['severity'] == severity)
          .toList();
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            const _Header(eyebrow: 'QUẢN TRỊ', title: 'Cờ phiên'),
            const SizedBox(height: 4),
            const Text('Cờ do hệ thống phát hiện và báo cáo từ người dùng.', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _Filter(label: 'Tất cả', value: 'all', selected: severity, onSelect: (v) => setState(() => severity = v)),
                _Filter(label: 'Cao', value: 'high', selected: severity, onSelect: (v) => setState(() => severity = v)),
                _Filter(label: 'Trung bình', value: 'medium', selected: severity, onSelect: (v) => setState(() => severity = v)),
                _Filter(label: 'Thấp', value: 'low', selected: severity, onSelect: (v) => setState(() => severity = v)),
              ],
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty) const _Empty('Không có cờ phù hợp.'),
            for (final flag in rows)
              _CaseTile(
                title: _string(_map(flag['auction'])['title'], 'Phiên #${_map(flag['auction'])['id'] ?? '—'}'),
                subtitle: '${_string(flag['reason'])} · ${_string(flag['severity'])} · ${_string(flag['status'])}',
                detail: 'Độ tin cậy ${flag['confidence'] ?? 0}%',
                onTap: () async {
                  await Navigator.of(context).push<void>(MaterialPageRoute(
                    builder: (_) => AdminOpsFlagDetailScreen(flagId: '${flag['id']}'),
                  ));
                  if (mounted) await _refresh();
                },
              ),
          ],
        ),
      );
    },
  );
}

class AdminOpsFlagDetailScreen extends StatefulWidget {
  final String flagId;
  const AdminOpsFlagDetailScreen({super.key, required this.flagId});

  @override
  State<AdminOpsFlagDetailScreen> createState() => _AdminOpsFlagDetailScreenState();
}

class _AdminOpsFlagDetailScreenState extends State<AdminOpsFlagDetailScreen> {
  Future<Map<String, dynamic>>? _future;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _ops(context).flag(widget.flagId);
  }

  Future<void> _act(Map<String, dynamic> flag, String action) async {
    String? reason;
    if (action == 'terminate') {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Chấm dứt phiên?'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 1000,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Lý do bắt buộc'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Huỷ')),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) Navigator.pop(dialogContext, value);
              },
              child: const Text('Chấm dứt'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (reason == null || !mounted) return;
    }
    setState(() => _saving = true);
    try {
      await _ops(context).actOnFlag(widget.flagId, action: action, reason: reason);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted && !const {'UNAUTHORIZED', 'ACCOUNT_SUSPENDED'}.contains(error.code)) {
        _showError(context, error.message);
      }
    } catch (_) {
      if (mounted) _showError(context, 'Không thực hiện được thao tác.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _retryFlag() async {
    final next = _ops(context).flag(widget.flagId);
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết cờ')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _CaseError(error: snapshot.error!, onRetry: _retryFlag);
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final flag = snapshot.data!;
        final auction = _map(flag['auction']);
        final evidence = flag['evidence'] is List ? (flag['evidence'] as List).whereType<Map>() : const <Map>[];
        final closed = const {'safe', 'terminated'}.contains(flag['status']);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(_string(auction['title']), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Phiên #${auction['id'] ?? '—'} · ${flag['severity'] ?? '—'} · ${flag['status'] ?? '—'}'),
            const SizedBox(height: 14),
            _InfoSection(title: 'Lý do', values: {
              'Mô tả': flag['reason'],
              'Giải thích': flag['aiExplanation'],
              'Độ tin cậy': '${flag['confidence'] ?? 0}%',
              'Giá hiện tại': _money(auction['currentPrice']),
              'Lượt đặt giá': auction['bidCount'],
            }),
            const SizedBox(height: 12),
            _InfoSection(title: 'Bằng chứng', values: {
              for (final item in evidence) '${item['label'] ?? 'Bằng chứng'}': item['value'] ?? '—',
            }),
            if (!closed) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _saving || flag['status'] == 'paused' ? null : () => _act(flag, 'pause'),
                icon: const Icon(Icons.pause),
                label: const Text('Tạm dừng phiên'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.dangerStrong),
              ),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: _saving ? null : () => _act(flag, 'verify'), child: const Text('Yêu cầu xác minh')),
              OutlinedButton(onPressed: _saving ? null : () => _act(flag, 'safe'), child: const Text('Đánh dấu an toàn')),
              OutlinedButton.icon(
                onPressed: _saving ? null : () => _act(flag, 'terminate'),
                icon: const Icon(Icons.dangerous_outlined),
                label: const Text('Chấm dứt phiên'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.dangerStrong),
              ),
              if (_saving) const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
            ],
          ],
        );
      },
    ),
  );
}

class AdminOpsDisputesScreen extends StatefulWidget {
  const AdminOpsDisputesScreen({super.key});

  @override
  State<AdminOpsDisputesScreen> createState() => _AdminOpsDisputesScreenState();
}

class _AdminOpsDisputesScreenState extends State<AdminOpsDisputesScreen> {
  String status = 'all';
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _ops(context).disputes();
  }

  Future<void> _refresh() async {
    final next = _ops(context).disputes(status: status == 'all' ? null : status);
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {}
  }

  void _setStatus(String value) {
    setState(() {
      status = value;
      _future = _ops(context).disputes(status: value == 'all' ? null : value);
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) return _CaseError(error: snapshot.error!, onRetry: _refresh);
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final rows = snapshot.data!;
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            const _Header(eyebrow: 'QUẢN TRỊ', title: 'Tranh chấp'),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              _Filter(label: 'Tất cả', value: 'all', selected: status, onSelect: _setStatus),
              _Filter(label: 'Đang mở', value: 'open', selected: status, onSelect: _setStatus),
              _Filter(label: 'Đã xử lý', value: 'resolved', selected: status, onSelect: _setStatus),
            ]),
            const SizedBox(height: 12),
            if (rows.isEmpty) const _Empty('Không có tranh chấp phù hợp.'),
            for (final dispute in rows)
              _CaseTile(
                title: _string(dispute['itemTitle'], 'Đơn #${dispute['orderId'] ?? '—'}'),
                subtitle: _string(dispute['title']),
                detail: '${_string(dispute['source'])} · ${_string(dispute['status'])} · ${_money(dispute['escrowAmount'])}',
                onTap: () async {
                  await Navigator.of(context).push<void>(MaterialPageRoute(
                    builder: (_) => AdminOpsDisputeDetailScreen(dispute: dispute),
                  ));
                  if (mounted) await _refresh();
                },
              ),
          ],
        ),
      );
    },
  );
}

class AdminOpsDisputeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> dispute;
  const AdminOpsDisputeDetailScreen({super.key, required this.dispute});

  @override
  State<AdminOpsDisputeDetailScreen> createState() => _AdminOpsDisputeDetailScreenState();
}

class _AdminOpsDisputeDetailScreenState extends State<AdminOpsDisputeDetailScreen> {
  bool _saving = false;

  Widget _evidencePhoto(Map<String, dynamic> photo) {
    final url = photo['url'] as String;
    final role = switch (photo['uploaderRole']) {
      'bidder' => 'Người mua',
      'seller' => 'Người bán',
      'warehouse' => 'Kho',
      _ => 'Ảnh',
    };
    Widget image({double? width, double? height}) => Image.network(
      url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: width,
        height: height,
        color: AppColors.neutralBg,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined, color: AppColors.muted),
      ),
    );

    return Semantics(
      button: true,
      label: 'Xem ảnh bằng chứng của $role',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => Dialog(
            child: InteractiveViewer(
              child: Image.network(
                url,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Không tải được ảnh.'),
                ),
              ),
            ),
          ),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: image(width: 96, height: 96),
            ),
            const SizedBox(height: 4),
            Text(role, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  Future<void> _resolve(String resolution) async {
    final noteController = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(resolution == 'refund' ? 'Hoàn tiền người mua?' : 'Giữ nguyên giao dịch?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(resolution == 'refund'
                ? 'Khoản ký quỹ ${_money(widget.dispute['escrowAmount'])} sẽ được hoàn vào ví người mua.'
                : 'Khoản ký quỹ sẽ được giải ngân cho người bán.'),
            const SizedBox(height: 12),
            TextField(controller: noteController, maxLength: 2000, maxLines: 3, decoration: const InputDecoration(labelText: 'Ghi chú (không bắt buộc)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, noteController.text), child: const Text('Xác nhận')),
        ],
      ),
    );
    noteController.dispose();
    if (note == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await _ops(context).resolveDispute(
        '${widget.dispute['id']}',
        resolution: resolution,
        note: note,
      );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted && !const {'UNAUTHORIZED', 'ACCOUNT_SUSPENDED'}.contains(error.code)) {
        _showError(context, error.message);
      }
    } catch (_) {
      if (mounted) _showError(context, 'Không xử lý được tranh chấp.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dispute = widget.dispute;
    final timeline = dispute['timeline'] is List
        ? (dispute['timeline'] as List).whereType<Map>().toList()
        : const <Map>[];
    final photos = dispute['photos'] is List
        ? (dispute['photos'] as List)
            .whereType<Map>()
            .map((photo) => Map<String, dynamic>.from(photo))
            .where((photo) =>
                photo['url'] is String &&
                ProfileRepository.validUrl(photo['url'] as String))
            .toList()
        : <Map<String, dynamic>>[];
    final open = dispute['status'] == 'open';
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết tranh chấp')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_string(dispute['itemTitle']), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Tranh chấp #${dispute['id']} · Đơn #${dispute['orderId']} · ${_string(dispute['source'])}'),
          const SizedBox(height: 14),
          _InfoSection(title: 'Báo cáo', values: {
            'Tiêu đề': dispute['title'],
            'Trạng thái': dispute['status'],
            'Số tiền ký quỹ': _money(dispute['escrowAmount']),
            'Giá chốt': _money(dispute['finalPrice']),
            'Kết quả': dispute['resolution'],
            'Người xử lý': dispute['resolvedBy'],
          }),
          const SizedBox(height: 12),
          _InfoSection(title: 'Diễn biến', values: {
            for (var i = 0; i < timeline.length; i++) 'Mốc ${i + 1} · ${timeline[i]['at'] ?? '—'}': timeline[i]['note'] ?? '—',
          }),
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ảnh bằng chứng (${photos.length})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [for (final photo in photos) _evidencePhoto(photo)],
                  ),
                ],
              ),
            ),
          ],
          if (open) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : () => _resolve('refund'),
              icon: const Icon(Icons.currency_exchange),
              label: const Text('Hoàn tiền người mua'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.dangerStrong),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _resolve('keep'),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Giữ nguyên, giải ngân người bán'),
            ),
            if (_saving) const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String eyebrow;
  final String title;
  const _Header({required this.eyebrow, required this.title});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(eyebrow, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
      Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
    ],
  );
}

class _Filter extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onSelect;
  const _Filter({required this.label, required this.value, required this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label),
    selected: value == selected,
    onSelected: (_) => onSelect(value),
  );
}

class _CaseTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String detail;
  final VoidCallback onTap;
  const _CaseTile({required this.title, required this.subtitle, required this.detail, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      onTap: onTap,
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(detail, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
      ),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

class _InfoSection extends StatelessWidget {
  final String title;
  final Map<String, dynamic> values;
  const _InfoSection({required this.title, required this.values});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      const Divider(height: 18),
      for (final item in values.entries)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 110, child: Text(item.key, style: const TextStyle(color: AppColors.muted))),
            Expanded(child: Text('${item.value ?? '—'}')),
          ]),
        ),
    ]),
  );
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: Center(child: Text(text, style: const TextStyle(color: AppColors.muted))));
}

class _CaseError extends StatelessWidget {
  final Object error;
  final Future<void> Function() onRetry;
  const _CaseError({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    final message = error is ApiException ? (error as ApiException).message : 'Không tải được dữ liệu.';
    return Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Thử lại')),
      ]),
    ));
  }
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}