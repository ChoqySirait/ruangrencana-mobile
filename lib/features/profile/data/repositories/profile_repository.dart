import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_schema.dart';
import '../models/student_profile.dart';

/// Kontrak akses data profil mahasiswa dan preferensi aplikasi.
abstract class ProfileRepository {
  StudentProfile getProfile();
  Future<void> saveProfile(StudentProfile profile);
  Future<void> load();
}

/// Implementasi repositori profil berbasis SQLite (`sqflite`).
class SqliteProfileRepository implements ProfileRepository {
  SqliteProfileRepository({required this.appDatabase});

  final AppDatabase appDatabase;
  StudentProfile? _cachedProfile;

  static const StudentProfile defaultFallbackProfile = StudentProfile(
    fullName: 'Choqy Pananda',
    studentId: '2024010099',
    email: 'choqy@contoh-kampus.ac.id',
    university: 'Universitas Nusantara Merdeka',
    studyProgram: 'S1 Teknik Informatika',
    academicYear: '2025/2026',
    activeSemesterLabel: 'Semester 4 (Genap)',
    notifyClassReminder: true,
    notifyDeadlineReminder: true,
    notifyWeeklySummary: false,
  );

  @override
  StudentProfile getProfile() {
    return _cachedProfile ?? defaultFallbackProfile;
  }

  @override
  Future<void> load() async {
    final db = await appDatabase.database;

    final profileRows = await db.query(
      DatabaseSchema.tableStudentProfiles,
      orderBy: 'id ASC',
      limit: 1,
    );

    // Ambil semester aktif
    final activeTermRows = await db.query(
      DatabaseSchema.tableAcademicTerms,
      where: 'is_active = 1',
      limit: 1,
    );

    // Ambil preferensi notifikasi
    final prefRows = await db.query(DatabaseSchema.tableAppPreferences);
    final prefMap = {
      for (final r in prefRows)
        r['preference_key'] as String: r['preference_value'] as String,
    };

    if (profileRows.isEmpty) {
      _cachedProfile = defaultFallbackProfile;
      return;
    }

    final pRow = profileRows.first;
    final termName = activeTermRows.isNotEmpty
        ? activeTermRows.first['semester_name'] as String
        : 'Semester 4 (Genap)';
    final termYear = activeTermRows.isNotEmpty
        ? activeTermRows.first['academic_year'] as String
        : '2025/2026';

    _cachedProfile = StudentProfile(
      id: pRow['id'] as int?,
      fullName: pRow['full_name'] as String,
      studentId: (pRow['student_number'] as String?) ?? '',
      email: prefMap['email'] ?? 'choqy@contoh-kampus.ac.id',
      university: pRow['institution_name'] as String,
      studyProgram: pRow['study_program'] as String,
      academicYear: termYear,
      activeSemesterLabel: termName,
      notifyClassReminder: prefMap['notify_class_reminder'] != 'false',
      notifyDeadlineReminder: prefMap['notify_deadline_reminder'] != 'false',
      notifyWeeklySummary: prefMap['notify_weekly_summary'] == 'true',
    );
  }

  @override
  Future<void> saveProfile(StudentProfile profile) async {
    final db = await appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      // 1. Simpan atau perbarui tabel student_profiles
      final existing = await txn.query(
        DatabaseSchema.tableStudentProfiles,
        limit: 1,
      );

      int profileId;
      if (existing.isNotEmpty) {
        profileId = existing.first['id'] as int;
        await txn.update(
          DatabaseSchema.tableStudentProfiles,
          {
            'full_name': profile.fullName,
            'student_number': profile.studentId,
            'study_program': profile.studyProgram,
            'institution_name': profile.university,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [profileId],
        );
      } else {
        profileId = await txn.insert(DatabaseSchema.tableStudentProfiles, {
          'full_name': profile.fullName,
          'student_number': profile.studentId,
          'study_program': profile.studyProgram,
          'institution_name': profile.university,
          'created_at': now,
          'updated_at': now,
        });
      }

      // 2. Perbarui semester aktif jika ada
      final activeTerms = await txn.query(
        DatabaseSchema.tableAcademicTerms,
        where: 'is_active = 1',
        limit: 1,
      );
      if (activeTerms.isNotEmpty) {
        await txn.update(
          DatabaseSchema.tableAcademicTerms,
          {
            'academic_year': profile.academicYear,
            'semester_name': profile.activeSemesterLabel,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [activeTerms.first['id']],
        );
      }

      // 3. Simpan preferensi notifikasi & email
      final prefsToSave = {
        'email': profile.email,
        'notify_class_reminder': profile.notifyClassReminder.toString(),
        'notify_deadline_reminder': profile.notifyDeadlineReminder.toString(),
        'notify_weekly_summary': profile.notifyWeeklySummary.toString(),
      };

      for (final entry in prefsToSave.entries) {
        await txn.insert(DatabaseSchema.tableAppPreferences, {
          'preference_key': entry.key,
          'preference_value': entry.value,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      _cachedProfile = profile.copyWith(id: profileId);
    });
  }
}

/// Implementasi in-memory sebagai fallback atau pengujian ringan.
class InMemoryProfileRepository implements ProfileRepository {
  StudentProfile _profile = SqliteProfileRepository.defaultFallbackProfile;

  @override
  StudentProfile getProfile() => _profile;

  @override
  Future<void> saveProfile(StudentProfile profile) async {
    _profile = profile;
  }

  @override
  Future<void> load() async {}
}
