import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/database/app_database.dart';
import '../core/database/database_seeder.dart';
import '../features/academic/grades/data/repositories/academic_repository.dart';
import '../features/academic/grades/presentation/view_models/academic_view_model.dart';
import '../features/academic/terms/presentation/view_models/semester_view_model.dart';
import '../features/courses/data/repositories/course_repository.dart';
import '../features/courses/presentation/view_models/courses_view_model.dart';
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
/// (Repository berbasis SQLite & ViewModel melalui Provider), tema Material 3, dan GoRouter.
class RuangRencanaApp extends StatefulWidget {
  const RuangRencanaApp({
    this.initialLocation = '/beranda',
    this.appDatabase,
    this.courseRepository,
    this.scheduleRepository,
    this.taskRepository,
    this.profileRepository,
    this.academicRepository,
    this.dashboardRepository,
    super.key,
  });

  final String initialLocation;
  final AppDatabase? appDatabase;
  final CourseRepository? courseRepository;
  final ScheduleRepository? scheduleRepository;
  final TaskRepository? taskRepository;
  final ProfileRepository? profileRepository;
  final AcademicRepository? academicRepository;
  final DashboardRepository? dashboardRepository;

  @override
  State<RuangRencanaApp> createState() => _RuangRencanaAppState();
}

class _RuangRencanaAppState extends State<RuangRencanaApp> {
  late final GoRouter _router;
  late final AppDatabase _appDatabase;

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
  late final SemesterViewModel _semesterViewModel;
  late final CoursesViewModel _coursesViewModel;

  @override
  void initState() {
    super.initState();
    _router = AppRouter.createRouter(initialLocation: widget.initialLocation);
    _appDatabase = widget.appDatabase ?? AppDatabase.instance;

    _courseRepository =
        widget.courseRepository ??
        SqliteCourseRepository(appDatabase: _appDatabase);
    _scheduleRepository =
        widget.scheduleRepository ??
        SqliteScheduleRepository(appDatabase: _appDatabase);
    _taskRepository =
        widget.taskRepository ??
        SqliteTaskRepository(appDatabase: _appDatabase);
    _profileRepository =
        widget.profileRepository ??
        SqliteProfileRepository(appDatabase: _appDatabase);
    _academicRepository =
        widget.academicRepository ??
        SqliteAcademicRepository(
          appDatabase: _appDatabase,
          courseRepository: _courseRepository,
        );

    _dashboardRepository =
        widget.dashboardRepository ??
        DefaultDashboardRepository(
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

    _semesterViewModel = SemesterViewModel(
      repository: _academicRepository,
      onActiveSemesterChanged: () async {
        await _courseRepository.load();
        await _scheduleRepository.load();
        await _academicRepository.load();
        if (mounted) {
          _academicViewModel.refresh();
          _dashboardViewModel.refresh();
          _scheduleViewModel.selectDay(_scheduleViewModel.selectedDayOfWeek);
          _coursesViewModel.loadCourses();
        }
      },
    );

    _coursesViewModel = CoursesViewModel(
      courseRepository: _courseRepository,
      academicRepository: _academicRepository,
      onCoursesChanged: () async {
        await _courseRepository.load();
        await _scheduleRepository.load();
        await _academicRepository.load();
        if (mounted) {
          _academicViewModel.refresh();
          _dashboardViewModel.refresh();
          _scheduleViewModel.selectDay(_scheduleViewModel.selectedDayOfWeek);
        }
      },
    );

    // Muat data awal jika repositori belum memiliki cache
    if (_courseRepository.getActiveCourses().isEmpty) {
      _loadInitialData();
    }
  }

  Future<void> _loadInitialData() async {
    try {
      final db = await _appDatabase.database;
      await DatabaseSeeder.seedIfNeeded(db);
      await _courseRepository.load();
      await _scheduleRepository.load();
      await _taskRepository.load();
      await _profileRepository.load();
      await _academicRepository.load();
      if (mounted) {
        _dashboardViewModel.refresh();
        _scheduleViewModel.selectDay(_scheduleViewModel.selectedDayOfWeek);
        _tasksViewModel.refresh();
        _academicViewModel.refresh();
        _profileViewModel.refresh();
        _semesterViewModel.refresh();
        _coursesViewModel.loadCourses();
      }
    } catch (_) {
      // Abaikan jika database ditangani oleh pengujian secara manual
    }
  }

  @override
  void dispose() {
    _router.dispose();
    _dashboardViewModel.dispose();
    _scheduleViewModel.dispose();
    _tasksViewModel.dispose();
    _academicViewModel.dispose();
    _profileViewModel.dispose();
    _semesterViewModel.dispose();
    _coursesViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: _appDatabase),
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
        ChangeNotifierProvider<SemesterViewModel>.value(
          value: _semesterViewModel,
        ),
        ChangeNotifierProvider<CoursesViewModel>.value(
          value: _coursesViewModel,
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
