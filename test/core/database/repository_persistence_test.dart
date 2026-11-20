import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruangrencana/core/database/app_database.dart';
import 'package:ruangrencana/core/database/database_schema.dart';
import 'package:ruangrencana/core/database/database_seeder.dart';
import 'package:ruangrencana/core/errors/app_failure.dart';
import 'package:ruangrencana/core/utils/date_formatter.dart';
import 'package:ruangrencana/features/academic/grades/data/repositories/academic_repository.dart';
import 'package:ruangrencana/features/academic/simulator/presentation/view_models/grade_simulator_view_model.dart';
import 'package:ruangrencana/features/courses/data/repositories/course_repository.dart';
import 'package:ruangrencana/features/profile/data/repositories/profile_repository.dart';
import 'package:ruangrencana/features/schedule/data/repositories/schedule_repository.dart';
import 'package:ruangrencana/features/tasks/data/models/assignment_item.dart';
import 'package:ruangrencana/features/tasks/data/repositories/task_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('SQLite Repositories Persistence & Lifecycle Tests', () {
    late Directory tempDir;
    late String dbFilePath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ruangrencana_test_');
      dbFilePath = '${tempDir.path}${Platform.pathSeparator}test_academic.db';
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Siklus Hidup Tugas: Tambah -> Tutup DB -> Verifikasi -> Edit -> Restart -> Verifikasi -> Hapus', () async {
      // 1. Inisialisasi awal database dan seeding
      final appDb1 = AppDatabase(databaseFactory: databaseFactoryFfi);
      final db1 = await appDb1.open(customPath: dbFilePath);
      await DatabaseSeeder.seedIfNeeded(db1);

      final taskRepo1 = SqliteTaskRepository(appDatabase: appDb1);
      await taskRepo1.load();

      final initialCount = taskRepo1.getAllAssignments().length;
      expect(initialCount, greaterThan(0));

      // 2. Tambah tugas baru
      final newAssignment = AssignmentItem(
        id: 'temp-id',
        title: 'Tugas Uji Persistensi SQLite',
        courseId: '1',
        courseName: 'Pemrograman Mobile',
        dueDate: DateTime.parse('2026-11-25T23:59:00Z'),
        priority: AssignmentPriority.high,
        notes: 'Instruksi pengerjaan uji persistensi.',
      );
      await taskRepo1.addAssignment(newAssignment);
      expect(taskRepo1.getAllAssignments().length, initialCount + 1);

      // 3. TUTUP DATABASE (simulasi aplikasi ditutup)
      await appDb1.close();

      // 4. BUKA KEMBALI DATABASE (simulasi aplikasi dibuka kembali)
      final appDb2 = AppDatabase(databaseFactory: databaseFactoryFfi);
      await appDb2.open(customPath: dbFilePath);
      final taskRepo2 = SqliteTaskRepository(appDatabase: appDb2);
      await taskRepo2.load();

      final created = taskRepo2.getAllAssignments().firstWhere(
        (a) => a.title == 'Tugas Uji Persistensi SQLite',
      );
      expect(created.notes, 'Instruksi pengerjaan uji persistensi.');
      expect(created.priority, AssignmentPriority.high);
      expect(created.isCompleted, isFalse);

      // 5. Ubah tugas (tandai selesai dan edit catatan)
      final updatedAssignment = created.copyWith(
        notes: 'Catatan telah diperbarui sebelum restart kedua.',
        isCompleted: true,
      );
      await taskRepo2.updateAssignment(updatedAssignment);

      // 6. TUTUP DATABASE KEDUA KALI
      await appDb2.close();

      // 7. BUKA KEMBALI KETIGA KALI
      final appDb3 = AppDatabase(databaseFactory: databaseFactoryFfi);
      await appDb3.open(customPath: dbFilePath);
      final taskRepo3 = SqliteTaskRepository(appDatabase: appDb3);
      await taskRepo3.load();

      final updatedCheck = taskRepo3.getAllAssignments().firstWhere(
        (a) => a.title == 'Tugas Uji Persistensi SQLite',
      );
      expect(
        updatedCheck.notes,
        'Catatan telah diperbarui sebelum restart kedua.',
      );
      expect(updatedCheck.isCompleted, isTrue);

      // 8. Hapus tugas dan verifikasi setelah restart
      await taskRepo3.deleteAssignment(updatedCheck.id);
      expect(
        taskRepo3.getAllAssignments().any(
          (a) => a.title == 'Tugas Uji Persistensi SQLite',
        ),
        isFalse,
      );

      await appDb3.close();

      final appDb4 = AppDatabase(databaseFactory: databaseFactoryFfi);
      await appDb4.open(customPath: dbFilePath);
      final taskRepo4 = SqliteTaskRepository(appDatabase: appDb4);
      await taskRepo4.load();

      expect(
        taskRepo4.getAllAssignments().any(
          (a) => a.title == 'Tugas Uji Persistensi SQLite',
        ),
        isFalse,
      );

      await appDb4.close();
    });

    test('Persistensi Profil Mahasiswa & Preferensi Antar Sesi', () async {
      final appDb1 = AppDatabase(databaseFactory: databaseFactoryFfi);
      final db1 = await appDb1.open(customPath: dbFilePath);
      await DatabaseSeeder.seedIfNeeded(db1);

      final profileRepo1 = SqliteProfileRepository(appDatabase: appDb1);
      await profileRepo1.load();

      final current = profileRepo1.getProfile();
      expect(current.fullName, contains('Mahasiswa Demo'));

      // Ubah profil
      final updated = current.copyWith(
        fullName: 'Mahasiswa Berprestasi',
        university: 'Institut Teknologi Harapan Bangsa',
        studyProgram: 'S1 Sistem Informasi Terapan',
        notifyWeeklySummary: true,
      );
      await profileRepo1.saveProfile(updated);

      await appDb1.close();

      // Buka kembali database baru
      final appDb2 = AppDatabase(databaseFactory: databaseFactoryFfi);
      await appDb2.open(customPath: dbFilePath);
      final profileRepo2 = SqliteProfileRepository(appDatabase: appDb2);
      await profileRepo2.load();

      final reloaded = profileRepo2.getProfile();
      expect(reloaded.fullName, 'Mahasiswa Berprestasi');
      expect(reloaded.university, 'Institut Teknologi Harapan Bangsa');
      expect(reloaded.studyProgram, 'S1 Sistem Informasi Terapan');
      expect(reloaded.notifyWeeklySummary, isTrue);

      await appDb2.close();
    });

    test('Persistensi Mata Kuliah, Jadwal, Komponen Nilai & Skor', () async {
      final appDb1 = AppDatabase(databaseFactory: databaseFactoryFfi);
      final db1 = await appDb1.open(customPath: dbFilePath);
      await DatabaseSeeder.seedIfNeeded(db1);

      final courseRepo1 = SqliteCourseRepository(appDatabase: appDb1);
      final schedRepo1 = SqliteScheduleRepository(appDatabase: appDb1);
      await courseRepo1.load();
      await schedRepo1.load();

      // 1. Tambah mata kuliah baru
      final newCourseId = await courseRepo1.insertCourse(
        termId: 4,
        code: 'SI3999',
        name: 'Arsitektur Sistem Informasi Lanjut',
        credits: 4,
        lecturer: 'Dr. Tech Mentor, M.T.',
      );

      // 2. Tambah jadwal kuliah
      await schedRepo1.addSchedule(
        courseId: newCourseId,
        weekday: 5,
        startTime: '13:00',
        endTime: '16:30',
        classroom: 'Lab Riset 1',
      );

      // 3. Tambah komponen penilaian dan skor
      final compId = await courseRepo1.addAssessmentComponent(
        courseId: newCourseId.toString(),
        name: 'Tugas Besar Arsitektur',
        weightPercent: 100.0,
        isRequired: true,
        initialScore: 95.0,
      );
      expect(compId, greaterThan(0));

      await appDb1.close();

      // Buka kembali database di sesi berbeda
      final appDb2 = AppDatabase(databaseFactory: databaseFactoryFfi);
      await appDb2.open(customPath: dbFilePath);

      final courseRepo2 = SqliteCourseRepository(appDatabase: appDb2);
      final schedRepo2 = SqliteScheduleRepository(appDatabase: appDb2);
      await courseRepo2.load();
      await schedRepo2.load();

      final course = courseRepo2.getCourseById(newCourseId.toString());
      expect(course, isNotNull);
      expect(course!.code, 'SI3999');
      expect(course.sks, 4);
      expect(course.assessmentComponents.length, 1);
      expect(course.assessmentComponents.first.score, 95.0);
      expect(course.gradeCalculation.isFinalReady, isTrue);
      expect(course.gradeCalculation.finalScore, 95.0);

      final schedules = schedRepo2.getSchedulesForDay(5);
      expect(schedules.any((s) => s.courseCode == 'SI3999'), isTrue);

      await appDb2.close();
    });

    test(
      'Isolasi Simulasi Nilai: Tidak Menimpa Data Asli pada Repository',
      () async {
        final appDb = AppDatabase(databaseFactory: databaseFactoryFfi);
        final db = await appDb.open(customPath: dbFilePath);
        await DatabaseSeeder.seedIfNeeded(db);

        final courseRepo = SqliteCourseRepository(appDatabase: appDb);
        final academicRepo = SqliteAcademicRepository(
          appDatabase: appDb,
          courseRepository: courseRepo,
        );

        await courseRepo.load();
        await academicRepo.load();

        final overviewBefore = academicRepo.getAcademicOverview();
        final firstCourse = overviewBefore.courseGrades.first;
        final originalScore = firstCourse.calculation.provisionalAverage;

        // Buka ViewModel simulasi nilai
        final simVm = GradeSimulatorViewModel(academicRepository: academicRepo);

        // Ubah skor simulasi secara drastis
        simVm.updateHypotheticalScore(firstCourse.course.id, 50.0);
        expect(simVm.scoreForCourse(firstCourse.course.id), 50.0);

        // Pastikan catatan nilai di repositori asli TIDAK berubah
        final overviewAfter = academicRepo.getAcademicOverview();
        final firstCourseAfter = overviewAfter.courseGrades.first;
        expect(firstCourseAfter.calculation.provisionalAverage, originalScore);

        await appDb.close();
      },
    );

    test('Otoritas Riwayat Akademik dari academic_terms dan courses (Bukan app_preferences)', () async {
      final appDb = AppDatabase(databaseFactory: databaseFactoryFfi);
      final db = await appDb.open(customPath: dbFilePath);
      await DatabaseSeeder.seedIfNeeded(db);

      // Verifikasi bahwa app_preferences TIDAK menyimpan 'historical_semesters_summary'
      final prefCheck = await db.query(
        DatabaseSchema.tableAppPreferences,
        where: 'preference_key = ?',
        whereArgs: ['historical_semesters_summary'],
      );
      expect(
        prefCheck,
        isEmpty,
        reason:
            'app_preferences tidak boleh menyimpan duplikasi riwayat akademik',
      );

      final courseRepo = SqliteCourseRepository(appDatabase: appDb);
      final academicRepo = SqliteAcademicRepository(
        appDatabase: appDb,
        courseRepository: courseRepo,
      );

      await courseRepo.load();
      await academicRepo.load();

      final overview = academicRepo.getAcademicOverview();

      // Verifikasi riwayat semester berasal dari academic_terms (Sem 1, Sem 2, Sem 3)
      expect(overview.historicalSemesters.length, 3);
      expect(overview.historicalSemesters[0].semesterLabel, 'Sem 1');
      expect(overview.historicalSemesters[0].sks, 19);
      expect(overview.historicalSemesters[0].ips, greaterThan(3.5));

      expect(overview.historicalSemesters[1].semesterLabel, 'Sem 2');
      expect(overview.historicalSemesters[1].sks, 21);
      expect(overview.historicalSemesters[1].ips, greaterThan(3.5));

      expect(overview.historicalSemesters[2].semesterLabel, 'Sem 3');
      expect(overview.historicalSemesters[2].sks, 20);
      expect(overview.historicalSemesters[2].ips, greaterThan(3.5));

      expect(overview.completedSksBeforeActive, 60);
      expect(overview.cumulativeIpk, greaterThan(3.5));

      await appDb.close();
    });

    test(
      'Idempotensi dan Konsistensi Seeder Demo (Mahasiswa Demo, DEMO-001)',
      () async {
        final appDb = AppDatabase(databaseFactory: databaseFactoryFfi);
        final db = await appDb.open(customPath: dbFilePath);

        // Seeding pertama
        final firstSeed = await DatabaseSeeder.seedIfNeeded(db);
        expect(firstSeed, isTrue);

        // Seeding kedua (harus idempotent / return false tanpa modifikasi)
        final secondSeed = await DatabaseSeeder.seedIfNeeded(db);
        expect(secondSeed, isFalse);

        final profileRepo = SqliteProfileRepository(appDatabase: appDb);
        await profileRepo.load();

        final p = profileRepo.getProfile();
        expect(p.fullName, 'Mahasiswa Demo');
        expect(p.studentId, 'DEMO-001');
        expect(p.studyProgram, 'S1 Sistem Informasi');
        expect(p.university, 'Universitas Contoh');

        await appDb.close();
      },
    );

    test(
      'Perlindungan Rekaman Akademik pada Penghapusan Mata Kuliah',
      () async {
        final appDb = AppDatabase(databaseFactory: databaseFactoryFfi);
        final db = await appDb.open(customPath: dbFilePath);
        await DatabaseSeeder.seedIfNeeded(db);

        final courseRepo = SqliteCourseRepository(appDatabase: appDb);
        await courseRepo.load();

        // Ambil mata kuliah pertama semester aktif (yang sudah memiliki komponen penilaian dan skor)
        final activeCourses = courseRepo.getActiveCourses();
        expect(activeCourses, isNotEmpty);
        final courseWithGrades = activeCourses.first;

        // Cek statistik dependensi
        final stats = await courseRepo.getDependentStats(courseWithGrades.id);
        expect(stats.hasAcademicHistory, isTrue);
        expect(stats.scoreCount, greaterThan(0));

        // 1. Penghapusan tanpa force HARUS gagal dan melempar AppFailure
        expect(
          () => courseRepo.deleteCourse(courseWithGrades.id, force: false),
          throwsA(
            isA<AppFailure>().having(
              (e) => e.code,
              'code',
              'COURSE_HAS_ACADEMIC_HISTORY',
            ),
          ),
        );

        // 2. Pengarsipan (archiveCourse) adalah operasi yang direkomendasikan dan berhasil
        await courseRepo.archiveCourse(courseWithGrades.id);
        expect(courseRepo.getCourseById(courseWithGrades.id), isNull);

        // 3. Penghapusan dengan force: true berhasil menghapus secara bersih tanpa meninggalkan orphan scores
        await courseRepo.deleteCourse(courseWithGrades.id, force: true);

        final orphanScores = await db.rawQuery('''
        SELECT COUNT(*) as count FROM ${DatabaseSchema.tableAssessmentScores} s
        LEFT JOIN ${DatabaseSchema.tableAssessmentComponents} c ON c.id = s.assessment_component_id
        WHERE c.id IS NULL
        ''');
        expect(
          orphanScores.first['count'],
          0,
          reason: 'Tidak boleh ada assessment score yang menjadi yatim piatu',
        );

        await appDb.close();
      },
    );

    test('Konsistensi Zona Waktu & Tenggat Tugas', () async {
      final appDb = AppDatabase(databaseFactory: databaseFactoryFfi);
      final db = await appDb.open(customPath: dbFilePath);
      await DatabaseSeeder.seedIfNeeded(db);

      final taskRepo = SqliteTaskRepository(appDatabase: appDb);
      await taskRepo.load();

      // Buat tugas dengan tenggat waktu spesifik
      final targetUtc = DateTime.utc(2026, 12, 10, 16, 59, 0);
      final taskItem = AssignmentItem(
        id: 'tz-test',
        title: 'Tugas Uji Timezone',
        courseId: '1',
        courseName: 'Pemrograman Mobile',
        dueDate: targetUtc,
        priority: AssignmentPriority.high,
      );
      await taskRepo.addAssignment(taskItem);

      await appDb.close();

      // Buka kembali database dan verifikasi
      final appDb2 = AppDatabase(databaseFactory: databaseFactoryFfi);
      await appDb2.open(customPath: dbFilePath);
      final taskRepo2 = SqliteTaskRepository(appDatabase: appDb2);
      await taskRepo2.load();

      final loaded = taskRepo2.getAllAssignments().firstWhere(
        (t) => t.title == 'Tugas Uji Timezone',
      );
      expect(loaded.dueDate.toUtc(), targetUtc);

      // Format lokal via DateFormatter tidak boleh menghasilkan pergeseran negatif
      final formatted = DateFormatter.shortDateWithTime(loaded.dueDate);
      expect(formatted, contains('Des'));

      // Uji status tenggat waktu
      final pastReference = DateTime.utc(2026, 12, 15, 0, 0, 0);
      expect(loaded.statusAt(pastReference), AssignmentStatus.overdue);

      final futureReference = DateTime.utc(2026, 12, 1, 0, 0, 0);
      expect(loaded.statusAt(futureReference), AssignmentStatus.upcoming);

      await appDb2.close();
    });
  });
}
