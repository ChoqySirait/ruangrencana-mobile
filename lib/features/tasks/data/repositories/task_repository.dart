import '../models/assignment_item.dart';

/// Kontrak akses data tugas kuliah.
abstract class TaskRepository {
  List<AssignmentItem> getAllAssignments();
  List<AssignmentItem> getAssignmentsByCourse(String courseId);
  AssignmentItem? getAssignmentById(String id);
  void addAssignment(AssignmentItem item);
  void updateAssignment(AssignmentItem item);
  void toggleCompleted(String id);
}

/// Implementasi repositori tugas berbasis memori dengan data demonstrasi fiktif.
class InMemoryTaskRepository implements TaskRepository {
  InMemoryTaskRepository({DateTime? referenceTime}) {
    final now = referenceTime ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 23, 59);

    _assignments.addAll([
      AssignmentItem(
        id: 'tgs-1',
        title: 'Implementasi Navigasi & State Provider',
        courseId: 'mk-mob',
        courseName: 'Pemrograman Mobile',
        dueDate: today.add(const Duration(days: 1)),
        priority: AssignmentPriority.high,
        notes: 'Pastikan struktur MVVM bersih dan lolos flutter analyze.',
      ),
      AssignmentItem(
        id: 'tgs-2',
        title: 'Optimasi Query Indeks & Normalisasi BCNF',
        courseId: 'mk-bdl',
        courseName: 'Basis Data Lanjut',
        dueDate: today.subtract(const Duration(days: 1)),
        priority: AssignmentPriority.high,
        notes: 'Lampirkan hasil EXPLAIN QUERY PLAN sebelum dan sesudah indeks.',
      ),
      AssignmentItem(
        id: 'tgs-3',
        title: 'Review Dokumen SRS & Use Case Diagram',
        courseId: 'mk-rpl',
        courseName: 'Rekayasa Perangkat Lunak',
        dueDate: today.add(const Duration(days: 3)),
        priority: AssignmentPriority.medium,
        notes:
            'Fokus pada spesifikasi kebutuhan fungsional dan non-fungsional.',
      ),
      AssignmentItem(
        id: 'tgs-4',
        title: 'Simulasi Subnetting & Routing Statis',
        courseId: 'mk-jarkom',
        courseName: 'Jaringan Komputer',
        dueDate: today.add(const Duration(days: 5)),
        priority: AssignmentPriority.medium,
        notes: 'Kumpulkan berkas topologi dan tabel routing.',
      ),
      AssignmentItem(
        id: 'tgs-5',
        title: 'Laporan Evaluasi Heuristik Antarmuka',
        courseId: 'mk-imk',
        courseName: 'Interaksi Manusia dan Komputer',
        dueDate: today.subtract(const Duration(days: 3)),
        priority: AssignmentPriority.low,
        isCompleted: true,
        notes: 'Sudah dikumpulkan melalui portal akademik.',
      ),
      AssignmentItem(
        id: 'tgs-6',
        title: 'Analisis Distribusi Normal & Uji Hipotesis',
        courseId: 'mk-stat',
        courseName: 'Statistika dan Probabilitas',
        dueDate: today.add(const Duration(days: 7)),
        priority: AssignmentPriority.low,
        notes: 'Kerjakan soal nomor 1 sampai 5 dengan langkah perhitungan.',
      ),
    ]);
  }

  final List<AssignmentItem> _assignments = [];

  @override
  List<AssignmentItem> getAllAssignments() {
    final sorted = List<AssignmentItem>.from(_assignments)
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return List.unmodifiable(sorted);
  }

  @override
  List<AssignmentItem> getAssignmentsByCourse(String courseId) {
    return getAllAssignments()
        .where((item) => item.courseId == courseId)
        .toList(growable: false);
  }

  @override
  AssignmentItem? getAssignmentById(String id) {
    for (final item in _assignments) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  void addAssignment(AssignmentItem item) {
    _assignments.add(item);
  }

  @override
  void updateAssignment(AssignmentItem item) {
    final index = _assignments.indexWhere((existing) => existing.id == item.id);
    if (index != -1) {
      _assignments[index] = item;
    }
  }

  @override
  void toggleCompleted(String id) {
    final index = _assignments.indexWhere((existing) => existing.id == id);
    if (index != -1) {
      final current = _assignments[index];
      _assignments[index] = current.copyWith(isCompleted: !current.isCompleted);
    }
  }
}
