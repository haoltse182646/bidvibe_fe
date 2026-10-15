import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/features/auctions/auction_events.dart';
import 'package:bidvibe/features/notifications/notification_controller.dart';
import 'package:bidvibe/features/notifications/notification_repository.dart';
import 'package:bidvibe/screens/bidder/bidder_notifications.dart';

http.Response ok(Map<String, dynamic> data) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
Map<String, dynamic> item(
  String id, {
  bool read = false,
  Map<String, dynamic>? data,
}) => {
  'id': id,
  'type': 'outbid',
  'title': 'Thông báo $id',
  'isRead': read,
  'createdAt': '2026-10-15T01:00:00Z',
  'data': data,
};
Map<String, dynamic> page(List<Map<String, dynamic>> items, int count) => {
  'notifications': items,
  'unreadCount': count,
};

class FakeNotificationEvents implements AuctionEvents {
  final controller = StreamController<AuctionEvent>.broadcast(sync: true);
  bool closed = false;
  int connects = 0;
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
  test(
    'List uses Bearer, limit/offset and unreadCount without assuming total',
    () async {
      final api = ApiClient(
        client: MockClient((request) async {
          expect(request.url.path, '/api/notifications');
          expect(request.url.queryParameters, {'limit': '20', 'offset': '20'});
          expect(request.headers['Authorization'], 'Bearer bidder');
          return ok(page([item('1')], 51));
        }),
      )..token = 'bidder';
      addTearDown(api.close);
      final result = await NotificationRepository(api).list(offset: 20);
      expect(result.items.single.id, '1');
      expect(result.unreadCount, 51);
      expect(result.items.single.data, isNull);
    },
  );

