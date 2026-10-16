import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/remote_app_store.dart';
import '../../features/ops/ops_repository.dart';
import '../../store.dart';
import '../../theme.dart';

OpsRepository _ops(BuildContext context) =>
    OpsRepository(
      (context.read<AppStore>() as RemoteAppStore).api,
      onAuthError: (context.read<AppStore>() as RemoteAppStore).handleApiException,
    );

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

String _money(dynamic value) {
  final digits = (value is num ? value.toInt() : 0).toString();
  return '${digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')} đ';
}

String _time(dynamic value) {
  final date = value is String ? DateTime.tryParse(value)?.toLocal() : null;
  if (date == null) return '—';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class AppraiserOpsScreen extends StatefulWidget {
  const AppraiserOpsScreen({super.key});

  @override
  State<AppraiserOpsScreen> createState() => _AppraiserOpsScreenState();
}

class _AppraiserOpsScreenState extends State<AppraiserOpsScreen> {
  String status = 'pending_appraisal';
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _ops(context).appraisalQueue(status: status);
  }

  Future<void> _refresh() async {
    final next = _ops(context).appraisalQueue(status: status);
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {}
  }

  void _select(String value) {
    setState(() {
      status = value;
      _future = _ops(context).appraisalQueue(status: value);
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('THẨM ĐỊNH', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
          const Text('Hàng chờ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'pending_appraisal', label: Text('Chờ duyệt')),
              ButtonSegment(value: 'needs_info', label: Text('Chờ bổ sung')),
            ],
            selected: {status},
            onSelectionChanged: (value) => _select(value.first),
          ),
        ]),
      ),
      Expanded(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _AppraiserError(error: snapshot.error!, onRetry: _refresh);
            }
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final rows = snapshot.data!;
            if (rows.isEmpty) return const Center(child: Text('Không có hồ sơ trong hàng chờ này.'));
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 20),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = rows[index];
                  final seller = _map(item['seller']);
                  return Card(
                    child: ListTile(
                      onTap: () async {
                        await Navigator.of(context).push<void>(MaterialPageRoute(
                          builder: (_) => AppraiserOpsDetailScreen(listingId: '${item['listingId']}'),
                        ));
                        if (mounted) await _refresh();
                      },
                      leading: _ListingThumb(item['category']),
                      title: Text('${item['title'] ?? 'Tin đăng'}', maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('${seller['storeName'] ?? 'Người bán'} · ${item['photoCount'] ?? 0} ảnh · gửi ${_time(item['createdAt'])}', maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ]),
  );
}

class AppraiserOpsDetailScreen extends StatefulWidget {
  final String listingId;
  const AppraiserOpsDetailScreen({super.key, required this.listingId});

  @override
  State<AppraiserOpsDetailScreen> createState() => _AppraiserOpsDetailScreenState();
}

