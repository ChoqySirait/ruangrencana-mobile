import 'package:ruangrencana/core/database/app_database.dart';
import 'package:ruangrencana/core/database/database_schema.dart';
import 'package:ruangrencana/core/errors/app_failure.dart';

import '../models/schedule_item.dart';

/// Kontrak akses data jadwal kuliah mingguan.
abstract class ScheduleRepository {
  List<ScheduleItem> getAllSchedules();
  List<ScheduleItem> getSchedulesForDay(int dayOfWeek);
  List<ScheduleItem> getSchedulesForCourse(String courseId);
  Future<List<ScheduleItem>> findConflictingSchedules({
    required int weekday,
    required String startTime,
    required String endTime,
    int? excludeScheduleId,
    int? courseId,
  });
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
        .where((item) => item.isActiveTerm && item.dayOfWeek == dayOfWeek)
        .toList(growable: false);
  }

  @override
  List<ScheduleItem> getSchedulesForCourse(String courseId) {
    return _cachedSchedules
        .where((item) => item.courseId == courseId)
        .toList(growable: false);
  }

  @override
  Future<void> load() async {
    final db = await appDatabase.database;

    // Join class_schedules dengan courses
    final rows = await db.rawQuery('''
      SELECT s.id, s.course_id, s.weekday, s.start_time, s.end_time, s.classroom,
             c.course_code, c.course_name, c.credits, c.lecturer_name, t.is_active
      FROM ${DatabaseSchema.tableClassSchedules} s
      INNER JOIN ${DatabaseSchema.tableCourses} c ON c.id = s.course_id
      INNER JOIN ${DatabaseSchema.tableAcademicTerms} t ON t.id = c.academic_term_id
      WHERE c.archived_at IS NULL
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
            isActiveTerm: (r['is_active'] as int) == 1,
          );
        })
        .toList(growable: false);

    _cachedSchedules
      ..clear()
      ..addAll(loaded);
  }

  @override
  Future<List<ScheduleItem>> findConflictingSchedules({
    required int weekday,
    required String startTime,
    required String endTime,
    int? excludeScheduleId,
    int? courseId,
  }) async {
    final targetStart = _timeToMinutes(startTime);
    final targetEnd = _timeToMinutes(endTime);

    final db = await appDatabase.database;

    int? termId;
    if (courseId != null) {
      final cRow = await db.query(
        DatabaseSchema.tableCourses,
        columns: ['academic_term_id'],
        where: 'id = ?',
        whereArgs: [courseId],
      );
      if (cRow.isNotEmpty) {
        termId = cRow.first['academic_term_id'] as int?;
      }
    }

    final String termCondition;
    final List<Object?> queryArgs;

    if (termId != null) {
      termCondition = 'c.academic_term_id = ?';
      queryArgs = [termId, weekday];
    } else {
      termCondition = 't.is_active = 1';
      queryArgs = [weekday];
    }

    final rows = await db.rawQuery('''
      SELECT s.id, s.course_id, s.weekday, s.start_time, s.end_time, s.classroom,
             c.course_code, c.course_name, c.credits, c.lecturer_name
      FROM ${DatabaseSchema.tableClassSchedules} s
      INNER JOIN ${DatabaseSchema.tableCourses} c ON c.id = s.course_id
      INNER JOIN ${DatabaseSchema.tableAcademicTerms} t ON t.id = c.academic_term_id
      WHERE $termCondition AND c.archived_at IS NULL AND s.weekday = ?
      ORDER BY s.start_time ASC
      ''', queryArgs);

    final conflicts = <ScheduleItem>[];

    for (final r in rows) {
      final sId = r['id'] as int;
      if (excludeScheduleId != null && sId == excludeScheduleId) continue;

      final sStart = _timeToMinutes(r['start_time'] as String);
      final sEnd = _timeToMinutes(r['end_time'] as String);

      if (_intervalsOverlap(targetStart, targetEnd, sStart, sEnd)) {
        conflicts.add(
          ScheduleItem(
            id: sId.toString(),
            courseId: r['course_id'].toString(),
            courseCode: r['course_code'] as String,
            courseName: r['course_name'] as String,
            dayOfWeek: r['weekday'] as int,
            startTime: r['start_time'] as String,
            endTime: r['end_time'] as String,
            room: (r['classroom'] as String?) ?? 'Ruang Kelas',
            sks: r['credits'] as int,
            lecturer: (r['lecturer_name'] as String?) ?? '',
          ),
        );
      }
    }

    return conflicts;
  }

  @override
  Future<int> addSchedule({
    required int courseId,
    required int weekday,
    required String startTime,
    required String endTime,
    required String classroom,
  }) async {
    _validateScheduleInput(
      weekday: weekday,
      startTime: startTime,
      endTime: endTime,
    );

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
    _validateScheduleInput(
      weekday: weekday,
      startTime: startTime,
      endTime: endTime,
    );

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

  void _validateScheduleInput({
    required int weekday,
    required String startTime,
    required String endTime,
  }) {
    if (weekday < 1 || weekday > 7) {
      throw AppFailure(
        'Hari perkuliahan tidak valid (harus 1 sampai 7).',
        code: 'INVALID_WEEKDAY',
      );
    }
    final startMin = _timeToMinutes(startTime);
    final endMin = _timeToMinutes(endTime);

    if (startMin >= endMin) {
      throw AppFailure(
        'Jam selesai perkuliahan harus lebih lambat dari jam mulai.',
        code: 'INVALID_TIME_RANGE',
      );
    }
  }

  static int _timeToMinutes(String time) {
    final parts = time.trim().split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  static bool _intervalsOverlap(int startA, int endA, int startB, int endB) {
    return startA < endB && startB < endA;
  }
}

/// Implementasi in-memory untuk fallback atau pengetesan terisolasi.
class InMemoryScheduleRepository implements ScheduleRepository {
  final List<ScheduleItem> _schedules = [];

  @override
  List<ScheduleItem> getAllSchedules() => List.unmodifiable(_schedules);

  @override
  List<ScheduleItem> getSchedulesForDay(int dayOfWeek) {
    return _schedules.where((item) => item.dayOfWeek == dayOfWeek).toList();
  }

  @override
  List<ScheduleItem> getSchedulesForCourse(String courseId) {
    return _schedules.where((item) => item.courseId == courseId).toList();
  }

  @override
  Future<List<ScheduleItem>> findConflictingSchedules({
    required int weekday,
    required String startTime,
    required String endTime,
    int? excludeScheduleId,
    int? courseId,
  }) async {
    final startMin = _timeToMinutes(startTime);
    final endMin = _timeToMinutes(endTime);

    return _schedules.where((s) {
      if (s.dayOfWeek != weekday) return false;
      if (excludeScheduleId != null &&
          int.tryParse(s.id) == excludeScheduleId) {
        return false;
      }
      final sStart = _timeToMinutes(s.startTime);
      final sEnd = _timeToMinutes(s.endTime);
      return startMin < sEnd && sStart < endMin;
    }).toList();
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
  }) async {
    final startMin = _timeToMinutes(startTime);
    final endMin = _timeToMinutes(endTime);
    if (startMin >= endMin) {
      throw AppFailure(
        'Jam selesai perkuliahan harus lebih lambat dari jam mulai.',
        code: 'INVALID_TIME_RANGE',
      );
    }
    final newId = _schedules.length + 1;
    _schedules.add(
      ScheduleItem(
        id: newId.toString(),
        courseId: courseId.toString(),
        courseCode: 'TEST',
        courseName: 'Mata Kuliah Test',
        dayOfWeek: weekday,
        startTime: startTime,
        endTime: endTime,
        room: classroom,
        sks: 3,
        lecturer: 'Dosen Test',
      ),
    );
    return newId;
  }

  @override
  Future<void> updateSchedule({
    required int scheduleId,
    required int weekday,
    required String startTime,
    required String endTime,
    required String classroom,
  }) async {
    final index = _schedules.indexWhere((s) => s.id == scheduleId.toString());
    if (index != -1) {
      final s = _schedules[index];
      _schedules[index] = ScheduleItem(
        id: s.id,
        courseId: s.courseId,
        courseCode: s.courseCode,
        courseName: s.courseName,
        dayOfWeek: weekday,
        startTime: startTime,
        endTime: endTime,
        room: classroom,
        sks: s.sks,
        lecturer: s.lecturer,
      );
    }
  }

  @override
  Future<void> deleteSchedule(int scheduleId) async {
    _schedules.removeWhere((s) => s.id == scheduleId.toString());
  }

  static int _timeToMinutes(String time) {
    final parts = time.trim().split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }
}
