import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruangrencana/core/database/app_database.dart';
import 'package:ruangrencana/core/database/database_seeder.dart';
import 'package:ruangrencana/core/errors/app_failure.dart';
import 'package:ruangrencana/features/academic/grades/data/repositories/academic_repository.dart';
import 'package:ruangrencana/features/courses/data/repositories/course_repository.dart';
import 'package:ruangrencana/features/courses/presentation/view_models/course_detail_view_model.dart';
import 'package:ruangrencana/features/schedule/data/repositories/schedule_repository.dart';
import 'package:ruangrencana/features/tasks/data/repositories/task_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Manajemen Jadwal Perkuliahan & Penilaian (SQLite & ViewModel)', () {
    late Directory tempDir;
    late String dbFilePath;
    late AppDatabase appDb;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'ruangrencana_sched_eval_test_',
      );
      dbFilePath = '${tempDir.path}${Platform.pathSeparator}test_sched_eval.db';
      appDb = AppDatabase(databaseFactory: databaseFactoryFfi);
    });

    tearDown(() async {
      await appDb.close();
      if (await tempDir.exists()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('Validasi dan operasi CRUD jadwal perkuliahan', () async {
      final db = await appDb.open(customPath: dbFilePath);
      await DatabaseSeeder.seedIfNeeded(db);

      final schedRepo = SqliteScheduleRepository(appDatabase: appDb);
      await schedRepo.load();

      // 1. Validasi: jam selesai <= jam mulai ditolak
      expect(
        () => schedRepo.addSchedule(
          courseId: 1,
          weekday: 1,
          startTime: '10:00',
          endTime: '08:00',
          classroom: 'Ruang 101',
        ),
        throwsA(
          isA<AppFailure>().having((e) => e.code, 'code', 'INVALID_TIME_RANGE'),
        ),
      );

      // 2. Validasi: hari tidak valid (< 1 atau > 7)
      expect(
        () => schedRepo.addSchedule(
          courseId: 1,
          weekday: 8,
          startTime: '08:00',
          endTime: '09:40',
          classroom: 'Ruang 101',
        ),
        throwsA(
          isA<AppFailure>().having((e) => e.code, 'code', 'INVALID_WEEKDAY'),
        ),
      );

      // 3. Tambah jadwal valid
      final schedId = await schedRepo.addSchedule(
        courseId: 1,
        weekday: 1,
        startTime: '13:00',
        endTime: '14:40',
        classroom: 'Lab RPL',
      );
      expect(schedId, greaterThan(0));

      final courseSchedules = schedRepo.getSchedulesForCourse('1');
      expect(courseSchedules.any((s) => s.id == schedId.toString()), isTrue);

      // 4. Update jadwal
      await schedRepo.updateSchedule(
        scheduleId: schedId,
        weekday: 2,
        startTime: '14:00',
        endTime: '15:40',
        classroom: 'Lab Jaringan',
      );

      final updatedCourseSchedules = schedRepo.getSchedulesForCourse('1');
      final updated = updatedCourseSchedules.firstWhere(
        (s) => s.id == schedId.toString(),
      );
      expect(updated.dayOfWeek, 2);
      expect(updated.startTime, '14:00');
      expect(updated.endTime, '15:40');
      expect(updated.room, 'Lab Jaringan');

      // 5. Hapus jadwal
      await schedRepo.deleteSchedule(schedId);
      final afterDelete = schedRepo.getSchedulesForCourse('1');
      expect(afterDelete.any((s) => s.id == schedId.toString()), isFalse);
    });

    test('Deteksi konflik jadwal perkuliahan pada hari yang sama (interval overlap)', () async {
      final db = await appDb.open(customPath: dbFilePath);
      await DatabaseSeeder.seedIfNeeded(db);

      final schedRepo = SqliteScheduleRepository(appDatabase: appDb);
      await schedRepo.load();

      // Tambahkan jadwal awal pada hari Sabtu (weekday 6) untuk mengisolasi dari seed data
      final s1 = await schedRepo.addSchedule(
        courseId: 1,
        weekday: 6,
        startTime: '08:00',
        endTime: '09:40',
        classroom: 'Ruang A',
      );

      // Kasus A: Bentrok tumpang-tindih sebagian (Sabtu 09:00 - 10:30)
      final conflictPartial = await schedRepo.findConflictingSchedules(
        courseId: 1,
        weekday: 6,
        startTime: '09:00',
        endTime: '10:30',
      );
      expect(conflictPartial.length, 1);
      expect(conflictPartial.first.id, s1.toString());

      // Kasus B: Bentrok di dalam rentang (Sabtu 08:30 - 09:00)
      final conflictInside = await schedRepo.findConflictingSchedules(
        courseId: 1,
        weekday: 6,
        startTime: '08:30',
        endTime: '09:00',
      );
      expect(conflictInside.length, 1);
      expect(conflictInside.first.id, s1.toString());

      // Kasus C: Tidak bentrok karena pas berbatasan (Sabtu 09:40 - 11:20)
      final noConflictAdjacent = await schedRepo.findConflictingSchedules(
        courseId: 1,
        weekday: 6,
        startTime: '09:40',
        endTime: '11:20',
      );
      expect(noConflictAdjacent, isEmpty);

      // Kasus D: Tidak bentrok karena beda hari (Minggu 08:00 - 09:40)
      final noConflictDifferentDay = await schedRepo.findConflictingSchedules(
        courseId: 1,
        weekday: 7,
        startTime: '08:00',
        endTime: '09:40',
      );
      expect(noConflictDifferentDay, isEmpty);

      // Kasus E: Pengecualian ID sendiri saat edit jadwal (excludeScheduleId)
      final noConflictSelf = await schedRepo.findConflictingSchedules(
        courseId: 1,
        weekday: 6,
        startTime: '08:00',
        endTime: '09:40',
        excludeScheduleId: s1,
      );
      expect(noConflictSelf, isEmpty);
    });

    test(
      'Mendukung multi-sesi untuk satu mata kuliah (Teori & Praktikum)',
      () async {
        final db = await appDb.open(customPath: dbFilePath);
        await DatabaseSeeder.seedIfNeeded(db);

        final schedRepo = SqliteScheduleRepository(appDatabase: appDb);
        await schedRepo.load();

        // Tambahkan sesi teori
        final sTeori = await schedRepo.addSchedule(
          courseId: 1,
          weekday: 1,
          startTime: '08:00',
          endTime: '09:40',
          classroom: 'Ruang Teori 301',
        );

        // Tambahkan sesi praktikum
        final sPrak = await schedRepo.addSchedule(
          courseId: 1,
          weekday: 3,
          startTime: '13:00',
          endTime: '15:30',
          classroom: 'Laboratorium Basis Data',
        );

        final schedules = schedRepo.getSchedulesForCourse('1');
        expect(schedules.any((s) => s.id == sTeori.toString()), isTrue);
        expect(schedules.any((s) => s.id == sPrak.toString()), isTrue);
      },
    );

    test(
      'Validasi batas total bobot komponen penilaian (maksimal 100%)',
      () async {
        final db = await appDb.open(customPath: dbFilePath);
        await DatabaseSeeder.seedIfNeeded(db);

        final courseRepo = SqliteCourseRepository(appDatabase: appDb);
        await courseRepo.load();

        // Buat mata kuliah baru khusus uji komponen
        final newCourseId = await courseRepo.insertCourse(
          termId: 1,
          code: 'TEST101',
          name: 'Uji Penilaian',
          credits: 3,
          lecturer: 'Dosen Pengampu',
        );

        // 1. Validasi nama kosong
        expect(
          () => courseRepo.addAssessmentComponent(
            courseId: newCourseId.toString(),
            name: '',
            weightPercent: 20,
          ),
          throwsA(
            isA<AppFailure>().having(
              (e) => e.code,
              'code',
              'INVALID_COMPONENT_NAME',
            ),
          ),
        );

        // 2. Validasi bobot <= 0 atau > 100
        expect(
          () => courseRepo.addAssessmentComponent(
            courseId: newCourseId.toString(),
            name: 'Tugas',
            weightPercent: 0,
          ),
          throwsA(
            isA<AppFailure>().having((e) => e.code, 'code', 'INVALID_WEIGHT'),
          ),
        );

        expect(
          () => courseRepo.addAssessmentComponent(
            courseId: newCourseId.toString(),
            name: 'Tugas',
            weightPercent: 105,
          ),
          throwsA(
            isA<AppFailure>().having((e) => e.code, 'code', 'INVALID_WEIGHT'),
          ),
        );

        // 3. Tambah komponen pertama 60%
        await courseRepo.addAssessmentComponent(
          courseId: newCourseId.toString(),
          name: 'UTS',
          weightPercent: 60,
        );

        // 4. Tambah komponen kedua 50% -> total 110% harus ditolak saat validasi total bobot aktif
        expect(
          () => courseRepo.addAssessmentComponent(
            courseId: newCourseId.toString(),
            name: 'UAS',
            weightPercent: 50,
            validateTotalWeight: true,
          ),
          throwsA(
            isA<AppFailure>().having(
              (e) => e.code,
              'code',
              'EXCEEDS_MAX_WEIGHT',
            ),
          ),
        );

        // 5. Tambah komponen kedua 40% -> total pas 100% harus berhasil
        final uasId = await courseRepo.addAssessmentComponent(
          courseId: newCourseId.toString(),
          name: 'UAS',
          weightPercent: 40,
        );
        expect(uasId, greaterThan(0));

        final c = courseRepo.getCourseById(newCourseId.toString());
        expect(c, isNotNull);
        expect(c!.assessmentComponents.length, 2);
        expect(c.gradeCalculation.totalConfiguredWeightPercent, 100.0);
      },
    );

    test(
      'Validasi rentang skor 0.0 - 100.0 dan pencegahan silent clamping',
      () async {
        final db = await appDb.open(customPath: dbFilePath);
        await DatabaseSeeder.seedIfNeeded(db);

        final courseRepo = SqliteCourseRepository(appDatabase: appDb);
        await courseRepo.load();

        final newCourseId = await courseRepo.insertCourse(
          termId: 1,
          code: 'TEST102',
          name: 'Uji Validasi Skor',
          credits: 2,
          lecturer: 'Dosen Pengampu',
        );

        final compId = await courseRepo.addAssessmentComponent(
          courseId: newCourseId.toString(),
          name: 'Kuis 1',
          weightPercent: 100,
        );

        // Skor negatif harus ditolak (bukan di-clamp ke 0)
        expect(
          () => courseRepo.recordAssessmentScore(
            componentId: compId,
            score: -5.0,
          ),
          throwsA(
            isA<AppFailure>().having((e) => e.code, 'code', 'INVALID_SCORE'),
          ),
        );

        // Skor > 100 harus ditolak (bukan di-clamp ke 100)
        expect(
          () => courseRepo.recordAssessmentScore(
            componentId: compId,
            score: 105.0,
          ),
          throwsA(
            isA<AppFailure>().having((e) => e.code, 'code', 'INVALID_SCORE'),
          ),
        );

        // Batas 0.0 dan 100.0 harus valid
        await courseRepo.recordAssessmentScore(componentId: compId, score: 0.0);
        var c = courseRepo.getCourseById(newCourseId.toString());
        expect(c!.assessmentComponents.first.score, 0.0);

        await courseRepo.recordAssessmentScore(
          componentId: compId,
          score: 100.0,
        );
        c = courseRepo.getCourseById(newCourseId.toString());
        expect(c!.assessmentComponents.first.score, 100.0);

        // Hapus skor
        await courseRepo.deleteAssessmentScore(compId);
        c = courseRepo.getCourseById(newCourseId.toString());
        expect(c!.assessmentComponents.first.hasScore, isFalse);
      },
    );

    test('Perhitungan Nilai Sementara vs Nilai Akhir pada ViewModel', () async {
      final db = await appDb.open(customPath: dbFilePath);
      await DatabaseSeeder.seedIfNeeded(db);

      final courseRepo = SqliteCourseRepository(appDatabase: appDb);
      final taskRepo = SqliteTaskRepository(appDatabase: appDb);
      final academicRepo = SqliteAcademicRepository(
        appDatabase: appDb,
        courseRepository: courseRepo,
      );
      final schedRepo = SqliteScheduleRepository(appDatabase: appDb);

      await courseRepo.load();
      await taskRepo.load();
      await academicRepo.load();
      await schedRepo.load();

      final cId = await courseRepo.insertCourse(
        termId: 1,
        code: 'TEST103',
        name: 'Uji Nilai Akhir',
        credits: 3,
        lecturer: 'Dosen Pengampu',
      );

      // Buat 3 komponen: Tugas (20%), UTS (30%), UAS (50%)
      final tugasId = await courseRepo.addAssessmentComponent(
        courseId: cId.toString(),
        name: 'Tugas',
        weightPercent: 20,
        isRequired: true,
      );
      final utsId = await courseRepo.addAssessmentComponent(
        courseId: cId.toString(),
        name: 'UTS',
        weightPercent: 30,
        isRequired: true,
      );
      final uasId = await courseRepo.addAssessmentComponent(
        courseId: cId.toString(),
        name: 'UAS',
        weightPercent: 50,
        isRequired: true,
      );

      final vm = CourseDetailViewModel(
        courseId: cId.toString(),
        courseRepository: courseRepo,
        taskRepository: taskRepo,
        academicRepository: academicRepo,
        scheduleRepository: schedRepo,
      );

      // 1. Belum ada skor -> provisional null & isFinalReady false
      expect(vm.course!.gradeCalculation.provisionalAverage, isNull);
      expect(vm.course!.gradeCalculation.isFinalReady, isFalse);

      // 2. Nilai tugas 90.0 dimasukkan -> Nilai sementara = 90.0 (bobot 20%)
      await vm.recordScore(componentId: tugasId, score: 90.0);
      expect(vm.course!.gradeCalculation.provisionalAverage, 90.0);
      expect(vm.course!.gradeCalculation.gradedWeightPercent, 20.0);
      expect(vm.course!.gradeCalculation.isFinalReady, isFalse);

      // 3. Nilai UTS 80.0 dimasukkan -> Nilai sementara = (90*20 + 80*30)/50 = (1800 + 2400)/50 = 84.0
      await vm.recordScore(componentId: utsId, score: 80.0);
      expect(vm.course!.gradeCalculation.provisionalAverage, 84.0);
      expect(vm.course!.gradeCalculation.gradedWeightPercent, 50.0);
      expect(vm.course!.gradeCalculation.isFinalReady, isFalse);

      // 4. Nilai UAS 85.0 dimasukkan -> Seluruh komponen wajib (100%) terisi -> isFinalReady true!
      // Total score = 90*0.2 + 80*0.3 + 85*0.5 = 18 + 24 + 42.5 = 84.5
      await vm.recordScore(componentId: uasId, score: 85.0);
      expect(vm.course!.gradeCalculation.isFinalReady, isTrue);
      expect(vm.course!.gradeCalculation.finalScore, 84.5);
      expect(vm.resolvedGradeRule, isNotNull);
      expect(vm.resolvedGradeRule!.letter, 'A-');
      expect(vm.resolvedGradeRule!.gradePoint, 3.70);
    });

    test(
      'Persistensi SQLite komponen dan jadwal antar-restart aplikasi',
      () async {
        final db = await appDb.open(customPath: dbFilePath);
        await DatabaseSeeder.seedIfNeeded(db);

        final courseRepo = SqliteCourseRepository(appDatabase: appDb);
        final schedRepo = SqliteScheduleRepository(appDatabase: appDb);
        await courseRepo.load();
        await schedRepo.load();

        final cId = await courseRepo.insertCourse(
          termId: 1,
          code: 'PERSIST1',
          name: 'Mata Kuliah Persisten',
          credits: 4,
          lecturer: 'Dosen Pengampu',
        );

        final sId = await schedRepo.addSchedule(
          courseId: cId,
          weekday: 4,
          startTime: '08:00',
          endTime: '11:20',
          classroom: 'Ruang Seminar 2',
        );

        final compId = await courseRepo.addAssessmentComponent(
          courseId: cId.toString(),
          name: 'Proyek Akhir',
          weightPercent: 100,
          isRequired: true,
        );

        await courseRepo.recordAssessmentScore(
          componentId: compId,
          score: 95.0,
          notes: 'Hasil demo sangat memuaskan',
        );

        // Tutup koneksi database (simulasi restart / kill process)
        await appDb.close();

        // Buka koneksi baru dengan file database yang sama
        final freshAppDb = AppDatabase(databaseFactory: databaseFactoryFfi);
        await freshAppDb.open(customPath: dbFilePath);

        final freshCourseRepo = SqliteCourseRepository(appDatabase: freshAppDb);
        final freshSchedRepo = SqliteScheduleRepository(
          appDatabase: freshAppDb,
        );
        await freshCourseRepo.load();
        await freshSchedRepo.load();

        final freshCourse = freshCourseRepo.getCourseById(cId.toString());
        expect(freshCourse, isNotNull);
        expect(freshCourse!.code, 'PERSIST1');
        expect(freshCourse.assessmentComponents.length, 1);

        final freshComp = freshCourse.assessmentComponents.first;
        expect(freshComp.id, compId);
        expect(freshComp.name, 'Proyek Akhir');
        expect(freshComp.weightPercent, 100.0);
        expect(freshComp.score, 95.0);
        expect(freshComp.notes, 'Hasil demo sangat memuaskan');

        final freshSchedules = freshSchedRepo.getSchedulesForCourse(
          cId.toString(),
        );
        expect(freshSchedules.length, 1);
        expect(freshSchedules.first.id, sId.toString());
        expect(freshSchedules.first.dayOfWeek, 4);
        expect(freshSchedules.first.startTime, '08:00');
        expect(freshSchedules.first.endTime, '11:20');
        expect(freshSchedules.first.room, 'Ruang Seminar 2');

        await freshAppDb.close();
      },
    );
  });
}
