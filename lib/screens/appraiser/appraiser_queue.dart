import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'appraiser_detail.dart';

class AppraiserQueueScreen extends StatefulWidget {
  const AppraiserQueueScreen({super.key});

  @override
  State<AppraiserQueueScreen> createState() => _AppraiserQueueScreenState();
}

class _AppraiserQueueScreenState extends State<AppraiserQueueScreen> {
  String cat = 'all';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final items = store.appraisalQueue.where((i) => cat == 'all' || i.cat == cat).toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          const Text('THẨM ĐỊNH', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted, letterSpacing: 0.5)),
          const Text('Hàng chờ duyệt', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChipButton(label: 'Tất cả', selected: cat == 'all', onTap: () => setState(() => cat = 'all')),
              FilterChipButton(label: 'Giày', selected: cat == 'shoes', onTap: () => setState(() => cat = 'shoes')),
              FilterChipButton(label: 'Điện tử', selected: cat == 'elec', onTap: () => setState(() => cat = 'elec')),
              FilterChipButton(label: 'Đồ cổ', selected: cat == 'antique', onTap: () => setState(() => cat = 'antique')),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('Không còn hồ sơ chờ duyệt.', style: TextStyle(color: AppColors.muted)))),
          ...items.map((it) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AppraiserDetailScreen(itemId: it.id))),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CategoryThumb(cat: it.cat, size: 56),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(it.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.35)),
                                const SizedBox(height: 4),
                                Text('${it.seller} · gửi ${it.ago}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                const SizedBox(height: 6),
                                if (it.status == 'needinfo')
                                  const StatusPill(label: 'Chờ người bán bổ sung', tone: StatusTone.progress)
                                else
                                  const StatusPill(label: 'Chờ thẩm định', tone: StatusTone.pending),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
