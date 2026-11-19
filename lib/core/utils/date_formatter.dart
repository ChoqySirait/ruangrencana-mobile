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

  /// Format ringkas: "18 Nov 2026".
  static String shortDate(DateTime date) {
    final month = _shortMonths[(date.month - 1).clamp(0, 11)];
    return '${date.day} $month ${date.year}';
  }

  /// Format tanggal dengan waktu: "18 Nov, 23:59".
  static String shortDateWithTime(DateTime date) {
    final month = _shortMonths[(date.month - 1).clamp(0, 11)];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} $month, $hour:$minute';
  }

  /// Mengembalikan label relatif singkat terhadap [reference].
  static String relativeDeadlineLabel(DateTime dueDate, DateTime reference) {
    final diff = dueDate.difference(reference);
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
