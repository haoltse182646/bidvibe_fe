import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class WarehouseDetailScreen extends StatelessWidget {
  final String id;
  const WarehouseDetailScreen({super.key, required this.id});

  static const checkLabels = {
    'desc': 'Đúng mô tả và tình trạng đã khai báo',
    'accessories': 'Đủ phụ kiện đi kèm (hộp, dây, giấy tờ)',
    'damage': 'Không có hư hỏng phát sinh khi vận chuyển',
  };

  (String, StatusTone) _pill(String status) => switch (status) {
        'waiting' => ('Chờ nhận', StatusTone.pending),
        'inspecting' => ('Đang kiểm hàng', StatusTone.progress),
        'inspecting_done' => ('Chờ đóng gói', StatusTone.progress),
        'packed' => ('Sẵn sàng gửi', StatusTone.progress),
        'shipped' => ('Đang vận chuyển', StatusTone.progress),
        'delivered' => ('Đã giao thành công', StatusTone.success),
        _ => ('Đã báo cáo Admin', StatusTone.danger),
      };

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final w = store.warehouseShipments.firstWhere((x) => x.id == id);
    final (label, tone) = _pill(w.status);
    final vals = w.checks.values.toList();
    final anyMismatch = vals.any((v) => v == WarehouseCheck.mismatch);
    final allMatch = vals.every((v) => v == WarehouseCheck.match);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(w.code, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CategoryThumb(cat: w.cat, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.35)),
                    Text('Người bán: ${w.seller}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StatusPill(label: label, tone: tone),

          if (w.status == 'waiting') _ReceiveStep(w: w, store: store),
          if (w.status == 'inspecting') _InspectStep(w: w, store: store, anyMismatch: anyMismatch, allMatch: allMatch),
          if (w.status == 'escalated') _EscalatedCard(note: w.note),
          if (w.status == 'inspecting_done') _PackStep(w: w, store: store),
          if (w.status == 'packed')
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: BigActionButton(label: 'Đã gửi cho đơn vị vận chuyển', onPressed: () => store.whMarkShipped(w.id)),
            ),
          if (w.status == 'shipped')
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: BigActionButton(label: 'Đã giao thành công', background: AppColors.successStrong, onPressed: () => store.whMarkDelivered(w.id)),
            ),
          if (w.status == 'delivered')
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFB9DCCA))),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Đã giao thành công', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.successFg)),
                  SizedBox(height: 4),
                  Text('Đơn hoàn tất, không cần thao tác thêm.', style: TextStyle(fontSize: 13, color: AppColors.successFg)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ReceiveStep extends StatelessWidget {
  final WarehouseShipment w;
  final AppStore store;
  const _ReceiveStep({required this.w, required this.store});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Xác nhận nhận hàng', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const Text('Quét mã hoặc kiểm tra mã phiếu trên kiện hàng.', style: TextStyle(fontSize: 13, color: AppColors.muted)),
              const SizedBox(height: 12),
              Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFCFCCC3), style: BorderStyle.solid)),
                child: Text(w.code, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFCFCCC3)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: const Text('Quét mã (minh hoạ)', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Ảnh khi mở kiện (${w.recvPhotos})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => store.whAddPhoto(w.id),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF9AA0A9), width: 1.5)),
                      child: const Icon(Icons.add, color: AppColors.muted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ...List.generate(w.recvPhotos.clamp(0, 4), (i) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(color: categoryTileColor(w.cat), borderRadius: BorderRadius.circular(12)),
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_outlined, color: AppColors.neutralFg),
                        ),
                      )),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: BigActionButton(
            label: 'Xác nhận đã nhận hàng',
            icon: Icons.check,
            background: AppColors.successStrong,
            onPressed: w.recvPhotos == 0 ? null : () => store.whConfirmReceive(w.id),
          ),
        ),
      ],
    );
  }
}

class _InspectStep extends StatefulWidget {
  final WarehouseShipment w;
  final AppStore store;
  final bool anyMismatch;
  final bool allMatch;
  const _InspectStep({required this.w, required this.store, required this.anyMismatch, required this.allMatch});

  @override
  State<_InspectStep> createState() => _InspectStepState();
}

class _InspectStepState extends State<_InspectStep> {
  final noteCtrl = TextEditingController();
  final shelfCtrl = TextEditingController();

