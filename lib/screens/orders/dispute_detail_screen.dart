import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/deferred_refresh.dart';
import '../../features/disputes/dispute_repository.dart';
import '../../theme.dart';
import 'order_detail_screen.dart';
import 'order_labels.dart';

/// Chi tiết tranh chấp của bidder, lấy từ danh sách thuộc tài khoản hiện tại.
/// BE không có GET /api/disputes/:id dành cho người dùng.
class DisputeDetailScreen extends StatefulWidget {
  final ApiClient api;
  final String disputeId;
  final Listenable? refreshSignal;
  final void Function(ApiException)? onSessionExpired;
  final Future<void> Function(String)? onOpenOrder;
  const DisputeDetailScreen({
    super.key,
    required this.api,
    required this.disputeId,
    this.refreshSignal,
    this.onSessionExpired,
    this.onOpenOrder,
  });

  @override
  State<DisputeDetailScreen> createState() => _DisputeDetailScreenState();
}

class _DisputeDetailScreenState extends State<DisputeDetailScreen>
    with DeferredRefresh<DisputeDetailScreen>, WidgetsBindingObserver {
  late final String? _token;
  late final String _baseUrl;
  UserDispute? _dispute;
  bool _loading = false;
  String? _error;
  bool get _active =>
      mounted && widget.api.token == _token && ApiClient.baseUrl == _baseUrl;
  @override
  Listenable? get refreshSignal => widget.refreshSignal;
  @override
  bool get canRefresh => _active && !_loading;
  @override
  Future<void> refreshData() => _load();

  @override
  void initState() {
    super.initState();
    // Capture the session before starting the first asynchronous request.
    _token = widget.api.token;
    _baseUrl = ApiClient.baseUrl;
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) requestDataRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    if (!_active || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!DisputeRepository.validId(widget.disputeId)) {
        throw const ApiException(
            'VALIDATION_ERROR', 'Mã tranh chấp không hợp lệ.');
      }
      final items = await DisputeRepository(widget.api).mine();
      if (!_active) return;
      UserDispute? found;
      for (final item in items) {
        if (item.id == widget.disputeId) {
          found = item;
          break;
        }
      }
      setState(() {
        _dispute = found;
        if (found == null) {
          _error = 'Không tìm thấy tranh chấp hoặc bạn không có quyền xem.';
        }
      });
    } catch (e) {
      if (!_active) return;
      setState(() => _error = e is ApiException
          ? e.message
          : 'Không tải được tranh chấp. Vui lòng thử lại.');
      if (e is ApiException &&
          const {'UNAUTHORIZED', 'ACCOUNT_SUSPENDED'}.contains(e.code)) {
        widget.onSessionExpired?.call(e);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
      drainDataRefresh();
    }
  }

  Future<void> _openOrder() async {
    final dispute = _dispute;
    if (!_active || _loading || _error != null || dispute == null) return;
    if (widget.onOpenOrder != null) {
      await widget.onOpenOrder!(dispute.orderId);
    } else {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => OrderDetailScreen(
          api: widget.api,
          orderId: dispute.orderId,
          refreshSignal: widget.refreshSignal,
          onSessionExpired: widget.onSessionExpired,
        ),
      ));
    }
    if (_active) requestDataRefresh();
  }

  Widget _card(Widget child) => Card(
        elevation: 0,
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Padding(padding: const EdgeInsets.all(18), child: child),
      );

  static const _roleLabels = {
    'bidder': 'Người mua',
    'seller': 'Người bán',
    'warehouse': 'Kho',
  };

  Widget _photoThumb(DisputePhoto photo) {
    final label = _roleLabels[photo.uploaderRole] ?? 'Ảnh';
    return Semantics(
      button: true,
      label: 'Xem ảnh của $label',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => Dialog(
            child: InteractiveViewer(
              child: Image.network(
                photo.url,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Không tải được ảnh.'),
                ),
              ),
            ),
          ),
        ),
        child: Column(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              photo.url,
              width: 88,
              height: 88,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 88,
                height: 88,
                color: AppColors.neutralBg,
                child: const Icon(Icons.broken_image_outlined,
                    color: AppColors.muted),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _dispute;
    final resolution = switch (d?.resolution) {
      'refund' => 'Đã hoàn tiền cho người mua',
      'keep' => 'Giữ nguyên, giải ngân cho người bán',
      _ => d?.open == true ? 'Đang chờ xem xét' : 'Chưa có kết quả xử lý',
    };
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text('Tranh chấp #${widget.disputeId}')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ...[
              _card(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_error!,
                        style: const TextStyle(color: AppColors.dangerFg)),
                    if (d != null)
                      const Text('Thông tin bên dưới có thể chưa cập nhật.'),
                    TextButton(
                        onPressed: _loading ? null : _load,
                        child: const Text('Thử lại')),
                  ])),
            ],
            if (d != null) ...[
              _card(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.support_agent,
                        color: AppColors.accent, size: 32),
                    const SizedBox(height: 12),
                    Text(d.itemTitle,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(d.title),
                    const SizedBox(height: 12),
                    Chip(label: Text(d.open ? 'Đang xử lý' : 'Đã xử lý')),
                    Text(resolution,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Text('Ký quỹ liên quan: ${orderMoney(d.escrowAmount)}'),
                    Text('Đơn hàng #${d.orderId}',
                        style: const TextStyle(color: AppColors.muted)),
                  ])),
              _card(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tiến trình xử lý',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    if (d.timeline.isEmpty)
                      const Text('Chưa có cập nhật tiến trình.'),
                    for (final step in d.timeline)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.circle,
                                  size: 10, color: AppColors.accent),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(step.note),
                                    const SizedBox(height: 4),
                                    Text(orderTime(step.at),
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.muted)),
                                  ])),
                            ]),
                      ),
                  ])),
              if (d.photos.isNotEmpty)
                _card(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ảnh bằng chứng (${d.photos.length})',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final photo in d.photos)
                          _photoThumb(photo),
                      ]),
                    ])),
              FilledButton.icon(
                onPressed: _loading || _error != null ? null : _openOrder,
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Xem đơn liên quan'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
