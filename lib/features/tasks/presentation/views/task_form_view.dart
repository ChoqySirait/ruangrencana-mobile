import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../courses/data/models/course_item.dart';
import '../../../courses/data/repositories/course_repository.dart';
import '../../data/models/assignment_item.dart';
import '../view_models/tasks_view_model.dart';

/// Layar sekunder untuk menambahkan tugas baru atau mengubah tugas yang ada.
class TaskFormView extends StatefulWidget {
  const TaskFormView({this.taskId, super.key});

  /// Jika `null`, form beroperasi dalam mode Tambah Tugas.
  /// Jika terisi, form beroperasi dalam mode Ubah Tugas.
  final String? taskId;

  bool get isEditMode => taskId != null;

  @override
  State<TaskFormView> createState() => _TaskFormViewState();
}

class _TaskFormViewState extends State<TaskFormView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  late List<CourseItem> _courses;
  late String _selectedCourseId;
  late DateTime _selectedDueDate;
  late AssignmentPriority _selectedPriority;
  AssignmentItem? _editingItem;

  @override
  void initState() {
    super.initState();
    _courses = context.read<CourseRepository>().getActiveCourses();
    final tasksVm = context.read<TasksViewModel>();
    _editingItem = widget.taskId != null
        ? tasksVm.findById(widget.taskId!)
        : null;

    if (_editingItem != null) {
      _titleController.text = _editingItem!.title;
      _notesController.text = _editingItem!.notes;
      _selectedCourseId = _editingItem!.courseId;
      _selectedDueDate = _editingItem!.dueDate;
      _selectedPriority = _editingItem!.priority;
    } else {
      _selectedCourseId = _courses.isNotEmpty ? _courses.first.id : '';
      final now = DateTime.now();
      _selectedDueDate = DateTime(now.year, now.month, now.day + 2, 23, 59);
      _selectedPriority = AssignmentPriority.medium;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked == null) return;
    setState(() {
      _selectedDueDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _selectedDueDate.hour,
        _selectedDueDate.minute,
      );
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final selectedCourse = _courses.firstWhere(
      (c) => c.id == _selectedCourseId,
      orElse: () => _courses.first,
    );
    final tasksVm = context.read<TasksViewModel>();

    if (_editingItem != null) {
      tasksVm.saveEditedAssignment(
        _editingItem!.copyWith(
          title: _titleController.text.trim(),
          courseId: selectedCourse.id,
          courseName: selectedCourse.name,
          dueDate: _selectedDueDate,
          priority: _selectedPriority,
          notes: _notesController.text.trim(),
        ),
      );
    } else {
      tasksVm.saveNewAssignment(
        title: _titleController.text,
        courseId: selectedCourse.id,
        courseName: selectedCourse.name,
        dueDate: _selectedDueDate,
        priority: _selectedPriority,
        notes: _notesController.text,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.isEditMode
              ? 'Perubahan tugas berhasil disimpan ke database.'
              : 'Tugas baru berhasil disimpan ke database.',
        ),
      ),
    );
    context.pop();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Tugas'),
        content: Text(
          'Apakah Anda yakin ingin menghapus "${_editingItem?.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<TasksViewModel>().deleteAssignment(_editingItem!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tugas berhasil dihapus dari database.'),
          ),
        );
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNotFound = widget.isEditMode && _editingItem == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditMode ? 'Ubah Tugas' : 'Tambah Tugas'),
        actions: [
          if (widget.isEditMode && _editingItem != null)
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
              tooltip: 'Hapus Tugas',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: isNotFound
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Data tugas tidak ditemukan.',
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
                children: [
                  const Text('Judul Tugas', style: AppTextStyles.labelLarge),
                  const SizedBox(height: AppSpacing.xs),
                  TextFormField(
                    controller: _titleController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Contoh: Laporan Praktikum Basis Data',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Judul tugas wajib diisi.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  const Text('Mata Kuliah', style: AppTextStyles.labelLarge),
                  const SizedBox(height: AppSpacing.xs),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCourseId,
                    isExpanded: true,
                    items: _courses
                        .map(
                          (course) => DropdownMenuItem(
                            value: course.id,
                            child: Text(
                              '${course.code} — ${course.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedCourseId = value);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  const Text('Tenggat Waktu', style: AppTextStyles.labelLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.calendar_today_outlined,
                        color: AppColors.primaryNavy,
                      ),
                      title: Text(
                        DateFormatter.shortDateWithTime(_selectedDueDate),
                        style: AppTextStyles.bodyMedium,
                      ),
                      subtitle: const Text(
                        'Ketuk untuk mengubah tanggal tenggat',
                        style: AppTextStyles.bodySmall,
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _pickDueDate,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  const Text('Prioritas', style: AppTextStyles.labelLarge),
                  const SizedBox(height: AppSpacing.xs),
                  SegmentedButton<AssignmentPriority>(
                    segments: AssignmentPriority.values
                        .map(
                          (p) => ButtonSegment<AssignmentPriority>(
                            value: p,
                            label: Text(p.label),
                          ),
                        )
                        .toList(),
                    selected: {_selectedPriority},
                    onSelectionChanged: (selected) {
                      setState(() => _selectedPriority = selected.first);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  const Text(
                    'Catatan (Opsional)',
                    style: AppTextStyles.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Tambahkan instruksi pengumpulan atau poin penting...',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  FilledButton(
                    onPressed: _submit,
                    child: Text(
                      widget.isEditMode ? 'Simpan Perubahan' : 'Simpan Tugas',
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
