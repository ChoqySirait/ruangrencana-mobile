import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:ruangrencana/app/theme/app_colors.dart';
import 'package:ruangrencana/app/theme/app_spacing.dart';
import 'package:ruangrencana/app/theme/app_text_styles.dart';
import 'package:ruangrencana/core/widgets/info_badge.dart';
import 'package:ruangrencana/core/widgets/metric_summary_card.dart';
import 'package:ruangrencana/features/academic/grades/data/repositories/academic_repository.dart';
import 'package:ruangrencana/features/academic/simulator/presentation/view_models/grade_simulator_view_model.dart';

/// Layar interaktif Simulasi Nilai & Perhitungan Target IPK.
///
/// Memungkinkan mahasiswa menguji skenario skor nilai mata kuliah, menghitung
/// target IPK yang realistis, dan melihat proyeksi hasil studi secara terisolasi.
class GradeSimulatorView extends StatelessWidget {
  const GradeSimulatorView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GradeSimulatorViewModel>(
      create: (context) => GradeSimulatorViewModel(
        academicRepository: context.read<AcademicRepository>(),
      ),
      child: const _GradeSimulatorBody(),
    );
  }
}

class _GradeSimulatorBody extends StatefulWidget {
  const _GradeSimulatorBody();

  @override
  State<_GradeSimulatorBody> createState() => _GradeSimulatorBodyState();
}

class _GradeSimulatorBodyState extends State<_GradeSimulatorBody> {
  final TextEditingController _targetIpsController = TextEditingController();
  final TextEditingController _targetIpkController = TextEditingController();

  @override
  void dispose() {
    _targetIpsController.dispose();
    _targetIpkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GradeSimulatorViewModel>();
    final overview = vm.overview;
    final rec = vm.targetRecommendation;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulasi Nilai & Target IPK'),
        actions: [
          TextButton.icon(
            onPressed: () {
              _targetIpsController.clear();
              _targetIpkController.clear();
              vm.resetSimulation();
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reset'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal,
          vertical: AppSpacing.md,
        ),
        children: [
          // Banner Penegasan Isolasi Bisnis
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: AppColors.secondaryTeal.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 20,
                  color: AppColors.secondaryTeal,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Eksperimen Terisolasi Penuh',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.secondaryTeal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Seluruh perubahan nilai pada simulator disimpan di memori dan tidak akan menimpa catatan nilai asli pada database SQLite Anda.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Ringkasan Proyeksi & Delta
          Row(
            children: [
              Expanded(
                child: MetricSummaryCard(
                  label: 'Proyeksi IPS',
                  value: vm.simulatedIps.toStringAsFixed(2),
                  subtitle:
                      'Asli: ${overview.provisionalIps.toStringAsFixed(2)} (Δ ${GradeSimulatorViewModel.formatDelta(vm.ipsDelta)})',
                  accentColor: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: MetricSummaryCard(
                  label: 'Proyeksi IPK',
                  value: vm.simulatedIpk.toStringAsFixed(2),
                  subtitle:
                      'Asli: ${overview.cumulativeIpk.toStringAsFixed(2)} (Δ ${GradeSimulatorViewModel.formatDelta(vm.ipkDelta)})',
                  accentColor: AppColors.secondaryTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Alat Bantu Perhitungan Target IPK / IPS
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.track_changes_outlined,
                        color: AppColors.primaryNavy,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Kalkulator Target Prestasi',
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Masukkan target IPS atau IPK yang ingin Anda raih untuk melihat rekomendasi rata-rata nilai yang dibutuhkan.',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _targetIpsController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Target IPS',
                            hintText: 'Misal: 3.75',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          onChanged: (val) {
                            _targetIpkController.clear();
                            final parsed = double.tryParse(
                              val.replaceAll(',', '.'),
                            );
                            vm.setTargetIps(parsed);
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextFormField(
                          controller: _targetIpkController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Target IPK',
                            hintText: 'Misal: 3.80',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          onChanged: (val) {
                            _targetIpsController.clear();
                            final parsed = double.tryParse(
                              val.replaceAll(',', '.'),
                            );
                            vm.setTargetIpk(parsed);
                          },
                        ),
                      ),
                    ],
                  ),

                  if (rec != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: rec.isAchievable
                            ? AppColors.secondaryTeal.withValues(alpha: 0.1)
                            : AppColors.errorSoft,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSm,
                        ),
                        border: Border.all(
                          color: rec.isAchievable
                              ? AppColors.secondaryTeal.withValues(alpha: 0.4)
                              : AppColors.error.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                rec.isAchievable
                                    ? Icons.check_circle_outline
                                    : Icons.warning_amber_rounded,
                                color: rec.isAchievable
                                    ? AppColors.secondaryTeal
                                    : AppColors.error,
                                size: 18,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  rec.statusMessage,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: rec.isAchievable
                                        ? AppColors.textPrimary
                                        : AppColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (rec.isAchievable &&
                              rec.averageRequiredScore > 0) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: vm.applyTargetRecommendation,
                                icon: const Icon(
                                  Icons.auto_fix_high_outlined,
                                  size: 16,
                                ),
                                label: const Text('Terapkan Rekomendasi'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Pilihan Cepat Skenario
          const Text(
            'Uji Cepat Skenario Global',
            style: AppTextStyles.labelLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              ActionChip(
                avatar: const Icon(Icons.star_rounded, size: 16),
                label: const Text('Semua A (85)'),
                onPressed: () => vm.setAllScores(85.0),
              ),
              ActionChip(
                avatar: const Icon(Icons.trending_up, size: 16),
                label: const Text('Semua B+ (75)'),
                onPressed: () => vm.setAllScores(75.0),
              ),
              ActionChip(
                avatar: const Icon(Icons.check, size: 16),
                label: const Text('Semua B (70)'),
                onPressed: () => vm.setAllScores(70.0),
              ),
              ActionChip(
                avatar: const Icon(Icons.undo, size: 16),
                label: const Text('Nilai Asli'),
                onPressed: vm.resetSimulation,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          const Text(
            'Target Skor per Mata Kuliah',
            style: AppTextStyles.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),

          if (overview.courseGrades.isEmpty) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Text(
                  'Tidak ada mata kuliah aktif di semester ini.',
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            ),
          ] else ...[
            ...overview.courseGrades.map((item) {
              final score = vm.scoreForCourse(item.course.id);
              final rule = vm.simulatedRuleForCourse(item.course.id);
              final actualScore = item.calculation.provisionalAverage;

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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${item.course.sks} SKS (${item.course.code}) • Skor: ${score.toStringAsFixed(1)}',
                                style: AppTextStyles.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (actualScore != null) ...[
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                'Asli: ${actualScore.toStringAsFixed(1)}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
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
                        // Pintasan huruf mutu langsung
                        Wrap(
                          spacing: 4,
                          children: overview.gradingScale.map((scaleRule) {
                            final isCurrent = rule?.letter == scaleRule.letter;
                            return ChoiceChip(
                              label: Text(
                                scaleRule.letter,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isCurrent
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              selected: isCurrent,
                              onSelected: (_) => vm.updateHypotheticalScore(
                                item.course.id,
                                scaleRule.minScore,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
