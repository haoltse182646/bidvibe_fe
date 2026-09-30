import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class AppraiserDetailScreen extends StatefulWidget {
  final String itemId;
  const AppraiserDetailScreen({super.key, required this.itemId});

  @override
  State<AppraiserDetailScreen> createState() => _AppraiserDetailScreenState();
}

class _AppraiserDetailScreenState extends State<AppraiserDetailScreen> {
  int? zoomIdx;
  bool rejectOpen = false;
  bool moreInfoOpen = false;
  final reasonCtrl = TextEditingController();
  final Map<String, bool> moreSel = {'photos': false, 'receipt': false, 'serial': false};

  @override
  void dispose() {
    reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final it = store.appraisalQueue.where((x) => x.id == widget.itemId).toList();
    if (it.isEmpty) {
      // Đã được duyệt/từ chối từ chính màn này — quay lại hàng chờ.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }
    final d = it.first;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Hồ sơ thẩm định', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: d.photos,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => setState(() => zoomIdx = i),
                child: Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(color: categoryTileColor(d.cat), borderRadius: BorderRadius.circular(12), border: Border.all(color: zoomIdx == i ? AppColors.accent : Colors.transparent, width: 2)),
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_outlined, size: 30, color: AppColors.neutralFg),
                ),
              ),
            ),
          ),
          if (zoomIdx != null) ...[
            const SizedBox(height: 10),
            Stack(
              children: [
                Container(
                  height: 260,
                  decoration: BoxDecoration(color: categoryTileColor(d.cat), borderRadius: BorderRadius.circular(16)),
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_outlined, size: 88, color: AppColors.neutralFg),
                ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(12)),
                    child: Text('Ảnh ${zoomIdx! + 1}/${d.photos} · phóng to (minh hoạ)', style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: IconButton(
                    style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: 0.65)),
                    onPressed: () => setState(() => zoomIdx = null),
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Text(labelForCategory(d.cat), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted, letterSpacing: 0.5)),
          Text(d.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: -0.2)),
          const SizedBox(height: 8),
          if (d.status == 'needinfo')
            const StatusPill(label: 'Chờ người bán bổ sung', tone: StatusTone.progress)
          else
            const StatusPill(label: 'Chờ thẩm định', tone: StatusTone.pending),
          if (d.status == 'needinfo') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.progressBg, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Đã yêu cầu người bán bổ sung', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.progressFg)),
                  const SizedBox(height: 6),
                  ...d.requests.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.chevron_right, size: 16, color: AppColors.progressFg),
                          Expanded(child: Text(r, style: const TextStyle(fontSize: 13, color: AppColors.progressFg))),
                        ]),
                      )),
                  const SizedBox(height: 4),
                  const Text('Hồ sơ sẽ tự quay lại hàng chờ khi người bán gửi bổ sung.', style: TextStyle(fontSize: 12, color: AppColors.progressFg)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.desc, style: const TextStyle(fontSize: 14, height: 1.5)),
                const Divider(height: 24),
                _kv('Tình trạng khai báo', d.cond),
                _kv('Giá khởi điểm đề xuất', store.money(d.start)),
                _kv('Số ảnh đính kèm', '${d.photos} ảnh'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Lịch sử người bán', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Row(
              children: [
                CircleAvatar(radius: 20, backgroundColor: AppColors.neutralBg, child: Text(d.seller.isNotEmpty ? d.seller[0] : '?', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.neutralFg))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.seller, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      Text('${d.sellerRating}/5 · ${d.sellerStats}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (moreInfoOpen) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Yêu cầu bổ sung', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  _moreOpt('photos', 'Chụp thêm ảnh chi tiết/vết hư hỏng'),
                  _moreOpt('receipt', 'Cung cấp hoá đơn hoặc giấy tờ mua'),
                  _moreOpt('serial', 'Ảnh cận số seri / mã sản phẩm'),
                  const SizedBox(height: 12),
                  BigActionButton(
                    label: 'Gửi yêu cầu cho người bán',
                    onPressed: moreSel.values.any((v) => v)
                        ? () {
                            store.requestMoreInfo(d.id, moreSel.entries.where((e) => e.value).map((e) => e.key).toList());
                            Navigator.of(context).pop();
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ],

          if (rejectOpen) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Lý do từ chối', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Ví dụ: ảnh không rõ số seri, tình trạng không khớp mô tả…',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCFCCC3))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  BigActionButton(
                    label: 'Xác nhận từ chối',
                    background: AppColors.dangerStrong,
                    onPressed: reasonCtrl.text.trim().isEmpty
                        ? null
                        : () => store.rejectAppraisal(d.id, reasonCtrl.text.trim()),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: (rejectOpen || moreInfoOpen)
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => rejectOpen = true),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.dangerStrong, side: const BorderSide(color: AppColors.dangerStrong, width: 1.5), minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        child: const Text('Từ chối', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: d.status == 'needinfo' ? null : () => setState(() => moreInfoOpen = true),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.ink, side: const BorderSide(color: Color(0xFFCFCCC3), width: 1.5), minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        child: const Text('Bổ sung', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: d.status == 'needinfo' ? null : () => store.approveAppraisal(d.id),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.successStrong, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        child: const Text('Duyệt', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ]),
      );

  Widget _moreOpt(String key, String label) {
    final on = moreSel[key] ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: on ? const Color(0xFFF1F3F8) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => moreSel[key] = !on),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFCFCCC3))),
            child: Row(
              children: [
                Icon(on ? Icons.check_box : Icons.check_box_outline_blank, size: 20, color: on ? AppColors.accent : const Color(0xFF9AA0A9)),
                const SizedBox(width: 10),
                Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
