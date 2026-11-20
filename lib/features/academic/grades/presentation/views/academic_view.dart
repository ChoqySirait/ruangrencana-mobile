import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../../app/router/app_router.dart';
import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../../core/widgets/info_badge.dart';
import '../../../../../core/widgets/metric_summary_card.dart';
import '../../../../../core/widgets/section_header.dart';
import '../../data/models/academic_overview.dart';
import '../view_models/academic_view_model.dart';

/// Halaman Akademik: menampilkan semester aktif, ringkasan IPS & IPK,
/// daftar nilai sementara/akhir per mata kuliah, progres SKS & riwayat IPS,
/// serta pintu masuk menuju Simulasi Nilai dan Manajemen Semester.
class AcademicView extends StatelessWidget {
  const AcademicView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AcademicViewModel>();
    final overview = vm.overview;
    final totalWithActiveSks =
        overview.completedSksBeforeActive + overview.activeSks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Performa Akademik'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Kelola Semester',
            onPressed: () => context.pushNamed(AppRoutes.semesterList),
          ),
          IconButton(
            icon: const Icon(Icons.list_alt_rounded),
            tooltip: 'Daftar Mata Kuliah',
            onPressed: () => context.pushNamed(AppRoutes.courses),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal,
          vertical: AppSpacing.xs,
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () => context.pushNamed(AppRoutes.semesterList),
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              child: InfoBadge(
                label: overview.activeSemesterLabel,
                tone: BadgeTone.primary,
                icon: Icons.calendar_today_outlined,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Ringkasan IPS & IPK
          Row(
            children: [
              Expanded(
                child: MetricSummaryCard(
                  label: 'IPS Sementara',
                  value: overview.provisionalIps.toStringAsFixed(2),
                  subtitle: '${overview.activeSks} SKS aktif',
                  accentColor: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: MetricSummaryCard(
                  label: 'IPK Kumulatif',
                  value: overview.cumulativeIpk.toStringAsFixed(2),
                  subtitle: '${overview.completedSksBeforeActive} SKS selesai',
                  accentColor: AppColors.secondaryTeal,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Pintu masuk Simulasi Nilai
          Card(
            color: AppColors.primaryNavy,
            child: InkWell(
              onTap: () => context.pushNamed(AppRoutes.gradeSimulation),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                      ),
                      child: const Icon(
                        Icons.calculate_outlined,
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Simulasi Nilai & Proyeksi IPS',
                            style: AppTextStyles.titleSmall.copyWith(
                              color: AppColors.textOnPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            'Uji skenario nilai akhir tanpa mengubah catatan akademik asli.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textOnPrimary.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: AppColors.textOnPrimary,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Seksi Progres Akademik
          const SectionHeader(title: 'Progres Akademik'),
          const SizedBox(height: AppSpacing.xs),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Progres Tempuh SKS',
                          style: AppTextStyles.titleSmall,
                        ),
                      ),
                      Text(
                        '$totalWithActiveSks / ${overview.targetGraduationSks} SKS',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.primaryNavy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    child: LinearProgressIndicator(
                      value: vm.sksProgressRatio,
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceSubtle,
                      color: AppColors.secondaryTeal,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${overview.completedSksBeforeActive} SKS lulus + ${overview.activeSks} SKS sedang ditempuh',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Divider(),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Riwayat IPS Semester Selesai',
                    style: AppTextStyles.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (overview.historicalSemesters.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      child: Text(
                        'Belum ada riwayat semester lampau.',
                        style: AppTextStyles.bodySmall,
                      ),
                    )
                  else
                    Row(
                      children: overview.historicalSemesters.map((record) {
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(right: AppSpacing.xs),
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMd,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  record.semesterLabel,
                                  style: AppTextStyles.labelSmall,
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  record.ips.toStringAsFixed(2),
                                  style: AppTextStyles.titleMedium.copyWith(
                                    color: AppColors.primaryNavy,
                                  ),
                                ),
                                Text(
                                  '${record.sks} SKS',
                                  style: AppTextStyles.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Ringkasan Nilai per Mata Kuliah
          SectionHeader(
            title: 'Ringkasan Nilai Mata Kuliah',
            actionLabel: 'Kelola',
            onActionTap: () => context.pushNamed(AppRoutes.courses),
          ),
          const SizedBox(height: AppSpacing.xxs),
          const Text(
            'Nilai sementara dihitung hanya dari bobot komponen yang sudah dinilai.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (overview.courseGrades.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'Belum ada mata kuliah aktif pada semester ini.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...overview.courseGrades.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _CourseGradeCard(
                  summary: item,
                  onTap: () => context.pushNamed(
                    AppRoutes.courseDetail,
                    pathParameters: {'courseId': item.course.id},
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _CourseGradeCard extends StatelessWidget {
  const _CourseGradeCard({required this.summary, required this.onTap});

  final CourseGradeSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final calc = summary.calculation;
    final scoreText = calc.provisionalAverage != null
        ? calc.provisionalAverage!.toStringAsFixed(1)
        : '-';
    final gradedPct = calc.gradedWeightPercent.toStringAsFixed(0);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        InfoBadge(
                          label: summary.course.code,
                          tone: BadgeTone.neutral,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        InfoBadge(
                          label: calc.isFinalReady ? 'Final' : 'Sementara',
                          tone: calc.isFinalReady
                              ? BadgeTone.secondary
                              : BadgeTone.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      summary.course.name,
                      style: AppTextStyles.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${summary.course.sks} SKS • $gradedPct% bobot sudah dinilai',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    summary.letterGrade,
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: AppColors.primaryNavy,
                    ),
                  ),
                  Text(
                    'Skor $scoreText',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
