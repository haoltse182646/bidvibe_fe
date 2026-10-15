import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String code;
  final String message;
  const ApiException(this.code, this.message);
  @override
  String toString() => message;
}

class ApiClient {
  static String baseUrl = 'http://10.0.2.2:5000';

  static Future<void> loadConfig() async {
    final content = await rootBundle.loadString('config/dev.json');
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('File cấu hình phải là JSON object.');
    }
    final value = decoded['API_BASE_URL'];
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Thiếu API_BASE_URL trong config/dev.json.');
    }
    final url = value.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('API_BASE_URL không hợp lệ.');
    }
    baseUrl = url;
  }

  final http.Client client;
  String? token;
  ApiClient({http.Client? client}) : client = client ?? http.Client();

  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
    String? method,
  }) async {
    try {
      final verb = method ?? (body == null ? 'GET' : 'POST');
      if (!['GET', 'POST', 'PATCH', 'DELETE'].contains(verb)) {
        throw ArgumentError('Unsupported HTTP method: $verb');
      }
      final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      final response =
          await (verb == 'GET'
                  ? client.get(uri, headers: headers)
                  : verb == 'PATCH'
                  ? client.patch(
                      uri,
                      headers: headers,
                      body: body == null ? null : jsonEncode(body),
                    )
                  : verb == 'DELETE'
                  ? client.delete(uri, headers: headers)
                  : client.post(
                      uri,
                      headers: headers,
                      body: body == null ? null : jsonEncode(body),
                    ))
              .timeout(const Duration(seconds: 20));
      return _decode(response);
    } on TimeoutException {
      throw const ApiException('TIMEOUT', 'Kết nối quá lâu. Vui lòng thử lại.');
    } on http.ClientException {
      throw const ApiException(
        'NETWORK',
        'Không kết nối được máy chủ. Kiểm tra backend và địa chỉ API.',
      );
    } on FormatException {
      throw const ApiException(
        'INVALID_RESPONSE',
        'Phản hồi máy chủ không hợp lệ.',
      );
    }
  }

  Future<Map<String, dynamic>> uploadAvatar(
    List<int> bytes,
    String filename,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/api/uploads/images?purpose=avatar',
        ),
      );
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(
        http.MultipartFile.fromBytes('files', bytes, filename: filename),
      );
      final response = await (() async => http.Response.fromStream(
        await client.send(request),
      ))().timeout(const Duration(seconds: 60));
      return _decode(response);
    } on TimeoutException {
      throw const ApiException('TIMEOUT', 'Tải ảnh quá lâu. Vui lòng thử lại.');
    } on http.ClientException {
      throw const ApiException(
        'NETWORK',
        'Không kết nối được máy chủ để tải ảnh.',
      );
    } on FormatException {
      throw const ApiException(
        'INVALID_RESPONSE',
        'Phản hồi tải ảnh không hợp lệ.',
      );
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded['success'] != true) {
        final error = decoded['error'];
        throw ApiException(
          error is Map ? '${error['code'] ?? 'HTTP_ERROR'}' : 'HTTP_ERROR',
          error is Map
              ? '${error['message'] ?? 'Yêu cầu thất bại.'}'
              : 'Yêu cầu thất bại.',
        );
      }
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        throw const FormatException();
      }
      return data;
    } on FormatException {
      throw const ApiException(
        'INVALID_RESPONSE',
        'Phản hồi máy chủ không hợp lệ.',
      );
    }
  }

  void close() => client.close();
}
