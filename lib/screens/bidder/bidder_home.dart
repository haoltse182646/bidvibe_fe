import 'auction_detail_screen.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/remote_app_store.dart';
import '../../features/auctions/auction_repository.dart';
import '../../store.dart';

class BidderHomeScreen extends StatefulWidget {
  final AuctionRepository? repository;
  final Listenable? refreshSignal;
  final VoidCallback? onReturnFromAuction;
  final Future<void> Function(String)? onOpenOrder;
  const BidderHomeScreen(
      {super.key,
      this.repository,
      this.refreshSignal,
      this.onReturnFromAuction,
      this.onOpenOrder});
  @override
  State<BidderHomeScreen> createState() => _BidderHomeScreenState();
}

class _BidderHomeScreenState extends State<BidderHomeScreen> {
  final _search = TextEditingController();
  late final AuctionRepository _repo;
  List<Map<String, dynamic>> _categories = [], _items = [];
  String? _category, _error, _categoryError;
  String _status = 'live', _sort = 'ending', _query = '';
  bool _loading = true, _moreLoading = false, _categoryLoading = true;
  int _total = 0, _generation = 0;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ??
        AuctionRepository((context.read<AppStore>() as RemoteAppStore).api);
    _loadCategories();
    _load();
  }

  @override
  void dispose() {
    _generation++;
    _search.dispose();
    super.dispose();
  }

  String _message(Object error) {
    if (error is ApiException) return error.message;
    return 'Không tải được dữ liệu. Vui lòng thử lại.';
  }

  bool _sessionExpired(Object error) {
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

  Future<void> _loadCategories() async {
    setState(() {
      _categoryLoading = true;
      _categoryError = null;
    });
    try {
      final values = await _repo.categories();
      if (!mounted) return;
      setState(() => _categories = values);
    } catch (e) {
      if (!mounted || _sessionExpired(e)) return;
      setState(() => _categoryError = _message(e));
    } finally {
      if (mounted) setState(() => _categoryLoading = false);
    }
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_loading || _moreLoading || _items.length >= _total)) return;
    final generation = more ? _generation : ++_generation;
    final offset = more ? _items.length : 0;
    setState(() {
      _error = null;
      if (more) {
        _moreLoading = true;
      } else {
        _loading = true;
        _moreLoading = false;
        _items = [];
        _total = 0;
      }
    });
    try {
      final page = await _repo.list(
        status: _status,
        category: _category,
        query: _query,
        sort: _sort,
        offset: offset,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = more ? [..._items, ...page.items] : page.items;
        _total = page.total;
      });
    } catch (e) {
      if (!mounted || generation != _generation || _sessionExpired(e)) return;
      setState(() => _error = _message(e));
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _moreLoading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_loadCategories(), _load()]);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Khám phá phiên đấu giá',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Dữ liệu từ máy chủ · Kéo xuống để cập nhật'),
          const SizedBox(height: 16),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              _query = _search.text.trim();
              _load();
            },
            decoration: InputDecoration(
              labelText: 'Tìm theo tên sản phẩm',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Tìm kiếm',
                icon: const Icon(Icons.search),
                onPressed: () {
                  _query = _search.text.trim();
                  _load();
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_categoryLoading) const LinearProgressIndicator(),
          if (_categoryError != null) ...[
            Text(_categoryError!),
            TextButton(
              onPressed: _loadCategories,
              child: const Text('Tải lại danh mục'),
            ),
          ],
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Tất cả'),
                selected: _category == null,
                onSelected: (_) {
                  setState(() => _category = null);
                  _load();
                },
              ),
              for (final category in _categories)
                ChoiceChip(
                  label: Text('${category['name']}'),
                  selected: _category == category['code'],
                  onSelected: (_) {
                    setState(() => _category = '${category['code']}');
                    _load();
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Danh sách phiên'),
            items: const [
              DropdownMenuItem(value: 'live', child: Text('Đang diễn ra')),
              DropdownMenuItem(
                value: 'ended',
                child: Text('Đã kết thúc / hủy'),
              ),
              DropdownMenuItem(
                value: 'joined',
                child: Text('Phiên đã tham gia'),
              ),
            ],
            onChanged: (v) {
              if (v != null) {
                _status = v;
                _load();
              }
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _sort,
            decoration: const InputDecoration(labelText: 'Sắp xếp'),
            items: const [
              DropdownMenuItem(value: 'ending', child: Text('Sắp kết thúc')),
              DropdownMenuItem(value: 'newest', child: Text('Mới nhất')),
              DropdownMenuItem(value: 'price_asc', child: Text('Giá tăng dần')),
              DropdownMenuItem(
                value: 'price_desc',
                child: Text('Giá giảm dần'),
              ),
              DropdownMenuItem(
                value: 'popular',
                child: Text('Nhiều lượt đặt giá'),
              ),
            ],
            onChanged: (v) {
              if (v != null) {
                _sort = v;
                _load();
              }
            },
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            Text('Đã tải ${_items.length} / $_total phiên'),
            if (_items.isEmpty && _error == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'Không có phiên phù hợp. Thử đổi bộ lọc hoặc từ khóa.',
                ),
              ),
            for (final item in _items)
              _AuctionCard(
                item: item,
                onOpen: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AuctionDetailScreen(
                        auctionId: '${item['id']}',
                        repository: _repo,
                        refreshSignal: widget.refreshSignal,
                        onOpenOrder: widget.onOpenOrder,
                      ),
                    ),
                  );
                  if (mounted) {
                    widget.onReturnFromAuction?.call();
                    await _load();
                  }
                },
              ),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(
                onPressed: () => _load(more: _items.isNotEmpty),
                child: const Text('Thử lại'),
              ),
            ],
            if (_items.length < _total && _error == null)
              OutlinedButton(
                onPressed: _moreLoading ? null : () => _load(more: true),
                child: Text(_moreLoading ? 'Đang tải...' : 'Tải thêm'),
              ),
          ],
        ],
      ),
    );
  }
}

