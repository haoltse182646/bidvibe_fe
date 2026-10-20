import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../features/listings/listing_repository.dart';
import '../features/orders/order_repository.dart';
import '../models.dart';
import '../store.dart';
import 'api_client.dart';
import 'picked_image.dart';

// Authentication uses the BE. Other inherited features are still prototypes.
class RemoteAppStore extends AppStore {
  final api = ApiClient();
  final _storage = const FlutterSecureStorage();
  Future<void> _storageQueue = Future<void>.value();
  bool restoring = true;
  String? restoreError;
  String? sessionError;
  bool _disposed = false;
  final Map<String, String> _orderByListing = {};
  bool sellerLoading = false;

  RemoteAppStore({bool restoreOnStart = true}) {
    if (restoreOnStart) {
      unawaited(restoreSession());
    } else {
      restoring = false;
    }
  }

  // Dữ liệu và sự kiện thật đến từ BE; không chạy bot/giả lập của store prototype
  // (nếu chạy, toast "bị vượt giá" giả sẽ hiện trong phiên thật).
  @override
  bool get simulatesMarket => false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _persist(String? token) {
    final operation = _storageQueue.then(
      (_) => token == null
          ? _storage.delete(key: 'bidvibe.token')
          : _storage.write(key: 'bidvibe.token', value: token),
    );
    _storageQueue = operation.catchError((Object _) {});
    return operation;
  }

  UserAccount _user(Map<String, dynamic> data, String role) {
    if (![
          'bidder',
          'seller',
          'appraiser',
          'warehouse',
          'admin',
        ].contains(role) ||
        data['id'] == null ||
        data['fullName'] is! String) {
      throw const ApiException(
        'INVALID_RESPONSE',
        'Thông tin tài khoản không hợp lệ.',
      );
    }
    return UserAccount(
      id: '${data['id']}',
      name: data['fullName'] as String,
      email: '${data['email'] ?? ''}',
      phone: '${data['phone'] ?? ''}',
      role: role,
      shop: data['storeName'] as String?,
      password: '',
      status: '${data['status'] ?? 'active'}',
    );
  }

  Future<void> restoreSession() async {
    restoring = true;
    restoreError = null;
    _notify();
    try {
      await _storageQueue;
      api.token = await _storage.read(key: 'bidvibe.token');
      if (api.token != null) {
        final me = await api.request('/api/me');
        currentUser = _user(me, '${me['role']}');
        _afterSignIn();
      }
    } on ApiException catch (e) {
      if (e.code == 'UNAUTHORIZED' || e.code == 'ACCOUNT_SUSPENDED') {
        api.token = null;
        currentUser = null;
        await _persist(null);
        sessionError = e.message;
      } else {
        restoreError = e.message;
      }
    } catch (_) {
      restoreError = 'Không đọc được phiên đăng nhập. Vui lòng thử lại.';
    } finally {
      restoring = false;
      _notify();
    }
  }

  Future<void> authenticate(
    Map<String, dynamic> input, {
    bool register = false,
    bool ops = false,
  }) async {
    await _storageQueue;
    api.token = null;
    final data = await api.request(
      register
          ? '/api/auth/register'
          : ops
          ? '/api/auth/ops/login'
          : '/api/auth/login',
      body: input,
    );
    final token = data['token'];
    if (token is! String || token.isEmpty) {
      throw const ApiException(
        'INVALID_RESPONSE',
        'Máy chủ chưa trả token hợp lệ.',
      );
    }
    api.token = token;
    try {
      final me = await api.request('/api/me');
      final user = _user(me, '${me['role']}');
      await _persist(token);
      currentUser = user;
      sessionError = null;
      _notify();
      _afterSignIn();
    } catch (_) {
      api.token = null;
      rethrow;
    }
  }

