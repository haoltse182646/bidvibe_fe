import 'dart:convert';
import 'dart:ui' as ui;
import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/core/picked_image.dart';
import 'package:bidvibe/core/remote_app_store.dart';
import 'package:bidvibe/main.dart';
import 'package:bidvibe/store.dart';
import 'package:bidvibe/screens/auth/auth_login.dart';
import 'package:bidvibe/screens/seller/seller_create.dart';
import 'package:bidvibe/screens/seller/seller_shell.dart';
import 'package:bidvibe/screens/appraiser/appraiser_ops_screen.dart';
import 'package:bidvibe/screens/appraiser/appraiser_shell.dart';
import 'package:bidvibe/screens/bidder/bidder_shell.dart';
import 'package:bidvibe/screens/bidder/bidder_home.dart';
import 'package:bidvibe/screens/bidder/bidder_wallet.dart';
import 'package:bidvibe/screens/bidder/auction_detail_screen.dart';
import 'package:bidvibe/screens/bidder/auction_bid_panel.dart';
import 'package:bidvibe/widgets/photo_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'support/discovery_assertions.dart';

const _url = String.fromEnvironment('BIDVIBE_API_BASE_URL');
const _resumeAuction = String.fromEnvironment('E2E_RESUME_UI_AUCTION');
const _resumeTitle = String.fromEnvironment('E2E_RESUME_UI_TITLE');
const _resumeListing = String.fromEnvironment('E2E_RESUME_UI_LISTING');
const _accounts = {
  'SELLER': (
    String.fromEnvironment('E2E_SELLER_EMAIL'),
    String.fromEnvironment('E2E_SELLER_PASSWORD')
  ),
  'APPRAISER': (
    String.fromEnvironment('E2E_APPRAISER_EMAIL'),
    String.fromEnvironment('E2E_APPRAISER_PASSWORD')
  ),
  'BIDDER_A': (
    String.fromEnvironment('E2E_BIDDER_A_EMAIL'),
    String.fromEnvironment('E2E_BIDDER_A_PASSWORD')
  ),
  'BIDDER_B': (
    String.fromEnvironment('E2E_BIDDER_B_EMAIL'),
    String.fromEnvironment('E2E_BIDDER_B_PASSWORD')
  ),
};

Future<void> _wait(
    WidgetTester tester, bool Function() predicate, String stage) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (!predicate() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(predicate(), isTrue,
      reason:
          'Timed out at $stage; inspect UI and API evidence before assigning cause.');
}

Future<void> _reveal(WidgetTester tester, Finder target, Finder scope) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 400));
  final scroll =
      find.descendant(of: scope, matching: find.byType(Scrollable)).first;
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(target, 250,
        scrollable: scroll, maxScrolls: 45);
  }
  if (target.evaluate().isNotEmpty) {
    await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  }
  await tester.pump(const Duration(milliseconds: 400));
  expect(target.hitTestable(), findsOneWidget);
}

Future<void> _tap(WidgetTester tester, Finder target, Finder scope) async {
  await _reveal(tester, target, scope);
  await tester.tap(target);
  await tester.pump(const Duration(milliseconds: 400));
}

RemoteAppStore _store(WidgetTester tester) =>
    tester.element(find.byType(RootShell)).read<AppStore>() as RemoteAppStore;
Future<void> _logout(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Đăng xuất'));
  await _wait(tester, () => find.byType(AuthLoginScreen).evaluate().isNotEmpty,
      'logout');
}

