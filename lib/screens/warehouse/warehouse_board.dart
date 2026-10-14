import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'warehouse_detail.dart';

class WarehouseBoardScreen extends StatefulWidget {
  const WarehouseBoardScreen({super.key});

  @override
  State<WarehouseBoardScreen> createState() => _WarehouseBoardScreenState();
}

class _WarehouseBoardScreenState extends State<WarehouseBoardScreen> {
  String colFilter = 'waiting';

  static const colDefs = [('waiting', 'Chờ nhận'), ('inspecting', 'Đang kiểm'), ('packed', 'Sẵn sàng gửi'), ('shipped', 'Đang giao'), ('delivered', 'Đã giao'), ('escalated', 'Đã báo Admin')];
  static const listTitleMap = {'waiting': 'Chờ nhận hàng', 'inspecting': 'Đang kiểm hàng', 'packed': 'Sẵn sàng gửi', 'shipped': 'Đang giao', 'delivered': 'Đã giao thành công', 'escalated': 'Đã báo cáo lên Admin'};

  bool _colMatch(String col, String status) => col == 'packed' ? (status == 'packed' || status == 'inspecting_done') : status == col;

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
    final items = store.warehouseShipments.where((w) => _colMatch(colFilter, w.status)).toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          const Text('KHO VẬN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted, letterSpacing: 0.5)),
          const Text('Đơn đang xử lý', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          const SizedBox(height: 12),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, mainAxisExtent: 96),
            children: colDefs.map((c) {
              final n = store.warehouseShipments.where((w) => _colMatch(c.$1, w.status)).length;
              final on = colFilter == c.$1;
              return Material(
                color: on ? const Color(0xFFF1F3F8) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => colFilter = c.$1),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: on ? AppColors.accent : AppColors.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$n', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: on ? AppColors.accent : AppColors.ink)),
                        Text(c.$2, style: const TextStyle(fontSize: 13, color: AppColors.mutedStrong)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          Text(listTitleMap[colFilter]!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (items.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: Text('Không có đơn nào ở trạng thái này.', style: TextStyle(color: AppColors.muted)))),
          ...items.map((w) {
            final (label, tone) = _pill(w.status);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WarehouseDetailScreen(id: w.id))),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                    child: Row(
                      children: [
                        CategoryThumb(cat: w.cat, size: 52),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(w.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.35)),
                              const SizedBox(height: 4),
                              Text('${w.code} · ${w.seller}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                              const SizedBox(height: 6),
                              StatusPill(label: label, tone: tone),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.muted),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
