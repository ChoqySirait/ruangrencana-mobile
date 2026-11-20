import 'package:ruangrencana/core/database/app_database.dart';
import 'package:ruangrencana/core/database/database_schema.dart';
import 'package:ruangrencana/core/errors/app_failure.dart';
import 'package:ruangrencana/core/utils/academic_calculator.dart';
import 'package:ruangrencana/features/academic/terms/data/models/academic_term_item.dart';
import 'package:ruangrencana/features/courses/data/repositories/course_repository.dart';
import 'package:sqflite/sqflite.dart';

import '../models/academic_overview.dart';

/// Kontrak akses data ringkasan nilai, performa akademik, dan manajemen semester.
abstract class AcademicRepository {
  AcademicOverview getAcademicOverview();
  List<GradeScaleRule> getActiveGradingScale();
  Future<void> load();

  // Operasi CRUD Semester Akademik
  List<AcademicTermItem> getAllSemesters();
  AcademicTermItem? getActiveSemester();
  AcademicTermItem? getSemesterById(int id);

  Future<int> createSemester({
    required String academicYear,
    required String semesterName,
    required int semesterNumber,
    DateTime? startDate,
    DateTime? endDate,
    int? gradingScaleId,
    bool makeActive = false,
  });

  Future<void> updateSemester({
    required int id,
    required String academicYear,
    required String semesterName,
    required int semesterNumber,
    DateTime? startDate,
    DateTime? endDate,
    int? gradingScaleId,
  });

  Future<void> setActiveSemester(int id);
  Future<void> deleteSemester(int id);

  // Operasi CRUD Skala Nilai
  Future<int> createGradingScale({
    required String name,
    bool isDefault = false,
  });

  Future<int> addGradingScaleRange({
    required int scaleId,
    required double minScore,
    required double maxScore,
    required String letter,
    required double gradePoint,
  });

  Future<void> deleteGradingScaleRange(int rangeId);
}

/// Implementasi repositori performa akademik berbasis SQLite (`sqflite`).
class SqliteAcademicRepository implements AcademicRepository {
  SqliteAcademicRepository({
    required this.appDatabase,
    required this.courseRepository,
  });

  final AppDatabase appDatabase;
  final CourseRepository courseRepository;

  final List<GradeScaleRule> _activeScaleRules = [];
  final List<AcademicTermItem> _cachedSemesters = [];
  String _activeScaleName = 'Contoh Skala 4.00 (Dapat Dikonfigurasi)';
  String _activeSemesterLabel = 'Semester 4 • Genap 2025/2026';
  final List<SemesterGpaRecord> _historicalSemesters = [];
  int _targetGraduationSks = 144;

  @override
  List<AcademicTermItem> getAllSemesters() =>
      List.unmodifiable(_cachedSemesters);

  @override
  AcademicTermItem? getActiveSemester() {
    for (final term in _cachedSemesters) {
      if (term.isActive) return term;
    }
    return null;
  }

  @override
  AcademicTermItem? getSemesterById(int id) {
    for (final term in _cachedSemesters) {
      if (term.id == id) return term;
    }
    return null;
  }

  @override
  List<GradeScaleRule> getActiveGradingScale() =>
      List.unmodifiable(_activeScaleRules);

