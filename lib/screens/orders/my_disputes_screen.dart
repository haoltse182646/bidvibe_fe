import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../features/disputes/dispute_repository.dart';
import '../../theme.dart';
import '../../widgets/skeleton.dart';
import 'dispute_detail_screen.dart';
import 'order_labels.dart';

/// Tranh chấp trên các đơn của tôi (người mua hoặc người bán).
/// Chạm một dòng để mở tiến trình tranh chấp.
class MyDisputesScreen extends StatefulWidget {
  final ApiClient api;
  final Listenable? refreshSignal;
  final void Function(ApiException error)? onSessionExpired;
  const MyDisputesScreen(
      {super.key,
      required this.api,
      this.onSessionExpired,
      this.refreshSignal});

  @override
  State<MyDisputesScreen> createState() => _MyDisputesScreenState();
}

class _MyDisputesScreenState extends State<MyDisputesScreen> {
  late final DisputeRepository _repo = DisputeRepository(widget.api);
  List<UserDispute> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.mine();
      if (!mounted) return;
      setState(() => _items = items);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (const {'UNAUTHORIZED', 'ACCOUNT_SUSPENDED'}.contains(e.code)) {
        widget.onSessionExpired?.call(e);
        return;
      }
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _resolution(UserDispute d) => switch (d.resolution) {
        'refund' => 'Đã hoàn tiền cho người mua',
        'keep' => 'Giữ nguyên, giải ngân cho người bán',
        _ => 'Admin đang xem xét',
      };

  String _source(String s) => switch (s) {
        'bidder' => 'Người mua mở',
        'seller' => 'Người bán mở',
        'warehouse' => 'Kho mở (kiểm không khớp)',
        _ => s,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text(
          'Tranh chấp của tôi',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      body: RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    if (_loading && _items.isEmpty) {
      return const SkeletonTileList(count: 3);
    }
    if (_error != null && _items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 60),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.dangerFg),
          ),
          const SizedBox(height: 12),
          Center(
            child:
                OutlinedButton(onPressed: _load, child: const Text('Thử lại')),
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 80),
          Text(
            'Bạn chưa có tranh chấp nào.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _tile(_items[i]),
    );
  }

  Widget _tile(UserDispute d) {
    final open = d.open;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DisputeDetailScreen(
                api: widget.api,
                disputeId: d.id,
                refreshSignal: widget.refreshSignal,
                onSessionExpired: widget.onSessionExpired,
              ),
            ),
          );
          if (mounted) _load();
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: open ? AppColors.pendingBg : AppColors.successBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      open ? 'Đang mở' : 'Đã xử lý',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: open ? AppColors.pendingFg : AppColors.successFg,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _source(d.source),
                      style:
                          const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                d.itemTitle,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, height: 1.3),
              ),
              const SizedBox(height: 4),
              Text(
                _resolution(d),
                style:
                    const TextStyle(fontSize: 13, color: AppColors.mutedStrong),
              ),
              const SizedBox(height: 4),
              Text(
                'Ký quỹ ${orderMoney(d.escrowAmount)} · ${orderTime(d.createdAt)}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
