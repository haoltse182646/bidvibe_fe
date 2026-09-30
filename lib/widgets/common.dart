import 'package:flutter/material.dart';
import '../theme.dart';

/// Ô minh hoạ ảnh sản phẩm theo danh mục (chưa có ảnh thật trong prototype).
class CategoryThumb extends StatelessWidget {
  final String cat;
  final double size;
  final double radius;
  const CategoryThumb({super.key, required this.cat, this.size = 56, this.radius = 12});

  IconData get _icon {
    switch (cat) {
      case 'shoes':
        return Icons.directions_walk;
      case 'elec':
        return Icons.camera_alt_outlined;
      case 'antique':
        return Icons.emoji_objects_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: categoryTileColor(cat), borderRadius: BorderRadius.circular(radius)),
      alignment: Alignment.center,
      child: Icon(_icon, size: size * 0.46, color: AppColors.neutralFg),
    );
  }
}

/// Đồng hồ đếm ngược chạy thật, tự cập nhật mỗi giây.
class CountdownText extends StatefulWidget {
  final DateTime endsAt;
  final TextStyle? style;
  final bool short;
  final bool ended;
  const CountdownText({super.key, required this.endsAt, this.style, this.short = false, this.ended = false});

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  @override
  Widget build(BuildContext context) {
    if (widget.ended) {
      return Text('Đã kết thúc', style: widget.style);
    }
    final rem = widget.endsAt.difference(DateTime.now());
    final sec = rem.isNegative ? 0 : rem.inSeconds;
    final h = sec ~/ 3600, m = (sec % 3600) ~/ 60, s = sec % 60;
    final text = widget.short
        ? (h > 0 ? '${h}g ${m.toString().padLeft(2, '0')}p' : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}')
        : (h > 0
            ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
            : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}');
    return Text(text, style: widget.style);
  }
}

/// Nút lớn dễ chạm, dùng cho luồng vận hành (Kho vận).
class BigActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;
  const BigActionButton({super.key, required this.label, this.icon, this.background = AppColors.accent, this.foreground = Colors.white, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: const Color(0xFFD9D8D2),
          disabledForegroundColor: AppColors.muted,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
            Text(label),
          ],
        ),
      ),
    );
  }
}

/// Chip lọc dạng bo tròn, dùng cho các màn danh sách/hàng chờ.
class FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const FilterChipButton({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accent : Colors.white,
      shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.accent : AppColors.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: selected ? Colors.white : AppColors.ink)),
        ),
      ),
    );
  }
}

/// Toast nổi ở đầu màn hình — dùng cho phản hồi bị vượt giá / thắng phiên.
class TopToast extends StatelessWidget {
  final String title;
  final String body;
  final bool danger;
  final bool success;
  final VoidCallback onTap;
  final VoidCallback onClose;
  const TopToast({super.key, required this.title, required this.body, required this.danger, required this.success, required this.onTap, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final Color bg = danger ? AppColors.dangerStrong : (success ? AppColors.successStrong : AppColors.ink);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      elevation: 8,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(body, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3)),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                tooltip: 'Đóng thông báo',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kiểu ô nhập liệu dùng chung cho các form (đăng nhập, hồ sơ, tranh chấp…).
InputDecoration appInputDecoration(String? hint, {Widget? suffixIcon, String? errorText}) => InputDecoration(
      hintText: hint,
      errorText: errorText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCFCCC3))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCFCCC3))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
    );

/// Tiêu đề nhỏ phía trên ô nhập liệu.
class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      );
}

/// Thanh chọn vai trò cho mục đích trình diễn prototype — tương đương
/// thanh "DEMO" trên canvas thiết kế. Chuyển vai trò = đăng nhập nhanh vào
/// tài khoản mẫu đầu tiên của vai trò đó; nút thoát ở cuối để đăng xuất.
class RoleSwitcherBar extends StatelessWidget implements PreferredSizeWidget {
  final String current;
  final ValueChanged<String> onSelect;
  final VoidCallback onLogout;
  const RoleSwitcherBar({super.key, required this.current, required this.onSelect, required this.onLogout});

  static const roles = [
    ('bidder', 'Bidder'),
    ('seller', 'Seller'),
    ('appraiser', 'Thẩm định'),
    ('warehouse', 'Kho'),
    ('admin', 'Admin'),
  ];

  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: AppColors.ink,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Text('DEMO', style: TextStyle(color: Color(0xFFB7BCC6), fontSize: 11, letterSpacing: 0.5)),
          const Spacer(),
          ...roles.map((r) {
            final on = r.$1 == current;
            return Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Material(
                color: on ? AppColors.bg : Colors.transparent,
                borderRadius: BorderRadius.circular(13),
                child: InkWell(
                  borderRadius: BorderRadius.circular(13),
                  onTap: () => onSelect(r.$1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Text(r.$2, style: TextStyle(fontSize: 12, fontWeight: on ? FontWeight.w600 : FontWeight.w500, color: on ? AppColors.ink : const Color(0xFFDADDE3))),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onLogout,
            tooltip: 'Đăng xuất',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.logout, size: 18, color: Color(0xFFDADDE3)),
          ),
        ],
      ),
    );
  }
}
