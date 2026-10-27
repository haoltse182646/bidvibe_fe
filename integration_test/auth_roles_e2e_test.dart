import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/core/remote_app_store.dart';
import 'package:bidvibe/main.dart';
import 'package:bidvibe/screens/admin/admin_shell.dart';
import 'package:bidvibe/screens/appraiser/appraiser_shell.dart';
import 'package:bidvibe/screens/auth/auth_login.dart';
import 'package:bidvibe/screens/bidder/bidder_shell.dart';
import 'package:bidvibe/screens/seller/seller_shell.dart';
import 'package:bidvibe/screens/warehouse/warehouse_shell.dart';
import 'package:bidvibe/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

const _apiUrl = String.fromEnvironment('BIDVIBE_API_BASE_URL');
const _allowAuth = bool.fromEnvironment('BIDVIBE_ALLOW_DEPLOYED_AUTH_TEST');

class _Account {
  const _Account(this.id, this.role, this.email, this.password, this.shell);
  final String id;
  final String role;
  final String email;
  final String password;
  final Type shell;
  bool get ops => !['bidder', 'seller'].contains(role);
}

const _accounts = [
  _Account('AUTH-01', 'bidder', String.fromEnvironment('E2E_BIDDER_A_EMAIL'),
      String.fromEnvironment('E2E_BIDDER_A_PASSWORD'), BidderShell),
  _Account('AUTH-02', 'bidder', String.fromEnvironment('E2E_BIDDER_B_EMAIL'),
      String.fromEnvironment('E2E_BIDDER_B_PASSWORD'), BidderShell),
  _Account('AUTH-03', 'seller', String.fromEnvironment('E2E_SELLER_EMAIL'),
      String.fromEnvironment('E2E_SELLER_PASSWORD'), SellerShell),
  _Account(
      'AUTH-04',
      'appraiser',
      String.fromEnvironment('E2E_APPRAISER_EMAIL'),
      String.fromEnvironment('E2E_APPRAISER_PASSWORD'),
      AppraiserShell),
  _Account(
      'AUTH-05',
      'warehouse',
      String.fromEnvironment('E2E_WAREHOUSE_EMAIL'),
      String.fromEnvironment('E2E_WAREHOUSE_PASSWORD'),
      WarehouseShell),
  _Account('AUTH-06', 'admin', String.fromEnvironment('E2E_ADMIN_EMAIL'),
      String.fromEnvironment('E2E_ADMIN_PASSWORD'), AdminShell),
];

Future<void> _wait(
  WidgetTester tester,
  bool Function() condition,
  String stage,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(condition(), isTrue,
      reason: 'Stage failed: $stage. '
          'Check device screen and BE logs; a timeout alone does not prove its cause.');
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final account in _accounts) {
    testWidgets('${account.id}: ${account.role} login, identity, shell, logout',
        (tester) async {
      var stage = 'configuration';
      final watch = Stopwatch()..start();
      try {
        expect(_allowAuth, isTrue,
            reason:
                'Explicit opt-in required for deployed authentication tests.');
        expect(_apiUrl, 'https://bidvibe-be.onrender.com',
            reason: 'This auth-only suite targets the agreed deployed BE.');
        expect(account.email.trim().isNotEmpty && account.password.isNotEmpty,
            isTrue,
            reason: 'Missing account defines for ${account.id}.');
        await ApiClient.loadConfig();
        await tester.pumpWidget(const BidVibeApp());
        final login = find.byType(AuthLoginScreen);
        final logout = find.byTooltip('Đăng xuất');
        stage = 'restore existing session';
        await _wait(
            tester,
            () => login.evaluate().isNotEmpty || logout.evaluate().isNotEmpty,
            stage);
        if (logout.evaluate().isNotEmpty) {
          await tester.tap(logout);
          await _wait(tester, () => login.evaluate().isNotEmpty,
              'clear existing session');
        }

        stage = 'submit login form';
        final fields = find.byType(TextFormField);
        expect(fields, findsNWidgets(2));
        await tester.enterText(fields.at(0), account.email);
        await tester.enterText(fields.at(1), account.password);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 300));
        final checkbox = find.byType(CheckboxListTile);
        expect(checkbox, findsOneWidget);
        if (tester.widget<CheckboxListTile>(checkbox).value != account.ops) {
          await tester.ensureVisible(checkbox);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(checkbox);
          await tester.pump();
        }
        final submit = find.widgetWithText(FilledButton, 'Đăng nhập');
        await tester.ensureVisible(submit);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(submit);
        stage = 'authenticated role shell';
        await _wait(
            tester,
            () =>
                find.byType(account.shell).evaluate().isNotEmpty &&
                logout.evaluate().isNotEmpty,
            stage);
        expect(login, findsNothing);
        final store = tester.element(find.byType(RootShell)).read<AppStore>()
            as RemoteAppStore;
        stage = 'identity and role from authenticated store';
        // Boolean checks avoid printing credentials or identity in failures.
        expect(
            store.currentUser?.email.toLowerCase() ==
                account.email.trim().toLowerCase(),
            isTrue,
            reason: 'Authenticated identity differs from configured account.');
        expect(store.currentUser?.role, account.role);
        expect(store.api.token?.isNotEmpty, isTrue);
        expect(find.byType(account.shell), findsOneWidget);

        stage = 'logout';
        await tester.tap(logout);
        await _wait(tester, () => login.evaluate().isNotEmpty, stage);
        expect(find.byType(account.shell), findsNothing);
        expect(store.currentUser, isNull);
        expect(store.api.token, isNull);
        expect(find.byType(TextFormField), findsNWidgets(2));
        final frameworkError = tester.takeException();
        expect(frameworkError == null, isTrue,
            reason:
                'Flutter exception occurred; inspect preceding test output.');
        binding.reportData = {
          ...?binding.reportData,
          account.id: {
            'result': 'PASS',
            'stage': 'completed',
            'elapsedMs': watch.elapsedMilliseconds
          },
        };
      } catch (_) {
        binding.reportData = {
          ...?binding.reportData,
          account.id: {
            'result': 'FAIL',
            'stage': stage,
            'elapsedMs': watch.elapsedMilliseconds
          },
        };
        // Record the failing step, without inferring an unverified root cause.
        debugPrint('${account.id} FAILED at stage: $stage');
        rethrow;
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 500));
      }
    });
  }
}
