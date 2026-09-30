import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bảng màu và kiểu chữ dùng chung cho toàn bộ app, khớp với prototype
/// thiết kế trên canvas BidVibe. Trạng thái dùng cùng một tông màu xuyên
/// suốt các vai trò: vàng = chờ xử lý, xanh dương = đang xử lý,
/// xanh lá = hoàn thành/khớp, đỏ = sai lệch/từ chối/tranh chấp,
/// xám = trung tính.
class AppColors {
  AppColors._();

  static const bg = Color(0xFFF5F4F0);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF15171C);
  static const border = Color(0xFFE4E2DC);
  static const muted = Color(0xFF5B616B);
  static const mutedStrong = Color(0xFF3A3F48);

  static const accent = Color(0xFF1A2B4C);

  // Trạng thái — nhất quán cho mọi vai trò
  static const pendingBg = Color(0xFFFFF1D6);
  static const pendingFg = Color(0xFF7A4B00);
  static const progressBg = Color(0xFFE7ECF7);
  static const progressFg = Color(0xFF1A2B4C);
  static const successBg = Color(0xFFE4F2EB);
  static const successFg = Color(0xFF0B5A3B);
  static const successStrong = Color(0xFF0E6B47);
  static const dangerBg = Color(0xFFFBE9E7);
  static const dangerFg = Color(0xFF8C1C15);
  static const dangerStrong = Color(0xFFB3261E);
  static const neutralBg = Color(0xFFEFEDE8);
  static const neutralFg = Color(0xFF3B4658);

  // Ô màu minh hoạ ảnh sản phẩm theo danh mục
  static const tileShoes = Color(0xFFE4E9F2);
  static const tileElec = Color(0xFFE5EAE6);
  static const tileAntique = Color(0xFFEEE6D9);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      primary: AppColors.accent,
      surface: AppColors.surface,
      brightness: Brightness.light,
    ),
  );
  final textTheme = GoogleFonts.beVietnamProTextTheme(base.textTheme).apply(
    bodyColor: AppColors.ink,
    displayColor: AppColors.ink,
  );
  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
  );
}

/// Nhãn trạng thái dạng pill, dùng cùng bộ màu cho mọi vai trò.
enum StatusTone { pending, progress, success, danger, neutral }

class StatusPill extends StatelessWidget {
  final String label;
  final StatusTone tone;
  const StatusPill({super.key, required this.label, required this.tone});

  (Color, Color) _colors() {
    switch (tone) {
      case StatusTone.pending:
        return (AppColors.pendingBg, AppColors.pendingFg);
      case StatusTone.progress:
        return (AppColors.progressBg, AppColors.progressFg);
      case StatusTone.success:
        return (AppColors.successBg, AppColors.successFg);
      case StatusTone.danger:
        return (AppColors.dangerBg, AppColors.dangerFg);
      case StatusTone.neutral:
        return (AppColors.neutralBg, AppColors.neutralFg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

Color categoryTileColor(String cat) {
  switch (cat) {
    case 'shoes':
      return AppColors.tileShoes;
    case 'elec':
      return AppColors.tileElec;
    case 'antique':
      return AppColors.tileAntique;
    default:
      return AppColors.neutralBg;
  }
}

IconData categoryIcon(String cat) {
  switch (cat) {
    case 'shoes':
      return Icons.sports_baseball_outlined; // placeholder, overridden per-screen where custom icon used
    case 'elec':
      return Icons.memory_outlined;
    case 'antique':
      return Icons.liquor_outlined;
    default:
      return Icons.category_outlined;
  }
}

String labelForCategory(String cat) {
  switch (cat) {
    case 'shoes':
      return 'Giày';
    case 'elec':
      return 'Điện tử';
    case 'antique':
      return 'Đồ cổ';
    default:
      return 'Khác';
  }
}
