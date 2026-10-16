import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/remote_app_store.dart';
import '../../core/api_client.dart';
import '../../features/auctions/auction_repository.dart';
import '../../features/notifications/notification_controller.dart';
import '../../features/notifications/notification_events.dart';
import '../../features/notifications/notification_repository.dart';
import '../../store.dart';
import '../auth/auth_profile.dart';
import '../orders/order_detail_screen.dart';
import '../orders/dispute_detail_screen.dart';
import '../orders/orders_screen.dart';
import 'auction_detail_screen.dart';
import 'bidder_home.dart';
import 'bidder_wallet.dart';
import 'bidder_notifications.dart';

class BidderShell extends StatefulWidget {
  final NotificationController? notifications;
  // Optional override for an enclosing application/router.
  final Future<void> Function(NotificationTarget)? onOpenTarget;
  const BidderShell({super.key, this.notifications, this.onOpenTarget});
  @override
  State<BidderShell> createState() => _BidderShellState();
}

class _BidderShellState extends State<BidderShell> with WidgetsBindingObserver {
  late final NotificationController _notifications;
  late final bool _ownsController;
  int _tab = 0;
  bool _loggingOut = false;
  String? _lastToast;
  final _dataRefresh = ValueNotifier<int>(0);
  bool _refreshQueued = false, _wasConnected = false;
  late final String? _token;
  late final String _baseUrl;
  ScaffoldMessengerState? _messenger;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.notifications == null;
    if (widget.notifications != null) {
      _notifications = widget.notifications!;
    } else {
      final store = context.read<AppStore>();
      if (store is! RemoteAppStore || store.api.token == null) {
        throw StateError('BidderShell needs an authenticated RemoteAppStore.');
      }
      _notifications = NotificationController(
        repository: NotificationRepository(store.api),
        events: SessionNotificationEvents(store.api.token!),
      );
    }
    _token = _notifications.repository.api.token;
    _baseUrl = ApiClient.baseUrl;
    _notifications.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    _notifications.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
  }

  void _changed() {
    if (!mounted) {
      return;
    }
    if (_notifications.repository.api.token != _token ||
        ApiClient.baseUrl != _baseUrl) {
      return;
    }
    if (_notifications.connected && !_wasConnected) _queueDataRefresh();
    _wasConnected = _notifications.connected;
    if (_notifications.authCode != null && !_loggingOut) {
      _loggingOut = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            _notifications.repository.api.token != _token ||
            ApiClient.baseUrl != _baseUrl) {
          return;
        }
        final store = context.read<AppStore>();
        store.logout();
        if (store is RemoteAppStore) {
          store.sessionError = _notifications.authCode == 'ACCOUNT_SUSPENDED'
              ? 'Tài khoản đã bị tạm khóa.'
              : 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
        }
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
    final toast = _notifications.toast;
    if (toast != null && toast.id != _lastToast && !_loggingOut) {
      _lastToast = toast.id;
      _queueDataRefresh();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _loggingOut || _lastToast != toast.id) {
          return;
        }
        _messenger?.removeCurrentSnackBar();
        _messenger?.showSnackBar(
          SnackBar(
            content: Text(toast.title),
            action: SnackBarAction(label: 'Xem', onPressed: () => _open(toast)),
          ),
        );
      });
    }
    setState(() {});
  }

  void _queueDataRefresh() {
    if (_refreshQueued || !mounted || _loggingOut) return;
    _refreshQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshQueued = false;
      if (mounted &&
          !_loggingOut &&
          _notifications.repository.api.token == _token &&
          ApiClient.baseUrl == _baseUrl) {
        _dataRefresh.value++;
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _notifications.resume();
      _queueDataRefresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notifications.removeListener(_changed);
    _dataRefresh.dispose();
    if (_ownsController) {
      _notifications.dispose();
    }
    // ScaffoldMessenger may be unmounting alongside this shell.
    final messenger = _messenger;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (messenger?.mounted == true) messenger!.removeCurrentSnackBar();
    });
    super.dispose();
  }

  // Hết phiên ở màn con (đơn hàng): đăng xuất giống khi thông báo báo hết phiên.
  void _sessionExpired(ApiException error) {
    if (_loggingOut ||
        !mounted ||
        _notifications.repository.api.token != _token ||
        ApiClient.baseUrl != _baseUrl) {
      return;
    }
    _loggingOut = true;
    final store = context.read<AppStore>();
    store.logout();
    if (store is RemoteAppStore) {
      store.sessionError = error.code == 'ACCOUNT_SUSPENDED'
          ? 'Tài khoản đã bị tạm khóa.'
          : 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _orders() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrdersScreen(
          api: _notifications.repository.api,
          refreshSignal: _dataRefresh,
          onSessionExpired: _sessionExpired,
        ),
      ),
    );
    if (mounted) {
      _queueDataRefresh();
      await _notifications.refresh();
    }
  }

  Future<void> _order(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailScreen(
          api: _notifications.repository.api,
          orderId: id,
          refreshSignal: _dataRefresh,
          onSessionExpired: _sessionExpired,
        ),
      ),
    );
    if (mounted) {
      _queueDataRefresh();
      await _notifications.refresh();
    }
  }

  Future<void> _auction(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AuctionDetailScreen(
          auctionId: id,
          repository: AuctionRepository(_notifications.repository.api),
          refreshSignal: _dataRefresh,
          onOpenOrder: _order,
        ),
      ),
    );
    if (mounted) {
      _queueDataRefresh();
      await _notifications.refresh();
    }
  }

  Future<void> _dispute(String id) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => DisputeDetailScreen(
        api: _notifications.repository.api,
        disputeId: id,
        refreshSignal: _dataRefresh,
        onSessionExpired: _sessionExpired,
        onOpenOrder: _order,
      ),
    ));
    if (mounted) {
      _queueDataRefresh();
      await _notifications.refresh();
    }
  }

  Future<void> _open(NotificationItem item) async {
    if (!mounted || _loggingOut) return;
    final read = await _notifications.markRead(item);
    if (!mounted ||
        !read ||
        _notifications.authCode != null ||
        _notifications.repository.api.token != _token ||
        ApiClient.baseUrl != _baseUrl) {
      return;
    }
    final target = NotificationTarget.fromData(item.data);
    if (target == null) {
      return;
    }
    if (target.kind == 'auction') {
      await _auction(target.id);
      return;
    }
    if (target.kind == 'order' && widget.onOpenTarget == null) {
      await _order(target.id);
      return;
    }
    if (target.kind == 'dispute' && widget.onOpenTarget == null) {
      await _dispute(target.id);
      return;
    }
    final callback = widget.onOpenTarget;
    if (callback != null) {
      await callback(target);
      return;
    }
    final labels = {
      'dispute': 'Tranh chấp',
      'order': 'Đơn hàng',
      'listing': 'Tin đăng',
    };
    final auctionId = item.data?['auctionId'];
    final hasAuction =
        auctionId != null && RegExp(r'^[0-9]{1,18}$').hasMatch('$auctionId');
    final showAuction = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${labels[target.kind]} #${target.id}',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(item.title),
              const SizedBox(height: 16),
              if (hasAuction)
                FilledButton(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: const Text('Xem phiên đấu giá liên quan'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext, false),
                child: const Text('Đóng'),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted && showAuction == true) {
      await _auction('$auctionId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.unreadCount;
    final badge = unread > 99 ? '99+' : '$unread';
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          BidderHomeScreen(
              refreshSignal: _dataRefresh,
              onReturnFromAuction: _queueDataRefresh,
              onOpenOrder: _order),
          BidderWalletScreen(refreshSignal: _dataRefresh),
          BidderNotificationsScreen(controller: _notifications, onOpen: _open),
          AuthProfileScreen(
              onOrders: _orders,
              onOpenOrder: _order,
              refreshSignal: _dataRefresh),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) {
          setState(() => _tab = index);
          if (index == 1 || index == 3) _queueDataRefresh();
          if (index == 2) {
            _notifications.refresh();
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            label: 'Khám phá',
          ),
          const NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Ví',
          ),
          NavigationDestination(
            icon: Badge(
              label: Text(badge),
              isLabelVisible: unread > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            label: 'Thông báo',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Hồ sơ',
          ),
        ],
      ),
    );
  }
}
