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

/// Halaman Tugas Kuliah dengan fitur pencarian teks, filter status
/// (Semua, Mendatang, Terlambat, Selesai), pengurutan fleksibel,
/// akses ke Kalender Akademik, dan aksi CRUD tugas.
class TasksView extends StatefulWidget {
  const TasksView({super.key});

  @override
  State<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<TasksView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TasksViewModel>();
    final items = vm.filteredAssignments;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tugas Kuliah'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: 'Kalender Akademik',
            onPressed: () => context.pushNamed(AppRoutes.calendar),
          ),
          PopupMenuButton<AssignmentSort>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Urutkan Tugas',
            initialValue: vm.selectedSort,
            onSelected: (sort) => vm.setSort(sort),
            itemBuilder: (context) => AssignmentSort.values.map((sort) {
              final isSelected = vm.selectedSort == sort;
              return PopupMenuItem<AssignmentSort>(
                value: sort,
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 18,
                      color: isSelected
                          ? AppColors.secondaryTeal
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      sort.label,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isSelected
                            ? AppColors.secondaryTeal
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(AppRoutes.addTask),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Tugas'),
      ),
      body: Column(
        children: [
          // Bar Pencarian
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              AppSpacing.xs,
              AppSpacing.pageHorizontal,
              AppSpacing.xs,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari tugas, catatan, atau mata kuliah...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          vm.clearSearch();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.5),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.5),
                  ),
                ),
              ),
              onChanged: (query) => vm.setSearchQuery(query),
            ),
          ),

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

          // Daftar Tugas
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            vm.searchQuery.isNotEmpty
                                ? Icons.search_off_rounded
                                : Icons.task_alt_rounded,
                            size: 44,
                            color: AppColors.secondaryTeal,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            vm.searchQuery.isNotEmpty
                                ? 'Tugas Tidak Ditemukan'
                                : 'Belum Ada Tugas (${vm.selectedFilter.label})',
                            style: AppTextStyles.titleSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            vm.searchQuery.isNotEmpty
                                ? 'Tidak ada tugas yang cocok dengan "${vm.searchQuery}". Coba kata kunci lain.'
                                : 'Tekan tombol Tambah Tugas untuk mencatat tenggat kuliah baru.',
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
                          AppRoutes.taskDetail,
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
