import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:ruangrencana/app/theme/app_colors.dart';
import 'package:ruangrencana/app/theme/app_spacing.dart';
import 'package:ruangrencana/app/theme/app_text_styles.dart';
import 'package:ruangrencana/core/utils/date_formatter.dart';
import 'package:ruangrencana/features/academic/grades/data/repositories/academic_repository.dart';
import 'package:ruangrencana/features/academic/terms/data/models/academic_term_item.dart';
import 'package:ruangrencana/features/academic/terms/presentation/view_models/semester_view_model.dart';

/// Formulir Tambah & Edit Semester Akademik.
class SemesterFormView extends StatefulWidget {
  const SemesterFormView({this.termId, super.key});

  final String? termId;

  @override
  State<SemesterFormView> createState() => _SemesterFormViewState();
}

class _SemesterFormViewState extends State<SemesterFormView> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _yearController;
  late final TextEditingController _nameController;
  late final TextEditingController _numberController;

  DateTime? _startDate;
  DateTime? _endDate;
  int? _gradingScaleId;
  bool _makeActive = false;
  bool _isInit = false;
  AcademicTermItem? _existingTerm;

  bool get isEditing => widget.termId != null;

  @override
  void initState() {
    super.initState();
    _yearController = TextEditingController(text: '2025/2026');
    _nameController = TextEditingController();
    _numberController = TextEditingController(text: '1');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      _isInit = true;
      final academicRepo = context.read<AcademicRepository>();
      final defScale = academicRepo.getDefaultGradingScale();
      _gradingScaleId = defScale?.id ?? 1;

      if (widget.termId != null) {
        final id = int.tryParse(widget.termId!);
        if (id != null) {
          final vm = context.read<SemesterViewModel>();
          _existingTerm = vm.semesters.where((s) => s.id == id).firstOrNull;
          if (_existingTerm != null) {
            _yearController.text = _existingTerm!.academicYear;
            _nameController.text = _existingTerm!.semesterName;
            _numberController.text = _existingTerm!.semesterNumber.toString();
            _startDate = _existingTerm!.startDate;
            _endDate = _existingTerm!.endDate;
            _gradingScaleId = _existingTerm!.gradingScaleId;
            _makeActive = _existingTerm!.isActive;
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _yearController.dispose();
    _nameController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? _startDate ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2010),
      lastDate: DateTime(2040),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate != null &&
        _endDate != null &&
        _startDate!.isAfter(_endDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanggal mulai harus lebih awal dari tanggal selesai.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final vm = context.read<SemesterViewModel>();
    final semNumber = int.parse(_numberController.text.trim());

    if (isEditing && _existingTerm != null) {
      final success = await vm.updateSemester(
        id: _existingTerm!.id,
        academicYear: _yearController.text.trim(),
        semesterName: _nameController.text.trim(),
        semesterNumber: semNumber,
        startDate: _startDate,
        endDate: _endDate,
        gradingScaleId: _gradingScaleId,
      );

      if (_makeActive && !_existingTerm!.isActive) {
        await vm.setActiveSemester(_existingTerm!.id);
      }

      if (mounted && success) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Semester berhasil diperbarui.')),
        );
      }
    } else {
      final newId = await vm.createSemester(
        academicYear: _yearController.text.trim(),
        semesterName: _nameController.text.trim(),
        semesterNumber: semNumber,
        startDate: _startDate,
        endDate: _endDate,
        gradingScaleId: _gradingScaleId,
        makeActive: _makeActive,
      );

      if (mounted && newId != null) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Semester baru berhasil dibuat.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SemesterViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Semester' : 'Tambah Semester'),
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

            TextFormField(
              controller: _yearController,
              decoration: const InputDecoration(
                labelText: 'Tahun Akademik',
                hintText: 'Contoh: 2025/2026',
                prefixIcon: Icon(Icons.date_range_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Tahun akademik tidak boleh kosong';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Semester',
                hintText: 'Contoh: Semester 4 (Genap)',
                prefixIcon: Icon(Icons.school_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Nama semester tidak boleh kosong';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            TextFormField(
              controller: _numberController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nomor Semester',
                hintText: 'Contoh: 4',
                prefixIcon: Icon(Icons.format_list_numbered),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Nomor semester tidak boleh kosong';
                }
                final n = int.tryParse(v);
                if (n == null || n <= 0) {
                  return 'Nomor semester harus berupa angka positif (minimal 1)';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Pilihan Skala Penilaian Kampus
            DropdownButtonFormField<int>(
              initialValue: _gradingScaleId,
              decoration: const InputDecoration(
                labelText: 'Skala Penilaian Kampus',
                hintText: 'Pilih aturan konversi nilai',
                prefixIcon: Icon(Icons.tune_outlined),
                helperText: 'Skala konversi nilai angka (0-100) ke huruf mutu untuk semester ini.',
              ),
              items: context
                  .read<AcademicRepository>()
                  .getAllGradingScales()
                  .map(
                    (s) => DropdownMenuItem<int>(
                      value: s.id,
                      child: Text('${s.name}${s.isDefault ? ' (Bawaan)' : ''}'),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _gradingScaleId = val);
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Rentang Tanggal
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(isStart: true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Tanggal Mulai',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(
                        _startDate != null
                            ? DateFormatter.shortDate(_startDate!)
                            : 'Pilih tanggal',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: _startDate != null
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(isStart: false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Tanggal Selesai',
                        prefixIcon: Icon(Icons.event_outlined),
                      ),
                      child: Text(
                        _endDate != null
                            ? DateFormatter.shortDate(_endDate!)
                            : 'Pilih tanggal',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: _endDate != null
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Jadikan Semester Aktif'),
              subtitle: const Text(
                'Mengaktifkan semester ini akan secara otomatis menonaktifkan semester aktif sebelumnya.',
              ),
              value: _makeActive,
              onChanged: (_existingTerm?.isActive == true)
                  ? null
                  : (val) => setState(() => _makeActive = val),
            ),
            const SizedBox(height: AppSpacing.lg),

            FilledButton(
              onPressed: vm.isLoading ? null : _submit,
              child: vm.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEditing ? 'Simpan Perubahan' : 'Buat Semester'),
            ),
          ],
        ),
      ),
    );
  }
}
