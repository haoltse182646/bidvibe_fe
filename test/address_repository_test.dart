import 'dart:convert';

import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/features/addresses/address_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response ok(Map<String, dynamic> data, [int status = 200]) =>
    http.Response(
      jsonEncode({'success': true, 'data': data}),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> address({
  String id = '1',
  String recipientName = 'Nguyen An',
  String phone = '+84 912 345 678',
  String addressLine = '12 Example Street',
  String? ward = 'Ward 1',
  String? district = 'District 1',
  String city = 'Ho Chi Minh City',
  bool isDefault = false,
}) =>
    {
      'id': id,
      'recipientName': recipientName,
      'phone': phone,
      'addressLine': addressLine,
      'ward': ward,
      'district': district,
      'city': city,
      'isDefault': isDefault,
    };

void main() {
  group('ShippingAddress', () {
    test('parses address fields and formats full address', () {
      final parsed = ShippingAddress.fromJson(address());

      expect(parsed.id, '1');
      expect(parsed.fullAddress,
          '12 Example Street, Ward 1, District 1, Ho Chi Minh City');
      expect(parsed.fields, {
        'recipientName': 'Nguyen An',
        'phone': '+84 912 345 678',
        'addressLine': '12 Example Street',
        'ward': 'Ward 1',
        'district': 'District 1',
        'city': 'Ho Chi Minh City',
      });
    });

    test('rejects malformed IDs and missing required fields', () {
      for (final data in [
        address(id: '0'),
        address()..remove('city'),
        address()..['isDefault'] = 'false',
      ]) {
        expect(
          () => ShippingAddress.fromJson(data),
          throwsA(isA<ApiException>()),
        );
      }
    });
  });

  group('AddressRepository validation', () {
    test('validates IDs, required fields, optional fields, and phone numbers',
        () {
      expect(AddressRepository.validId('123'), isTrue);
      expect(AddressRepository.validId('../1'), isFalse);
      expect(AddressRepository.fieldError('ward', '  '), isNull);
      expect(AddressRepository.fieldError('city', '  '), isNotNull);
      expect(AddressRepository.fieldError('phone', '123'), isNotNull);

      expect(
        AddressRepository.validate({
          'recipientName': '  An  ',
          'phone': '+84 912 345 678',
          'addressLine': '  12 Example Street ',
          'ward': ' ',
          'city': ' HCMC ',
        }),
        {
          'recipientName': 'An',
          'phone': '+84 912 345 678',
          'addressLine': '12 Example Street',
          'ward': null,
          'district': null,
          'city': 'HCMC',
        },
      );
      expect(
        AddressRepository.validate({'city': 'HCMC'}, partial: true),
        {'city': 'HCMC'},
      );
      expect(
        () => AddressRepository.validate({'unexpected': 'value'}),
        throwsA(isA<ApiException>()),
      );
      expect(
        () => AddressRepository.validate({'city': ' '}, partial: true),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('AddressRepository requests', () {
    test('lists, creates, updates, sets default, and confirms deletion',
        () async {
      final requests = <String>[];
      final bodies = <String, Map<String, dynamic>>{};
      final api = ApiClient(
        client: MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          if (request.body.isNotEmpty) {
            bodies[request.url.path] =
                jsonDecode(request.body) as Map<String, dynamic>;
          }
          return switch ('${request.method} ${request.url.path}') {
            'GET /api/addresses' => ok({
                'addresses': [address()]
              }),
            'POST /api/addresses' => ok(address(isDefault: true), 201),
            'PATCH /api/addresses/1' => ok(address(city: 'Hanoi')),
            'POST /api/addresses/1/default' => ok(address(isDefault: true)),
            'DELETE /api/addresses/1' => ok({'id': '1', 'deleted': true}),
            _ => throw StateError(
                'Unexpected request: ${request.method} ${request.url.path}'),
          };
        }),
      );
      addTearDown(api.close);
      final repository = AddressRepository(api);

      expect((await repository.list()).single.fullAddress,
          contains('Ho Chi Minh City'));
      expect(
          (await repository.create({
            'recipientName': ' Nguyen An ',
            'phone': '+84 912 345 678',
            'addressLine': ' 12 Example Street ',
            'city': ' HCMC ',
          }, isDefault: true))
              .isDefault,
          isTrue);
      expect((await repository.update('1', {'city': 'Hanoi'})).city, 'Hanoi');
      expect((await repository.setDefault('1')).isDefault, isTrue);
      await repository.remove('1');

      expect(requests, [
        'GET /api/addresses',
        'POST /api/addresses',
        'PATCH /api/addresses/1',
        'POST /api/addresses/1/default',
        'DELETE /api/addresses/1',
      ]);
      expect(bodies['/api/addresses'], {
        'recipientName': 'Nguyen An',
        'phone': '+84 912 345 678',
        'addressLine': '12 Example Street',
        'ward': null,
        'district': null,
        'city': 'HCMC',
        'isDefault': true,
      });
      expect(bodies['/api/addresses/1'], {'city': 'Hanoi'});
    });

    test(
        'rejects malformed responses and invalid IDs without sending mutations',
        () async {
      var requests = 0;
      final api = ApiClient(
        client: MockClient((_) async {
          requests++;
          return ok({'addresses': 'not-a-list'});
        }),
      );
      addTearDown(api.close);
      final repository = AddressRepository(api);

      await expectLater(repository.list(), throwsA(isA<ApiException>()));
      await expectLater(repository.update('../1', {'city': 'HCMC'}),
          throwsA(isA<ApiException>()));
      await expectLater(
          repository.setDefault('0'), throwsA(isA<ApiException>()));
      await expectLater(
          repository.remove('../1'), throwsA(isA<ApiException>()));
      expect(requests, 1);
    });
  });
}