class _AppraiserOpsDetailScreenState extends State<AppraiserOpsDetailScreen> {
  Future<Map<String, dynamic>>? _future;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _ops(context).appraisalDetail(widget.listingId);
  }

  Future<void> _decide(String decision) async {
    String? reason;
    if (decision != 'approve') {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(decision == 'reject' ? 'Từ chối tin đăng' : 'Yêu cầu bổ sung'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 1000,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Lý do bắt buộc'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Huỷ')),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) Navigator.pop(dialogContext, value);
              },
              child: const Text('Tiếp tục'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (reason == null || !mounted) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Duyệt tin đăng?'),
          content: const Text('Tin sẽ chuyển sang live và phiên đấu giá được mở ngay.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Duyệt')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _saving = true);
    try {
      final result = await _ops(context).decideAppraisal(
        widget.listingId,
        decision: decision,
        reason: reason,
      );
      if (mounted) {
        final message = decision == 'approve'
            ? 'Đã duyệt. Mã phiên: ${result['auctionId'] ?? '—'}'
            : decision == 'reject'
            ? 'Đã từ chối tin đăng.'
            : 'Đã gửi yêu cầu bổ sung.';
        Navigator.of(context).pop(message);
      }
    } on ApiException catch (error) {
      if (mounted && !const {'UNAUTHORIZED', 'ACCOUNT_SUSPENDED'}.contains(error.code)) {
        _showError(context, error.message);
      }
    } catch (_) {
      if (mounted) _showError(context, 'Không gửi được quyết định.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _retryDetail() async {
    final next = _ops(context).appraisalDetail(widget.listingId);
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết thẩm định')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _AppraiserError(error: snapshot.error!, onRetry: _retryDetail);
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final listing = snapshot.data!;
        final seller = _map(listing['seller']);
        final photos = listing['photos'] is List ? (listing['photos'] as List).whereType<Map>().toList() : const <Map>[];
        final history = listing['history'] is List ? (listing['history'] as List).whereType<Map>().toList() : const <Map>[];
        final canDecide = listing['status'] == 'pending_appraisal';
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text('${listing['category'] ?? 'Tin đăng'} · ${listing['status'] ?? '—'}', style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 4),
            Text('${listing['title'] ?? 'Tin đăng'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (photos.isEmpty)
              const _Panel(child: Text('Tin đăng chưa có ảnh.'))
            else
              SizedBox(
                height: 190,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final url = photos[index]['url'];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 190,
                        child: url is String
                            ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const _PhotoFallback())
                            : const _PhotoFallback(),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${listing['description'] ?? 'Không có mô tả.'}'),
              const Divider(height: 20),
              _ValueRow(label: 'Tình trạng', value: '${listing['condition'] ?? '—'}'),
              _ValueRow(label: 'Giá khởi điểm', value: _money(listing['startingPrice'])),
              _ValueRow(label: 'Gợi ý giá', value: listing['aiSuggestedPrice'] == null ? '—' : _money(listing['aiSuggestedPrice'])),
              _ValueRow(label: 'Thời lượng', value: '${listing['durationHours'] ?? '—'} giờ'),
              _ValueRow(label: 'Người bán', value: '${seller['storeName'] ?? '—'}'),
              _ValueRow(label: 'Đánh giá', value: '${seller['rating'] ?? 'Chưa có'}'),
              if (listing['status'] == 'needs_info') ...[
                const SizedBox(height: 8),
                Text('Đang chờ người bán bổ sung. Tin chỉ trở lại hàng chờ sau khi được nộp lại.', style: TextStyle(color: AppColors.progressFg)),
              ],
            ])),
            const SizedBox(height: 12),
            _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Lịch sử thẩm định', style: TextStyle(fontWeight: FontWeight.w700)),
              const Divider(height: 18),
              if (history.isEmpty) const Text('Chưa có quyết định trước đó.', style: TextStyle(color: AppColors.muted)),
              for (final entry in history)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text('${entry['decision'] ?? '—'} · ${_time(entry['decidedAt'])}${entry['reason'] is String ? '\n${entry['reason']}' : ''}'),
                ),
            ])),
            if (canDecide) ...[
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: _saving ? null : () => _decide('approve'), icon: const Icon(Icons.check), label: const Text('Duyệt và mở phiên')),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: _saving ? null : () => _decide('more_info'), icon: const Icon(Icons.assignment_late_outlined), label: const Text('Yêu cầu bổ sung')),
              OutlinedButton.icon(onPressed: _saving ? null : () => _decide('reject'), icon: const Icon(Icons.close), label: const Text('Từ chối')),
              if (_saving) const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
            ],
          ],
        );
      },
    ),
  );
}

class _ListingThumb extends StatelessWidget {
  final dynamic category;
  const _ListingThumb(this.category);
  @override
  Widget build(BuildContext context) => Container(
    width: 46,
    height: 46,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: AppColors.neutralBg, borderRadius: BorderRadius.circular(8)),
    child: Icon(switch (category) {
      'shoes' => Icons.directions_run,
      'elec' => Icons.devices_other,
      'antique' => Icons.history_edu,
      _ => Icons.inventory_2_outlined,
    }, color: AppColors.neutralFg),
  );
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
    child: child,
  );
}

class _ValueRow extends StatelessWidget {
  final String label;
  final String value;
  const _ValueRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      SizedBox(width: 135, child: Text(label, style: const TextStyle(color: AppColors.muted))),
      Expanded(child: Text(value, textAlign: TextAlign.end)),
    ]),
  );
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();
  @override
  Widget build(BuildContext context) => Container(color: AppColors.neutralBg, alignment: Alignment.center, child: const Icon(Icons.broken_image_outlined, size: 36));
}

class _AppraiserError extends StatelessWidget {
  final Object error;
  final Future<void> Function() onRetry;
  const _AppraiserError({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    final message = error is ApiException ? (error as ApiException).message : 'Không tải được dữ liệu.';
    return Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Thử lại')),
      ]),
    ));
  }
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}