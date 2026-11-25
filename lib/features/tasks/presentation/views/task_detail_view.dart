import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/info_badge.dart';
import '../../data/models/assignment_item.dart';
import '../view_models/tasks_view_model.dart';

/// Halaman detail tugas yang menampilkan informasi lengkap tugas,
/// tenggat waktu, prioritas, status, catatan deskripsi, serta aksi
/// penyelesaian, pengubahan, dan penghapusan tugas.
class TaskDetailView extends StatelessWidget {
  const TaskDetailView({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TasksViewModel>();
    final task = vm.findById(taskId);

    if (task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Tugas')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.search_off_rounded,
                  size: 48,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Tugas Tidak Ditemukan',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Data tugas mungkin telah dihapus atau tidak tersedia.',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.tonal(
                  onPressed: () => context.pop(),
                  child: const Text('Kembali ke Daftar Tugas'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final now = DateTime.now();
    final status = task.statusAt(now);
    final isUrgent = task.isUrgentAt(now);

    final statusTone = switch (status) {
      AssignmentStatus.upcoming => BadgeTone.primary,
      AssignmentStatus.overdue => BadgeTone.error,
      AssignmentStatus.completed => BadgeTone.secondary,
    };

    final priorityTone = switch (task.priority) {
      AssignmentPriority.high => BadgeTone.error,
      AssignmentPriority.medium => BadgeTone.warning,
      AssignmentPriority.low => BadgeTone.neutral,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Tugas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Ubah Tugas',
            onPressed: () => context.pushNamed(
              AppRoutes.editTask,
              pathParameters: {'taskId': task.id},
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            tooltip: 'Hapus Tugas',
            onPressed: () => _confirmDelete(context, vm, task),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: task.isCompleted
                    ? OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryNavy,
                          side: const BorderSide(color: AppColors.primaryNavy),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => vm.reopenAssignment(task.id),
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('Buka Kembali Tugas'),
                      )
                    : FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.secondaryTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => vm.markCompleted(task.id),
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('Tandai Selesai'),
                      ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kartu status & judul
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xxs,
                      children: [
                        InfoBadge(label: status.label, tone: statusTone),
                        InfoBadge(
                          label: 'Prioritas ${task.priority.label}',
                          tone: priorityTone,
                        ),
                        if (isUrgent && status != AssignmentStatus.overdue)
                          const InfoBadge(
                            label: 'Mendesak',
                            tone: BadgeTone.warning,
                            icon: Icons.priority_high_rounded,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      task.title,
                      style: AppTextStyles.titleMedium.copyWith(
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        const Icon(
                          Icons.school_outlined,
                          size: 16,
                          color: AppColors.secondaryTeal,
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Expanded(
                          child: Text(
                            task.courseCode.isNotEmpty
                                ? '${task.courseCode} — ${task.courseName}'
                                : task.courseName,
                            style: AppTextStyles.labelLarge.copyWith(
                              color: AppColors.secondaryTeal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Kartu Informasi Tenggat Waktu
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tenggat Waktu', style: AppTextStyles.titleSmall),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 20,
                          color: status == AssignmentStatus.overdue
                              ? AppColors.error
                              : AppColors.primaryNavy,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormatter.fullDateWithTime(task.dueDate),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: status == AssignmentStatus.overdue
                                      ? AppColors.error
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${task.remainingTimeText(now)} • Berdasarkan waktu lokal',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: status == AssignmentStatus.overdue
                                      ? AppColors.error
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Deskripsi / Catatan Tugas
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Catatan / Deskripsi',
                      style: AppTextStyles.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (task.notes.trim().isEmpty)
                      const Text(
                        'Tidak ada deskripsi tambahan untuk tugas ini.',
                        style: AppTextStyles.bodySmall,
                      )
                    else
                      Text(task.notes, style: AppTextStyles.bodyMedium),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Kartu Riwayat Waktu
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Informasi Catatan', style: AppTextStyles.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    if (task.createdAt != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'Dibuat: ${DateFormatter.fullDateWithTime(task.createdAt!)}',
                          style: AppTextStyles.bodySmall,
                        ),
                      ),
                    if (task.updatedAt != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'Terakhir diubah: ${DateFormatter.fullDateWithTime(task.updatedAt!)}',
                          style: AppTextStyles.bodySmall,
                        ),
                      ),
                    if (task.isCompleted && task.completedAt != null)
                      Text(
                        'Diselesaikan: ${DateFormatter.fullDateWithTime(task.completedAt!)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.secondaryTeal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TasksViewModel vm,
    AssignmentItem task,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Tugas'),
        content: Text(
          'Apakah Anda yakin ingin menghapus tugas "${task.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await vm.deleteAssignment(task.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tugas berhasil dihapus.')),
        );
        context.pop();
      }
    }
  }
}