  test('Read endpoints use POST with no body', () async {
    final paths = <String>[];
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.body, isEmpty);
        paths.add(request.url.path);
        return request.url.path.endsWith('read-all')
            ? ok({'updated': 3})
            : ok({'id': '1', 'isRead': true});
      }),
    );
    addTearDown(api.close);
    final repo = NotificationRepository(api);
    await repo.markRead('1');
    expect(await repo.markAllRead(), 3);
    expect(paths, ['/api/notifications/1/read', '/api/notifications/read-all']);
  });

  test(
    'Target uses data key priority, not type; null and malformed IDs are safe',
    () {
      expect(NotificationTarget.fromData(null), isNull);
      expect(NotificationTarget.fromData({'auctionId': '../me'}), isNull);
      expect(NotificationTarget.fromData({'auctionId': '9'})!.kind, 'auction');
      final target = NotificationTarget.fromData({
        'auctionId': '9',
        'orderId': '8',
        'disputeId': '7',
      });
      expect(target!.kind, 'dispute');
      expect(target.id, '7');
      expect(
        NotificationTarget.fromData({'orderId': '8', 'auctionId': '9'})!.kind,
        'order',
      );
    },
  );

  test('Initial load does not mark anything read; global unread count may exceed page size', () async {
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        return ok(page([item('1')], 40));
      }),
    );
    final c = NotificationController(repository: NotificationRepository(api));
    addTearDown(() {
      c.dispose();
      api.close();
    });
    await c.start();
    expect(c.unreadCount, 40);
    expect(c.items.single.isRead, isFalse);
  });

  test('Pagination without total stops after a short page', () async {
    final offsets = <int>[];
    final api = ApiClient(
      client: MockClient((request) async {
        final offset = int.parse(request.url.queryParameters['offset']!);
        offsets.add(offset);
        return ok(
          page(
            List.generate(
              offset == 0 ? 20 : 3,
              (i) => item('${i + offset + 1}'),
            ),
            23,
          ),
        );
      }),
    );
    final c = NotificationController(repository: NotificationRepository(api));
    addTearDown(() {
      c.dispose();
      api.close();
    });
    await c.start();
    expect(c.hasMore, isTrue);
    await c.more();
    expect(c.items.length, 23);
    expect(c.hasMore, isFalse);
    expect(offsets, [0, 20]);
  });

  test('Mark one updates from server, and marking an already read item does not POST again', () async {
    var read = false, posts = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.method == 'POST') {
          posts++;
          read = true;
          return ok({'id': '1', 'isRead': true});
        }
        return ok(page([item('1', read: read)], read ? 0 : 1));
      }),
    );
    final c = NotificationController(repository: NotificationRepository(api));
    addTearDown(() {
      c.dispose();
      api.close();
    });
    await c.start();
    expect(await c.markRead(c.items.single), isTrue);
    expect(c.unreadCount, 0);
    expect(c.items.single.isRead, isTrue);
    await c.markRead(c.items.single);
    expect(posts, 1);
  });

  test('Duplicate socket events do not duplicate the list or increment badge twice', () async {
    var current = page([], 0);
    final api = ApiClient(client: MockClient((_) async => ok(current)));
    final events = FakeNotificationEvents();
    final c = NotificationController(
      repository: NotificationRepository(api),
      events: events,
    );
    addTearDown(() {
      c.dispose();
      api.close();
    });
    await c.start();
    current = page([item('2')], 1);
    events.send('notification:new', item('2'));
    events.send('notification:new', item('2'));
    expect(c.unreadCount, 1);
    await c.refresh();
    expect(c.items.length, 1);
    expect(c.unreadCount, 1);
    expect(c.toast!.id, '2');
  });

  test('Reconnect fetches notifications missed while offline', () async {
    var current = page([], 0);
    final api = ApiClient(client: MockClient((_) async => ok(current)));
    final events = FakeNotificationEvents();
    final c = NotificationController(
      repository: NotificationRepository(api),
      events: events,
    );
    addTearDown(() {
      c.dispose();
      api.close();
    });
    await c.start();
    events.send('disconnected');
    current = page([item('3')], 1);
    events.send('connected');
    await c.refresh();
    expect(c.connected, isTrue);
    expect(c.items.single.id, '3');
    expect(c.unreadCount, 1);
  });

  test('Read-all refresh preserves a new notification not included in the server update', () async {
    var current = page([item('1')], 1);
    final pending = Completer<http.Response>();
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.method == 'POST') {
          return await pending.future;
        }
        return ok(current);
      }),
    );
    final events = FakeNotificationEvents();
    final c = NotificationController(
      repository: NotificationRepository(api),
      events: events,
    );
    addTearDown(() {
      c.dispose();
      api.close();
    });
    await c.start();
    final marking = c.markAllRead();
    current = page([item('2'), item('1', read: true)], 1);
    events.send('notification:new', item('2'));
    pending.complete(ok({'updated': 1}));
    await marking;
    expect(c.unreadCount, 1);
    expect(c.items.first.isRead, isFalse);
  });

  test('A rejected read request does not mark the item locally', () async {
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            '{"success":false,"error":{"code":"NOT_FOUND","message":"Missing"}}',
            404,
          );
        }
        return ok(page([item('1')], 1));
      }),
    );
    final c = NotificationController(repository: NotificationRepository(api));
    addTearDown(() {
      c.dispose();
      api.close();
    });
    await c.start();
    expect(await c.markRead(c.items.single), isFalse);
    expect(c.items.single.isRead, isFalse);
    expect(c.unreadCount, 1);
  });

  test(
    'Suspension closes the session transport and prevents reconnect',
    () async {
      final api = ApiClient(client: MockClient((_) async => ok(page([], 0))));
      final events = FakeNotificationEvents();
      final c = NotificationController(
        repository: NotificationRepository(api),
        events: events,
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
    },
  );

  testWidgets(
    'Opening the list does not auto-read; explicit read-all updates the list',
    (tester) async {
      var read = false, posts = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.method == 'POST') {
            posts++;
            read = true;
            return ok({'updated': 1});
          }
          return ok(page([item('1', read: read)], read ? 0 : 1));
        }),
      );
      final c = NotificationController(repository: NotificationRepository(api));
      await c.start();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BidderNotificationsScreen(
                controller: c,
                onOpen: (item) async {
                  await c.markRead(item);
                },
              ),
            ),
          ),
        );
        expect(posts, 0);
        expect(find.text('1 thông báo chưa đọc'), findsOneWidget);
        await tester.tap(find.text('Đánh dấu tất cả đã đọc'));
        await tester.pumpAndSettle();
        expect(posts, 1);
        expect(find.text('0 thông báo chưa đọc'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        c.dispose();
        api.close();
      }
    },
  );

  testWidgets(
    'A notification with null data can be selected and marked read safely',
    (tester) async {
      var read = false;
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.method == 'POST') {
            read = true;
            return ok({'id': '1', 'isRead': true});
          }
          return ok(page([item('1', read: read)], read ? 0 : 1));
        }),
      );
      final c = NotificationController(repository: NotificationRepository(api));
      await c.start();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BidderNotificationsScreen(
                controller: c,
                onOpen: (item) async {
                  await c.markRead(item);
                  expect(NotificationTarget.fromData(item.data), isNull);
                },
              ),
            ),
          ),
        );
        await tester.tap(find.text('Thông báo 1'));
        await tester.pumpAndSettle();
        expect(c.items.single.isRead, isTrue);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        c.dispose();
        api.close();
      }
    },
  );
}
