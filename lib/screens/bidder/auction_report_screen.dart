import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/remote_app_store.dart';
import '../../features/auctions/auction_repository.dart';
import '../../store.dart';

class AuctionReportScreen extends StatefulWidget {
  final String auctionId;
  final String? auctionTitle;
  final AuctionRepository repository;
  final VoidCallback? onReported;
  const AuctionReportScreen({
    super.key,
    required this.auctionId,
    required this.repository,
    this.auctionTitle,
    this.onReported,
  });
  @override
  State<AuctionReportScreen> createState() => _AuctionReportScreenState();
}

class _AuctionReportScreenState extends State<AuctionReportScreen> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false,
      _confirming = false,
      _sent = false,
      _already = false,
      _unavailable = false;
  String? _error;
  Map<String, String>? _pending;
  bool get _locked =>
      _busy || _confirming || _sent || _unavailable || _pending != null;

  @override
  void dispose() {
    _reason.dispose();
    _note.dispose();
    super.dispose();
  }

  void _received({bool already = false}) {
    setState(() {
      _sent = true;
      _already = already;
      _pending = null;
      _error = null;
    });
    widget.onReported?.call();
  }

  Future<void> _send({bool retry = false}) async {
    if (_busy || _confirming || _sent || _unavailable) {
      return;
    }
    if (!retry && (!_form.currentState!.validate() || _pending != null)) {
      return;
    }
    final payload = retry
        ? _pending
        : <String, String>{
            'reason': _reason.text.trim(),
            'note': _note.text.trim(),
          };
    if (payload == null) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _confirming = true);
    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(retry ? 'Gửi lại báo cáo?' : 'Xác nhận gửi báo cáo'),
          content: Text(
            retry
                ? 'Nếu báo cáo trước đã được nhận, hệ thống sẽ chặn báo cáo trùng. Gửi lại cùng nội dung?'
                : 'Gửi báo cáo về phiên #${widget.auctionId} để quản trị viên xem xét? Mỗi tài khoản chỉ báo cáo một lần cho mỗi phiên.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Xác nhận gửi'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _confirming = false);
      }
    }
    if (!mounted || confirmed != true) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.report(
        widget.auctionId,
        reason: payload['reason']!,
        note: payload['note'],
      );
      if (mounted) {
        _received();
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      if (['UNAUTHORIZED', 'ACCOUNT_SUSPENDED'].contains(e.code)) {
        final store = context.read<AppStore>();
        store.logout();
        if (store is RemoteAppStore) {
          store.sessionError = e.message;
        }
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }
      if (e.code == 'ALREADY_REPORTED') {
        _received(already: true);
      } else if ([
        'VALIDATION_ERROR',
        'NOT_FOUND',
        'FORBIDDEN',
      ].contains(e.code)) {
        setState(() {
          _error = e.message;
          _pending = null;
          _unavailable = e.code != 'VALIDATION_ERROR';
        });
      } else {
        setState(() {
          _pending = payload;
          _error = 'Chưa xác định được báo cáo đã gửi thành công hay chưa. Bạn có thể gửi lại cùng nội dung; hệ thống sẽ chặn báo cáo trùng.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _pending = payload;
          _error =
              'Chưa xác nhận được kết quả. Bạn có thể gửi lại cùng nội dung.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Báo cáo phiên đấu giá')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.auctionTitle ?? 'Phiên #${widget.auctionId}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (_sent) ...[
              const Icon(Icons.check_circle_outline, size: 48),
              Text(
                _already
                    ? 'Bạn đã báo cáo phiên này trước đó.'
                    : 'Báo cáo đã được ghi nhận để quản trị viên xem xét.',
              ),
              const Text(
                'Gửi báo cáo không tự động hủy hoặc dừng phiên đấu giá.',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Quay lại phiên'),
              ),
            ] else ...[
              const Text(
                'Mô tả vấn đề bạn nhận thấy. Mỗi tài khoản chỉ gửi một báo cáo cho mỗi phiên.',
              ),
              const SizedBox(height: 16),
              Form(
                key: _form,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _reason,
                      enabled: !_locked,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: 'Lý do báo cáo',
                        hintText: 'Ví dụ: Nghi đẩy giá',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final reason = value?.trim() ?? '';
                        if (reason.isEmpty) {
                          return 'Vui lòng nhập lý do báo cáo.';
                        }
                        if (reason.length > 100) {
                          return 'Lý do tối đa 100 ký tự.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _note,
                      enabled: !_locked,
                      maxLength: 500,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú (không bắt buộc)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => (value?.trim().length ?? 0) > 500
                          ? 'Ghi chú tối đa 500 ký tự.'
                          : null,
                    ),
                  ],
                ),
              ),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 16),
              if (_pending != null)
                FilledButton(
                  onPressed: _busy || _confirming
                      ? null
                      : () => _send(retry: true),
                  child: const Text('Gửi lại cùng nội dung'),
                )
              else
                FilledButton(
                  onPressed: _locked ? null : _send,
                  child: Text(_busy ? 'Đang gửi...' : 'Gửi báo cáo'),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}
