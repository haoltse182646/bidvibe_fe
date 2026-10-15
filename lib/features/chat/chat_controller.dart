import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/api_client.dart';
import 'chat_repository.dart';

abstract class ChatSessionStore {
  Future<String?> read(String scope);
  Future<void> write(String scope, String? sessionId);
}

class SecureChatSessionStore implements ChatSessionStore {
  static Future<void> _queue = Future<void>.value();
  final FlutterSecureStorage storage;
  const SecureChatSessionStore({this.storage = const FlutterSecureStorage()});
  @override
  Future<String?> read(String scope) async {
    await _queue;
    return storage.read(key: scope);
  }

  @override
  Future<void> write(String scope, String? sessionId) {
    final next = _queue.then(
      (_) => sessionId == null
          ? storage.delete(key: scope)
          : storage.write(key: scope, value: sessionId),
    );
    _queue = next.catchError((Object _) {});
    return next;
  }
}

class ChatController extends ChangeNotifier {
  final ChatRepository repository;
  final ChatSessionStore sessions;
  final String accountId;
  late final String scope;
  late final String? _token;
  late final String _baseUrl;
  String? sessionId, error, warning, authCode;
  List<ChatMessage> messages = [];
  bool loading = false,
      sending = false,
      ready = false,
      uncertain = false,
      historyChecked = false;
  bool _disposed = false;
  ChatController({
    required this.repository,
    required this.accountId,
    this.sessions = const SecureChatSessionStore(),
  }) {
    _token = repository.api.token;
    _baseUrl = ApiClient.baseUrl;
    scope = 'bidvibe.chat.${Uri.encodeComponent(_baseUrl)}.$accountId';
  }
  bool get _active =>
      !_disposed &&
      repository.api.token == _token &&
      ApiClient.baseUrl == _baseUrl;
  bool get canSend =>
      _active &&
      ready &&
      !loading &&
      !sending &&
      !uncertain &&
      authCode == null;
  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  bool _auth(Object e) {
    if (e is ApiException &&
        ['UNAUTHORIZED', 'ACCOUNT_SUSPENDED'].contains(e.code)) {
      authCode = e.code;
      ready = false;
      return true;
    }
    return false;
  }

  String _message(Object e) => e is ApiException
      ? e.message
      : 'Không tải được hội thoại. Vui lòng thử lại.';

  Future<void> load() async {
    if (!_active || loading || sending || authCode != null) {
      return;
    }
    loading = true;
    error = null;
    _notify();
    try {
      final stored = sessionId ?? await sessions.read(scope);
      if (!_active) {
        return;
      }
      if (stored == null || !ChatRepository.validId(stored)) {
        if (stored != null) {
          await sessions.write(scope, null);
        }
        if (!_active) {
          return;
        }
        sessionId = null;
        messages = [];
        ready = true;
      } else {
        sessionId = stored;
        final thread = await repository.history(stored);
        if (!_active) {
          return;
        }
        messages = thread.messages;
        ready = true;
        if (uncertain) {
          historyChecked = true;
        }
      }
    } catch (e) {
      if (!_active) {
        return;
      }
      if (_auth(e)) {
        return;
      }
      if (e is ApiException && e.code == 'NOT_FOUND') {
        try {
          await sessions.write(scope, null);
          if (!_active) {
            return;
          }
          sessionId = null;
          messages = [];
          uncertain = false;
          historyChecked = false;
          ready = true;
          warning = 'Hội thoại trước không còn khả dụng. Bạn có thể bắt đầu câu hỏi mới.';
        } catch (_) {
          ready = false;
          error = 'Không khôi phục được hội thoại. Hãy thử tải lại.';
        }
      } else {
        ready = false;
        error = _message(e);
      }
    } finally {
      if (!_disposed) {
        loading = false;
        _notify();
      }
    }
  }

  Future<bool> send(String content) async {
    if (!canSend) {
      return false;
    }
    final text = content.trim();
    if (text.isEmpty || text.length > 2000) {
      error = 'Nhập câu hỏi từ 1 đến 2000 ký tự.';
      _notify();
      return false;
    }
    sending = true;
    error = null;
    warning = null;
    _notify();
    try {
      final thread = await repository.send(text, sessionId: sessionId);
      if (!_active) {
        return false;
      }
      sessionId = thread.sessionId;
      final merged = <String, ChatMessage>{
        for (final message in messages) message.id: message,
      };
      for (final message in thread.messages) {
        merged[message.id] = message;
      }
      messages = merged.values.toList();
      ready = true;
      try {
        await sessions.write(scope, thread.sessionId);
      } catch (_) {
        if (_active) {
          warning = 'Tin nhắn đã gửi, nhưng chưa lưu được hội thoại trên thiết bị để mở lại lần sau.';
        }
      }
      return _active;
    } catch (e) {
      if (!_active) {
        return false;
      }
      if (_auth(e)) {
        return false;
      }
      final rejected =
          e is ApiException &&
          ['VALIDATION_ERROR', 'FORBIDDEN', 'NOT_FOUND'].contains(e.code);
      uncertain = !rejected;
      historyChecked = false;
      if (e is ApiException && ['FORBIDDEN', 'NOT_FOUND'].contains(e.code)) {
        ready = false;
      }
      error = rejected
          ? _message(e)
          : sessionId == null
          ? 'Chưa xác nhận được câu hỏi đã gửi hay chưa và chưa nhận được mã hội thoại. Không tự gửi lại. Bạn có thể bắt đầu hội thoại mới.'
          : 'Chưa xác nhận được câu hỏi đã gửi hay chưa. Hãy tải lại lịch sử và kiểm tra trước khi tiếp tục; không tự gửi lại câu hỏi.';
      return false;
    } finally {
      if (!_disposed) {
        sending = false;
        _notify();
      }
    }
  }

  void acknowledgeHistory() {
    if (!_active || sending || loading || !uncertain || !historyChecked) {
      return;
    }
    uncertain = false;
    historyChecked = false;
    error = null;
    _notify();
  }

  Future<bool> newConversation() async {
    if (!_active || loading || sending || authCode != null) {
      return false;
    }
    loading = true;
    _notify();
    try {
      await sessions.write(scope, null);
      if (!_active) {
        return false;
      }
      sessionId = null;
      messages = [];
      ready = true;
      uncertain = false;
      historyChecked = false;
      error = null;
      warning = 'Hội thoại mới sẽ được tạo khi bạn gửi câu hỏi đầu tiên.';
      return true;
    } catch (_) {
      if (_active) {
        error = 'Chưa bắt đầu được hội thoại mới. Vui lòng thử lại.';
      }
      return false;
    } finally {
      if (!_disposed) {
        loading = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
