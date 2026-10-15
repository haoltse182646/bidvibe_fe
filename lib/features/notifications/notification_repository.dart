import '../../core/api_client.dart';

class NotificationItem {
  final String id, type, title;
  final bool isRead;
  final DateTime? createdAt;
  final Map<String, dynamic>? data;
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    this.isRead = false,
    this.createdAt,
    this.data,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    if (json['id'] == null || json['title'] is! String) {
      throw const ApiException('INVALID_RESPONSE', 'Thông báo không hợp lệ.');
    }
    return NotificationItem(
      id: '${json['id']}',
      type: '${json['type'] ?? 'info'}',
      title: json['title'] as String,
      isRead: json['isRead'] == true,
      createdAt: DateTime.tryParse('${json['createdAt']}'),
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : null,
    );
  }

  NotificationItem read() => NotificationItem(
    id: id,
    type: type,
    title: title,
    isRead: true,
    createdAt: createdAt,
    data: data,
  );
}

class NotificationTarget {
  final String kind, id;
  const NotificationTarget(this.kind, this.id);
  static NotificationTarget? fromData(Map<String, dynamic>? data) {
    if (data == null) {
      return null;
    }
    for (final kind in ['dispute', 'order', 'listing', 'auction']) {
      final value = data['${kind}Id'];
      if (value != null && RegExp(r'^[0-9]{1,18}$').hasMatch('$value')) {
        return NotificationTarget(kind, '$value');
      }
    }
    return null;
  }
}

class NotificationPage {
  final List<NotificationItem> items;
  final int unreadCount;
  const NotificationPage(this.items, this.unreadCount);
}

class NotificationRepository {
  final ApiClient api;
  const NotificationRepository(this.api);
  Future<NotificationPage> list({int offset = 0}) async {
    final data = await api.request(
      '/api/notifications?limit=20&offset=$offset',
    );
    if (data['notifications'] is! List || data['unreadCount'] is! num) {
      throw const ApiException(
        'INVALID_RESPONSE',
        'Danh sách thông báo không hợp lệ.',
      );
    }
    return NotificationPage(
      (data['notifications'] as List)
          .map(
            (item) => NotificationItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      (data['unreadCount'] as num).toInt(),
    );
  }

  Future<void> markRead(String id) async {
    if (!RegExp(r'^[0-9]{1,18}$').hasMatch(id)) {
      throw const ApiException(
        'VALIDATION_ERROR',
        'Mã thông báo không hợp lệ.',
      );
    }
    await api.request('/api/notifications/$id/read', method: 'POST');
  }

  Future<int> markAllRead() async {
    final data = await api.request(
      '/api/notifications/read-all',
      method: 'POST',
    );
    return (data['updated'] as num).toInt();
  }
}
