import 'dart:convert';

import 'package:ruangrencana/core/database/app_database.dart';
import 'package:ruangrencana/core/database/database_schema.dart';
import 'package:ruangrencana/core/utils/academic_calculator.dart';
import 'package:ruangrencana/features/courses/data/repositories/course_repository.dart';

import '../models/academic_overview.dart';

/// Kontrak akses data ringkasan nilai dan performa akademik.
abstract class AcademicRepository {
  AcademicOverview getAcademicOverview();
  List<GradeScaleRule> getActiveGradingScale();
  Future<void> load();

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
  String _activeScaleName = 'Contoh Skala 4.00 (Dapat Dikonfigurasi)';
  String _activeSemesterLabel = 'Semester 4 • Genap 2025/2026';
  final List<SemesterGpaRecord> _historicalSemesters = [];
  int _targetGraduationSks = 144;

  @override
  List<GradeScaleRule> getActiveGradingScale() =>
      List.unmodifiable(_activeScaleRules);

  @override
  Future<void> load() async {
    final db = await appDatabase.database;

    // 1. Ambil semester aktif
    final activeTerms = await db.query(
      DatabaseSchema.tableAcademicTerms,
      where: 'is_active = 1',
      limit: 1,
    );

    int scaleId = 1;
    if (activeTerms.isNotEmpty) {
      final term = activeTerms.first;
      _activeSemesterLabel =
          '${term['semester_name']} • ${term['academic_year']}';
      scaleId = term['grading_scale_id'] as int;
    }

    // 2. Ambil master skala nilai
    final scaleRows = await db.query(
      DatabaseSchema.tableGradingScales,
      where: 'id = ?',
      whereArgs: [scaleId],
      limit: 1,
    );

    if (scaleRows.isNotEmpty) {
      _activeScaleName = scaleRows.first['scale_name'] as String;
    }

    // 3. Ambil rentang nilai (rules)
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

    // 4. Ambil ringkasan riwayat semester lampau & target SKS dari app_preferences
    final prefRows = await db.query(DatabaseSchema.tableAppPreferences);
    final prefMap = {
      for (final r in prefRows)
        r['preference_key'] as String: r['preference_value'] as String,
    };

    if (prefMap.containsKey('target_graduation_sks')) {
      _targetGraduationSks =
          int.tryParse(prefMap['target_graduation_sks']!) ?? 144;
    }

    _historicalSemesters.clear();
    final historyJson = prefMap['historical_semesters_summary'];
    if (historyJson != null) {
      try {
        final List<dynamic> parsed = jsonDecode(historyJson);
        for (final item in parsed) {
          _historicalSemesters.add(
            SemesterGpaRecord(
              semesterLabel: item['label'] as String,
              sks: item['sks'] as int,
              ips: (item['ips'] as num).toDouble(),
            ),
          );
        }
      } catch (_) {
        // Abaikan kegagalan parsing JSON
      }
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

/// Implementasi in-memory untuk fallback atau testing.
class InMemoryAcademicRepository implements AcademicRepository {
  InMemoryAcademicRepository({required this.courseRepository});

  final CourseRepository courseRepository;

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