  @override
  Future<void> load() async {
    final db = await appDatabase.database;

    // 1. Ambil seluruh data semester beserta agregasi jumlah mata kuliah & total SKS
    final termRows = await db.rawQuery('''
      SELECT t.*,
        (SELECT COUNT(*) FROM ${DatabaseSchema.tableCourses} c 
         WHERE c.academic_term_id = t.id AND c.archived_at IS NULL) as course_count,
        (SELECT COALESCE(SUM(c.credits), 0) FROM ${DatabaseSchema.tableCourses} c 
         WHERE c.academic_term_id = t.id AND c.archived_at IS NULL) as total_credits
      FROM ${DatabaseSchema.tableAcademicTerms} t
      ORDER BY t.semester_number ASC
    ''');

    _cachedSemesters
      ..clear()
      ..addAll(
        termRows.map((r) {
          final startStr = r['start_date'] as String?;
          final endStr = r['end_date'] as String?;
          return AcademicTermItem(
            id: r['id'] as int,
            academicYear: r['academic_year'] as String,
            semesterName: r['semester_name'] as String,
            semesterNumber: r['semester_number'] as int,
            startDate: startStr != null ? DateTime.tryParse(startStr) : null,
            endDate: endStr != null ? DateTime.tryParse(endStr) : null,
            gradingScaleId: r['grading_scale_id'] as int,
            isActive: (r['is_active'] as int) == 1,
            createdAt: DateTime.parse(r['created_at'] as String),
            updatedAt: DateTime.parse(r['updated_at'] as String),
            courseCount: (r['course_count'] as int?) ?? 0,
            totalCredits: (r['total_credits'] as int?) ?? 0,
          );
        }),
      );

    // 2. Ambil semester aktif
    final activeTerm = getActiveSemester();
    int scaleId = 1;
    if (activeTerm != null) {
      _activeSemesterLabel = activeTerm.fullLabel;
      scaleId = activeTerm.gradingScaleId;
    } else if (_cachedSemesters.isNotEmpty) {
      _activeSemesterLabel = _cachedSemesters.last.fullLabel;
      scaleId = _cachedSemesters.last.gradingScaleId;
    } else {
      _activeSemesterLabel = 'Belum ada semester';
    }

    // 3. Ambil master skala nilai
    final scaleRows = await db.query(
      DatabaseSchema.tableGradingScales,
      where: 'id = ?',
      whereArgs: [scaleId],
      limit: 1,
    );

    if (scaleRows.isNotEmpty) {
      _activeScaleName = scaleRows.first['scale_name'] as String;
    }

    // 4. Ambil rentang nilai (rules)
    final rangeRows = await db.query(
      DatabaseSchema.tableGradingScaleRanges,
      where: 'grading_scale_id = ?',
      whereArgs: [scaleId],
      orderBy: 'minimum_score DESC',
    );

    _activeScaleRules
      ..clear()
      ..addAll(
        rangeRows.map((r) {
          return GradeScaleRule(
            minScore: (r['minimum_score'] as num).toDouble(),
            maxScore: (r['maximum_score'] as num).toDouble(),
            letter: r['letter_grade'] as String,
            gradePoint: (r['grade_point'] as num).toDouble(),
          );
        }),
      );

    // 5. Target SKS kelulusan dari preferensi aplikasi murni
    final prefRows = await db.query(DatabaseSchema.tableAppPreferences);
    final prefMap = {
      for (final r in prefRows)
        r['preference_key'] as String: r['preference_value'] as String,
    };

    if (prefMap.containsKey('target_graduation_sks')) {
      _targetGraduationSks =
          int.tryParse(prefMap['target_graduation_sks']!) ?? 144;
    }

    // 6. Hitung riwayat semester lampau secara otoritatif dari academic_terms dan courses
    final pastTerms = _cachedSemesters.where((t) => !t.isActive).toList();

    _historicalSemesters.clear();

    for (final term in pastTerms) {
      final termId = term.id;
      final semNumber = term.semesterNumber;
      final termScaleId = term.gradingScaleId;

      // Ambil aturan skala nilai untuk semester ini
      final List<GradeScaleRule> termRules;
      if (termScaleId == scaleId) {
        termRules = _activeScaleRules;
      } else {
        final termRanges = await db.query(
          DatabaseSchema.tableGradingScaleRanges,
          where: 'grading_scale_id = ?',
          whereArgs: [termScaleId],
          orderBy: 'minimum_score DESC',
        );
        termRules = termRanges
            .map(
              (r) => GradeScaleRule(
                minScore: (r['minimum_score'] as num).toDouble(),
                maxScore: (r['maximum_score'] as num).toDouble(),
                letter: r['letter_grade'] as String,
                gradePoint: (r['grade_point'] as num).toDouble(),
              ),
            )
            .toList(growable: false);
      }

      // Ambil seluruh mata kuliah pada semester lampau ini
      final termCourses = await db.query(
        DatabaseSchema.tableCourses,
        where: 'academic_term_id = ? AND archived_at IS NULL',
        whereArgs: [termId],
      );

      if (termCourses.isEmpty) continue;

      var termTotalSks = 0;
      final termWeightedPoints = <WeightedGradePoint>[];

      for (final cRow in termCourses) {
        final cId = cRow['id'] as int;
        final sks = cRow['credits'] as int;
        termTotalSks += sks;

        final compRows = await db.rawQuery(
          '''
          SELECT c.weight_percentage, c.is_required, s.score
          FROM ${DatabaseSchema.tableAssessmentComponents} c
          LEFT JOIN ${DatabaseSchema.tableAssessmentScores} s
            ON s.assessment_component_id = c.id
          WHERE c.course_id = ?
          ''',
          [cId],
        );

        final components = compRows
            .map((cr) {
              final sVal = cr['score'];
              return AssessmentComponentInput(
                name: '',
                weightPercent: (cr['weight_percentage'] as num).toDouble(),
                isMandatory: (cr['is_required'] as int) == 1,
                score: sVal != null ? (sVal as num).toDouble() : null,
              );
            })
            .toList(growable: false);

        final calc = AcademicCalculator.calculateCourseGrade(components);
        if (calc.provisionalAverage != null) {
          final rule = AcademicCalculator.resolveGradeRule(
            calc.provisionalAverage!,
            termRules,
          );
          if (rule != null) {
            termWeightedPoints.add(
              WeightedGradePoint(sks: sks, gradePoint: rule.gradePoint),
            );
          }
        }
      }

      final termIps = AcademicCalculator.calculateWeightedGpa(
        termWeightedPoints,
      );
      _historicalSemesters.add(
        SemesterGpaRecord(
          semesterLabel: 'Sem $semNumber',
          sks: termTotalSks,
          ips: termIps,
        ),
      );
    }
  }

