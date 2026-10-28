import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/core/remote_app_store.dart';
import 'package:bidvibe/screens/appraiser/appraiser_ops_screen.dart';
import 'package:bidvibe/store.dart';

class _OpsStore extends RemoteAppStore {
  final ApiClient testApi;
  _OpsStore(this.testApi) : super(restoreOnStart: false);
  @override
  ApiClient get api => testApi;
}

void main() {
  // setState must not receive a callback that returns the refresh Future,
  // otherwise Flutter asserts as soon as the queue is reloaded.
  testWidgets('Appraiser queue: kéo để làm mới không phát lỗi setState', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    var queueRequests = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/api/appraisals/queue') {
          queueRequests++;
          return http.Response(
            '{"success":true,"data":{"items":[{"listingId":"31",'
            '"title":"Bình gốm kiểm thử","category":"antique",'
            '"seller":{"name":"Cửa hàng kiểm thử"}}]}}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('{"success":false}', 404);
      }),
    )..token = 'ops-token';
    addTearDown(api.close);
    final store = _OpsStore(api);

    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppStore>.value(
        value: store,
        child: const MaterialApp(home: Scaffold(body: AppraiserOpsScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bình gốm kiểm thử'), findsOneWidget);
    expect(queueRequests, 1);

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(queueRequests, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}
