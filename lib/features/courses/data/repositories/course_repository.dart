import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_schema.dart';
import '../../../../core/utils/academic_calculator.dart';
import '../../../../core/utils/date_formatter.dart';
import '../models/course_item.dart';

/// Kontrak akses dan manipulasi data mata kuliah beserta komponen penilaiannya.
abstract class CourseRepository {
  List<CourseItem> getActiveCourses();
  CourseItem? getCourseById(String id);
  Future<void> load();

  // Operasi CRUD
  Future<int> insertCourse({
    required int termId,
    required String code,
    required String name,
    required int credits,
    required String lecturer,
  });

  Future<void> updateCourse({
    required String id,
    required String code,
    required String name,
    required int credits,
    required String lecturer,
  });

  Future<void> archiveCourse(String id);
  Future<void> deleteCourse(String id);

  Future<int> addAssessmentComponent({
    required String courseId,
    required String name,
    required double weightPercent,
    bool isRequired = true,
    int sortOrder = 0,
    double? initialScore,
  });

  Future<void> recordAssessmentScore({
    required int componentId,
    required double score,
    String notes = '',
  });

  Future<void> deleteAssessmentComponent(int componentId);
}

/// Implementasi persistensi mata kuliah berbasis SQLite (`sqflite`).
class SqliteCourseRepository implements CourseRepository {
  SqliteCourseRepository({required this.appDatabase});

  final AppDatabase appDatabase;
  final List<CourseItem> _cachedCourses = [];

  @override
  List<CourseItem> getActiveCourses() => List.unmodifiable(_cachedCourses);

  @override
  CourseItem? getCourseById(String id) {
    for (final c in _cachedCourses) {
      if (c.id == id || c.code == id) return c;
    }
    return null;
  }

  @override
  Future<void> load() async {
    final db = await appDatabase.database;

    // 1. Ambil semester aktif
    final activeTerms = await db.query(
      DatabaseSchema.tableAcademicTerms,
      where: 'is_active = 1',
      limit: 1,
    );

    if (activeTerms.isEmpty) {
      _cachedCourses.clear();
      return;
    }

    final termId = activeTerms.first['id'] as int;

    // 2. Ambil mata kuliah pada semester aktif yang tidak diarsipkan
    final courseRows = await db.query(
      DatabaseSchema.tableCourses,
      where: 'academic_term_id = ? AND archived_at IS NULL',
      whereArgs: [termId],
      orderBy: 'course_code ASC',
    );

    final loaded = <CourseItem>[];

    for (final row in courseRows) {
      final courseId = row['id'] as int;

      // Ambil jadwal kuliah untuk mendapatkan informasi ruangan dan label jadwal
      final schedRows = await db.query(
        DatabaseSchema.tableClassSchedules,
        where: 'course_id = ?',
        whereArgs: [courseId],
        orderBy: 'weekday ASC, start_time ASC',
      );

      String room = 'Ruang Kelas';
      String scheduleLabel = 'Jadwal belum ditentukan';

      if (schedRows.isNotEmpty) {
        final first = schedRows.first;
        final weekday = first['weekday'] as int;
        final start = first['start_time'] as String;
        final end = first['end_time'] as String;
        room = (first['classroom'] as String?) ?? room;
        scheduleLabel = '${DateFormatter.fullDayName(weekday)}, $start - $end';
      }

      // Ambil komponen penilaian dan skornya
      final compRows = await db.rawQuery(
        '''
        SELECT c.id as comp_id, c.component_name, c.weight_percentage, c.is_required, s.score
        FROM ${DatabaseSchema.tableAssessmentComponents} c
        LEFT JOIN ${DatabaseSchema.tableAssessmentScores} s
          ON s.assessment_component_id = c.id
        WHERE c.course_id = ?
        ORDER BY c.sort_order ASC, c.id ASC
        ''',
        [courseId],
      );

      final components = compRows
          .map((c) {
            final scoreVal = c['score'];
            return AssessmentComponentInput(
              name: c['component_name'] as String,
              weightPercent: (c['weight_percentage'] as num).toDouble(),
              isMandatory: (c['is_required'] as int) == 1,
              score: scoreVal != null ? (scoreVal as num).toDouble() : null,
            );
          })
          .toList(growable: false);

      loaded.add(
        CourseItem(
          id: courseId.toString(),
          code: row['course_code'] as String,
          name: row['course_name'] as String,
          sks: row['credits'] as int,
          lecturer: (row['lecturer_name'] as String?) ?? '',
          room: room,
          scheduleLabel: scheduleLabel,
          assessmentComponents: components,
        ),
      );
    }

    _cachedCourses
      ..clear()
      ..addAll(loaded);
  }

