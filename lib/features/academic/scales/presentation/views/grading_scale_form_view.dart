import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:ruangrencana/app/theme/app_colors.dart';
import 'package:ruangrencana/app/theme/app_spacing.dart';
import 'package:ruangrencana/app/theme/app_text_styles.dart';
import 'package:ruangrencana/core/utils/academic_calculator.dart';
import 'package:ruangrencana/features/academic/grades/data/repositories/academic_repository.dart';
import 'package:ruangrencana/features/academic/scales/presentation/view_models/grading_scale_form_view_model.dart';

/// Formulir pembuatan dan pengeditan profil skala konversi penilaian universitas.
class GradingScaleFormView extends StatelessWidget {
  const GradingScaleFormView({this.scaleId, super.key});

  final String? scaleId;

  @override
  Widget build(BuildContext context) {
    final parsedId = scaleId != null ? int.tryParse(scaleId!) : null;

    return ChangeNotifierProvider<GradingScaleFormViewModel>(
      create: (context) => GradingScaleFormViewModel(
        repository: context.read<AcademicRepository>(),
        scaleId: parsedId,
      ),
      child: const _GradingScaleFormBody(),
    );
  }
}

class _GradingScaleFormBody extends StatefulWidget {
  const _GradingScaleFormBody();

  @override
  State<_GradingScaleFormBody> createState() => _GradingScaleFormBodyState();
}

