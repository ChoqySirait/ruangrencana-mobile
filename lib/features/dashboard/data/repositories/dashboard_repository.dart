import '../../../academic/grades/data/repositories/academic_repository.dart';
import '../../../profile/data/repositories/profile_repository.dart';
import '../../../schedule/data/repositories/schedule_repository.dart';
import '../../../tasks/data/repositories/task_repository.dart';
import '../models/dashboard_summary.dart';

/// Kontrak agregasi data untuk halaman Beranda.
abstract class DashboardRepository {
  DashboardSummary loadDashboard({DateTime? referenceTime});
}

/// Implementasi default yang menggabungkan ringkasan profil, jadwal,
/// tugas, dan nilai akademik secara terintegrasi.
class DefaultDashboardRepository implements DashboardRepository {
  DefaultDashboardRepository({
    required this._profileRepository,
    required this._scheduleRepository,
    required this._taskRepository,
    required this._academicRepository,
  });

  final ProfileRepository _profileRepository;
  final ScheduleRepository _scheduleRepository;
  final TaskRepository _taskRepository;
  final AcademicRepository _academicRepository;

  @override
  DashboardSummary loadDashboard({DateTime? referenceTime}) {
    final now = referenceTime ?? DateTime.now();
    final profile = _profileRepository.getProfile();
    final academic = _academicRepository.getAcademicOverview();

    // Jika hari Minggu (7), tampilkan jadwal Senin (1) sebagai kelas terdekat.
    final displayDay = now.weekday == DateTime.sunday
        ? DateTime.monday
        : now.weekday;
    var todaySchedules = _scheduleRepository.getSchedulesForDay(displayDay);
    if (todaySchedules.isEmpty) {
      todaySchedules = _scheduleRepository.getSchedulesForDay(DateTime.monday);
    }

    final activeTasks = _taskRepository
        .getAllAssignments()
        .where((task) => !task.isCompleted)
        .toList(growable: false);

    final urgentCount = activeTasks
        .where((task) => task.isUrgentAt(now))
        .length;

    return DashboardSummary(
      greetingName: profile.firstName,
      activeSemesterLabel:
          '${profile.activeSemesterLabel} • ${profile.academicYear}',
      provisionalIps: academic.provisionalIps,
      cumulativeIpk: academic.cumulativeIpk,
      activeSks: academic.activeSks,
      todayDayOfWeek: todaySchedules.isNotEmpty
          ? todaySchedules.first.dayOfWeek
          : displayDay,
      todaySchedules: todaySchedules,
      upcomingAssignments: activeTasks.take(3).toList(growable: false),
      urgentAssignmentCount: urgentCount,
    );
  }
}
