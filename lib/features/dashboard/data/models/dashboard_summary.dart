import '../../../schedule/data/models/schedule_item.dart';
import '../../../tasks/data/models/assignment_item.dart';

/// Ringkasan teragregasi untuk halaman utama Beranda.
class DashboardSummary {
  const DashboardSummary({
    required this.greetingName,
    required this.activeSemesterLabel,
    required this.provisionalIps,
    required this.cumulativeIpk,
    required this.activeSks,
    required this.todayDayOfWeek,
    required this.todaySchedules,
    required this.upcomingAssignments,
    required this.urgentAssignmentCount,
  });

  final String greetingName;
  final String activeSemesterLabel;
  final double provisionalIps;
  final double cumulativeIpk;
  final int activeSks;
  final int todayDayOfWeek;
  final List<ScheduleItem> todaySchedules;
  final List<AssignmentItem> upcomingAssignments;
  final int urgentAssignmentCount;
}
