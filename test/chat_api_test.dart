import 'dart:async';
import 'dart:convert';

import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/features/chat/chat_controller.dart';
import 'package:bidvibe/features/chat/chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response ok(Map<String, dynamic> data) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
http.Response fail(String code, {int status = 400}) => http.Response(
  jsonEncode({
    'success': false,
    'error': {'code': code, 'message': code},
  }),
  status,
);
Map<String, dynamic> thread({
  String session = '16',
  String content = 'Đặt cọc thế nào?',
  int firstId = 61,
}) => {
  'sessionId': session,
  'messages': [
    {
      'id': '$firstId',
      'sender': 'user',
      'content': content,
      'createdAt': '2026-10-15T01:00:00Z',
    },
    {
      'id': '${firstId + 1}',
      'sender': 'bot',
      'content': 'Câu trả lời từ máy chủ',
      'createdAt': '2026-10-15T01:00:00Z',
    },
  ],
};

class MemorySessions implements ChatSessionStore {
  final values = <String, String>{};
  bool failWrite = false;
  @override
  Future<String?> read(String scope) async => values[scope];
  @override
  Future<void> write(String scope, String? sessionId) async {
    if (failWrite) {
      throw StateError('storage unavailable');
    }
    if (sessionId == null) {
      values.remove(scope);
    } else {
      values[scope] = sessionId;
    }
  }
}