  // Only accept the server's profile for the currently signed-in account.
  void applyProfile(Map<String, dynamic> data) {
    if (_disposed || currentUser == null) {
      return;
    }
    final next = _user(data, '${data['role']}');
    if (next.id != currentUser!.id || next.role != currentUser!.role) {
      throw const ApiException(
        'INVALID_RESPONSE',
        'Thông tin hồ sơ không khớp tài khoản đang đăng nhập.',
      );
    }
    currentUser = next;
    _notify();
  }

  @override
  void logout() {
    api.token = null;
    currentUser = null;
    _orderByListing.clear();
    sessionError = null;
    unawaited(
      _persist(null).catchError((Object _) {
        sessionError =
            'Chưa xóa được phiên đã lưu. Vui lòng thử đăng xuất lại.';
        _notify();
      }),
    );
    _notify();
  }

  // ---------------- Người bán (I05–I06) và tranh chấp (I07) ----------------

  ListingRepository get _listings => ListingRepository(api);

  /// Lỗi tải dữ liệu người bán gần nhất (null = ổn), để màn hình hiện nút thử lại.
  String? sellerError;
  int _sellerSeq = 0; // chỉ phản hồi của lần tải mới nhất được áp dụng
  final DraftProgress _draft = DraftProgress();

  void _afterSignIn() {
    if (currentUser?.role == 'seller') {
      // Bỏ dữ liệu mẫu của prototype trong store: người bán thật chỉ được thấy dữ liệu từ BE,
      // kể cả khi lần tải đầu thất bại (khi đó thấy danh sách trống kèm lỗi, không phải hàng giả).
      sellerListings.clear();
      sellerShipments.clear();
      _orderByListing.clear();
      unawaited(loadSeller());
    }
  }

  /// Thông báo ngắn; bỏ qua khi store đã huỷ (thao tác bất đồng bộ về muộn).
  void _say(String title, String body, {bool danger = false}) {
    if (!_disposed) showMessage(title, body, danger: danger);
  }

  /// Tải lại tin đăng + đơn đã bán của người bán đang đăng nhập.
  Future<void> loadSeller() async {
    final user = currentUser;
    if (user == null || user.role != 'seller' || _disposed) return;
    final seq = ++_sellerSeq;
    sellerLoading = true;
    sellerError = null;
    _notify();
    try {
      final data = await _listings.loadSeller(fallbackShop: user.shop ?? user.name);
      // Bỏ kết quả cũ: có lần tải mới hơn, hoặc đã đổi / thoát tài khoản.
      if (_disposed || seq != _sellerSeq || currentUser?.id != user.id) return;
      user.shop = data.shop;
      sellerListings
        ..clear()
        ..addAll(data.listings);
      sellerShipments
        ..clear()
        ..addAll(data.shipments);
      _orderByListing
        ..clear()
        ..addAll(data.orderByListing);
    } on ApiException catch (e) {
      if (seq == _sellerSeq && !_handleAuth(e)) sellerError = e.message;
    } finally {
      if (seq == _sellerSeq) sellerLoading = false;
      _notify();
    }
  }

  /// UNAUTHORIZED / ACCOUNT_SUSPENDED từ thao tác ở store: đăng xuất như khôi phục phiên.
  bool _handleAuth(ApiException e) {
    if (e.code != 'UNAUTHORIZED' && e.code != 'ACCOUNT_SUSPENDED') return false;
    logout();
    sessionError = e.code == 'ACCOUNT_SUSPENDED'
        ? 'Tài khoản đã bị tạm khóa.'
        : 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    _notify();
    return true;
  }

  bool handleApiException(ApiException e) => _handleAuth(e);

