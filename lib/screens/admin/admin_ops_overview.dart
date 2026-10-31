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
  final amount = value is num ? value.toInt() : 0;
  final digits = amount.toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '$grouped đ';
}

String _date(dynamic value) {
  final date = value is String ? DateTime.tryParse(value)?.toLocal() : null;
  if (date == null) return '—';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class AdminOpsDashboardScreen extends StatefulWidget {
  const AdminOpsDashboardScreen({super.key});

  @override
  State<AdminOpsDashboardScreen> createState() => _AdminOpsDashboardScreenState();
}

class _AdminOpsDashboardScreenState extends State<AdminOpsDashboardScreen> {
  Future<Map<String, dynamic>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _ops(context).dashboard();
  }

  Future<void> _refresh() async {
    final next = _ops(context).dashboard();
    setState(() {
      _future = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _OpsError(error: snapshot.error!, onRetry: _refresh);
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final data = snapshot.data!;
      final auctions = _map(data['auctions']);
      final appraisal = _map(data['appraisal']);
      final orders = _map(data['orders']);
      final flags = _map(data['flags']);
      final disputes = _map(data['disputes']);
      final users = _map(data['users']);
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            const _Eyebrow('QUẢN TRỊ'),
            const _Title('Tổng quan vận hành'),
            const SizedBox(height: 4),
            const Text('Số liệu hiện tại từ máy chủ.', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 14),
            _MetricGrid(items: [
              ('Phiên đang chạy', auctions['live'], Icons.gavel_outlined),
              ('Kết thúc trong 24 giờ', auctions['endingIn24h'], Icons.timer_outlined),
              ('Cờ đang mở', flags['open'], Icons.flag_outlined),
              ('Tranh chấp đang mở', disputes['open'], Icons.report_outlined),
              ('Chờ thẩm định', appraisal['pending'], Icons.fact_check_outlined),
              ('Cần bổ sung', appraisal['needsInfo'], Icons.assignment_late_outlined),
            ]),
            const SizedBox(height: 18),
            _DataSection(title: 'Đơn hàng', values: {
              'Chờ thanh toán': orders['awaitingPayment'],
              'Chờ người bán gửi kho': orders['awaitingSellerShipment'],
              'Đang chuyển về kho': orders['inTransitToWarehouse'],
              'Kho đang kiểm định': orders['inspecting'],
              'Đang giao người mua': orders['outbound'],
              'Đã giao, chờ xác nhận': orders['deliveredAwaitingConfirm'],
            }),
            const SizedBox(height: 12),
            _DataSection(title: 'Tài khoản và ký quỹ', values: {
              'Người mua': users['bidders'],
              'Người bán': users['sellers'],
              'Tài khoản vận hành': users['ops'],
              'Tài khoản bị khoá': users['suspended'],
              'Cờ đang tạm dừng': flags['paused'],
              'Tiền ký quỹ đang giữ': _money(data['escrowHeld']),
            }),
          ],
        ),
      );
    },
  );
}

class AdminOpsReportScreen extends StatefulWidget {
  const AdminOpsReportScreen({super.key});

  @override
  State<AdminOpsReportScreen> createState() => _AdminOpsReportScreenState();
}

class _AdminOpsReportScreenState extends State<AdminOpsReportScreen> {
  Future<Map<String, dynamic>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _ops(context).weeklyReport();
  }

  Future<void> _refresh() async {
    final next = _ops(context).weeklyReport();
    setState(() {
      _future = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _OpsError(error: snapshot.error!, onRetry: _refresh);
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final report = snapshot.data!;
      final period = _map(report['period']);
      final auctions = _map(report['auctions']);
      final sales = _map(report['sales']);
      final payments = _map(report['payments']);
      final accounts = _map(report['newAccounts']);
      final appraisals = _map(report['appraisals']);
      final disputes = _map(report['disputes']);
      final topups = _map(report['walletTopups']);
      final categories = report['topCategories'] is List
          ? (report['topCategories'] as List).whereType<Map>().toList()
          : const <Map>[];
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            const _Eyebrow('QUẢN TRỊ'),
            const _Title('Báo cáo tuần'),
            Text('${_date(period['from'])} – ${_date(period['to'])}', style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 14),
            _DataSection(title: 'Đấu giá và doanh số', values: {
              'Phiên kết thúc': auctions['ended'],
              'Phiên bán thành công': auctions['sold'],
              'Phiên bị huỷ': auctions['cancelled'],
              'Đơn hàng': sales['orders'],
              'Tổng giá trị giao dịch': _money(sales['gmv']),
              'Phí ước tính': _money(sales['estimatedFees']),
            }),
            const SizedBox(height: 12),
            _DataSection(title: 'Thanh toán và tài khoản mới', values: {
              'Đã thanh toán': payments['paid'],
              'Quá hạn': payments['expired'],
              'Người mua mới': accounts['bidder'],
              'Người bán mới': accounts['seller'],
              'Lượt nạp ví': topups['count'],
              'Tổng nạp ví': _money(topups['total']),
            }),
            const SizedBox(height: 12),
            _DataSection(title: 'Thẩm định và tranh chấp', values: {
              'Đã duyệt': appraisals['approve'],
              'Từ chối': appraisals['reject'],
              'Yêu cầu bổ sung': appraisals['more_info'],
              'Tranh chấp mở mới': disputes['opened'],
              'Tranh chấp đã xử lý': disputes['resolved'],
            }),
            if (categories.isNotEmpty) ...[
              const SizedBox(height: 12),
              _DataSection(
                title: 'Danh mục nổi bật',
                values: {
                  for (final row in categories)
                    '${row['code'] ?? '—'} · ${row['orders'] ?? 0} đơn': _money(row['gmv']),
                },
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _OpsError extends StatelessWidget {
  final Object error;
  final Future<void> Function() onRetry;
  const _OpsError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error as ApiException).message
        : 'Không tải được dữ liệu.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  final String text;
  const _Eyebrow(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
  );
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Text(text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
  );
}

class _MetricGrid extends StatelessWidget {
  final List<(String, dynamic, IconData)> items;
  const _MetricGrid({required this.items});

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 8,
    crossAxisSpacing: 8,
    childAspectRatio: 1.65,
    children: [
      for (final item in items)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(item.$3, color: AppColors.accent, size: 20),
              Text('${item.$2 ?? 0}', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
              Text(item.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.mutedStrong)),
            ],
          ),
        ),
    ],
  );
}

class _DataSection extends StatelessWidget {
  final String title;
  final Map<String, dynamic> values;
  const _DataSection({required this.title, required this.values});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const Divider(height: 18),
        for (final entry in values.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 13, color: AppColors.mutedStrong))),
                const SizedBox(width: 12),
                Flexible(child: Text('${entry.value ?? 0}', textAlign: TextAlign.end, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
      ],
    ),
  );
}