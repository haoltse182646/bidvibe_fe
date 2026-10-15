import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/features/auctions/auction_repository.dart';

void main() {
  test('Categories use bearer token and backend field names', () async {
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.url.path, '/api/categories');
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'categories': [
                {'code': 'elec', 'name': 'Điện tử'},
              ],
            },
          }),
          200, headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..token = 'test-token';
    addTearDown(api.close);
    final result = await AuctionRepository(api).categories();
    expect(result.single['code'], 'elec');
  });

  test('Filters, Vietnamese query and pagination match API contract', () async {
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.url.path, '/api/auctions');
        expect(request.url.queryParameters, {
          'status': 'joined',
          'sort': 'price_asc',
          'limit': '20',
          'offset': '20',
          'category': 'antique',
          'q': 'bình gốm & trà',
        });
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'auctions': [
                {'id': '41', 'title': 'Bình gốm'},
              ],
              'total': 21,
              'limit': 20,
              'offset': 20,
            },
          }),
          200, headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(api.close);
    final page = await AuctionRepository(api).list(
      status: 'joined',
      sort: 'price_asc',
      category: 'antique',
      query: ' bình gốm & trà ',
      offset: 20,
    );
    expect(page.total, 21);
    expect(page.items.single['id'], '41');
  });

  test(
    'Default list omits optional filters and accepts an empty page',
    () async {
      final api = ApiClient(
        client: MockClient((request) async {
          expect(request.url.queryParameters, {
            'status': 'live',
            'sort': 'ending',
            'limit': '20',
            'offset': '0',
          });
          return http.Response(
            '{"success":true,"data":{"auctions":[],"total":0}}',
            200, headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(api.close);
      final page = await AuctionRepository(api).list();
      expect(page.items, isEmpty);
      expect(page.total, 0);
    },
  );

  test('Backend auth errors retain the code used to expire sessions', () async {
    final api = ApiClient(
      client: MockClient(
        (_) async => http.Response(
          '{"success":false,"error":{"code":"UNAUTHORIZED","message":"Token expired"}}',
          401,
        ),
      ),
    );
    addTearDown(api.close);
    await expectLater(
      AuctionRepository(api).list(),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'UNAUTHORIZED'),
      ),
    );
  });
}
