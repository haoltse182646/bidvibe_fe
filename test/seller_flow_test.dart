import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/features/disputes/dispute_repository.dart';
import 'package:bidvibe/features/listings/listing_repository.dart';

http.Response ok(Map<String, dynamic> data) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> listing(String id, String status, {Map<String, dynamic>? auction, Map<String, dynamic>? appraisal}) => {
  'id': id,
  'title': 'Tin $id',
  'category': 'shoes',
  'status': status,
  'startingPrice': 1500000,
  'durationHours': 72,
  'condition': 'Như mới',
  'description': 'Mô tả',
  'lastAppraisal': appraisal,
  'auction': auction,
};

void main() {
  test('tin đăng + đơn bán quy về trạng thái hiển thị của người bán', () async {
    final api = ApiClient(
      client: MockClient((r) async {
        if (r.url.path == '/api/listings/mine') {
          return ok({
            'listings': [
              listing('1', 'draft'),
              listing('2', 'pending_appraisal'),
              listing('3', 'needs_info', appraisal: {'decision': 'more_info', 'reason': 'Chụp thêm đế giày'}),
              listing('4', 'live', auction: {'id': '40', 'currentPrice': 1600000, 'endsAt': '2030-01-01T00:00:00Z'}),
              listing('5', 'ended', auction: {'id': '50', 'currentPrice': 2000000}),
              listing('6', 'ended', auction: {'id': '60', 'currentPrice': 2500000}),
              listing('7', 'rejected', appraisal: {'decision': 'reject', 'reason': 'Hàng nghi giả'}),
            ],
          });
        }
        return ok({
          'orders': [
            {'id': '501', 'auctionId': '50', 'stage': 'awaiting_seller_shipment', 'paymentStatus': 'paid', 'payoutStatus': 'pending', 'finalPrice': 2000000, 'seller': {'storeName': 'Shop Thử'}},
            {'id': '601', 'auctionId': '60', 'stage': 'awaiting_payment', 'paymentStatus': 'awaiting_payment', 'payoutStatus': 'pending', 'finalPrice': 2500000, 'seller': {'storeName': 'Shop Thử'}},
          ],
        });
      }),
    )..token = 't';
    addTearDown(api.close);
    final data = await ListingRepository(api).loadSeller(fallbackShop: 'Tên thật');
    final byId = {for (final l in data.listings) l.id: l};
    expect(data.shop, 'Shop Thử', reason: 'tên gian hàng lấy từ đơn bán');
    expect(byId.containsKey('1'), isFalse, reason: 'bản nháp không hiện');
    expect(byId['2']!.status, 'appraisal');
    expect(byId['3']!.status, 'needinfo');
    expect(byId['3']!.requests, ['Chụp thêm đế giày']);
    expect(byId['3']!.canEdit, isTrue);
    expect(byId['4']!.status, 'live');
    expect(byId['4']!.canEdit, isFalse, reason: 'BE không cho sửa phiên đang chạy');
    expect(byId['5']!.status, 'shipping');
    expect(byId['6']!.status, 'unpaid');
    expect(byId['7']!.note, 'Hàng nghi giả');
    expect(data.shipments.single.at, 1, reason: 'chỉ đơn đã thanh toán có phiếu gửi kho');
    expect(data.orderByListing, {'5': '501'});
  });

  test('tạo tin: gọi lần lượt tạo → ảnh → gửi thẩm định, mã sai bị chặn', () async {
    final seen = <String>[];
    final api = ApiClient(
      client: MockClient((r) async {
        seen.add('${r.method} ${r.url.path}');
        return ok({'id': '77'});
      }),
    )..token = 't';
    addTearDown(api.close);
    final repo = ListingRepository(api);
    final id = await repo.createAndSubmit(title: 'A', category: 'shoes', startingPrice: 1, durationHours: 24, condition: 'Mới', photos: 2, progress: DraftProgress());
    expect(id, '77');
    expect(seen, ['POST /api/listings', 'POST /api/listings/77/photos', 'POST /api/listings/77/submit']);
    await expectLater(repo.shipToWarehouse('x'), throwsA(isA<ApiException>()));
    expect(seen.length, 3);
  });

  test('gợi ý giá: đọc giá, khoảng và giải thích từ BE; giá không hợp lệ bị từ chối', () async {
    Map<String, dynamic>? sent;
    var price = 3300000;
    final api = ApiClient(
      client: MockClient((r) async {
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return ok({
          'suggestedStartingPrice': price,
          'expectedFinalRange': [2750000, 4600000],
          'basis': 'history',
          'sampleSize': 5,
          'explanation': 'Dựa trên 5 phiên cùng danh mục.',
        });
      }),
    )..token = 't';
    addTearDown(api.close);
    final repo = ListingRepository(api);
    final s = await repo.suggestPrice(category: 'shoes', condition: 'Như mới');
    expect(sent, {'categoryCode': 'shoes', 'condition': 'Như mới'});
    expect((s.price, s.low, s.high, s.fromHistory), (3300000, 2750000, 4600000, true));
    price = 0;
    await expectLater(repo.suggestPrice(category: 'shoes', condition: 'x'), throwsA(isA<ApiException>()));
  });

  test('tranh chấp của tôi: đọc trạng thái, kết quả xử lý và mốc thời gian', () async {
    final api = ApiClient(
      client: MockClient((_) async => ok({
        'disputes': [
          {
            'id': '74', 'orderId': '11', 'itemTitle': 'Đầu đĩa than Sanyo 1979', 'source': 'seller',
            'title': 'x', 'status': 'open', 'resolution': 'none', 'escrowAmount': 4135000,
            'timeline': [{'note': 'Người bán mở tranh chấp', 'at': '2026-10-16T01:49:00Z'}],
          },
          {'id': '4', 'orderId': '17', 'source': 'bidder', 'status': 'resolved', 'resolution': 'refund'},
        ],
      })),
    )..token = 't';
    addTearDown(api.close);
    final list = await DisputeRepository(api).mine();
    expect(list.first.open, isTrue);
    expect(list.first.escrowAmount, 4135000);
    expect(list.first.createdAt, isNotNull);
    expect(list.last.open, isFalse);
    expect(list.last.itemTitle, 'Đơn #17', reason: 'thiếu tên hàng thì hiện mã đơn');
  });
}
