import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/features/auctions/auction_repository.dart';
import 'package:bidvibe/features/auctions/auction_events.dart';
import 'package:bidvibe/features/auctions/auction_live_controller.dart';
import 'package:bidvibe/screens/bidder/auction_bid_panel.dart';

http.Response success(Map<String, dynamic> data, {int status = 200}) =>
    http.Response(
      jsonEncode({'success': true, 'data': data}),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> snapshot({
  int price = 100000,
  int seconds = 100,
  bool leading = false,
}) => {
  'id': '11',
  'status': 'active',
  'isLive': true,
  'paused': false,
  'currentPrice': price,
  'bidStep': 50000,
  'minNextBid': price + 50000,
  'bidCount': 1,
  'joined': true,
  'myDepositStatus': 'held',
  'leading': leading,
  'remainingSeconds': seconds,
  'endsAt': '2026-10-15T01:02:00Z',
};

class FakeEvents implements AuctionEvents {
  final controller = StreamController<AuctionEvent>.broadcast(sync: true);
  int connects = 0;
  bool closed = false;
  @override
  Stream<AuctionEvent> get stream => controller.stream;
  void send(String type, [Map<String, dynamic> data = const {}]) {
    if (!closed) {
      controller.add(AuctionEvent(type, data));
    }
  }

  @override
  void connect() {
    connects++;
  }

  @override
  void dispose() {
    if (!closed) {
      closed = true;
      scheduleMicrotask(() => unawaited(controller.close()));
    }
  }
}

void main() {
  test('Bid REST sends auctionId and amount only, with Bearer token', () async {
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/bids');
        expect(request.headers['Authorization'], 'Bearer bidder');
        expect(jsonDecode(request.body), {'auctionId': '11', 'amount': 150000});
        return success({
          'bidId': '1',
          'currentPrice': 150000,
          'extended': false,
        }, status: 201);
      }),
    )..token = 'bidder';
    addTearDown(api.close);
    await AuctionRepository(api).bid('11', 150000);
  });

  test('Successful bid reloads own leading state and does not allow self-outbidding', () async {
    var posted = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.method == 'POST') {
          posted++;
          return success({'bidId': '1', 'extended': true}, status: 201);
        }
        return success(
          snapshot(price: posted == 0 ? 100000 : 150000, leading: posted > 0),
        );
      }),
    );
    final c = AuctionLiveController(
      auctionId: '11',
      repository: AuctionRepository(api),
      autoTick: false,
    );
    addTearDown(() {
      c.dispose();
      api.close();
    });
    await c.start();
    expect(c.canBid, isTrue);
    expect(await c.bid(150000), isTrue);
    expect(c.data!['leading'], isTrue);
    expect(c.canBid, isFalse);
    expect(c.notice, contains('gia hạn'));
    expect(await c.bid(200000), isFalse);
    expect(posted, 1);
  });

  test(
    'Network failure never retries POST and requires explicit verification',
    () async {
      var posts = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.method == 'POST') {
            posts++;
            throw http.ClientException('Lost response');
          }
          return success(snapshot());
        }),
      );
      final c = AuctionLiveController(
        auctionId: '11',
        repository: AuctionRepository(api),
        autoTick: false,
      );
      addTearDown(() {
        c.dispose();
        api.close();
      });
      await c.start();
      expect(await c.bid(150000), isFalse);
      expect(c.uncertainBid, isTrue);
      expect(c.canBid, isFalse);
      expect(posts, 1);
      await c.refresh(verifyBid: true);
      expect(c.uncertainBid, isFalse);
      expect(posts, 1);
    },
  );

  test('Cannot bid before deposit, during pause, or below minimum', () async {
    var current = {...snapshot(), 'joined': false};
    var posts = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.method == 'POST') {
          posts++;
        }
        return success(current);
      }),
    );
    final c = AuctionLiveController(
      auctionId: '11',
      repository: AuctionRepository(api),
      autoTick: false,
    );
    addTearDown(() {
      c.dispose();
      api.close();
    });
    await c.start();
    expect(await c.bid(150000), isFalse);
    current = {...snapshot(), 'paused': true};
    await c.refresh();
    expect(await c.bid(150000), isFalse);
    current = snapshot();
    await c.refresh();
    expect(await c.bid(100000), isFalse);
    expect(posts, 0);
  });

  test(
    'Server BID_TOO_LOW refreshes minNextBid without retrying bid',
    () async {
      var posts = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.method == 'POST') {
            posts++;
            return http.Response(
              '{"success":false,"error":{"code":"BID_TOO_LOW","message":"Price changed"}}',
              400,
            );
          }
          return success(snapshot(price: posts == 0 ? 100000 : 200000));
        }),
      );
      final c = AuctionLiveController(
        auctionId: '11',
        repository: AuctionRepository(api),
        autoTick: false,
      );
      addTearDown(() {
        c.dispose();
        api.close();
      });
      await c.start();
      expect(await c.bid(150000), isFalse);
      expect(c.data!['minNextBid'], 250000);
      expect(c.notice, 'Price changed');
      expect(posts, 1);
    },
  );

  test(
    'Pause freezes countdown; resume continues from server remainingSeconds',
    () async {
      var moment = DateTime.utc(2026, 10, 15, 1);
      var current = snapshot(seconds: 120);
      final api = ApiClient(client: MockClient((_) async => success(current)));
      final events = FakeEvents();
      final c = AuctionLiveController(
        auctionId: '11',
        repository: AuctionRepository(api),
        events: events,
        autoTick: false,
        now: () => moment,
      );
      addTearDown(() {
        c.dispose();
        api.close();
      });
      await c.start();
      events.send('connected');
      await c.refresh();
      moment = moment.add(const Duration(seconds: 10));
      expect(c.remainingSeconds, 110);
      current = {...snapshot(seconds: 110), 'paused': true, 'isLive': false};
      events.send('auction:update', {
        'auctionId': '11',
        'reason': 'paused',
        'paused': true,
        'remainingSeconds': 110,
      });
      await c.refresh();
      moment = moment.add(const Duration(seconds: 50));
      expect(c.remainingSeconds, 110);
      expect(c.canBid, isFalse);
      current = snapshot(seconds: 110);
      events.send('auction:update', {
        'auctionId': '11',
        'reason': 'resumed',
        'paused': false,
        'remainingSeconds': 110,
      });
      await c.refresh();
      moment = moment.add(const Duration(seconds: 10));
      expect(c.remainingSeconds, 100);
    },
  );

  test(
    'Bid event adjusts anti-snipe deadline before REST refresh finishes',
    () async {
      var moment = DateTime.utc(2026, 10, 15, 1);
      final delayed = Completer<http.Response>();
      var defer = false;
      final initial = {
        ...snapshot(seconds: 20),
        'endsAt': '2026-10-15T01:00:20Z',
      };
      final api = ApiClient(
        client: MockClient(
          (_) async => defer ? await delayed.future : success(initial),
        ),
      );
      final events = FakeEvents();
      final c = AuctionLiveController(
        auctionId: '11',
        repository: AuctionRepository(api),
        events: events,
        autoTick: false,
        now: () => moment,
      );
      addTearDown(() {
        c.dispose();
        api.close();
      });
      await c.start();
      moment = moment.add(const Duration(seconds: 10));
      defer = true;
      events.send('auction:update', {
        'auctionId': '11',
        'reason': 'bid',
        'currentPrice': 150000,
        'bidCount': 2,
        'endsAt': '2026-10-15T01:00:40Z',
      });
      expect(c.remainingSeconds, 30);
      expect(c.data!['currentPrice'], 150000);
      delayed.complete(
        success({
          ...initial,
          'remainingSeconds': 30,
          'currentPrice': 150000,
          'endsAt': '2026-10-15T01:00:40Z',
        }),
      );
      await c.refresh();
    },
  );

  test(
    'An update arriving during a GET prevents that stale GET overwriting state',
    () async {
      final first = Completer<http.Response>();
      var gets = 0;
      final api = ApiClient(
        client: MockClient((_) async {
          gets++;
          return gets == 1 ? await first.future : success(snapshot(price: 300000));
        }),
      );
      final events = FakeEvents();
      final c = AuctionLiveController(
        auctionId: '11',
        repository: AuctionRepository(api),
        events: events,
        autoTick: false,
      );
      addTearDown(() {
        c.dispose();
        api.close();
      });
      final start = c.start();
      events.send('auction:update', {
        'auctionId': '11',
        'currentPrice': 300000,
      });
      first.complete(success(snapshot(price: 100000)));
      await start;
      expect(c.data!['currentPrice'], 300000);
      expect(gets, 2);
    },
  );

  test('Disconnect locks bids; reconnect reloads own leading state', () async {
    var current = snapshot();
    final api = ApiClient(client: MockClient((_) async => success(current)));
    final events = FakeEvents();
    final c = AuctionLiveController(
      auctionId: '11',
      repository: AuctionRepository(api),
      events: events,
      autoTick: false,
    );
    addTearDown(() {
      c.dispose();
      api.close();
    });
    await c.start();
    events.send('connected');
    await c.refresh();
    expect(c.canBid, isTrue);
    events.send('disconnected');
    expect(c.canBid, isFalse);
    current = snapshot(leading: true);
    events.send('connected');
    await c.refresh();
    expect(c.data!['leading'], isTrue);
    expect(c.connected, isTrue);
  });

  test('Ended event fetches the authoritative winner and stops bids', () async {
    var current = snapshot();
    final api = ApiClient(client: MockClient((_) async => success(current)));
    final events = FakeEvents();
    final c = AuctionLiveController(
      auctionId: '11',
      repository: AuctionRepository(api),
      events: events,
      autoTick: false,
    );
    addTearDown(() {
      c.dispose();
      api.close();
    });
    await c.start();
    current = {
      ...snapshot(seconds: 0),
      'status': 'ended',
      'isLive': false,
      'won': true,
    };
    events.send('auction:ended', {'auctionId': '11', 'hasWinner': true});
    expect(c.canBid, isFalse);
    await c.refresh();
    expect(c.data!['won'], isTrue);
  });

  test('Auth disconnection disposes transport and never reconnects', () async {
    final api = ApiClient(client: MockClient((_) async => success(snapshot())));
    final events = FakeEvents();
    final c = AuctionLiveController(
      auctionId: '11',
      repository: AuctionRepository(api),
      events: events,
      autoTick: false,
    );
    addTearDown(() {
      c.dispose();
      api.close();
    });
    await c.start();
    events.send('error', {'code': 'ACCOUNT_SUSPENDED'});
    c.resume();
    expect(c.authCode, 'ACCOUNT_SUSPENDED');
    expect(events.closed, isTrue);
    expect(events.connects, 1);
  });

  testWidgets('Confirmation is required before submitting an absolute bid', (
    tester,
  ) async {
    var posts = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.method == 'POST') {
          posts++;
          return success({'extended': false}, status: 201);
        }
        return success(
          snapshot(price: posts == 0 ? 100000 : 150000, leading: posts > 0),
        );
      }),
    );
    final c = AuctionLiveController(
      auctionId: '11',
      repository: AuctionRepository(api),
      autoTick: false,
    );
    await c.start();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedBuilder(
              animation: c,
              builder: (context, child) => AuctionBidPanel(controller: c),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Dùng giá tối thiểu'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Đặt giá'));
      await tester.pumpAndSettle();
      expect(posts, 0);
      await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận đặt giá'));
      await tester.pumpAndSettle();
      expect(posts, 1);
      expect(c.data!['leading'], isTrue);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
      api.close();
    }
  });
}
