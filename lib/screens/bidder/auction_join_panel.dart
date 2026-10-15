import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/remote_app_store.dart';
import '../../features/auctions/auction_repository.dart';
import '../../features/wallet/wallet_repository.dart';
import '../../store.dart';
import 'bidder_wallet.dart';

class AuctionJoinPanel extends StatefulWidget {
  final Map<String, dynamic> auction;
  final AuctionRepository repository;
  final Future<bool> Function() onRefresh;
  final bool refreshing, stale;
  const AuctionJoinPanel({
    super.key,
    required this.auction,
    required this.repository,
    required this.onRefresh,
    this.refreshing = false,
    this.stale = false,
  });
  @override
  State<AuctionJoinPanel> createState() => _AuctionJoinPanelState();
}

class _AuctionJoinPanelState extends State<AuctionJoinPanel> {
  bool _busy = false, _needsVerification = false, _insufficient = false;
  String? _message;
  String _money(dynamic amount) =>
      '${NumberFormat.decimalPattern('vi_VN').format(amount is num ? amount : 0)} đ';

  bool get _locked => _busy || widget.refreshing;

  bool _authError(ApiException e) {
    if (['UNAUTHORIZED', 'ACCOUNT_SUSPENDED'].contains(e.code)) {
      final store = context.read<AppStore>();
      if (store is RemoteAppStore) {
        store.logout();
        store.sessionError = e.message;
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
      return true;
    }
    return false;
  }

  Future<bool> _refresh() async {
    final success = await widget.onRefresh();
    if (mounted && success) {
      setState(() {
        _needsVerification = false;
        _insufficient = false;
      });
    }
    return success;
  }

  Future<void> _wallet() async {
    if (_locked) {
      return;
    }
    setState(() => _busy = true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Ví của tôi')),
            body: BidderWalletScreen(
              repository: WalletRepository(widget.repository.api),
            ),
          ),
        ),
      );
      if (mounted) {
        await _refresh();
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _join() async {
    if (_locked ||
        _needsVerification ||
        widget.stale ||
        widget.auction['joined'] == true ||
        widget.auction['isLive'] != true) {
      return;
    }
    setState(() => _busy = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Đặt cọc tham gia phiên'),
          content: Text(
            'Giữ ${_money(widget.auction['depositRequired'])} từ số dư khả dụng để tham gia phiên này? '
            'Thao tác này chưa gửi lượt đặt giá. Cọc được xử lý theo kết quả phiên và hạn thanh toán.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Xác nhận đặt cọc'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) {
        return;
      }
      try {
        await widget.repository.join('${widget.auction['id']}');
        if (!mounted) {
          return;
        }
        setState(() {
          _needsVerification = true;
          _message = 'BE đã xác nhận đặt cọc thành công. Đang tải lại trạng thái phiên.';
        });
        final success = await _refresh();
        if (mounted) {
          setState(
            () => _message = success ? 'Đã cập nhật trạng thái đặt cọc từ BE.' : 'Đặt cọc đã thành công, nhưng chưa tải lại được phiên. Hãy tải lại trạng thái trước khi tiếp tục.',
          );
        }
      } on ApiException catch (e) {
        if (!mounted || _authError(e)) {
          return;
        }
        if (e.code == 'INSUFFICIENT_FUNDS') {
          setState(() {
            _insufficient = true;
            _message = e.message;
          });
        } else if ([
          'ALREADY_JOINED',
          'AUCTION_ENDED',
          'AUCTION_PAUSED',
        ].contains(e.code)) {
          setState(() {
            _needsVerification = true;
            _message = e.message;
          });
          await _refresh();
        } else {
          final rejected = [
            'NOT_FOUND',
            'FORBIDDEN',
            'VALIDATION_ERROR',
          ].contains(e.code);
          setState(() {
            _needsVerification = !rejected;
            _message = rejected ? e.message : 'Chưa xác định được kết quả đặt cọc. Tải lại trạng thái và kiểm tra ví trước khi gửi lại.';
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _needsVerification = true;
            _message = 'Chưa xác định được kết quả đặt cọc. Hãy tải lại trạng thái phiên.';
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.auction;
    final joined = a['joined'] == true;
    final needsFunds = a['depositAffordable'] == false || _insufficient;
    final paused = a['paused'] == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Đặt cọc tham gia',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('Cọc yêu cầu: ${_money(a['depositRequired'])}'),
            if (_busy) const LinearProgressIndicator(),
            if (_message != null) Text(_message!),
            if (joined)
              const Text(
                'Bạn đã đặt cọc tham gia phiên này. Không cần đặt cọc lại.',
              )
            else if (a['isLive'] != true)
              Text(
                paused
                    ? 'Phiên đang tạm dừng, chưa thể đặt cọc.'
                    : 'Phiên hiện không nhận đặt cọc.',
              )
            else if (needsFunds)
              const Text('Ví chưa đủ tiền cọc. Hãy nạp ví rồi tải lại phiên.')
            else
              const Text('Đặt cọc trước khi gửi lượt đặt giá.'),
            if (!joined && a['isLive'] == true && !needsFunds)
              FilledButton(
                onPressed: _locked || _needsVerification || widget.stale
                    ? null
                    : _join,
                child: const Text('Đặt cọc tham gia'),
              ),
            if (widget.stale || _needsVerification)
              const Text('Cần tải lại dữ liệu trước khi tiếp tục thao tác.'),
            if (needsFunds || joined || _needsVerification)
              OutlinedButton(
                onPressed: _locked ? null : _wallet,
                child: const Text('Mở ví / Nạp tiền'),
              ),
            TextButton(
              onPressed: _locked ? null : _refresh,
              child: const Text('Tải lại trạng thái đặt cọc'),
            ),
          ],
        ),
      ),
    );
  }
}
