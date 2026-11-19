/// Model profil mahasiswa dan preferensi lokal RuangRencana.
class StudentProfile {
  const StudentProfile({
    this.id,
    required this.fullName,
    required this.studentId,
    required this.email,
    required this.university,
    required this.studyProgram,
    required this.academicYear,
    required this.activeSemesterLabel,
    required this.notifyClassReminder,
    required this.notifyDeadlineReminder,
    required this.notifyWeeklySummary,
  });

  final int? id;
  final String fullName;

  /// Nomor induk (NIM) mahasiswa di perangkat lokal.
  final String studentId;
  final String email;
  final String university;
  final String studyProgram;
  final String academicYear;
  final String activeSemesterLabel;

  // Preferensi notifikasi lokal
  final bool notifyClassReminder;
  final bool notifyDeadlineReminder;
  final bool notifyWeeklySummary;

  String get firstName {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'Mahasiswa';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  StudentProfile copyWith({
    int? id,
    String? fullName,
    String? studentId,
    String? email,
    String? university,
    String? studyProgram,
    String? academicYear,
    String? activeSemesterLabel,
    bool? notifyClassReminder,
    bool? notifyDeadlineReminder,
    bool? notifyWeeklySummary,
  }) {
    return StudentProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      studentId: studentId ?? this.studentId,
      email: email ?? this.email,
      university: university ?? this.university,
      studyProgram: studyProgram ?? this.studyProgram,
      academicYear: academicYear ?? this.academicYear,
      activeSemesterLabel: activeSemesterLabel ?? this.activeSemesterLabel,
      notifyClassReminder: notifyClassReminder ?? this.notifyClassReminder,
      notifyDeadlineReminder:
          notifyDeadlineReminder ?? this.notifyDeadlineReminder,
      notifyWeeklySummary: notifyWeeklySummary ?? this.notifyWeeklySummary,
    );
  }
}
