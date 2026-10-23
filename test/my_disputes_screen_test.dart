import 'dart:async';
import 'dart:convert';

import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/screens/orders/my_disputes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response ok(Map<String, dynamic> data) => http.Response(
      jsonEncode({'success': true, 'data': data}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

http.Response fail(String code, String message, int status) => http.Response(
      jsonEncode({
        'success': false,
        'error': {'code': code, 'message': message},
      }),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> dispute({
  String id = '7',
  String source = 'bidder',
  String status = 'open',
  String resolution = 'none',
}) =>
    {
      'id': id,
      'orderId': '120',
      'itemTitle': 'Auction item $id',
      'title': 'Item condition dispute',
      'source': source,
      'status': status,
      'resolution': resolution,
      'escrowAmount': 1200000,
      'timeline': [
        {'note': 'Dispute received', 'at': '2025-01-01T12:00:00Z'},
      ],
    };

Future<void> pumpScreen(WidgetTester tester, ApiClient api,
    {void Function(ApiException)? onSessionExpired}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MyDisputesScreen(api: api, onSessionExpired: onSessionExpired),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows loading state before rendering empty results',
      (tester) async {
    final response = Completer<http.Response>();
    final api = ApiClient(client: MockClient((_) => response.future));
    addTearDown(api.close);

    await tester.pumpWidget(MaterialApp(home: MyDisputesScreen(api: api)));
    await tester.pump();
    expect(find.text('Tranh chấp của tôi'), findsOneWidget);
    expect(find.text('Bạn chưa có tranh chấp nào.'), findsNothing);

    response.complete(ok({'disputes': <Object>[]}));
    await tester.pumpAndSettle();
    expect(find.text('Bạn chưa có tranh chấp nào.'), findsOneWidget);
  });

  testWidgets('renders dispute status, source, and resolution labels',
      (tester) async {
    final api = ApiClient(
      client: MockClient((_) async => ok({
            'disputes': [
              dispute(),
              dispute(
                  id: '8',
                  source: 'warehouse',
                  status: 'resolved',
                  resolution: 'refund'),
            ],
          })),
    );
    addTearDown(api.close);

    await pumpScreen(tester, api);

    expect(find.text('Auction item 7'), findsOneWidget);
    expect(find.text('Đang mở'), findsOneWidget);
    expect(find.text('Người mua mở'), findsOneWidget);
    expect(find.text('Admin đang xem xét'), findsOneWidget);
    expect(find.text('Auction item 8'), findsOneWidget);
    expect(find.text('Đã xử lý'), findsOneWidget);
    expect(find.text('Kho mở (kiểm không khớp)'), findsOneWidget);
    expect(find.text('Đã hoàn tiền cho người mua'), findsOneWidget);
  });

  testWidgets('shows an error and retries the request', (tester) async {
    var calls = 0;
    final api = ApiClient(
      client: MockClient((_) async {
        calls++;
        return calls == 1
            ? fail('SERVER_ERROR', 'Temporarily unavailable', 500)
            : ok({'disputes': <Object>[]});
      }),
    );
    addTearDown(api.close);

    await pumpScreen(tester, api);
    expect(find.text('Temporarily unavailable'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Bạn chưa có tranh chấp nào.'), findsOneWidget);
  });

  testWidgets('notifies the caller when the session has expired',
      (tester) async {
    ApiException? expired;
    final api = ApiClient(
      client:
          MockClient((_) async => fail('UNAUTHORIZED', 'Session expired', 401)),
    );
    addTearDown(api.close);

    await pumpScreen(tester, api, onSessionExpired: (error) => expired = error);

    expect(expired?.code, 'UNAUTHORIZED');
  });
}
