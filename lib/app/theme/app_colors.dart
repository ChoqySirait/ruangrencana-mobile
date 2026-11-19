import 'package:material_ui/material_ui.dart';

/// Token warna terpusat untuk aplikasi RuangRencana (Mode Terang).
///
/// Mengacu pada arah desain RuangRencana berbasis Material Design 3.
abstract final class AppColors {
  // Warna utama merek
  static const Color primaryNavy = Color(0xFF17324D);
  static const Color secondaryTeal = Color(0xFF2D8C83);

  // Permukaan dan latar belakang
  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF0F3F7);
  static const Color border = Color(0xFFE4E7EC);

  // Teks
  static const Color textPrimary = Color(0xFF1B2530);
  static const Color textSecondary = Color(0xFF667085);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Status semantik
  static const Color warning = Color(0xFFD99A35);
  static const Color error = Color(0xFFC65A56);
  static const Color success = Color(0xFF2D8C83);

  // Latar lembut untuk badge dan penanda status
  static const Color primarySoft = Color(0xFFE8EEF4);
  static const Color secondarySoft = Color(0xFFE6F4F2);
  static const Color warningSoft = Color(0xFFFCF4E6);
  static const Color errorSoft = Color(0xFFFAECEB);
}
