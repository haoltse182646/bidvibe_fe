import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Supply these values with --dart-define; keep account credentials out of source.
const _email = String.fromEnvironment('BIDVIBE_E2E_EMAIL');
const _password = String.fromEnvironment('BIDVIBE_E2E_PASSWORD');
const _auctionTitle = String.fromEnvironment('BIDVIBE_E2E_AUCTION_TITLE');
const _auctionId = String.fromEnvironment('BIDVIBE_E2E_AUCTION_ID');
const _apiBaseUrl = String.fromEnvironment('BIDVIBE_API_BASE_URL');

bool _isAndroidEmulatorApi(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'http' &&
      uri.host == '10.0.2.2' &&
      uri.userInfo.isEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment &&
      (uri.path.isEmpty || uri.path == '/');
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String reason,
  Duration timeout = const Duration(seconds: 45),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(condition(), isTrue, reason: reason);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final missing = <String>[
    if (_apiBaseUrl.trim().isEmpty) 'BIDVIBE_API_BASE_URL',
    if (_email.trim().isEmpty) 'BIDVIBE_E2E_EMAIL',
    if (_password.isEmpty) 'BIDVIBE_E2E_PASSWORD',
    if (_auctionTitle.trim().isEmpty) 'BIDVIBE_E2E_AUCTION_TITLE',
    if (_auctionId.trim().isEmpty) 'BIDVIBE_E2E_AUCTION_ID',
  ];

  testWidgets(
    'bidder signs in, finds the configured live auction, opens its details, and signs out'
    '${missing.isEmpty ? '' : ' (skipped; missing ${missing.join(', ')})'}',
    (tester) async {
      expect(
        _isAndroidEmulatorApi(_apiBaseUrl),
        isTrue,
        reason: 'Refusing to run E2E against a non-emulator-local API URL.',
      );
      await ApiClient.loadConfig();
      await tester.pumpWidget(const BidVibeApp());

      final loginButton = find.widgetWithText(FilledButton, 'Đăng nhập');
      final logoutButton = find.byIcon(Icons.logout);
      await _pumpUntil(
        tester,
        () =>
            find.byType(TextFormField).evaluate().isNotEmpty ||
            logoutButton.evaluate().isNotEmpty,
        reason: 'The app should restore its session or show the login form.',
      );

      if (logoutButton.evaluate().isNotEmpty) {
        await tester.tap(logoutButton);
        await _pumpUntil(
          tester,
          () => find.byType(TextFormField).evaluate().isNotEmpty,
          reason: 'Logging out should return to the login form.',
        );
      }

      final loginFields = find.byType(TextFormField);
      expect(loginFields, findsNWidgets(2));
      await tester.enterText(loginFields.at(0), _email);
      await tester.enterText(loginFields.at(1), _password);
      await tester.tap(loginButton);

      await _pumpUntil(
        tester,
        () => find.text('Khám phá phiên đấu giá').evaluate().isNotEmpty,
        reason: 'Successful sign-in should open bidder discovery.',
      );

      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, _auctionTitle);
      await tester.tap(find.byTooltip('Tìm kiếm'));

      final targetAuctionCard = find.ancestor(
        of: find.textContaining('Mã phiên $_auctionId'),
        matching: find.byType(Card),
      );
      final targetTitle = find.descendant(
        of: targetAuctionCard,
        matching: find.text(_auctionTitle),
      );
      final openAuctionButton = find.descendant(
        of: targetAuctionCard,
        matching: find.widgetWithText(TextButton, 'Xem chi tiết phiên'),
      );
      await _pumpUntil(
        tester,
        () =>
            targetTitle.evaluate().isNotEmpty &&
            openAuctionButton.evaluate().isNotEmpty,
        reason:
            'Discovery should show the configured live auction title and ID.',
      );

      await tester.tap(openAuctionButton);
      await _pumpUntil(
        tester,
        () =>
            find.text('Phiên #$_auctionId').evaluate().isNotEmpty &&
            find.text('Thông tin sản phẩm').evaluate().isNotEmpty,
        reason: 'The selected auction details should match the configured ID.',
      );

      await tester.pageBack();
      await _pumpUntil(
        tester,
        () => find.text('Khám phá phiên đấu giá').evaluate().isNotEmpty,
        reason: 'Back navigation should return to bidder discovery.',
      );
      await tester.tap(logoutButton);
      await _pumpUntil(
        tester,
        () => find.byType(TextFormField).evaluate().isNotEmpty,
        reason: 'Logging out should clear the test session.',
      );
    },
    skip: missing.isNotEmpty,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
