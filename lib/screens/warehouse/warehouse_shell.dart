import 'package:flutter/material.dart';
import 'warehouse_board.dart';

/// Vai trò Kho vận không dùng thanh tab dưới cùng như các vai trò khác —
/// luồng chính là Bảng tổng quan (dạng kanban rút gọn) → Chi tiết đơn.
class WarehouseShell extends StatelessWidget {
  const WarehouseShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const WarehouseBoardScreen();
  }
}
