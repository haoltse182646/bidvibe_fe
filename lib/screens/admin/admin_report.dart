import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../store.dart';
import '../../theme.dart';

/// Báo cáo tài chính tuần (View Financial Reports + AI Executive Summary):
/// bản tóm tắt bằng ngôn ngữ tự nhiên do AI tổng hợp, cùng khối số liệu
/// tham chiếu bên dưới. Các con số đếm được (phiên, tranh chấp, ký quỹ,
/// hàng đợi) lấy trực tiếp từ store nên luôn khớp với các tab khác. Nút
/// "Tạo lại bản tóm tắt" mô phỏng trạng thái đang tải rồi hiện bản viết lại.
class AdminReportScreen extends StatefulWidget {
  const AdminReportScreen({super.key});

  @override
  State<AdminReportScreen> createState() => _AdminReportScreenState();
}

class _AdminReportScreenState extends State<AdminReportScreen> {
  bool loading = false;
  int version = 0;

  List<List<String>> _variants(AppStore s) => [
        [
          'Tuần này nền tảng ghi nhận doanh thu 142,3 triệu ₫, tăng 12,4% so với tuần trước. Mức tăng chủ yếu đến từ nhóm điện tử và đồ cổ, trong khi giày sneaker giữ nhịp ổn định. Ngày thứ Sáu là ngày có doanh thu cao nhất tuần, trùng với thời điểm các phiên đấu giá đồ cổ giá trị lớn kết thúc.',
          'Tỷ lệ tranh chấp giảm còn 1,8%, thấp hơn 0,8 điểm phần trăm so với tuần trước — cải thiện chủ yếu nhờ quy trình đối chiếu ảnh thẩm định tại khâu kho vận được siết chặt hơn. Hiện còn ${s.openDisputesCount} tranh chấp đang chờ xử lý, với ${s.money(s.escrowHeldTotal)} đang nằm trong ký quỹ.',
          'Hàng chờ thẩm định hiện có ${s.appraisalPendingCount} hồ sơ với thời gian chờ trung bình 31 giờ. Nếu xu hướng ký gửi tiếp tục tăng như hai tuần gần đây, đội thẩm định có thể cần thêm nhân sự hoặc điều chỉnh phân bổ để giữ thời gian chờ dưới 24 giờ.',
        ],
        [
          'Doanh thu 7 ngày gần nhất đạt 142,3 triệu ₫ (+12,4% so với kỳ trước). Hiện có ${s.liveAuctionsCount} phiên đang hoạt động, trong đó ${s.endingIn24hCount} phiên kết thúc trong 24 giờ tới, cần theo dõi để đảm bảo thanh toán và bàn giao đúng hạn.',
          'Chất lượng vận hành cải thiện rõ: tỷ lệ tranh chấp còn 1,8% (giảm 0,8 điểm). Các tranh chấp còn mở chủ yếu liên quan đến mô tả sản phẩm chưa khớp ảnh thẩm định — gợi ý nên bổ sung yêu cầu chụp cận cảnh khu vực dễ trầy xước ở bước thẩm định.',
          'Hàng đợi vận hành: ${s.appraisalPendingCount} chờ thẩm định, ${s.whWaitingCount} chờ nhập kho, ${s.whToDeliverCount} chờ giao cho người mua. Thời gian chờ thẩm định trung bình 31 giờ vẫn là điểm nghẽn lớn nhất trong chuỗi xử lý đơn hàng tuần này.',
        ],
      ];

  String _range() {
    final now = DateTime.now();
    String f(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    return '${f(now.subtract(const Duration(days: 6)))} – ${f(now)}/${now.year}';
  }

  void regenerate() {
    setState(() => loading = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        loading = false;
        version = (version + 1) % 2;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final paras = _variants(store)[version];
    final hot = store.flags.where((f) => f.status == 'open' && f.severity == 'high').toList()..sort((a, b) => b.confidence.compareTo(a.confidence));

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          const Text('QUẢN TRỊ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted, letterSpacing: 0.5)),
          const Text('Báo cáo tài chính tuần', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          const SizedBox(height: 4),
          Text('Bản tóm tắt bằng ngôn ngữ tự nhiên · ${_range()}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: loading ? null : regenerate,
              icon: loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome_outlined, size: 18),
              label: Text(loading ? 'Đang tạo lại…' : 'Tạo lại bản tóm tắt'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: loading
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(6, (i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            height: 14,
                            width: i.isEven ? double.infinity : 200,
                            decoration: BoxDecoration(color: const Color(0xFFEDEBE5), borderRadius: BorderRadius.circular(7)),
                          ),
                        )),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.progressBg, borderRadius: BorderRadius.circular(12)),
                          child: const Text('Tạo bởi AI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.progressFg)),
                        ),
                        const SizedBox(width: 8),
                        const Text('Cập nhật vừa xong', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                      ]),
                      const SizedBox(height: 16),
                      for (final p in paras) ...[
                        Text(p, style: const TextStyle(fontSize: 14, height: 1.6)),
                        const SizedBox(height: 14),
                      ],
                      const SizedBox(height: 4),
                      if (hot.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.priority_high_rounded, size: 18, color: AppColors.dangerFg),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Cần chú ý: phiên "${hot.first.title}" đang có mẫu đặt giá bất thường (${hot.first.reason.toLowerCase()}) với độ tin cậy ${hot.first.confidence}% — nên xem lại trước khi phiên kết thúc.',
                                  style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.dangerFg, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(12)),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.tips_and_updates_outlined, size: 18, color: AppColors.successFg),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Gợi ý cho tuần tới: bổ sung 1–2 thẩm định viên tạm thời để giảm thời gian chờ, và nhắc người bán chụp ảnh cận cảnh các vị trí dễ trầy xước.',
                                style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.successFg, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Báo cáo được tạo tự động từ dữ liệu nền tảng và có thể chứa sai sót. Vui lòng đối chiếu số liệu quan trọng trước khi sử dụng cho quyết định chính thức.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted, fontStyle: FontStyle.italic, height: 1.5),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Số liệu tham chiếu', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const _RefRow(label: 'Doanh thu tuần', value: '142,3 tr ₫'),
                const _RefRow(label: 'So với tuần trước', value: '+12,4%'),
                _RefRow(label: 'Phiên đang hoạt động', value: '${store.liveAuctionsCount}'),
                _RefRow(label: 'Kết thúc trong 24 giờ tới', value: '${store.endingIn24hCount}'),
                const _RefRow(label: 'Tỷ lệ tranh chấp', value: '1,8%'),
                _RefRow(label: 'Tranh chấp đang mở', value: '${store.openDisputesCount}'),
                _RefRow(label: 'Phiên đang bị gắn cờ', value: '${store.openFlagsCount}'),
                _RefRow(label: 'Đang giữ ký quỹ', value: store.money(store.escrowHeldTotal)),
                _RefRow(label: 'Chờ thẩm định', value: '${store.appraisalPendingCount} (TB 31 giờ)'),
                _RefRow(label: 'Chờ nhập kho', value: '${store.whWaitingCount}'),
                _RefRow(label: 'Chờ giao người mua', value: '${store.whToDeliverCount}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RefRow extends StatelessWidget {
  final String label;
  final String value;
  const _RefRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted))),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