  @override
  AcademicOverview getAcademicOverview() {
    final activeCourses = courseRepository.getActiveCourses();
    final courseSummaries = <CourseGradeSummary>[];
    final weightedCurrentPoints = <WeightedGradePoint>[];
    var activeSks = 0;

    for (final course in activeCourses) {
      activeSks += course.sks;
      final calc = course.gradeCalculation;
      final scoreForMapping = calc.provisionalAverage ?? 0;
      final rule = AcademicCalculator.resolveGradeRule(
        scoreForMapping,
        _activeScaleRules,
      );

      final letter = calc.provisionalAverage == null
          ? '-'
          : (rule?.letter ?? '-');
      final gradePoint = calc.provisionalAverage == null
          ? 0.0
          : (rule?.gradePoint ?? 0.0);

      courseSummaries.add(
        CourseGradeSummary(
          course: course,
          calculation: calc,
          letterGrade: letter,
          gradePoint: gradePoint,
        ),
      );

      if (calc.provisionalAverage != null) {
        weightedCurrentPoints.add(
          WeightedGradePoint(sks: course.sks, gradePoint: gradePoint),
        );
      }
    }

    final provisionalIps = AcademicCalculator.calculateWeightedGpa(
      weightedCurrentPoints,
    );

    final completedWeighted = _historicalSemesters
        .map((sem) => WeightedGradePoint(sks: sem.sks, gradePoint: sem.ips))
        .toList(growable: false);

    final cumulativeIpk = AcademicCalculator.calculateWeightedGpa(
      completedWeighted,
    );

    final completedSks = _historicalSemesters.fold<int>(
      0,
      (sum, sem) => sum + sem.sks,
    );

    return AcademicOverview(
      activeSemesterLabel: _activeSemesterLabel,
      activeSks: activeSks,
      completedSksBeforeActive: completedSks,
      targetGraduationSks: _targetGraduationSks,
      provisionalIps: provisionalIps,
      cumulativeIpk: cumulativeIpk,
      historicalSemesters: _historicalSemesters,
      courseGrades: courseSummaries,
      gradingScale: _activeScaleRules,
      gradingScaleName: _activeScaleName,
    );
  }

