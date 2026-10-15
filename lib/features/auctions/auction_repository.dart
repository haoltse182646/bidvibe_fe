import '../../core/api_client.dart';

class AuctionRepository {
  final ApiClient api;
  const AuctionRepository(this.api);

  Future<void> report(
    String auctionId, {
    required String reason,
    String? note,
  }) async {
    final cleanReason = reason.trim();
    final cleanNote = note?.trim() ?? '';
    if (!RegExp(r'^[0-9]{1,18}$').hasMatch(auctionId) ||
        cleanReason.isEmpty ||
        cleanReason.length > 100 ||
        cleanNote.length > 500) {
      throw const ApiException(
        'VALIDATION_ERROR',
        'Mã phiên, lý do hoặc ghi chú không hợp lệ.',
      );
    }
    final result = await api.request(
      '/api/auctions/$auctionId/report',
      body: {
        'reason': cleanReason,
        if (cleanNote.isNotEmpty) 'note': cleanNote,
      },
    );
    if (result['reported'] != true) {
      throw const ApiException(
        'INVALID_RESPONSE',
        'Chưa xác nhận được kết quả gửi báo cáo.',
      );
    }
  }

  Future<Map<String, dynamic>> bid(String auctionId, int amount) async {
    if (!RegExp(r'^[0-9]{1,18}$').hasMatch(auctionId) || amount <= 0) {
      throw const ApiException(
        'VALIDATION_ERROR',
        'Mã phiên hoặc giá đặt không hợp lệ.',
      );
    }
    return api.request(
      '/api/bids',
      body: {'auctionId': auctionId, 'amount': amount},
    );
  }

  Future<Map<String, dynamic>> join(String auctionId) async {
    if (!RegExp(r'^[0-9]{1,18}$').hasMatch(auctionId)) {
      throw const ApiException('VALIDATION_ERROR', 'Mã phiên không hợp lệ.');
    }
    return api.request('/api/auctions/$auctionId/join', method: 'POST');
  }

  Future<Map<String, dynamic>> detail(String auctionId) async {
    if (!RegExp(r'^[0-9]+$').hasMatch(auctionId)) {
      throw const ApiException('VALIDATION_ERROR', 'Mã phiên không hợp lệ.');
    }
    return api.request('/api/auctions/$auctionId');
  }

  Future<List<Map<String, dynamic>>> categories() async {
    final data = await api.request('/api/categories');
    return _list(data['categories']);
  }

  Future<AuctionPage> list({
    String status = 'live',
    String? category,
    String query = '',
    String sort = 'ending',
    int offset = 0,
  }) async {
    final params = <String, String>{
      'status': status,
      'sort': sort,
      'limit': '20',
      'offset': '$offset',
      if (category != null) 'category': category,
      if (query.trim().isNotEmpty) 'q': query.trim(),
    };
    final path = Uri(path: '/api/auctions', queryParameters: params).toString();
    final data = await api.request(path);
    return AuctionPage(_list(data['auctions']), (data['total'] as num).toInt());
  }

  List<Map<String, dynamic>> _list(dynamic value) {
    if (value is! List) {
      throw const ApiException(
        'INVALID_RESPONSE',
        'Danh sách máy chủ không hợp lệ.',
      );
    }
    return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}

class AuctionPage {
  final List<Map<String, dynamic>> items;
  final int total;
  const AuctionPage(this.items, this.total);
}