  /// Chạy một thao tác ghi: báo lỗi của BE, không tự thử lại. Chỉ tải lại dữ liệu
  /// khi thao tác đã thành công hoặc chưa rõ kết quả (mất mạng / quá thời gian).
  Future<bool> _write(Future<void> Function() action, {String? ok, String okBody = ''}) async {
    var success = true;
    var reload = true;
    try {
      await action();
    } on ApiException catch (e) {
      success = false;
      reload = e.code == 'NETWORK' || e.code == 'TIMEOUT';
      if (!_handleAuth(e)) _say('Không thực hiện được', e.message, danger: true);
    }
    if (success && ok != null) _say(ok, okBody);
    if (reload && !_disposed && currentUser != null) await loadSeller();
    return success;
  }

  @override
  Future<PriceSuggestion?> suggestStartingPrice({required String cat, required String cond}) async {
    try {
      return await _listings.suggestPrice(category: cat, condition: cond);
    } on ApiException catch (e) {
      if (!_handleAuth(e)) _say('Chưa có gợi ý giá', e.message, danger: true);
      rethrow;
    }
  }

  @override
  Future<bool> createListing({
    required String title,
    required String cat,
    required int start,
    String desc = '',
    String cond = 'Đã qua sử dụng',
    int durationHours = 24,
    List<PickedImage> images = const [],
  }) async {
    final ok = await _write(
      () async {
        await _listings.createAndSubmit(
          title: title,
          category: cat,
          startingPrice: start,
          durationHours: durationHours,
          condition: cond,
          description: desc,
          images: images,
          progress: _draft,
        );
      },
      ok: 'Đã gửi để thẩm định',
      okBody: 'Phiên được công khai sau khi thẩm định viên duyệt.',
    );
    if (ok) {
      // Tin đã gửi xong: lần tạo tiếp theo là tin mới.
      _draft.reset();
    }
    return ok;
  }

  @override
  Future<bool> updateListing(
    String id, {
    required String title,
    required String desc,
    required int start,
    required int durationHours,
    required String cond,
  }) => _write(
    () => _listings.update(id, {
      'title': title,
      'description': desc,
      'startingPrice': start,
      'durationHours': durationHours,
      'condition': cond,
    }),
  );

  @override
  Future<bool> sellerSubmitMoreInfo(
    String listingId, {
    List<PickedImage> images = const [],
  }) => _write(() => _listings.resubmit(listingId, images: images));

  @override
  Future<void> sellerMarkShipped(String listingId) async {
    final orderId = _orderByListing[listingId];
    if (orderId == null) {
      _say('Chưa tìm thấy đơn hàng', 'Chỉ báo gửi hàng được cho đơn đã thanh toán.', danger: true);
      return;
    }
    await _write(
      () => _listings.shipToWarehouse(orderId),
      ok: 'Đã báo gửi hàng',
      okBody: 'Kho BidVibe sẽ xác nhận khi nhận được hàng.',
    );
  }

  @override
  Future<bool> raiseDispute({
    required String source,
    String? auctionId,
    String? listingId,
    required String title,
    required String reason,
    String detail = '',
    List<PickedImage> images = const [],
  }) async {
    try {
      String? orderId;
      if (source == 'seller') {
        orderId = _orderByListing[listingId];
      } else if (auctionId != null) {
        final orders = await OrderRepository(api).mine();
        orderId = orders.where((o) => o.auctionId == auctionId).firstOrNull?.id;
      }
      if (orderId == null) {
        _say('Chưa tìm thấy đơn hàng', 'Chỉ mở được tranh chấp cho đơn đã thanh toán.', danger: true);
        return false;
      }
      await _listings.openDispute(
        orderId: orderId,
        title: title,
        reason: detail.trim().isEmpty ? reason : '$reason — ${detail.trim()}',
        images: images,
      );
      _say('Đã gửi tranh chấp', 'Ký quỹ được giữ lại. Admin sẽ phản hồi sớm.');
    } on ApiException catch (e) {
      if (!_handleAuth(e)) _say('Không gửi được tranh chấp', e.message, danger: true);
      return false;
    }
    if (!_disposed && currentUser != null) await loadSeller();
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    api.close();
    super.dispose();
  }
}
