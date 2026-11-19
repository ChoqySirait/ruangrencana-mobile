import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/widgets/app_shell_scaffold.dart';
import '../../features/academic/grades/presentation/views/academic_view.dart';
import '../../features/academic/simulator/presentation/views/grade_simulator_view.dart';
import '../../features/courses/presentation/views/course_detail_view.dart';
import '../../features/dashboard/presentation/views/dashboard_view.dart';
import '../../features/profile/presentation/views/profile_view.dart';
import '../../features/schedule/presentation/views/schedule_view.dart';
import '../../features/tasks/presentation/views/task_form_view.dart';
import '../../features/tasks/presentation/views/tasks_view.dart';

/// Daftar nama rute terpusat agar navigasi GoRouter tetap terprediksi
/// dan bebas dari salah ketik string.
abstract final class AppRoutes {
  // Destinasi utama (persistent bottom navigation)
  static const String beranda = 'beranda';
  static const String jadwal = 'jadwal';
  static const String tugas = 'tugas';
  static const String akademik = 'akademik';
  static const String profil = 'profil';

  // Rute sekunder
  static const String courseDetail = 'course-detail';
  static const String addTask = 'add-task';
  static const String editTask = 'edit-task';
  static const String gradeSimulation = 'grade-simulation';
}

/// Konfigurasi GoRouter untuk RuangRencana menggunakan [StatefulShellRoute]
/// agar state setiap tab tetap terjaga saat berpindah halaman.
abstract final class AppRouter {
  static GoRouter createRouter({String initialLocation = '/beranda'}) {
    final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: initialLocation,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return AppShellScaffold(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/beranda',
                  name: AppRoutes.beranda,
                  builder: (context, state) => const DashboardView(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/jadwal',
                  name: AppRoutes.jadwal,
                  builder: (context, state) => const ScheduleView(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/tugas',
                  name: AppRoutes.tugas,
                  builder: (context, state) => const TasksView(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/akademik',
                  name: AppRoutes.akademik,
                  builder: (context, state) => const AcademicView(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profil',
                  name: AppRoutes.profil,
                  builder: (context, state) => const ProfileView(),
                ),
              ],
            ),
          ],
        ),

        // Rute sekunder ditampilkan di atas shell (tanpa bottom navigation bar)
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/mata-kuliah/:courseId',
          name: AppRoutes.courseDetail,
          builder: (context, state) {
            final courseId = state.pathParameters['courseId'] ?? '';
            return CourseDetailView(courseId: courseId);
          },
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/tugas/tambah',
          name: AppRoutes.addTask,
          builder: (context, state) => const TaskFormView(),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/tugas/:taskId/edit',
          name: AppRoutes.editTask,
          builder: (context, state) {
            final taskId = state.pathParameters['taskId'] ?? '';
            return TaskFormView(taskId: taskId);
          },
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/akademik/simulasi-nilai',
          name: AppRoutes.gradeSimulation,
          builder: (context, state) => const GradeSimulatorView(),
        ),
      ],
    );
  }
}
