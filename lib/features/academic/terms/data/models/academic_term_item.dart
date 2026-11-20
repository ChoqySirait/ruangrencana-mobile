/// Model data semester akademik (tabel `academic_terms`).
class AcademicTermItem {
  const AcademicTermItem({
    required this.id,
    required this.academicYear,
    required this.semesterName,
    required this.semesterNumber,
    this.startDate,
    this.endDate,
    required this.gradingScaleId,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.courseCount = 0,
    this.totalCredits = 0,
  });

  final int id;
  final String academicYear;
  final String semesterName;
  final int semesterNumber;
  final DateTime? startDate;
  final DateTime? endDate;
  final int gradingScaleId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Jumlah mata kuliah yang terdaftar pada semester ini.
  final int courseCount;

  /// Total SKS mata kuliah pada semester ini.
  final int totalCredits;

  /// Label nama lengkap semester beserta tahun akademik.
  String get fullLabel => '$semesterName • $academicYear';

  /// Label ringkas nomor semester, misal 'Sem 4'.
  String get shortLabel => 'Sem $semesterNumber';

  AcademicTermItem copyWith({
    int? id,
    String? academicYear,
    String? semesterName,
    int? semesterNumber,
    DateTime? startDate,
    DateTime? endDate,
    int? gradingScaleId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? courseCount,
    int? totalCredits,
  }) {
    return AcademicTermItem(
      id: id ?? this.id,
      academicYear: academicYear ?? this.academicYear,
      semesterName: semesterName ?? this.semesterName,
      semesterNumber: semesterNumber ?? this.semesterNumber,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      gradingScaleId: gradingScaleId ?? this.gradingScaleId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      courseCount: courseCount ?? this.courseCount,
      totalCredits: totalCredits ?? this.totalCredits,
    );
  }
}
