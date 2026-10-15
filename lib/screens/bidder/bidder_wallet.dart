import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/remote_app_store.dart';
import '../../features/wallet/wallet_repository.dart';
import '../../store.dart';

class BidderWalletScreen extends StatefulWidget {
  final WalletRepository? repository;
  const BidderWalletScreen({super.key, this.repository});
  @override
  State<BidderWalletScreen> createState() => _BidderWalletScreenState();
}

class _BidderWalletScreenState extends State<BidderWalletScreen> {
  late final WalletRepository _repo;
  final _amount = TextEditingController();
  final _form = GlobalKey<FormState>();
  WalletSnapshot? _wallet;
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true,
      _posting = false,
      _loadingMore = false,
      _uncertain = false;
  int _total = 0, _generation = 0;
  String? _error, _pageError;

  @override
  void initState() {
    super.initState();
    _repo =
        widget.repository ??
        WalletRepository((context.read<AppStore>() as RemoteAppStore).api);
    _load();
  }

  @override
  void dispose() {
    _generation++;
    _amount.dispose();
    super.dispose();
  }

  String _money(num value) =>
      '${NumberFormat.decimalPattern('vi_VN').format(value)} đ';
  String _time(dynamic value) {
    final parsed = DateTime.tryParse('$value');
    return parsed == null
        ? 'Chưa có thời gian'
        : DateFormat('dd/MM/yyyy HH:mm:ss').format(parsed.toLocal());
  }

  bool _authError(Object error) {
    if (error is ApiException &&
        ['UNAUTHORIZED', 'ACCOUNT_SUSPENDED'].contains(error.code)) {
      final store = context.read<AppStore>();
      if (store is RemoteAppStore) {
        store.logout();
        store.sessionError = error.message;
      }
      return true;
    }
    return false;
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : 'Không tải được ví. Vui lòng thử lại.';

  Future<void> _load() async {
    if (_posting) {
      return;
    }
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _pageError = null;
      _loadingMore = false;
    });
    try {
      final results = await Future.wait<Object>([
        _repo.wallet(),
        _repo.transactions(),
      ]);
      if (!mounted || generation != _generation) {
        return;
      }
      final page = results[1] as WalletPage;
      setState(() {
        _wallet = results[0] as WalletSnapshot;
        _transactions = page.transactions;
        _total = page.total;
        _uncertain = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation || _authError(e)) {
        return;
      }
      setState(() => _error = _message(e));
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _more() async {
    if (_loading ||
        _posting ||
        _loadingMore ||
        _transactions.length >= _total) {
      return;
    }
    final generation = _generation;
    setState(() {
      _loadingMore = true;
      _pageError = null;
    });
    try {
      final page = await _repo.transactions(offset: _transactions.length);
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _transactions = [..._transactions, ...page.transactions];
        _total = page.total;
      });
    } catch (e) {
      if (!mounted || generation != _generation || _authError(e)) {
        return;
      }
      setState(() => _pageError = _message(e));
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _topup() async {
    if (_posting ||
        _loading ||
        _loadingMore ||
        _uncertain ||
        !_form.currentState!.validate()) {
      return;
    }
    final amount = int.parse(_amount.text.trim());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận nạp ví'),
        content: Text(
          'Nạp ${_money(amount)} vào ví? Đây là cổng nạp tiền giả lập của bản demo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || _posting || _loading || _loadingMore) {
      return;
    }
    setState(() {
      _posting = true;
      _error = null;
    });
    var success = false;
    try {
      final wallet = await _repo.topup(amount);
      if (!mounted) {
        return;
      }
      setState(() => _wallet = wallet);
      _amount.clear();
      success = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã nạp ${_money(amount)} vào ví.')),
      );
    } catch (e) {
      if (!mounted || _authError(e)) {
        return;
      }
      final knownRejection =
          e is ApiException &&
          ['VALIDATION_ERROR', 'FORBIDDEN', 'NOT_FOUND'].contains(e.code);
      setState(() {
        _uncertain = !knownRejection;
        _error = knownRejection ? _message(e) : 'Chưa xác định được kết quả nạp. Hãy tải lại ví và kiểm tra giao dịch trước khi nạp lần nữa.';
      });
    } finally {
      if (mounted) {
        setState(() => _posting = false);
      }
    }
    if (mounted && success) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked =
        _loading || _posting || _loadingMore || _uncertain || _wallet == null;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text('Ví của tôi', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          if (_loading || _posting) const LinearProgressIndicator(),
          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            if (_wallet != null)
              const Text('Số dư bên dưới có thể là dữ liệu đã tải trước đó.'),
          ],
          TextButton.icon(
            onPressed: _loading || _posting ? null : _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Tải lại ví và lịch sử'),
          ),
          if (_wallet != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Số dư khả dụng'),
                    Text(
                      _money(_wallet!.available),
                      key: const Key('wallet-available'),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text('Cọc đang giữ: ${_money(_wallet!.held)}'),
                    const Text('Tiền cọc đang giữ nằm ngoài số dư khả dụng.'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text('Nạp tiền', style: Theme.of(context).textTheme.titleLarge),
          const Text('Nạp tiền giả lập cho bản demo, không thu tiền thật.'),
          const SizedBox(height: 12),
          Form(
            key: _form,
            child: TextFormField(
              controller: _amount,
              enabled: !locked,
              keyboardType: TextInputType.number,
              validator: (v) => WalletRepository.validateAmount(v ?? ''),
              decoration: const InputDecoration(
                labelText: 'Số tiền (VND)',
                hintText: 'Ví dụ: 1000000',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final amount in [100000, 500000, 1000000, 5000000])
                ActionChip(
                  label: Text(_money(amount)),
                  onPressed: locked ? null : () => _amount.text = '$amount',
                ),
            ],
          ),
          FilledButton(
            onPressed: locked ? null : _topup,
            child: Text(_posting ? 'Đang nạp...' : 'Nạp tiền'),
          ),
          const SizedBox(height: 24),
          Text(
            'Lịch sử giao dịch',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text('Đã tải ${_transactions.length} / $_total giao dịch'),
          if (!_loading && _error == null && _transactions.isEmpty)
            const Text('Chưa có giao dịch'),
          for (final tx in _transactions)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tx['kindLabel'] ?? tx['kind']}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Giá trị giao dịch: ${_money((tx['amount'] as num?) ?? 0)}',
                    ),
                    Text(
                      'Số dư sau giao dịch: ${_money((tx['balanceAfter'] as num?) ?? 0)}',
                    ),
                    Text('${_time(tx['createdAt'])} · Mã #${tx['id']}'),
                    if (tx['relatedAuctionId'] != null)
                      Text(
                        'Phiên #${tx['relatedAuctionId']} · ${tx['auctionTitle'] ?? ''}',
                      ),
                  ],
                ),
              ),
            ),
          if (_pageError != null) ...[
            Text(_pageError!),
            TextButton(onPressed: _more, child: const Text('Thử tải thêm lại')),
          ],
          if (_transactions.length < _total && _pageError == null)
            OutlinedButton(
              onPressed: _loading || _posting || _loadingMore ? null : _more,
              child: Text(_loadingMore ? 'Đang tải...' : 'Tải thêm giao dịch'),
            ),
        ],
      ),
    );
  }
}
