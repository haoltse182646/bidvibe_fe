import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/core/remote_app_store.dart';
import 'package:bidvibe/models.dart';
import 'package:bidvibe/store.dart';
import 'package:bidvibe/features/auctions/auction_events.dart';
import 'package:bidvibe/features/notifications/notification_controller.dart';
import 'package:bidvibe/features/notifications/notification_repository.dart';
import 'package:bidvibe/screens/bidder/bidder_shell.dart';

class TestRemoteStore extends RemoteAppStore {
  final ApiClient _testApi;
  @override
  ApiClient get api => _testApi;
  TestRemoteStore(this._testApi) : super(restoreOnStart: false);
}

class FakeShellEvents implements AuctionEvents {
  final controller = StreamController<AuctionEvent>.broadcast(sync: true);
  bool closed = false;
  @override
  Stream<AuctionEvent> get stream => controller.stream;
  @override
  void connect() {}
  void send(Map<String, dynamic> data) =>
      controller.add(AuctionEvent('notification:new', data));
  @override
  void dispose() {
    if (!closed) {
      closed = true;
      scheduleMicrotask(() => unawaited(controller.close()));
    }
  }
}

void main() {
  testWidgets(
    'Bidder shell uses the server badge, reads on selection and receives events across tabs',
    (tester) async {
      var read = false, newNotification = false, posts = 0;
      Map<String, dynamic> notification(String id, bool isRead) => {
        'id': id,
        'title': 'Thông báo $id',
        'type': 'info',
        'isRead': isRead,
        'createdAt': '2026-10-15T01:00:00Z',
        'data': null,
      };
      final api = ApiClient(
        client: MockClient((request) async {
          Map<String, dynamic> data;
          if (request.method == 'POST') {
            posts++;
            read = true;
            data = {'id': '1', 'isRead': true};
          } else {
            data = switch (request.url.path) {
              '/api/categories' => {'categories': []},
              '/api/auctions' => {'auctions': [], 'total': 0},
              '/api/wallet' => {'balance': 0, 'held': 0, 'available': 0},
              '/api/wallet/transactions' => {'transactions': [], 'total': 0},
              '/api/notifications' => {
                'notifications': [
                  if (newNotification) notification('2', false),
                  notification('1', read),
                ],
                'unreadCount': (read ? 0 : 1) + (newNotification ? 1 : 0),
              },
              _ => throw StateError('Unexpected API ${request.url}'),
            };
          }
          return http.Response(
            jsonEncode({'success': true, 'data': data}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      )..token = 'test-token';
      final store = TestRemoteStore(api);
      store.currentUser = UserAccount(
        id: '123',
        name: 'Test bidder',
        email: 'test@example.com',
        role: 'bidder',
      );
      final events = FakeShellEvents();
      final c = NotificationController(
        repository: NotificationRepository(api),
        events: events,
      );
      try {
        await tester.pumpWidget(
          ChangeNotifierProvider<AppStore>.value(
            value: store,
            child: MaterialApp(home: BidderShell(notifications: c)),
          ),
        );
        await tester.pumpAndSettle();
        expect(posts, 0);
        expect(c.unreadCount, 1);
        await tester.tap(find.text('Thông báo'));
        await tester.pumpAndSettle();
        expect(find.text('1 thông báo chưa đọc'), findsOneWidget);
        expect(posts, 0);
        await tester.tap(find.text('Thông báo 1'));
        await tester.pumpAndSettle();
        expect(posts, 1);
        expect(c.unreadCount, 0);
        await tester.tap(find.text('Khám phá'));
        await tester.pumpAndSettle();
        newNotification = true;
        events.send(notification('2', false));
        await tester.pumpAndSettle();
        expect(find.text('Thông báo 2'), findsOneWidget);
        expect(c.unreadCount, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        c.dispose();
        store.dispose();
      }
    },
  );
}
