import '../../../../core/utils/academic_calculator.dart';

/// Model data mata kuliah pada semester aktif.
class CourseItem {
  const CourseItem({
    required this.id,
    required this.code,
    required this.name,
    required this.sks,
    required this.lecturer,
    required this.room,
    required this.scheduleLabel,
    required this.assessmentComponents,
  });

  final String id;
  final String code;
  final String name;
  final int sks;
  final String lecturer;
  final String room;
  final String scheduleLabel;
  final List<AssessmentComponentInput> assessmentComponents;

  /// Menghitung status nilai sementara maupun akhir melalui [AcademicCalculator].
  CourseGradeCalculation get gradeCalculation =>
      AcademicCalculator.calculateCourseGrade(assessmentComponents);
}
