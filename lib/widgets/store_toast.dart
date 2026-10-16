import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store.dart';
import '../theme.dart';

/// Hiện thông báo ngắn mà store phát ra (`AppStore.showMessage`) dưới dạng SnackBar.
/// Đặt một lần ở khung chính của app; mỗi thông báo mới (id mới) chỉ hiện một lần.
class StoreToastListener extends StatefulWidget {
  final Widget child;
  const StoreToastListener({super.key, required this.child});

  @override
  State<StoreToastListener> createState() => _StoreToastListenerState();
}

class _StoreToastListenerState extends State<StoreToastListener> {
  String? _lastShown;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final id = store.toastId;
    if (id != null && id != _lastShown) {
      _lastShown = id;
      final title = store.toastTitle;
      final body = store.toastBody;
      final danger = store.toastIsDanger;
      // Hiện sau khung hình hiện tại: không gọi ScaffoldMessenger trong lúc build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              backgroundColor: danger ? AppColors.dangerStrong : null,
              duration: Duration(seconds: danger ? 5 : 3),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (body.isNotEmpty) Text(body),
                ],
              ),
            ),
          );
      });
    }
    return widget.child;
  }
}
