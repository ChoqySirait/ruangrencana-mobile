import 'package:ruangrencana/core/database/app_database.dart';
import 'package:ruangrencana/core/database/database_schema.dart';
import 'package:ruangrencana/core/errors/app_failure.dart';
import 'package:ruangrencana/core/utils/academic_calculator.dart';
import 'package:ruangrencana/core/utils/date_formatter.dart';
import 'package:ruangrencana/features/courses/data/models/course_item.dart';
import 'package:sqflite/sqflite.dart';

/// Statistik rekaman terkait suatu mata kuliah untuk perlindungan integritas akademik.
class CourseDependentStats {
  const CourseDependentStats({
    required this.scheduleCount,
    required this.assignmentCount,
    required this.componentCount,
    required this.scoreCount,
    required this.isTermActive,
  });

  final int scheduleCount;
  final int assignmentCount;
  final int componentCount;
  final int scoreCount;
  final bool isTermActive;

  /// Bernilai `true` jika mata kuliah memiliki riwayat penilaian atau berada di semester lampau.
  bool get hasAcademicHistory => scoreCount > 0 || !isTermActive;

  bool get hasDependentRecords =>
      scheduleCount > 0 ||
      assignmentCount > 0 ||
      componentCount > 0 ||
      scoreCount > 0;
}