Future<void> _login(WidgetTester tester, String key, Type shell) async {
  final a = _accounts[key]!;
  expect(a.$1.isNotEmpty && a.$2.isNotEmpty, isTrue);
  final fields = find.byType(TextFormField);
  expect(fields, findsNWidgets(2));
  await tester.enterText(fields.at(0), a.$1);
  await tester.enterText(fields.at(1), a.$2);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 300));
  final check = find.byType(CheckboxListTile);
  if (tester.widget<CheckboxListTile>(check).value != (key == 'APPRAISER')) {
    await _tap(tester, check, find.byType(AuthLoginScreen));
  }
  await _tap(tester, find.widgetWithText(FilledButton, 'Đăng nhập'),
      find.byType(AuthLoginScreen));
  await _wait(
      tester, () => find.byType(shell).evaluate().isNotEmpty, 'login $key');
  expect(_store(tester).currentUser?.email.toLowerCase() == a.$1.toLowerCase(),
      isTrue);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      _resumeAuction.isEmpty
          ? 'UI-BIZ: seller submit, appraiser approve, bidder wallet deposit and bid'
          : 'UI-BIDDER: independent wallet deposit bid journey on existing E2E fixture',
      (tester) async {
    final evidence = <String, dynamic>{'steps': <Map<String, dynamic>>[]};
    var stage = 'configuration';
    final title = _resumeAuction.isEmpty
        ? 'E2E_${DateTime.now().toUtc().millisecondsSinceEpoch}_UI'
        : _resumeTitle;
    String? listingId, auctionId;
    void passed(String id, Map<String, dynamic> data) {
      (evidence['steps'] as List).add({'id': id, 'result': 'PASS', ...data});
      binding.reportData = evidence;
      debugPrint(
          'CHECKPOINT ${jsonEncode({'id': id, 'result': 'PASS', ...data})}');
    }

    try {
      expect(const bool.fromEnvironment('BIDVIBE_ALLOW_DEPLOYED_AUTH_TEST'),
          isTrue);
      expect(_url, 'https://bidvibe-be.onrender.com');
      await ApiClient.loadConfig();
      await tester.pumpWidget(const BidVibeApp());
      await _wait(
          tester,
          () =>
              find.byType(AuthLoginScreen).evaluate().isNotEmpty ||
              find.byTooltip('Đăng xuất').evaluate().isNotEmpty,
          'initial session');
      if (find.byTooltip('Đăng xuất').evaluate().isNotEmpty) {
        await _logout(tester);
      }
      if (_resumeAuction.isEmpty) {
        stage = 'seller create and submit';
        await _login(tester, 'SELLER', SellerShell);
        await tester.tap(find.text('Tạo mới'));
        await tester.pump(const Duration(milliseconds: 500));
        final create = find.byType(SellerCreateScreen);
        final titleField = find.byWidgetPredicate((w) =>
            w is TextField &&
            w.decoration?.hintText == 'Ví dụ: Giày da thủ công, size 41');
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
            const Rect.fromLTWH(0, 0, 32, 32), Paint()..color = Colors.blue);
        final image = await recorder.endRecording().toImage(32, 32);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
            .buffer
            .asUint8List();
        image.dispose();
        // The native OS image picker is outside integration_test control. Inject
        // only the selected image through the existing callback; uploads stay real.
        final picker =
            find.descendant(of: create, matching: find.byType(PhotoPicker));
        await _reveal(tester, picker, create);
        tester
            .widget<PhotoPicker>(picker)
            .onChanged([PickedImage(bytes, 'e2e-product.png')]);
        await tester.pump();
        await _reveal(tester, titleField, create);
        await tester.enterText(titleField, title);
        final price = find.byWidgetPredicate((w) =>
            w is TextField && w.decoration?.hintText == 'Nhập giá khởi điểm');
        await _reveal(tester, price, create);
        await tester.enterText(price, '10000');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 300));
        await _tap(tester, find.text('Gửi để thẩm định'), create);
        final sellerApi = _store(tester).api;
        Map<String, dynamic>? fixture;
        final deadline = DateTime.now().add(const Duration(seconds: 45));
        while (fixture == null && DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 500));
          final rows = await sellerApi.request('/api/listings/mine?limit=100');
          for (final value in rows['listings'] as List) {
            if (value['title'] == title) {
              fixture = Map<String, dynamic>.from(value as Map);
            }
          }
          if (fixture?['status'] != 'pending_appraisal') {
            fixture = null;
          }
        }
        expect(fixture, isNotNull,
            reason: 'Seller did not produce submitted listing.');
        listingId = '${fixture!['id']}';
        evidence['fixture'] = {
          'title': title,
          'listingId': listingId,
          'photoPicker': 'Selected bytes injected; native gallery NOT tested'
        };
        passed('UI-SELLER', {
          'listingId': listingId,
          'status': fixture['status'],
          'photoCount': (fixture['photos'] as List).length
        });
        await _logout(tester);
        stage = 'appraiser queue and approval';
        await _login(tester, 'APPRAISER', AppraiserShell);
        final queue = find.byType(AppraiserOpsScreen);
        await _wait(
            tester,
            () => find
                .descendant(of: queue, matching: find.byType(ListView))
                .evaluate()
                .isNotEmpty,
            'appraisal queue loaded');
        await _tap(tester, find.text(title), queue);
        final appraisal = find.byType(AppraiserOpsDetailScreen);
        await _wait(
            tester,
            () => find.text('Duyệt và mở phiên').evaluate().isNotEmpty,
            'appraisal details');
        await _tap(tester, find.text('Duyệt và mở phiên'), appraisal);
        await _wait(
            tester,
            () => find.byType(AlertDialog).evaluate().isNotEmpty,
            'approve confirmation');
        await tester.tap(find.widgetWithText(FilledButton, 'Duyệt'));
        await _wait(tester, () => appraisal.evaluate().isEmpty,
            'appraisal closes after successful decision');
        final appApi = _store(tester).api;
        final appDetail = await appApi.request('/api/appraisals/$listingId');
        expect(appDetail['status'], 'live');
        final auctions = await appApi.request(
            '/api/auctions?status=live&q=${Uri.encodeQueryComponent(title)}');
        final list = auctions['auctions'] as List;
        expect(list.length, 1);
        auctionId = '${list.single['id']}';
        evidence['fixture']['auctionId'] = auctionId;
        passed('UI-APPRAISER',
            {'listingId': listingId, 'auctionId': auctionId, 'status': 'live'});
        await _logout(tester);
      } else {
        expect(_resumeTitle.startsWith('E2E_'), isTrue);
        expect(_resumeListing.isNotEmpty, isTrue);
        auctionId = _resumeAuction;
        listingId = _resumeListing;
        evidence['fixture'] = {
          'title': title,
          'listingId': listingId,
          'auctionId': auctionId,
          'setup':
              'Existing fixture; seller/appraiser NOT tested by this independent run'
        };
      }
      for (final key in ['BIDDER_A', 'BIDDER_B']) {
        stage = '$key login and wallet';
        await _login(tester, key, BidderShell);
        final api = _store(tester).api;
        final guard = await api.request('/api/auctions/$auctionId');
        expect(guard['title'], title);
        expect('${guard['listingId']}', listingId);
        expect(guard['isLive'], true);
        expect(guard['joined'], false,
            reason:
                'Do not repeat deposits/topups on an already-used fixture.');
        final before = await api.request('/api/wallet');
        var funded = before;
        if (!const bool.fromEnvironment('E2E_SKIP_UI_TOPUP')) {
          await tester.tap(find.text('Ví'));
          await tester.pump(const Duration(milliseconds: 600));
          final wallet = find.byType(BidderWalletScreen);
          final field =
              find.descendant(of: wallet, matching: find.byType(TextFormField));
          await _reveal(tester, field, wallet);
          await _wait(
              tester,
              () => tester.widget<TextFormField>(field).enabled == true,
              'wallet ready');
          await tester.enterText(field, '10000');
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pump(const Duration(milliseconds: 300));
          await _tap(
              tester, find.widgetWithText(FilledButton, 'Nạp tiền'), wallet);
          await _wait(
              tester,
              () => find.byType(AlertDialog).evaluate().isNotEmpty,
              'topup confirmation');
          await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận'));
          await _wait(
              tester,
              () =>
                  tester.widget<TextFormField>(field).controller!.text.isEmpty,
              'topup completed');
          funded = await api.request('/api/wallet');
          expect(funded['balance'], (before['balance'] as num) + 10000);
          passed('UI-TOPUP-$key',
              {'amount': 10000, 'before': before, 'after': funded});
        }
        stage = '$key discovery and detail';
        await tester.tap(find.text('Khám phá'));
        await tester.pump(const Duration(milliseconds: 400));
        final home = find.byType(BidderHomeScreen);
        final search =
            find.descendant(of: home, matching: find.byType(TextField)).first;
        await _reveal(tester, search, home);
        await tester.enterText(search, title);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.byTooltip('Tìm kiếm'));
        await _wait(
            tester,
            () => find
                .textContaining('Mã phiên $auctionId')
                .evaluate()
                .isNotEmpty,
            'discovery exact fixture');
        final card = find.ancestor(
            of: find.textContaining('Mã phiên $auctionId'),
            matching: find.byType(Card));
        final open = find.descendant(
            of: card,
            matching: find.widgetWithText(TextButton, 'Xem chi tiết phiên'));
        await _tap(tester, open, home);
        final detail = find.byType(AuctionDetailScreen);
        await _wait(
            tester,
            () => find.text('Thông tin sản phẩm').evaluate().isNotEmpty,
            'detail loaded');
        final join = find.widgetWithText(FilledButton, 'Đặt cọc tham gia');
        stage = '$key deposit';
        await _reveal(tester, join, detail);
        await _wait(
            tester,
            () => tester.widget<FilledButton>(join).onPressed != null,
            'deposit button ready');
        await tester.tap(join);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận đặt cọc'));
        await _wait(
            tester,
            () => find
                .text(
                    'Bạn đã đặt cọc tham gia phiên này. Không cần đặt cọc lại.')
                .evaluate()
                .isNotEmpty,
            'deposit confirmed');
        final joined = await api.request('/api/auctions/$auctionId');
        final held = await api.request('/api/wallet');
        expect(joined['joined'], true);
        expect(held['held'],
            (funded['held'] as num) + (joined['depositRequired'] as num));
        expect(held['balance'],
            (funded['balance'] as num) - (joined['depositRequired'] as num));
        passed('UI-JOIN-$key', {
          'auctionId': auctionId,
          'deposit': joined['myDeposit'],
          'wallet': held
        });
        stage = '$key bid';
        final bidPanel = find.byType(AuctionBidPanel);
        final minimum = find.widgetWithText(TextButton, 'Dùng giá tối thiểu');
        await _reveal(tester, minimum, detail);
        await _wait(
            tester,
            () => tester.widget<TextButton>(minimum).onPressed != null,
            'bid ready and Socket.IO connected');
        await tester.tap(minimum);
        await tester.pump();
        final bid = find.descendant(
            of: bidPanel,
            matching: find.widgetWithText(FilledButton, 'Đặt giá'));
        await _tap(tester, bid, detail);
        await _wait(
            tester,
            () => find.byType(AlertDialog).evaluate().isNotEmpty,
            'bid confirmation');
        await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận đặt giá'));
        await _wait(
            tester,
            () =>
                tester
                    .widget<AuctionBidPanel>(bidPanel)
                    .controller
                    .data?['leading'] ==
                true,
            'bid accepted and leader refreshed');
        final finalDetail = await api.request('/api/auctions/$auctionId');
        expect(finalDetail['leading'], true);
        expect(finalDetail['bidCount'], key == 'BIDDER_A' ? 1 : 2);
        passed('UI-BID-$key', {
          'auctionId': auctionId,
          'currentPrice': finalDetail['currentPrice'],
          'bidCount': finalDetail['bidCount'],
          'connected':
              tester.widget<AuctionBidPanel>(bidPanel).controller.connected
        });
        stage = '$key back navigation';
        await tester.pageBack();
        await expectDiscoveryAfterBack(tester);
        passed('UI-BACK-$key', {'homeVisible': true});
        await _logout(tester);
      }
      evidence['result'] = 'PASS';
      binding.reportData = evidence;
      debugPrint('BUSINESS_EVIDENCE ${jsonEncode(evidence)}');
    } catch (e) {
      evidence['result'] = 'FAIL';
      evidence['failedStage'] = stage;
      binding.reportData = evidence;
      debugPrint('BUSINESS_EVIDENCE ${jsonEncode(evidence)}');
      rethrow;
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
    }
  });
}
