import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ruangrencana/app/app.dart';
import 'package:ruangrencana/core/database/app_database.dart';
import 'package:ruangrencana/core/database/database_seeder.dart';
import 'package:ruangrencana/features/academic/grades/data/repositories/academic_repository.dart';
import 'package:ruangrencana/features/courses/data/repositories/course_repository.dart';
import 'package:ruangrencana/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:ruangrencana/features/profile/data/repositories/profile_repository.dart';
import 'package:ruangrencana/features/schedule/data/repositories/schedule_repository.dart';
import 'package:ruangrencana/features/tasks/data/repositories/task_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  late Directory tempDir;
  late String dbPath;
  late AppDatabase appDb;
  late CourseRepository courseRepo;
  late ScheduleRepository schedRepo;
  late TaskRepository taskRepo;
  late ProfileRepository profileRepo;
  late AcademicRepository academicRepo;
  late DashboardRepository dashboardRepo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('widget_test_db_');
    dbPath = '${tempDir.path}${Platform.pathSeparator}test.db';
    appDb = AppDatabase(databaseFactory: databaseFactoryFfi);
    final db = await appDb.open(customPath: dbPath);
    await DatabaseSeeder.seedIfNeeded(db);

    courseRepo = SqliteCourseRepository(appDatabase: appDb);
    schedRepo = SqliteScheduleRepository(appDatabase: appDb);
    taskRepo = SqliteTaskRepository(appDatabase: appDb);
    profileRepo = SqliteProfileRepository(appDatabase: appDb);
    academicRepo = SqliteAcademicRepository(
      appDatabase: appDb,
      courseRepository: courseRepo,
    );

    await courseRepo.load();
    await schedRepo.load();
    await taskRepo.load();
    await profileRepo.load();
    await academicRepo.load();

    dashboardRepo = DefaultDashboardRepository(
      profileRepository: profileRepo,
      scheduleRepository: schedRepo,
      taskRepository: taskRepo,
      academicRepository: academicRepo,
    );
  });

  tearDown(() async {
    await appDb.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> pumpAppAtMobileViewport(
    WidgetTester tester, {
    String initialLocation = '/beranda',
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      RuangRencanaApp(
        initialLocation: initialLocation,
        appDatabase: appDb,
        courseRepository: courseRepo,
        scheduleRepository: schedRepo,
        taskRepository: taskRepo,
        profileRepository: profileRepo,
        academicRepository: academicRepo,
        dashboardRepository: dashboardRepo,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Navigasi lima destinasi utama berjalan tanpa error overflow', (
    tester,
  ) async {
    await pumpAppAtMobileViewport(tester);

    // 1. Beranda
    expect(find.textContaining('Mahasiswa'), findsWidgets);
    expect(find.text('IPS Sementara'), findsOneWidget);
    expect(find.text('IPK Kumulatif'), findsOneWidget);
    expect(find.text('SKS Aktif'), findsOneWidget);

    // 2. Pindah ke Jadwal
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Jadwal'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Jadwal Kuliah'), findsOneWidget);

    // 3. Pindah ke Tugas & uji filter
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Tugas'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tugas Kuliah'), findsOneWidget);
    expect(find.textContaining('Mendatang'), findsWidgets);
    expect(find.textContaining('Terlambat'), findsWidgets);
    expect(find.textContaining('Selesai'), findsWidgets);

    // 4. Pindah ke Akademik
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Akademik'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Performa Akademik'), findsOneWidget);
    expect(find.text('Simulasi Nilai & Proyeksi IPS'), findsOneWidget);

    // 5. Pindah ke Profil
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Profil'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mahasiswa Demo'), findsOneWidget);
    expect(find.text('Skala Konversi Nilai Kampus'), findsOneWidget);
  });

  testWidgets('Rute sekunder Simulasi Nilai dan Tambah Tugas dapat dibuka', (
    tester,
  ) async {
    await pumpAppAtMobileViewport(tester);

    // Buka Simulasi Nilai dari aksi cepat di Beranda
    await tester.tap(find.text('Simulasi Nilai'));
    await tester.pumpAndSettle();
    expect(find.text('Proyeksi IPS'), findsOneWidget);
    expect(find.text('Proyeksi IPK'), findsOneWidget);

    // Kembali ke Beranda
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Buka Tambah Tugas dari aksi cepat di Beranda
    await tester.tap(find.text('Tambah Tugas'));
    await tester.pumpAndSettle();
    expect(find.text('Simpan Tugas'), findsOneWidget);
  });

  testWidgets('Rute sekunder Detail Mata Kuliah dapat dibuka dari Jadwal', (
    tester,
  ) async {
    final activeCourse = courseRepo.getActiveCourses().first;
    await pumpAppAtMobileViewport(
      tester,
      initialLocation: '/mata-kuliah/${activeCourse.id}',
    );
    expect(find.text(activeCourse.name), findsOneWidget);
    expect(find.text('Komponen Penilaian'), findsOneWidget);
  });
}
