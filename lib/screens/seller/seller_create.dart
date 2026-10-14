import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class _AiSuggestion {
  final int price;
  final String range;
  final List<String> reasons;
  const _AiSuggestion({required this.price, required this.range, required this.reasons});
}

const Map<String, _AiSuggestion> _aiByCat = {
  'shoes': _AiSuggestion(
    price: 3600000,
    range: '3.200.000 – 4.100.000 ₫',
    reasons: [
      'Trung vị giá chốt của các phiên giày tương tự gần đây là khoảng 4,0 triệu ₫.',
      'Tình trạng "Như mới" thường được trả cao hơn mức trung bình của nhóm.',
      'Đặt thấp hơn trung vị khoảng 10% giúp thu hút nhiều lượt đặt giá hơn.',
    ],
  ),
  'elec': _AiSuggestion(
    price: 2400000,
    range: '2.000.000 – 2.900.000 ₫',
    reasons: [
      'Các thiết bị điện tử cùng đời có giá chốt tập trung quanh 2,6 triệu ₫.',
      'Hàng còn hoạt động tốt và đủ phụ kiện được trả cao hơn.',
      'Giá khởi điểm vừa phải giúp phiên có nhiều người tham gia từ đầu.',
    ],
  ),
  'antique': _AiSuggestion(
    price: 5200000,
    range: '4.400.000 – 6.300.000 ₫',
    reasons: [
      'Đồ cổ cùng loại thường chốt giá quanh 5,5 triệu ₫.',
      'Có chứng nhận hoặc nguồn gốc rõ ràng giúp giá chốt ổn định hơn.',
      'Đặt khởi điểm sát mức thấp của khoảng giá để tránh bỏ lỡ người mua.',
    ],
  ),
};

class SellerCreateScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SellerCreateScreen({super.key, required this.onDone});

  @override
  State<SellerCreateScreen> createState() => _SellerCreateScreenState();
}

enum _AiState { idle, loading, done }

