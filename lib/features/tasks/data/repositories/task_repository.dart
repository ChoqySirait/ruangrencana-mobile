import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_schema.dart';
import '../models/assignment_item.dart';

/// Kontrak akses data tugas kuliah.
abstract class TaskRepository {
  List<AssignmentItem> getAllAssignments();
  List<AssignmentItem> getAssignmentsByCourse(String courseId);
  AssignmentItem? getAssignmentById(String id);
  Future<void> load();

  // Operasi CRUD
  Future<void> addAssignment(AssignmentItem item);
  Future<void> updateAssignment(AssignmentItem item);
  Future<void> toggleCompleted(String id);
  Future<void> markCompleted(String id);
  Future<void> reopenAssignment(String id);
  Future<void> deleteAssignment(String id);
}

/// Implementasi repositori tugas kuliah berbasis SQLite (`sqflite`).
class SqliteTaskRepository implements TaskRepository {
  SqliteTaskRepository({required this.appDatabase});

  final AppDatabase appDatabase;
  final List<AssignmentItem> _cachedAssignments = [];

  @override
  List<AssignmentItem> getAllAssignments() {
    final sorted = List<AssignmentItem>.from(_cachedAssignments)
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
    for (final item in _cachedAssignments) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<void> load() async {
    final db = await appDatabase.database;

    final rows = await db.rawQuery('''
      SELECT a.id, a.course_id, a.title, a.description, a.due_at, a.priority,
             a.status, a.completed_at, a.created_at, a.updated_at, c.course_name, c.course_code
      FROM ${DatabaseSchema.tableAssignments} a
      INNER JOIN ${DatabaseSchema.tableCourses} c ON c.id = a.course_id
      ORDER BY a.due_at ASC
    ''');

    final loaded = rows
        .map((r) {
          final statusStr = r['status'] as String;
          final isCompleted = statusStr == 'completed';
          final priorityStr = r['priority'] as String;

          final priority = switch (priorityStr) {
            'high' => AssignmentPriority.high,
            'medium' => AssignmentPriority.medium,
            _ => AssignmentPriority.low,
          };

          DateTime? completedAt;
          if (r['completed_at'] != null) {
            completedAt = DateTime.tryParse(r['completed_at'] as String)
                ?.toLocal();
          }

          DateTime? createdAt;
          if (r['created_at'] != null) {
            createdAt = DateTime.tryParse(r['created_at'] as String)?.toLocal();
          }

          DateTime? updatedAt;
          if (r['updated_at'] != null) {
            updatedAt = DateTime.tryParse(r['updated_at'] as String)?.toLocal();
          }

          return AssignmentItem(
            id: r['id'].toString(),
            title: r['title'] as String,
            courseId: r['course_id'].toString(),
            courseName: r['course_name'] as String,
            courseCode: (r['course_code'] as String?) ?? '',
            dueDate: DateTime.parse(r['due_at'] as String).toLocal(),
            priority: priority,
            isCompleted: isCompleted,
            notes: (r['description'] as String?) ?? '',
            createdAt: createdAt,
            updatedAt: updatedAt,
            completedAt: completedAt,
          );
        })
        .toList(growable: false);

    _cachedAssignments
      ..clear()
      ..addAll(loaded);
  }

  @override
  Future<void> addAssignment(AssignmentItem item) async {
    final db = await appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();

    // Resolusi courseId ke INTEGER
    var cId = int.tryParse(item.courseId);
    if (cId == null) {
      final match = await db.query(
        DatabaseSchema.tableCourses,
        columns: ['id'],
        where: 'course_code = ? OR course_name = ?',
        whereArgs: [item.courseId, item.courseName],
        limit: 1,
      );
      if (match.isNotEmpty) {
        cId = match.first['id'] as int;
      } else {
        final first = await db.query(DatabaseSchema.tableCourses, limit: 1);
        cId = first.isNotEmpty ? first.first['id'] as int : 1;
      }
    }

    final priorityStr = switch (item.priority) {
      AssignmentPriority.high => 'high',
      AssignmentPriority.medium => 'medium',
      AssignmentPriority.low => 'low',
    };

    final statusStr = item.isCompleted ? 'completed' : 'upcoming';

    await db.insert(DatabaseSchema.tableAssignments, {
      'course_id': cId,
      'title': item.title.trim(),
      'description': item.notes.trim(),
      'due_at': item.dueDate.toUtc().toIso8601String(),
      'priority': priorityStr,
      'status': statusStr,
      'completed_at': item.isCompleted
          ? (item.completedAt?.toUtc().toIso8601String() ?? now)
          : null,
      'created_at': item.createdAt?.toUtc().toIso8601String() ?? now,
      'updated_at': now,
    });

    await load();
  }

  @override
  Future<void> updateAssignment(AssignmentItem item) async {
    final db = await appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final numericId = int.tryParse(item.id);

    final priorityStr = switch (item.priority) {
      AssignmentPriority.high => 'high',
      AssignmentPriority.medium => 'medium',
      AssignmentPriority.low => 'low',
    };

    final statusStr = item.isCompleted ? 'completed' : 'upcoming';

    final updateValues = <String, Object?>{
      'title': item.title.trim(),
      'description': item.notes.trim(),
      'due_at': item.dueDate.toUtc().toIso8601String(),
      'priority': priorityStr,
      'status': statusStr,
      'completed_at': item.isCompleted
          ? (item.completedAt?.toUtc().toIso8601String() ?? now)
          : null,
      'updated_at': now,
    };

    // Update course_id jika valid
    final cId = int.tryParse(item.courseId);
    if (cId != null) {
      updateValues['course_id'] = cId;
    }

    await db.update(
      DatabaseSchema.tableAssignments,
      updateValues,
      where: 'id = ?',
      whereArgs: [numericId ?? item.id],
    );

    await load();
  }

  @override
  Future<void> toggleCompleted(String id) async {
    final item = getAssignmentById(id);
    if (item == null) return;

    final nextCompleted = !item.isCompleted;
    final updated = item.copyWith(
      isCompleted: nextCompleted,
      completedAt: nextCompleted ? DateTime.now() : null,
    );
    await updateAssignment(updated);
  }

  @override
  Future<void> markCompleted(String id) async {
    final item = getAssignmentById(id);
    if (item == null || item.isCompleted) return;

    final updated = item.copyWith(
      isCompleted: true,
      completedAt: DateTime.now(),
    );
    await updateAssignment(updated);
  }

  @override
  Future<void> reopenAssignment(String id) async {
    final item = getAssignmentById(id);
    if (item == null || !item.isCompleted) return;

    final updated = item.copyWith(isCompleted: false, completedAt: null);
    await updateAssignment(updated);
  }

  @override
  Future<void> deleteAssignment(String id) async {
    final db = await appDatabase.database;
    final numericId = int.tryParse(id);

    await db.delete(
      DatabaseSchema.tableAssignments,
      where: 'id = ?',
      whereArgs: [numericId ?? id],
    );

    await load();
  }
}

/// Implementasi in-memory untuk testing atau fallback.
class InMemoryTaskRepository implements TaskRepository {
  final List<AssignmentItem> _assignments = [];

