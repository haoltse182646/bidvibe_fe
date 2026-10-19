import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:bidvibe/core/api_client.dart';
import 'package:bidvibe/core/picked_image.dart';
import 'package:bidvibe/core/remote_app_store.dart';
import 'package:bidvibe/models.dart';
import 'package:bidvibe/store.dart';
import 'package:bidvibe/screens/customer/customer_dispute.dart';
import 'package:bidvibe/screens/seller/seller_create.dart';
import 'package:bidvibe/screens/seller/seller_list.dart';
import 'package:bidvibe/widgets/store_toast.dart';

/// Hành vi của RemoteAppStore phía người bán / tranh chấp và các màn dùng nó:
/// thử lại không tạo bản nháp thừa, thất bại thì không đóng màn, không gửi hai lần.

http.Response ok(Map<String, dynamic> data, [int status = 200]) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response fail(String code, String message, int status) => http.Response(
  jsonEncode({
    'success': false,
    'error': {'code': code, 'message': message},
  }),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class TestRemoteStore extends RemoteAppStore {
  final ApiClient _testApi;
  @override
  ApiClient get api => _testApi;
  TestRemoteStore(this._testApi) : super(restoreOnStart: false);
}

TestRemoteStore sellerStore(MockClientHandler handler) {
  final api = ApiClient(client: MockClient(handler))..token = 't';
  return TestRemoteStore(api)
    ..currentUser = UserAccount(id: '9', name: 'Long', email: 'long@x.vn', role: 'seller', shop: 'Shop Thử');
}

const emptySeller = {'listings': <Object>[]};

void main() {
  test('gửi tin lỗi giữa chừng rồi thử lại: dùng lại bản nháp cũ, không tạo thêm', () async {
    final calls = <String>[];
    var failPhotos = true;
    var uploads = 0;
    final store = sellerStore((r) async {
      calls.add('${r.method} ${r.url.path}');
      switch ('${r.method} ${r.url.path}') {
        case 'POST /api/listings':
          return ok({'id': '77'}, 201);
        case 'PATCH /api/listings/77':
          return ok({});
        case 'POST /api/uploads/images':
          uploads++;
          return ok({'urls': ['https://cdn.test/$uploads.png']}, 201);
        case 'POST /api/listings/77/photos':
          if (failPhotos) return fail('SERVER_ERROR', 'Lỗi máy chủ', 500);
          return ok({});
        case 'POST /api/listings/77/submit':
          return ok({});
        case 'GET /api/listings/mine':
          return ok(emptySeller);
        case 'GET /api/orders/selling':
          return ok({'orders': <Object>[]});
      }
      return fail('NOT_FOUND', 'x', 404);
    });
    addTearDown(store.dispose);

    final images = [PickedImage(Uint8List(3), 'a.png')];
    expect(await store.createListing(title: 'A', cat: 'shoes', start: 1000000, images: images), isFalse);
    failPhotos = false;
    expect(await store.createListing(title: 'A (sửa)', cat: 'shoes', start: 1100000, images: images), isTrue);
    expect(uploads, 1, reason: 'cùng bộ ảnh: không tải lên lần hai');
    expect(calls.where((c) => c == 'POST /api/listings').length, 1, reason: 'không tạo bản nháp thứ hai');
    expect(calls, contains('PATCH /api/listings/77'), reason: 'đồng bộ nội dung mới nhất vào bản nháp');
    expect(calls.where((c) => c == 'POST /api/listings/77/submit').length, 1);

    // Tin đã gửi xong: lần tạo tiếp theo là tin mới.
    await store.createListing(title: 'B', cat: 'shoes', start: 1000000, images: [PickedImage(Uint8List(3), 'b.png')]);
    expect(calls.where((c) => c == 'POST /api/listings').length, 2);
  });

  test('lỗi nghiệp vụ không tải lại dữ liệu; lỗi mạng (chưa rõ kết quả) thì có', () async {
    var loads = 0;
    var mode = 'business';
    final store = sellerStore((r) async {
      if (r.url.path == '/api/listings/mine') {
        loads++;
        return ok(emptySeller);
      }
      if (r.url.path == '/api/orders/selling') return ok({'orders': <Object>[]});
      if (mode == 'network') throw http.ClientException('offline');
      return fail('INVALID_STATE', 'Không đúng trạng thái', 409);
    });
    addTearDown(store.dispose);

    expect(await store.sellerSubmitMoreInfo('5'), isFalse);
    expect(loads, 0, reason: 'BE đã từ chối rõ ràng: không có gì thay đổi để tải lại');
    mode = 'network';
    expect(await store.sellerSubmitMoreInfo('5'), isFalse);
    expect(loads, 1, reason: 'mất mạng: chưa rõ đã gửi chưa, tải lại để biết');
  });

  test('mở tranh chấp: trả false khi BE từ chối, true khi thành công', () async {
    var accept = false;
    final store = sellerStore((r) async {
      switch (r.url.path) {
        case '/api/orders/mine':
          return ok({
            'orders': [
              {'id': '501', 'auctionId': '50', 'title': 'Hàng', 'paymentStatus': 'paid', 'payoutStatus': 'pending'},
            ],
          });
        case '/api/disputes':
          return accept ? ok({'id': '1'}, 201) : fail('DISPUTE_OPEN', 'Đơn đã có tranh chấp', 409);
        case '/api/listings/mine':
          return ok(emptySeller);
        case '/api/orders/selling':
          return ok({'orders': <Object>[]});
      }
      return fail('NOT_FOUND', 'x', 404);
    });
    addTearDown(store.dispose);

    Future<bool> open(String auction) =>
        Future.value(store.raiseDispute(source: 'bidder', auctionId: auction, title: 't', reason: 'r'));
    expect(await open('50'), isFalse);
    expect(await open('999'), isFalse, reason: 'không có đơn của phiên này');
    accept = true;
    expect(await open('50'), isTrue);
  });

  test('tải người bán lỗi thì ghi lỗi để hiện nút thử lại, thành công thì xoá lỗi', () async {
    var offline = true;
    final store = sellerStore((r) async {
      if (offline) throw http.ClientException('offline');
      if (r.url.path == '/api/listings/mine') return ok(emptySeller);
      return ok({'orders': <Object>[]});
    });
    addTearDown(store.dispose);
    await store.loadSeller();
    expect(store.sellerError, isNotNull);
    expect(store.sellerLoading, isFalse);
    offline = false;
    await store.loadSeller();
    expect(store.sellerError, isNull);
  });

  test('hai lần tải chồng nhau: kết quả cũ về muộn không ghi đè kết quả mới', () async {
    final first = Completer<http.Response>();
    var calls = 0;
    Map<String, dynamic> listing(String id) => {
      'id': id, 'title': 'Tin $id', 'category': 'shoes', 'status': 'pending_appraisal',
      'startingPrice': 1000, 'durationHours': 24, 'auction': null,
    };
    final store = sellerStore((r) async {
      if (r.url.path == '/api/listings/mine') {
        calls++;
        if (calls == 1) return first.future; // lần 1 chậm
        return ok({'listings': [listing('2')]});
      }
      return ok({'orders': <Object>[]});
    });
    addTearDown(store.dispose);

    final slow = store.loadSeller();
    await store.loadSeller(); // lần 2 nhanh, mới hơn
    expect(store.sellerListings.map((l) => l.id), ['2']);
    first.complete(ok({'listings': [listing('1')]}));
    await slow;
    expect(store.sellerListings.map((l) => l.id), ['2'], reason: 'bỏ kết quả cũ');
  });

  test('đăng nhập người bán thật: bỏ dữ liệu mẫu, tải lỗi thì danh sách trống chứ không hiện hàng giả', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final api = ApiClient(
      client: MockClient((r) async {
        switch (r.url.path) {
          case '/api/auth/login':
            return ok({'token': 'tok', 'role': 'seller', 'account': {'id': '9', 'fullName': 'Long'}});
          case '/api/me':
            return ok({'id': '9', 'fullName': 'Long', 'email': 'l@x.vn', 'role': 'seller'});
        }
        throw http.ClientException('offline'); // tải tin đăng / đơn bán thất bại
      }),
    );
    final store = TestRemoteStore(api);
    addTearDown(store.dispose);
    expect(store.sellerListings, isNotEmpty, reason: 'store mẫu có sẵn dữ liệu giả của prototype');
    await store.authenticate({'email': 'l@x.vn', 'password': 'x'});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(store.currentUser?.role, 'seller');
    expect(store.sellerListings, isEmpty, reason: 'không hiện dữ liệu mẫu như thể là dữ liệu thật');
    expect(store.sellerShipments, isEmpty);
    expect(store.sellerError, isNotNull);
  });

  testWidgets('bản thật không chạy mô phỏng: 1 phút trôi qua không có toast giả hay thay đổi dữ liệu mẫu', (t) async {
    final store = TestRemoteStore(ApiClient(client: MockClient((_) async => fail('NOT_FOUND', 'x', 404))));
    final before = store.auctions.map((a) => '${a.id}:${a.price}:${a.count}').toList();
    var notified = 0;
    store.addListener(() => notified++);
    await t.pump(const Duration(seconds: 60));
    expect(store.toastId, isNull, reason: 'không có "bị vượt giá" giả');
    expect(store.auctions.map((a) => '${a.id}:${a.price}:${a.count}').toList(), before, reason: 'bot không đặt giá');
    expect(notified, greaterThan(50), reason: 'vẫn có nhịp mỗi giây cho các đồng hồ đếm ngược');
    store.dispose();
  });

  group('màn hình', () {
    Future<void> pump(WidgetTester t, AppStore store, Widget child) async {
      t.view.physicalSize = const Size(420, 1200);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        ChangeNotifierProvider<AppStore>.value(value: store, child: MaterialApp(home: child)),
      );
      await t.pump();
    }

    testWidgets('tranh chấp: bấm đúp chỉ gửi một lần; thất bại thì không đóng màn và giữ nội dung', (t) async {
      final gate = Completer<bool>();
      final store = _DisputeStore(gate);
      await pump(
        t,
        store,
        Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(c).push(
                MaterialPageRoute<void>(builder: (_) => const CustomerDisputeScreen(source: 'bidder', title: 'Hàng', auctionId: '50')),
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      );
      await t.tap(find.text('mở'));
      await t.pumpAndSettle();
      await t.tap(find.text('Hàng không đúng mô tả'));
      await t.pump();
      await t.tap(find.text('Gửi tranh chấp'));
      await t.pump();
      expect(find.text('Đang gửi…'), findsOneWidget);
      await t.tap(find.text('Đang gửi…'), warnIfMissed: false);
      await t.pump();
      expect(store.calls, 1, reason: 'nút bị khoá trong lúc đang gửi');

      gate.complete(false); // BE từ chối
      await t.pumpAndSettle();
      expect(find.text('Gửi tranh chấp'), findsOneWidget, reason: 'vẫn ở màn tranh chấp');
      expect(find.text('mở'), findsNothing);

      store.next = Completer<bool>()..complete(true);
      await t.tap(find.text('Gửi tranh chấp'));
      await t.pumpAndSettle();
      expect(find.text('mở'), findsOneWidget, reason: 'thành công thì đóng màn');
      expect(store.calls, 2);
      await t.pumpWidget(const SizedBox());
      store.dispose();
    });

    testWidgets('tạo tin: bấm đúp chỉ tạo một tin', (t) async {
      // Màn tạo tin là màn prototype có sẵn; font của môi trường test rộng hơn thật nên
      // một hàng của nó báo tràn chữ. Chỉ bỏ qua "overflowed" trong test này.
      final original = FlutterError.onError;
      FlutterError.onError = (d) {
        if (!d.exceptionAsString().contains('overflowed')) original?.call(d);
      };
      addTearDown(() => FlutterError.onError = original);
      final gate = Completer<bool>();
      final store = _CreateStore(gate);
      final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');
      await pump(t, store, Scaffold(body: SellerCreateScreen(onDone: () {}, pickImages: (_) async => [XFile.fromData(png, name: 'a.png')])));
      await t.tap(find.byKey(const ValueKey('photo-slot-0')));
      await t.pump();
      await t.pump();
      expect(find.byType(Image), findsOneWidget);
      await t.enterText(find.byType(TextField).at(0), 'Giày Nike');
      await t.enterText(find.byType(TextField).at(2), '1200000');
      await t.pump();
      await t.drag(find.byType(ListView).first, const Offset(0, -2000));
      await t.pump();
      await t.tap(find.text('Gửi để thẩm định'));
      await t.pump();
      await t.tap(find.text('Đang gửi…'), warnIfMissed: false);
      await t.pump();
      expect(store.creates, 1);
      gate.complete(true);
      await t.pumpAndSettle();
      expect(find.text('Đã tạo phiếu ký gửi'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      store.dispose();
    });

    testWidgets('gợi ý giá AI biến mất khi đổi tình trạng (giá phụ thuộc tình trạng)', (t) async {
      final original = FlutterError.onError;
      FlutterError.onError = (d) {
        if (!d.exceptionAsString().contains('overflowed')) original?.call(d);
      };
      addTearDown(() => FlutterError.onError = original);
      final store = _AiStore();
      await pump(t, store, Scaffold(body: SellerCreateScreen(onDone: () {})));
      await t.enterText(find.byType(TextField).at(0), 'Giày Nike');
      await t.pump();
      await t.drag(find.byType(ListView).first, const Offset(0, -600));
      await t.pump();
      await t.tap(find.text('Nhờ AI gợi ý giá'));
      await t.pumpAndSettle();
      expect(find.text('Dùng giá này'), findsOneWidget);
      await t.tap(find.text('Đã qua sử dụng'));
      await t.pumpAndSettle();
      expect(find.text('Dùng giá này'), findsNothing, reason: 'gợi ý cũ không còn đúng với tình trạng mới');
      expect(find.text('Nhờ AI gợi ý giá'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      store.dispose();
    });

    testWidgets('thông báo của store hiện thành SnackBar, mỗi thông báo một lần', (t) async {
      final store = _PokeStore();
      await pump(t, store, const Scaffold(body: StoreToastListener(child: SizedBox.expand())));
      expect(find.byType(SnackBar), findsNothing);
      store.showMessage('Không gửi được tranh chấp', 'Đơn đã có tranh chấp', danger: true);
      await t.pump();
      await t.pump();
      expect(find.text('Không gửi được tranh chấp'), findsOneWidget);
      expect(find.text('Đơn đã có tranh chấp'), findsOneWidget);
      // Cập nhật store không liên quan không làm hiện lại cùng thông báo.
      store.poke();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Không gửi được tranh chấp'), findsOneWidget);
      store.showMessage('Tin khác', 'Nội dung khác');
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Tin khác'), findsOneWidget, reason: 'thông báo mới thay thế thông báo cũ');
      await t.pumpWidget(const SizedBox());
      store.dispose();
    });

    testWidgets('tải người bán lỗi: hiện banner lỗi và nút Thử lại gọi tải lại', (t) async {
      var offline = true;
      var loads = 0;
      final store = sellerStore((r) async {
        if (r.url.path == '/api/listings/mine') loads++;
        if (offline) throw http.ClientException('offline');
        return r.url.path == '/api/listings/mine' ? ok(emptySeller) : ok({'orders': <Object>[]});
      });
      await store.loadSeller();
      await pump(t, store, const Scaffold(body: SellerListScreen()));
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);
      offline = false;
      await t.tap(find.text('Thử lại'));
      await t.pumpAndSettle();
      expect(loads, 2);
      expect(find.text('Thử lại'), findsNothing, reason: 'tải được thì banner biến mất');
      await t.pumpWidget(const SizedBox());
      store.dispose();
    });
  });
}

class _PokeStore extends AppStore {
  void poke() => notifyListeners();
}

class _AiStore extends AppStore {
  @override
  FutureOr<PriceSuggestion?> suggestStartingPrice({required String cat, required String cond}) =>
      PriceSuggestion(price: cond == 'Như mới' ? 3300000 : 3000000, low: 2750000, high: 4600000, explanation: 'Dựa trên 5 phiên.', fromHistory: true);
}

class _DisputeStore extends AppStore {
  Completer<bool> next;
  int calls = 0;
  _DisputeStore(this.next);
  @override
  FutureOr<bool> raiseDispute({
    required String source,
    String? auctionId,
    String? listingId,
    required String title,
    required String reason,
    String detail = '',
  }) {
    calls++;
    return next.future;
  }
}

class _CreateStore extends AppStore {
  final Completer<bool> gate;
  int creates = 0;
  _CreateStore(this.gate);
  @override
  FutureOr<bool> createListing({
    required String title,
    required String cat,
    required int start,
    String desc = '',
    String cond = 'Đã qua sử dụng',
    int durationHours = 24,
    List<PickedImage> images = const [],
  }) {
    creates++;
    return gate.future;
  }
}
