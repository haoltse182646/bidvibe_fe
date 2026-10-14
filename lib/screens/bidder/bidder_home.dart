import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'bidder_detail.dart';
import '../customer/customer_chatbot.dart';

class BidderHomeScreen extends StatefulWidget {
  const BidderHomeScreen({super.key});

  @override
  State<BidderHomeScreen> createState() => _BidderHomeScreenState();
}

class _BidderHomeScreenState extends State<BidderHomeScreen> {
  String cat = 'all';

  static const cats = [('all', 'Tất cả'), ('shoes', 'Giày'), ('elec', 'Điện tử'), ('antique', 'Đồ cổ')];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final items = store.auctions.where((a) => cat == 'all' || a.cat == cat).toList()
      ..sort((x, y) {
        final xe = x.ended ? 1 : 0, ye = y.ended ? 1 : 0;
        if (xe != ye) return xe - ye;
        return x.endsAt.compareTo(y.endsAt);
      });

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(8)),
                  child: const Text('B', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                const Text('BidVibe', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CustomerChatbotScreen())),
                  tooltip: 'Hỗ trợ',
                  icon: const Icon(Icons.support_agent, color: AppColors.accent),
                ),
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text(store.money(store.wallet), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Đang diễn ra', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                              SizedBox(height: 2),
                              Text('Giá cập nhật liên tục · mọi món đều đã thẩm định', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.successStrong, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            const Text('Trực tiếp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.successStrong)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  sliver: SliverToBoxAdapter(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: cats.map((c) => FilterChipButton(label: c.$2, selected: cat == c.$1, onTap: () => setState(() => cat = c.$1))).toList(),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 250),
                    delegate: SliverChildBuilderDelegate((context, i) => _AuctionCard(auction: items[i]), childCount: items.length),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuctionCard extends StatelessWidget {
  final Auction auction;
  const _AuctionCard({required this.auction});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final urgent = !auction.ended && auction.endsAt.difference(DateTime.now()).inSeconds <= 60;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BidderDetailScreen(auctionId: auction.id))),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: Container(color: categoryTileColor(auction.cat), alignment: Alignment.center, child: Icon(_iconFor(auction.cat), size: 48, color: AppColors.neutralFg))),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: urgent ? AppColors.dangerStrong : Colors.black.withValues(alpha: 0.72), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            CountdownText(endsAt: auction.endsAt, ended: auction.ended, short: true, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    if (auction.paused && !auction.ended)
                      const Positioned(left: 8, top: 8, child: _Chip(text: 'Tạm dừng', bg: AppColors.pendingFg))
                    else if (auction.terminated)
                      const Positioned(left: 8, top: 8, child: _Chip(text: 'Đã bị chấm dứt', bg: AppColors.dangerStrong))
                    else if (!auction.ended && auction.leading)
                      const Positioned(left: 8, top: 8, child: _Chip(text: 'Bạn dẫn đầu', bg: AppColors.successStrong))
                    else if (!auction.ended && auction.myBid > 0 && !auction.leading)
                      const Positioned(left: 8, top: 8, child: _Chip(text: 'Bị vượt giá', bg: AppColors.dangerStrong))
                    else if (!auction.ended && auction.joined)
                      const Positioned(left: 8, top: 8, child: _Chip(text: 'Đã đặt cọc', bg: AppColors.accent))
                    else if (auction.ended && auction.won)
                      const Positioned(left: 8, top: 8, child: _Chip(text: 'Bạn đã thắng', bg: AppColors.successStrong))
                    else if (auction.ended && auction.joined)
                      const Positioned(left: 8, top: 8, child: _Chip(text: 'Không thắng', bg: AppColors.neutralFg)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(auction.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.3)),
                    const SizedBox(height: 6),
                    const Text('Giá hiện tại', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                    Text(store.money(auction.price), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                    const SizedBox(height: 2),
                    Text('${auction.count} lượt đặt giá', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String cat) {
    switch (cat) {
      case 'shoes':
        return Icons.directions_walk;
      case 'elec':
        return Icons.camera_alt_outlined;
      default:
        return Icons.emoji_objects_outlined;
    }
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color bg;
  const _Chip({required this.text, required this.bg});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
