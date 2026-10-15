import '../../core/api_client.dart';

class ShippingAddress {
  final String id, recipientName, phone, addressLine, city;
  final String? ward, district;
  final bool isDefault;
  const ShippingAddress({
    required this.id,
    required this.recipientName,
    required this.phone,
    required this.addressLine,
    required this.city,
    this.ward,
    this.district,
    required this.isDefault,
  });
  factory ShippingAddress.fromJson(Map<String, dynamic> data) {
    final id = '${data['id']}';
    if (!AddressRepository.validId(id) ||
        ['recipientName', 'phone', 'addressLine', 'city'].any(
          (key) => data[key] is! String || (data[key] as String).trim().isEmpty,
        ) ||
        data['isDefault'] is! bool ||
        [
          'ward',
          'district',
        ].any((key) => data[key] != null && data[key] is! String)) {
      throw const ApiException(
        'INVALID_RESPONSE',
        'Địa chỉ trả về không hợp lệ.',
      );
    }
    return ShippingAddress(
      id: id,
      recipientName: data['recipientName'],
      phone: data['phone'],
      addressLine: data['addressLine'],
      city: data['city'],
      ward: data['ward'],
      district: data['district'],
      isDefault: data['isDefault'],
    );
  }
  String get fullAddress => [
    addressLine,
    ward,
    district,
    city,
  ].whereType<String>().where((s) => s.trim().isNotEmpty).join(', ');
  Map<String, dynamic> get fields => {
    'recipientName': recipientName,
    'phone': phone,
    'addressLine': addressLine,
    'ward': ward,
    'district': district,
    'city': city,
  };
}

class AddressRepository {
  final ApiClient api;
  const AddressRepository(this.api);
  static bool validId(String id) => RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(id);
  static void checkId(String id) {
    if (!validId(id)) {
      throw const ApiException('VALIDATION_ERROR', 'Mã địa chỉ không hợp lệ.');
    }
  }

  static String? fieldError(String key, String? value) {
    final text = value?.trim() ?? '';
    final optional = ['ward', 'district'].contains(key);
    if (text.isEmpty) {
      return optional ? null : 'Vui lòng nhập thông tin này.';
    }
    if (text.length >
        (key == 'addressLine'
            ? 255
            : key == 'phone'
            ? 20
            : 100)) {
      return 'Thông tin vượt quá độ dài cho phép.';
    }
    if (key == 'phone') {
      final digits = text.replaceAll(RegExp(r'\D'), '');
      if (!RegExp(r'^\+?[0-9\s.()-]{8,20}$').hasMatch(text) ||
          digits.length < 9 ||
          digits.length > 15) {
        return 'Nhập số điện thoại từ 9 đến 15 chữ số.';
      }
    }
    return null;
  }

  static Map<String, dynamic> validate(
    Map<String, dynamic> fields, {
    bool partial = false,
  }) {
    const keys = [
      'recipientName',
      'phone',
      'addressLine',
      'ward',
      'district',
      'city',
    ];
    if (fields.isEmpty || fields.keys.any((key) => !keys.contains(key))) {
      throw const ApiException(
        'VALIDATION_ERROR',
        'Không có thông tin địa chỉ hợp lệ.',
      );
    }
    final out = <String, dynamic>{};
    for (final key in keys) {
      if (partial && !fields.containsKey(key)) {
        continue;
      }
      final value = fields[key];
      if ((value != null && value is! String) ||
          fieldError(key, value as String?) != null) {
        throw const ApiException(
          'VALIDATION_ERROR',
          'Vui lòng kiểm tra thông tin địa chỉ.',
        );
      }
      final text = value?.trim() ?? '';
      out[key] = text.isEmpty ? null : text;
    }
    return out;
  }

  Future<List<ShippingAddress>> list() async {
    final data = await api.request('/api/addresses');
    final rows = data['addresses'];
    if (rows is! List || rows.any((row) => row is! Map)) {
      throw const ApiException(
        'INVALID_RESPONSE',
        'Không đọc được danh sách địa chỉ.',
      );
    }
    return rows
        .map(
          (row) =>
              ShippingAddress.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<ShippingAddress> create(
    Map<String, dynamic> fields, {
    bool isDefault = false,
  }) async => ShippingAddress.fromJson(
    await api.request(
      '/api/addresses',
      method: 'POST',
      body: {...validate(fields), 'isDefault': isDefault},
    ),
  );
  Future<ShippingAddress> update(
    String id,
    Map<String, dynamic> changes,
  ) async {
    checkId(id);
    return ShippingAddress.fromJson(
      await api.request(
        '/api/addresses/$id',
        method: 'PATCH',
        body: validate(changes, partial: true),
      ),
    );
  }

  Future<ShippingAddress> setDefault(String id) async {
    checkId(id);
    return ShippingAddress.fromJson(
      await api.request('/api/addresses/$id/default', method: 'POST'),
    );
  }

  Future<void> remove(String id) async {
    checkId(id);
    final data = await api.request('/api/addresses/$id', method: 'DELETE');
    if ('${data['id']}' != id || data['deleted'] != true) {
      throw const ApiException(
        'INVALID_RESPONSE',
        'Chưa xác nhận được kết quả xóa địa chỉ.',
      );
    }
  }
}