class _AuctionCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onOpen;
  const _AuctionCard({required this.item, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final seller = item['seller'] as Map?;
    final image = item['coverUrl'] as String?;
    final paused = item['paused'] == true;
    final seconds = (item['remainingSeconds'] as num?)?.toInt() ?? 0;
    final state = item['terminated'] == true || item['status'] == 'cancelled'
        ? 'Đã hủy'
        : paused
            ? 'Tạm dừng'
            : item['status'] == 'ended'
                ? 'Đã kết thúc'
                : seconds <= 0
                    ? 'Chờ máy chủ chốt phiên'
                    : 'Đang diễn ra';
    final money = NumberFormat.decimalPattern('vi_VN')
        .format((item['currentPrice'] as num?) ?? 0);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextButton(
            onPressed: onOpen,
            child: const Text('Xem chi tiết phiên'),
          ),
          if (image != null && image.isNotEmpty)
            Image.network(
              image,
              height: 170,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const SizedBox(
                height: 100,
                child: Icon(Icons.broken_image_outlined),
              ),
            )
          else
            const SizedBox(height: 100, child: Icon(Icons.image_outlined)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['title']}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text('${seller?['name'] ?? 'Người bán'} · $state'),
                Text('$money đ', style: Theme.of(context).textTheme.titleLarge),
                Text(
                  '${item['bidCount'] ?? 0} lượt đặt giá · Mã phiên ${item['id']}',
                ),
                if (item['joined'] == true)
                  const Text('Bạn đã tham gia phiên này'),
                if (item['leading'] == true) const Text('Bạn đang dẫn đầu'),
                if (item['won'] == true) const Text('Bạn đã thắng phiên'),
                if (item['status'] == 'active' && seconds > 0)
                  Text(
                    '${paused ? 'Thời gian còn lại khi dừng' : 'Còn lại lúc tải'}: '
                    '${Duration(seconds: seconds).toString().split('.').first}',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
