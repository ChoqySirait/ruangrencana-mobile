import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../features/academic/grades/data/repositories/academic_repository.dart';
import '../features/academic/grades/presentation/view_models/academic_view_model.dart';
import '../features/courses/data/repositories/course_repository.dart';
import '../features/dashboard/data/repositories/dashboard_repository.dart';
import '../features/dashboard/presentation/view_models/dashboard_view_model.dart';
import '../features/profile/data/repositories/profile_repository.dart';
import '../features/profile/presentation/view_models/profile_view_model.dart';
import '../features/schedule/data/repositories/schedule_repository.dart';
import '../features/schedule/presentation/view_models/schedule_view_model.dart';
import '../features/tasks/data/repositories/task_repository.dart';
import '../features/tasks/presentation/view_models/tasks_view_model.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Root widget aplikasi RuangRencana yang menyusun dependency injection
/// (Repository & ViewModel melalui Provider), tema Material 3, dan GoRouter.
class RuangRencanaApp extends StatefulWidget {
  const RuangRencanaApp({this.initialLocation = '/beranda', super.key});

  final String initialLocation;

  @override
  State<RuangRencanaApp> createState() => _RuangRencanaAppState();
}

class _RuangRencanaAppState extends State<RuangRencanaApp> {
  late final GoRouter _router;

  // Repositori in-memory pada tahap fondasi (akan diganti SQLite pada tahap berikutnya)
  late final CourseRepository _courseRepository;
  late final ScheduleRepository _scheduleRepository;
  late final TaskRepository _taskRepository;
  late final ProfileRepository _profileRepository;
  late final AcademicRepository _academicRepository;
  late final DashboardRepository _dashboardRepository;

  late final DashboardViewModel _dashboardViewModel;
  late final ScheduleViewModel _scheduleViewModel;
  late final TasksViewModel _tasksViewModel;
  late final AcademicViewModel _academicViewModel;
  late final ProfileViewModel _profileViewModel;

  @override
  void initState() {
    super.initState();
    _router = AppRouter.createRouter(initialLocation: widget.initialLocation);

    _courseRepository = InMemoryCourseRepository();
    _scheduleRepository = InMemoryScheduleRepository();
    _taskRepository = InMemoryTaskRepository();
    _profileRepository = InMemoryProfileRepository();
    _academicRepository = InMemoryAcademicRepository(
      courseRepository: _courseRepository,
    );
    _dashboardRepository = DefaultDashboardRepository(
      profileRepository: _profileRepository,
      scheduleRepository: _scheduleRepository,
      taskRepository: _taskRepository,
      academicRepository: _academicRepository,
    );

    _dashboardViewModel = DashboardViewModel(repository: _dashboardRepository);
    _scheduleViewModel = ScheduleViewModel(repository: _scheduleRepository);
    _tasksViewModel = TasksViewModel(
      repository: _taskRepository,
      onDataChanged: _dashboardViewModel.refresh,
    );
    _academicViewModel = AcademicViewModel(repository: _academicRepository);
    _profileViewModel = ProfileViewModel(
      repository: _profileRepository,
      onProfileChanged: _dashboardViewModel.refresh,
    );
  }

  @override
  void dispose() {
    _router.dispose();
    _dashboardViewModel.dispose();
    _scheduleViewModel.dispose();
    _tasksViewModel.dispose();
    _academicViewModel.dispose();
    _profileViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<CourseRepository>.value(value: _courseRepository),
        Provider<ScheduleRepository>.value(value: _scheduleRepository),
        Provider<TaskRepository>.value(value: _taskRepository),
        Provider<ProfileRepository>.value(value: _profileRepository),
        Provider<AcademicRepository>.value(value: _academicRepository),
        ChangeNotifierProvider<DashboardViewModel>.value(
          value: _dashboardViewModel,
        ),
        ChangeNotifierProvider<ScheduleViewModel>.value(
          value: _scheduleViewModel,
        ),
        ChangeNotifierProvider<TasksViewModel>.value(value: _tasksViewModel),
        ChangeNotifierProvider<AcademicViewModel>.value(
          value: _academicViewModel,
        ),
        ChangeNotifierProvider<ProfileViewModel>.value(
          value: _profileViewModel,
        ),
      ],
      child: MaterialApp.router(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router,
      ),
    );
  }
}
