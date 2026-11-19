/// Tingkat prioritas tugas kuliah.
enum AssignmentPriority {
  low('Rendah'),
  medium('Sedang'),
  high('Tinggi');

  const AssignmentPriority(this.label);

  final String label;
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

/// Model data tugas akademik.
class AssignmentItem {
  const AssignmentItem({
    required this.id,
    required this.title,
    required this.courseId,
    required this.courseName,
    required this.dueDate,
    required this.priority,
    this.isCompleted = false,
    this.notes = '',
  });

  final String id;
  final String title;
  final String courseId;
  final String courseName;
  final DateTime dueDate;
  final AssignmentPriority priority;
  final bool isCompleted;
  final String notes;

  AssignmentStatus statusAt(DateTime reference) {
    if (isCompleted) return AssignmentStatus.completed;
    if (dueDate.isBefore(reference)) return AssignmentStatus.overdue;
    return AssignmentStatus.upcoming;
  }

  /// Menandai tugas sebagai mendesak jika belum selesai dan terlambat atau
  /// tenggatnya dalam 48 jam ke depan.
  bool isUrgentAt(DateTime reference) {
    if (isCompleted) return false;
    final hoursRemaining = dueDate.difference(reference).inHours;
    return hoursRemaining <= 48;
  }

  AssignmentItem copyWith({
    String? id,
    String? title,
    String? courseId,
    String? courseName,
    DateTime? dueDate,
    AssignmentPriority? priority,
    bool? isCompleted,
    String? notes,
  }) {
    return AssignmentItem(
      id: id ?? this.id,
      title: title ?? this.title,
      courseId: courseId ?? this.courseId,
      courseName: courseName ?? this.courseName,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      notes: notes ?? this.notes,
    );
  }
}
