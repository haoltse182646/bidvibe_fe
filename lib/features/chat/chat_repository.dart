import '../../core/api_client.dart';

class ChatMessage {
  final String id, sender, content;
  final DateTime? createdAt;
  const ChatMessage({
    required this.id,
    required this.sender,
    required this.content,
    this.createdAt,
  });
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    if (!ChatRepository.validId('${json['id']}') ||
        !['user', 'bot'].contains(json['sender']) ||
        json['content'] is! String) {
      throw const ApiException(
        'INVALID_RESPONSE',
        'Tin nhắn trả về không hợp lệ.',
      );
    }
    return ChatMessage(
      id: '${json['id']}',
      sender: json['sender'] as String,
      content: json['content'] as String,
      createdAt: DateTime.tryParse('${json['createdAt']}'),
    );
  }
}

class ChatThread {
  final String sessionId;
  final List<ChatMessage> messages;
  const ChatThread(this.sessionId, this.messages);
  factory ChatThread.fromJson(Map<String, dynamic> json) {
    if (!ChatRepository.validId('${json['sessionId']}') ||
        json['messages'] is! List) {
      throw const ApiException(
        'INVALID_RESPONSE',
        'Hội thoại trả về không hợp lệ.',
      );
    }
    final messages = <ChatMessage>[];
    final seen = <String>{};
    for (final row in json['messages'] as List) {
      if (row is! Map) {
        throw const ApiException(
          'INVALID_RESPONSE',
          'Tin nhắn trả về không hợp lệ.',
        );
      }
      final message = ChatMessage.fromJson(Map<String, dynamic>.from(row));
      if (seen.add(message.id)) {
        messages.add(message);
      }
    }
    return ChatThread('${json['sessionId']}', List.unmodifiable(messages));
  }
}

class ChatRepository {
  final ApiClient api;
  const ChatRepository(this.api);
  static bool validId(String id) =>
      RegExp(r'^[0-9]{1,18}$').hasMatch(id) && BigInt.parse(id) > BigInt.zero;
  Future<ChatThread> send(String content, {String? sessionId}) async {
    final text = content.trim();
    if (text.isEmpty ||
        text.length > 2000 ||
        (sessionId != null && !validId(sessionId))) {
      throw const ApiException(
        'VALIDATION_ERROR',
        'Nhập câu hỏi từ 1 đến 2000 ký tự.',
      );
    }
    final thread = ChatThread.fromJson(
      await api.request(
        '/api/chat/messages',
        body: {'content': text, if (sessionId != null) 'sessionId': sessionId},
      ),
    );
    if ((sessionId != null && thread.sessionId != sessionId) ||
        thread.messages.length != 2 ||
        thread.messages[0].sender != 'user' ||
        thread.messages[0].content != text ||
        thread.messages[1].sender != 'bot') {
      throw const ApiException(
        'INVALID_RESPONSE',
        'Chưa xác nhận được kết quả gửi câu hỏi.',
      );
    }
    return thread;
  }

  Future<ChatThread> history(String sessionId) async {
    if (!validId(sessionId)) {
      throw const ApiException(
        'VALIDATION_ERROR',
        'Mã hội thoại không hợp lệ.',
      );
    }
    final thread = ChatThread.fromJson(
      await api.request('/api/chat/sessions/$sessionId/messages'),
    );
    if (thread.sessionId != sessionId) {
      throw const ApiException(
        'INVALID_RESPONSE',
        'Hội thoại trả về không khớp.',
      );
    }
    return thread;
  }
}
