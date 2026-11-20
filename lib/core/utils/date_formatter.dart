/// Utilitas pemformatan tanggal dan hari dalam Bahasa Indonesia
/// tanpa memerlukan dependensi tambahan pada tahap inisialisasi.
abstract final class DateFormatter {
  static const List<String> _shortDays = [
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ];

  static const List<String> _fullDays = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  static const List<String> _shortMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  /// Mengembalikan nama hari lengkap untuk weekday 1 (Senin) sampai 7 (Minggu).
  static String fullDayName(int weekday) {
    final index = (weekday - 1).clamp(0, 6);
    return _fullDays[index];
  }

  /// Mengembalikan singkatan hari untuk weekday 1 (Sen) sampai 7 (Min).
  static String shortDayName(int weekday) {
    final index = (weekday - 1).clamp(0, 6);
    return _shortDays[index];
  }

  /// Format ringkas: "18 Nov 2026" dalam zona waktu lokal pengguna.
  static String shortDate(DateTime date) {
    final local = date.toLocal();
    final month = _shortMonths[(local.month - 1).clamp(0, 11)];
    return '${local.day} $month ${local.year}';
  }

  /// Format tanggal dengan waktu: "18 Nov, 23:59" dalam zona waktu lokal pengguna.
  static String shortDateWithTime(DateTime date) {
    final local = date.toLocal();
    final month = _shortMonths[(local.month - 1).clamp(0, 11)];
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} $month, $hour:$minute';
  }

  /// Mengembalikan label relatif singkat terhadap [reference] dengan konsistensi waktu UTC.
  static String relativeDeadlineLabel(DateTime dueDate, DateTime reference) {
    final diff = dueDate.toUtc().difference(reference.toUtc());
    if (diff.isNegative) {
      final overdueDays = diff.inDays.abs();
      if (overdueDays == 0) {
        return 'Lewat tenggat hari ini';
      }
      return 'Terlambat $overdueDays hari';
    }
    if (diff.inHours < 24) {
      return 'Tenggat kurang dari 24 jam';
    }
    if (diff.inDays == 1) {
      return 'Besok';
    }
    return '${diff.inDays} hari lagi';
  }
}
