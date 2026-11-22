import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:ruangrencana/app/router/app_router.dart';
import 'package:ruangrencana/app/theme/app_colors.dart';
import 'package:ruangrencana/app/theme/app_spacing.dart';
import 'package:ruangrencana/app/theme/app_text_styles.dart';
import 'package:ruangrencana/core/widgets/info_badge.dart';
import 'package:ruangrencana/features/academic/grades/data/repositories/academic_repository.dart';
import 'package:ruangrencana/features/academic/scales/data/models/grading_scale_item.dart';
import 'package:ruangrencana/features/academic/scales/presentation/view_models/grading_scales_view_model.dart';

/// Tampilan daftar profil skala konversi penilaian universitas.
class GradingScaleListView extends StatelessWidget {
  const GradingScaleListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GradingScalesViewModel>(
      create: (context) => GradingScalesViewModel(
        repository: context.read<AcademicRepository>(),
      ),
      child: const _GradingScaleListBody(),
    );
  }
}

class _GradingScaleListBody extends StatelessWidget {
  const _GradingScaleListBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GradingScalesViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Skala Penilaian Kampus')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.pushNamed(AppRoutes.addGradingScale);
          vm.loadScales();
        },
        icon: const Icon(Icons.add),
        label: const Text('Tambah Skala'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => vm.loadScales(),
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageHorizontal,
            vertical: AppSpacing.md,
          ),
          children: [
            // Penjelasan banner
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primaryNavy,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sistem Konversi Nilai Kampus',
                          style: AppTextStyles.labelLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        const Text(
                          'Skala penilaian mengonversi nilai angka (0-100) menjadi huruf mutu dan bobot IPK. Setiap semester dapat menerapkan skala berbeda sesuai kebijakan universitas.',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            if (vm.errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.errorSoft,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  vm.errorMessage!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            ],

            if (vm.scales.isEmpty) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Text(
                    'Belum ada skala nilai.',
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
              ),
            ] else ...[
              for (final scale in vm.scales)
                _GradingScaleCard(
                  scale: scale,
                  onSetDefault: () => vm.setDefaultScale(scale.id),
                  onDelete: () => _confirmDelete(context, vm, scale),
                  onDuplicate: () => _promptDuplicate(context, vm, scale),
                  onEdit: () async {
                    await context.pushNamed(
                      AppRoutes.editGradingScale,
                      pathParameters: {'scaleId': scale.id.toString()},
                    );
                    vm.loadScales();
                  },
                ),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    GradingScalesViewModel vm,
    GradingScaleItem scale,
  ) {
    if (scale.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Skala bawaan (default) tidak dapat dihapus.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (scale.usageCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Skala ini sedang digunakan oleh ${scale.usageCount} semester dan tidak dapat dihapus.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Skala Nilai'),
        content: Text('Hapus profil skala nilai "${scale.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await vm.deleteScale(scale.id);
              if (context.mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Skala berhasil dihapus.')),
                );
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _promptDuplicate(
    BuildContext context,
    GradingScalesViewModel vm,
    GradingScaleItem scale,
  ) {
    final controller = TextEditingController(text: '${scale.name} (Salinan)');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duplikasi Skala Nilai'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nama Skala Baru',
            hintText: 'Contoh: Standar 4.00 Revisi 2026',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final newId = await vm.duplicateScale(
                sourceId: scale.id,
                newName: name,
              );
              if (context.mounted && newId != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Skala berhasil diduplikasi.')),
                );
              }
            },
            child: const Text('Duplikasi'),
          ),
        ],
      ),
    );
  }
}

class _GradingScaleCard extends StatelessWidget {
  const _GradingScaleCard({
    required this.scale,
    required this.onSetDefault,
    required this.onDelete,
    required this.onDuplicate,
    required this.onEdit,
  });

  final GradingScaleItem scale;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final isValid = scale.isValid;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              scale.name,
                              style: AppTextStyles.titleMedium,
                            ),
                          ),
                          if (scale.isDefault) ...[
                            const SizedBox(width: AppSpacing.xs),
                            const InfoBadge(
                              label: 'Bawaan',
                              tone: BadgeTone.primary,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Row(
                        children: [
                          Text(
                            '${scale.ranges.length} rentang nilai',
                            style: AppTextStyles.bodySmall,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          const Text('•', style: AppTextStyles.bodySmall),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            scale.usageCount > 0
                                ? 'Digunakan di ${scale.usageCount} semester'
                                : 'Belum digunakan semester manapun',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: scale.usageCount > 0
                                  ? AppColors.secondaryTeal
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (val) {
                    switch (val) {
                      case 'edit':
                        onEdit();
                        break;
                      case 'set_default':
                        onSetDefault();
                        break;
                      case 'duplicate':
                        onDuplicate();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 20),
                          SizedBox(width: AppSpacing.xs),
                          Text('Edit Skala'),
                        ],
                      ),
                    ),
                    if (!scale.isDefault)
                      const PopupMenuItem(
                        value: 'set_default',
                        child: Row(
                          children: [
                            Icon(Icons.star_outline_rounded, size: 20),
                            SizedBox(width: AppSpacing.xs),
                            Text('Jadikan Bawaan'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          Icon(Icons.copy_outlined, size: 20),
                          SizedBox(width: AppSpacing.xs),
                          Text('Duplikasi'),
                        ],
                      ),
                    ),
                    if (!scale.isDefault && scale.usageCount == 0)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              color: AppColors.error,
                              size: 20,
                            ),
                            SizedBox(width: AppSpacing.xs),
                            Text(
                              'Hapus',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Indikator validitas jika ada error konfigurasi
            if (!isValid) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.errorSoft,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.error,
                      size: 16,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        scale.validation.errors.first,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            // Preview chip tingkatan nilai (A, B, C, ...)
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: scale.ranges.map((r) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    '${r.letterGrade} (${r.gradePoint.toStringAsFixed(1)}) • ${r.minimumScore.toStringAsFixed(0)}-${r.maximumScore.toStringAsFixed(0)}',
                    style: AppTextStyles.labelSmall.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
