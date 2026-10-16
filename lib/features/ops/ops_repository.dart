import '../../core/api_client.dart';

class OpsRepository {
  final ApiClient api;
  final bool Function(ApiException error)? onAuthError;
  const OpsRepository(this.api, {this.onAuthError});

  Future<Map<String, dynamic>> _request(
    String path, {
    Map<String, dynamic>? body,
    String? method,
  }) async {
    try {
      return await api.request(path, body: body, method: method);
    } on ApiException catch (error) {
      if (error.code == 'UNAUTHORIZED' || error.code == 'ACCOUNT_SUSPENDED') {
        onAuthError?.call(error);
      }
      rethrow;
    }
  }

  static bool validId(String id) => RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(id);

  static String _query(Map<String, String> values) =>
      Uri(queryParameters: values).query;

  static List<Map<String, dynamic>> _list(
    Map<String, dynamic> data,
    String key,
    String message,
  ) {
    final rows = data[key];
    if (rows is! List || rows.any((row) => row is! Map)) {
      throw ApiException('INVALID_RESPONSE', message);
    }
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  static String _checkId(String id, String label) {
    if (!validId(id)) {
      throw ApiException('VALIDATION_ERROR', '$label không hợp lệ.');
    }
    return id;
  }

  Future<Map<String, dynamic>> dashboard() async =>
      _request('/api/admin/dashboard');

  Future<Map<String, dynamic>> weeklyReport() async =>
      _request('/api/admin/report/weekly');

  Future<List<Map<String, dynamic>>> flags({
    String? status,
    int limit = 100,
  }) async {
    final query = <String, String>{'limit': '$limit'};
    if (status != null) query['status'] = status;
    return _list(
      await _request('/api/admin/flags?${_query(query)}'),
      'flags',
      'Không đọc được danh sách cờ phiên.',
    );
  }

  Future<Map<String, dynamic>> flag(String id) async {
    _checkId(id, 'Mã cờ');
    final rows = await flags();
    for (final row in rows) {
      if ('${row['id']}' == id) return row;
    }
    throw const ApiException('NOT_FOUND', 'Không tìm thấy cờ phiên.');
  }

  Future<Map<String, dynamic>> actOnFlag(
    String id, {
    required String action,
    String? reason,
  }) async {
    _checkId(id, 'Mã cờ');
    if (!const {'pause', 'verify', 'safe', 'terminate'}.contains(action)) {
      throw const ApiException('VALIDATION_ERROR', 'Thao tác cờ không hợp lệ.');
    }
    if (action == 'terminate' && (reason == null || reason.trim().isEmpty)) {
      throw const ApiException('VALIDATION_ERROR', 'Cần nêu lý do chấm dứt phiên.');
    }
    final body = <String, dynamic>{'action': action};
    if (reason != null && reason.trim().isNotEmpty) {
      body['reason'] = reason.trim();
    }
    return _request(
      '/api/admin/flags/$id/action',
      method: 'POST',
      body: body,
    );
  }

  Future<List<Map<String, dynamic>>> disputes({
    String? status,
    int limit = 100,
  }) async {
    final query = <String, String>{'limit': '$limit'};
    if (status != null) query['status'] = status;
    return _list(
      await _request('/api/admin/disputes?${_query(query)}'),
      'disputes',
      'Không đọc được danh sách tranh chấp.',
    );
  }

  Future<Map<String, dynamic>> resolveDispute(
    String id, {
    required String resolution,
    String? note,
  }) async {
    _checkId(id, 'Mã tranh chấp');
    if (!const {'refund', 'keep'}.contains(resolution)) {
      throw const ApiException(
        'VALIDATION_ERROR',
        'Kết quả xử lý tranh chấp không hợp lệ.',
      );
    }
    return _request(
      '/api/admin/disputes/$id/resolve',
      method: 'POST',
      body: {
        'resolution': resolution,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> accounts({
    String? role,
    String? status,
    String? query,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, String>{'limit': '$limit', 'offset': '$offset'};
    if (role != null) params['role'] = role;
    if (status != null) params['status'] = status;
    if (query != null && query.trim().isNotEmpty) params['q'] = query.trim();
    return _list(
      await _request('/api/admin/accounts?${_query(params)}'),
      'accounts',
      'Không đọc được danh sách tài khoản.',
    );
  }

  Future<Map<String, dynamic>> updateAccount(
    String id, {
    required String status,
  }) async {
    _checkId(id, 'Mã tài khoản');
    if (!const {'active', 'suspended'}.contains(status)) {
      throw const ApiException('VALIDATION_ERROR', 'Trạng thái tài khoản không hợp lệ.');
    }
    return _request(
      '/api/admin/accounts/$id',
      method: 'PATCH',
      body: {'status': status},
    );
  }

  Future<List<Map<String, dynamic>>> opsAccounts({
    String? role,
    String? status,
  }) async {
    final params = <String, String>{};
    if (role != null) params['role'] = role;
    if (status != null) params['status'] = status;
    final suffix = params.isEmpty ? '' : '?${_query(params)}';
    return _list(
      await _request('/api/admin/ops-accounts$suffix'),
      'accounts',
      'Không đọc được tài khoản vận hành.',
    );
  }

  Future<Map<String, dynamic>> createOpsAccount({
    required String name,
    required String email,
    required String role,
    required String password,
  }) async {
    if (!const {'appraiser', 'warehouse', 'admin'}.contains(role)) {
      throw const ApiException('VALIDATION_ERROR', 'Vai trò vận hành không hợp lệ.');
    }
    return _request(
      '/api/admin/ops-accounts',
      method: 'POST',
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'role': role,
        'password': password,
      },
    );
  }

  Future<Map<String, dynamic>> updateOpsAccount(
    String id, {
    String? name,
    String? role,
    String? status,
    String? password,
  }) async {
    _checkId(id, 'Mã tài khoản vận hành');
    if (role != null &&
        !const {'appraiser', 'warehouse', 'admin'}.contains(role)) {
      throw const ApiException('VALIDATION_ERROR', 'Vai trò vận hành không hợp lệ.');
    }
    if (status != null && !const {'active', 'suspended'}.contains(status)) {
      throw const ApiException('VALIDATION_ERROR', 'Trạng thái tài khoản không hợp lệ.');
    }
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name.trim();
    if (role != null) body['role'] = role;
    if (status != null) body['status'] = status;
    if (password != null && password.isNotEmpty) body['password'] = password;
    if (body.isEmpty) {
      throw const ApiException('VALIDATION_ERROR', 'Chưa có thay đổi.');
    }
    return _request(
      '/api/admin/ops-accounts/$id',
      method: 'PATCH',
      body: body,
    );
  }

  Future<List<Map<String, dynamic>>> appraisalQueue({
    String status = 'pending_appraisal',
    int limit = 50,
    int offset = 0,
  }) async {
    if (!const {'pending_appraisal', 'needs_info'}.contains(status)) {
      throw const ApiException('VALIDATION_ERROR', 'Trạng thái hàng chờ không hợp lệ.');
    }
    return _list(
      await _request(
        '/api/appraisals/queue?${_query({'status': status, 'limit': '$limit', 'offset': '$offset'})}',
      ),
      'items',
      'Không đọc được hàng chờ thẩm định.',
    );
  }

  Future<Map<String, dynamic>> appraisalDetail(String listingId) async {
    _checkId(listingId, 'Mã tin đăng');
    return _request('/api/appraisals/$listingId');
  }

  Future<Map<String, dynamic>> decideAppraisal(
    String listingId, {
    required String decision,
    String? reason,
  }) async {
    _checkId(listingId, 'Mã tin đăng');
    if (!const {'approve', 'reject', 'more_info'}.contains(decision)) {
      throw const ApiException('VALIDATION_ERROR', 'Quyết định thẩm định không hợp lệ.');
    }
    return _request(
      '/api/appraisals/$listingId/decision',
      method: 'POST',
      body: {
        'decision': decision,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> warehouseOrders({
    String? stage,
    int limit = 100,
    int offset = 0,
  }) async {
    final params = <String, String>{'limit': '$limit', 'offset': '$offset'};
    if (stage != null) params['stage'] = stage;
    return _list(
      await _request('/api/warehouse/orders?${_query(params)}'),
      'orders',
      'Không đọc được danh sách đơn kho.',
    );
  }

  Future<Map<String, dynamic>> warehouseOrder(String id) async {
    _checkId(id, 'Mã đơn');
    var offset = 0;
    while (true) {
      final rows = await warehouseOrders(offset: offset);
      for (final row in rows) {
        if ('${row['id']}' == id) return row;
      }
      if (rows.length < 100) break;
      offset += rows.length;
    }
    throw const ApiException('NOT_FOUND', 'Không tìm thấy đơn trong kho.');
  }

  Future<Map<String, dynamic>> receiveWarehouseOrder(String id) =>
      _warehouseAction(id, 'receive');

  Future<Map<String, dynamic>> inspectWarehouseOrder(
    String id, {
    required String result,
    String? notes,
  }) {
    if (!const {'match', 'mismatch'}.contains(result)) {
      throw const ApiException('VALIDATION_ERROR', 'Kết quả kiểm định không hợp lệ.');
    }
    return _warehouseAction(
      id,
      'inspect',
      body: {
        'result': result,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> packWarehouseOrder(
    String id, {
    String? notes,
  }) => _warehouseAction(
    id,
    'pack',
    body: {if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim()},
  );

  Future<Map<String, dynamic>> shipWarehouseOrder(
    String id, {
    required String carrier,
    required String trackingCode,
  }) => _warehouseAction(
    id,
    'ship',
    body: {'carrier': carrier.trim(), 'trackingCode': trackingCode.trim()},
  );

  Future<Map<String, dynamic>> deliverWarehouseOrder(String id) =>
      _warehouseAction(id, 'deliver');

  Future<Map<String, dynamic>> _warehouseAction(
    String id,
    String action, {
    Map<String, dynamic>? body,
  }) {
    _checkId(id, 'Mã đơn');
    return _request(
      '/api/warehouse/orders/$id/$action',
      method: 'POST',
      body: body,
    );
  }
}