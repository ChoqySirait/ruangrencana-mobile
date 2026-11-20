import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruangrencana/core/database/app_database.dart';
import 'package:ruangrencana/core/database/database_seeder.dart';
import 'package:ruangrencana/core/errors/app_failure.dart';
import 'package:ruangrencana/features/academic/grades/data/repositories/academic_repository.dart';
import 'package:ruangrencana/features/academic/terms/presentation/view_models/semester_view_model.dart';
import 'package:ruangrencana/features/courses/data/repositories/course_repository.dart';
import 'package:ruangrencana/features/courses/presentation/view_models/courses_view_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Manajemen Semester & Mata Kuliah (SQLite & ViewModel)', () {
    late Directory tempDir;
    late String dbFilePath;
    late AppDatabase appDb;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ruangrencana_sem_test_');
      dbFilePath = '${tempDir.path}${Platform.pathSeparator}test_semester.db';
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

    test('Validasi dan pembuatan semester baru dengan proteksi tanggal dan nomor semester', () async {
      final db = await appDb.open(customPath: dbFilePath);
      await DatabaseSeeder.seedIfNeeded(db);

      final courseRepo = SqliteCourseRepository(appDatabase: appDb);
      final academicRepo = SqliteAcademicRepository(
        appDatabase: appDb,
        courseRepository: courseRepo,
      );
      await courseRepo.load();
      await academicRepo.load();

      // 1. Validasi: Tanggal mulai > tanggal selesai harus ditolak
      expect(
        () => academicRepo.createSemester(
          academicYear: '2026/2027',
          semesterName: 'Semester 5 (Ganjil)',
          semesterNumber: 5,
          startDate: DateTime(2026, 9, 1),
          endDate: DateTime(2026, 1, 1), // Invalid: end sebelum start
        ),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.code,
            'code',
            'INVALID_DATE_RANGE',
          ),
        ),
      );

      // 2. Validasi: Nomor semester <= 0 harus ditolak
      expect(
        () => academicRepo.createSemester(
          academicYear: '2026/2027',
          semesterName: 'Semester Tidak Valid',
          semesterNumber: 0,
        ),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.code,
            'code',
            'INVALID_SEMESTER_NUMBER',
          ),
        ),
      );

      // 3. Pembuatan semester yang valid
      final newTermId = await academicRepo.createSemester(
        academicYear: '2026/2027',
        semesterName: 'Semester 5 (Ganjil)',
        semesterNumber: 5,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2027, 1, 31),
        makeActive: false,
      );

      expect(newTermId, greaterThan(0));

      final created = academicRepo.getSemesterById(newTermId);
      expect(created, isNotNull);
      expect(created!.semesterName, 'Semester 5 (Ganjil)');
      expect(created.isActive, isFalse);
    });

    test('Peralihan semester aktif memastikan hanya ada tepat SATU semester aktif', () async {
      final db = await appDb.open(customPath: dbFilePath);
      await DatabaseSeeder.seedIfNeeded(db);

      final courseRepo = SqliteCourseRepository(appDatabase: appDb);
      final academicRepo = SqliteAcademicRepository(
        appDatabase: appDb,
        courseRepository: courseRepo,
      );
      await courseRepo.load();
      await academicRepo.load();

      // Awalnya Semester 4 adalah semester aktif
      final initialActive = academicRepo.getActiveSemester();
      expect(initialActive, isNotNull);
      expect(initialActive!.semesterNumber, 4);

      // Ambil Semester 3
      final allSemesters = academicRepo.getAllSemesters();
      final sem3 = allSemesters.firstWhere((s) => s.semesterNumber == 3);
      expect(sem3.isActive, isFalse);

      // Alihkan semester aktif ke Semester 3
      await academicRepo.setActiveSemester(sem3.id);

      // Verifikasi: Hanya tepat 1 semester yang aktif
      final activeSemestersAfter =
          academicRepo.getAllSemesters().where((s) => s.isActive).toList();
      expect(activeSemestersAfter.length, 1);
      expect(activeSemestersAfter.first.id, sem3.id);
      expect(activeSemestersAfter.first.semesterNumber, 3);

      // Verifikasi courseRepo otomatis memuat mata kuliah semester 3
      final coursesInActiveTerm = courseRepo.getActiveCourses();
      expect(coursesInActiveTerm, isNotEmpty);
      expect(coursesInActiveTerm.any((c) => c.code == 'SI2301'), isTrue);
    });

    test('Proteksi penghapusan semester: semester aktif dan semester berisi mata kuliah tidak dapat dihapus', () async {
      final db = await appDb.open(customPath: dbFilePath);
      await DatabaseSeeder.seedIfNeeded(db);

      final courseRepo = SqliteCourseRepository(appDatabase: appDb);
      final academicRepo = SqliteAcademicRepository(
        appDatabase: appDb,
        courseRepository: courseRepo,
      );
      await courseRepo.load();
      await academicRepo.load();

      final activeTerm = academicRepo.getActiveSemester()!;

      // 1. Coba hapus semester aktif -> harus ditolak
      expect(
        () => academicRepo.deleteSemester(activeTerm.id),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.code,
            'code',
            'CANNOT_DELETE_ACTIVE_SEMESTER',
          ),
        ),
      );

      // 2. Coba hapus semester lampau yang berisi mata kuliah -> harus ditolak
      final sem1 =
          academicRepo.getAllSemesters().firstWhere((s) => s.semesterNumber == 1);
      expect(
        () => academicRepo.deleteSemester(sem1.id),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.code,
            'code',
            'SEMESTER_CONTAINS_COURSES',
          ),
        ),
      );

      // 3. Buat semester kosong baru, lalu hapus -> harus berhasil
      final emptyTermId = await academicRepo.createSemester(
        academicYear: '2028/2029',
        semesterName: 'Semester Kosong',
        semesterNumber: 8,
      );
      expect(academicRepo.getSemesterById(emptyTermId), isNotNull);

      await academicRepo.deleteSemester(emptyTermId);
      expect(academicRepo.getSemesterById(emptyTermId), isNull);
    });

    test('Validasi mata kuliah: keunikan kode per semester, SKS positif, dan arsip', () async {
      final db = await appDb.open(customPath: dbFilePath);
      await DatabaseSeeder.seedIfNeeded(db);

      final courseRepo = SqliteCourseRepository(appDatabase: appDb);
      final academicRepo = SqliteAcademicRepository(
        appDatabase: appDb,
        courseRepository: courseRepo,
      );
      await courseRepo.load();
      await academicRepo.load();

      final activeTermId = academicRepo.getActiveSemester()!.id;

      // 1. Validasi: SKS <= 0 harus ditolak
      expect(
        () => courseRepo.insertCourse(
          termId: activeTermId,
          code: 'IF999',
          name: 'Mata Kuliah Nol SKS',
          credits: 0,
          lecturer: 'Dosen X',
        ),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.code,
            'code',
            'INVALID_CREDITS',
          ),
        ),
      );

      // 2. Validasi: Keunikan kode dalam semester yang sama
      // IF2401 sudah ada di semester 4
      expect(
        () => courseRepo.insertCourse(
          termId: activeTermId,
          code: 'if2401', // case insensitive
          name: 'Duplikat Pemrograman Mobile',
          credits: 3,
          lecturer: 'Dosen Lain',
        ),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.code,
            'code',
            'DUPLICATE_COURSE_CODE',
          ),
        ),
      );

      // 3. Tambah mata kuliah baru
      final newCourseId = await courseRepo.insertCourse(
        termId: activeTermId,
        code: 'IF2499',
        name: 'Cloud Computing & DevOps',
        credits: 3,
        lecturer: 'Ir. Ahmad Dani',
      );
      expect(newCourseId, greaterThan(0));

      final fetched = courseRepo.getCourseById(newCourseId.toString());
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Cloud Computing & DevOps');
      expect(fetched.isArchived, isFalse);

      // 4. Pengarsipan mata kuliah
      await courseRepo.archiveCourse(newCourseId.toString());

      // Tidak boleh muncul di getActiveCourses()
      final activeList = courseRepo.getActiveCourses();
      expect(activeList.any((c) => c.id == newCourseId.toString()), isFalse);

      // Tapi tetap ada di getCoursesBySemester dengan includeArchived: true
      final allSemesterCourses = await courseRepo.getCoursesBySemester(
        activeTermId,
        includeArchived: true,
      );
      final archivedCourse =
          allSemesterCourses.firstWhere((c) => c.id == newCourseId.toString());
      expect(archivedCourse.isArchived, isTrue);

      // 5. Pembatalan arsip (unarchive)
      await courseRepo.unarchiveCourse(newCourseId.toString());
      final restoredList = courseRepo.getActiveCourses();
      expect(restoredList.any((c) => c.id == newCourseId.toString()), isTrue);
    });

    test('Persistensi perubahan semester dan mata kuliah antar restart database', () async {
      // Sesi 1
      final db1 = await appDb.open(customPath: dbFilePath);
      await DatabaseSeeder.seedIfNeeded(db1);

      final courseRepo1 = SqliteCourseRepository(appDatabase: appDb);
      final academicRepo1 = SqliteAcademicRepository(
        appDatabase: appDb,
        courseRepository: courseRepo1,
      );
      await courseRepo1.load();
      await academicRepo1.load();

      final createdSemId = await academicRepo1.createSemester(
        academicYear: '2027/2028',
        semesterName: 'Semester 7 (Ganjil)',
        semesterNumber: 7,
      );

      final createdCourseId = await courseRepo1.insertCourse(
        termId: createdSemId,
        code: 'SI4701',
        name: 'Kapita Selekta Sistem Informasi',
        credits: 4,
        lecturer: 'Prof. Dr. Hendra',
      );

      await appDb.close();

      // Sesi 2: Buka kembali database dari disk dengan instance AppDatabase baru
      final appDb2 = AppDatabase(databaseFactory: databaseFactoryFfi);
      await appDb2.open(customPath: dbFilePath);

      final courseRepo2 = SqliteCourseRepository(appDatabase: appDb2);
      final academicRepo2 = SqliteAcademicRepository(
        appDatabase: appDb2,
        courseRepository: courseRepo2,
      );
      await courseRepo2.load();
      await academicRepo2.load();

      final reloadedSem = academicRepo2.getSemesterById(createdSemId);
      expect(reloadedSem, isNotNull);
      expect(reloadedSem!.semesterName, 'Semester 7 (Ganjil)');
      expect(reloadedSem.courseCount, 1);
      expect(reloadedSem.totalCredits, 4);

      final semCourses = await courseRepo2.getCoursesBySemester(createdSemId);
      expect(semCourses.length, 1);
      expect(semCourses.first.id, createdCourseId.toString());
      expect(semCourses.first.code, 'SI4701');

      await appDb2.close();
    });

    test('Interaksi SemesterViewModel dan CoursesViewModel', () async {
      final db = await appDb.open(customPath: dbFilePath);
      await DatabaseSeeder.seedIfNeeded(db);

      final courseRepo = SqliteCourseRepository(appDatabase: appDb);
      final academicRepo = SqliteAcademicRepository(
        appDatabase: appDb,
        courseRepository: courseRepo,
      );
      await courseRepo.load();
      await academicRepo.load();

      var activeChangedCalled = false;
      final semVm = SemesterViewModel(
        repository: academicRepo,
        onActiveSemesterChanged: () async {
          activeChangedCalled = true;
        },
      );

      var coursesChangedCalled = false;
      final coursesVm = CoursesViewModel(
        courseRepository: courseRepo,
        academicRepository: academicRepo,
        onCoursesChanged: () async {
          coursesChangedCalled = true;
        },
      );

      // Verifikasi SemesterViewModel memuat semester awal
      expect(semVm.semesters.length, 4);
      expect(semVm.activeSemester?.semesterNumber, 4);

      // Verifikasi CoursesViewModel memuat mata kuliah semester 4
      await coursesVm.loadCourses();
      expect(coursesVm.courses.length, 7);

      // Ganti semester aktif melalui SemesterViewModel
      final sem2 = semVm.semesters.firstWhere((s) => s.semesterNumber == 2);
      final success = await semVm.setActiveSemester(sem2.id);
      expect(success, isTrue);
      expect(activeChangedCalled, isTrue);
      expect(semVm.activeSemester?.id, sem2.id);

      // Ganti semester pada CoursesViewModel
      coursesVm.selectSemester(sem2.id);
      await coursesVm.loadCourses();
      expect(coursesVm.courses.length, 7);
      expect(coursesVm.courses.every((c) => c.code.startsWith('SI12') || c.code.startsWith('MA12') || c.code.startsWith('KU12')), isTrue);

      // Test pengarsipan melalui CoursesViewModel
      final courseToArchive = coursesVm.courses.first;
      await coursesVm.archiveCourse(courseToArchive.id);
      expect(coursesChangedCalled, isTrue);

      // Course aktif berkurang 1
      expect(coursesVm.courses.length, 6);

      // Tampilkan arsip
      coursesVm.toggleShowArchived();
      await coursesVm.loadCourses();
      expect(coursesVm.courses.length, 1);
      expect(coursesVm.courses.first.id, courseToArchive.id);
    });
  });
}
