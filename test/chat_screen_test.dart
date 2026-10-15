import 'dart:async';
import 'dart:convert';

import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/features/chat/chat_controller.dart';
import 'package:bidvibe/features/chat/chat_repository.dart';
import 'package:bidvibe/screens/auth/auth_profile.dart';
import 'package:bidvibe/screens/customer/customer_chatbot.dart';
import 'package:bidvibe/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'chat_api_test.dart' as fixture;
import 'profile_api_test.dart' as profile_fixture;
import 'profile_screen_test.dart' as profile_widgets;

Future<void> showChat(
  WidgetTester tester,
  profile_widgets.ProfileTestStore store,
  ChatController chat,
) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: MaterialApp(home: CustomerChatbotScreen(controller: chat)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> ask(WidgetTester tester, String content) async {
  await tester.enterText(find.byKey(const ValueKey('chat.input')), content);
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Gửi'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Chat renders server answer, reuses session and refreshes without duplicate bubbles',
    (tester) async {
      var posts = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.method == 'POST') {
            posts++;
            final body = jsonDecode(request.body) as Map;
            return fixture.ok(
              fixture.thread(content: body['content'] as String),
            );
          }
          return fixture.ok(fixture.thread());
        }),
      )..token = 'A';
      final store = profile_widgets.ProfileTestStore(api);
      final chat = ChatController(
        repository: ChatRepository(api),
        accountId: '123',
        sessions: fixture.MemorySessions(),
      );
      try {
        await showChat(tester, store, chat);
        expect(posts, 0);
        await ask(tester, 'Đặt cọc thế nào?');
        expect(posts, 1);
        expect(find.text('Câu trả lời từ máy chủ'), findsOneWidget);
        expect(find.text('Hội thoại #16'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('chat.input')))
              .controller!
              .text,
          isEmpty,
        );
        await tester.tap(find.byTooltip('Tải lại lịch sử'));
        await tester.pumpAndSettle();
        expect(posts, 1);
        expect(find.byKey(const ValueKey('chat.message.61')), findsOneWidget);
        expect(find.byKey(const ValueKey('chat.message.62')), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        chat.dispose();
        store.dispose();
      }
    },
  );
  testWidgets(
    'New conversation cancel preserves history, confirm waits for first question before POST',
    (tester) async {
      var posts = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.method == 'POST') {
            posts++;
          }
          return fixture.ok(fixture.thread());
        }),
      )..token = 'A';
      final store = profile_widgets.ProfileTestStore(api);
      final sessions = fixture.MemorySessions();
      final chat = ChatController(
        repository: ChatRepository(api),
        accountId: '123',
        sessions: sessions,
      );
      sessions.values[chat.scope] = '16';
      try {
        await showChat(tester, store, chat);
        await tester.tap(find.byTooltip('Hội thoại mới'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
        await tester.pumpAndSettle();
        expect(chat.sessionId, '16');
        await tester.tap(find.byTooltip('Hội thoại mới'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Bắt đầu mới'));
        await tester.pumpAndSettle();
        expect(chat.sessionId, isNull);
        expect(chat.messages, isEmpty);
        expect(posts, 0);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        chat.dispose();
        store.dispose();
      }
    },
  );
  testWidgets(
    'Pending send disables input and back; repeated taps do not POST twice',
    (tester) async {
      final pending = Completer<http.Response>();
      var posts = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          posts++;
          return pending.future;
        }),
      )..token = 'A';
      final store = profile_widgets.ProfileTestStore(api);
      final chat = ChatController(
        repository: ChatRepository(api),
        accountId: '123',
        sessions: fixture.MemorySessions(),
      );
      try {
        await showChat(tester, store, chat);
        await tester.enterText(
          find.byKey(const ValueKey('chat.input')),
          'Test',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Gửi'));
        await tester.pump(const Duration(milliseconds: 250));
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('chat.input')))
              .enabled,
          false,
        );
        expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, false);
        expect(posts, 1);
        pending.complete(fixture.ok(fixture.thread(content: 'Test')));
        await tester.pumpAndSettle();
        expect(posts, 1);
        expect(chat.messages.length, 2);
      } finally {
        if (!pending.isCompleted) {
          pending.complete(fixture.ok(fixture.thread(content: 'Test')));
        }
        await tester.pumpWidget(const SizedBox.shrink());
        chat.dispose();
        store.dispose();
      }
    },
  );
  testWidgets(
    'Unknown send retains draft and requires history acknowledgement before continuing',
    (tester) async {
      var posts = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.method == 'POST') {
            posts++;
            throw http.ClientException('lost');
          }
          return fixture.ok(fixture.thread());
        }),
      )..token = 'A';
      final store = profile_widgets.ProfileTestStore(api);
      final sessions = fixture.MemorySessions();
      final chat = ChatController(
        repository: ChatRepository(api),
        accountId: '123',
        sessions: sessions,
      );
      sessions.values[chat.scope] = '16';
      try {
        await showChat(tester, store, chat);
        await ask(tester, 'Câu hỏi mới');
        expect(posts, 1);
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('chat.input')))
              .controller!
              .text,
          'Câu hỏi mới',
        );
        await tester.tap(find.text('Kiểm tra lịch sử'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tôi đã kiểm tra, tiếp tục'));
        await tester.pumpAndSettle();
        expect(chat.canSend, true);
        expect(posts, 1);
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('chat.input')))
              .controller!
              .text,
          isEmpty,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        chat.dispose();
        store.dispose();
      }
    },
  );
  testWidgets(
    'Chat authorization failure logs out instead of giving a fabricated answer',
    (tester) async {
      final api = ApiClient(
        client: MockClient(
          (request) async => fixture.fail('UNAUTHORIZED', status: 401),
        ),
      )..token = 'A';
      final store = profile_widgets.ProfileTestStore(api);
      final chat = ChatController(
        repository: ChatRepository(api),
        accountId: '123',
        sessions: fixture.MemorySessions(),
      );
      try {
        await showChat(tester, store, chat);
        await ask(tester, 'Test');
        expect(store.loggedOut, true);
        expect(chat.messages, isEmpty);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        chat.dispose();
        store.dispose();
      }
    },
  );
  testWidgets(
    'Old profile support tile opens real chat and restores its history when reopened',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      var posts = 0, historyGets = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.url.path == '/api/me') {
            return profile_fixture.ok(profile_fixture.profile());
          }
          if (request.url.path == '/api/addresses') {
            return fixture.ok({
              'addresses': [
                {
                  'id': '7',
                  'isDefault': true,
                  'addressLine': 'Địa chỉ thật',
                  'city': 'TP.HCM',
                },
              ],
            });
          }
          if (request.url.path == '/api/orders/mine') {
            return fixture.ok({'orders': []});
          }
          if (request.method == 'POST') {
            posts++;
            return fixture.ok(
              fixture.thread(
                content: (jsonDecode(request.body) as Map)['content'] as String,
              ),
            );
          }
          historyGets++;
          return fixture.ok(fixture.thread());
        }),
      )..token = 'A';
      final store = profile_widgets.ProfileTestStore(api);
      try {
        await profile_widgets.showProfile(tester, store);
        expect(find.text('Địa chỉ thật, TP.HCM'), findsOneWidget);
        await profile_widgets.tapLabel(tester, 'Trợ lý hỗ trợ BidVibe');
        expect(find.byType(CustomerChatbotScreen), findsOneWidget);
        expect(posts, 0);
        await ask(tester, 'Đặt cọc thế nào?');
        expect(posts, 1);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(AuthProfileScreen), findsOneWidget);
        await profile_widgets.tapLabel(tester, 'Trợ lý hỗ trợ BidVibe');
        expect(historyGets, 1);
        expect(posts, 1);
        expect(find.text('Câu trả lời từ máy chủ'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        store.dispose();
      }
    },
  );
  testWidgets('Chat adapts to a phone viewport and keyboard without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = ApiClient(
      client: MockClient((request) async => fixture.ok(fixture.thread())),
    )..token = 'A';
    final store = profile_widgets.ProfileTestStore(api);
    final chat = ChatController(
      repository: ChatRepository(api),
      accountId: '123',
      sessions: fixture.MemorySessions(),
    );
    try {
      await showChat(tester, store, chat);
      await tester.tap(find.byKey(const ValueKey('chat.input')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      chat.dispose();
      store.dispose();
    }
  });
}
