import 'dart:async';
import 'dart:convert';

import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/features/auctions/auction_repository.dart';
import 'package:bidvibe/screens/bidder/auction_report_screen.dart';
import 'package:bidvibe/screens/bidder/auction_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response success({bool created = true}) => http.Response(
  jsonEncode({
    'success': true,
    'data': {'reported': true, 'flagCreated': created},
  }),
  201,
);
http.Response failure(String code, {int status = 409}) => http.Response(
  jsonEncode({
    'success': false,
    'error': {'code': code, 'message': code},
  }),
  status,
);

Future<void> showReport(
  WidgetTester tester,
  ApiClient api, {
  VoidCallback? onReported,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AuctionReportScreen(
        auctionId: '1107',
        auctionTitle: 'Phiên thử nghiệm',
        repository: AuctionRepository(api),
        onReported: onReported,
      ),
    ),
  );
}

Future<void> enterReport(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), '  Nghi đẩy giá  ');
  await tester.enterText(
    find.byType(TextFormField).at(1),
    '  Đặt giá xen kẽ  ',
  );
}

Future<void> pressSend(WidgetTester tester, {bool retry = false}) async {
  final button = find.widgetWithText(
    FilledButton,
    retry ? 'Gửi lại cùng nội dung' : 'Gửi báo cáo',
  );
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> confirm(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận gửi'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Detail opens report for an ended auction and remembers receipt',
    (tester) async {
      var reports = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.method == 'POST') {
            expect(request.url.path, '/api/auctions/1107/report');
            reports++;
            return success();
          }
          expect(request.url.path, '/api/auctions/1107');
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': '1107',
                'listingId': '1115',
                'title': 'Phiên thử nghiệm',
                'seller': {'name': 'Người bán', 'rating': 4.9},
                'currentPrice': 100000,
                'startPrice': 100000,
                'minNextBid': 110000,
                'bidStep': 10000,
                'depositRequired': 10000,
                'depositAffordable': false,
                'bidCount': 0,
                'status': 'ended',
                'isLive': false,
                'paused': false,
                'remainingSeconds': 0,
                'joined': false,
                'leading': false,
                'won': false,
                'photos': [],
                'bids': [],
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: AuctionDetailScreen(
              auctionId: '1107',
              repository: AuctionRepository(api),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Báo cáo phiên'));
        await tester.pumpAndSettle();
        expect(find.byType(AuctionReportScreen), findsOneWidget);
        await enterReport(tester);
        await pressSend(tester);
        await confirm(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Quay lại phiên'));
        await tester.pumpAndSettle();
        expect(reports, 1);
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is IconButton &&
                      widget.tooltip == 'Đã báo cáo phiên này',
                ),
              )
              .onPressed,
          isNull,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        api.close();
      }
    },
  );
  for (final created in [true, false]) {
    test(
      'POST trims payload, uses token, accepts flagCreated=$created',
      () async {
        var calls = 0;
        final api = ApiClient(
          client: MockClient((request) async {
            calls++;
            expect(request.method, 'POST');
            expect(request.url.path, '/api/auctions/1107/report');
            expect(request.headers['Authorization'], 'Bearer bidder');
            expect(jsonDecode(request.body), {
              'reason': 'Nghi đẩy giá',
              'note': 'Đặt giá xen kẽ',
            });
            return success(created: created);
          }),
        )..token = 'bidder';
        addTearDown(api.close);
        await AuctionRepository(
          api,
        ).report('1107', reason: '  Nghi đẩy giá ', note: ' Đặt giá xen kẽ  ');
        expect(calls, 1);
      },
    );
  }
  test('Optional empty note is omitted', () async {
    final api = ApiClient(
      client: MockClient((request) async {
        expect(jsonDecode(request.body), {'reason': 'Test'});
        return success();
      }),
    );
    addTearDown(api.close);
    await AuctionRepository(api).report('1107', reason: 'Test', note: '   ');
  });
  test('Invalid input makes no request', () async {
    var calls = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        calls++;
        return success();
      }),
    );
    addTearDown(api.close);
    final repo = AuctionRepository(api);
    for (final id in ['', '../wallet', '1234567890123456789']) {
      await expectLater(
        repo.report(id, reason: 'Test'),
        throwsA(isA<ApiException>()),
      );
    }
    for (final reason in ['   ', 'a' * 101]) {
      await expectLater(
        repo.report('1107', reason: reason),
        throwsA(isA<ApiException>()),
      );
    }
    await expectLater(
      repo.report('1107', reason: 'Test', note: 'a' * 501),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 0);
  });
  for (final code in ['ALREADY_REPORTED', 'NOT_FOUND', 'VALIDATION_ERROR']) {
    test('Preserves $code without automatic retry', () async {
      var calls = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          calls++;
          return failure(code);
        }),
      );
      addTearDown(api.close);
      await expectLater(
        AuctionRepository(api).report('1107', reason: 'Test'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', code)),
      );
      expect(calls, 1);
    });
  }
  test('Unconfirmed success is rejected', () async {
    final api = ApiClient(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'success': true,
            'data': {'reported': false},
          }),
          201,
        ),
      ),
    );
    addTearDown(api.close);
    await expectLater(
      AuctionRepository(api).report('1107', reason: 'Test'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'INVALID_RESPONSE'),
      ),
    );
  });
  testWidgets(
    'Empty reason validates locally; cancelled dialog makes no POST',
    (tester) async {
      var calls = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          calls++;
          return success();
        }),
      );
      try {
        await showReport(tester, api);
        await pressSend(tester);
        expect(find.text('Vui lòng nhập lý do báo cáo.'), findsOneWidget);
        expect(calls, 0);
        await enterReport(tester);
        await pressSend(tester);
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
        await tester.pumpAndSettle();
        expect(calls, 0);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        api.close();
      }
    },
  );
  for (final duplicate in [false, true]) {
    testWidgets('Confirmed report shows receipt, duplicate=$duplicate', (
      tester,
    ) async {
      var calls = 0, callbacks = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          calls++;
          return duplicate
              ? failure('ALREADY_REPORTED')
              : success(created: false);
        }),
      );
      try {
        await showReport(tester, api, onReported: () => callbacks++);
        await enterReport(tester);
        await pressSend(tester);
        await confirm(tester);
        expect(calls, 1);
        expect(callbacks, 1);
        expect(
          find.text(
            duplicate
                ? 'Bạn đã báo cáo phiên này trước đó.'
                : 'Báo cáo đã được ghi nhận để quản trị viên xem xét.',
          ),
          findsOneWidget,
        );
        expect(find.byType(TextFormField), findsNothing);
        expect(
          find.text('Gửi báo cáo không tự động hủy hoặc dừng phiên đấu giá.'),
          findsOneWidget,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        api.close();
      }
    });
  }
  testWidgets(
    'Unknown delivery requires explicit retry with identical payload',
    (tester) async {
      final payloads = <String>[];
      final api = ApiClient(
        client: MockClient((request) async {
          payloads.add(request.body);
          if (payloads.length == 1) {
            throw http.ClientException('connection lost');
          }
          return failure('ALREADY_REPORTED');
        }),
      );
      try {
        await showReport(tester, api);
        await enterReport(tester);
        await pressSend(tester);
        await confirm(tester);
        await tester.pump(const Duration(seconds: 2));
        expect(payloads.length, 1);
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .enabled,
          false,
        );
        await pressSend(tester, retry: true);
        expect(payloads.length, 1);
        await confirm(tester);
        expect(payloads.length, 2);
        expect(payloads[1], payloads[0]);
        expect(find.text('Bạn đã báo cáo phiên này trước đó.'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        api.close();
      }
    },
  );
  testWidgets(
    'In-flight report disables sending and prevents back navigation',
    (tester) async {
      var calls = 0;
      final pending = Completer<http.Response>();
      final api = ApiClient(
        client: MockClient((request) async {
          calls++;
          return pending.future;
        }),
      );
      try {
        await showReport(tester, api);
        await enterReport(tester);
        await pressSend(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận gửi'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(calls, 1);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Đang gửi...'),
              )
              .onPressed,
          isNull,
        );
        expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, false);
        pending.complete(success());
        await tester.pumpAndSettle();
        expect(calls, 1);
      } finally {
        if (!pending.isCompleted) {
          pending.complete(success());
        }
        await tester.pumpWidget(const SizedBox.shrink());
        api.close();
      }
    },
  );
}
