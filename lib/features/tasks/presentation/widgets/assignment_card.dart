import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/info_badge.dart';
import '../../data/models/assignment_item.dart';

/// Kartu tugas kuliah yang menampilkan judul, mata kuliah, tenggat,
/// prioritas, status, serta aksi centang selesai.
class AssignmentCard extends StatelessWidget {
  const AssignmentCard({
    required this.item,
    required this.onToggleComplete,
    this.onTap,
    super.key,
  });

  final AssignmentItem item;
  final VoidCallback onToggleComplete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final status = item.statusAt(now);
    final isUrgent = item.isUrgentAt(now);

    final statusTone = switch (status) {
      AssignmentStatus.upcoming => BadgeTone.primary,
      AssignmentStatus.overdue => BadgeTone.error,
      AssignmentStatus.completed => BadgeTone.secondary,
    };

    final priorityTone = switch (item.priority) {
      AssignmentPriority.high => BadgeTone.error,
      AssignmentPriority.medium => BadgeTone.warning,
      AssignmentPriority.low => BadgeTone.neutral,
    };

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: item.isCompleted,
                  onChanged: (_) => onToggleComplete(),
                  activeColor: AppColors.secondaryTeal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTextStyles.titleSmall.copyWith(
                        decoration: item.isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color: item.isCompleted
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      item.courseName,
                      style: AppTextStyles.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.event_outlined,
                          size: 14,
                          color: status == AssignmentStatus.overdue
                              ? AppColors.error
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Expanded(
                          child: Text(
                            '${DateFormatter.shortDateWithTime(item.dueDate)} • ${DateFormatter.relativeDeadlineLabel(item.dueDate, now)}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: status == AssignmentStatus.overdue
                                  ? AppColors.error
                                  : AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xxs,
                      children: [
                        InfoBadge(label: status.label, tone: statusTone),
                        InfoBadge(
                          label: 'Prioritas ${item.priority.label}',
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
