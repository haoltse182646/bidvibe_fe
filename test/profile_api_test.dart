import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/features/profile/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> profile({String role = 'bidder'}) => {
  'id': '123',
  'fullName': 'Hào',
  'email': 'hao@example.com',
  'phone': null,
  'avatarUrl': null,
  'status': 'active',
  'role': role,
  'kind': 'account',
  if (role == 'seller') 'storeName': 'Gian hàng',
};
http.Response ok(Map<String, dynamic> data) => http.Response(
  jsonEncode({'success': true, 'data': data, 'error': null}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
http.Response fail(String code, {int status = 400}) => http.Response(
  jsonEncode({
    'success': false,
    'data': null,
    'error': {'code': code, 'message': code},
  }),
  status,
);
final png = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 0]);

void main() {
  test('Profile address/order summaries use the documented GET endpoints and token', () async {
    final paths = <String>[];
    final api = ApiClient(
      client: MockClient((request) async {
        paths.add(request.url.path);
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer A');
        return request.url.path == '/api/addresses'
            ? ok({
                'addresses': [
                  {'id': '7', 'addressLine': 'Địa chỉ thật', 'isDefault': true},
                ],
              })
            : ok({
                'orders': [
                  {'id': '120', 'title': 'Đơn thật', 'paymentStatus': 'paid'},
                ],
              });
      }),
    )..token = 'A';
    addTearDown(api.close);
    final repository = ProfileRepository(api);
    expect((await repository.addresses()).first['id'], '7');
    expect((await repository.orders()).first['id'], '120');
    expect(paths, ['/api/addresses', '/api/orders/mine']);
  });
  test(
    'GET /me uses current token and supports nullable phone/avatar',
    () async {
      final api = ApiClient(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/me');
          expect(request.headers['Authorization'], 'Bearer bidder');
          return ok(profile());
        }),
      )..token = 'bidder';
      addTearDown(api.close);
      final result = await ProfileRepository(api).fetch();
      expect(result.fullName, 'Hào');
      expect(result.phone, isNull);
      expect(result.avatarUrl, isNull);
    },
  );
  test('PATCH sends only changes and uses server response', () async {
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/me');
        expect(request.headers['Authorization'], 'Bearer bidder');
        expect(jsonDecode(request.body), {'fullName': 'Hào mới'});
        return ok({...profile(), 'fullName': 'Hào mới'});
      }),
    )..token = 'bidder';
    addTearDown(api.close);
    expect(
      (await ProfileRepository(api).update({'fullName': '  Hào mới  '}))
          .fullName,
      'Hào mới',
    );
  });
  test('Blank phone and removed avatar are sent as explicit null', () async {
    final api = ApiClient(
      client: MockClient((request) async {
        expect(jsonDecode(request.body), {'phone': null, 'avatarUrl': null});
        return ok(profile());
      }),
    );
    addTearDown(api.close);
    await ProfileRepository(api).update({'phone': '   ', 'avatarUrl': null});
  });
  test('Seller sends shopName and reads storeName', () async {
    final api = ApiClient(
      client: MockClient((request) async {
        expect(jsonDecode(request.body), {'shopName': 'Gốm mới'});
        return ok({...profile(role: 'seller'), 'storeName': 'Gốm mới'});
      }),
    );
    addTearDown(api.close);
    expect(
      (await ProfileRepository(api).update({'shopName': ' Gốm mới '}))
          .storeName,
      'Gốm mới',
    );
  });
  test(
    'Profile validation rejects unknown fields and invalid values before HTTP',
    () async {
      var calls = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          calls++;
          return ok(profile());
        }),
      );
      addTearDown(api.close);
      for (final changes in <Map<String, dynamic>>[
        {},
        {'email': 'other@example.com'},
        {'address': 'demo'},
        {'fullName': ' '},
        {'fullName': 'a' * 101},
        {'phone': '123'},
        {'phone': 123},
        {'phone': 'abc0901234567'},
        {'avatarUrl': 'file:///tmp/a.png'},
        {'shopName': ''},
      ]) {
        await expectLater(
          ProfileRepository(api).update(changes),
          throwsA(isA<ApiException>()),
        );
      }
      expect(calls, 0);
    },
  );
  test('Phone validation follows BE formatting and digit limits', () {
    for (final value in ['', '+84 (903) 123-456', '0903 123 456']) {
      expect(ProfileRepository.phoneError(value), isNull);
    }
    for (final value in ['123', '+1234567890123456', '0903abc123456']) {
      expect(ProfileRepository.phoneError(value), isNotNull);
    }
  });
  test(
    'Password POST preserves whitespace and token; no implicit logout',
    () async {
      final api = ApiClient(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/me/password');
          expect(jsonDecode(request.body), {
            'currentPassword': ' old password ',
            'newPassword': ' new password ',
          });
          return ok({'changed': true});
        }),
      )..token = 'token';
      addTearDown(api.close);
      await ProfileRepository(api)
          .changePassword(' old password ', ' new password ');
      expect(api.token, 'token');
    },
  );
  test('Invalid password length or missing current makes no POST', () async {
    var calls = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        calls++;
        return ok({'changed': true});
      }),
    );
    addTearDown(api.close);
    for (final pair in [('', '123456'), ('old', '12345'), ('old', 'a' * 73)]) {
      await expectLater(
        ProfileRepository(api).changePassword(pair.$1, pair.$2),
        throwsA(isA<ApiException>()),
      );
    }
    expect(calls, 0);
  });
  for (final code in [
    'WRONG_PASSWORD',
    'UNAUTHORIZED',
    'ACCOUNT_SUSPENDED',
    'FORBIDDEN',
  ]) {
    test('Password preserves $code with one POST', () async {
      var calls = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          calls++;
          return fail(code);
        }),
      );
      addTearDown(api.close);
      await expectLater(
        ProfileRepository(api).changePassword('old', '123456'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', code)),
      );
      expect(calls, 1);
    });
  }
  test('Password missing changed=true does not claim success', () async {
    final api = ApiClient(
      client: MockClient((request) async => ok({'changed': false})),
    );
    addTearDown(api.close);
    await expectLater(
      ProfileRepository(api).changePassword('old', '123456'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'INVALID_RESPONSE'),
      ),
    );
  });
  test(
    'Multipart avatar uses files field, avatar purpose and Bearer token',
    () async {
      final api = ApiClient(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/uploads/images');
          expect(request.url.queryParameters, {'purpose': 'avatar'});
          expect(request.headers['Authorization'], 'Bearer bidder');
          expect(
            request.headers['content-type'],
            contains('multipart/form-data; boundary='),
          );
          final multipart = latin1.decode(request.bodyBytes);
          expect(multipart, contains('name="files"'));
          expect(multipart, contains('filename="avatar.png"'));
          return ok({
            'urls': ['https://example.com/avatar.png'],
          });
        }),
      )..token = 'bidder';
      addTearDown(api.close);
      expect(
        await ProfileRepository(api).uploadAvatar(png, 'avatar.png'),
        'https://example.com/avatar.png',
      );
    },
  );
  test(
    'Avatar rejects oversized content and fake extension without upload',
    () async {
      var calls = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          calls++;
          return ok({});
        }),
      );
      addTearDown(api.close);
      await expectLater(
        ProfileRepository(api)
            .uploadAvatar(Uint8List(5 * 1024 * 1024 + 1), 'big.png'),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'FILE_TOO_LARGE'),
        ),
      );
      await expectLater(
        ProfileRepository(api).uploadAvatar(
          Uint8List.fromList(utf8.encode('not an image')),
          'fake.png',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'INVALID_FILE_TYPE',
          ),
        ),
      );
      expect(calls, 0);
    },
  );
  for (final code in [
    'UPLOAD_NOT_CONFIGURED',
    'UPLOAD_FAILED',
    'FILE_TOO_LARGE',
    'INVALID_FILE_TYPE',
  ]) {
    test('Avatar displays server error $code without retry', () async {
      var calls = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          calls++;
          return fail(code, status: 503);
        }),
      );
      addTearDown(api.close);
      await expectLater(
        ProfileRepository(api).uploadAvatar(png, 'avatar.png'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', code)),
      );
      expect(calls, 1);
    });
  }
  test('PATCH timeout is exposed without an automatic retry', () async {
    var calls = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        calls++;
        throw TimeoutException('lost');
      }),
    );
    addTearDown(api.close);
    await expectLater(
      ProfileRepository(api).update({'fullName': 'New'}),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'TIMEOUT')),
    );
    expect(calls, 1);
  });
  test('Existing bodyless POST remains bodyless', () async {
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.body, isEmpty);
        return ok({'updated': 1});
      }),
    );
    addTearDown(api.close);
    await api.request('/api/notifications/read-all', method: 'POST');
  });
}
