import 'dart:async';

import 'package:flutter/widgets.dart';

/// Gom các yêu cầu cập nhật và đợi thao tác/biểu mẫu hiện tại hoàn tất.
/// Chỉ tải lại dữ liệu; không thử lại các yêu cầu ghi.
mixin DeferredRefresh<T extends StatefulWidget> on State<T> {
  Listenable? get refreshSignal;
  bool get canRefresh;
  Future<void> refreshData();

  bool _refreshPending = false;
  bool _refreshRunning = false;

  @override
  void initState() {
    super.initState();
    _boundSignal = refreshSignal;
    refreshSignal?.addListener(requestDataRefresh);
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    // Rebind even when the caller replaces its signal.
    _boundSignal?.removeListener(requestDataRefresh);
    super.didUpdateWidget(oldWidget);
    refreshSignal?.removeListener(requestDataRefresh);
    refreshSignal?.addListener(requestDataRefresh);
    _boundSignal = refreshSignal;
  }

  Listenable? _boundSignal;

  void requestDataRefresh() {
    _refreshPending = true;
    drainDataRefresh();
  }

  void drainDataRefresh() {
    _boundSignal ??= refreshSignal;
    if (!mounted || !_refreshPending || _refreshRunning || !canRefresh) {
      return;
    }
    _refreshPending = false;
    _refreshRunning = true;
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    try {
      await refreshData();
    } finally {
      _refreshRunning = false;
      drainDataRefresh();
    }
  }

  @override
  void dispose() {
    (_boundSignal ?? refreshSignal)?.removeListener(requestDataRefresh);
    super.dispose();
  }
}
