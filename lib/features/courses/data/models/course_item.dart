import '../../../../core/utils/academic_calculator.dart';

/// Model data mata kuliah pada semester akademik.
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
    this.termId = 0,
    this.isArchived = false,
  });

  final String id;
  final String code;
  final String name;
  final int sks;
  final String lecturer;
  final String room;
  final String scheduleLabel;
  final List<AssessmentComponentInput> assessmentComponents;
  final int termId;
  final bool isArchived;

  /// Menghitung status nilai sementara maupun akhir melalui [AcademicCalculator].
  CourseGradeCalculation get gradeCalculation =>
      AcademicCalculator.calculateCourseGrade(assessmentComponents);

  CourseItem copyWith({
    String? id,
    String? code,
    String? name,
    int? sks,
    String? lecturer,
    String? room,
    String? scheduleLabel,
    List<AssessmentComponentInput>? assessmentComponents,
    int? termId,
    bool? isArchived,
  }) {
    return CourseItem(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      sks: sks ?? this.sks,
      lecturer: lecturer ?? this.lecturer,
      room: room ?? this.room,
      scheduleLabel: scheduleLabel ?? this.scheduleLabel,
      assessmentComponents: assessmentComponents ?? this.assessmentComponents,
      termId: termId ?? this.termId,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}