class _GradingScaleFormBodyState extends State<_GradingScaleFormBody> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final vm = context.read<GradingScaleFormViewModel>();
      _nameController.text = vm.name;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave(GradingScaleFormViewModel vm) async {
    if (!_formKey.currentState!.validate()) return;

    if (!vm.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.validationResult.errors.first),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (vm.isEditing && vm.affectedTerms.isNotEmpty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Perlindungan Riwayat Akademik'),
          content: Text(
            'Skala ini saat ini digunakan oleh ${vm.affectedTerms.length} semester (${vm.affectedTerms.map((t) => t.semesterName).join(', ')}).\n\n'
            'Mengubah aturan nilai secara langsung dapat mengubah huruf mutu dan IPS semester lampau. Apakah Anda ingin memperbarui skala asli atau menyimpannya sebagai skala baru?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Batal'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'overwrite'),
              child: const Text('Perbarui Langsung'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'duplicate'),
              child: const Text('Simpan Sebagai Skala Baru'),
            ),
          ],
        ),
      );

      if (choice == null || choice == 'cancel') return;

      final saveAsNew = choice == 'duplicate';
      final resId = await vm.save(saveAsNewDuplicate: saveAsNew);
      if (mounted && resId != null) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              saveAsNew
                  ? 'Disimpan sebagai skala baru untuk menjaga riwayat.'
                  : 'Skala nilai berhasil diperbarui.',
            ),
          ),
        );
      }
      return;
    }

    final resId = await vm.save();
    if (mounted && resId != null) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Skala nilai berhasil disimpan.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GradingScaleFormViewModel>();

    // Update text controller if preset applied
    if (_nameController.text != vm.name && vm.name.isNotEmpty) {
      _nameController.text = vm.name;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(vm.isEditing ? 'Edit Skala Nilai' : 'Tambah Skala Nilai'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Simpan',
            onPressed: vm.isLoading ? null : () => _handleSave(vm),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageHorizontal,
            vertical: AppSpacing.sm,
          ),
          child: FilledButton.icon(
            onPressed: vm.isLoading ? null : () => _handleSave(vm),
            icon: vm.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(vm.isLoading ? 'Menyimpan...' : 'Simpan Skala Nilai'),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
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

            // Input Nama Skala
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Skala Penilaian',
                hintText: 'Contoh: Standar Kampus 4.00 (A-E)',
                prefixIcon: Icon(Icons.format_list_numbered_rounded),
              ),
              onChanged: vm.setName,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Nama skala nilai tidak boleh kosong';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.sm),

            // Switch Skala Bawaan
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Jadikan Skala Bawaan (Default)'),
              subtitle: const Text(
                'Akan otomatis digunakan pada semester baru kecuali diubah.',
                style: AppTextStyles.bodySmall,
              ),
              value: vm.isDefault,
              onChanged: vm.setIsDefault,
            ),
            const Divider(height: AppSpacing.lg),

            // Pilihan Cepat Preset Skala
            const Text('Gunakan Preset Cepat', style: AppTextStyles.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.flash_on_outlined, size: 16),
                  label: const Text('Standar +/- (A s/d E)'),
                  onPressed: () => vm.applyPreset('standard_plus_minus'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.auto_awesome_outlined, size: 16),
                  label: const Text('Skala 5 (A-E)'),
                  onPressed: () => vm.applyPreset('simple_5'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.tune_outlined, size: 16),
                  label: const Text('Skala 7 (A, AB, B...)'),
                  onPressed: () => vm.applyPreset('scale_7'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Status Validasi Real-Time
            _ValidationBanner(result: vm.validationResult),
            const SizedBox(height: AppSpacing.md),

            // Peringatan jika skala digunakan oleh semester lain
            if (vm.affectedTerms.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.secondaryTeal),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: AppColors.secondaryTeal,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Skala ini sedang digunakan oleh ${vm.affectedTerms.length} semester (${vm.affectedTerms.map((t) => t.semesterName).join(', ')}). Saat menyimpan, Anda dapat memilih untuk memperbarui langsung atau membuat salinan baru untuk menjaga riwayat masa lalu.',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Daftar Baris Rentang Nilai
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Konfigurasi Rentang Skor',
                  style: AppTextStyles.titleSmall,
                ),
                TextButton.icon(
                  onPressed: vm.addRange,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tambah Baris'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),

            for (var i = 0; i < vm.ranges.length; i++)
              _RangeRowCard(
                index: i,
                range: vm.ranges[i],
                onUpdate: (letter, gp, min, max) {
                  vm.updateRange(
                    i,
                    letter: letter,
                    gradePoint: gp,
                    minScore: min,
                    maxScore: max,
                  );
                },
                onDelete: () => vm.removeRange(i),
              ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _ValidationBanner extends StatelessWidget {
  const _ValidationBanner({required this.result});

  final GradingScaleValidationResult result;

  @override
  Widget build(BuildContext context) {
    if (result.isValid) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.secondaryTeal.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: AppColors.secondaryTeal.withValues(alpha: 0.4),
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: AppColors.secondaryTeal,
              size: 22,
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Konfigurasi Valid (0.0 - 100.0)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondaryTeal,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Seluruh skor tercakup penuh tanpa celah atau tumpang tindih.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Konfigurasi Belum Valid (${result.errors.length} Masalah)',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final err in result.errors)
            Padding(
              padding: const EdgeInsets.only(left: 30, bottom: 4),
              child: Text(
                '• $err',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
        ],
      ),
    );
  }
}

class _RangeRowCard extends StatefulWidget {
  const _RangeRowCard({
    required this.index,
    required this.range,
    required this.onUpdate,
    required this.onDelete,
  });

  final int index;
  final GradingScaleRangeDraft range;
  final void Function(
    String letter,
    double gradePoint,
    double minScore,
    double maxScore,
  )
  onUpdate;
  final VoidCallback onDelete;

  @override
  State<_RangeRowCard> createState() => _RangeRowCardState();
}

class _RangeRowCardState extends State<_RangeRowCard> {
  late final TextEditingController _letterCtrl;
  late final TextEditingController _pointCtrl;
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;

  @override
  void initState() {
    super.initState();
    _letterCtrl = TextEditingController(text: widget.range.letter);
    _pointCtrl = TextEditingController(
      text: widget.range.gradePoint.toStringAsFixed(2),
    );
    _minCtrl = TextEditingController(
      text: widget.range.minScore.toStringAsFixed(2),
    );
    _maxCtrl = TextEditingController(
      text: widget.range.maxScore.toStringAsFixed(2),
    );
  }

  @override
  void didUpdateWidget(covariant _RangeRowCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.range.letter != _letterCtrl.text) {
      _letterCtrl.text = widget.range.letter;
    }
    final formattedPoint = widget.range.gradePoint.toStringAsFixed(2);
    if (double.tryParse(_pointCtrl.text) != widget.range.gradePoint &&
        _pointCtrl.text != formattedPoint) {
      _pointCtrl.text = formattedPoint;
    }
    final formattedMin = widget.range.minScore.toStringAsFixed(2);
    if (double.tryParse(_minCtrl.text) != widget.range.minScore &&
        _minCtrl.text != formattedMin) {
      _minCtrl.text = formattedMin;
    }
    final formattedMax = widget.range.maxScore.toStringAsFixed(2);
    if (double.tryParse(_maxCtrl.text) != widget.range.maxScore &&
        _maxCtrl.text != formattedMax) {
      _maxCtrl.text = formattedMax;
    }
  }

  @override
  void dispose() {
    _letterCtrl.dispose();
    _pointCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  void _notifyChange() {
    final letter = _letterCtrl.text.trim();
    final point = double.tryParse(_pointCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final min = double.tryParse(_minCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final max = double.tryParse(_maxCtrl.text.replaceAll(',', '.')) ?? 0.0;
    widget.onUpdate(letter, point, min, max);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            // Huruf Mutu
            SizedBox(
              width: 58,
              child: TextFormField(
                controller: _letterCtrl,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  labelText: 'Huruf',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                ),
                onChanged: (_) => _notifyChange(),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),

            // Bobot Mutu (Grade Point)
            SizedBox(
              width: 64,
              child: TextFormField(
                controller: _pointCtrl,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Bobot',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                ),
                onChanged: (_) => _notifyChange(),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),

            // Skor Minimum
            Expanded(
              child: TextFormField(
                controller: _minCtrl,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Min Skor',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                ),
                onChanged: (_) => _notifyChange(),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('-'),
            ),

            // Skor Maksimum
            Expanded(
              child: TextFormField(
                controller: _maxCtrl,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Max Skor',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                ),
                onChanged: (_) => _notifyChange(),
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),

            // Tombol Hapus Baris
            IconButton(
              icon: const Icon(
                Icons.remove_circle_outline,
                color: AppColors.error,
                size: 20,
              ),
              tooltip: 'Hapus Baris',
              onPressed: widget.onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
