import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../data/models/assignment_item.dart';
import '../view_models/tasks_view_model.dart';
import '../widgets/assignment_card.dart';

/// Halaman Tugas dengan filter Semua, Mendatang, Terlambat, Selesai,
/// daftar tugas, serta tombol tambah tugas baru.
class TasksView extends StatelessWidget {
  const TasksView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TasksViewModel>();
    final items = vm.filteredAssignments;

    return Scaffold(
      appBar: AppBar(title: const Text('Tugas Kuliah')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(AppRoutes.addTask),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Tugas'),
      ),
      body: Column(
        children: [
          // Filter chip horizontal
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageHorizontal,
              ),
              itemCount: AssignmentFilter.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, index) {
                final filter = AssignmentFilter.values[index];
                final isSelected = vm.selectedFilter == filter;
                final count = vm.countForFilter(filter);
                return ChoiceChip(
                  selected: isSelected,
                  showCheckmark: false,
                  label: Text('${filter.label} ($count)'),
                  labelStyle: AppTextStyles.labelMedium.copyWith(
                    color: isSelected
                        ? AppColors.textOnPrimary
                        : AppColors.textPrimary,
                  ),
                  selectedColor: AppColors.primaryNavy,
                  backgroundColor: AppColors.surface,
                  onSelected: (_) => vm.setFilter(filter),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.task_alt_rounded,
                            size: 40,
                            color: AppColors.secondaryTeal,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Belum ada tugas pada filter "${vm.selectedFilter.label}"',
                            style: AppTextStyles.titleSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          const Text(
                            'Tekan tombol Tambah Tugas untuk mencatat tenggat baru.',
                            style: AppTextStyles.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageHorizontal,
                      AppSpacing.xs,
                      AppSpacing.pageHorizontal,
                      AppSpacing.xxl * 2,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final task = items[index];
                      return AssignmentCard(
                        item: task,
                        onToggleComplete: () => vm.toggleCompleted(task.id),
                        onTap: () => context.pushNamed(
                          AppRoutes.editTask,
                          pathParameters: {'taskId': task.id},
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
