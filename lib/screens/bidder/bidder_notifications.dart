import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../features/notifications/notification_controller.dart';
import '../../features/notifications/notification_repository.dart';

class BidderNotificationsScreen extends StatelessWidget {
  final NotificationController controller;
  final Future<void> Function(NotificationItem) onOpen;
  const BidderNotificationsScreen({
    super.key,
    required this.controller,
    required this.onOpen,
  });

  IconData _icon(String type) => switch (type) {
    'outbid' => Icons.trending_up,
    'win' => Icons.emoji_events_outlined,
    'refund' => Icons.replay,
    'order' => Icons.local_shipping_outlined,
    'dispute' => Icons.support_agent,
    'warn' => Icons.warning_amber_rounded,
    _ => Icons.notifications_outlined,
  };

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, child) => RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text('Thông báo', style: Theme.of(context).textTheme.headlineSmall),
          Text('${controller.unreadCount} thông báo chưa đọc'),
          Text(
            controller.connected
                ? 'Đang nhận thông báo trực tiếp'
                : 'Chưa có kết nối trực tiếp. Kéo xuống để cập nhật.',
          ),
          TextButton(
            onPressed:
                controller.loading ||
                    controller.mutating ||
                    controller.unreadCount == 0
                ? null
                : controller.markAllRead,
            child: const Text('Đánh dấu tất cả đã đọc'),
          ),
          if (controller.loading || controller.mutating)
            const LinearProgressIndicator(),
          if (controller.error != null) ...[
            Text(
              controller.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(
              onPressed: controller.loading ? null : controller.refresh,
              child: const Text('Thử lại'),
            ),
            if (controller.items.isNotEmpty)
              const Text(
                'Danh sách bên dưới có thể là dữ liệu đã tải trước đó.',
              ),
          ],
          if (!controller.loading &&
              controller.error == null &&
              controller.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text('Bạn chưa có thông báo.'),
            ),
          for (final item in controller.items)
            Card(
              color: item.isRead
                  ? null
                  : Theme.of(context).colorScheme.primaryContainer,
              child: ListTile(
                leading: Icon(_icon(item.type)),
                title: Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: item.isRead
                        ? FontWeight.normal
                        : FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  item.createdAt == null
                      ? ''
                      : DateFormat('dd/MM/yyyy HH:mm')
                            .format(item.createdAt!.toLocal()),
                ),
                trailing: item.isRead
                    ? null
                    : const Icon(Icons.circle, size: 10),
                onTap: controller.mutating ? null : () => onOpen(item),
              ),
            ),
          if (controller.pageError != null) ...[
            Text(controller.pageError!),
            TextButton(
              onPressed: controller.loadingMore ? null : controller.more,
              child: const Text('Thử tải thêm lại'),
            ),
          ],
          if (controller.hasMore && controller.pageError == null)
            OutlinedButton(
              onPressed:
                  controller.loading ||
                      controller.loadingMore ||
                      controller.mutating
                  ? null
                  : controller.more,
              child: Text(
                controller.loadingMore ? 'Đang tải...' : 'Tải thêm thông báo',
              ),
            ),
        ],
      ),
    ),
  );
}
