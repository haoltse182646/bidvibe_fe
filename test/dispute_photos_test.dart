import 'dart:convert';
import 'dart:typed_data';

import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/core/picked_image.dart';
import 'package:bidvibe/features/disputes/dispute_repository.dart';
import 'package:bidvibe/screens/orders/dispute_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';

http.Response ok(Map<String, dynamic> data, [int status = 200]) => http.Response(
      jsonEncode({'success': true, 'data': data}),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

http.Response fail(String code, String message, int status) => http.Response(
      jsonEncode({'success': false, 'error': {'code': code, 'message': message}}),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> dispute({String status = 'open', int photos = 1}) => {
      'id': '7',
      'orderId': '120',
      'itemTitle': 'Ong kinh Helios',
      'title': 'Hang loi',
      'source': 'bidder',
      'status': status,
      'resolution': 'none',
      'escrowAmount': 1000000,
      'timeline': <Object>[],
      'photos': [
        for (var i = 0; i < photos; i++)
          {'id': '${i + 1}', 'url': 'https://cdn.test/p$i.png', 'uploaderRole': 'bidder', 'createdAt': '2026-10-20T01:00:00Z'},
      ],
    };

final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');
Future<List<XFile>> pickOne(int limit) async => [XFile.fromData(png, name: 'them.png')];

/// Cuộn tới nút rồi bấm: nút nằm dưới vùng nhìn thấy của màn hình test.
Future<void> tapVisible(WidgetTester t, String text) async {
  await t.ensureVisible(find.text(text));
  await t.pump();
  await t.tap(find.text(text));
}

Future<void> show(WidgetTester t, Widget w) async {
  await t.pumpWidget(MaterialApp(home: w));
  await t.pumpAndSettle();
}

void main() {
  group('DisputeRepository.addPhotos', () {
    test('tải lên purpose=dispute trước rồi gắn photoUrls vào đúng tranh chấp', () async {
      final seen = <String>[];
      Map<String, dynamic>? body;
      final api = ApiClient(
        client: MockClient((r) async {
          seen.add('${r.method} ${r.url.path}${r.url.query.isEmpty ? '' : '?${r.url.query}'}');
          if (r.url.path == '/api/uploads/images') {
            return ok({'urls': ['https://cdn.test/n1.png', 'https://cdn.test/n2.png']}, 201);
          }
          body = jsonDecode(r.body) as Map<String, dynamic>;
          return ok({'id': '7'}, 201);
        }),
      )..token = 't';
      addTearDown(api.close);
      await DisputeRepository(api).addPhotos('7', [
        PickedImage(Uint8List(3), 'a.png'),
        PickedImage(Uint8List(3), 'b.png'),
      ]);
      expect(seen, ['POST /api/uploads/images?purpose=dispute', 'POST /api/disputes/7/photos']);
      expect(body, {'photoUrls': ['https://cdn.test/n1.png', 'https://cdn.test/n2.png']});
    });

    test('mã sai, không có ảnh hoặc quá 6 ảnh: báo lỗi và không gửi request nào', () async {
      var calls = 0;
      final api = ApiClient(
        client: MockClient((_) async {
          calls++;
          return ok({});
        }),
      )..token = 't';
      addTearDown(api.close);
      final repo = DisputeRepository(api);
      final one = [PickedImage(Uint8List(3), 'a.png')];
      await expectLater(repo.addPhotos('../7', one), throwsA(isA<ApiException>()));
      await expectLater(repo.addPhotos('7', const []), throwsA(isA<ApiException>()));
      await expectLater(
        repo.addPhotos('7', [for (var i = 0; i < 7; i++) PickedImage(Uint8List(3), '$i.png')]),
        throwsA(isA<ApiException>()),
      );
      expect(calls, 0);
    });

    test('upload lỗi thì không gắn ảnh vào tranh chấp', () async {
      final seen = <String>[];
      final api = ApiClient(
        client: MockClient((r) async {
          seen.add(r.url.path);
          return fail('UPLOAD_FAILED', 'loi', 502);
        }),
      )..token = 't';
      addTearDown(api.close);
      await expectLater(
        DisputeRepository(api).addPhotos('7', [PickedImage(Uint8List(3), 'a.png')]),
        throwsA(isA<ApiException>()),
      );
      expect(seen, ['/api/uploads/images']);
    });
  });

  group('Màn chi tiết tranh chấp: bổ sung ảnh', () {
    testWidgets('chọn ảnh → tải lên → gắn vào tranh chấp → tải lại và hiện ảnh mới', (t) async {
      var photos = 1;
      final seen = <String>[];
      final api = ApiClient(
        client: MockClient((r) async {
          seen.add('${r.method} ${r.url.path}');
          if (r.url.path == '/api/uploads/images') return ok({'urls': ['https://cdn.test/n.png']}, 201);
          if (r.url.path == '/api/disputes/7/photos') {
            photos = 2;
            return ok({'id': '7'}, 201);
          }
          return ok({'disputes': [dispute(photos: photos)]});
        }),
      )..token = 't';
      addTearDown(api.close);
      await show(t, DisputeDetailScreen(api: api, disputeId: '7', pickImages: pickOne));
      expect(find.text('Ảnh bằng chứng (1)'), findsOneWidget);
      await tapVisible(t, 'Bổ sung ảnh');
      await t.pumpAndSettle();
      expect(seen, [
        'GET /api/disputes/mine',
        'POST /api/uploads/images',
        'POST /api/disputes/7/photos',
        'GET /api/disputes/mine',
      ]);
      expect(find.text('Ảnh bằng chứng (2)'), findsOneWidget);
      expect(find.text('Đã bổ sung 1 ảnh bằng chứng.'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('tranh chấp đã xử lý hoặc đã đủ 12 ảnh: không có nút bổ sung', (t) async {
      var current = dispute(status: 'resolved');
      final api = ApiClient(client: MockClient((_) async => ok({'disputes': [current]})))..token = 't';
      addTearDown(api.close);
      await show(t, DisputeDetailScreen(api: api, disputeId: '7', pickImages: pickOne));
      expect(find.text('Bổ sung ảnh'), findsNothing);
      expect(find.text('Ảnh bằng chứng (1)'), findsOneWidget, reason: 'ảnh cũ vẫn hiện để xem');
      await t.pumpWidget(const SizedBox.shrink());

      current = dispute(photos: 12);
      await show(t, DisputeDetailScreen(api: api, disputeId: '7', pickImages: pickOne));
      expect(find.text('Bổ sung ảnh'), findsNothing);
      await t.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('BE từ chối (đã xử lý trong lúc chọn ảnh): báo lý do và tải lại dữ liệu', (t) async {
      var gets = 0;
      final api = ApiClient(
        client: MockClient((r) async {
          if (r.url.path == '/api/uploads/images') return ok({'urls': ['https://cdn.test/n.png']}, 201);
          if (r.url.path == '/api/disputes/7/photos') {
            return fail('INVALID_STATE', 'Tranh chap da duoc xu ly, khong the bo sung anh', 409);
          }
          gets++;
          return ok({'disputes': [dispute(status: gets > 1 ? 'resolved' : 'open')]});
        }),
      )..token = 't';
      addTearDown(api.close);
      await show(t, DisputeDetailScreen(api: api, disputeId: '7', pickImages: pickOne));
      await tapVisible(t, 'Bổ sung ảnh');
      await t.pumpAndSettle();
      expect(find.text('Tranh chap da duoc xu ly, khong the bo sung anh'), findsOneWidget);
      expect(gets, 2);
      expect(find.text('Bổ sung ảnh'), findsNothing, reason: 'sau khi tải lại thấy tranh chấp đã đóng');
      await t.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('bấm đúp chỉ tải ảnh một lần', (t) async {
      var uploads = 0;
      final api = ApiClient(
        client: MockClient((r) async {
          if (r.url.path == '/api/uploads/images') {
            uploads++;
            await Future<void>.delayed(const Duration(milliseconds: 200));
            return ok({'urls': ['https://cdn.test/n.png']}, 201);
          }
          if (r.url.path == '/api/disputes/7/photos') return ok({'id': '7'}, 201);
          return ok({'disputes': [dispute()]});
        }),
      )..token = 't';
      addTearDown(api.close);
      await show(t, DisputeDetailScreen(api: api, disputeId: '7', pickImages: pickOne));
      await tapVisible(t, 'Bổ sung ảnh');
      await t.pump();
      await t.pump();
      expect(find.text('Đang tải ảnh…'), findsOneWidget);
      await t.tap(find.text('Đang tải ảnh…'), warnIfMissed: false);
      await t.pump();
      await t.pumpAndSettle();
      expect(uploads, 1);
      await t.pumpWidget(const SizedBox.shrink());
    });
  });
}
