import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/remote_app_store.dart';
import '../../features/ops/ops_repository.dart';
import '../../store.dart';
import '../../theme.dart';
import '../orders/order_labels.dart';

OpsRepository _ops(BuildContext context) =>
    OpsRepository(
      (context.read<AppStore>() as RemoteAppStore).api,
      onAuthError: (context.read<AppStore>() as RemoteAppStore).handleApiException,
    );

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

String _paymentLabel(dynamic value) => switch (value) {
  'paid' => 'Đã thanh toán',
  'awaiting_payment' => 'Chờ thanh toán',
  'expired' => 'Quá hạn thanh toán',
  _ => value is String && value.isNotEmpty ? value : '—',
};

String _inspectionLabel(dynamic value) => switch (value) {
  'match' => 'Khớp mô tả',
  'mismatch' => 'Không khớp mô tả',
  _ => value is String && value.isNotEmpty ? value : '—',
};

/// Giờ ISO của BE -> "HH:mm dd/MM/yyyy" theo giờ máy.
String _eventTime(dynamic value) =>
    orderTime(value is String ? DateTime.tryParse(value)?.toLocal() : null);

String _str(dynamic value, [String fallback = '—']) =>
    value is String && value.isNotEmpty ? value : fallback;

const _stages = <(String, String)>[
  ('in_transit_to_warehouse', 'Chờ kho nhận'),
  ('inspecting', 'Đang kiểm định'),
  ('inspection_failed', 'Có sai lệch'),
  ('inspected', 'Đạt kiểm định'),
  ('packed', 'Đã đóng gói'),
  ('shipped', 'Đang vận chuyển'),
  ('delivered', 'Đã giao'),
  ('completed', 'Hoàn tất'),
];

String _stageLabel(String stage) =>
    _stages.where((item) => item.$1 == stage).map((item) => item.$2).firstOrNull ?? stage;

class WarehouseOpsScreen extends StatefulWidget {
  const WarehouseOpsScreen({super.key});

  @override
  State<WarehouseOpsScreen> createState() => _WarehouseOpsScreenState();
}

