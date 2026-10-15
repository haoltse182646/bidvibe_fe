import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import 'auction_repository.dart';
import 'auction_events.dart';

class AuctionLiveController extends ChangeNotifier {
  final String auctionId;
  final AuctionRepository repository;
  final AuctionEvents? events;
  final DateTime Function() now;
  final bool autoTick;
  Map<String, dynamic>? data;
  bool loading = true, posting = false, connected = false, dirty = true;
  bool uncertainBid = false;
  String? error, notice, authCode;
  Timer? _ticker;
  StreamSubscription<AuctionEvent>? _subscription;
  Future<bool>? _fetch;
  int _requested = 0, _seconds = 0;
  DateTime? _receivedAt, _lastEndCheck;
  bool _disposed = false, _started = false;

  AuctionLiveController({
    required this.auctionId,
    required this.repository,
    this.events,
    DateTime Function()? now,
    this.autoTick = true,
  }) : now = now ?? DateTime.now;

  int get remainingSeconds {
    if (data?['paused'] == true || _receivedAt == null) {
      return max(0, _seconds);
    }
    return max(0, _seconds - max(0, now().difference(_receivedAt!).inSeconds));
  }

  bool get canBid =>
      data != null &&
      !loading &&
      !posting &&
      !dirty &&
      error == null &&
      authCode == null &&
      !uncertainBid &&
      (events == null || connected) &&
      data!['joined'] == true &&
      data!['myDepositStatus'] == 'held' &&
      data!['isLive'] == true &&
      data!['paused'] != true &&
      data!['leading'] != true &&
      remainingSeconds > 0;

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
      if (autoTick) {
        _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
      }
    }
    return refresh();
  }

  void _anchor(Map<String, dynamic> next) {
    data = next;
    _seconds = (next['remainingSeconds'] as num?)?.toInt() ?? 0;
    _receivedAt = now();
  }

  Future<bool> refresh({bool verifyBid = false}) async {
    if (_disposed || authCode != null) {
      return false;
    }
    _requested++;
    final running = _fetch;
    if (running != null) {
      final result = await running;
      if (result && verifyBid) {
        uncertainBid = false;
        _notify();
      }
      return result;
    }
    final operation = _refreshLoop();
    _fetch = operation;
    try {
      final result = await operation;
      if (result && verifyBid) {
        uncertainBid = false;
        _notify();
      }
      return result;
    } finally {
      _fetch = null;
    }
  }

  Future<bool> _refreshLoop() async {
    loading = true;
    _notify();
    try {
      while (!_disposed && authCode == null) {
        final revision = _requested;
        try {
          final next = await repository.detail(auctionId);
          if (_disposed || authCode != null) {
            return false;
          }
          if (revision != _requested) {
            continue;
          }
          _anchor(next);
          dirty = false;
          error = null;
          return true;
        } catch (e) {
          if (_disposed || authCode != null) {
            return false;
          }
          if (revision != _requested) {
            continue;
          }
          if (e is ApiException &&
              ['UNAUTHORIZED', 'ACCOUNT_SUSPENDED'].contains(e.code)) {
            _expire(e.code);
          } else {
            error = e is ApiException
                ? e.code == 'NOT_FOUND'
                    ? 'Phiên này không còn tồn tại hoặc bạn không được phép xem.'
                    : e.message
                : 'Không tải được chi tiết phiên.';
            dirty = true;
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

  void _expire(String code) {
    authCode = code;
    connected = false;
    dirty = true;
    events?.dispose();
    _notify();
  }

  void _event(AuctionEvent event) {
    if (_disposed || authCode != null) {
      return;
    }
    final payload = event.data;
    switch (event.type) {
      case 'connected':
        connected = true;
        dirty = true;
        unawaited(refresh());
        break;
      case 'disconnected':
        connected = false;
        dirty = true;
        break;
      case 'error':
        final code = '${payload['code']}';
        if (['UNAUTHORIZED', 'ACCOUNT_SUSPENDED'].contains(code)) {
          _expire(code);
        } else {
          connected = false;
          dirty = true;
        }
        break;
      case 'auction:update':
        if ('${payload['auctionId']}' != auctionId) {
          return;
        }
        if (data != null) {
          final next = Map<String, dynamic>.from(data!);
          var seconds = remainingSeconds;
          final oldEnd = DateTime.tryParse('${data!['endsAt']}');
          final newEnd = DateTime.tryParse('${payload['endsAt']}');
          if (payload['remainingSeconds'] is num) {
            seconds = (payload['remainingSeconds'] as num).toInt();
          } else if (oldEnd != null && newEnd != null) {
            seconds += newEnd.difference(oldEnd).inSeconds;
          }
          for (final key in [
            'currentPrice',
            'bidCount',
            'endsAt',
            'paused',
            'pausedAt',
            'status',
          ]) {
            if (payload.containsKey(key)) {
              next[key] = payload[key];
            }
          }
          next['remainingSeconds'] = max(0, seconds);
          if (next['currentPrice'] is num && next['bidStep'] is num) {
            next['minNextBid'] =
                (next['currentPrice'] as num) + (next['bidStep'] as num);
          }
          if (next['paused'] == true) {
            next['isLive'] = false;
          }
          _anchor(next);
        }
        dirty = true;
        unawaited(refresh());
        break;
      case 'auction:ended':
        if ('${payload['auctionId']}' != auctionId) {
          return;
        }
        if (data != null) {
          _anchor({
            ...data!,
            'status': payload['cancelled'] == true ? 'cancelled' : 'ended',
            'isLive': false,
            'terminated': payload['cancelled'] == true,
            'remainingSeconds': 0,
          });
        }
        dirty = true;
        unawaited(refresh());
        break;
      case 'notification:new':
        notice = '${payload['title'] ?? 'Phiên vừa có cập nhật.'}';
        unawaited(refresh());
        break;
    }
    _notify();
  }

  void tick() {
    if (_disposed) {
      return;
    }
    if (data?['status'] == 'active' &&
        data?['paused'] != true &&
        remainingSeconds == 0 &&
        !loading &&
        (_lastEndCheck == null ||
            now().difference(_lastEndCheck!).inSeconds >= 5)) {
      _lastEndCheck = now();
      unawaited(refresh());
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

  Future<bool> bid(int amount) async {
    if (!canBid) {
      notice = 'Chưa thể đặt giá. Kiểm tra trạng thái phiên và kết nối.';
      _notify();
      return false;
    }
    final minimum = (data!['minNextBid'] as num?)?.toInt() ?? 0;
    if (amount < minimum) {
      notice = 'Giá tối thiểu hiện tại là $minimum VND.';
      _notify();
      return false;
    }
    posting = true;
    notice = null;
    _notify();
    try {
      final result = await repository.bid(auctionId, amount);
      if (_disposed) {
        return true;
      }
      notice = result['extended'] == true
          ? 'Đặt giá thành công. Thời gian đấu giá đã được gia hạn.'
          : 'Đặt giá thành công.';
      dirty = true;
      await refresh();
      return true;
    } on ApiException catch (e) {
      if (_disposed) {
        return false;
      }
      if (['UNAUTHORIZED', 'ACCOUNT_SUSPENDED'].contains(e.code)) {
        _expire(e.code);
        return false;
      }
      final rejected = [
        'BID_TOO_LOW',
        'ALREADY_LEADING',
        'DEPOSIT_REQUIRED',
        'AUCTION_ENDED',
        'AUCTION_PAUSED',
        'VALIDATION_ERROR',
        'FORBIDDEN',
        'NOT_FOUND',
      ].contains(e.code);
      uncertainBid = !rejected;
      notice = rejected ? e.message : 'Chưa xác định được lượt giá đã được nhận chưa. Bấm kiểm tra kết quả trước khi gửi lại.';
      dirty = true;
      await refresh();
      return false;
    } catch (_) {
      if (!_disposed) {
        uncertainBid = true;
        dirty = true;
        notice = 'Chưa xác định được kết quả. Kiểm tra lại trạng thái và lịch sử trước khi gửi lượt mới.';
      }
      return false;
    } finally {
      posting = false;
      _notify();
    }
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _ticker?.cancel();
    unawaited(_subscription?.cancel());
    events?.dispose();
    super.dispose();
  }
}
