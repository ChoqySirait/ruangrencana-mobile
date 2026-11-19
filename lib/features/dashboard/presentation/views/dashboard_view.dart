import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/info_badge.dart';
import '../../../../core/widgets/metric_summary_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../schedule/presentation/widgets/schedule_card.dart';
import '../../../tasks/presentation/view_models/tasks_view_model.dart';
import '../../../tasks/presentation/widgets/assignment_card.dart';
import '../view_models/dashboard_view_model.dart';

/// Halaman utama Beranda: menyajikan ringkasan semester aktif, IPS/IPK,
/// SKS aktif, kelas hari ini, tugas terdekat, indikator mendesak, dan aksi cepat.
class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final dashboardVm = context.watch<DashboardViewModel>();
    final tasksVm = context.read<TasksViewModel>();
    final summary = dashboardVm.summary;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageHorizontal,
            vertical: AppSpacing.pageVertical,
          ),
          children: [
            // Header sapaan & semester aktif
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${dashboardVm.greetingPrefix}, ${summary.greetingName}',
                        style: AppTextStyles.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      const Text(
                        AppConstants.tagline,
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                IconButton.filledTonal(
                  onPressed: () => context.goNamed(AppRoutes.profil),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primarySoft,
                    foregroundColor: AppColors.primaryNavy,
                  ),
                  icon: const Icon(Icons.person_outline_rounded),
                  tooltip: 'Buka Profil',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                InfoBadge(
                  label: summary.activeSemesterLabel,
                  tone: BadgeTone.primary,
                  icon: Icons.school_outlined,
                ),
                if (summary.urgentAssignmentCount > 0)
                  InfoBadge(
                    label: '${summary.urgentAssignmentCount} tugas mendesak',
                    tone: BadgeTone.warning,
                    icon: Icons.warning_amber_rounded,
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // Ringkasan IPS, IPK, dan SKS aktif
            Row(
              children: [
                Expanded(
                  child: MetricSummaryCard(
                    label: 'IPS Sementara',
                    value: summary.provisionalIps.toStringAsFixed(2),
                    subtitle: 'Semester aktif',
                    accentColor: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: MetricSummaryCard(
                    label: 'IPK Kumulatif',
                    value: summary.cumulativeIpk.toStringAsFixed(2),
                    subtitle: 'Semester selesai',
                    accentColor: AppColors.secondaryTeal,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: MetricSummaryCard(
                    label: 'SKS Aktif',
                    value: '${summary.activeSks}',
                    subtitle: '7 mata kuliah',
                    accentColor: AppColors.textPrimary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // Aksi cepat
            const SectionHeader(title: 'Aksi Cepat'),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.add_task_rounded,
                    label: 'Tambah Tugas',
                    onTap: () => context.pushNamed(AppRoutes.addTask),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.calculate_outlined,
                    label: 'Simulasi Nilai',
                    onTap: () => context.pushNamed(AppRoutes.gradeSimulation),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.calendar_month_outlined,
                    label: 'Lihat Jadwal',
                    onTap: () => context.goNamed(AppRoutes.jadwal),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // Jadwal kelas hari ini / terdekat
            SectionHeader(
              title:
                  'Kelas ${DateFormatter.fullDayName(summary.todayDayOfWeek)}',
              actionLabel: 'Semua jadwal',
              onActionTap: () => context.goNamed(AppRoutes.jadwal),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (summary.todaySchedules.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'Tidak ada jadwal kuliah untuk hari ini.',
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
              )
            else
              ...summary.todaySchedules.map(
                (schedule) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: ScheduleCard(
                    item: schedule,
                    onTap: () => context.pushNamed(
                      AppRoutes.courseDetail,
                      pathParameters: {'courseId': schedule.courseId},
                    ),
                  ),
                ),
              ),

            const SizedBox(height: AppSpacing.md),

            // Tugas mendatang & tenggat mendesak
            SectionHeader(
              title: 'Tugas Mendatang',
              actionLabel: 'Lihat semua',
              onActionTap: () => context.goNamed(AppRoutes.tugas),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (summary.upcomingAssignments.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'Semua tugas sudah selesai. Kerja bagus!',
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
              )
            else
              ...summary.upcomingAssignments.map(
                (task) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: AssignmentCard(
                    item: task,
                    onToggleComplete: () => tasksVm.toggleCompleted(task.id),
                    onTap: () => context.pushNamed(
                      AppRoutes.editTask,
                      pathParameters: {'taskId': task.id},
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(icon, size: 20, color: AppColors.primaryNavy),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
