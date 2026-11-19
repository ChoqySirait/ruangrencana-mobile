import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../../core/widgets/info_badge.dart';
import '../../../../../core/widgets/metric_summary_card.dart';
import '../../../grades/data/repositories/academic_repository.dart';
import '../view_models/grade_simulator_view_model.dart';

/// Layar sekunder Simulasi Nilai.
///
/// Mengizinkan mahasiswa menguji target skor mata kuliah untuk melihat
/// proyeksi IPS dan IPK tanpa menimpa catatan nilai asli.
class GradeSimulatorView extends StatelessWidget {
  const GradeSimulatorView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => GradeSimulatorViewModel(
        academicRepository: context.read<AcademicRepository>(),
      ),
      child: const _GradeSimulatorBody(),
    );
  }
}

class _GradeSimulatorBody extends StatelessWidget {
  const _GradeSimulatorBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GradeSimulatorViewModel>();
    final overview = vm.overview;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulasi Nilai'),
        actions: [
          TextButton(onPressed: vm.resetSimulation, child: const Text('Reset')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
        children: [
          // Penegasan aturan bisnis: simulasi terpisah dari data asli
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Mode simulasi bersifat hipotetis dan tidak akan mengubah nilai akademik asli Anda.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          Row(
            children: [
              Expanded(
                child: MetricSummaryCard(
                  label: 'Proyeksi IPS',
                  value: vm.simulatedIps.toStringAsFixed(2),
                  subtitle:
                      'Saat ini: ${overview.provisionalIps.toStringAsFixed(2)}',
                  accentColor: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: MetricSummaryCard(
                  label: 'Proyeksi IPK',
                  value: vm.simulatedIpk.toStringAsFixed(2),
                  subtitle:
                      'Saat ini: ${overview.cumulativeIpk.toStringAsFixed(2)}',
                  accentColor: AppColors.secondaryTeal,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),
          const Text(
            'Sesuaikan Target Skor Mata Kuliah',
            style: AppTextStyles.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),

          ...overview.courseGrades.map((item) {
            final score = vm.scoreForCourse(item.course.id);
            final rule = vm.simulatedRuleForCourse(item.course.id);

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.course.name,
                              style: AppTextStyles.titleSmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          InfoBadge(
                            label:
                                '${rule?.letter ?? '-'} (${rule?.gradePoint.toStringAsFixed(2) ?? '0.00'})',
                            tone: BadgeTone.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '${item.course.sks} SKS • Target skor: ${score.toStringAsFixed(0)}',
                        style: AppTextStyles.bodySmall,
                      ),
                      Slider(
                        value: score,
                        min: 0,
                        max: 100,
                        divisions: 100,
                        activeColor: AppColors.secondaryTeal,
                        label: score.toStringAsFixed(0),
                        onChanged: (value) =>
                            vm.updateHypotheticalScore(item.course.id, value),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
