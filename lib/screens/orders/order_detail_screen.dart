import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../features/addresses/address_repository.dart';
import '../../features/orders/order_repository.dart';
import '../../features/wallet/wallet_repository.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/skeleton.dart';
import '../addresses/address_book_screen.dart';
import '../customer/customer_dispute.dart';
import 'order_labels.dart';

/// I01–I04 — chi tiết một đơn: tiền, địa chỉ giao, thanh toán, tiến trình
/// giao hàng và xác nhận nhận hàng. Mở bằng orderId; mọi trạng thái lấy lại từ BE.
class OrderDetailScreen extends StatefulWidget {
  final ApiClient api;
  final String orderId;
  final void Function(ApiException error)? onSessionExpired;
  const OrderDetailScreen({
    super.key,
    required this.api,
    required this.orderId,
    this.onSessionExpired,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late final OrderRepository _repo = OrderRepository(widget.api);
  late final AddressRepository _addresses = AddressRepository(widget.api);
  late final WalletRepository _wallet = WalletRepository(widget.api);
  Order? _order;
  int? _balance;
  bool _balanceFailed = false; // lỗi ví không được chặn cả màn đơn
  bool _deadlinePassed = false; // đồng hồ đã chạy hết hạn thanh toán
  String _method = 'qr';
  bool _loading = true, _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Trả về true nếu lỗi là hết phiên (đã báo cho màn cha, dừng xử lý tiếp).
  bool _expired(ApiException e) {
    if (!const {'UNAUTHORIZED', 'ACCOUNT_SUSPENDED'}.contains(e.code)) {
      return false;
    }
    widget.onSessionExpired?.call(e);
    return true;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order = await _repo.load(widget.orderId);
      int? balance;
      var balanceFailed = false;
      if (order.awaitingPayment) {
        // Số dư chỉ phục vụ lựa chọn "Ví": lỗi ở đây chỉ vô hiệu hoá lựa chọn đó.
        try {
          balance = (await _wallet.wallet()).available;
        } on ApiException catch (e) {
          if (_expired(e)) return;
          balanceFailed = true;
        }
      }
      if (!mounted) return;
      setState(() {
        _order = order;
        _balance = balance;
        _balanceFailed = balanceFailed;
        _deadlinePassed = false;
        if (balance != null && balance < order.amountToPay && _method == 'wallet') {
          _method = 'qr';
        }
      });
    } on ApiException catch (e) {
      if (!mounted || _expired(e)) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(text)));

  /// Chạy một thao tác ghi: khoá nút, báo lỗi bằng mã nghiệp vụ, rồi tải lại đơn.
  /// Không tự thử lại — lỗi mạng khi trả tiền chưa rõ kết quả nên phải tải lại để kiểm tra.
  Future<void> _run(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      _toast(success);
    } on ApiException catch (e) {
      if (!mounted || _expired(e)) return;
      _toast(_friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) await _load();
  }

  String _friendly(ApiException e) => switch (e.code) {
    'INSUFFICIENT_FUNDS' => 'Ví không đủ số dư. Hãy nạp thêm hoặc chọn phương thức khác.',
    'ALREADY_PAID' => 'Đơn này đã được thanh toán.',
    'PAYMENT_EXPIRED' => 'Đơn đã quá hạn thanh toán.',
    'ALREADY_SHIPPED' => 'Đơn đã được gửi đi, không thể đổi địa chỉ.',
    'NOT_DELIVERED' => 'Đơn chưa được giao, chưa thể xác nhận.',
    'ALREADY_CONFIRMED' => 'Bạn đã xác nhận nhận hàng rồi.',
    'DISPUTE_OPEN' => 'Đơn đang có tranh chấp, chưa thể xác nhận.',
    'NETWORK' || 'TIMEOUT' => '${e.message} Đơn sẽ được tải lại để kiểm tra kết quả.',
    _ => e.message,
  };

  Future<bool> _confirm(String title, String body, String ok) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Để sau')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
          ],
        ),
      ) ??
      false;

  Future<void> _chooseAddress(Order o) async {
    final selected = await Navigator.of(context).push<ShippingAddress>(
      MaterialPageRoute(
        builder: (_) => AddressBookScreen(
          repository: _addresses,
          selectionMode: true,
          selectedAddressId: o.shippingAddress?.id,
          onSessionExpired: widget.onSessionExpired,
        ),
      ),
    );
    if (selected == null || !mounted) return;
    // Chọn xong chưa phải đã gắn vào đơn: chỉ tin phản hồi của BE.
    await _run(() => _repo.setAddress(o.id, selected.id), 'Đã cập nhật địa chỉ giao hàng.');
  }

  Future<void> _pay(Order o) async {
    if (o.shippingAddress == null) {
      _toast('Hãy chọn địa chỉ nhận hàng trước khi thanh toán.');
      return;
    }
    final ok = await _confirm(
      'Xác nhận thanh toán',
      'Thanh toán ${orderMoney(o.amountToPay)} cho đơn này?',
      'Thanh toán',
    );
    if (!ok || !mounted) return;
    await _run(() => _repo.pay(o.id, _method), 'Thanh toán thành công.');
  }

  Future<void> _dispute(Order o) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerDisputeScreen(source: 'bidder', title: o.title, auctionId: o.auctionId),
      ),
    );
    if (mounted) await _load(); // tranh chấp đổi trạng thái giải ngân của đơn
  }

  Future<void> _confirmDelivery(Order o) async {
    final ok = await _confirm(
      'Xác nhận đã nhận hàng',
      'Tiền sẽ được chuyển cho người bán và bạn không thể mở tranh chấp sau bước này. Chỉ xác nhận khi hàng đúng mô tả.',
      'Đã nhận hàng',
    );
    if (!ok || !mounted) return;
    await _run(() => _repo.confirmDelivery(o.id), 'Đã xác nhận nhận hàng.');
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          'Đơn hàng #${widget.orderId}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      body: o == null
          ? _loading
                ? const SkeletonOrderDetail()
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error ?? 'Không tải được đơn.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.dangerFg),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(onPressed: _load, child: const Text('Thử lại')),
                        ],
                      ),
                    ),
                  )
          : RefreshIndicator(onRefresh: _load, child: _content(o)),
      bottomNavigationBar: o == null ? null : _action(o),
    );
  }

  bool _pastDeadline(Order o) =>
      _deadlinePassed || (o.paymentDeadline != null && !DateTime.now().isBefore(o.paymentDeadline!));

  Widget? _action(Order o) {
    if (o.awaitingPayment) {
      final late = _pastDeadline(o);
      return _bar(
        BigActionButton(
          label: late ? 'Đã quá hạn thanh toán' : (_busy ? 'Đang xử lý…' : 'Thanh toán ${orderMoney(o.amountToPay)}'),
          onPressed: _busy || late ? null : () => _pay(o),
        ),
      );
    }
    if (o.canConfirmDelivery) {
      return _bar(
        BigActionButton(
          label: _busy ? 'Đang xử lý…' : 'Đã nhận hàng',
          onPressed: _busy ? null : () => _confirmDelivery(o),
        ),
      );
    }
    return null;
  }

  Widget _bar(Widget child) => SafeArea(
    child: Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 14), child: child),
  );

  Widget _card(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );

  Widget _title(String text) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
  );

  Widget _row(String k, String v, {Color? color, bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
        Text(
          v,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    ),
  );

  Widget _content(Order o) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _card(
          Row(
            children: [
              OrderCover(o.coverUrl, size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.35),
                    ),
                    if (o.sellerName != null) ...[
                      const SizedBox(height: 2),
                      Text(o.sellerName!, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ],
                    const SizedBox(height: 6),
                    OrderStatusPill(o),
                  ],
                ),
              ),
            ],
          ),
        ),
        _title('Chi tiết thanh toán'),
        _card(
          Column(
            children: [
              _row('Giá thắng', orderMoney(o.finalPrice)),
              _row('Phí dịch vụ (5%)', orderMoney(o.fee)),
              _row('Vận chuyển từ kho', orderMoney(o.shippingFee)),
              _row('Cọc đã đặt', '−${orderMoney(o.depositApplied)}', color: AppColors.successStrong),
              const Divider(height: 24),
              _row(
                o.paid ? 'Đã thanh toán' : 'Cần thanh toán',
                orderMoney(o.amountToPay),
                bold: true,
              ),
              if (o.awaitingPayment && o.paymentDeadline != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('Còn lại để thanh toán: ', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                        LiveCountdown(
                          deadline: o.paymentDeadline!,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.pendingFg),
                          onExpired: () => setState(() => _deadlinePassed = true),
                        ),
                      ],
                    ),
                  ),
                ),
              if (o.disputed)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Đơn đang có tranh chấp. Ký quỹ được giữ lại cho tới khi Admin phán quyết.',
                      style: TextStyle(fontSize: 12, color: AppColors.dangerStrong, height: 1.4),
                    ),
                  ),
                ),
              if (o.expired || (o.awaitingPayment && _pastDeadline(o)))
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Đã quá hạn thanh toán — giao dịch bị huỷ.',
                      style: TextStyle(fontSize: 12, color: AppColors.dangerStrong),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _title('Giao đến'),
        _addressCard(o),
        // Đổi giai đoạn (chờ thanh toán → đã trả → theo dõi) chuyển nội dung nhẹ thay vì nhảy đột ngột.
        AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 200),
          child: Column(
            key: ValueKey(o.awaitingPayment ? 'pay' : (o.expired ? 'expired' : 'track')),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            if (o.awaitingPayment) ...[
              _title('Phương thức'),
              _payTile('qr', 'VietQR', 'Quét mã từ ứng dụng ngân hàng', true),
              const SizedBox(height: 8),
              _payTile('card', 'Thẻ nội địa', 'Thanh toán qua cổng ngân hàng', true),
              const SizedBox(height: 8),
              _payTile(
                'wallet',
                'Ví BidVibe',
                _balanceFailed
                    ? 'Không tải được số dư. Kéo xuống để thử lại.'
                    : _balance == null
                    ? 'Đang tải số dư…'
                    : _balance! >= o.amountToPay
                    ? 'Số dư khả dụng ${orderMoney(_balance!)}'
                    : 'Số dư ${orderMoney(_balance!)} — không đủ, hãy nạp thêm',
                _balance != null && _balance! >= o.amountToPay,
              ),
            ],
            if (!o.expired && !o.awaitingPayment) ...[_title('Theo dõi đơn'), _tracking(o)],
            ],
          ),
        ),
        if (o.canDispute) ...[
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _busy ? null : () => _dispute(o),
              child: const Text(
                'Hàng có vấn đề? Mở tranh chấp',
                style: TextStyle(fontSize: 13, color: AppColors.dangerStrong, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _addressCard(Order o) {
    final a = o.shippingAddress;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: o.canChangeAddress && !_busy ? () => _chooseAddress(o) : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: a == null && !o.expired ? AppColors.dangerStrong : AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: a == null
                    ? const Text(
                        'Chưa có địa chỉ nhận hàng. Kho không gửi được đơn nếu thiếu địa chỉ.',
                        style: TextStyle(fontSize: 14, color: AppColors.dangerFg, height: 1.4),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${a.recipientName} · ${a.phone}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(a.fullAddress, style: const TextStyle(fontSize: 14, height: 1.4)),
                        ],
                      ),
              ),
              if (o.canChangeAddress) ...[
                const SizedBox(width: 8),
                Text(
                  a == null ? 'Chọn' : 'Đổi',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.accent),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _payTile(String value, String title, String sub, bool enabled) {
    final selected = _method == value;
    return Opacity(
      opacity: enabled ? 1 : 0.75,
      child: Material(
        color: selected ? const Color(0xFFF1F3F8) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? () => setState(() => _method = value) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? AppColors.accent : AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? AppColors.accent : const Color(0xFF9AA0A9),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      Text(
                        sub,
                        style: TextStyle(fontSize: 12, color: enabled ? AppColors.muted : AppColors.dangerFg),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tracking(Order o) {
    final failed = o.stage == 'inspection_failed';
    final current = orderStages.indexOf(o.stage ?? '');
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (failed)
            const Text(
              'Kho phát hiện hàng không khớp mô tả. Đơn tạm dừng cho tới khi quản trị viên xử lý.',
              style: TextStyle(fontSize: 13, color: AppColors.dangerFg, height: 1.4),
            )
          else
            for (var i = 1; i < orderStages.length; i++)
              _step(
                stageLabel(orderStages[i]),
                done: i < current,
                active: i == current,
              ),
          if (o.warehouseCode != null) ...[
            const Divider(height: 24),
            _row('Mã kho', o.warehouseCode!),
          ],
          if (o.trackingCode != null) _row('Mã vận đơn', o.trackingCode!),
          if (o.events.isNotEmpty) ...[
            const Divider(height: 24),
            for (final e in o.events)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  '${orderTime(e.at)} · ${eventLabel(e.step)}${e.note == null || e.note!.isEmpty ? '' : ' — ${e.note}'}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _step(String label, {required bool done, required bool active}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(
          done
              ? Icons.check_circle
              : active
              ? Icons.radio_button_checked
              : Icons.radio_button_off,
          size: 20,
          color: done
              ? AppColors.successStrong
              : active
              ? AppColors.accent
              : const Color(0xFF9AA0A9),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: done || active ? AppColors.ink : AppColors.muted,
            ),
          ),
        ),
      ],
    ),
  );
}
