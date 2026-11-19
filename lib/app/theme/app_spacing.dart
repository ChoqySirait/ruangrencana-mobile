/// Sistem jarak berbasis kelipatan 8 poin (8-point spacing system)
/// serta token radius sudut untuk menjaga konsistensi tata letak.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;

  // Padding halaman standar
  static const double pageHorizontal = md;
  static const double pageVertical = md;

  // Radius sudut moderat
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusPill = 999;
}
