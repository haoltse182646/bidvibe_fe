import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models.dart';
import '../store.dart';
import 'api_client.dart';

// Authentication uses the BE. Other inherited features are still prototypes.
class RemoteAppStore extends AppStore {
  final api = ApiClient();
  final _storage = const FlutterSecureStorage();
  Future<void> _storageQueue = Future<void>.value();
  bool restoring = true;
  String? restoreError;
  String? sessionError;
  bool _disposed = false;

  RemoteAppStore({bool restoreOnStart = true}) {
    if (restoreOnStart) {
      unawaited(restoreSession());
    } else {
      restoring = false;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _persist(String? token) {
    final operation = _storageQueue.then(
      (_) => token == null
          ? _storage.delete(key: 'bidvibe.token')
          : _storage.write(key: 'bidvibe.token', value: token),
    );
    _storageQueue = operation.catchError((Object _) {});
    return operation;
  }

  UserAccount _user(Map<String, dynamic> data, String role) {
    if (![
          'bidder',
          'seller',
          'appraiser',
          'warehouse',
          'admin',
        ].contains(role) ||
        data['id'] == null ||
        data['fullName'] is! String) {
      throw const ApiException(
        'INVALID_RESPONSE',
        'Thông tin tài khoản không hợp lệ.',
      );
    }
    return UserAccount(
      id: '${data['id']}',
      name: data['fullName'] as String,
      email: '${data['email'] ?? ''}',
      phone: '${data['phone'] ?? ''}',
      role: role,
      shop: data['storeName'] as String?,
      password: '',
      status: '${data['status'] ?? 'active'}',
    );
  }

  Future<void> restoreSession() async {
    restoring = true;
    restoreError = null;
    _notify();
    try {
      await _storageQueue;
      api.token = await _storage.read(key: 'bidvibe.token');
      if (api.token != null) {
        final me = await api.request('/api/me');
        currentUser = _user(me, '${me['role']}');
      }
    } on ApiException catch (e) {
      if (e.code == 'UNAUTHORIZED' || e.code == 'ACCOUNT_SUSPENDED') {
        api.token = null;
        currentUser = null;
        await _persist(null);
        sessionError = e.message;
      } else {
        restoreError = e.message;
      }
    } catch (_) {
      restoreError = 'Không đọc được phiên đăng nhập. Vui lòng thử lại.';
    } finally {
      restoring = false;
      _notify();
    }
  }

  Future<void> authenticate(
    Map<String, dynamic> input, {
    bool register = false,
    bool ops = false,
  }) async {
    await _storageQueue;
    api.token = null;
    final data = await api.request(
      register
          ? '/api/auth/register'
          : ops
          ? '/api/auth/ops/login'
          : '/api/auth/login',
      body: input,
    );
    final token = data['token'];
    if (token is! String || token.isEmpty) {
      throw const ApiException(
        'INVALID_RESPONSE',
        'Máy chủ chưa trả token hợp lệ.',
      );
    }
    api.token = token;
    try {
      final me = await api.request('/api/me');
      final user = _user(me, '${me['role']}');
      await _persist(token);
      currentUser = user;
      sessionError = null;
      _notify();
    } catch (_) {
      api.token = null;
      rethrow;
    }
  }

  // Only accept the server's profile for the currently signed-in account.
  void applyProfile(Map<String, dynamic> data) {
    if (_disposed || currentUser == null) {
      return;
    }
    final next = _user(data, '${data['role']}');
    if (next.id != currentUser!.id || next.role != currentUser!.role) {
      throw const ApiException(
        'INVALID_RESPONSE',
        'Thông tin hồ sơ không khớp tài khoản đang đăng nhập.',
      );
    }
    currentUser = next;
    _notify();
  }

  @override
  void logout() {
    api.token = null;
    currentUser = null;
    sessionError = null;
    unawaited(
      _persist(null).catchError((Object _) {
        sessionError =
            'Chưa xóa được phiên đã lưu. Vui lòng thử đăng xuất lại.';
        _notify();
      }),
    );
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    api.close();
    super.dispose();
  }
}
