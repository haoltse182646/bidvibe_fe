import '../../core/api_client.dart';
import '../profile/profile_repository.dart';

int _int(dynamic v) => v is num ? v.toInt() : 0;

class DisputeStep {
  final String note;
  final DateTime? at;
  const DisputeStep(this.note, this.at);
}

/// Ảnh bằng chứng của tranh chấp; [uploaderRole] là bidder | seller | warehouse.
class DisputePhoto {
  final String id, url, uploaderRole;
  final DateTime? createdAt;
  const DisputePhoto(this.id, this.url, this.uploaderRole, this.createdAt);
}

/// Tranh chấp trên đơn của tôi (`GET /api/disputes/mine`).
class UserDispute {
  final String id, orderId, itemTitle, title;
  final String source; // bidder | seller | warehouse
  final String status; // open | resolved
  final String resolution; // none | refund | keep
  final int escrowAmount;
  final DateTime? createdAt;
  final List<DisputeStep> timeline;
  final List<DisputePhoto> photos;

  const UserDispute({
    required this.id,
    required this.orderId,
    required this.itemTitle,
    required this.title,
    required this.source,
    required this.status,
    required this.resolution,
    required this.escrowAmount,
    required this.createdAt,
    required this.timeline,
    this.photos = const [],
  });

  factory UserDispute.fromJson(Map<String, dynamic> j) {
    final id = '${j['id']}';
    final orderId = '${j['orderId']}';
    if (!DisputeRepository.validId(id) || !DisputeRepository.validId(orderId)) {
      throw const ApiException('INVALID_RESPONSE', 'Tranh chấp không hợp lệ.');
    }
    final steps = j['timeline'];
    final timeline = steps is List
        ? steps
              .whereType<Map>()
              .map(
                (e) => DisputeStep(
                  '${e['note'] ?? ''}',
                  e['at'] is String
                      ? DateTime.tryParse(e['at'] as String)?.toLocal()
                      : null,
                ),
              )
              .toList()
        : <DisputeStep>[];
    final rawPhotos = j['photos'];
    final photos = <DisputePhoto>[
      if (rawPhotos is List)
        for (final e in rawPhotos.whereType<Map>())
          // Bỏ qua ảnh có URL lạ thay vì làm hỏng cả màn tranh chấp.
          if (e['url'] is String && ProfileRepository.validUrl(e['url'] as String))
            DisputePhoto(
              '${e['id']}',
              e['url'] as String,
              '${e['uploaderRole'] ?? ''}',
              e['createdAt'] is String
                  ? DateTime.tryParse(e['createdAt'] as String)?.toLocal()
                  : null,
            ),
    ];
    return UserDispute(
      id: id,
      orderId: orderId,
      itemTitle: '${j['itemTitle'] ?? 'Đơn #$orderId'}',
      title: '${j['title'] ?? ''}',
      source: '${j['source'] ?? ''}',
      status: '${j['status'] ?? ''}',
      resolution: '${j['resolution'] ?? 'none'}',
      escrowAmount: _int(j['escrowAmount']),
      createdAt: timeline.isEmpty ? null : timeline.first.at,
      timeline: timeline,
      photos: photos,
    );
  }

  bool get open => status == 'open';
}

class DisputeRepository {
  final ApiClient api;
  const DisputeRepository(this.api);

  static bool validId(String id) => RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(id);

  Future<List<UserDispute>> mine() async {
    final rows = (await api.request('/api/disputes/mine'))['disputes'];
    if (rows is! List || rows.any((r) => r is! Map)) {
      throw const ApiException(
        'INVALID_RESPONSE',
        'Không đọc được danh sách tranh chấp.',
      );
    }
    return rows
        .map((r) => UserDispute.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }
}