/// Kontrak akses dan manipulasi data mata kuliah beserta komponen penilaiannya.
abstract class CourseRepository {
  List<CourseItem> getActiveCourses();
  CourseItem? getCourseById(String id);
  Future<List<CourseItem>> getCoursesBySemester(
    int termId, {
    bool includeArchived = false,
  });
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
    int? termId,
  });

  Future<CourseDependentStats> getDependentStats(String id);
  Future<void> archiveCourse(String id);
  Future<void> unarchiveCourse(String id);
  Future<void> deleteCourse(String id, {bool force = false});

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

    final loaded = await _hydrateCourses(db, courseRows);

    _cachedCourses
      ..clear()
      ..addAll(loaded);
  }

  @override
  Future<List<CourseItem>> getCoursesBySemester(
    int termId, {
    bool includeArchived = false,
  }) async {
    final db = await appDatabase.database;

    final String whereClause;
    final List<Object?> whereArgs;

    if (includeArchived) {
      whereClause = 'academic_term_id = ?';
      whereArgs = [termId];
    } else {
      whereClause = 'academic_term_id = ? AND archived_at IS NULL';
      whereArgs = [termId];
    }

    final courseRows = await db.query(
      DatabaseSchema.tableCourses,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'course_code ASC',
    );

    return _hydrateCourses(db, courseRows);
  }

  Future<List<CourseItem>> _hydrateCourses(
    DatabaseExecutor db,
    List<Map<String, Object?>> courseRows,
  ) async {
    final result = <CourseItem>[];

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

      result.add(
        CourseItem(
          id: courseId.toString(),
          code: row['course_code'] as String,
          name: row['course_name'] as String,
          sks: row['credits'] as int,
          lecturer: (row['lecturer_name'] as String?) ?? '',
          room: room,
          scheduleLabel: scheduleLabel,
          assessmentComponents: components,
          termId: (row['academic_term_id'] as int?) ?? 0,
          isArchived: row['archived_at'] != null,
        ),
      );
    }

    return result;
  }

  @override
  Future<int> insertCourse({
    required int termId,
    required String code,
    required String name,
    required int credits,
    required String lecturer,
  }) async {
    _validateCourseInput(code: code, name: name, credits: credits);

    final db = await appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final trimmedCode = code.trim();

    // Verifikasi semester target ada
    final termCheck = await db.query(
      DatabaseSchema.tableAcademicTerms,
      where: 'id = ?',
      whereArgs: [termId],
      limit: 1,
    );
    if (termCheck.isEmpty) {
      throw AppFailure(
        'Semester akademik tidak valid atau tidak ditemukan.',
        code: 'INVALID_TERM',
      );
    }

    // Verifikasi keunikan kode mata kuliah dalam satu semester
    final duplicate = await db.query(
      DatabaseSchema.tableCourses,
      where: 'academic_term_id = ? AND LOWER(course_code) = LOWER(?)',
      whereArgs: [termId, trimmedCode],
      limit: 1,
    );
    if (duplicate.isNotEmpty) {
      throw AppFailure(
        'Kode mata kuliah "$trimmedCode" sudah terdaftar pada semester ini.',
        code: 'DUPLICATE_COURSE_CODE',
      );
    }

    final id = await db.insert(DatabaseSchema.tableCourses, {
      'academic_term_id': termId,
      'course_code': trimmedCode,
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
    int? termId,
  }) async {
    _validateCourseInput(code: code, name: name, credits: credits);

    final db = await appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final cId = int.tryParse(id) ?? id;
    final trimmedCode = code.trim();

    final currentRows = await db.query(
      DatabaseSchema.tableCourses,
      where: 'id = ?',
      whereArgs: [cId],
      limit: 1,
    );

    if (currentRows.isEmpty) {
      throw AppFailure(
        'Mata kuliah tidak ditemukan.',
        code: 'COURSE_NOT_FOUND',
      );
    }

    final targetTermId =
        termId ?? (currentRows.first['academic_term_id'] as int);

    // Verifikasi keunikan kode mata kuliah dalam semester yang sama (abaikan ID diri sendiri)
    final duplicate = await db.query(
      DatabaseSchema.tableCourses,
      where:
          'academic_term_id = ? AND LOWER(course_code) = LOWER(?) AND id != ?',
      whereArgs: [targetTermId, trimmedCode, cId],
      limit: 1,
    );

    if (duplicate.isNotEmpty) {
      throw AppFailure(
        'Kode mata kuliah "$trimmedCode" sudah terdaftar pada semester ini.',
        code: 'DUPLICATE_COURSE_CODE',
      );
    }

    final updateData = <String, dynamic>{
      'course_code': trimmedCode,
      'course_name': name.trim(),
      'credits': credits,
      'lecturer_name': lecturer.trim(),
      'updated_at': now,
    };
    if (termId != null) {
      updateData['academic_term_id'] = termId;
    }

    await db.update(
      DatabaseSchema.tableCourses,
      updateData,
      where: 'id = ?',
      whereArgs: [cId],
    );

    await load();
  }

  void _validateCourseInput({
    required String code,
    required String name,
    required int credits,
  }) {
    if (code.trim().isEmpty) {
      throw AppFailure(
        'Kode mata kuliah tidak boleh kosong.',
        code: 'INVALID_COURSE_CODE',
      );
    }
    if (name.trim().isEmpty) {
      throw AppFailure(
        'Nama mata kuliah tidak boleh kosong.',
        code: 'INVALID_COURSE_NAME',
      );
    }
    if (credits <= 0) {
      throw AppFailure(
        'SKS harus berupa bilangan bulat positif (minimal 1 SKS).',
        code: 'INVALID_CREDITS',
      );
    }
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
  Future<void> unarchiveCourse(String id) async {
    final db = await appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.update(
      DatabaseSchema.tableCourses,
      {'archived_at': null, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [int.tryParse(id) ?? id],
    );

    await load();
  }

  @override
  Future<CourseDependentStats> getDependentStats(String id) async {
    final db = await appDatabase.database;
    final cId = int.tryParse(id) ?? id;

    final courseRow = await db.rawQuery(
      '''
      SELECT c.id, t.is_active
      FROM ${DatabaseSchema.tableCourses} c
      JOIN ${DatabaseSchema.tableAcademicTerms} t ON t.id = c.academic_term_id
      WHERE c.id = ?
      ''',
      [cId],
    );

    final isTermActive = courseRow.isNotEmpty
        ? (courseRow.first['is_active'] as int) == 1
        : true;

    final schedCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM ${DatabaseSchema.tableClassSchedules} WHERE course_id = ?',
            [cId],
          ),
        ) ??
        0;

    final assignCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM ${DatabaseSchema.tableAssignments} WHERE course_id = ?',
            [cId],
          ),
        ) ??
        0;

    final compCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM ${DatabaseSchema.tableAssessmentComponents} WHERE course_id = ?',
            [cId],
          ),
        ) ??
        0;

    final scoreCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            '''
      SELECT COUNT(*) FROM ${DatabaseSchema.tableAssessmentScores}
      WHERE assessment_component_id IN (
        SELECT id FROM ${DatabaseSchema.tableAssessmentComponents}
        WHERE course_id = ?
      )
      ''',
            [cId],
          ),
        ) ??
        0;

    return CourseDependentStats(
      scheduleCount: schedCount,
      assignmentCount: assignCount,
      componentCount: compCount,
      scoreCount: scoreCount,
      isTermActive: isTermActive,
    );
  }

  @override
  Future<void> deleteCourse(String id, {bool force = false}) async {
    final stats = await getDependentStats(id);

    // Perlindungan Rekaman Akademik: cegah penghapusan tidak sengaja jika sudah memiliki riwayat nilai
    if (stats.hasAcademicHistory && !force) {
      throw AppFailure(
        'Mata kuliah memiliki riwayat penilaian akademik. Disarankan untuk mengarsipkan mata kuliah daripada menghapus permanen.',
        code: 'COURSE_HAS_ACADEMIC_HISTORY',
      );
    }

    final cId = int.tryParse(id) ?? id;

    // Eksekusi penghapusan dalam transaksi atomik untuk mencegah orphaned assessment scores
    await appDatabase.transaction((txn) async {
      await txn.rawDelete(
        '''
        DELETE FROM ${DatabaseSchema.tableAssessmentScores}
        WHERE assessment_component_id IN (
          SELECT id FROM ${DatabaseSchema.tableAssessmentComponents}
          WHERE course_id = ?
        )
        ''',
        [cId],
      );
      await txn.delete(
        DatabaseSchema.tableAssessmentComponents,
        where: 'course_id = ?',
        whereArgs: [cId],
      );
      await txn.delete(
        DatabaseSchema.tableAssignments,
        where: 'course_id = ?',
        whereArgs: [cId],
      );
      await txn.delete(
        DatabaseSchema.tableClassSchedules,
        where: 'course_id = ?',
        whereArgs: [cId],
      );
      await txn.delete(
        DatabaseSchema.tableCourses,
        where: 'id = ?',
        whereArgs: [cId],
      );
    });

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
    if (initialScore != null &&
        !AcademicCalculator.isValidScore(initialScore)) {
      throw AppFailure(
        'Skor nilai awal harus berada dalam rentang valid 0.0 sampai 100.0.',
        code: 'INVALID_SCORE',
      );
    }

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
          'score': AcademicCalculator.normalizeScore(initialScore),
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
    if (!AcademicCalculator.isValidScore(score)) {
      throw AppFailure(
        'Skor nilai harus berada dalam rentang valid 0.0 sampai 100.0.',
        code: 'INVALID_SCORE',
      );
    }

    final db = await appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final normalizedScore = AcademicCalculator.normalizeScore(score);

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
          {'score': normalizedScore, 'graded_at': now, 'notes': notes},
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      } else {
        await txn.insert(DatabaseSchema.tableAssessmentScores, {
          'assessment_component_id': componentId,
          'score': normalizedScore,
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
  List<CourseItem> getActiveCourses() =>
      List.unmodifiable(_courses.where((c) => !c.isArchived));

  @override
  CourseItem? getCourseById(String id) {
    for (final c in _courses) {
      if (c.id == id || c.code == id) return c;
    }
    return null;
  }

  @override
  Future<List<CourseItem>> getCoursesBySemester(
    int termId, {
    bool includeArchived = false,
  }) async {
    return _courses
        .where(
          (c) => c.termId == termId && (includeArchived ? true : !c.isArchived),
        )
        .toList();
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
  }) async {
    if (code.trim().isEmpty) {
      throw AppFailure(
        'Kode mata kuliah tidak boleh kosong.',
        code: 'INVALID_COURSE_CODE',
      );
    }
    if (name.trim().isEmpty) {
      throw AppFailure(
        'Nama mata kuliah tidak boleh kosong.',
        code: 'INVALID_COURSE_NAME',
      );
    }
    if (credits <= 0) {
      throw AppFailure(
        'SKS harus berupa bilangan bulat positif.',
        code: 'INVALID_CREDITS',
      );
    }

    final duplicate = _courses.any(
      (c) =>
          c.termId == termId &&
          c.code.toLowerCase() == code.trim().toLowerCase(),
    );
    if (duplicate) {
      throw AppFailure(
        'Kode mata kuliah "$code" sudah terdaftar pada semester ini.',
        code: 'DUPLICATE_COURSE_CODE',
      );
    }

    final newId = (_courses.length + 1).toString();
    _courses.add(
      CourseItem(
        id: newId,
        code: code.trim(),
        name: name.trim(),
        sks: credits,
        lecturer: lecturer.trim(),
        room: 'Ruang Kelas',
        scheduleLabel: 'Jadwal belum ditentukan',
        assessmentComponents: const [],
        termId: termId,
      ),
    );
    return int.parse(newId);
  }

  @override
  Future<void> updateCourse({
    required String id,
    required String code,
    required String name,
    required int credits,
    required String lecturer,
    int? termId,
  }) async {
    final index = _courses.indexWhere((c) => c.id == id);
    if (index == -1) {
      throw AppFailure(
        'Mata kuliah tidak ditemukan.',
        code: 'COURSE_NOT_FOUND',
      );
    }
    final current = _courses[index];
    final targetTerm = termId ?? current.termId;

    final duplicate = _courses.any(
      (c) =>
          c.id != id &&
          c.termId == targetTerm &&
          c.code.toLowerCase() == code.trim().toLowerCase(),
    );
    if (duplicate) {
      throw AppFailure(
        'Kode mata kuliah "$code" sudah terdaftar pada semester ini.',
        code: 'DUPLICATE_COURSE_CODE',
      );
    }

    _courses[index] = current.copyWith(
      code: code.trim(),
      name: name.trim(),
      sks: credits,
      lecturer: lecturer.trim(),
      termId: targetTerm,
    );
  }

  @override
  Future<CourseDependentStats> getDependentStats(String id) async =>
      const CourseDependentStats(
        scheduleCount: 0,
        assignmentCount: 0,
        componentCount: 0,
        scoreCount: 0,
        isTermActive: true,
      );

  @override
  Future<void> archiveCourse(String id) async {
    final index = _courses.indexWhere((c) => c.id == id);
    if (index != -1) {
      _courses[index] = _courses[index].copyWith(isArchived: true);
    }
  }

  @override
  Future<void> unarchiveCourse(String id) async {
    final index = _courses.indexWhere((c) => c.id == id);
    if (index != -1) {
      _courses[index] = _courses[index].copyWith(isArchived: false);
    }
  }

  @override
  Future<void> deleteCourse(String id, {bool force = false}) async {
    _courses.removeWhere((c) => c.id == id);
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
    if (initialScore != null &&
        !AcademicCalculator.isValidScore(initialScore)) {
      throw AppFailure(
        'Skor nilai awal harus berada dalam rentang valid 0.0 sampai 100.0.',
        code: 'INVALID_SCORE',
      );
    }
    return 1;
  }

  @override
  Future<void> recordAssessmentScore({
    required int componentId,
    required double score,
    String notes = '',
  }) async {
    if (!AcademicCalculator.isValidScore(score)) {
      throw AppFailure(
        'Skor nilai harus berada dalam rentang valid 0.0 sampai 100.0.',
        code: 'INVALID_SCORE',
      );
    }
  }

  @override
  Future<void> deleteAssessmentComponent(int componentId) async {}
}
