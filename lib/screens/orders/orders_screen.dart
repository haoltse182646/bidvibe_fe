import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../features/orders/order_repository.dart';
import '../../theme.dart';
import '../../widgets/skeleton.dart';
import 'my_disputes_screen.dart';
import 'order_detail_screen.dart';
import 'order_labels.dart';

/// I01 — đơn thắng của người mua. Chạm một đơn để mở chi tiết theo orderId thật.
class OrdersScreen extends StatefulWidget {
  final ApiClient api;
  final Listenable? refreshSignal;
  final void Function(ApiException error)? onSessionExpired;
  const OrdersScreen(
      {super.key,
      required this.api,
      this.onSessionExpired,
      this.refreshSignal});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late final OrderRepository _repo = OrderRepository(widget.api);
  List<Order> _orders = [];
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
      final orders = await _repo.mine();
      if (!mounted) return;
      setState(() => _orders = orders);
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

  Future<void> _open(Order o) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailScreen(
          api: widget.api,
          orderId: o.id,
          refreshSignal: widget.refreshSignal,
          onSessionExpired: widget.onSessionExpired,
        ),
      ),
    );
    if (mounted) _load(); // quay về thì tải lại: đơn có thể đã đổi trạng thái
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text(
          'Đơn hàng của tôi',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MyDisputesScreen(
                  api: widget.api,
                  refreshSignal: widget.refreshSignal,
                  onSessionExpired: widget.onSessionExpired,
                ),
              ),
            ),
            child: const Text('Tranh chấp'),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    if (_loading && _orders.isEmpty) {
      return const SkeletonTileList();
    }
    if (_error != null && _orders.isEmpty) {
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
    if (_orders.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 80),
          Text(
            'Bạn chưa có đơn nào.\nĐơn được tạo khi bạn thắng một phiên đấu giá.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) =>
          _OrderTile(order: _orders[i], onTap: () => _open(_orders[i])),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;
  const _OrderTile({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              OrderCover(order.coverUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        OrderStatusPill(order),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            orderMoney(order.awaitingPayment
                                ? order.amountToPay
                                : order.finalPrice),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
