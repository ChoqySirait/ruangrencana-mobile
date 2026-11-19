import '../../../../../core/utils/academic_calculator.dart';
import '../../../../courses/data/repositories/course_repository.dart';
import '../models/academic_overview.dart';

/// Kontrak akses data ringkasan nilai dan performa akademik.
abstract class AcademicRepository {
  AcademicOverview getAcademicOverview();
  List<GradeScaleRule> getActiveGradingScale();
}

/// Implementasi sementara berbasis memori menggunakan [AcademicCalculator].
///
/// Penting: Skala nilai di bawah ini hanyalah contoh konfigurasi awal pengguna,
/// bukan standar universal untuk seluruh perguruan tinggi di Indonesia.
class InMemoryAcademicRepository implements AcademicRepository {
  InMemoryAcademicRepository({required this._courseRepository});

  final CourseRepository _courseRepository;

  static const String _sampleScaleName =
      'Contoh Skala 4.00 (Dapat Dikonfigurasi)';

  static const List<GradeScaleRule> _sampleGradingScale = [
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

  static const List<SemesterGpaRecord> _historicalSemesters = [
    SemesterGpaRecord(semesterLabel: 'Sem 1', sks: 19, ips: 3.58),
    SemesterGpaRecord(semesterLabel: 'Sem 2', sks: 21, ips: 3.71),
    SemesterGpaRecord(semesterLabel: 'Sem 3', sks: 20, ips: 3.78),
  ];

  @override
  List<GradeScaleRule> getActiveGradingScale() =>
      List.unmodifiable(_sampleGradingScale);

  @override
  AcademicOverview getAcademicOverview() {
    final activeCourses = _courseRepository.getActiveCourses();
    final courseSummaries = <CourseGradeSummary>[];
    final weightedCurrentPoints = <WeightedGradePoint>[];
    var activeSks = 0;

    for (final course in activeCourses) {
      activeSks += course.sks;
      final calc = course.gradeCalculation;
      final scoreForMapping = calc.provisionalAverage ?? 0;
      final rule = AcademicCalculator.resolveGradeRule(
        scoreForMapping,
        _sampleGradingScale,
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
      activeSemesterLabel: 'Semester 4 • Genap 2025/2026',
      activeSks: activeSks,
      completedSksBeforeActive: completedSks,
      targetGraduationSks: 144,
      provisionalIps: provisionalIps,
      cumulativeIpk: cumulativeIpk,
      historicalSemesters: _historicalSemesters,
      courseGrades: courseSummaries,
      gradingScale: _sampleGradingScale,
      gradingScaleName: _sampleScaleName,
    );
  }
}
