import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/api_client.dart';
import '../auctions/auction_events.dart';

// The server automatically joins user:{accountId} after authenticating.
class SessionNotificationEvents implements AuctionEvents {
  final String token;
  final _events = StreamController<AuctionEvent>.broadcast(sync: true);
  io.Socket? _socket;
  bool _closed = false;
  SessionNotificationEvents(this.token);
  @override
  Stream<AuctionEvent> get stream => _events.stream;
  void _emit(String name, [Map<String, dynamic> data = const {}]) {
    if (!_closed) {
      _events.add(AuctionEvent(name, data));
    }
  }

  @override
  void connect() {
    if (_closed) {
      return;
    }
    if (_socket != null) {
      if (!_socket!.connected) {
        _socket!.connect();
      }
      return;
    }
    final socket = io.io(ApiClient.baseUrl, {
      'transports': ['websocket'],
      'auth': {'token': token},
      'autoConnect': false,
      'forceNew': true,
      'multiplex': false,
      'reconnection': true,
    });
    _socket = socket;
    socket.onConnect((_) => _emit('connected'));
    socket.onDisconnect((_) => _emit('disconnected'));
    socket.onConnectError((error) {
      final text = error is Map ? '${error['message'] ?? error}' : '$error';
      final code = text.contains('ACCOUNT_SUSPENDED')
          ? 'ACCOUNT_SUSPENDED'
          : text.contains('UNAUTHORIZED')
          ? 'UNAUTHORIZED'
          : 'SOCKET_ERROR';
      _emit('error', {'code': code});
      if (code != 'SOCKET_ERROR') {
        socket.disconnect();
      }
    });
    socket.on('notification:new', (payload) {
      if (payload is Map) {
        _emit('notification:new', Map<String, dynamic>.from(payload));
      }
    });
    socket.on('account:disconnected', (_) {
      _emit('error', {'code': 'ACCOUNT_SUSPENDED'});
      socket.disconnect();
    });
    socket.connect();
  }

  @override
  void dispose() {
    if (_closed) {
      return;
    }
    _closed = true;
    _socket?.dispose();
    scheduleMicrotask(() => unawaited(_events.close()));
  }
}
