import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import '../auctions/auction_events.dart';
import 'notification_repository.dart';

class NotificationController extends ChangeNotifier {
  final NotificationRepository repository;
  final AuctionEvents? events;
  List<NotificationItem> items = [];
  int unreadCount = 0;
  bool loading = true,
      loadingMore = false,
      mutating = false,
      hasMore = false,
      connected = false;
  String? error, pageError, authCode;
  NotificationItem? toast;
  StreamSubscription<AuctionEvent>? _subscription;
  Future<bool>? _fetch;
  int _revision = 0, _offset = 0;
  bool _disposed = false, _started = false;
  final _seenEvents = <String>{};
  NotificationController({required this.repository, this.events});

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<bool> start() {
    if (!_started) {
      _started = true;
      _subscription = events?.stream.listen(_event);
      events?.connect();
    }
    return refresh();
  }

  bool _expired(Object e) {
    if (e is ApiException &&
        ['UNAUTHORIZED', 'ACCOUNT_SUSPENDED'].contains(e.code)) {
      authCode = e.code;
      events?.dispose();
      connected = false;
      _notify();
      return true;
    }
    return false;
  }

  String _message(Object e) => e is ApiException
      ? e.message
      : 'Không tải được thông báo. Vui lòng thử lại.';

  Future<bool> refresh() async {
    if (_disposed || authCode != null) {
      return false;
    }
    _revision++;
    final current = _fetch;
    if (current != null) {
      return current;
    }
    final operation = _refreshLoop();
    _fetch = operation;
    try {
      return await operation;
    } finally {
      _fetch = null;
    }
  }

  Future<bool> _refreshLoop() async {
    loading = true;
    loadingMore = false;
    error = null;
    pageError = null;
    _notify();
    try {
      while (!_disposed && authCode == null) {
        final revision = _revision;
        try {
          final page = await repository.list();
          if (_disposed || authCode != null) {
            return false;
          }
          if (revision != _revision) {
            continue;
          }
          items = _unique(page.items);
          unreadCount = page.unreadCount;
          _offset = page.items.length;
          hasMore = page.items.length == 20;
          return true;
        } catch (e) {
          if (_disposed || authCode != null) {
            return false;
          }
          if (revision != _revision) {
            continue;
          }
          if (!_expired(e)) {
            error = _message(e);
          }
          return false;
        }
      }
      return false;
    } finally {
      loading = false;
      _notify();
    }
  }

  List<NotificationItem> _unique(List<NotificationItem> values) =>
      {for (final item in values) item.id: item}.values.toList();

  Future<void> more() async {
    if (_disposed ||
        loading ||
        loadingMore ||
        mutating ||
        !hasMore ||
        authCode != null) {
      return;
    }
    final revision = _revision;
    loadingMore = true;
    pageError = null;
    _notify();
    try {
      final page = await repository.list(offset: _offset);
      if (_disposed || revision != _revision || authCode != null) {
        return;
      }
      items = _unique([...items, ...page.items]);
      unreadCount = page.unreadCount;
      _offset += page.items.length;
      hasMore = page.items.length == 20;
    } catch (e) {
      if (!_disposed && revision == _revision && !_expired(e)) {
        pageError = _message(e);
      }
    } finally {
      if (revision == _revision) {
        loadingMore = false;
        _notify();
      }
    }
  }

  Future<bool> markRead(NotificationItem item) async {
    if (_disposed || mutating || authCode != null) {
      return false;
    }
    final matches = items.where((n) => n.id == item.id);
    final current = matches.isEmpty ? null : matches.first;
    if (current?.isRead == true || (current == null && item.isRead)) {
      return true;
    }
    mutating = true;
    error = null;
    _notify();
    try {
      await repository.markRead(item.id);
      if (_disposed) {
        return true;
      }
      items = items.map((n) => n.id == item.id ? n.read() : n).toList();
      unreadCount = max(0, unreadCount - 1);
      await refresh();
      return true;
    } catch (e) {
      if (!_disposed && !_expired(e)) {
        error = _message(e);
      }
      return false;
    } finally {
      mutating = false;
      _notify();
    }
  }

  Future<bool> markAllRead() async {
    if (_disposed || mutating || authCode != null) {
      return false;
    }
    mutating = true;
    error = null;
    _notify();
    try {
      final updated = await repository.markAllRead();
      if (_disposed) {
        return true;
      }
      items = items.map((n) => n.read()).toList();
      unreadCount = max(0, unreadCount - updated);
      await refresh();
      return true;
    } catch (e) {
      if (!_disposed && !_expired(e)) {
        error = _message(e);
      }
      return false;
    } finally {
      mutating = false;
      _notify();
    }
  }

  void _event(AuctionEvent event) {
    if (_disposed || authCode != null) {
      return;
    }
    switch (event.type) {
      case 'connected':
        connected = true;
        unawaited(refresh());
        break;
      case 'disconnected':
        connected = false;
        break;
      case 'error':
        final code = '${event.data['code']}';
        if (!_expired(ApiException(code, code))) {
          connected = false;
        }
        break;
      case 'notification:new':
        try {
          final item = NotificationItem.fromJson(event.data);
          if (_seenEvents.add(item.id)) {
            if (_seenEvents.length > 1000) {
              _seenEvents.remove(_seenEvents.first);
            }
            final known = items.any((n) => n.id == item.id);
            if (!known) {
              items = [item, ...items];
              if (!item.isRead) {
                unreadCount++;
              }
              toast = item;
            }
            unawaited(refresh());
          }
        } catch (_) {
          unawaited(refresh());
        }
        break;
    }
    _notify();
  }

  void resume() {
    if (_disposed || authCode != null) {
      return;
    }
    events?.connect();
    unawaited(refresh());
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    unawaited(_subscription?.cancel());
    events?.dispose();
    super.dispose();
  }
}
