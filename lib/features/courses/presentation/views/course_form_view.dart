import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:ruangrencana/app/theme/app_colors.dart';
import 'package:ruangrencana/app/theme/app_spacing.dart';
import 'package:ruangrencana/app/theme/app_text_styles.dart';
import 'package:ruangrencana/features/academic/grades/data/repositories/academic_repository.dart';
import 'package:ruangrencana/features/courses/data/repositories/course_repository.dart';
import 'package:ruangrencana/features/courses/presentation/view_models/course_form_view_model.dart';

/// Formulir Tambah dan Edit Mata Kuliah.
class CourseFormView extends StatelessWidget {
  const CourseFormView({this.courseId, super.key});

  final String? courseId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => CourseFormViewModel(
        courseRepository: context.read<CourseRepository>(),
        academicRepository: context.read<AcademicRepository>(),
        courseId: courseId,
      ),
      child: const _CourseFormBody(),
    );
  }
}

class _CourseFormBody extends StatefulWidget {
  const _CourseFormBody();

  @override
  State<_CourseFormBody> createState() => _CourseFormBodyState();
}

class _CourseFormBodyState extends State<_CourseFormBody> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _creditsController;
  late final TextEditingController _lecturerController;

  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
    _nameController = TextEditingController();
    _creditsController = TextEditingController(text: '3');
    _lecturerController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      _isInit = true;
      final vm = context.read<CourseFormViewModel>();
      if (vm.isEditing) {
        _codeController.text = vm.code;
        _nameController.text = vm.name;
        _creditsController.text = vm.credits.toString();
        _lecturerController.text = vm.lecturer;
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _creditsController.dispose();
    _lecturerController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<CourseFormViewModel>();
    vm.setCode(_codeController.text.trim());
    vm.setName(_nameController.text.trim());
    vm.setCredits(int.parse(_creditsController.text.trim()));
    vm.setLecturer(_lecturerController.text.trim());

    final success = await vm.save();
    if (mounted && success) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            vm.isEditing
                ? 'Mata kuliah berhasil diperbarui.'
                : 'Mata kuliah baru berhasil ditambahkan.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CourseFormViewModel>();
    final semesters = vm.availableSemesters;

    return Scaffold(
      appBar: AppBar(
        title: Text(vm.isEditing ? 'Edit Mata Kuliah' : 'Tambah Mata Kuliah'),
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
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error),
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

            DropdownButtonFormField<int>(
              initialValue: vm.termId,
              decoration: const InputDecoration(
                labelText: 'Semester Akademik',
                prefixIcon: Icon(Icons.calendar_today_outlined),
              ),
              items: semesters.map((term) {
                return DropdownMenuItem<int>(
                  value: term.id,
                  child: Text(
                    '${term.fullLabel}${term.isActive ? ' (Aktif)' : ''}',
                  ),
                );
              }).toList(),
              onChanged: vm.setTermId,
              validator: (v) =>
                  v == null ? 'Silakan pilih semester akademik' : null,
            ),
            const SizedBox(height: AppSpacing.md),

            TextFormField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Kode Mata Kuliah',
                hintText: 'Contoh: IF2401',
                prefixIcon: Icon(Icons.tag_rounded),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Kode mata kuliah tidak boleh kosong';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Mata Kuliah',
                hintText: 'Contoh: Pemrograman Mobile',
                prefixIcon: Icon(Icons.school_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Nama mata kuliah tidak boleh kosong';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            TextFormField(
              controller: _creditsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Jumlah SKS',
                hintText: 'Contoh: 3',
                prefixIcon: Icon(Icons.hourglass_bottom_rounded),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'SKS tidak boleh kosong';
                }
                final n = int.tryParse(v);
                if (n == null || n <= 0) {
                  return 'SKS harus berupa angka positif (minimal 1)';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            TextFormField(
              controller: _lecturerController,
              decoration: const InputDecoration(
                labelText: 'Dosen Pengampu',
                hintText: 'Contoh: Dr. Budi Santoso, M.Kom.',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
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
                  : Text(
                      vm.isEditing ? 'Simpan Perubahan' : 'Tambah Mata Kuliah',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
