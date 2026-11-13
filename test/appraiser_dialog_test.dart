import 'dart:convert';

import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/core/remote_app_store.dart';
import 'package:bidvibe/screens/appraiser/appraiser_ops_screen.dart';
import 'package:bidvibe/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

class _OpsStore extends RemoteAppStore {
  final ApiClient testApi;
  _OpsStore(this.testApi) : super(restoreOnStart: false);
  @override
  ApiClient get api => testApi;
}

Future<_OpsStore> _open(
    WidgetTester tester, List<Map<String, dynamic>> decisions) async {
  FlutterSecureStorage.setMockInitialValues({});
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = ApiClient(client: MockClient((request) async {
    final Object data;
    if (request.method == 'POST') {
      decisions.add(Map<String, dynamic>.from(jsonDecode(request.body) as Map));
      data = {'listingId': '31', 'status': 'needs_info'};
    } else {
      data = {
        'listingId': '31',
        'title': 'Bình gốm kiểm thử',
        'category': 'antique',
        'status': 'pending_appraisal',
        'photos': [],
        'history': [],
        'description': 'Bình gốm men rạn',
        'seller': {},
        'startingPrice': 10000
      };
    }
    return http.Response(jsonEncode({'success': true, 'data': data}),
        request.method == 'POST' ? 201 : 200,
        headers: {'content-type': 'application/json; charset=utf-8'});
  }))
    ..token = 'ops-test-token';
  addTearDown(api.close);
  final store = _OpsStore(api);
  await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
    value: store,
    child: MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                    body: Center(
                        child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) =>
                              const AppraiserOpsDetailScreen(listingId: '31'))),
                  child: const Text('Mở hồ sơ'),
                ))))),
  ));
  await tester.tap(find.text('Mở hồ sơ'));
  await tester.pumpAndSettle();
  return store;
}

void main() {
  for (final close in ['cancel', 'barrier', 'back']) {
    testWidgets(
        'More-info dialog closes with $close while input is focused, without errors or POST',
        (tester) async {
      final decisions = <Map<String, dynamic>>[];
      final store = await _open(tester, decisions);
      try {
        await tester
            .tap(find.widgetWithText(OutlinedButton, 'Yêu cầu bổ sung'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Cần thêm ảnh đáy bình');
        if (close == 'cancel') {
          await tester.tap(find.text('Huỷ'));
        } else if (close == 'barrier') {
          await tester.tapAt(const Offset(10, 10));
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(AppraiserOpsDetailScreen), findsOneWidget);
        expect(decisions, isEmpty);
        // A reopened prompt has its own empty input; dismissing it is also safe.
        await tester
            .tap(find.widgetWithText(OutlinedButton, 'Yêu cầu bổ sung'));
        await tester.pumpAndSettle();
        expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            isEmpty);
        await tester.tap(find.text('Huỷ'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        store.dispose();
      }
    });
  }

  for (final decision in ['more_info', 'reject']) {
    testWidgets(
        '$decision keeps mandatory reason and sends only the confirmed trimmed value',
        (tester) async {
      final decisions = <Map<String, dynamic>>[];
      final store = await _open(tester, decisions);
      try {
        await tester.tap(find.widgetWithText(OutlinedButton,
            decision == 'reject' ? 'Từ chối' : 'Yêu cầu bổ sung'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tiếp tục'));
        await tester.pumpAndSettle();
        expect(decisions, isEmpty);
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.enterText(
            find.byType(TextField), '  Cần thêm ảnh đáy bình  ');
        await tester.tap(find.text('Tiếp tục'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(decisions, [
          {'decision': decision, 'reason': 'Cần thêm ảnh đáy bình'}
        ]);
        expect(find.byType(AppraiserOpsDetailScreen), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        store.dispose();
      }
    });
  }
}
