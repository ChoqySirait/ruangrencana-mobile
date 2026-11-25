import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/info_badge.dart';
import '../view_models/schedule_view_model.dart';
import '../widgets/schedule_card.dart';

/// Halaman Jadwal Kuliah dengan pemilih hari mingguan dan daftar kartu kelas.
class ScheduleView extends StatelessWidget {
  const ScheduleView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ScheduleViewModel>();
    final schedules = vm.schedulesForSelectedDay;
    final selectedDayName = DateFormatter.fullDayName(vm.selectedDayOfWeek);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Kuliah'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: 'Kalender Akademik',
            onPressed: () => context.pushNamed(AppRoutes.calendar),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal,
          vertical: AppSpacing.xs,
        ),
        children: [
          // Pemilih hari mingguan (Sen - Sab)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Row(
                children: ScheduleViewModel.activeDays.map((day) {
                  final isSelected = day == vm.selectedDayOfWeek;
                  final classCount = vm.classCountForDay(day);
                  return Expanded(
                    child: InkWell(
                      onTap: () => vm.selectDay(day),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryNavy
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormatter.shortDayName(day),
                              style: AppTextStyles.labelMedium.copyWith(
                                color: isSelected
                                    ? AppColors.textOnPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: classCount > 0
                                    ? (isSelected
                                          ? AppColors.secondarySoft
                                          : AppColors.secondaryTeal)
                                    : Colors.transparent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Informasi hari terpilih
          Row(
            children: [
              Expanded(
                child: Text(selectedDayName, style: AppTextStyles.titleLarge),
              ),
              InfoBadge(
                label:
                    '${schedules.length} kelas • ${vm.totalSksForSelectedDay} SKS',
                tone: BadgeTone.primary,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          if (schedules.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    const Icon(
                      Icons.event_available_outlined,
                      size: 36,
                      color: AppColors.secondaryTeal,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Tidak ada kelas pada hari $selectedDayName',
                      style: AppTextStyles.titleSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    const Text(
                      'Manfaatkan waktu kosong ini untuk menyelesaikan tugas atau meninjau materi kuliah.',
                      style: AppTextStyles.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ...schedules.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ScheduleCard(
                  item: item,
                  onTap: () => context.pushNamed(
                    AppRoutes.courseDetail,
                    pathParameters: {'courseId': item.courseId},
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
