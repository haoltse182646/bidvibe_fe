import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/api_client.dart';

class AuctionEvent {
  final String type;
  final Map<String, dynamic> data;
  const AuctionEvent(this.type, [this.data = const {}]);
}

abstract class AuctionEvents {
  Stream<AuctionEvent> get stream;
  void connect();
  void dispose();
}

class SocketAuctionEvents implements AuctionEvents {
  final String auctionId, token;
  final _events = StreamController<AuctionEvent>.broadcast(sync: true);
  io.Socket? _socket;
  bool _closed = false;
  SocketAuctionEvents({required this.auctionId, required this.token});
  @override
  Stream<AuctionEvent> get stream => _events.stream;

  void _emit(String type, [Map<String, dynamic> data = const {}]) {
    if (!_closed) {
      _events.add(AuctionEvent(type, data));
    }
  }

  @override
  void connect() {
    if (_closed) {
      return;
    }
    if (_socket != null) {
      if (_socket!.connected) {
        _socket!.emit('auction:join', auctionId);
      } else {
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
    socket.onConnect((_) {
      socket.emit('auction:join', auctionId);
      _emit('connected');
    });
    socket.onDisconnect((_) => _emit('disconnected'));
    socket.onConnectError((error) {
      final message = error is Map ? '${error['message'] ?? error}' : '$error';
      final code = message.contains('ACCOUNT_SUSPENDED')
          ? 'ACCOUNT_SUSPENDED'
          : message.contains('UNAUTHORIZED')
          ? 'UNAUTHORIZED'
          : 'SOCKET_ERROR';
      _emit('error', {'code': code});
      if (code != 'SOCKET_ERROR') {
        socket.disconnect();
      }
    });
    for (final name in ['auction:update', 'auction:ended']) {
      socket.on(name, (payload) {
        if (payload is Map && '${payload['auctionId']}' == auctionId) {
          _emit(name, Map<String, dynamic>.from(payload));
        }
      });
    }
    socket.on('notification:new', (payload) {
      if (payload is Map) {
        final data = payload['data'];
        if (data is Map && '${data['auctionId']}' == auctionId) {
          _emit('notification:new', Map<String, dynamic>.from(payload));
        }
      }
    });
    socket.on('account:disconnected', (payload) {
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
    if (_socket?.connected == true) {
      _socket!.emit('auction:leave', auctionId);
    }
    _socket?.dispose();
    scheduleMicrotask(() => unawaited(_events.close()));
  }
}
