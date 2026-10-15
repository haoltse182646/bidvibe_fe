import '../../core/api_client.dart';

class WalletSnapshot {
  final int balance, held, available;
  const WalletSnapshot({
    required this.balance,
    required this.held,
    required this.available,
  });
  factory WalletSnapshot.fromJson(Map<String, dynamic> data) {
    if (data['balance'] is! num ||
        data['held'] is! num ||
        data['available'] is! num) {
      throw const ApiException(
        'INVALID_RESPONSE',
        'Dữ liệu số dư không hợp lệ.',
      );
    }
    return WalletSnapshot(
      balance: (data['balance'] as num).toInt(),
      held: (data['held'] as num).toInt(),
      available: (data['available'] as num).toInt(),
    );
  }
}

class WalletPage {
  final List<Map<String, dynamic>> transactions;
  final int total;
  const WalletPage(this.transactions, this.total);
}

class WalletRepository {
  final ApiClient api;
  const WalletRepository(this.api);

  Future<WalletSnapshot> wallet() async =>
      WalletSnapshot.fromJson(await api.request('/api/wallet'));

  Future<WalletPage> transactions({int offset = 0}) async {
    final data = await api.request(
      '/api/wallet/transactions?limit=20&offset=$offset',
    );
    if (data['transactions'] is! List || data['total'] is! num) {
      throw const ApiException(
        'INVALID_RESPONSE',
        'Lịch sử giao dịch không hợp lệ.',
      );
    }
    return WalletPage(
      (data['transactions'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      (data['total'] as num).toInt(),
    );
  }

  static String? validateAmount(String text) {
    final value = text.trim();
    final amount = int.tryParse(value);
    if (!RegExp(r'^[0-9]+$').hasMatch(value) ||
        amount == null ||
        amount < 1 ||
        amount > 100000000) {
      return 'Nhập số nguyên từ 1 đến 100.000.000 đồng, không có dấu phân cách.';
    }
    return null;
  }

  Future<WalletSnapshot> topup(int amount) async {
    final error = validateAmount('$amount');
    if (error != null) {
      throw ApiException('VALIDATION_ERROR', error);
    }
    return WalletSnapshot.fromJson(
      await api.request('/api/wallet/topup', body: {'amount': amount}),
    );
  }
}