void main() {
  test(
    'First POST omits sessionId, trims content and uses current token',
    () async {
      final api = ApiClient(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/chat/messages');
          expect(request.headers['Authorization'], 'Bearer A');
          expect(jsonDecode(request.body), {'content': 'Đặt cọc thế nào?'});
          return ok(thread());
        }),
      )..token = 'A';
      addTearDown(api.close);
      final result = await ChatRepository(api).send('  Đặt cọc thế nào?  ');
      expect(result.sessionId, '16');
      expect(result.messages.last.content, 'Câu trả lời từ máy chủ');
    },
  );
  test(
    'Next POST includes sessionId; GET history uses owning-session path',
    () async {
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.method == 'POST') {
            expect(jsonDecode(request.body), {
              'content': 'Đặt cọc thế nào?',
              'sessionId': '16',
            });
          } else {
            expect(request.url.path, '/api/chat/sessions/16/messages');
          }
          return ok(thread());
        }),
      );
      addTearDown(api.close);
      await ChatRepository(api).send('Đặt cọc thế nào?', sessionId: '16');
      expect((await ChatRepository(api).history('16')).messages.length, 2);
    },
  );
  test('Invalid content and IDs make no requests', () async {
    var calls = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        calls++;
        return ok(thread());
      }),
    );
    addTearDown(api.close);
    final repo = ChatRepository(api);
    for (final content in ['', '  ', 'a' * 2001]) {
      await expectLater(repo.send(content), throwsA(isA<ApiException>()));
    }
    for (final id in ['../me', '0', '-1', '1234567890123456789']) {
      await expectLater(
        repo.send('Test', sessionId: id),
        throwsA(isA<ApiException>()),
      );
      await expectLater(repo.history(id), throwsA(isA<ApiException>()));
    }
    expect(calls, 0);
  });
  for (final code in [
    'VALIDATION_ERROR',
    'FORBIDDEN',
    'UNAUTHORIZED',
    'ACCOUNT_SUSPENDED',
    'NOT_FOUND',
  ]) {
    test('POST preserves $code without retry', () async {
      var calls = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          calls++;
          return fail(code);
        }),
      );
      addTearDown(api.close);
      await expectLater(
        ChatRepository(api).send('Test'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', code)),
      );
      expect(calls, 1);
    });
  }
  test(
    'Mismatched session or malformed reply never generates a local answer',
    () async {
      final api = ApiClient(
        client: MockClient((request) async => ok(thread(session: '99'))),
      );
      addTearDown(api.close);
      await expectLater(
        ChatRepository(api).send('Đặt cọc thế nào?', sessionId: '16'),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        ChatRepository(api).history('16'),
        throwsA(isA<ApiException>()),
      );
      expect(
        () => ChatThread.fromJson({
          'sessionId': '16',
          'messages': [
            {'id': '1', 'sender': 'admin', 'content': 'bad'},
          ],
        }),
        throwsA(isA<ApiException>()),
      );
    },
  );
  test('Opening a new chat makes no HTTP request or server session', () async {
    var calls = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        calls++;
        return ok(thread());
      }),
    )..token = 'A';
    final chat = ChatController(
      repository: ChatRepository(api),
      accountId: '123',
      sessions: MemorySessions(),
    );
    try {
      await chat.load();
      expect(chat.canSend, true);
      expect(calls, 0);
      expect(chat.messages, isEmpty);
    } finally {
      chat.dispose();
      api.close();
    }
  });
  test(
    'Accepted POST persists session, next POST stays in that conversation',
    () async {
      var posts = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          posts++;
          final body = jsonDecode(request.body) as Map;
          expect(body['sessionId'], posts == 1 ? isNull : '16');
          return ok(
            thread(content: body['content'] as String, firstId: posts * 2),
          );
        }),
      )..token = 'A';
      final sessions = MemorySessions();
      final chat = ChatController(
        repository: ChatRepository(api),
        accountId: '123',
        sessions: sessions,
      );
      try {
        await chat.load();
        expect(await chat.send('First'), true);
        expect(await chat.send('Second'), true);
        expect(sessions.values[chat.scope], '16');
        expect(chat.messages.length, 4);
        expect(posts, 2);
      } finally {
        chat.dispose();
        api.close();
      }
    },
  );
  test(
    'Reload restores server history rather than adding another POST',
    () async {
      var gets = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          gets++;
          return ok(thread());
        }),
      )..token = 'A';
      final sessions = MemorySessions();
      final chat = ChatController(
        repository: ChatRepository(api),
        accountId: '123',
        sessions: sessions,
      );
      sessions.values[chat.scope] = '16';
      try {
        await chat.load();
        await chat.load();
        expect(gets, 2);
        expect(chat.messages.length, 2);
      } finally {
        chat.dispose();
        api.close();
      }
    },
  );
  test('Last session is scoped to backend and account', () async {
    final api = ApiClient(client: MockClient((request) async => ok(thread())))
      ..token = 'A';
    final sessions = MemorySessions();
    final a = ChatController(
      repository: ChatRepository(api),
      accountId: '123',
      sessions: sessions,
    );
    final b = ChatController(
      repository: ChatRepository(api),
      accountId: '999',
      sessions: sessions,
    );
    sessions.values[a.scope] = '16';
    try {
      await a.load();
      await b.load();
      expect(a.sessionId, '16');
      expect(b.sessionId, isNull);
      expect(b.messages, isEmpty);
    } finally {
      a.dispose();
      b.dispose();
      api.close();
    }
  });
  test('Missing or foreign session resets local pointer after 404, without creating one', () async {
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        return fail('NOT_FOUND', status: 404);
      }),
    )..token = 'A';
    final sessions = MemorySessions();
    final chat = ChatController(
      repository: ChatRepository(api),
      accountId: '123',
      sessions: sessions,
    );
    sessions.values[chat.scope] = '16';
    try {
      await chat.load();
      expect(chat.sessionId, isNull);
      expect(chat.canSend, true);
      expect(sessions.values, isEmpty);
    } finally {
      chat.dispose();
      api.close();
    }
  });
  test(
    'Unknown first POST result cannot retry blindly or invent a session ID',
    () async {
      var posts = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          posts++;
          throw http.ClientException('lost response');
        }),
      )..token = 'A';
      final chat = ChatController(
        repository: ChatRepository(api),
        accountId: '123',
        sessions: MemorySessions(),
      );
      try {
        await chat.load();
        expect(await chat.send('First'), false);
        expect(chat.uncertain, true);
        expect(chat.sessionId, isNull);
        expect(await chat.send('First'), false);
        expect(posts, 1);
        expect(await chat.newConversation(), true);
        expect(posts, 1);
        expect(chat.canSend, true);
      } finally {
        chat.dispose();
        api.close();
      }
    },
  );
  test('Unknown existing-session result requires history and explicit acknowledgement', () async {
    var posts = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.method == 'POST') {
          posts++;
          throw http.ClientException('lost response');
        }
        return ok(thread());
      }),
    )..token = 'A';
    final sessions = MemorySessions();
    final chat = ChatController(
      repository: ChatRepository(api),
      accountId: '123',
      sessions: sessions,
    );
    sessions.values[chat.scope] = '16';
    try {
      await chat.load();
      await chat.send('Question');
      expect(chat.uncertain, true);
      chat.acknowledgeHistory();
      expect(chat.canSend, false);
      await chat.load();
      expect(chat.historyChecked, true);
      expect(chat.canSend, false);
      expect(posts, 1);
      chat.acknowledgeHistory();
      expect(chat.canSend, true);
      expect(posts, 1);
    } finally {
      chat.dispose();
      api.close();
    }
  });
  test('Rapid second send while pending creates only one POST', () async {
    var posts = 0;
    final pending = Completer<http.Response>();
    final api = ApiClient(
      client: MockClient((request) async {
        posts++;
        return pending.future;
      }),
    )..token = 'A';
    final chat = ChatController(
      repository: ChatRepository(api),
      accountId: '123',
      sessions: MemorySessions(),
    );
    try {
      await chat.load();
      final first = chat.send('First');
      expect(await chat.send('Second'), false);
      await Future<void>.delayed(Duration.zero);
      expect(posts, 1);
      pending.complete(ok(thread(content: 'First')));
      expect(await first, true);
      expect(chat.messages.length, 2);
    } finally {
      if (!pending.isCompleted) {
        pending.complete(ok(thread(content: 'First')));
      }
      chat.dispose();
      api.close();
    }
  });
  test('Successful POST with local storage failure stays successful', () async {
    final api = ApiClient(client: MockClient((request) async => ok(thread())))
      ..token = 'A';
    final sessions = MemorySessions();
    final chat = ChatController(
      repository: ChatRepository(api),
      accountId: '123',
      sessions: sessions,
    );
    try {
      await chat.load();
      sessions.failWrite = true;
      expect(await chat.send('Đặt cọc thế nào?'), true);
      expect(chat.sessionId, '16');
      expect(chat.uncertain, false);
      expect(chat.warning, isNotNull);
    } finally {
      chat.dispose();
      api.close();
    }
  });
  for (final code in ['UNAUTHORIZED', 'ACCOUNT_SUSPENDED']) {
    test('$code stops further chat actions', () async {
      final api = ApiClient(client: MockClient((request) async => fail(code)))
        ..token = 'A';
      final chat = ChatController(
        repository: ChatRepository(api),
        accountId: '123',
        sessions: MemorySessions(),
      );
      try {
        await chat.load();
        await chat.send('Test');
        expect(chat.authCode, code);
        expect(chat.canSend, false);
      } finally {
        chat.dispose();
        api.close();
      }
    });
  }
  test('Late response after token change cannot populate old chat or write a pointer', () async {
    final pending = Completer<http.Response>();
    final sessions = MemorySessions();
    final api = ApiClient(client: MockClient((request) async => pending.future))
      ..token = 'A';
    final chat = ChatController(
      repository: ChatRepository(api),
      accountId: '123',
      sessions: sessions,
    );
    try {
      await chat.load();
      final result = chat.send('Test');
      api.token = 'B';
      pending.complete(ok(thread(content: 'Test')));
      expect(await result, false);
      expect(chat.messages, isEmpty);
      expect(sessions.values, isEmpty);
    } finally {
      if (!pending.isCompleted) {
        pending.complete(ok(thread(content: 'Test')));
      }
      chat.dispose();
      api.close();
    }
  });
  test('History connection failure locks input and never falls back to demo messages', () async {
    final api = ApiClient(
      client: MockClient(
        (request) async => throw http.ClientException('offline'),
      ),
    )..token = 'A';
    final sessions = MemorySessions();
    final chat = ChatController(
      repository: ChatRepository(api),
      accountId: '123',
      sessions: sessions,
    );
    sessions.values[chat.scope] = '16';
    try {
      await chat.load();
      expect(chat.ready, false);
      expect(chat.canSend, false);
      expect(chat.messages, isEmpty);
      expect(chat.error, isNotNull);
    } finally {
      chat.dispose();
      api.close();
    }
  });
}
