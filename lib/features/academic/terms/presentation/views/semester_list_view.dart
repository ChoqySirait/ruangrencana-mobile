import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:ruangrencana/app/router/app_router.dart';
import 'package:ruangrencana/app/theme/app_colors.dart';
import 'package:ruangrencana/app/theme/app_spacing.dart';
import 'package:ruangrencana/app/theme/app_text_styles.dart';
import 'package:ruangrencana/core/utils/date_formatter.dart';
import 'package:ruangrencana/core/widgets/info_badge.dart';
import 'package:ruangrencana/core/widgets/section_header.dart';
import 'package:ruangrencana/features/academic/terms/data/models/academic_term_item.dart';
import 'package:ruangrencana/features/academic/terms/presentation/view_models/semester_view_model.dart';

/// Layar untuk mengelola dan beralih antar semester akademik.
class SemesterListView extends StatelessWidget {
  const SemesterListView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SemesterViewModel>();
    final active = vm.activeSemester;
    final historical = vm.historicalSemesters;

    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Semester')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(AppRoutes.addSemester),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Semester'),
      ),
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => vm.refresh(),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageHorizontal,
                  vertical: AppSpacing.md,
                ),
                children: [
                  if (vm.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.errorSoft,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              vm.errorMessage!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Seksi Semester Aktif
                  const SectionHeader(title: 'Semester Aktif'),
                  const SizedBox(height: AppSpacing.xs),
                  if (active == null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          'Belum ada semester yang ditandai aktif. Silakan pilih atau buat semester aktif.',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  else
                    _SemesterCard(
                      term: active,
                      isActive: true,
                      onEdit: () => context.pushNamed(
                        AppRoutes.editSemester,
                        pathParameters: {'termId': active.id.toString()},
                      ),
                    ),

                  const SizedBox(height: AppSpacing.lg),

                  // Seksi Riwayat Semester
                  const SectionHeader(title: 'Riwayat Semester'),
                  const SizedBox(height: AppSpacing.xs),
                  if (historical.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          'Belum ada riwayat semester lain.',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  else
                    ...historical.map(
                      (term) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _SemesterCard(
                          term: term,
                          isActive: false,
                          onActivate: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Ganti Semester Aktif?'),
                                content: Text(
                                  'Apakah Anda yakin ingin beralih ke ${term.fullLabel}? '
                                  'Jadwal dan mata kuliah aktif akan disesuaikan dengan semester ini.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Batal'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Aktifkan'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true && context.mounted) {
                              final success = await vm.setActiveSemester(
                                term.id,
                              );
                              if (context.mounted && success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${term.fullLabel} sekarang menjadi semester aktif.',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          onEdit: () => context.pushNamed(
                            AppRoutes.editSemester,
                            pathParameters: {'termId': term.id.toString()},
                          ),
                          onDelete: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Hapus Semester?'),
                                content: Text(
                                  'Apakah Anda yakin ingin menghapus ${term.fullLabel}? '
                                  'Semester yang masih memiliki mata kuliah tidak dapat dihapus.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Batal'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.error,
                                    ),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Hapus'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true && context.mounted) {
                              final success = await vm.deleteSemester(term.id);
                              if (context.mounted) {
                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Semester berhasil dihapus.',
                                      ),
                                    ),
                                  );
                                } else if (vm.errorMessage != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(vm.errorMessage!),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}

class _SemesterCard extends StatelessWidget {
  const _SemesterCard({
    required this.term,
    required this.isActive,
    this.onActivate,
    this.onEdit,
    this.onDelete,
  });

  final AcademicTermItem term;
  final bool isActive;
  final VoidCallback? onActivate;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final dateRangeStr = (term.startDate != null && term.endDate != null)
        ? '${DateFormatter.shortDate(term.startDate!)} - ${DateFormatter.shortDate(term.endDate!)}'
        : 'Rentang tanggal belum ditentukan';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InfoBadge(
                  label: term.shortLabel,
                  tone: isActive ? BadgeTone.primary : BadgeTone.neutral,
                ),
                const SizedBox(width: AppSpacing.xs),
                InfoBadge(
                  label: isActive ? 'Aktif' : 'Riwayat',
                  tone: isActive ? BadgeTone.secondary : BadgeTone.neutral,
                ),
                const Spacer(),
                if (onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Edit Semester',
                    onPressed: onEdit,
                  ),
                if (!isActive && onDelete != null)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: AppColors.error,
                    ),
                    tooltip: 'Hapus Semester',
                    onPressed: onDelete,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(term.fullLabel, style: AppTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              dateRangeStr,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text(
                  '${term.courseCount} mata kuliah • ${term.totalCredits} SKS',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primaryNavy,
                  ),
                ),
                const Spacer(),
                if (!isActive && onActivate != null)
                  OutlinedButton.icon(
                    onPressed: onActivate,
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Jadikan Aktif'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
