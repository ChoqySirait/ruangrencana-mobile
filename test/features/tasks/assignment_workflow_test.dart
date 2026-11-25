import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruangrencana/core/database/app_database.dart';
import 'package:ruangrencana/core/database/database_seeder.dart';
import 'package:ruangrencana/features/courses/data/repositories/course_repository.dart';
import 'package:ruangrencana/features/tasks/data/models/assignment_item.dart';
import 'package:ruangrencana/features/tasks/data/repositories/task_repository.dart';
import 'package:ruangrencana/features/tasks/presentation/view_models/tasks_view_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Alur Kerja Manajemen Tugas (SQLite & ViewModel)', () {
    late Directory tempDir;
    late String dbFilePath;
    late AppDatabase appDb;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'ruangrencana_task_test_',
      );
      dbFilePath = '${tempDir.path}${Platform.pathSeparator}test_tasks.db';
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

    test('Operasi CRUD Tugas, Persistensi SQLite, dan Perubahan Status Penyelesaian', () async {
      final db = await appDb.open(customPath: dbFilePath);
      await DatabaseSeeder.seedIfNeeded(db);

      final courseRepo = SqliteCourseRepository(appDatabase: appDb);
      final taskRepo = SqliteTaskRepository(appDatabase: appDb);
      await courseRepo.load();
      await taskRepo.load();

      final activeCourses = courseRepo.getActiveCourses();
      expect(activeCourses.isNotEmpty, isTrue);
      final targetCourse = activeCourses.first;

      final vm = TasksViewModel(repository: taskRepo);

      // 1. Tambah tugas baru
      final dueDate = DateTime.now().add(const Duration(days: 3));
      await vm.saveNewAssignment(
        title: 'Tugas Akhir Kecerdasan Buatan',
        courseId: targetCourse.id,
        courseName: targetCourse.name,
        courseCode: targetCourse.code,
        dueDate: dueDate,
        priority: AssignmentPriority.high,
        notes: 'Implementasi algoritma A* dan Minimax.',
      );

      final allTasks = vm.allAssignments;
      final added = allTasks.firstWhere(
        (t) => t.title == 'Tugas Akhir Kecerdasan Buatan',
      );
      expect(added.courseId, targetCourse.id);
      expect(added.courseCode, targetCourse.code);
      expect(added.priority, AssignmentPriority.high);
      expect(added.isCompleted, isFalse);
      expect(added.notes, 'Implementasi algoritma A* dan Minimax.');

      // 2. Tandai selesai (Complete)
      await vm.markCompleted(added.id);
      final completedItem = vm.findById(added.id);
      expect(completedItem, isNotNull);
      expect(completedItem!.isCompleted, isTrue);
      expect(completedItem.completedAt, isNotNull);

      // 3. Buka kembali tugas (Reopen)
      await vm.reopenAssignment(added.id);
      final reopenedItem = vm.findById(added.id);
      expect(reopenedItem, isNotNull);
      expect(reopenedItem!.isCompleted, isFalse);
      expect(reopenedItem.completedAt, isNull);

      // 4. Ubah tugas (Edit)
      final newDueDate = DateTime.now().add(const Duration(days: 5));
      await vm.saveEditedAssignment(
        reopenedItem.copyWith(
          title: 'Tugas Akhir AI - Revisi',
          priority: AssignmentPriority.medium,
          dueDate: newDueDate,
        ),
      );

      final editedItem = vm.findById(added.id);
      expect(editedItem!.title, 'Tugas Akhir AI - Revisi');
      expect(editedItem.priority, AssignmentPriority.medium);

      // 5. Persistensi antar siklus hidup restart DB
      await appDb.close();
      final reopenedDb = await appDb.open(customPath: dbFilePath);
      expect(reopenedDb.isOpen, isTrue);

      final freshTaskRepo = SqliteTaskRepository(appDatabase: appDb);
      await freshTaskRepo.load();
      final freshItem = freshTaskRepo.getAssignmentById(added.id);
      expect(freshItem, isNotNull);
      expect(freshItem!.title, 'Tugas Akhir AI - Revisi');
      expect(freshItem.priority, AssignmentPriority.medium);

      // 6. Hapus tugas (Delete)
      await freshTaskRepo.deleteAssignment(added.id);
      expect(freshTaskRepo.getAssignmentById(added.id), isNull);
    });

    test('Pencarian, Filter Status Dinamis, dan Pengurutan Tugas', () async {
      final db = await appDb.open(customPath: dbFilePath);
      await DatabaseSeeder.seedIfNeeded(db);

      final courseRepo = SqliteCourseRepository(appDatabase: appDb);
      final taskRepo = SqliteTaskRepository(appDatabase: appDb);
      await courseRepo.load();
      await taskRepo.load();

      final vm = TasksViewModel(repository: taskRepo);
      final now = DateTime.now();

      // Tambahkan beberapa tugas dengan berbagai tenggat dan prioritas
      await vm.saveNewAssignment(
        title: 'Praktikum Jaringan Client Server',
        courseId: '1',
        courseName: 'Jaringan Komputer',
        courseCode: 'JK101',
        dueDate: now.subtract(const Duration(days: 2)), // Overdue
        priority: AssignmentPriority.low,
      );

      await vm.saveNewAssignment(
        title: 'Makalah Etika Profesi',
        courseId: '1',
        courseName: 'Etika Profesi',
        courseCode: 'EP202',
        dueDate: now.add(const Duration(days: 1)), // Upcoming
        priority: AssignmentPriority.high,
      );

      // 1. Pengujian Pencarian
      vm.setSearchQuery('Makalah');
      expect(
        vm.filteredAssignments.any((t) => t.title.contains('Makalah')),
        isTrue,
      );
      expect(
        vm.filteredAssignments.every(
          (t) =>
              t.title.contains('Makalah') || t.courseName.contains('Makalah'),
        ),
        isTrue,
      );
      vm.clearSearch();

      // 2. Pengujian Filter Status
      vm.setFilter(AssignmentFilter.overdue);
      for (final t in vm.filteredAssignments) {
        expect(t.statusAt(now), AssignmentStatus.overdue);
      }

      vm.setFilter(AssignmentFilter.upcoming);
      for (final t in vm.filteredAssignments) {
        expect(t.statusAt(now), AssignmentStatus.upcoming);
      }

      vm.setFilter(AssignmentFilter.all);

      // 3. Pengujian Pengurutan
      // Tenggat Terdekat
      vm.setSort(AssignmentSort.dueSoonest);
      final sortedByDue = vm.filteredAssignments;
      for (var i = 0; i < sortedByDue.length - 1; i++) {
        expect(
          sortedByDue[i].dueDate.isBefore(sortedByDue[i + 1].dueDate) ||
              sortedByDue[i].dueDate.isAtSameMomentAs(
                sortedByDue[i + 1].dueDate,
              ),
          isTrue,
        );
      }

      // Prioritas Tertinggi
      vm.setSort(AssignmentSort.priorityHighest);
      final sortedByPriority = vm.filteredAssignments;
      for (var i = 0; i < sortedByPriority.length - 1; i++) {
        expect(
          sortedByPriority[i].priority.rank >=
              sortedByPriority[i + 1].priority.rank,
          isTrue,
        );
      }
    });

    test(
      'Validasi Dinamis Overdue Status Tanpa Ketergantungan Status Permanen',
      () {
        final now = DateTime.now();

        final overdueItem = AssignmentItem(
          id: '1',
          title: 'Tugas Lampau',
          courseId: '1',
          courseName: 'Basis Data',
          dueDate: now.subtract(const Duration(hours: 1)),
          priority: AssignmentPriority.medium,
          isCompleted: false,
        );
        expect(overdueItem.statusAt(now), AssignmentStatus.overdue);
        expect(overdueItem.isOverdueAt(now), isTrue);

        final completedItem = overdueItem.copyWith(isCompleted: true);
        expect(completedItem.statusAt(now), AssignmentStatus.completed);
        expect(completedItem.isOverdueAt(now), isFalse);

        final futureItem = AssignmentItem(
          id: '2',
          title: 'Tugas Masa Depan',
          courseId: '1',
          courseName: 'Basis Data',
          dueDate: now.add(const Duration(days: 2)),
          priority: AssignmentPriority.high,
          isCompleted: false,
        );
        expect(futureItem.statusAt(now), AssignmentStatus.upcoming);
        expect(futureItem.isOverdueAt(now), isFalse);
      },
    );
  });
}
