import '../../core/api_client.dart';
import '../addresses/address_repository.dart';

int _int(dynamic value) => value is num ? value.toInt() : 0;

DateTime? _time(dynamic value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

/// Chỉ nhận chuỗi; kiểu khác (backend đổi / lỗi) thành null thay vì ném TypeError.
String? _str(dynamic value) => value is String ? value : null;

class OrderEvent {
  final String step;
  final String? note;
  final DateTime? at;
  const OrderEvent(this.step, this.note, this.at);
}

/// Đơn thắng của người mua. Gộp hai dạng phản hồi của BE: chi tiết đơn
/// (`/orders/mine`, `/orders/:id`) và đơn sau bán (`/tracking`, `/confirm-delivery`).
class Order {
  final String id, auctionId, title;
  final String paymentStatus, payoutStatus;
  final int finalPrice, fee, shippingFee, totalDue, depositApplied, amountToPay;
  final DateTime? paymentDeadline, payoutDeadline, createdAt;
  final String? coverUrl, sellerName, stage;
  final ShippingAddress? shippingAddress;
  final String? warehouseCode, inspectionResult, shipmentStatus, trackingCode;
  final List<OrderEvent> events;

  const Order({
    required this.id,
    required this.auctionId,
    required this.title,
    required this.paymentStatus,
    required this.payoutStatus,
    required this.finalPrice,
    required this.fee,
    required this.shippingFee,
    required this.totalDue,
    required this.depositApplied,
    required this.amountToPay,
    this.paymentDeadline,
    this.payoutDeadline,
    this.createdAt,
    this.coverUrl,
    this.sellerName,
    this.stage,
    this.shippingAddress,
    this.warehouseCode,
    this.inspectionResult,
    this.shipmentStatus,
    this.trackingCode,
    this.events = const [],
  });

  factory Order.fromJson(Map<String, dynamic> data) {
    final id = '${data['id']}';
    if (!OrderRepository.validId(id) || data['title'] is! String) {
      throw const ApiException('INVALID_RESPONSE', 'Đơn hàng không hợp lệ.');
    }
    final seller = data['seller'];
    final address = data['shippingAddress'];
    final warehouse = data['warehouse'];
    final shipment = data['shipment'];
    final events = data['events'];
    final finalPrice = _int(data['finalPrice']);
    final deposit = _int(data['depositApplied']);
    final total = _int(data['totalDue']);
    return Order(
      id: id,
      auctionId: '${data['auctionId'] ?? ''}',
      title: data['title'] as String,
      paymentStatus: '${data['paymentStatus'] ?? ''}',
      payoutStatus: '${data['payoutStatus'] ?? ''}',
      finalPrice: finalPrice,
      fee: _int(data['fee']),
      shippingFee: _int(data['shippingFee']),
      totalDue: total,
      depositApplied: deposit,
      amountToPay: data['amountToPay'] is num
          ? _int(data['amountToPay'])
          : total - deposit,
      paymentDeadline: _time(data['paymentDeadline']),
      payoutDeadline: _time(data['payoutDeadline']),
      createdAt: _time(data['createdAt']),
      coverUrl: _str(data['coverUrl']),
      sellerName: seller is Map
          ? _str(seller['storeName']) ?? _str(seller['name'])
          : null,
      stage: _str(data['stage']),
      shippingAddress: address is Map
          ? ShippingAddress.fromJson({
              // Địa chỉ nhúng trong đơn không có cờ mặc định.
              'isDefault': false,
              ...Map<String, dynamic>.from(address),
            })
          : null,
      warehouseCode: warehouse is Map ? _str(warehouse['orderCode']) : null,
      inspectionResult: warehouse is Map
          ? _str(warehouse['inspectionResult'])
          : null,
      shipmentStatus: shipment is Map ? _str(shipment['status']) : null,
      trackingCode: shipment is Map ? _str(shipment['trackingCode']) : null,
      events: events is List
          ? events
                .whereType<Map>()
                .map(
                  (e) => OrderEvent(
                    '${e['step']}',
                    _str(e['note']),
                    _time(e['at']),
                  ),
                )
                .toList()
          : const [],
    );
  }

  bool get awaitingPayment => paymentStatus == 'awaiting_payment';
  bool get paid => paymentStatus == 'paid';
  bool get expired => paymentStatus == 'expired' || paymentStatus == 'cancelled';
  bool get completed => stage == 'completed' || payoutStatus == 'released';

  bool get disputed => payoutStatus == 'disputed';

  /// Chỉ xác nhận được khi hàng đã giao, chưa giải ngân và không có tranh chấp
  /// (BE trả DISPUTE_OPEN nếu đang tranh chấp).
  bool get canConfirmDelivery =>
      paid && !completed && !disputed && shipmentStatus == 'delivered';

  /// Mở tranh chấp được khi đã trả tiền, chưa giải ngân và chưa có tranh chấp.
  bool get canDispute => paid && !completed && payoutStatus == 'pending';

  /// BE cho đổi địa chỉ đến khi kho gửi đi.
  bool get canChangeAddress =>
      !expired &&
      !completed &&
      !const {'shipped', 'delivered'}.contains(shipmentStatus);
}

class OrderRepository {
  final ApiClient api;
  const OrderRepository(this.api);

  static bool validId(String id) => RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(id);
  static void checkId(String id) {
    if (!validId(id)) {
      throw const ApiException('VALIDATION_ERROR', 'Mã đơn không hợp lệ.');
    }
  }

  List<Order> _list(Map<String, dynamic> data) {
    final rows = data['orders'];
    if (rows is! List || rows.any((row) => row is! Map)) {
      throw const ApiException(
        'INVALID_RESPONSE',
        'Không đọc được danh sách đơn.',
      );
    }
    return rows
        .map((r) => Order.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<List<Order>> mine() async => _list(await api.request('/api/orders/mine'));

  /// Chi tiết tiền / hạn thanh toán / địa chỉ (không có tiến trình kho).
  Future<Order> detail(String id) async {
    checkId(id);
    return Order.fromJson(await api.request('/api/orders/$id'));
  }

  /// Tiến trình kho và giao hàng, kèm địa chỉ của người mua.
  Future<Order> tracking(String id) async {
    checkId(id);
    return Order.fromJson(await api.request('/api/orders/$id/tracking'));
  }

  /// Gộp hai nguồn: số tiền từ `detail`, tiến trình từ `tracking`.
  Future<Order> load(String id) async {
    final results = await Future.wait([detail(id), tracking(id)]);
    final d = results[0], t = results[1];
    return Order(
      id: d.id,
      auctionId: d.auctionId,
      title: d.title,
      paymentStatus: d.paymentStatus,
      payoutStatus: t.payoutStatus.isEmpty ? d.payoutStatus : t.payoutStatus,
      finalPrice: d.finalPrice,
      fee: d.fee,
      shippingFee: d.shippingFee,
      totalDue: d.totalDue,
      depositApplied: d.depositApplied,
      amountToPay: d.amountToPay,
      paymentDeadline: d.paymentDeadline,
      payoutDeadline: t.payoutDeadline,
      createdAt: d.createdAt,
      coverUrl: d.coverUrl,
      sellerName: d.sellerName ?? t.sellerName,
      stage: t.stage,
      shippingAddress: t.shippingAddress ?? d.shippingAddress,
      warehouseCode: t.warehouseCode,
      inspectionResult: t.inspectionResult,
      shipmentStatus: t.shipmentStatus,
      trackingCode: t.trackingCode,
      events: t.events,
    );
  }

  Future<void> setAddress(String orderId, String addressId) async {
    checkId(orderId);
    AddressRepository.checkId(addressId);
    await api.request(
      '/api/orders/$orderId/shipping-address',
      method: 'POST',
      body: {'addressId': addressId},
    );
  }

  /// method: wallet | qr | card. Không tự thử lại: lỗi mạng chưa rõ đã trừ tiền hay chưa.
  Future<void> pay(String orderId, String method) async {
    checkId(orderId);
    if (!const {'wallet', 'qr', 'card'}.contains(method)) {
      throw const ApiException('VALIDATION_ERROR', 'Phương thức không hợp lệ.');
    }
    await api.request(
      '/api/orders/$orderId/pay',
      method: 'POST',
      body: {'method': method},
    );
  }

  Future<void> confirmDelivery(String orderId) async {
    checkId(orderId);
    await api.request('/api/orders/$orderId/confirm-delivery', method: 'POST');
  }
}
