import 'dart:convert';

import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/features/auctions/auction_repository.dart';
import 'package:bidvibe/screens/bidder/auction_join_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('JOIN_BLOCKED shows the backend reason without an uncertain deposit message', (tester) async {
    const reason = 'Bạn tạm thời không được tham gia phiên mới vì đã bỏ thanh toán nhiều lần.';
    var posts = 0;
    final api = ApiClient(client: MockClient((request) async {
      posts++;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/auctions/1107/join');
      return http.Response(
        jsonEncode({
          'success': false,
          'data': null,
          'error': {'code': 'JOIN_BLOCKED', 'message': reason},
        }),
        403,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));
    try {
      await tester.pumpWidget(MaterialApp(home: Scaffold(
        body: AuctionJoinPanel(
          auction: const {
            'id': '1107', 'joined': false, 'isLive': true,
            'depositRequired': 1000, 'depositAffordable': true,
          },
          repository: AuctionRepository(api),
          onRefresh: () async => true,
        ),
      )));
      await tester.tap(find.widgetWithText(FilledButton, 'Đặt cọc tham gia'));
      // The join panel stays busy while the confirmation dialog is open.
      // Its progress indicator prevents pumpAndSettle from settling here.
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Xác nhận đặt cọc'), findsOneWidget);
      await tester.tap(find.text('Xác nhận đặt cọc'));
      await tester.pumpAndSettle();

      expect(posts, 1);
      expect(find.text(reason), findsOneWidget);
      expect(find.textContaining('Chưa xác định được kết quả đặt cọc'), findsNothing);
      expect(find.text('Cần tải lại dữ liệu trước khi tiếp tục thao tác.'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      api.close();
    }
  });
}
