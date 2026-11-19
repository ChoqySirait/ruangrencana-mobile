import '../../../../../core/utils/academic_calculator.dart';
import '../../../../courses/data/models/course_item.dart';

/// Ringkasan riwayat IPS per semester yang sudah selesai.
class SemesterGpaRecord {
  const SemesterGpaRecord({
    required this.semesterLabel,
    required this.sks,
    required this.ips,
  });

  final String semesterLabel;
  final int sks;
  final double ips;
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
}

/// Agregasi ringkasan performa akademik mahasiswa.
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
  });

  final String activeSemesterLabel;
  final int activeSks;
  final int completedSksBeforeActive;
  final int targetGraduationSks;

  /// IPS sementara semester berjalan berbasis komponen nilai yang sudah masuk.
  final double provisionalIps;

  /// IPK kumulatif dari seluruh semester selesai (dan proyeksi bila diperlukan).
  final double cumulativeIpk;

  final List<SemesterGpaRecord> historicalSemesters;
  final List<CourseGradeSummary> courseGrades;

  /// Skala konversi aktif milik pengguna (dapat disesuaikan di tahap berikut).
  final List<GradeScaleRule> gradingScale;
  final String gradingScaleName;
}
