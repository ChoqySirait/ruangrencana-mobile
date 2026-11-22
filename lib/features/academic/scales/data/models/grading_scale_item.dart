import 'package:ruangrencana/core/utils/academic_calculator.dart';

/// Item satu rentang nilai pada skala penilaian kampus.
class GradingScaleRangeItem {
  const GradingScaleRangeItem({
    required this.id,
    required this.gradingScaleId,
    required this.minimumScore,
    required this.maximumScore,
    required this.letterGrade,
    required this.gradePoint,
  });

  final int id;
  final int gradingScaleId;
  final double minimumScore;
  final double maximumScore;
  final String letterGrade;
  final double gradePoint;

  GradeScaleRule toRule() => GradeScaleRule(
    minScore: minimumScore,
    maxScore: maximumScore,
    letter: letterGrade,
    gradePoint: gradePoint,
  );

  GradingScaleRangeItem copyWith({
    int? id,
    int? gradingScaleId,
    double? minimumScore,
    double? maximumScore,
    String? letterGrade,
    double? gradePoint,
  }) {
    return GradingScaleRangeItem(
      id: id ?? this.id,
      gradingScaleId: gradingScaleId ?? this.gradingScaleId,
      minimumScore: minimumScore ?? this.minimumScore,
      maximumScore: maximumScore ?? this.maximumScore,
      letterGrade: letterGrade ?? this.letterGrade,
      gradePoint: gradePoint ?? this.gradePoint,
    );
  }
}

/// Model profil skala konversi penilaian universitas yang dapat dikonfigurasi pengguna.
class GradingScaleItem {
  const GradingScaleItem({
    required this.id,
    required this.name,
    this.isDefault = false,
    this.ranges = const [],
    this.usageCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final bool isDefault;
  final List<GradingScaleRangeItem> ranges;
  final int usageCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  List<GradeScaleRule> get rules =>
      ranges.map((r) => r.toRule()).toList(growable: false);

  GradingScaleValidationResult get validation =>
      AcademicCalculator.validateGradingScale(rules);

  bool get isValid => validation.isValid;

  GradingScaleItem copyWith({
    int? id,
    String? name,
    bool? isDefault,
    List<GradingScaleRangeItem>? ranges,
    int? usageCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GradingScaleItem(
      id: id ?? this.id,
      name: name ?? this.name,
      isDefault: isDefault ?? this.isDefault,
      ranges: ranges ?? this.ranges,
      usageCount: usageCount ?? this.usageCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
