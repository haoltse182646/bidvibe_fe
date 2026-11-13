import 'dart:convert';

import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/features/chat/chat_controller.dart';
import 'package:bidvibe/features/chat/chat_prompts.dart';
import 'package:bidvibe/features/chat/chat_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'chat_api_test.dart' as fixture;
import 'chat_screen_test.dart' as widgets;
import 'profile_screen_test.dart' as profile;

void main() {
  testWidgets(
      'Personal question is opt-in and follow-up preserves the same session',
      (tester) async {
    final bodies = <Map<String, dynamic>>[];
    final api = ApiClient(client: MockClient((request) async {
      final body = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
      bodies.add(body);
      final reply = fixture.thread(
          content: body['content'] as String, firstId: 60 + bodies.length * 2);
      (reply['messages'] as List)[1]['content'] = bodies.length == 1
          ? 'Số dư khả dụng trong ví của bạn là 50.000đ.'
          : 'Tiền cọc đang giữ sẽ trở lại số dư khả dụng khi bạn không thắng.';
      return fixture.ok(reply);
    }))
      ..token = 'bidder-token';
    final store = profile.ProfileTestStore(api);
    final chat = ChatController(
        repository: ChatRepository(api),
        accountId: '123',
        sessions: fixture.MemorySessions());
    try {
      await widgets.showChat(tester, store, chat);
      expect(bodies, isEmpty,
          reason: 'Opening chat must not query personal data automatically');
      await tester.tap(find.widgetWithText(ActionChip, 'Số dư ví'));
      await tester.pumpAndSettle();
      expect(bodies.single, {'content': ChatPrompts.personal.first.question});
      expect(find.text('Số dư khả dụng trong ví của bạn là 50.000đ.'),
          findsOneWidget);
      await tester
          .ensureVisible(find.widgetWithText(ActionChip, 'Còn gì nữa?'));
      await tester.tap(find.widgetWithText(ActionChip, 'Còn gì nữa?'));
      await tester.pumpAndSettle();
      expect(bodies.last, {'content': 'Còn gì nữa?', 'sessionId': '16'});
      expect(chat.messages, hasLength(4));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      chat.dispose();
      store.dispose();
    }
  });

  testWidgets(
      'Seller topic picker is usable on a narrow screen without bidder-only personal prompts',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bodies = <Map<String, dynamic>>[];
    final api = ApiClient(client: MockClient((request) async {
      final body = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
      bodies.add(body);
      return fixture.ok(fixture.thread(content: body['content'] as String));
    }))
      ..token = 'seller-token';
    final store = profile.ProfileTestStore(api, role: 'seller');
    final chat = ChatController(
        repository: ChatRepository(api),
        accountId: '123',
        sessions: fixture.MemorySessions());
    try {
      await widgets.showChat(tester, store, chat);
      await tester.tap(find.text('Tất cả chủ đề'));
      await tester.pumpAndSettle();
      expect(find.text('Bạn cần hỗ trợ gì?'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Số dư ví'), findsNothing);
      expect(find.widgetWithText(ActionChip, 'Cọc đang giữ'), findsNothing);
      final sheet = find.byType(BottomSheet);
      final selling = find.descendant(
          of: sheet,
          matching: find.widgetWithText(ActionChip, 'Đăng tin bán hàng'));
      await tester.tap(selling);
      await tester.pumpAndSettle();
      expect(bodies.single['content'], ChatPrompts.topics[10].question);
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      chat.dispose();
      store.dispose();
    }
  });
}
