import 'dart:async';
import 'dart:convert';

import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/core/remote_app_store.dart';
import 'package:bidvibe/features/profile/profile_repository.dart';
import 'package:bidvibe/models.dart';
import 'package:bidvibe/screens/auth/auth_profile.dart';
import 'package:bidvibe/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'profile_api_test.dart' as fixture;

class ProfileTestStore extends RemoteAppStore {
  final ApiClient _testApi;
  bool loggedOut = false;
  @override
  ApiClient get api => _testApi;
  ProfileTestStore(this._testApi, {String role = 'bidder'})
    : super(restoreOnStart: false) {
    currentUser = UserAccount(
      id: '123',
      name: 'Tên cũ',
      email: 'hao@example.com',
      role: role,
    );
  }
  @override
  void logout() {
    loggedOut = true;
    api.token = null;
    currentUser = null;
    notifyListeners();
  }
}

MockClient profileClient(
  Future<http.Response> Function(http.Request) handler,
) => MockClient((request) async {
  if (request.method == 'GET' && request.url.path == '/api/addresses') {
    return fixture.ok({'addresses': []});
  }
  if (request.method == 'GET' && request.url.path == '/api/orders/mine') {
    return fixture.ok({'orders': []});
  }
  return handler(request);
});

Future<void> showProfile(
  WidgetTester tester,
  ProfileTestStore store, {
  Future<XFile?> Function()? pickImage,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: MaterialApp(
        home: Scaffold(
          body: AuthProfileScreen(
            repository: ProfileRepository(store.api),
            pickImage: pickImage ?? () async => null,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapLabel(WidgetTester tester, String label) async {
  final target = find.text(label);
  if (target.evaluate().isEmpty) {
    final scrollable = find
        .descendant(
          of: find.byKey(const ValueKey('profile.scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(target, 250, scrollable: scrollable);
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String text) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.enterText(target, text);
}

Future<void> password(
  WidgetTester tester, {
  String confirmation = 'new password',
}) async {
  await tapLabel(tester, 'Đổi mật khẩu');
  await enter(tester, 'profile.currentPassword', 'old password');
  await enter(tester, 'profile.newPassword', 'new password');
  await enter(tester, 'profile.confirmPassword', confirmation);
}

void main() {
  testWidgets(
    'Loads real profile and restores old sections without fake device or OTP actions',
    (tester) async {
      final api = ApiClient(
        client: profileClient((request) async => fixture.ok(fixture.profile())),
      )..token = 'A';
      final store = ProfileTestStore(api);
      try {
        await showProfile(tester, store);
        expect(store.currentUser!.name, 'Hào');
        expect(find.text('hao@example.com'), findsOneWidget);
        expect(find.text('Địa chỉ nhận hàng'), findsNothing);
        expect(find.text('Đơn hàng của tôi'), findsOneWidget);
        final vertical = find
            .descendant(
              of: find.byKey(const ValueKey('profile.scroll')),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.byType(SwitchListTile),
          250,
          scrollable: vertical,
        );
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
          isNull,
        );
        await tester.scrollUntilVisible(
          find.text('Thiết bị đã đăng nhập'),
          250,
          scrollable: vertical,
        );
        expect(find.text('iPhone 13 · TP.HCM'), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        store.dispose();
      }
    },
  );
  testWidgets(
    'Edit sends only changed fields; response updates screen and AppStore',
    (tester) async {
      var patches = 0;
      final api = ApiClient(
        client: profileClient((request) async {
          if (request.method == 'PATCH') {
            patches++;
            expect(jsonDecode(request.body), {
              'fullName': 'Hào mới',
              'phone': '0901234567',
            });
            return fixture.ok({
              ...fixture.profile(),
              'fullName': 'Hào mới',
              'phone': '0901234567',
            });
          }
          return fixture.ok(fixture.profile());
        }),
      )..token = 'A';
      final store = ProfileTestStore(api);
      try {
        await showProfile(tester, store);
        await tapLabel(tester, 'Sửa');
        await enter(tester, 'profile.name', ' Hào mới ');
        await enter(tester, 'profile.phone', '0901234567');
        await tapLabel(tester, 'Lưu');
        expect(patches, 1);
        expect(store.currentUser!.name, 'Hào mới');
        expect(store.currentUser!.phone, '0901234567');
        expect(find.byKey(const ValueKey('profile.name')), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        store.dispose();
      }
    },
  );
  testWidgets('Invalid input, unchanged profile and cancel never PATCH', (
    tester,
  ) async {
    var patches = 0;
    final api = ApiClient(
      client: profileClient((request) async {
        if (request.method == 'PATCH') {
          patches++;
        }
        return fixture.ok(fixture.profile());
      }),
    )..token = 'A';
    final store = ProfileTestStore(api);
    try {
      await showProfile(tester, store);
      await tapLabel(tester, 'Sửa');
      await tapLabel(tester, 'Lưu');
      expect(find.text('Chưa có thay đổi.'), findsOneWidget);
      await enter(tester, 'profile.name', ' ');
      await tapLabel(tester, 'Lưu');
      expect(find.text('Nhập từ 1 đến 100 ký tự.'), findsOneWidget);
      await enter(tester, 'profile.name', 'Hào mới');
      await tapLabel(tester, 'Huỷ');
      expect(patches, 0);
      expect(store.currentUser!.name, 'Hào');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });
  testWidgets('Seller can edit shop name', (tester) async {
    final api = ApiClient(
      client: profileClient((request) async {
        if (request.method == 'PATCH') {
          expect(jsonDecode(request.body), {'shopName': 'Cửa hàng mới'});
          return fixture.ok({
            ...fixture.profile(role: 'seller'),
            'storeName': 'Cửa hàng mới',
          });
        }
        return fixture.ok(fixture.profile(role: 'seller'));
      }),
    )..token = 'A';
    final store = ProfileTestStore(api, role: 'seller');
    try {
      await showProfile(tester, store);
      await tapLabel(tester, 'Sửa');
      await enter(tester, 'profile.shop', 'Cửa hàng mới');
      await tapLabel(tester, 'Lưu');
      expect(store.currentUser!.shop, 'Cửa hàng mới');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });
  testWidgets(
    'Unknown PATCH result locks edits until successful GET verifies state',
    (tester) async {
      var patches = 0;
      final api = ApiClient(
        client: profileClient((request) async {
          if (request.method == 'PATCH') {
            patches++;
            throw http.ClientException('response lost');
          }
          return fixture.ok({
            ...fixture.profile(),
            if (patches > 0) 'fullName': 'Đã lưu ở máy chủ',
          });
        }),
      )..token = 'A';
      final store = ProfileTestStore(api);
      try {
        await showProfile(tester, store);
        await tapLabel(tester, 'Sửa');
        await enter(tester, 'profile.name', 'Đã lưu ở máy chủ');
        await tapLabel(tester, 'Lưu');
        expect(
          find.textContaining('Chưa xác nhận được kết quả lưu'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, 'Lưu'))
              .onPressed,
          isNull,
        );
        expect(store.currentUser!.name, 'Hào');
        expect(patches, 1);
        await tapLabel(tester, 'Kiểm tra hồ sơ đã lưu');
        expect(store.currentUser!.name, 'Đã lưu ở máy chủ');
        expect(patches, 1);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        store.dispose();
      }
    },
  );
  testWidgets('Avatar uploads first, PATCH attaches URL only after Save', (
    tester,
  ) async {
    var uploads = 0, patches = 0;
    final api = ApiClient(
      client: profileClient((request) async {
        if (request.url.path == '/api/uploads/images') {
          uploads++;
          return fixture.ok({
            'urls': ['https://example.com/avatar.png'],
          });
        }
        if (request.method == 'PATCH') {
          patches++;
          expect(jsonDecode(request.body), {
            'avatarUrl': 'https://example.com/avatar.png',
          });
          return fixture.ok({
            ...fixture.profile(),
            'avatarUrl': 'https://example.com/avatar.png',
          });
        }
        return fixture.ok(fixture.profile());
      }),
    )..token = 'A';
    final store = ProfileTestStore(api);
    try {
      await showProfile(
        tester,
        store,
        pickImage: () async => XFile.fromData(fixture.png, name: 'avatar.png'),
      );
      await tapLabel(tester, 'Sửa');
      await tapLabel(tester, 'Chọn ảnh đại diện');
      expect(uploads, 1);
      expect(patches, 0);
      await tapLabel(tester, 'Lưu');
      expect(patches, 1);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });
  testWidgets('Picker cancel leaves profile untouched', (tester) async {
    var writes = 0;
    final api = ApiClient(
      client: profileClient((request) async {
        if (request.method != 'GET') {
          writes++;
        }
        return fixture.ok(fixture.profile());
      }),
    )..token = 'A';
    final store = ProfileTestStore(api);
    try {
      await showProfile(tester, store);
      await tapLabel(tester, 'Sửa');
      await tapLabel(tester, 'Chọn ảnh đại diện');
      await tapLabel(tester, 'Lưu');
      expect(writes, 0);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });
  testWidgets('Password confirmation mismatch prevents POST', (tester) async {
    var writes = 0;
    final api = ApiClient(
      client: profileClient((request) async {
        if (request.method != 'GET') {
          writes++;
        }
        return fixture.ok(fixture.profile());
      }),
    )..token = 'A';
    final store = ProfileTestStore(api);
    try {
      await showProfile(tester, store);
      await password(tester, confirmation: 'different');
      await tapLabel(tester, 'Cập nhật mật khẩu');
      expect(find.text('Mật khẩu nhập lại chưa khớp.'), findsOneWidget);
      expect(writes, 0);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });
  for (final wrong in [false, true]) {
    testWidgets(
      'Password success/wrong password handled without fake local change: $wrong',
      (tester) async {
        var writes = 0;
        final api = ApiClient(
          client: profileClient((request) async {
            if (request.method == 'POST') {
              writes++;
              return wrong
                  ? fixture.fail('WRONG_PASSWORD')
                  : fixture.ok({'changed': true});
            }
            return fixture.ok(fixture.profile());
          }),
        )..token = 'A';
        final store = ProfileTestStore(api);
        try {
          await showProfile(tester, store);
          await password(tester);
          await tapLabel(tester, 'Cập nhật mật khẩu');
          expect(writes, 1);
          expect(store.loggedOut, false);
          expect(api.token, 'A');
          expect(store.currentUser!.password, '');
          if (wrong) {
            expect(find.text('WRONG_PASSWORD'), findsOneWidget);
          } else {
            expect(
              find.textContaining('Đổi mật khẩu thành công.'),
              findsOneWidget,
            );
            expect(
              find.byKey(const ValueKey('profile.newPassword')),
              findsNothing,
            );
          }
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          store.dispose();
        }
      },
    );
  }
  testWidgets(
    'Unknown password result blocks another POST and clears sensitive input',
    (tester) async {
      var writes = 0;
      final api = ApiClient(
        client: profileClient((request) async {
          if (request.method == 'POST') {
            writes++;
            throw http.ClientException('lost response');
          }
          return fixture.ok(fixture.profile());
        }),
      )..token = 'A';
      final store = ProfileTestStore(api);
      try {
        await showProfile(tester, store);
        await password(tester);
        await tapLabel(tester, 'Cập nhật mật khẩu');
        expect(writes, 1);
        expect(
          find.textContaining('Chưa xác nhận được kết quả đổi mật khẩu'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const ValueKey('profile.newPassword')),
              )
              .controller!
              .text,
          isEmpty,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Cập nhật mật khẩu'),
              )
              .onPressed,
          isNull,
        );
        await tapLabel(tester, 'Đăng xuất');
        expect(store.loggedOut, true);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        store.dispose();
      }
    },
  );
  for (final code in ['UNAUTHORIZED', 'ACCOUNT_SUSPENDED']) {
    testWidgets('GET $code logs out current user', (tester) async {
      final api = ApiClient(
        client: profileClient(
          (request) async => fixture.fail(code, status: 401),
        ),
      )..token = 'A';
      final store = ProfileTestStore(api);
      try {
        await showProfile(tester, store);
        expect(store.loggedOut, true);
        expect(store.sessionError, code);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        store.dispose();
      }
    });
  }
  testWidgets(
    'Late profile response cannot overwrite another signed-in account',
    (tester) async {
      final pending = Completer<http.Response>();
      final api = ApiClient(
        client: profileClient((request) async => pending.future),
      )..token = 'A';
      final store = ProfileTestStore(api);
      try {
        await tester.pumpWidget(
          ChangeNotifierProvider<AppStore>.value(
            value: store,
            child: MaterialApp(
              home: Scaffold(
                body: AuthProfileScreen(
                  repository: ProfileRepository(api),
                  pickImage: () async => null,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        api.token = 'B';
        store.currentUser = UserAccount(
          id: '999',
          name: 'Tài khoản B',
          email: 'b@example.com',
          role: 'bidder',
        );
        store.notifyListeners();
        pending.complete(fixture.ok(fixture.profile()));
        await tester.pumpAndSettle();
        expect(store.currentUser!.id, '999');
        expect(store.currentUser!.name, 'Tài khoản B');
      } finally {
        if (!pending.isCompleted) {
          pending.complete(fixture.ok(fixture.profile()));
        }
        await tester.pumpWidget(const SizedBox.shrink());
        store.dispose();
      }
    },
  );
  test(
    'applyProfile rejects mismatched account before changing current user',
    () {
      final store = ProfileTestStore(ApiClient());
      try {
        expect(
          () => store.applyProfile({...fixture.profile(), 'id': '999'}),
          throwsA(isA<ApiException>()),
        );
        expect(store.currentUser!.id, '123');
      } finally {
        store.dispose();
      }
    },
  );
}
