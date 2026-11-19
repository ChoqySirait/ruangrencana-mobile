import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';

/// Variasi warna semantik untuk [InfoBadge].
enum BadgeTone { primary, secondary, warning, error, neutral }

/// Label ringkas untuk menampilkan status, prioritas, bobot SKS, atau semester.
class InfoBadge extends StatelessWidget {
  const InfoBadge({
    required this.label,
    this.tone = BadgeTone.neutral,
    this.icon,
    super.key,
  });

  final String label;
  final BadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bgColor, fgColor) = switch (tone) {
      BadgeTone.primary => (AppColors.primarySoft, AppColors.primaryNavy),
      BadgeTone.secondary => (AppColors.secondarySoft, AppColors.secondaryTeal),
      BadgeTone.warning => (AppColors.warningSoft, AppColors.warning),
      BadgeTone.error => (AppColors.errorSoft, AppColors.error),
      BadgeTone.neutral => (AppColors.surfaceSubtle, AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs + 2,
        vertical: AppSpacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fgColor),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(color: fgColor),
            ),
          ),
        ],
      ),
    );
  }
}
