import 'auction_report_screen.dart';
import 'auction_bid_panel.dart';
import '../../features/auctions/auction_events.dart';
import '../../features/auctions/auction_live_controller.dart';
import 'auction_join_panel.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/remote_app_store.dart';
import '../../core/api_client.dart';
import '../../theme.dart';
import '../../features/orders/order_repository.dart';
import '../orders/order_detail_screen.dart';
import '../../features/auctions/auction_repository.dart';
import '../../store.dart';

class AuctionDetailScreen extends StatefulWidget {
  final String auctionId;
  final AuctionRepository repository;
  final AuctionEvents? events;
  final Listenable? refreshSignal;
  final Future<void> Function(String)? onOpenOrder;
  const AuctionDetailScreen({
    super.key,
    required this.auctionId,
    required this.repository,
    this.events,
    this.refreshSignal,
    this.onOpenOrder,
  });
  @override
  State<AuctionDetailScreen> createState() => _AuctionDetailScreenState();
}

class _AuctionDetailScreenState extends State<AuctionDetailScreen>
    with WidgetsBindingObserver {
  late final AuctionLiveController _live;
  bool _loggingOut = false;
  bool _reported = false;
  bool _openingOrder = false;
  String? _orderError;
  late final String? _token;
  late final String _baseUrl;
  bool get _active =>
      mounted &&
      widget.repository.api.token == _token &&
      ApiClient.baseUrl == _baseUrl;
  Map<String, dynamic>? get _data => _live.data;
  bool get _loading => _live.loading;
  String? get _error => _live.error;

  @override
  void initState() {
    super.initState();
    final token = widget.repository.api.token;
    _token = token;
    _baseUrl = ApiClient.baseUrl;
    _live = AuctionLiveController(
      auctionId: widget.auctionId,
      repository: widget.repository,
      events: widget.events ??
          (token == null
              ? null
              : SocketAuctionEvents(auctionId: widget.auctionId, token: token)),
    );
    _live.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    _live.start();
  }

  void _changed() {
    if (!mounted) {
      return;
    }
    if (_live.authCode != null && !_loggingOut) {
      _loggingOut = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final store = context.read<AppStore>();
        store.logout();
        if (store is RemoteAppStore) {
          store.sessionError = _live.authCode == 'ACCOUNT_SUSPENDED'
              ? 'Tài khoản đã bị tạm khóa.'
              : 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
        }
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _live.resume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _live.removeListener(_changed);
    _live.dispose();
    super.dispose();
  }

  Future<bool> _load() => _live.refresh();

  Future<void> _wonOrder() async {
    if (!_active ||
        _openingOrder ||
        _loading ||
        _error != null ||
        _live.dirty ||
        _data?['won'] != true) {
      return;
    }
    setState(() {
      _openingOrder = true;
      _orderError = null;
    });
    try {
      final orders = await OrderRepository(widget.repository.api).mine();
      if (!mounted || !_active) return;
      Order? won;
      for (final order in orders) {
        if (order.auctionId == widget.auctionId) {
          won = order;
          break;
        }
      }
      if (won == null) {
        setState(() => _orderError =
            'Đơn thắng đang được cập nhật. Vui lòng thử lại sau ít giây.');
        return;
      }
      if (widget.onOpenOrder != null) {
        await widget.onOpenOrder!(won.id);
      } else {
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => OrderDetailScreen(
            api: widget.repository.api,
            orderId: won!.id,
            refreshSignal: widget.refreshSignal,
            onSessionExpired: _orderSessionExpired,
          ),
        ));
      }
      if (_active) await _live.refresh();
    } catch (e) {
      if (!_active) return;
      setState(() => _orderError = e is ApiException
          ? e.message
          : 'Không tải được đơn thắng. Vui lòng thử lại.');
      if (e is ApiException) _orderSessionExpired(e);
    } finally {
      if (mounted) setState(() => _openingOrder = false);
    }
  }

  void _orderSessionExpired(ApiException error) {
    if (!_active ||
        _loggingOut ||
        !const {'UNAUTHORIZED', 'ACCOUNT_SUSPENDED'}.contains(error.code)) {
      return;
    }
    _loggingOut = true;
    final store = context.read<AppStore>();
    store.logout();
    if (store is RemoteAppStore) store.sessionError = error.message;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _report() async {
    if (_data == null || _reported || _live.posting) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => AuctionReportScreen(
          auctionId: widget.auctionId,
          auctionTitle: _data!['title'] as String?,
          repository: widget.repository,
          onReported: () {
            if (mounted) {
              setState(() => _reported = true);
            }
          },
        ),
      ),
    );
  }

  String _money(dynamic value) =>
      '${NumberFormat.decimalPattern('vi_VN').format(value is num ? value : 0)} đ';
  String _time(dynamic value) {
    final date = DateTime.tryParse('$value');
    if (date == null) return 'Chưa có';
    return DateFormat('dd/MM/yyyy HH:mm:ss').format(date.toLocal());
  }

  Widget _row(String name, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(name)),
            const SizedBox(width: 16),
            Expanded(child: Text(value, textAlign: TextAlign.end)),
          ],
        ),
      );

  Widget _section(String title, List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Phiên #${widget.auctionId}'),
        actions: [
          IconButton(
            tooltip: _reported ? 'Đã báo cáo phiên này' : 'Báo cáo phiên',
            onPressed:
                _data == null || _reported || _live.posting ? null : _report,
            icon: const Icon(Icons.flag_outlined),
          ),
          IconButton(
            tooltip: 'Làm mới phiên',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(
                onPressed: _loading ? null : _load,
                child: const Text('Thử lại'),
              ),
              if (_data != null)
                const Text('Dữ liệu bên dưới là lần tải thành công trước.'),
            ],
            if (_data != null) ..._content(_data!),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(Map<String, dynamic> data) {
    final seller = data['seller'] as Map? ?? {};
    final photos = (data['photos'] as List? ?? [])
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList()
      ..sort(
        (a, b) => ((a['orderIndex'] as num?) ?? 0).compareTo(
          (b['orderIndex'] as num?) ?? 0,
        ),
      );
    if (photos.isEmpty && data['coverUrl'] is String) {
      photos.add({'url': data['coverUrl']});
    }
    final bids = data['bids'] as List? ?? [];
    final paused = data['paused'] == true;
    final remaining = _live.remainingSeconds;
    final ended = data['status'] == 'ended';
    final cancelled =
        data['terminated'] == true || data['status'] == 'cancelled';
    final state = cancelled
        ? 'Đã hủy'
        : ended
            ? 'Đã kết thúc'
            : paused
                ? 'Tạm dừng'
                : data['isLive'] == true
                    ? 'Đang diễn ra'
                    : 'Chưa nhận lượt giá / chờ máy chủ cập nhật';
    return [
      Text(
        '${data['title'] ?? ''}',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      Chip(label: Text(state)),
      if (photos.isNotEmpty)
        SizedBox(
          height: 240,
          child: PageView(
            key: ValueKey(photos.map((p) => p['url']).join('|')),
            children: [
              for (final photo in photos)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Image.network(
                    '${photo['url']}',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Center(child: Text('Không tải được ảnh')),
                  ),
                ),
            ],
          ),
        )
      else
        const SizedBox(height: 100, child: Center(child: Text('Chưa có ảnh'))),
      if (photos.length > 1)
        Text(
          'Vuốt ngang để xem ${photos.length} ảnh',
          textAlign: TextAlign.center,
        ),
      _section('Thông tin sản phẩm', [
        Text('${data['description'] ?? 'Chưa có mô tả'}'),
        _row('Tình trạng', '${data['condition'] ?? 'Chưa có'}'),
        _row('Danh mục', categoryLabelOrRaw('${data['category'] ?? ''}')),
        _row('Mã phiên', '${data['id']}'),
      ]),
      _section('Người bán', [
        _row(
          'Gian hàng',
          '${seller['name'] ?? seller['storeName'] ?? 'Chưa có'}',
        ),
        _row(
          'Đánh giá',
          seller['rating'] == null ? 'Chưa có' : '${seller['rating']} / 5',
        ),
      ]),
      _section('Giá và thời gian', [
        _row('Giá khởi điểm', _money(data['startPrice'])),
        _row('Giá hiện tại', _money(data['currentPrice'])),
        _row('Bước giá tối thiểu', _money(data['bidStep'])),
        if (!ended && !cancelled)
          _row('Giá đặt tiếp tối thiểu', _money(data['minNextBid'])),
        _row('Tổng lượt đặt giá', '${data['bidCount'] ?? 0}'),
        _row('Bắt đầu', _time(data['startsAt'])),
        _row('Kết thúc', _time(data['endsAt'])),
        if (!ended && !cancelled)
          _row(
            paused ? 'Còn lại khi tạm dừng' : 'Thời gian còn lại',
            Duration(seconds: remaining < 0 ? 0 : remaining)
                .toString()
                .split('.')
                .first,
          ),
        Text(
          _live.events == null
              ? 'Chưa mở kết nối thời gian thực.'
              : _live.connected
                  ? 'Đang kết nối thời gian thực.'
                  : 'Mất kết nối thời gian thực, đang thử kết nối lại.',
        ),
      ]),
      _section('Tham gia và tiền cọc', [
        _row('Cọc yêu cầu', _money(data['depositRequired'])),
        _row('Đã tham gia', data['joined'] == true ? 'Có' : 'Chưa'),
        if (data['joined'] == true) ...[
          _row('Tiền cọc của bạn', _money(data['myDeposit'])),
          _row('Trạng thái cọc', '${data['myDepositStatus'] ?? 'Chưa có'}'),
        ],
        if (!ended &&
            !cancelled &&
            data['joined'] != true &&
            data['depositAffordable'] != null)
          _row(
            'Ví đủ cọc',
            data['depositAffordable'] == true ? 'Đủ' : 'Chưa đủ',
          ),
        if (!ended && !cancelled && data['leading'] == true)
          const Text('Bạn đang dẫn đầu'),
        if (ended && data['won'] == true) ...[
          const Text('Bạn đã thắng phiên này'),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed:
                _openingOrder || _loading || _error != null || _live.dirty
                    ? null
                    : _wonOrder,
            icon: const Icon(Icons.receipt_long_outlined),
            label: Text(_openingOrder ? 'Đang mở đơn…' : 'Xem đơn thắng'),
          ),
          if (_orderError != null)
            Text(_orderError!, style: const TextStyle(color: Colors.red)),
        ],
        if (ended && data['winnerId'] == null)
          const Text('Phiên kết thúc không có người thắng'),
      ]),
      AuctionJoinPanel(
        key: ValueKey('join-${widget.auctionId}'),
        auction: data,
        repository: widget.repository,
        onRefresh: _load,
        refreshing: _loading,
        stale: _error != null || _live.dirty || _live.posting,
      ),
      AuctionBidPanel(controller: _live),
      _section('20 lượt đặt giá gần nhất', [
        if (bids.isEmpty) const Text('Chưa có lượt đặt giá'),
        for (final bid in bids)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${bid['who']}${bid['me'] == true ? ' (Bạn)' : ''}'),
            subtitle: Text(_time(bid['at'])),
            trailing: Text(_money(bid['amount'])),
          ),
      ]),
    ];
  }
}
