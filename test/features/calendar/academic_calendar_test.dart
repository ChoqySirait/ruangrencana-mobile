import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruangrencana/core/database/app_database.dart';
import 'package:ruangrencana/core/database/database_seeder.dart';
import 'package:ruangrencana/features/calendar/presentation/view_models/calendar_view_model.dart';
import 'package:ruangrencana/features/schedule/data/repositories/schedule_repository.dart';
import 'package:ruangrencana/features/tasks/data/models/assignment_item.dart';
import 'package:ruangrencana/features/tasks/data/repositories/task_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Integrasi Kalender Akademik (SQLite & CalendarViewModel)', () {
    late Directory tempDir;
    late String dbFilePath;
    late AppDatabase appDb;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ruangrencana_cal_test_');
      dbFilePath = '${tempDir.path}${Platform.pathSeparator}test_cal.db';
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

    test('Navigasi Kalender, Sinkronisasi Bulan & Tanggal, dan Lompatan ke Hari Ini', () {
      final taskRepo = InMemoryTaskRepository();
      final scheduleRepo = SqliteScheduleRepository(appDatabase: appDb);

      final referenceDate = DateTime(2026, 11, 23);
      final vm = CalendarViewModel(
        taskRepository: taskRepo,
        scheduleRepository: scheduleRepo,
        initialDate: referenceDate,
      );

      expect(vm.focusedMonth.month, 11);
      expect(vm.focusedMonth.year, 2026);
      expect(vm.selectedDate, DateTime(2026, 11, 23));
      expect(vm.focusedMonthName, 'November 2026');

      // Pindah bulan berikutnya
      vm.nextMonth();
      expect(vm.focusedMonth.month, 12);
      expect(vm.focusedMonth.year, 2026);
      expect(vm.focusedMonthName, 'Desember 2026');

      // Pindah bulan sebelumnya (2 kali)
      vm.previousMonth();
      vm.previousMonth();
      expect(vm.focusedMonth.month, 10);
      expect(vm.focusedMonth.year, 2026);
      expect(vm.focusedMonthName, 'Oktober 2026');

      // Pilih tanggal di luar bulan aktif
      vm.selectDate(DateTime(2026, 9, 15));
      expect(vm.selectedDate, DateTime(2026, 9, 15));
      expect(vm.focusedMonth.month, 9);
      expect(vm.focusedMonth.year, 2026);

      // Lompat ke hari ini
      vm.goToToday();
      final now = DateTime.now();
      expect(vm.selectedDate.year, now.year);
      expect(vm.selectedDate.month, now.month);
      expect(vm.selectedDate.day, now.day);
    });

    test(
      'Integrasi Jadwal Kelas Mingguan dan Tenggat Tugas Tanpa Duplikasi Data',
      () async {
        final db = await appDb.open(customPath: dbFilePath);
        await DatabaseSeeder.seedIfNeeded(db);

        final scheduleRepo = SqliteScheduleRepository(appDatabase: appDb);
        final taskRepo = SqliteTaskRepository(appDatabase: appDb);
        await scheduleRepo.load();
        await taskRepo.load();

        // Pilih hari Senin (Senin 23 Nov 2026)
        final testMonday = DateTime(2026, 11, 23);
        expect(testMonday.weekday, 1); // Senin

        // Tambahkan tugas yang jatuh tempo pada testMonday
        await taskRepo.addAssignment(
          AssignmentItem(
            id: 'test-cal-1',
            title: 'Tugas Kalender Khusus',
            courseId: '1',
            courseName: 'Basis Data Lanjut',
            dueDate: DateTime(2026, 11, 23, 14, 0),
            priority: AssignmentPriority.high,
          ),
        );

        final vm = CalendarViewModel(
          taskRepository: taskRepo,
          scheduleRepository: scheduleRepo,
          initialDate: testMonday,
        );

        // Verifikasi jadwal kelas pada hari Senin
        final mondayClasses = vm.getSchedulesForDate(testMonday);
        expect(mondayClasses.isNotEmpty, isTrue);
        expect(vm.hasClassesOnDate(testMonday), isTrue);

        // Verifikasi tugas pada tanggal tersebut
        final mondayTasks = vm.getAssignmentsForDate(testMonday);
        expect(
          mondayTasks.any((t) => t.title == 'Tugas Kalender Khusus'),
          isTrue,
        );
        expect(vm.hasAssignmentsOnDate(testMonday), isTrue);

        // Verifikasi selectedDate
        expect(vm.selectedDateSchedules.length, mondayClasses.length);
        expect(vm.selectedDateAssignments.length, mondayTasks.length);
        expect(
          vm.totalEventsOnSelectedDate,
          mondayClasses.length + mondayTasks.length,
        );

        // Hari Minggu (bebas kelas jika hari 7 tidak ada jadwal di seeder)
        final testSunday = DateTime(2026, 11, 29);
        expect(testSunday.weekday, 7);
        final sundayClasses = vm.getSchedulesForDate(testSunday);
        expect(sundayClasses.isEmpty, isTrue);
      },
    );
  });
}
