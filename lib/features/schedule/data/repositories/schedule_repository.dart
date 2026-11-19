import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_schema.dart';
import '../models/schedule_item.dart';

/// Kontrak akses data jadwal kuliah mingguan.
abstract class ScheduleRepository {
  List<ScheduleItem> getAllSchedules();
  List<ScheduleItem> getSchedulesForDay(int dayOfWeek);
  Future<void> load();

  // Operasi CRUD
  Future<int> addSchedule({
    required int courseId,
    required int weekday,
    required String startTime,
    required String endTime,
    required String classroom,
  });

  Future<void> updateSchedule({
    required int scheduleId,
    required int weekday,
    required String startTime,
    required String endTime,
    required String classroom,
  });

  Future<void> deleteSchedule(int scheduleId);
}

/// Implementasi repositori jadwal kuliah berbasis SQLite (`sqflite`).
class SqliteScheduleRepository implements ScheduleRepository {
  SqliteScheduleRepository({required this.appDatabase});

  final AppDatabase appDatabase;
  final List<ScheduleItem> _cachedSchedules = [];

  @override
  List<ScheduleItem> getAllSchedules() => List.unmodifiable(_cachedSchedules);

  @override
  List<ScheduleItem> getSchedulesForDay(int dayOfWeek) {
    return _cachedSchedules
        .where((item) => item.dayOfWeek == dayOfWeek)
        .toList(growable: false);
  }

  @override
  Future<void> load() async {
    final db = await appDatabase.database;

    // Join class_schedules dengan courses pada semester aktif
    final rows = await db.rawQuery('''
      SELECT s.id, s.course_id, s.weekday, s.start_time, s.end_time, s.classroom,
             c.course_code, c.course_name, c.credits, c.lecturer_name
      FROM ${DatabaseSchema.tableClassSchedules} s
      INNER JOIN ${DatabaseSchema.tableCourses} c ON c.id = s.course_id
      INNER JOIN ${DatabaseSchema.tableAcademicTerms} t ON t.id = c.academic_term_id
      WHERE t.is_active = 1 AND c.archived_at IS NULL
      ORDER BY s.weekday ASC, s.start_time ASC
    ''');

    final loaded = rows
        .map((r) {
          return ScheduleItem(
            id: r['id'].toString(),
            courseId: r['course_id'].toString(),
            courseCode: r['course_code'] as String,
            courseName: r['course_name'] as String,
            dayOfWeek: r['weekday'] as int,
            startTime: r['start_time'] as String,
            endTime: r['end_time'] as String,
            room: (r['classroom'] as String?) ?? 'Ruang Kelas',
            sks: r['credits'] as int,
            lecturer: (r['lecturer_name'] as String?) ?? '',
          );
        })
        .toList(growable: false);

    _cachedSchedules
      ..clear()
      ..addAll(loaded);
  }

  @override
  Future<int> addSchedule({
    required int courseId,
    required int weekday,
    required String startTime,
    required String endTime,
    required String classroom,
  }) async {
    final db = await appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();

    final id = await db.insert(DatabaseSchema.tableClassSchedules, {
      'course_id': courseId,
      'weekday': weekday,
      'start_time': startTime.trim(),
      'end_time': endTime.trim(),
      'classroom': classroom.trim(),
      'created_at': now,
      'updated_at': now,
    });

    await load();
    return id;
  }

  @override
  Future<void> updateSchedule({
    required int scheduleId,
    required int weekday,
    required String startTime,
    required String endTime,
    required String classroom,
  }) async {
    final db = await appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.update(
      DatabaseSchema.tableClassSchedules,
      {
        'weekday': weekday,
        'start_time': startTime.trim(),
        'end_time': endTime.trim(),
        'classroom': classroom.trim(),
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [scheduleId],
    );

    await load();
  }

  @override
  Future<void> deleteSchedule(int scheduleId) async {
    final db = await appDatabase.database;
    await db.delete(
      DatabaseSchema.tableClassSchedules,
      where: 'id = ?',
      whereArgs: [scheduleId],
    );

    await load();
  }
}

/// Implementasi in-memory untuk fallback atau pengetesan.
class InMemoryScheduleRepository implements ScheduleRepository {
  final List<ScheduleItem> _schedules = [];

  @override
  List<ScheduleItem> getAllSchedules() => List.unmodifiable(_schedules);

  @override
  List<ScheduleItem> getSchedulesForDay(int dayOfWeek) {
    return _schedules.where((item) => item.dayOfWeek == dayOfWeek).toList();
  }

  @override
  Future<void> load() async {}

  @override
  Future<int> addSchedule({
    required int courseId,
    required int weekday,
    required String startTime,
    required String endTime,
    required String classroom,
  }) async => 1;

  @override
  Future<void> updateSchedule({
    required int scheduleId,
    required int weekday,
    required String startTime,
    required String endTime,
    required String classroom,
  }) async {}

  @override
  Future<void> deleteSchedule(int scheduleId) async {}
}
