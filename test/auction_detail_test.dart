import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/features/auctions/auction_repository.dart';
import 'package:bidvibe/screens/bidder/auction_detail_screen.dart';

void main() {
  Map<String, dynamic> fixture({bool paused = false}) => {
    'id': '1107', 'listingId': '1115', 'title': 'Bình gốm',
    'category': 'antique', 'description': 'Gốm men rạn', 'condition': 'Nguyên vẹn',
    'seller': {'name': 'Phố Cổ', 'rating': 4.9},
    'startPrice': 9000000, 'currentPrice': 9000000, 'bidStep': 200000,
    'minNextBid': 9200000, 'depositRequired': 900000, 'depositAffordable': false,
    'bidCount': 0, 'status': 'active', 'isLive': !paused, 'paused': paused,
    'remainingSeconds': 100, 'joined': false, 'leading': false, 'won': false,
    'photos': [], 'bids': [],
  };

  test('Uses auction ID, not listing ID, and carries the login token', () async {
    final api = ApiClient(client: MockClient((request) async {
      expect(request.url.path, '/api/auctions/1107');
      expect(request.headers['Authorization'], 'Bearer token');
      return http.Response(jsonEncode({'success': true, 'data': fixture()}), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});
    }))..token = 'token';
    addTearDown(api.close);
    final result = await AuctionRepository(api).detail('1107');
    expect(result['listingId'], '1115');
    expect(result['currentPrice'], 9000000);
  });

  test('Rejects invalid IDs before sending HTTP', () async {
    var calls = 0;
    final api = ApiClient(client: MockClient((_) async {
      calls++;
      return http.Response('{}', 500);
    }));
    addTearDown(api.close);
    await expectLater(AuctionRepository(api).detail('../me'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'VALIDATION_ERROR')));
    expect(calls, 0);
  });

  testWidgets('Renders paused detail without photos or bids; GET only', (tester) async {
    var calls = 0;
    final api = ApiClient(client: MockClient((request) async {
      calls++;
      expect(request.method, 'GET');
      return http.Response(jsonEncode({'success': true, 'data': fixture(paused: true)}),
        200, headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    try {
      await tester.pumpWidget(MaterialApp(home: AuctionDetailScreen(
        auctionId: '1107', repository: AuctionRepository(api))));
      await tester.pumpAndSettle();
      expect(find.text('Bình gốm'), findsOneWidget);
      expect(find.text('Tạm dừng'), findsOneWidget);
      expect(find.text('Chưa có ảnh'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Chưa có lượt đặt giá'), 400, scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first);
      expect(find.text('Chưa có lượt đặt giá'), findsOneWidget);
      expect(calls, 1);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      api.close();
    }
  });

  testWidgets('Not-found response displays a retry action', (tester) async {
    final api = ApiClient(client: MockClient((_) async => http.Response(
      '{"success":false,"error":{"code":"NOT_FOUND","message":"Not found"}}', 404)));
    try {
      await tester.pumpWidget(MaterialApp(home: AuctionDetailScreen(
        auctionId: '999999', repository: AuctionRepository(api))));
      await tester.pumpAndSettle();
      expect(find.text('Phiên này không còn tồn tại hoặc bạn không được phép xem.'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      api.close();
    }
  });
}
