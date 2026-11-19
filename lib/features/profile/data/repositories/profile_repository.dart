import '../models/student_profile.dart';

/// Kontrak akses data profil mahasiswa dan preferensi aplikasi.
abstract class ProfileRepository {
  StudentProfile getProfile();
  void saveProfile(StudentProfile profile);
}

/// Implementasi profil demonstrasi fiktif berbasis memori.
class InMemoryProfileRepository implements ProfileRepository {
  StudentProfile _profile = const StudentProfile(
    fullName: 'Nadia Putri Pratama',
    studentId: '2024010099',
    email: 'nadia.pratama@contoh-kampus.ac.id',
    university: 'Universitas Nusantara Merdeka',
    studyProgram: 'S1 Teknik Informatika',
    academicYear: '2025/2026',
    activeSemesterLabel: 'Semester 4 (Genap)',
    notifyClassReminder: true,
    notifyDeadlineReminder: true,
    notifyWeeklySummary: false,
  );

  @override
  StudentProfile getProfile() => _profile;

  @override
  void saveProfile(StudentProfile profile) {
    _profile = profile;
  }
}
