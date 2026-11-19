import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'core/database/app_database.dart';
import 'core/database/database_seeder.dart';
import 'features/academic/grades/data/repositories/academic_repository.dart';
import 'features/courses/data/repositories/course_repository.dart';
import 'features/dashboard/data/repositories/dashboard_repository.dart';
import 'features/profile/data/repositories/profile_repository.dart';
import 'features/schedule/data/repositories/schedule_repository.dart';
import 'features/tasks/data/repositories/task_repository.dart';

/// Titik masuk utama (entry point) aplikasi RuangRencana.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Buka database SQLite lokal dan jalankan seeding idempotent jika diperlukan
  final appDb = AppDatabase.instance;
  final db = await appDb.open();
  await DatabaseSeeder.seedIfNeeded(db);

  // 2. Inisialisasi repositori berbasis SQLite
  final courseRepo = SqliteCourseRepository(appDatabase: appDb);
  final schedRepo = SqliteScheduleRepository(appDatabase: appDb);
  final taskRepo = SqliteTaskRepository(appDatabase: appDb);
  final profileRepo = SqliteProfileRepository(appDatabase: appDb);
  final academicRepo = SqliteAcademicRepository(
    appDatabase: appDb,
    courseRepository: courseRepo,
  );

  // 3. Muat data awal ke memori repositori secara berurutan
  await courseRepo.load();
  await schedRepo.load();
  await taskRepo.load();
  await profileRepo.load();
  await academicRepo.load();

  final dashboardRepo = DefaultDashboardRepository(
    profileRepository: profileRepo,
    scheduleRepository: schedRepo,
    taskRepository: taskRepo,
    academicRepository: academicRepo,
  );

  runApp(
    RuangRencanaApp(
      appDatabase: appDb,
      courseRepository: courseRepo,
      scheduleRepository: schedRepo,
      taskRepository: taskRepo,
      profileRepository: profileRepo,
      academicRepository: academicRepo,
      dashboardRepository: dashboardRepo,
    ),
  );
}
