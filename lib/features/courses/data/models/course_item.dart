import 'package:ruangrencana/core/utils/academic_calculator.dart';

/// Model komponen penilaian mata kuliah yang tersimpan di basis data SQLite.
class CourseAssessmentComponent extends AssessmentComponentInput {
  const CourseAssessmentComponent({
    this.id = 0,
    required super.name,
    required super.weightPercent,
    super.score,
    super.isMandatory = true,
    this.sortOrder = 0,
    this.notes = '',
  });

  final int id;
  final int sortOrder;
  final String notes;

  CourseAssessmentComponent copyWith({
    int? id,
    String? name,
    double? weightPercent,
    double? score,
    bool? isMandatory,
    int? sortOrder,
    String? notes,
  }) {
    return CourseAssessmentComponent(
      id: id ?? this.id,
      name: name ?? this.name,
      weightPercent: weightPercent ?? this.weightPercent,
      score: score ?? this.score,
      isMandatory: isMandatory ?? this.isMandatory,
      sortOrder: sortOrder ?? this.sortOrder,
      notes: notes ?? this.notes,
    );
  }
}

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
  final List<CourseAssessmentComponent> assessmentComponents;
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
    List<CourseAssessmentComponent>? assessmentComponents,
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
