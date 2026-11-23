import '../../../../../core/utils/academic_calculator.dart';
import '../../../../courses/data/models/course_item.dart';

/// Catatan nilai satu mata kuliah pada semester lampau.
class HistoricalCourseGradeRecord {
  const HistoricalCourseGradeRecord({
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.sks,
    required this.score,
    required this.letterGrade,
    required this.gradePoint,
    required this.isFinalReady,
  });

  final String courseId;
  final String courseCode;
  final String courseName;
  final int sks;
  final double? score;
  final String letterGrade;
  final double gradePoint;
  final bool isFinalReady;

  bool get isPassed => gradePoint > 0.0;
}

/// Ringkasan riwayat IPS per semester yang sudah selesai beserta daftar mata kuliahnya.
class SemesterGpaRecord {
  const SemesterGpaRecord({
    required this.semesterLabel,
    required this.sks,
    required this.ips,
    this.passedSks,
    this.termId,
    this.academicYear,
    this.courses = const [],
  });

  final String semesterLabel;
  final int sks;
  final double ips;
  final int? passedSks;
  final int? termId;
  final String? academicYear;
  final List<HistoricalCourseGradeRecord> courses;

  /// Jumlah SKS yang lulus (grade point > 0.0). Jika tidak ditentukan, mengacu pada SKS yang lulus di courses atau sks.
  int get effectivePassedSks => passedSks ?? sks;
}

/// Ringkasan nilai satu mata kuliah dengan pemisahan jelas antara nilai
/// sementara (provisional) dan nilai akhir (final).
class CourseGradeSummary {
  const CourseGradeSummary({
    required this.course,
    required this.calculation,
    required this.letterGrade,
    required this.gradePoint,
  });

  final CourseItem course;
  final CourseGradeCalculation calculation;
  final String letterGrade;
  final double gradePoint;

  bool get isFinalReady => calculation.isFinalReady;
  bool get isPassed => gradePoint > 0.0;
}

/// Agregasi ringkasan performa akademik mahasiswa yang dihitung secara dinamis.
class AcademicOverview {
  const AcademicOverview({
    required this.activeSemesterLabel,
    required this.activeSks,
    required this.completedSksBeforeActive,
    required this.targetGraduationSks,
    required this.provisionalIps,
    required this.cumulativeIpk,
    required this.historicalSemesters,
    required this.courseGrades,
    required this.gradingScale,
    required this.gradingScaleName,
    this.officialIps = 0.0,
    this.activePassedSks = 0,
  });

  final String activeSemesterLabel;
  final int activeSks;
  final int completedSksBeforeActive;
  final int targetGraduationSks;

  /// IPS sementara semester berjalan berbasis komponen nilai yang sudah masuk.
  final double provisionalIps;

  /// IPS resmi semester berjalan hanya dari mata kuliah yang sudah berstatus final (100% bobot).
  final double officialIps;

  /// IPK kumulatif dari seluruh mata kuliah selesai lintas semester.
  final double cumulativeIpk;

  /// SKS yang telah lulus pada semester aktif (final dan grade point > 0).
  final int activePassedSks;

  final List<SemesterGpaRecord> historicalSemesters;
  final List<CourseGradeSummary> courseGrades;

  /// Skala konversi aktif milik pengguna.
  final List<GradeScaleRule> gradingScale;
  final String gradingScaleName;

  /// Total SKS lulus kumulatif (semester lampau + semester aktif yang sudah final & lulus).
  int get totalPassedSks => completedSksBeforeActive + activePassedSks;

  /// Total SKS yang sedang atau sudah ditempuh.
  int get totalEnrolledSks => completedSksBeforeActive + activeSks;

  /// Jumlah mata kuliah aktif yang sudah bernilai final.
  int get finalizedCourseCount =>
      courseGrades.where((c) => c.calculation.isFinalReady).length;
}
