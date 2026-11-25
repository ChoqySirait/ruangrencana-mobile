import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/info_badge.dart';
import '../../../schedule/data/repositories/schedule_repository.dart';
import '../../../tasks/data/models/assignment_item.dart';
import '../../../tasks/data/repositories/task_repository.dart';
import '../view_models/calendar_view_model.dart';

/// Halaman Kalender Akademik yang mengintegrasikan jadwal perkuliahan
/// dan tenggat tugas kuliah dalam satu tampilan bulanan interaktif.
class CalendarView extends StatelessWidget {
  const CalendarView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => CalendarViewModel(
        taskRepository: ctx.read<TaskRepository>(),
        scheduleRepository: ctx.read<ScheduleRepository>(),
      ),
      child: const _CalendarViewContent(),
    );
  }
}

class _CalendarViewContent extends StatelessWidget {
  const _CalendarViewContent();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CalendarViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalender Akademik'),
        actions: [
          TextButton.icon(
            onPressed: () => vm.goToToday(),
            icon: const Icon(Icons.today_rounded, size: 18),
            label: const Text('Hari Ini'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kontrol Bulan & Tahun
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded),
                          tooltip: 'Bulan Sebelumnya',
                          onPressed: () => vm.previousMonth(),
                        ),
                        Text(
                          vm.focusedMonthName,
                          style: AppTextStyles.titleMedium,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded),
                          tooltip: 'Bulan Berikutnya',
                          onPressed: () => vm.nextMonth(),
                        ),
                      ],
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.xs),

                    // Baris Nama Hari (Senin - Minggu)
                    _buildWeekdayHeader(),
                    const SizedBox(height: AppSpacing.xs),

                    // Grid Hari dalam Bulan
                    _buildCalendarGrid(context, vm),

                    const SizedBox(height: AppSpacing.xs),
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.xs),

                    // Legenda Indikator
                    _buildLegend(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Header Aktivitas Hari Terpilih
            Row(
              children: [
                const Icon(
                  Icons.event_note_rounded,
                  size: 20,
                  color: AppColors.primaryNavy,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Aktivitas: ${DateFormatter.fullDate(vm.selectedDate)}',
                    style: AppTextStyles.titleSmall,
                  ),
                ),
                if (vm.totalEventsOnSelectedDate > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${vm.totalEventsOnSelectedDate} Kegiatan',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.secondaryTeal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Daftar Kegiatan pada Hari Terpilih
            _buildSelectedDateActivities(context, vm),

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekdayHeader() {
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return Row(
      children: days.map((day) {
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarGrid(BuildContext context, CalendarViewModel vm) {
    final firstDayOfMonth = vm.focusedMonth;
    final totalDaysInMonth = DateTime(
      firstDayOfMonth.year,
      firstDayOfMonth.month + 1,
      0,
    ).day;
    final startWeekday = firstDayOfMonth.weekday; // 1 = Senin ... 7 = Minggu

    // Hari dari bulan sebelumnya untuk padding awal
    final prevMonthLastDay = DateTime(
      firstDayOfMonth.year,
      firstDayOfMonth.month,
      0,
    ).day;
    final leadDays = startWeekday - 1;

    // Total sel: kelipatan 7
    final totalCells = ((leadDays + totalDaysInMonth + 6) ~/ 7) * 7;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(
      vm.selectedDate.year,
      vm.selectedDate.month,
      vm.selectedDate.day,
    );

    final rows = <Widget>[];

    for (var week = 0; week < totalCells / 7; week++) {
      final weekCells = <Widget>[];

      for (var day = 0; day < 7; day++) {
        final index = week * 7 + day;
        DateTime cellDate;
        bool isCurrentMonth = true;

        if (index < leadDays) {
          final dayNum = prevMonthLastDay - leadDays + index + 1;
          cellDate = DateTime(
            firstDayOfMonth.year,
            firstDayOfMonth.month - 1,
            dayNum,
          );
          isCurrentMonth = false;
        } else if (index >= leadDays + totalDaysInMonth) {
          final dayNum = index - (leadDays + totalDaysInMonth) + 1;
          cellDate = DateTime(
            firstDayOfMonth.year,
            firstDayOfMonth.month + 1,
            dayNum,
          );
          isCurrentMonth = false;
        } else {
          final dayNum = index - leadDays + 1;
          cellDate = DateTime(
            firstDayOfMonth.year,
            firstDayOfMonth.month,
            dayNum,
          );
        }

        final isSelected =
            cellDate.year == selected.year &&
            cellDate.month == selected.month &&
            cellDate.day == selected.day;
        final isToday =
            cellDate.year == today.year &&
            cellDate.month == today.month &&
            cellDate.day == today.day;

        final hasClasses = vm.hasClassesOnDate(cellDate);
        final hasAssignments = vm.hasAssignmentsOnDate(cellDate);

        weekCells.add(
          Expanded(
            child: InkWell(
              onTap: () => vm.selectDate(cellDate),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 1),
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryNavy
                      : isToday
                      ? AppColors.secondaryTeal.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isToday && !isSelected
                      ? Border.all(color: AppColors.secondaryTeal, width: 1.5)
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${cellDate.day}',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: isSelected || isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? Colors.white
                            : isCurrentMonth
                            ? AppColors.textPrimary
                            : AppColors.textSecondary.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: 6,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (hasClasses)
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.secondaryTeal,
                              ),
                            ),
                          if (hasAssignments)
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.warning,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(children: weekCells),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildLegend() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondaryTeal,
              ),
            ),
            const SizedBox(width: 4),
            const Text('Jadwal Kuliah', style: AppTextStyles.bodySmall),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 4),
            const Text('Tenggat Tugas', style: AppTextStyles.bodySmall),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectedDateActivities(
    BuildContext context,
    CalendarViewModel vm,
  ) {
    final schedules = vm.selectedDateSchedules;
    final assignments = vm.selectedDateAssignments;

    if (schedules.isEmpty && assignments.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: Column(
              children: [
                const Icon(
                  Icons.event_available_rounded,
                  size: 40,
                  color: AppColors.secondaryTeal,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Tidak Ada Agenda Kuliah',
                  style: AppTextStyles.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                const Text(
                  'Tidak ada jadwal kelas mingguan maupun tenggat tugas pada tanggal ini.',
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Daftar Jadwal Kuliah
        if (schedules.isNotEmpty) ...[
          Text(
            'Jadwal Kuliah (${schedules.length})',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.secondaryTeal,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ...schedules.map((schedule) {
            return Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.school_outlined,
                    color: AppColors.secondaryTeal,
                    size: 20,
                  ),
                ),
                title: Text(
                  '${schedule.courseCode} — ${schedule.courseName}',
                  style: AppTextStyles.labelLarge,
                ),
                subtitle: Text(
                  '${schedule.timeRange} • ${schedule.room} • ${schedule.sks} SKS',
                  style: AppTextStyles.bodySmall,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.pushNamed(
                  AppRoutes.courseDetail,
                  pathParameters: {'courseId': schedule.courseId},
                ),
              ),
            );
          }),
          const SizedBox(height: AppSpacing.sm),
        ],

        // Daftar Tenggat Tugas
        if (assignments.isNotEmpty) ...[
          Text(
            'Tenggat Tugas (${assignments.length})',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ...assignments.map((assignment) {
            final now = DateTime.now();
            final status = assignment.statusAt(now);
            final statusTone = switch (status) {
              AssignmentStatus.upcoming => BadgeTone.primary,
              AssignmentStatus.overdue => BadgeTone.error,
              AssignmentStatus.completed => BadgeTone.secondary,
            };

            return Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.warningSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    assignment.isCompleted
                        ? Icons.check_circle_outline_rounded
                        : Icons.assignment_outlined,
                    color: assignment.isCompleted
                        ? AppColors.secondaryTeal
                        : AppColors.warning,
                    size: 20,
                  ),
                ),
                title: Text(
                  assignment.title,
                  style: AppTextStyles.labelLarge.copyWith(
                    decoration: assignment.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                subtitle: Text(
                  '${assignment.courseName} • Pk ${DateFormatter.timeOnly(assignment.dueDate)}',
                  style: AppTextStyles.bodySmall,
                ),
                trailing: InfoBadge(label: status.label, tone: statusTone),
                onTap: () => context.pushNamed(
                  AppRoutes.taskDetail,
                  pathParameters: {'taskId': assignment.id},
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}
