import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/features/addresses/address_repository.dart';
import 'package:bidvibe/features/orders/order_repository.dart';

/// Chạy với backend THẬT trên DB Docker cục bộ, KHÔNG chạy với DB dùng chung.
/// Tài khoản và mật khẩu lấy từ biến môi trường, không ghi trong repo:
///   BACKEND_URL=http://localhost:5000 TEST_PASSWORD=... ///   TEST_BIDDER_EMAIL=... TEST_BUYER_EMAIL=... flutter test test/order_live_test.dart
/// TEST_BIDDER_EMAIL: người mua có đơn đã thanh toán.
/// TEST_BUYER_EMAIL: người mua có một đơn đang chờ thanh toán.
/// Bước thanh toán ghi vào DB Docker và chỉ chạy được một lần cho mỗi đơn chờ.
void main() {
  final env = Platform.environment;
  final url = env['BACKEND_URL'];
  final password = env['TEST_PASSWORD'];
  final bidderEmail = env['TEST_BIDDER_EMAIL'];
  final buyerEmail = env['TEST_BUYER_EMAIL'];
  final missing = [
    if (url == null) 'BACKEND_URL',
    if (password == null) 'TEST_PASSWORD',
    if (bidderEmail == null) 'TEST_BIDDER_EMAIL',
    if (buyerEmail == null) 'TEST_BUYER_EMAIL',
  ];
  final skip = missing.isEmpty ? null : 'đặt biến môi trường: ${missing.join(', ')} (backend trên DB Docker)';

  Future<ApiClient> login(String email) async {
    ApiClient.baseUrl = url!;
    final api = ApiClient();
    addTearDown(api.close);
    final data = await api.request(
      '/api/auth/login',
      body: {'email': email, 'password': password},
    );
    api.token = data['token'] as String;
    return api;
  }

  test('đơn của người mua: danh sách, chi tiết và theo dõi khớp nhau', () async {
    final repo = OrderRepository(await login(bidderEmail!));
    final orders = await repo.mine();
    expect(orders, isNotEmpty);
    final paid = orders.firstWhere((o) => o.paid);
    final full = await repo.load(paid.id);
    expect(full.id, paid.id);
    expect(full.totalDue, paid.totalDue);
    expect(full.stage, isNotNull);
    expect(full.amountToPay, full.totalDue - full.depositApplied);
  }, skip: skip, timeout: const Timeout(Duration(seconds: 60)));

  test('gắn địa chỉ, thanh toán đơn chờ, không trả hai lần, chưa giao thì không xác nhận được', () async {
    final api = await login(buyerEmail!);
    final repo = OrderRepository(api);
    final pending = (await repo.mine()).where((o) => o.awaitingPayment).toList();
    if (pending.isEmpty) {
      markTestSkipped('không còn đơn chờ thanh toán trong DB Docker');
      return;
    }
    final order = pending.first;

    final addresses = AddressRepository(api);
    var list = await addresses.list();
    if (list.isEmpty) {
      await addresses.create({
        'recipientName': 'Chau Le',
        'phone': '0912345678',
        'addressLine': '12 Le Loi',
        'city': 'TP.HCM',
      }, isDefault: true);
      list = await addresses.list();
    }
    await repo.setAddress(order.id, list.first.id);
    expect((await repo.load(order.id)).shippingAddress?.id, list.first.id);

    await repo.pay(order.id, 'qr');
    final after = await repo.load(order.id);
    expect(after.paid, isTrue);
    expect(after.stage, 'awaiting_seller_shipment');

    await expectLater(
      repo.pay(order.id, 'qr'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'ALREADY_PAID')),
    );
    await expectLater(
      repo.confirmDelivery(order.id),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'NOT_DELIVERED')),
    );
  }, skip: skip, timeout: const Timeout(Duration(seconds: 60)));
}