  @override
  Future<int> createSemester({
    required String academicYear,
    required String semesterName,
    required int semesterNumber,
    DateTime? startDate,
    DateTime? endDate,
    int? gradingScaleId,
    bool makeActive = false,
  }) async {
    _validateSemesterInput(
      academicYear: academicYear,
      semesterName: semesterName,
      semesterNumber: semesterNumber,
      startDate: startDate,
      endDate: endDate,
    );

    final db = await appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final scaleId = gradingScaleId ?? 1;

    final termId = await db.transaction<int>((txn) async {
      if (makeActive) {
        // Deaktivasi seluruh semester aktif terlebih dahulu
        await txn.update(DatabaseSchema.tableAcademicTerms, {
          'is_active': 0,
          'updated_at': now,
        });
      }

      final id = await txn.insert(DatabaseSchema.tableAcademicTerms, {
        'academic_year': academicYear.trim(),
        'semester_name': semesterName.trim(),
        'semester_number': semesterNumber,
        'start_date': startDate?.toIso8601String().substring(0, 10),
        'end_date': endDate?.toIso8601String().substring(0, 10),
        'grading_scale_id': scaleId,
        'is_active': makeActive ? 1 : 0,
        'created_at': now,
        'updated_at': now,
      });

      return id;
    });

    await courseRepository.load();
    await load();
    return termId;
  }