  @override
  Future<int> insertCourse({
    required int termId,
    required String code,
    required String name,
    required int credits,
    required String lecturer,
  }) async {
    final db = await appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();

    final id = await db.insert(DatabaseSchema.tableCourses, {
      'academic_term_id': termId,
      'course_code': code.trim(),
      'course_name': name.trim(),
      'credits': credits,
      'lecturer_name': lecturer.trim(),
      'created_at': now,
      'updated_at': now,
    });

    await load();
    return id;
  }

  @override
  Future<void> updateCourse({
    required String id,
    required String code,
    required String name,
    required int credits,
    required String lecturer,
  }) async {
    final db = await appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.update(
      DatabaseSchema.tableCourses,
      {
        'course_code': code.trim(),
        'course_name': name.trim(),
        'credits': credits,
        'lecturer_name': lecturer.trim(),
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [int.tryParse(id) ?? id],
    );

    await load();
  }

  @override
  Future<void> archiveCourse(String id) async {
    final db = await appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.update(
      DatabaseSchema.tableCourses,
      {'archived_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [int.tryParse(id) ?? id],
    );

    await load();
  }

  @override
  Future<void> deleteCourse(String id) async {
    final db = await appDatabase.database;
    await db.delete(
      DatabaseSchema.tableCourses,
      where: 'id = ?',
      whereArgs: [int.tryParse(id) ?? id],
    );

    await load();
  }

  @override
  Future<int> addAssessmentComponent({
    required String courseId,
    required String name,
    required double weightPercent,
    bool isRequired = true,
    int sortOrder = 0,
    double? initialScore,
  }) async {
    final db = await appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final cId = int.parse(courseId);

    final compId = await db.transaction((txn) async {
      final id = await txn.insert(DatabaseSchema.tableAssessmentComponents, {
        'course_id': cId,
        'component_name': name.trim(),
        'weight_percentage': weightPercent,
        'is_required': isRequired ? 1 : 0,
        'sort_order': sortOrder,
        'created_at': now,
        'updated_at': now,
      });

      if (initialScore != null) {
        await txn.insert(DatabaseSchema.tableAssessmentScores, {
          'assessment_component_id': id,
          'score': initialScore,
          'graded_at': now,
          'notes': '',
        });
      }

      return id;
    });

    await load();
    return compId;
  }

  @override
  Future<void> recordAssessmentScore({
    required int componentId,
    required double score,
    String notes = '',
  }) async {
    final db = await appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      final existing = await txn.query(
        DatabaseSchema.tableAssessmentScores,
        where: 'assessment_component_id = ?',
        whereArgs: [componentId],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        await txn.update(
          DatabaseSchema.tableAssessmentScores,
          {'score': score, 'graded_at': now, 'notes': notes},
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      } else {
        await txn.insert(DatabaseSchema.tableAssessmentScores, {
          'assessment_component_id': componentId,
          'score': score,
          'graded_at': now,
          'notes': notes,
        });
      }
    });

    await load();
  }

  @override
  Future<void> deleteAssessmentComponent(int componentId) async {
    final db = await appDatabase.database;
    await db.delete(
      DatabaseSchema.tableAssessmentComponents,
      where: 'id = ?',
      whereArgs: [componentId],
    );

    await load();
  }
}

/// Implementasi in-memory untuk fallback atau pengujian terisolasi.
class InMemoryCourseRepository implements CourseRepository {
  final List<CourseItem> _courses = [];

  @override
  List<CourseItem> getActiveCourses() => List.unmodifiable(_courses);

  @override
  CourseItem? getCourseById(String id) {
    for (final c in _courses) {
      if (c.id == id || c.code == id) return c;
    }
    return null;
  }

  @override
  Future<void> load() async {}

  @override
  Future<int> insertCourse({
    required int termId,
    required String code,
    required String name,
    required int credits,
    required String lecturer,
  }) async => 1;

  @override
  Future<void> updateCourse({
    required String id,
    required String code,
    required String name,
    required int credits,
    required String lecturer,
  }) async {}

  @override
  Future<void> archiveCourse(String id) async {}

  @override
  Future<void> deleteCourse(String id) async {}

  @override
  Future<int> addAssessmentComponent({
    required String courseId,
    required String name,
    required double weightPercent,
    bool isRequired = true,
    int sortOrder = 0,
    double? initialScore,
  }) async => 1;

  @override
  Future<void> recordAssessmentScore({
    required int componentId,
    required double score,
    String notes = '',
  }) async {}

  @override
  Future<void> deleteAssessmentComponent(int componentId) async {}
}
