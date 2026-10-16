import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/features/ops/ops_repository.dart';

void main() {
  test('Appraisal queue requests the chosen backend status', () async {
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.url.path, '/api/appraisals/queue');
        expect(request.url.queryParameters['status'], 'needs_info');
        expect(request.headers['Authorization'], 'Bearer ops-token');
        return http.Response(
          '{"success":true,"data":{"items":[]}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..token = 'ops-token';
    addTearDown(api.close);

    expect(
      await OpsRepository(api).appraisalQueue(status: 'needs_info'),
      isEmpty,
    );
  });

  test('Flag decision uses the exact action route and body', () async {
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/admin/flags/12/action');
        expect(jsonDecode(request.body), {
          'action': 'terminate',
          'reason': 'Bằng chứng xác nhận bất thường',
        });
        return http.Response(
          '{"success":true,"data":{"id":"12","status":"terminated"}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(api.close);

    final result = await OpsRepository(api).actOnFlag(
      '12',
      action: 'terminate',
      reason: ' Bằng chứng xác nhận bất thường ',
    );
    expect(result['status'], 'terminated');
  });

  test('Dashboard and weekly report use their documented endpoints', () async {
    final paths = <String>[];
    final api = ApiClient(
      client: MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(
          '{"success":true,"data":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(api.close);
    final repository = OpsRepository(api);

    await repository.dashboard();
    await repository.weeklyReport();
    expect(paths, ['/api/admin/dashboard', '/api/admin/report/weekly']);
  });

  test('Account search filters and status patch match Admin contract', () async {
    var calls = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        calls++;
        if (calls == 1) {
          expect(request.url.path, '/api/admin/accounts');
          expect(request.url.queryParameters, {
            'role': 'seller',
            'status': 'suspended',
            'q': 'Hoa & Home',
            'limit': '50',
            'offset': '0',
          });
          return http.Response(
            '{"success":true,"data":{"accounts":[]}}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/admin/accounts/9');
        expect(jsonDecode(request.body), {'status': 'active'});
        return http.Response(
          '{"success":true,"data":{"id":"9","status":"active"}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(api.close);
    final repository = OpsRepository(api);

    await repository.accounts(role: 'seller', status: 'suspended', query: 'Hoa & Home');
    await repository.updateAccount('9', status: 'active');
  });

  test('Dispute resolution sends supported keep decision and optional note', () async {
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.url.path, '/api/admin/disputes/17/resolve');
        expect(jsonDecode(request.body), {
          'resolution': 'keep',
          'note': 'Đối chiếu đạt yêu cầu',
        });
        return http.Response(
          '{"success":true,"data":{"id":"17","resolution":"keep"}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(api.close);

    await OpsRepository(api).resolveDispute(
      '17',
      resolution: 'keep',
      note: ' Đối chiếu đạt yêu cầu ',
    );
  });

  test('Appraisal decision sends its reason to the listing endpoint', () async {
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/appraisals/31/decision');
        expect(jsonDecode(request.body), {
          'decision': 'more_info',
          'reason': 'Cần ảnh rõ số seri',
        });
        return http.Response(
          '{"success":true,"data":{"listingId":"31","decision":"more_info"}}',
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(api.close);

    await OpsRepository(api).decideAppraisal(
      '31',
      decision: 'more_info',
      reason: ' Cần ảnh rõ số seri ',
    );
  });

  test('Warehouse workflow uses each documented transition and body', () async {
    var requests = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        requests++;
        switch (requests) {
          case 1:
            expect(request.url.path, '/api/warehouse/orders/42/receive');
            expect(request.body, isEmpty);
          case 2:
            expect(request.url.path, '/api/warehouse/orders/42/inspect');
            expect(jsonDecode(request.body), {
              'result': 'mismatch',
              'notes': 'Thiếu phụ kiện theo mô tả',
            });
          case 3:
            expect(request.url.path, '/api/warehouse/orders/42/pack');
            expect(jsonDecode(request.body), {'notes': 'Bọc chống sốc'});
          case 4:
            expect(request.url.path, '/api/warehouse/orders/42/ship');
            expect(jsonDecode(request.body), {
              'carrier': 'GHN Express',
              'trackingCode': 'GHN-123',
            });
          case 5:
            expect(request.url.path, '/api/warehouse/orders/42/deliver');
            expect(request.body, isEmpty);
          default:
            fail('Unexpected warehouse request');
        }
        return http.Response(
          '{"success":true,"data":{"id":"42"}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(api.close);
    final repository = OpsRepository(api);

    await repository.receiveWarehouseOrder('42');
    await repository.inspectWarehouseOrder(
      '42',
      result: 'mismatch',
      notes: 'Thiếu phụ kiện theo mô tả',
    );
    await repository.packWarehouseOrder('42', notes: ' Bọc chống sốc ');
    await repository.shipWarehouseOrder(
      '42',
      carrier: ' GHN Express ',
      trackingCode: ' GHN-123 ',
    );
    await repository.deliverWarehouseOrder('42');
    expect(requests, 5);
  });

  test('Rejects invalid ids before issuing requests', () async {
    var requestCount = 0;
    final api = ApiClient(
      client: MockClient((_) async {
        requestCount++;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(api.close);

    await expectLater(
      OpsRepository(api).resolveDispute('not-an-id', resolution: 'refund'),
      throwsA(isA<ApiException>().having((error) => error.code, 'code', 'VALIDATION_ERROR')),
    );
    expect(requestCount, 0);
  });
}