  @override
  Future<void> updateSemester({
    required int id,
    required String academicYear,
    required String semesterName,
    required int semesterNumber,
    DateTime? startDate,
    DateTime? endDate,
    int? gradingScaleId,
  }) async {
    _validateSemesterInput(
      academicYear: academicYear,
      semesterName: semesterName,
      semesterNumber: semesterNumber,
      startDate: startDate,
      endDate: endDate,
    );

    final db = await appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();

    final updateData = <String, dynamic>{
      'academic_year': academicYear.trim(),
      'semester_name': semesterName.trim(),
      'semester_number': semesterNumber,
      'start_date': startDate?.toIso8601String().substring(0, 10),
      'end_date': endDate?.toIso8601String().substring(0, 10),
      'updated_at': now,
    };

    if (gradingScaleId != null) {
      updateData['grading_scale_id'] = gradingScaleId;
    }

    final affected = await db.update(
      DatabaseSchema.tableAcademicTerms,
      updateData,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (affected == 0) {
      throw AppFailure(
        'Semester akademik tidak ditemukan.',
        code: 'SEMESTER_NOT_FOUND',
      );
    }

    await courseRepository.load();
    await load();
  }

  @override
  Future<void> setActiveSemester(int id) async {
    final db = await appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      final term = await txn.query(
        DatabaseSchema.tableAcademicTerms,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (term.isEmpty) {
        throw AppFailure(
          'Semester target tidak ditemukan.',
          code: 'SEMESTER_NOT_FOUND',
        );
      }

      // 1. Deaktivasi semua semester yang ada secara atomik
      await txn.update(DatabaseSchema.tableAcademicTerms, {
        'is_active': 0,
        'updated_at': now,
      });

      // 2. Aktifkan semester terpilih
      await txn.update(
        DatabaseSchema.tableAcademicTerms,
        {'is_active': 1, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
    });

    // Sinkronkan ulang repositori mata kuliah dan performa akademik
    await courseRepository.load();
    await load();
  }

  @override
  Future<void> deleteSemester(int id) async {
    final db = await appDatabase.database;

    final termRows = await db.query(
      DatabaseSchema.tableAcademicTerms,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (termRows.isEmpty) {
      throw AppFailure('Semester tidak ditemukan.', code: 'SEMESTER_NOT_FOUND');
    }

    final term = termRows.first;
    if ((term['is_active'] as int) == 1) {
      throw AppFailure(
        'Semester aktif tidak dapat dihapus. Aktifkan semester lain terlebih dahulu sebelum menghapus.',
        code: 'CANNOT_DELETE_ACTIVE_SEMESTER',
      );
    }

    final courseCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM ${DatabaseSchema.tableCourses} WHERE academic_term_id = ?',
            [id],
          ),
        ) ??
        0;

    if (courseCount > 0) {
      throw AppFailure(
        'Semester tidak dapat dihapus karena masih memuat $courseCount mata kuliah.',
        code: 'SEMESTER_CONTAINS_COURSES',
      );
    }

    await db.delete(
      DatabaseSchema.tableAcademicTerms,
      where: 'id = ?',
      whereArgs: [id],
    );

    await load();
  }

  void _validateSemesterInput({
    required String academicYear,
    required String semesterName,
    required int semesterNumber,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    if (academicYear.trim().isEmpty) {
      throw AppFailure(
        'Tahun akademik tidak boleh kosong.',
        code: 'INVALID_ACADEMIC_YEAR',
      );
    }
    if (semesterName.trim().isEmpty) {
      throw AppFailure(
        'Nama semester tidak boleh kosong.',
        code: 'INVALID_SEMESTER_NAME',
      );
    }
    if (semesterNumber <= 0) {
      throw AppFailure(
        'Nomor semester harus bernilai positif (minimal 1).',
        code: 'INVALID_SEMESTER_NUMBER',
      );
    }
    if (startDate != null && endDate != null && startDate.isAfter(endDate)) {
      throw AppFailure(
        'Tanggal mulai semester harus lebih awal dari tanggal selesai.',
        code: 'INVALID_DATE_RANGE',
      );
    }
  }

  @override
  Future<int> createGradingScale({
    required String name,
    bool isDefault = false,
  }) async {
    final db = await appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();

    final id = await db.insert(DatabaseSchema.tableGradingScales, {
      'scale_name': name.trim(),
      'is_default': isDefault ? 1 : 0,
      'created_at': now,
      'updated_at': now,
    });

    await load();
    return id;
  }

  @override
  Future<int> addGradingScaleRange({
    required int scaleId,
    required double minScore,
    required double maxScore,
    required String letter,
    required double gradePoint,
  }) async {
    final db = await appDatabase.database;

    final id = await db.insert(DatabaseSchema.tableGradingScaleRanges, {
      'grading_scale_id': scaleId,
      'minimum_score': minScore,
      'maximum_score': maxScore,
      'letter_grade': letter.trim(),
      'grade_point': gradePoint,
    });

    await load();
    return id;
  }

  @override
  Future<void> deleteGradingScaleRange(int rangeId) async {
    final db = await appDatabase.database;
    await db.delete(
      DatabaseSchema.tableGradingScaleRanges,
      where: 'id = ?',
      whereArgs: [rangeId],
    );

    await load();
  }
}

/// Implementasi in-memory untuk fallback atau testing terisolasi.
class InMemoryAcademicRepository implements AcademicRepository {
  InMemoryAcademicRepository({required this.courseRepository});

  final CourseRepository courseRepository;
  final List<AcademicTermItem> _semesters = [];

  static const List<GradeScaleRule> sampleScale = [
    GradeScaleRule(minScore: 85, maxScore: 100, letter: 'A', gradePoint: 4.00),
    GradeScaleRule(
      minScore: 80,
      maxScore: 84.99,
      letter: 'A-',
      gradePoint: 3.70,
    ),
    GradeScaleRule(
      minScore: 75,
      maxScore: 79.99,
      letter: 'B+',
      gradePoint: 3.30,
    ),
    GradeScaleRule(
      minScore: 70,
      maxScore: 74.99,
      letter: 'B',
      gradePoint: 3.00,
    ),
    GradeScaleRule(
      minScore: 65,
      maxScore: 69.99,
      letter: 'B-',
      gradePoint: 2.70,
    ),
    GradeScaleRule(
      minScore: 60,
      maxScore: 64.99,
      letter: 'C+',
      gradePoint: 2.30,
    ),
    GradeScaleRule(
      minScore: 55,
      maxScore: 59.99,
      letter: 'C',
      gradePoint: 2.00,
    ),
    GradeScaleRule(
      minScore: 45,
      maxScore: 54.99,
      letter: 'D',
      gradePoint: 1.00,
    ),
    GradeScaleRule(minScore: 0, maxScore: 44.99, letter: 'E', gradePoint: 0.00),
  ];

  @override
  List<GradeScaleRule> getActiveGradingScale() => sampleScale;

  @override
  List<AcademicTermItem> getAllSemesters() => List.unmodifiable(_semesters);

  @override
  AcademicTermItem? getActiveSemester() {
    for (final s in _semesters) {
      if (s.isActive) return s;
    }
    return null;
  }

  @override
  AcademicTermItem? getSemesterById(int id) {
    for (final s in _semesters) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  Future<int> createSemester({
    required String academicYear,
    required String semesterName,
    required int semesterNumber,
    DateTime? startDate,
    DateTime? endDate,
    int? gradingScaleId,
    bool makeActive = false,
  }) async {
    if (academicYear.trim().isEmpty) {
      throw AppFailure(
        'Tahun akademik tidak boleh kosong.',
        code: 'INVALID_ACADEMIC_YEAR',
      );
    }
    if (semesterName.trim().isEmpty) {
      throw AppFailure(
        'Nama semester tidak boleh kosong.',
        code: 'INVALID_SEMESTER_NAME',
      );
    }
    if (semesterNumber <= 0) {
      throw AppFailure(
        'Nomor semester harus bernilai positif (minimal 1).',
        code: 'INVALID_SEMESTER_NUMBER',
      );
    }
    if (startDate != null && endDate != null && startDate.isAfter(endDate)) {
      throw AppFailure(
        'Tanggal mulai semester harus lebih awal dari tanggal selesai.',
        code: 'INVALID_DATE_RANGE',
      );
    }

    if (makeActive) {
      for (var i = 0; i < _semesters.length; i++) {
        _semesters[i] = _semesters[i].copyWith(isActive: false);
      }
    }

    final now = DateTime.now();
    final newId = _semesters.length + 1;
    final item = AcademicTermItem(
      id: newId,
      academicYear: academicYear,
      semesterName: semesterName,
      semesterNumber: semesterNumber,
      startDate: startDate,
      endDate: endDate,
      gradingScaleId: gradingScaleId ?? 1,
      isActive: makeActive || _semesters.isEmpty,
      createdAt: now,
      updatedAt: now,
    );
    _semesters.add(item);
    return newId;
  }

  @override
  Future<void> updateSemester({
    required int id,
    required String academicYear,
    required String semesterName,
    required int semesterNumber,
    DateTime? startDate,
    DateTime? endDate,
    int? gradingScaleId,
  }) async {
    final index = _semesters.indexWhere((s) => s.id == id);
    if (index == -1) {
      throw AppFailure('Semester tidak ditemukan.', code: 'SEMESTER_NOT_FOUND');
    }
    _semesters[index] = _semesters[index].copyWith(
      academicYear: academicYear,
      semesterName: semesterName,
      semesterNumber: semesterNumber,
      startDate: startDate,
      endDate: endDate,
      gradingScaleId: gradingScaleId,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> setActiveSemester(int id) async {
    final index = _semesters.indexWhere((s) => s.id == id);
    if (index == -1) {
      throw AppFailure(
        'Semester target tidak ditemukan.',
        code: 'SEMESTER_NOT_FOUND',
      );
    }
    for (var i = 0; i < _semesters.length; i++) {
      _semesters[i] = _semesters[i].copyWith(isActive: _semesters[i].id == id);
    }
  }

  @override
  Future<void> deleteSemester(int id) async {
    final term = getSemesterById(id);
    if (term == null) {
      throw AppFailure('Semester tidak ditemukan.', code: 'SEMESTER_NOT_FOUND');
    }
    if (term.isActive) {
      throw AppFailure(
        'Semester aktif tidak dapat dihapus.',
        code: 'CANNOT_DELETE_ACTIVE_SEMESTER',
      );
    }
    _semesters.removeWhere((s) => s.id == id);
  }

  @override
  AcademicOverview getAcademicOverview() {
    return const AcademicOverview(
      activeSemesterLabel: 'Semester 4 • Genap 2025/2026',
      activeSks: 20,
      completedSksBeforeActive: 60,
      targetGraduationSks: 144,
      provisionalIps: 3.65,
      cumulativeIpk: 3.69,
      historicalSemesters: [],
      courseGrades: [],
      gradingScale: sampleScale,
      gradingScaleName: 'Contoh Skala In-Memory',
    );
  }

  @override
  Future<void> load() async {}

  @override
  Future<int> createGradingScale({
    required String name,
    bool isDefault = false,
  }) async => 1;

  @override
  Future<int> addGradingScaleRange({
    required int scaleId,
    required double minScore,
    required double maxScore,
    required String letter,
    required double gradePoint,
  }) async => 1;

  @override
  Future<void> deleteGradingScaleRange(int rangeId) async {}
}
