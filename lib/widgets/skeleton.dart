import 'package:flutter/material.dart';

import '../theme.dart';

/// Khung xám đang tải: màu phẳng, chỉ nhấp nháy độ đậm (không gradient).
/// Tắt chuyển động khi người dùng bật "giảm chuyển động" trong hệ thống.
class SkeletonPulse extends StatefulWidget {
  final Widget child;
  const SkeletonPulse({super.key, required this.child});

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _opacity = Tween<double>(begin: 0.5, end: 1).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: _opacity, child: widget.child);
}

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 8});

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(color: const Color(0xFFE8E5DE), borderRadius: BorderRadius.circular(radius)),
  );
}

/// Thẻ trắng viền mảnh như thẻ thật, chứa các khối xám.
class SkeletonCard extends StatelessWidget {
  final Widget child;
  const SkeletonCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}

/// Danh sách thẻ "ảnh nhỏ + 2 dòng chữ + nhãn" cho màn danh sách đơn / tranh chấp.
class SkeletonTileList extends StatelessWidget {
  final int count;
  const SkeletonTileList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Đang tải',
      child: ExcludeSemantics(
        child: SkeletonPulse(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(), // vẫn kéo để làm mới được
            padding: const EdgeInsets.all(16),
            children: [
              for (var i = 0; i < count; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                const SkeletonCard(
                  child: Row(
                    children: [
                      SkeletonBox(width: 56, height: 56, radius: 10),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(height: 14),
                            SizedBox(height: 8),
                            SkeletonBox(width: 120, height: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Khung màn chi tiết đơn: thẻ đầu, thẻ tiền, thẻ địa chỉ.
class SkeletonOrderDetail extends StatelessWidget {
  const SkeletonOrderDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Đang tải đơn hàng',
      child: ExcludeSemantics(
        child: SkeletonPulse(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: const [
              SkeletonCard(
                child: Row(
                  children: [
                    SkeletonBox(width: 64, height: 64, radius: 10),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(height: 14),
                          SizedBox(height: 8),
                          SkeletonBox(width: 100, height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 18),
              SkeletonBox(width: 150, height: 16),
              SizedBox(height: 8),
              SkeletonCard(
                child: Column(
                  children: [
                    SkeletonBox(height: 12),
                    SizedBox(height: 14),
                    SkeletonBox(height: 12),
                    SizedBox(height: 14),
                    SkeletonBox(height: 12),
                    SizedBox(height: 14),
                    SkeletonBox(height: 20),
                  ],
                ),
              ),
              SizedBox(height: 18),
              SkeletonBox(width: 90, height: 16),
              SizedBox(height: 8),
              SkeletonCard(child: SkeletonBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }
}
