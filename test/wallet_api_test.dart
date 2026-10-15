import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/features/wallet/wallet_repository.dart';
import 'package:bidvibe/screens/bidder/bidder_wallet.dart';

http.Response response(Map<String, dynamic> data, {int status = 200}) =>
    http.Response(
      jsonEncode({'success': true, 'data': data}),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> balances(int balance, {int held = 0}) => {
  'balance': balance,
  'held': held,
  'available': balance,
};

void main() {
  test('Available balance is already exclusive of held funds', () async {
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.url.path, '/api/wallet');
        expect(request.headers['Authorization'], 'Bearer bidder-token');
        return response(balances(800000, held: 200000));
      }),
    )..token = 'bidder-token';
    addTearDown(api.close);
    final wallet = await WalletRepository(api).wallet();
    expect(wallet.available, 800000);
    expect(wallet.held, 200000);
  });

  test(
    'Ledger query uses limit/offset and preserves positive amount',
    () async {
      final api = ApiClient(
        client: MockClient((request) async {
          expect(request.url.path, '/api/wallet/transactions');
          expect(request.url.queryParameters, {'limit': '20', 'offset': '20'});
          return response({
            'transactions': [
              {
                'id': '7',
                'kind': 'deposit_forfeit',
                'kindLabel': 'Mất cọc',
                'amount': 200000,
                'balanceAfter': 800000,
              },
            ],
            'total': 21,
          });
        }),
      );
      addTearDown(api.close);
      final page = await WalletRepository(api).transactions(offset: 20);
      expect(page.total, 21);
      expect(page.transactions.single['amount'], 200000);
    },
  );

  test(
    'Topup sends only amount and uses authoritative response balance',
    () async {
      var calls = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          calls++;
          expect(request.method, 'POST');
          expect(request.url.path, '/api/wallet/topup');
          expect(jsonDecode(request.body), {'amount': 500000});
          return response({
            ...balances(1230000, held: 200000),
            'transaction': {'id': '8'},
          }, status: 201);
        }),
      );
      addTearDown(api.close);
      final wallet = await WalletRepository(api).topup(500000);
      expect(wallet.available, 1230000);
      expect(calls, 1);
    },
  );

  test('Invalid amounts are rejected without HTTP', () async {
    var calls = 0;
    final api = ApiClient(
      client: MockClient((_) async {
        calls++;
        return response(balances(0));
      }),
    );
    addTearDown(api.close);
    for (final amount in [0, -1, 100000001]) {
      await expectLater(
        WalletRepository(api).topup(amount),
        throwsA(isA<ApiException>()),
      );
    }
    for (final input in ['', '1.5', '1,000', '-5', 'abc', '100000001']) {
      expect(WalletRepository.validateAmount(input), isNotNull);
    }
    expect(WalletRepository.validateAmount('1'), isNull);
    expect(WalletRepository.validateAmount('100000000'), isNull);
    expect(calls, 0);
  });

  test('Topup network failure is not automatically retried', () async {
    var calls = 0;
    final api = ApiClient(
      client: MockClient((_) async {
        calls++;
        throw http.ClientException('Connection lost');
      }),
    );
    addTearDown(api.close);
    await expectLater(
      WalletRepository(api).topup(100000),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'NETWORK')),
    );
    expect(calls, 1);
  });

  testWidgets(
    'Topup confirmation refreshes balance and creates one transaction',
    (tester) async {
      var balance = 0, postCalls = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.method == 'POST') {
            postCalls++;
            balance += jsonDecode(request.body)['amount'] as int;
            return response({
              ...balances(balance),
              'transaction': {'id': '1'},
            }, status: 201);
          }
          if (request.url.path == '/api/wallet') {
            return response(balances(balance));
          }
          return response({
            'transactions': postCalls == 0
                ? []
                : [
                    {
                      'id': '1',
                      'kindLabel': 'Nạp tiền vào ví',
                      'amount': 100000,
                      'balanceAfter': balance,
                      'createdAt': '2026-10-15T01:00:00Z',
                    },
                  ],
            'total': postCalls,
          });
        }),
      );
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BidderWalletScreen(repository: WalletRepository(api)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Chưa có giao dịch'), findsOneWidget);
        await tester.enterText(find.byType(TextFormField), '100000');
        final button = find.widgetWithText(FilledButton, 'Nạp tiền');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(postCalls, 0);
        await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận'));
        await tester.pumpAndSettle();
        expect(postCalls, 1);
        expect(balance, 100000);
        expect(
          (tester.widget<Text>(find.byKey(const Key('wallet-available')))).data,
          '100.000 đ',
        );
        await tester.scrollUntilVisible(find.text('Nạp tiền vào ví'), 300,
          scrollable: find.descendant(of: find.byType(ListView),
            matching: find.byType(Scrollable)).first);
        expect(find.text('Nạp tiền vào ví'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        api.close();
      }
    },
  );

  testWidgets(
    'Failed topup requires a wallet refresh before another submission',
    (tester) async {
      var postCalls = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.method == 'POST') {
            postCalls++;
            throw http.ClientException('Disconnected');
          }
          return request.url.path == '/api/wallet'
              ? response(balances(0))
              : response({'transactions': [], 'total': 0});
        }),
      );
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BidderWalletScreen(repository: WalletRepository(api)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), '100000');
        final button = find.widgetWithText(FilledButton, 'Nạp tiền');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận'));
        await tester.pumpAndSettle();
        expect(postCalls, 1);
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        api.close();
      }
    },
  );
}