class _WarehouseOpsScreenState extends State<WarehouseOpsScreen> {
  String stage = 'all';
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _ops(context).warehouseOrders();
  }

  Future<void> _refresh() async {
    final next = _ops(context).warehouseOrders();
    setState(() {
      _future = next;
    });
    try {
      await next;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('KHO VẬN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
          const Text('Đơn hàng trong kho', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: DropdownButtonFormField<String>(
              initialValue: stage,
              decoration: const InputDecoration(labelText: 'Giai đoạn', isDense: true, border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('Tất cả giai đoạn')),
                for (final item in _stages) DropdownMenuItem(value: item.$1, child: Text(item.$2)),
              ],
              onChanged: (value) => setState(() => stage = value ?? 'all'),
            ),
          ),
        ]),
      ),
      Expanded(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) return _WarehouseError(error: snapshot.error!, onRetry: _refresh);
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final rows = snapshot.data!
                .where((order) => stage == 'all' || order['stage'] == stage)
                .toList();
            if (rows.isEmpty) return const Center(child: Text('Không có đơn ở giai đoạn này.'));
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final order = rows[index];
                  final seller = _map(order['seller']);
                  final warehouse = _map(order['warehouse']);
                  return Card(
                    child: ListTile(
                      onTap: () async {
                        await Navigator.of(context).push<void>(MaterialPageRoute(
                          builder: (_) => WarehouseOpsDetailScreen(orderId: '${order['id']}'),
                        ));
                        if (mounted) await _refresh();
                      },
                      leading: const CircleAvatar(child: Icon(Icons.inventory_2_outlined)),
                      title: Text('${order['title'] ?? 'Đơn hàng'}', maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${warehouse['orderCode'] ?? 'Đơn #${order['id']}'} · ${seller['storeName'] ?? 'Người bán'} · ${_stageLabel('${order['stage']}')}', maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ]),
  );
}

class WarehouseOpsDetailScreen extends StatefulWidget {
  final String orderId;
  const WarehouseOpsDetailScreen({super.key, required this.orderId});

  @override
  State<WarehouseOpsDetailScreen> createState() => _WarehouseOpsDetailScreenState();
}

class _WarehouseOpsDetailScreenState extends State<WarehouseOpsDetailScreen> {
  Future<Map<String, dynamic>>? _future;
  bool _saving = false;
  String inspectResult = 'match';
  final inspectNotes = TextEditingController();
  final packNotes = TextEditingController();
  final carrier = TextEditingController();
  final trackingCode = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _ops(context).warehouseOrder(widget.orderId);
  }

  @override
  void dispose() {
    inspectNotes.dispose();
    packNotes.dispose();
    carrier.dispose();
    trackingCode.dispose();
    super.dispose();
  }

  Future<void> _run(Future<Map<String, dynamic>> Function() action) async {
    setState(() => _saving = true);
    try {
      final updated = await action();
      if (mounted) setState(() => _future = Future.value(updated));
    } on ApiException catch (error) {
      if (mounted && !const {'UNAUTHORIZED', 'ACCOUNT_SUSPENDED'}.contains(error.code)) {
        _showError(context, error.message);
      }
    } catch (_) {
      if (mounted) _showError(context, 'Không cập nhật được đơn hàng.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _retryOrder() async {
    final next = _ops(context).warehouseOrder(widget.orderId);
    setState(() {
      _future = next;
    });
    try {
      await next;
    } catch (_) {}
  }

  Future<void> _ship() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Xác nhận bàn giao vận chuyển'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: carrier,
              onChanged: (_) => setDialogState(() {}),
              decoration: const InputDecoration(labelText: 'Đơn vị vận chuyển'),
              textCapitalization: TextCapitalization.words,
            ),
            TextField(
              controller: trackingCode,
              onChanged: (_) => setDialogState(() {}),
              decoration: const InputDecoration(labelText: 'Mã vận đơn'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Huỷ')),
            FilledButton(
              onPressed: carrier.text.trim().isEmpty || trackingCode.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Xác nhận gửi'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() => _ops(context).shipWarehouseOrder(
      widget.orderId,
      carrier: carrier.text,
      trackingCode: trackingCode.text,
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết đơn kho')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _WarehouseError(error: snapshot.error!, onRetry: _retryOrder);
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final order = snapshot.data!;
        final stage = '${order['stage'] ?? ''}';
        final seller = _map(order['seller']);
        final buyer = _map(order['buyer']);
        final address = _map(order['shippingAddress']);
        final warehouse = _map(order['warehouse']);
        final shipment = _map(order['shipment']);
        final events = order['events'] is List ? (order['events'] as List).whereType<Map>().toList() : const <Map>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text(_str(warehouse['orderCode'], 'Đơn #${order['id']}'), style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 4),
            Text('${order['title'] ?? 'Đơn hàng'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Chip(label: Text(_stageLabel(stage))),
            _WarehousePanel(title: 'Người bán', values: {
              'Tên gian hàng': seller['storeName'],
              'Đơn hàng': order['id'],
              'Trạng thái thanh toán': _paymentLabel(order['paymentStatus']),
            }),
            const SizedBox(height: 10),
            _WarehousePanel(title: 'Người nhận và địa chỉ', values: {
              'Người nhận': buyer['name'],
              'Điện thoại': buyer['phone'],
              'Địa chỉ': address.isEmpty ? 'Chưa chọn địa chỉ' : [address['addressLine'], address['ward'], address['district'], address['city']].whereType<String>().where((value) => value.isNotEmpty).join(', '),
            }),
            if (warehouse.isNotEmpty || shipment.isNotEmpty) ...[
              const SizedBox(height: 10),
              _WarehousePanel(title: 'Thông tin xử lý', values: {
                'Kết quả kiểm định': _inspectionLabel(warehouse['inspectionResult']),
                'Ghi chú kiểm định': warehouse['inspectionNotes'],
                'Đơn vị vận chuyển': shipment['carrier'],
                'Mã vận đơn': shipment['trackingCode'],
              }),
            ],
            if (events.isNotEmpty) ...[
              const SizedBox(height: 10),
              _WarehousePanel(title: 'Lịch sử', values: {
                for (var index = 0; index < events.length; index++) '${eventLabel('${events[index]['step'] ?? 'Bước ${index + 1}'}')} · ${_eventTime(events[index]['at'])}': events[index]['note'] ?? '—',
              }),
            ],
            const SizedBox(height: 16),
            if (stage == 'in_transit_to_warehouse')
              FilledButton.icon(
                onPressed: _saving ? null : () => _run(() => _ops(context).receiveWarehouseOrder(widget.orderId)),
                icon: const Icon(Icons.inventory),
                label: const Text('Xác nhận kho đã nhận hàng'),
              ),
            if (stage == 'inspecting') ...[
              const Text('Kết quả kiểm định', style: TextStyle(fontWeight: FontWeight.w700)),
              RadioGroup<String>(
                groupValue: inspectResult,
                onChanged: (value) {
                  if (!_saving && value != null) {
                    setState(() => inspectResult = value);
                  }
                },
                child: const Column(children: [
                  RadioListTile<String>(value: 'match', title: Text('Khớp mô tả')),
                  RadioListTile<String>(value: 'mismatch', title: Text('Không khớp, mở tranh chấp')),
                ]),
              ),
              if (inspectResult == 'mismatch')
                TextField(
                  controller: inspectNotes,
                  onChanged: (_) => setState(() {}),
                  maxLength: 2000,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Mô tả sai lệch (bắt buộc)', border: OutlineInputBorder()),
                ),
              FilledButton(
                onPressed: _saving || (inspectResult == 'mismatch' && inspectNotes.text.trim().isEmpty)
                    ? null
                    : () => _run(() => _ops(context).inspectWarehouseOrder(widget.orderId, result: inspectResult, notes: inspectNotes.text)),
                child: const Text('Lưu kết quả kiểm định'),
              ),
            ],
            if (stage == 'inspected') ...[
              TextField(controller: packNotes, maxLength: 500, maxLines: 2, decoration: const InputDecoration(labelText: 'Ghi chú đóng gói (không bắt buộc)', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              FilledButton.icon(onPressed: _saving ? null : () => _run(() => _ops(context).packWarehouseOrder(widget.orderId, notes: packNotes.text)), icon: const Icon(Icons.inventory_2), label: const Text('Xác nhận đóng gói')),
            ],
            if (stage == 'packed')
              FilledButton.icon(onPressed: _saving ? null : _ship, icon: const Icon(Icons.local_shipping_outlined), label: const Text('Gửi cho đơn vị vận chuyển')),
            if (stage == 'shipped')
              FilledButton.icon(onPressed: _saving ? null : () => _run(() => _ops(context).deliverWarehouseOrder(widget.orderId)), icon: const Icon(Icons.done_all), label: const Text('Xác nhận đã giao')),
            if (stage == 'inspection_failed')
              const Text('Đơn đang dừng để Admin xử lý tranh chấp.', style: TextStyle(color: AppColors.dangerStrong)),
            if (stage == 'delivered' || stage == 'completed')
              const Text('Không còn thao tác kho cho đơn này.', style: TextStyle(color: AppColors.successStrong)),
            if (_saving) const Center(child: Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator())),
          ],
        );
      },
    ),
  );
}

class _WarehousePanel extends StatelessWidget {
  final String title;
  final Map<String, dynamic> values;
  const _WarehousePanel({required this.title, required this.values});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      const Divider(height: 18),
      for (final entry in values.entries)
        if (entry.value != null && '${entry.value}'.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 112, child: Text(entry.key, style: const TextStyle(color: AppColors.muted))),
              Expanded(child: Text('${entry.value}')),
            ]),
          ),
    ]),
  );
}

class _WarehouseError extends StatelessWidget {
  final Object error;
  final Future<void> Function() onRetry;
  const _WarehouseError({required this.error, required this.onRetry});
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