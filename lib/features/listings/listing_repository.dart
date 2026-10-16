import '../../core/api_client.dart';
import '../../models.dart';

String _s(dynamic v, [String d = '']) => v == null ? d : '$v';
int _i(dynamic v) => v is num ? v.toInt() : 0;
Map<String, dynamic> _m(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];
DateTime? _dt(dynamic v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

/// Giai đoạn đơn (BE) → bước 1–5 của phiếu gửi kho phía người bán.
int shipmentStep(String stage) => switch (stage) {
  'awaiting_seller_shipment' => 1,
  'in_transit_to_warehouse' ||
  'inspecting' ||
  'inspected' ||
  'inspection_failed' ||
  'packed' => 2,
  'shipped' => 3,
  'delivered' => 4,
  'completed' => 5,
  _ => 1,
};

/// Dữ liệu người bán đã quy về model của app: tin đăng, phiếu gửi kho và map
/// listingId → orderId (để gửi kho / mở tranh chấp đúng đơn).
class SellerData {
  final String shop;
  final List<SellerListing> listings;
  final List<Shipment> shipments;
  final Map<String, String> orderByListing;
  const SellerData(
    this.shop,
    this.listings,
    this.shipments,
    this.orderByListing,
  );
}

/// Tiến độ tạo một tin mới, giữ ở nơi gọi để thử lại đúng bản nháp đã tạo.
class DraftProgress {
  String? id;
  bool photosAdded = false;
}

class ListingRepository {
  final ApiClient api;
  const ListingRepository(this.api);

  static bool validId(String id) => RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(id);
  static void checkId(String id) {
    if (!validId(id)) {
      throw const ApiException('VALIDATION_ERROR', 'Mã không hợp lệ.');
    }
  }

  /// Ảnh mẫu: tải ảnh thật lên cần Storage, nhóm tạm dùng URL mẫu.
  static List<String> sampleUrls(String seed, int n) => [
    for (var i = 0; i < (n < 1 ? 1 : n); i++)
      'https://picsum.photos/seed/bv$seed-$i/800/600',
  ];

  /// Tạo tin → thêm ảnh → gửi thẩm định. Mỗi bước xong được ghi vào [progress]
  /// nên khi một bước lỗi và người bán bấm gửi lại, ta làm tiếp tin nháp cũ
  /// (cập nhật theo nội dung mới) thay vì tạo thêm một bản nháp mồ côi.
  Future<String> createAndSubmit({
    required String title,
    required String category,
    required int startingPrice,
    required int durationHours,
    required String condition,
    String description = '',
    int photos = 2,
    required DraftProgress progress,
  }) async {
    final fields = {
      'title': title,
      'categoryCode': category,
      'startingPrice': startingPrice,
      'durationHours': durationHours,
      if (description.trim().isNotEmpty) 'description': description.trim(),
      'condition': condition,
    };
    var id = progress.id;
    if (id == null) {
      final created = await api.request(
        '/api/listings',
        method: 'POST',
        body: fields,
      );
      id = _s(created['id']);
      checkId(id);
      progress.id = id;
    } else {
      await update(id, fields); // lần gửi lại: đồng bộ nội dung mới nhất
    }
    if (!progress.photosAdded) {
      await api.request(
        '/api/listings/$id/photos',
        method: 'POST',
        body: {'urls': sampleUrls(id, photos)},
      );
      progress.photosAdded = true;
    }
    await api.request('/api/listings/$id/submit', method: 'POST');
    return id;
  }

  Future<void> update(String id, Map<String, dynamic> fields) async {
    checkId(id);
    await api.request('/api/listings/$id', method: 'PATCH', body: fields);
  }

  Future<void> resubmit(String id, {int extraPhotos = 0}) async {
    checkId(id);
    if (extraPhotos > 0) {
      await api.request(
        '/api/listings/$id/photos',
        method: 'POST',
        body: {
          'urls': sampleUrls(
            '$id-more${DateTime.now().millisecondsSinceEpoch}',
            extraPhotos,
          ),
        },
      );
    }
    await api.request('/api/listings/$id/resubmit', method: 'POST');
  }

  Future<PriceSuggestion> suggestPrice({required String category, required String condition}) async {
    final d = await api.request(
      '/api/ai/suggest-price',
      method: 'POST',
      body: {'categoryCode': category, 'condition': condition},
    );
    final range = d['expectedFinalRange'];
    final price = _i(d['suggestedStartingPrice']);
    if (price <= 0) {
      throw const ApiException('INVALID_RESPONSE', 'Không đọc được gợi ý giá.');
    }
    return PriceSuggestion(
      price: price,
      low: range is List && range.length == 2 ? _i(range[0]) : price,
      high: range is List && range.length == 2 ? _i(range[1]) : price,
      explanation: _s(d['explanation']),
      fromHistory: d['basis'] == 'history',
    );
  }

  Future<void> shipToWarehouse(String orderId) async {
    checkId(orderId);
    await api.request('/api/orders/$orderId/ship-to-warehouse', method: 'POST');
  }

  Future<void> openDispute({
    required String orderId,
    required String title,
    required String reason,
  }) async {
    checkId(orderId);
    await api.request(
      '/api/disputes',
      method: 'POST',
      body: {'orderId': orderId, 'title': title, 'reason': reason},
    );
  }

  /// Tin đăng + đơn đã bán của tôi, gộp thành trạng thái hiển thị của người bán.
  Future<SellerData> loadSeller({required String fallbackShop}) async {
    final listings = _l(
      (await api.request('/api/listings/mine?limit=100'))['listings'],
    );
    final orders = _l(
      (await api.request('/api/orders/selling?limit=100'))['orders'],
    );
    // BE không trả tên gian hàng lúc đăng nhập; lấy từ đơn đã bán của chính mình.
    final storeName = orders.isEmpty
        ? ''
        : _s(_m(orders.first['seller'])['storeName']);
    final shop = storeName.isNotEmpty ? storeName : fallbackShop;
    final orderByAuction = {for (final o in orders) _s(o['auctionId']): o};

    final out = <SellerListing>[];
    final shipments = <Shipment>[];
    final orderByListing = <String, String>{};
    for (final j in listings) {
      final raw = _s(j['status']);
      if (raw == 'draft') continue;
      final auction = _m(j['auction']);
      final aid = _s(auction['id']);
      final order = orderByAuction[aid];
      final stage = _s(order?['stage']);
      final id = _s(j['id']);
      final reason = _s(_m(j['lastAppraisal'])['reason']);

      var status = switch (raw) {
        'pending_appraisal' => 'appraisal',
        'needs_info' => 'needinfo',
        'rejected' => 'rejected',
        'live' => 'live',
        _ => 'cancelled',
      };
      String? note =
          (raw == 'rejected' || raw == 'needs_info') && reason.isNotEmpty
          ? reason
          : null;
      if (raw == 'ended') {
        if (order == null) {
          note = 'Phiên kết thúc không có người đặt giá.';
        } else if (_s(order['payoutStatus']) == 'disputed') {
          status = 'disputed';
        } else {
          status = switch (stage) {
            'awaiting_payment' => 'unpaid',
            'payment_expired' => 'cancelled',
            'completed' => 'sold',
            _ => 'shipping',
          };
          if (stage == 'payment_expired') {
            note = 'Người thắng quá hạn thanh toán, giao dịch bị huỷ.';
          }
        }
      }

      out.add(
        SellerListing(
          id: id,
          title: _s(j['title']),
          cat: _s(j['category']),
          seller: shop,
          status: status,
          price: auction.isEmpty
              ? _i(j['startingPrice'])
              : _i(auction['currentPrice']),
          start: _i(j['startingPrice']),
          count: _i(auction['bidCount']),
          desc: _s(j['description']),
          cond: _s(j['condition'], 'Đã qua sử dụng'),
          durationHours: _i(j['durationHours']),
          endsAt: auction.isEmpty ? null : _dt(auction['endsAt']),
          auctionId: aid.isEmpty ? null : aid,
          note: note,
          requests: raw == 'needs_info' && reason.isNotEmpty ? [reason] : [],
          // BE chỉ cho sửa khi cần bổ sung; phiên đang chạy không sửa được.
          editable: raw == 'needs_info',
        ),
      );

      if (order != null && _s(order['paymentStatus']) == 'paid') {
        final oid = _s(order['id']);
        orderByListing[id] = oid;
        shipments.add(
          Shipment(
            id: id,
            title: _s(j['title']),
            cat: _s(j['category']),
            code: _s(_m(order['warehouse'])['orderCode'], 'Đơn #$oid'),
            seller: shop,
            buyer: 'Người mua',
            amount: _i(order['finalPrice']),
            at: shipmentStep(stage),
          ),
        );
      }
    }
    return SellerData(shop, out, shipments, orderByListing);
  }
}