  /// Tình trạng ghi nhận khi nhập kho (Update Inventory & Condition).
  static const grades = ['Như mới', 'Tốt', 'Khá'];
  String grade = 'Tốt';

  @override
  void initState() {
    super.initState();
    noteCtrl.text = widget.w.note;
    shelfCtrl.text = widget.w.shelf;
    if (widget.w.grade != null && grades.contains(widget.w.grade)) grade = widget.w.grade!;
  }

  @override
  void dispose() {
    noteCtrl.dispose();
    shelfCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.w;
    final store = widget.store;
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Đối chiếu với hồ sơ thẩm định', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const Text('So sánh thực tế với ảnh và mô tả đã được duyệt.', style: TextStyle(fontSize: 13, color: AppColors.muted)),
              const SizedBox(height: 14),
              ...WarehouseDetailScreen.checkLabels.entries.map((e) {
                final v = w.checks[e.key] ?? WarehouseCheck.unknown;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _checkBtn(
                              label: 'Khớp',
                              icon: Icons.check,
                              on: v == WarehouseCheck.match,
                              color: AppColors.successStrong,
                              onTap: () => store.whSetCheck(w.id, e.key, WarehouseCheck.match),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _checkBtn(
                              label: 'Sai lệch',
                              icon: Icons.warning_amber_rounded,
                              on: v == WarehouseCheck.mismatch,
                              color: AppColors.dangerStrong,
                              onTap: () => store.whSetCheck(w.id, e.key, WarehouseCheck.mismatch),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              if (widget.anyMismatch) ...[
                const SizedBox(height: 4),
                const Text('Ghi chú sai lệch (bắt buộc)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  onChanged: (v) {
                    store.whSetNote(w.id, v);
                  },
                  decoration: InputDecoration(
                    hintText: 'Mô tả cụ thể sai lệch để báo cáo lên Admin…',
                    filled: true,
                    fillColor: AppColors.bg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCFCCC3))),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (widget.anyMismatch)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: BigActionButton(
              label: 'Báo cáo lên Admin',
              icon: Icons.flag_outlined,
              background: AppColors.dangerStrong,
              onPressed: w.note.trim().isEmpty ? null : () => store.whEscalate(w.id),
            ),
          ),
        if (widget.allMatch) ...[
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tình trạng ghi nhận', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: grades
                        .map((g) => FilterChipButton(label: g, selected: grade == g, onTap: () => setState(() => grade = g)))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text('Vị trí kệ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: shelfCtrl,
                    decoration: InputDecoration(
                      hintText: 'VD: Kệ A1-02 — để trống sẽ xếp vào “Kệ chờ gửi”',
                      filled: true,
                      fillColor: AppColors.bg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCFCCC3))),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: BigActionButton(
              label: 'Xác nhận kiểm hàng xong',
              icon: Icons.check,
              background: AppColors.successStrong,
              onPressed: () => store.whConfirmInspect(w.id, grade: grade, shelf: shelfCtrl.text),
            ),
          ),
        ],
      ],
    );
  }

  Widget _checkBtn({required String label, required IconData icon, required bool on, required Color color, required VoidCallback onTap}) {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: on ? color : Colors.white,
          foregroundColor: on ? Colors.white : AppColors.ink,
          side: BorderSide(color: on ? color : const Color(0xFFCFCCC3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _EscalatedCard extends StatelessWidget {
  final String note;
  const _EscalatedCard({required this.note});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.dangerStrong)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Đã báo cáo lên Admin', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.dangerFg)),
          const SizedBox(height: 6),
          Text(note, style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.dangerFg)),
          const SizedBox(height: 10),
          const Text('Admin sẽ xem báo cáo trong mục Tranh chấp và liên hệ nếu cần thêm thông tin.', style: TextStyle(fontSize: 12, color: AppColors.dangerFg)),
        ],
      ),
    );
  }
}

class _PackStep extends StatelessWidget {
  final WarehouseShipment w;
  final AppStore store;
  const _PackStep({required this.w, required this.store});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kiểm hàng đạt yêu cầu', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              SizedBox(height: 6),
              Text('Hàng khớp với hồ sơ thẩm định. Đóng gói và bàn giao cho đơn vị vận chuyển khi sẵn sàng.', style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.mutedStrong)),
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.only(top: 14), child: BigActionButton(label: 'Đã đóng gói xong', onPressed: () => store.whMarkPacked(w.id))),
      ],
    );
  }
}
