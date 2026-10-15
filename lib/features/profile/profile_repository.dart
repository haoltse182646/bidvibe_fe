import 'dart:typed_data';

import '../../core/api_client.dart';

class ProfileSnapshot {
  final Map<String, dynamic> data;
  ProfileSnapshot._(this.data);
  factory ProfileSnapshot.fromJson(Map<String, dynamic> json) {
    if (json['id'] == null ||
        json['fullName'] is! String ||
        (json['fullName'] as String).trim().isEmpty ||
        json['email'] is! String ||
        ![
          'bidder',
          'seller',
          'admin',
          'appraiser',
          'warehouse',
        ].contains(json['role'])) {
      throw const ApiException(
        'INVALID_RESPONSE',
        'Thông tin hồ sơ không hợp lệ.',
      );
    }
    return ProfileSnapshot._(Map<String, dynamic>.unmodifiable(json));
  }
  String get id => '${data['id']}';
  String get fullName => data['fullName'] as String;
  String get email => data['email'] as String;
  String get role => data['role'] as String;
  String? get phone => data['phone'] is String ? data['phone'] as String : null;
  String? get avatarUrl =>
      data['avatarUrl'] is String ? data['avatarUrl'] as String : null;
  String? get storeName =>
      data['storeName'] is String ? data['storeName'] as String : null;
}

class ProfileRepository {
  final ApiClient api;
  const ProfileRepository(this.api);

  Future<List<Map<String, dynamic>>> addresses() async =>
      _rows(await api.request('/api/addresses'), 'addresses');
  Future<List<Map<String, dynamic>>> orders() async =>
      _rows(await api.request('/api/orders/mine'), 'orders');
  List<Map<String, dynamic>> _rows(Map<String, dynamic> data, String key) {
    final rows = data[key];
    if (rows is! List || rows.any((row) => row is! Map)) {
      throw const ApiException(
        'INVALID_RESPONSE',
        'Danh sách trả về không hợp lệ.',
      );
    }
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  static String? nameError(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty || text.length > 100
        ? 'Nhập từ 1 đến 100 ký tự.'
        : null;
  }

  static String? phoneError(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final digits = text.replaceAll(RegExp(r'\D'), '');
    return text.length > 20 ||
            !RegExp(r'^\+?[0-9\s.()-]{8,20}$').hasMatch(text) ||
            digits.length < 9 ||
            digits.length > 15
        ? 'Số điện thoại cần từ 9 đến 15 chữ số.'
        : null;
  }

  static bool validUrl(String value) {
    final uri = Uri.tryParse(value);
    return value.length <= 2000 &&
        uri != null &&
        ['http', 'https'].contains(uri.scheme) &&
        uri.host.isNotEmpty;
  }

  Future<ProfileSnapshot> fetch() async =>
      ProfileSnapshot.fromJson(await api.request('/api/me'));

  Future<ProfileSnapshot> update(Map<String, dynamic> changes) async {
    if (changes.isEmpty ||
        changes.keys.any(
          (key) =>
              !['fullName', 'phone', 'avatarUrl', 'shopName'].contains(key),
        )) {
      throw const ApiException(
        'VALIDATION_ERROR',
        'Không có trường hồ sơ hợp lệ để cập nhật.',
      );
    }
    final body = Map<String, dynamic>.from(changes);
    for (final key in ['fullName', 'shopName']) {
      if (body.containsKey(key)) {
        if (body[key] is! String || nameError(body[key] as String) != null) {
          throw const ApiException(
            'VALIDATION_ERROR',
            'Họ tên và tên gian hàng phải từ 1 đến 100 ký tự.',
          );
        }
        body[key] = (body[key] as String).trim();
      }
    }
    if (body.containsKey('phone')) {
      final value = body['phone'];
      if (value != null && (value is! String || phoneError(value) != null)) {
        throw const ApiException(
          'VALIDATION_ERROR',
          'Số điện thoại không hợp lệ.',
        );
      }
      body['phone'] = value == null || (value as String).trim().isEmpty
          ? null
          : value.trim();
    }
    if (body.containsKey('avatarUrl')) {
      final value = body['avatarUrl'];
      if (value != null && (value is! String || !validUrl(value))) {
        throw const ApiException(
          'VALIDATION_ERROR',
          'Ảnh đại diện không hợp lệ.',
        );
      }
    }
    return ProfileSnapshot.fromJson(
      await api.request('/api/me', method: 'PATCH', body: body),
    );
  }

  Future<void> changePassword(String current, String next) async {
    if (current.isEmpty || next.length < 6 || next.length > 72) {
      throw const ApiException(
        'VALIDATION_ERROR',
        'Nhập mật khẩu hiện tại và mật khẩu mới từ 6 đến 72 ký tự.',
      );
    }
    final result = await api.request(
      '/api/me/password',
      body: {'currentPassword': current, 'newPassword': next},
    );
    if (result['changed'] != true) {
      throw const ApiException(
        'INVALID_RESPONSE',
        'Chưa xác nhận được kết quả đổi mật khẩu.',
      );
    }
  }

  Future<String> uploadAvatar(Uint8List bytes, String filename) async {
    if (bytes.length > 5 * 1024 * 1024) {
      throw const ApiException('FILE_TOO_LARGE', 'Mỗi ảnh tối đa 5 MB.');
    }
    final jpeg =
        bytes.length >= 12 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    final png =
        bytes.length >= 12 && _starts(bytes, [137, 80, 78, 71, 13, 10, 26, 10]);
    final webp =
        bytes.length >= 12 &&
        _starts(bytes, [82, 73, 70, 70]) &&
        bytes[8] == 87 &&
        bytes[9] == 69 &&
        bytes[10] == 66 &&
        bytes[11] == 80;
    if (!jpeg && !png && !webp) {
      throw const ApiException(
        'INVALID_FILE_TYPE',
        'Vui lòng chọn ảnh JPEG, PNG hoặc WEBP.',
      );
    }
    final result = await api.uploadAvatar(bytes, filename);
    final urls = result['urls'];
    if (urls is! List ||
        urls.length != 1 ||
        urls.first is! String ||
        !validUrl(urls.first as String)) {
      throw const ApiException(
        'INVALID_RESPONSE',
        'Máy chủ chưa trả đường dẫn ảnh hợp lệ.',
      );
    }
    return urls.first as String;
  }

  static bool _starts(Uint8List bytes, List<int> prefix) {
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) {
        return false;
      }
    }
    return true;
  }
}
