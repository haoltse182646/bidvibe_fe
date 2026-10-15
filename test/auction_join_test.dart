import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/features/auctions/auction_repository.dart';
import 'package:bidvibe/screens/bidder/auction_join_panel.dart';

http.Response ok(Map<String, dynamic> data, {int status = 200}) =>
    http.Response(
      jsonEncode({'success': true, 'data': data}),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> auction({
  bool joined = false,
  bool affordable = true,
  bool live = true,
  bool paused = false,
}) => {
  'id': '1107',
  'listingId': '1115',
  'joined': joined,
  'depositRequired': 900000,
  'depositAffordable': affordable,
  'isLive': live,
  'paused': paused,
};

void main() {
  testWidgets('New bidder opens wallet from deposit panel with a Material ancestor', (tester) async {
    var refreshes = 0;
    final api = ApiClient(client: MockClient((request) async {
      expect(request.method, 'GET');
      if (request.url.path == '/api/wallet') {
        return ok({'balance': 0, 'held': 0, 'available': 0});
      }
      expect(request.url.path, '/api/wallet/transactions');
      return ok({'transactions': [], 'total': 0, 'limit': 20, 'offset': 0});
    }));
    try {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: AuctionJoinPanel(
        auction: auction(affordable: false), repository: AuctionRepository(api),
        onRefresh: () async { refreshes++; return true; }))));
      await tester.tap(find.text('Mở ví / Nạp tiền'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.ancestor(of: find.byType(TextFormField), matching: find.byType(Material)), findsWidgets);
      await tester.enterText(find.byType(TextFormField), '100000');
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(refreshes, 1);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      api.close();
    }
  });
  test('Join uses POST without body and the login token', () async {
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/auctions/1107/join');
        expect(request.body, isEmpty);
        expect(request.headers['Authorization'], 'Bearer bidder');
        return ok({
          'depositId': '1',
          'deposit': 900000,
          'balanceAfter': 100000,
        }, status: 201);
      }),
    )..token = 'bidder';
    addTearDown(api.close);
    final data = await AuctionRepository(api).join('1107');
    expect(data['deposit'], 900000);
  });

  test('Zero deposit response may contain null balanceAfter', () async {
    final api = ApiClient(
      client: MockClient(
        (_) async => ok({
          'depositId': '2',
          'deposit': 0,
          'balanceAfter': null,
        }, status: 201),
      ),
    );
    addTearDown(api.close);
    final data = await AuctionRepository(api).join('1107');
    expect(data['balanceAfter'], isNull);
  });

  test('Reject invalid IDs without HTTP', () async {
    var calls = 0;
    final api = ApiClient(
      client: MockClient((_) async {
        calls++;
        return ok({});
      }),
    );
    addTearDown(api.close);
    for (final id in ['../wallet', '', '1234567890123456789']) {
      await expectLater(
        AuctionRepository(api).join(id),
        throwsA(isA<ApiException>()),
      );
    }
    expect(calls, 0);
  });

  for (final code in [
    'INSUFFICIENT_FUNDS',
    'ALREADY_JOINED',
    'AUCTION_ENDED',
    'AUCTION_PAUSED',
  ]) {
    test('Preserves backend error $code without retrying POST', () async {
      var calls = 0;
      final api = ApiClient(
        client: MockClient((_) async {
          calls++;
          return http.Response(
            jsonEncode({
              'success': false,
              'error': {'code': code, 'message': code},
            }),
            code == 'INSUFFICIENT_FUNDS' ? 402 : 409,
          );
        }),
      );
      addTearDown(api.close);
      await expectLater(
        AuctionRepository(api).join('1107'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', code)),
      );
      expect(calls, 1);
    });
  }

  testWidgets(
    'Cancel sends no request; confirm sends one POST then refreshes joined',
    (tester) async {
      var posts = 0, gets = 0;
      var data = auction();
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.method == 'POST') {
            posts++;
            return ok({
              'depositId': '1',
              'deposit': 900000,
              'balanceAfter': 100000,
            }, status: 201);
          }
          gets++;
          return ok(auction(joined: posts > 0));
        }),
      );
      final repo = AuctionRepository(api);
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, update) => AuctionJoinPanel(
                  auction: data,
                  repository: repo,
                  onRefresh: () async {
                    final next = await repo.detail('1107');
                    update(() => data = next);
                    return true;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Đặt cọc tham gia'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Hủy'));
        await tester.pumpAndSettle();
        expect(posts, 0);
        await tester.tap(find.widgetWithText(FilledButton, 'Đặt cọc tham gia'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Xác nhận đặt cọc'));
        await tester.pumpAndSettle();
        expect(posts, 1);
        expect(gets, 1);
        expect(
          find.widgetWithText(FilledButton, 'Đặt cọc tham gia'),
          findsNothing,
        );
        expect(
          find.text(
            'Bạn đã đặt cọc tham gia phiên này. Không cần đặt cọc lại.',
          ),
          findsOneWidget,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        api.close();
      }
    },
  );

  testWidgets('Insufficient funds offers wallet instead of a join action', (
    tester,
  ) async {
    final api = ApiClient(client: MockClient((_) async => ok({})));
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuctionJoinPanel(
              auction: auction(affordable: false),
              repository: AuctionRepository(api),
              onRefresh: () async => true,
            ),
          ),
        ),
      );
      expect(
        find.widgetWithText(FilledButton, 'Đặt cọc tham gia'),
        findsNothing,
      );
      expect(find.text('Mở ví / Nạp tiền'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      api.close();
    }
  });

  testWidgets('Network error blocks resubmission until state is verified', (
    tester,
  ) async {
    var posts = 0;
    final api = ApiClient(
      client: MockClient((_) async {
        posts++;
        throw http.ClientException('Disconnected');
      }),
    );
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuctionJoinPanel(
              auction: auction(),
              repository: AuctionRepository(api),
              onRefresh: () async => false,
            ),
          ),
        ),
      );
      final button = find.widgetWithText(FilledButton, 'Đặt cọc tham gia');
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Xác nhận đặt cọc'));
      await tester.pumpAndSettle();
      expect(posts, 1);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      api.close();
    }
  });
}
