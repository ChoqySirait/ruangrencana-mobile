import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruangrencana/core/database/app_database.dart';
import 'package:ruangrencana/core/database/database_seeder.dart';
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
      expect(current.fullName, contains('Choqy'));

      // Ubah profil
      final updated = current.copyWith(
        fullName: 'Choqy Pananda Sirait, S.Kom.',
        university: 'Institut Teknologi Harapan Bangsa',
        studyProgram: 'S1 Rekayasa Perangkat Lunak',
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
      expect(reloaded.fullName, 'Choqy Pananda Sirait, S.Kom.');
      expect(reloaded.university, 'Institut Teknologi Harapan Bangsa');
      expect(reloaded.studyProgram, 'S1 Rekayasa Perangkat Lunak');
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
        code: 'IF3999',
        name: 'Arsitektur Perangkat Lunak Lanjut',
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
      expect(course!.code, 'IF3999');
      expect(course.sks, 4);
      expect(course.assessmentComponents.length, 1);
      expect(course.assessmentComponents.first.score, 95.0);
      expect(course.gradeCalculation.isFinalReady, isTrue);
      expect(course.gradeCalculation.finalScore, 95.0);

      final schedules = schedRepo2.getSchedulesForDay(5);
      expect(schedules.any((s) => s.courseCode == 'IF3999'), isTrue);

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
  });
}