  @override
  List<AssignmentItem> getAllAssignments() {
    final sorted = List<AssignmentItem>.from(_assignments)
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return List.unmodifiable(sorted);
  }

  @override
  List<AssignmentItem> getAssignmentsByCourse(String courseId) {
    return getAllAssignments().where((i) => i.courseId == courseId).toList();
  }

  @override
  AssignmentItem? getAssignmentById(String id) {
    for (final i in _assignments) {
      if (i.id == id) return i;
    }
    return null;
  }

  @override
  Future<void> load() async {}

  @override
  Future<void> addAssignment(AssignmentItem item) async {
    _assignments.add(item);
  }

  @override
  Future<void> updateAssignment(AssignmentItem item) async {
    final index = _assignments.indexWhere((i) => i.id == item.id);
    if (index != -1) _assignments[index] = item;
  }

  @override
  Future<void> toggleCompleted(String id) async {
    final item = getAssignmentById(id);
    if (item == null) return;
    final nextCompleted = !item.isCompleted;
    final updated = item.copyWith(
      isCompleted: nextCompleted,
      completedAt: nextCompleted ? DateTime.now() : null,
    );
    await updateAssignment(updated);
  }

  @override
  Future<void> markCompleted(String id) async {
    final item = getAssignmentById(id);
    if (item == null || item.isCompleted) return;
    final updated = item.copyWith(
      isCompleted: true,
      completedAt: DateTime.now(),
    );
    await updateAssignment(updated);
  }

  @override
  Future<void> reopenAssignment(String id) async {
    final item = getAssignmentById(id);
    if (item == null || !item.isCompleted) return;
    final updated = item.copyWith(isCompleted: false, completedAt: null);
    await updateAssignment(updated);
  }

  @override
  Future<void> deleteAssignment(String id) async {
    _assignments.removeWhere((i) => i.id == id);
  }
}