class _SellerCreateScreenState extends State<SellerCreateScreen> {
  final titleCtrl = TextEditingController(text: 'Giày da thủ công, size 41');
  final descCtrl = TextEditingController(text: 'Da bò thật, đế khâu tay, đi được vài lần. Kèm hộp và túi vải.');
  final startCtrl = TextEditingController();
  String cat = 'shoes';
  String cond = 'Như mới';
  String dur = '24 giờ';
  int photoCount = 2;
  _AiState aiState = _AiState.idle;
  bool submitted = false;

  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    startCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final ai = _aiByCat[cat]!;
    final start = int.tryParse(startCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
    final canSubmit = titleCtrl.text.trim().isNotEmpty && start != null && start > 0;

    if (submitted) {
      return _DoneView(
        title: titleCtrl.text,
        startText: start != null ? store.money(start) : '',
        onViewListings: () {
          widget.onDone();
          setState(() {
            submitted = false;
            titleCtrl.text = '';
            descCtrl.text = '';
            startCtrl.text = '';
            aiState = _AiState.idle;
          });
        },
        onCreateAnother: () {
          setState(() {
            submitted = false;
            titleCtrl.text = '';
            descCtrl.text = '';
            startCtrl.text = '';
            aiState = _AiState.idle;
          });
        },
      );
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          const Text('KÝ GỬI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted, letterSpacing: 0.5)),
          const Text('Tạo phiên đấu giá', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          const SizedBox(height: 16),

          Text('Ảnh sản phẩm ($photoCount/4)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: List.generate(4, (i) {
              final filled = i < photoCount;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 3 ? 0 : 8),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Material(
                      color: filled ? categoryTileColor(cat) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => photoCount = filled ? photoCount - 1 : photoCount + 1),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: filled ? null : Border.all(color: const Color(0xFF9AA0A9), width: 1.5, style: BorderStyle.solid),
                          ),
                          child: Icon(filled ? Icons.image_outlined : Icons.add, color: filled ? AppColors.neutralFg : AppColors.muted),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          const Text('Chụp rõ mặt trước, mặt sau, chi tiết và các vết xước (nếu có).', style: TextStyle(fontSize: 12, color: AppColors.muted)),

          const SizedBox(height: 18),
          const Text('Tên sản phẩm', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(controller: titleCtrl, decoration: _dec('Ví dụ: Giày da thủ công, size 41'), onChanged: (_) => setState(() => aiState = _AiState.idle)),

          const SizedBox(height: 18),
          const Text('Danh mục', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _chip('Giày', 'shoes', cat, (v) => setState(() {
                    cat = v;
                    aiState = _AiState.idle;
                  })),
              _chip('Điện tử', 'elec', cat, (v) => setState(() {
                    cat = v;
                    aiState = _AiState.idle;
                  })),
              _chip('Đồ cổ', 'antique', cat, (v) => setState(() {
                    cat = v;
                    aiState = _AiState.idle;
                  })),
            ],
          ),

          const SizedBox(height: 18),
          const Text('Tình trạng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['Mới', 'Như mới', 'Đã qua sử dụng'].map((c) => _chip(c, c, cond, (v) => setState(() => cond = v))).toList(),
          ),

          const SizedBox(height: 18),
          const Text('Mô tả', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(controller: descCtrl, maxLines: 3, decoration: _dec(null)),

          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF7F9FD), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFC9D2E6))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(width: 24, height: 24, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.auto_awesome, size: 14, color: Colors.white)),
                  const SizedBox(width: 8),
                  const Text('Gợi ý giá khởi điểm từ AI', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ]),
                if (aiState == _AiState.idle) ...[
                  const SizedBox(height: 8),
                  const Text('Dựa trên các phiên tương tự đã kết thúc trên BidVibe. Bạn vẫn là người quyết định giá cuối cùng.', style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.mutedStrong)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: titleCtrl.text.trim().isEmpty
                          ? null
                          : () {
                              setState(() => aiState = _AiState.loading);
                              Future.delayed(const Duration(milliseconds: 1200), () {
                                if (mounted) setState(() => aiState = _AiState.done);
                              });
                            },
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.accent, side: const BorderSide(color: AppColors.accent, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Nhờ AI gợi ý giá', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ] else if (aiState == _AiState.loading) ...[
                  const SizedBox(height: 12),
                  const _ShimmerBlock(),
                  const SizedBox(height: 10),
                  const Text('Đang đối chiếu các phiên tương tự…', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                ] else ...[
                  const SizedBox(height: 10),
                  const Text('Giá khởi điểm đề xuất', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  Text(store.money(ai.price), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                  Text('Khoảng hợp lý: ${ai.range}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  const SizedBox(height: 12),
                  ...ai.reasons.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.check_circle, size: 16, color: AppColors.successStrong),
                          const SizedBox(width: 8),
                          Expanded(child: Text(r, style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.mutedStrong))),
                        ]),
                      )),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => setState(() => startCtrl.text = store.fmt(ai.price)),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('Dùng giá này', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => setState(() => aiState = _AiState.loading),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFC9D2E6)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('Tính lại'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 18),
          const Text('Giá khởi điểm (₫)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(controller: startCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: _dec('Nhập giá khởi điểm')),
          const SizedBox(height: 6),
          const Text('Bước giá tối thiểu của phiên: 50.000 ₫.', style: TextStyle(fontSize: 12, color: AppColors.muted)),

          const SizedBox(height: 18),
          const Text('Thời lượng phiên', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: ['24 giờ', '3 ngày', '7 ngày'].map((d) => _chip(d, d, dur, (v) => setState(() => dur = v))).toList()),

          const SizedBox(height: 18),
          const Text('Phiên chỉ được công khai sau khi chuyên gia thẩm định duyệt hồ sơ. Bạn chỉ gửi hàng đến kho sau khi có người thắng và thanh toán.', style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4)),
          const SizedBox(height: 12),
          BigActionButton(
            label: 'Gửi để thẩm định',
            onPressed: canSubmit
                ? () {
                    store.createListing(
                      title: titleCtrl.text.trim(),
                      cat: cat,
                      start: start,
                      desc: descCtrl.text.trim(),
                      cond: cond,
                      durationHours: dur == '7 ngày' ? 168 : (dur == '3 ngày' ? 72 : 24),
                      photos: photoCount,
                    );
                    setState(() => submitted = true);
                  }
                : null,
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String? hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCFCCC3))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCFCCC3))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
      );

  Widget _chip(String label, String value, String current, ValueChanged<String> onSelect) {
    final on = value == current;
    return OutlinedButton(
      onPressed: () => onSelect(value),
      style: OutlinedButton.styleFrom(
        backgroundColor: on ? AppColors.accent : Colors.white,
        foregroundColor: on ? Colors.white : AppColors.ink,
        side: BorderSide(color: on ? AppColors.accent : const Color(0xFFCFCCC3)),
        shape: const StadiumBorder(),
      ),
      child: Text(label),
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  const _ShimmerBlock();
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 28, width: 160, decoration: BoxDecoration(color: const Color(0xFFDDE3F0), borderRadius: BorderRadius.circular(8))),
        const SizedBox(height: 8),
        Container(height: 12, width: double.infinity, decoration: BoxDecoration(color: const Color(0xFFE6EAF3), borderRadius: BorderRadius.circular(6))),
        const SizedBox(height: 8),
        Container(height: 12, width: 220, decoration: BoxDecoration(color: const Color(0xFFE6EAF3), borderRadius: BorderRadius.circular(6))),
      ],
    );
  }
}

class _DoneView extends StatelessWidget {
  final String title;
  final String startText;
  final VoidCallback onViewListings;
  final VoidCallback onCreateAnother;
  const _DoneView({required this.title, required this.startText, required this.onViewListings, required this.onCreateAnother});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 44, 16, 16),
              children: [
                const CircleAvatar(radius: 32, backgroundColor: AppColors.successStrong, child: Icon(Icons.check, color: Colors.white, size: 32)),
                const SizedBox(height: 16),
                const Center(child: Text('Đã tạo phiếu ký gửi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3))),
                const SizedBox(height: 6),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text('$title sẽ được công khai sau khi thẩm định.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.45)),
                  ),
                ),
                const SizedBox(height: 26),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bước tiếp theo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      _step('1', 'Chuyên gia thẩm định xác thực hồ sơ, có thể yêu cầu bổ sung ảnh hoặc giấy tờ.'),
                      _step('2', 'Phiên đấu giá được công khai với giá khởi điểm $startText.'),
                      _step('3', 'Khi có người thắng và thanh toán, bạn gửi hàng đến kho BidVibe.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              children: [
                BigActionButton(label: 'Xem phiên của tôi', onPressed: onViewListings),
                const SizedBox(height: 8),
                TextButton(onPressed: onCreateAnother, child: const Text('Tạo phiên khác', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(String n, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 11, backgroundColor: const Color(0xFFF1F3F8), child: Text(n, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent))),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.45))),
        ]),
      );
}
