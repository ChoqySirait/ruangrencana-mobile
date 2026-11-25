/// Tingkat prioritas tugas kuliah.
enum AssignmentPriority {
  low('Rendah'),
  medium('Sedang'),
  high('Tinggi');

  const AssignmentPriority(this.label);

  final String label;

  int get rank => switch (this) {
    AssignmentPriority.high => 3,
    AssignmentPriority.medium => 2,
    AssignmentPriority.low => 1,
  };
}

/// Status tugas yang digunakan untuk tampilan maupun filter.
enum AssignmentStatus {
  upcoming('Mendatang'),
  overdue('Terlambat'),
  completed('Selesai');

  const AssignmentStatus(this.label);

  final String label;
}

/// Filter daftar tugas pada halaman Tugas.
enum AssignmentFilter {
  all('Semua'),
  upcoming('Mendatang'),
  overdue('Terlambat'),
  completed('Selesai');

  const AssignmentFilter(this.label);

  final String label;
}

/// Opsi pengurutan daftar tugas kuliah.
enum AssignmentSort {
  dueSoonest('Tenggat Terdekat'),
  priorityHighest('Prioritas Tertinggi'),
  courseName('Nama Mata Kuliah'),
  newest('Tanggal Terbaru');

  const AssignmentSort(this.label);

  final String label;
}

/// Model data tugas akademik.
class AssignmentItem {
  const AssignmentItem({
    required this.id,
    required this.title,
    required this.courseId,
    required this.courseName,
    required this.dueDate,
    required this.priority,
    this.courseCode = '',
    this.isCompleted = false,
    this.notes = '',
    this.createdAt,
    this.updatedAt,
    this.completedAt,
  });

  final String id;
  final String title;
  final String courseId;
  final String courseName;
  final String courseCode;
  final DateTime dueDate;
  final AssignmentPriority priority;
  final bool isCompleted;
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  AssignmentStatus statusAt(DateTime reference) {
    if (isCompleted) {
      return AssignmentStatus.completed;
    }
    if (dueDate.toUtc().isBefore(reference.toUtc())) {
      return AssignmentStatus.overdue;
    }
    return AssignmentStatus.upcoming;
  }

  bool isOverdueAt(DateTime reference) {
    return !isCompleted && dueDate.toUtc().isBefore(reference.toUtc());
  }

  /// Menandai tugas sebagai mendesak jika belum selesai dan terlambat atau
  /// tenggatnya dalam 48 jam ke depan.
  bool isUrgentAt(DateTime reference) {
    if (isCompleted) {
      return false;
    }
    final hoursRemaining = dueDate
        .toUtc()
        .difference(reference.toUtc())
        .inHours;
    return hoursRemaining <= 48;
  }

  AssignmentStatus get status => statusAt(DateTime.now());
  bool get isOverdue => isOverdueAt(DateTime.now());
  bool get isUrgent => isUrgentAt(DateTime.now());

  /// Teks keterangan tenggat waktu relatif dalam bahasa Indonesia.
  String remainingTimeText([DateTime? referenceTime]) {
    final now = referenceTime ?? DateTime.now();
    if (isCompleted) return 'Selesai';

    final diff = dueDate.toUtc().difference(now.toUtc());
    if (diff.isNegative) {
      final daysPast = (-diff.inDays);
      if (daysPast > 0) {
        return 'Terlambat $daysPast hari';
      }
      final hoursPast = (-diff.inHours);
      if (hoursPast > 0) {
        return 'Terlambat $hoursPast jam';
      }
      return 'Terlambat baru saja';
    } else {
      if (diff.inDays > 1) {
        return '${diff.inDays} hari lagi';
      } else if (diff.inDays == 1) {
        return 'Besok';
      } else if (diff.inHours > 0) {
        return '${diff.inHours} jam lagi';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes} menit lagi';
      } else {
        return 'Segera';
      }
    }
  }

  AssignmentItem copyWith({
    String? id,
    String? title,
    String? courseId,
    String? courseName,
    String? courseCode,
    DateTime? dueDate,
    AssignmentPriority? priority,
    bool? isCompleted,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return AssignmentItem(
      id: id ?? this.id,
      title: title ?? this.title,
      courseId: courseId ?? this.courseId,
      courseName: courseName ?? this.courseName,
      courseCode: courseCode ?? this.courseCode,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
