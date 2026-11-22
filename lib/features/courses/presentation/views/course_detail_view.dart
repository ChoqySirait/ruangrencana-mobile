import 'dart:math';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:ruangrencana/app/router/app_router.dart';
import 'package:ruangrencana/app/theme/app_colors.dart';
import 'package:ruangrencana/app/theme/app_spacing.dart';
import 'package:ruangrencana/app/theme/app_text_styles.dart';
import 'package:ruangrencana/core/utils/academic_calculator.dart';
import 'package:ruangrencana/core/utils/date_formatter.dart';
import 'package:ruangrencana/core/widgets/info_badge.dart';
import 'package:ruangrencana/core/widgets/section_header.dart';
import 'package:ruangrencana/features/academic/grades/data/repositories/academic_repository.dart';
import 'package:ruangrencana/features/academic/grades/presentation/view_models/academic_view_model.dart';
import 'package:ruangrencana/features/courses/data/models/course_item.dart';
import 'package:ruangrencana/features/courses/data/repositories/course_repository.dart';
import 'package:ruangrencana/features/courses/presentation/view_models/course_detail_view_model.dart';
import 'package:ruangrencana/features/courses/presentation/view_models/courses_view_model.dart';
import 'package:ruangrencana/features/dashboard/presentation/view_models/dashboard_view_model.dart';
import 'package:ruangrencana/features/schedule/data/models/schedule_item.dart';
import 'package:ruangrencana/features/schedule/data/repositories/schedule_repository.dart';
import 'package:ruangrencana/features/schedule/presentation/view_models/schedule_view_model.dart';
import 'package:ruangrencana/features/tasks/data/repositories/task_repository.dart';
import 'package:ruangrencana/features/tasks/presentation/view_models/tasks_view_model.dart';
import 'package:ruangrencana/features/tasks/presentation/widgets/assignment_card.dart';

/// Layar sekunder Detail Mata Kuliah: informasi kelas, jadwal sesi mingguan,
/// komponen bobot penilaian, pencatatan nilai, status nilai sementara/akhir,
/// serta daftar tugas terkait mata kuliah.
class CourseDetailView extends StatelessWidget {
  const CourseDetailView({required this.courseId, super.key});

  final String courseId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => CourseDetailViewModel(
        courseId: courseId,
        courseRepository: context.read<CourseRepository>(),
        taskRepository: context.read<TaskRepository>(),
        academicRepository: context.read<AcademicRepository>(),
        scheduleRepository: context.read<ScheduleRepository>(),
        onCourseUpdated: () async {
          if (context.mounted) {
            context.read<DashboardViewModel>().refresh();
            context.read<AcademicViewModel>().refresh();
            context.read<ScheduleViewModel>().refresh();
            context.read<CoursesViewModel>().loadCourses();
          }
        },
      ),
      child: const _CourseDetailBody(),
    );
  }
}

class _CourseDetailBody extends StatelessWidget {
  const _CourseDetailBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CourseDetailViewModel>();
    final tasksVm = context.watch<TasksViewModel>();
    final course = vm.course;

    if (course == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Mata Kuliah')),
        body: const Center(
          child: Text(
            'Mata kuliah tidak ditemukan.',
            style: AppTextStyles.bodyMedium,
          ),
        ),
      );
    }

    final calc = course.gradeCalculation;
    final courseTasks = tasksVm.allAssignments
        .where((item) => item.courseId == course.id)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(course.code),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Mata Kuliah',
            onPressed: () async {
              await context.pushNamed(
                AppRoutes.editCourse,
                pathParameters: {'courseId': course.id},
              );
              vm.load();
            },
          ),
          PopupMenuButton<String>(
            onSelected: (val) async {
              switch (val) {
                case 'archive':
                  final success = await vm.archiveCourse();
                  if (context.mounted && success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Mata kuliah berhasil diarsipkan.'),
                      ),
                    );
                  }
                  break;
                case 'unarchive':
                  final success = await vm.unarchiveCourse();
                  if (context.mounted && success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Arsip mata kuliah dibuka kembali.'),
                      ),
                    );
                  }
                  break;
                case 'delete':
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Hapus Mata Kuliah?'),
                      content: Text(
                        'Apakah Anda yakin ingin menghapus "${course.name}"? '
                        'Semua jadwal dan komponen penilaian terkait akan dihapus.',
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
                    final success = await vm.deleteCourse(force: true);
                    if (context.mounted) {
                      if (success) {
                        context.pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Mata kuliah berhasil dihapus.'),
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
                  break;
              }
            },
            itemBuilder: (ctx) => [
              if (!course.isArchived)
                const PopupMenuItem(
                  value: 'archive',
                  child: Row(
                    children: [
                      Icon(Icons.archive_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Arsipkan'),
                    ],
                  ),
                )
              else
                const PopupMenuItem(
                  value: 'unarchive',
                  child: Row(
                    children: [
                      Icon(Icons.unarchive_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Buka Arsip'),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: const [
                    Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppColors.error,
                    ),
                    SizedBox(width: 8),
                    Text('Hapus', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
        children: [
          // Header Informasi Mata Kuliah
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      InfoBadge(label: course.code, tone: BadgeTone.primary),
                      InfoBadge(
                        label: '${course.sks} SKS',
                        tone: BadgeTone.secondary,
                      ),
                      if (course.isArchived)
                        const InfoBadge(
                          label: 'Diarsipkan',
                          tone: BadgeTone.warning,
                        )
                      else if (calc.isFinalReady)
                        const InfoBadge(
                          label: 'Nilai Final Siap',
                          tone: BadgeTone.secondary,
                        )
                      else if (calc.provisionalAverage != null)
                        InfoBadge(
                          label:
                              'Nilai Sementara (${calc.gradedWeightPercent.toStringAsFixed(0)}% terisi)',
                          tone: BadgeTone.warning,
                        )
                      else
                        const InfoBadge(
                          label: 'Belum Ada Nilai',
                          tone: BadgeTone.neutral,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(course.name, style: AppTextStyles.headlineMedium),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(
                    icon: Icons.person_outline_rounded,
                    text: course.lecturer.isNotEmpty
                        ? course.lecturer
                        : 'Dosen belum ditentukan',
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _InfoRow(
                    icon: Icons.schedule_rounded,
                    text: course.scheduleLabel,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _InfoRow(icon: Icons.location_on_outlined, text: course.room),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Ringkasan Kalkulasi & Konversi Nilai
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          calc.isFinalReady
                              ? 'Skor Akhir Mata Kuliah'
                              : 'Rata-rata Nilai Sementara',
                          style: AppTextStyles.labelMedium,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          calc.provisionalAverage != null
                              ? calc.provisionalAverage!.toStringAsFixed(1)
                              : '-',
                          style: AppTextStyles.headlineLarge.copyWith(
                            color: AppColors.primaryNavy,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          calc.isFinalReady
                              ? 'Seluruh komponen wajib dinilai (100%)'
                              : 'Bobot dinilai: ${calc.gradedWeightPercent.toStringAsFixed(0)}% dari ${calc.totalConfiguredWeightPercent.toStringAsFixed(0)}%',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Column(
                      children: [
                        Text(
                          vm.resolvedGradeRule?.letter ?? '-',
                          style: AppTextStyles.headlineMedium.copyWith(
                            color: AppColors.primaryNavy,
                          ),
                        ),
                        Text(
                          vm.resolvedGradeRule != null
                              ? 'Mutu ${vm.resolvedGradeRule!.gradePoint.toStringAsFixed(2)}'
                              : 'Belum ada',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.primaryNavy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Seksi: Jadwal Kuliah Mingguan
          SectionHeader(
            title: 'Jadwal Kuliah',
            actionLabel: 'Tambah jadwal',
            onActionTap: () => _showScheduleDialog(context, vm),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (vm.schedules.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    const Text(
                      'Belum ada sesi jadwal tercatat untuk mata kuliah ini.',
                      style: AppTextStyles.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Tambah Jadwal Kuliah'),
                      onPressed: () => _showScheduleDialog(context, vm),
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < vm.schedules.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _ScheduleTile(
                      schedule: vm.schedules[i],
                      onEdit: () => _showScheduleDialog(
                        context,
                        vm,
                        existingSchedule: vm.schedules[i],
                      ),
                      onDelete: () => _showDeleteScheduleDialog(
                        context,
                        vm,
                        vm.schedules[i],
                      ),
                    ),
                  ],
                ],
              ),
            ),

          const SizedBox(height: AppSpacing.lg),

          // Seksi: Komponen Penilaian & Skor
          SectionHeader(
            title: 'Komponen Penilaian',
            actionLabel: 'Tambah komponen',
            onActionTap: () => _showComponentDialog(context, vm),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Indikator Akumulasi Bobot
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Total Bobot Konfigurasi',
                        style: AppTextStyles.labelMedium,
                      ),
                    ),
                    Text(
                      '${calc.totalConfiguredWeightPercent.toStringAsFixed(0)}% / 100%',
                      style: AppTextStyles.titleSmall.copyWith(
                        color:
                            (calc.totalConfiguredWeightPercent - 100.0).abs() <=
                                0.001
                            ? AppColors.secondaryTeal
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                LinearProgressIndicator(
                  value: min(calc.totalConfiguredWeightPercent / 100.0, 1.0),
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    (calc.totalConfiguredWeightPercent - 100.0).abs() <= 0.001
                        ? AppColors.secondaryTeal
                        : AppColors.primaryNavy,
                  ),
                ),
                if ((calc.totalConfiguredWeightPercent - 100.0).abs() >
                    0.001) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    calc.totalConfiguredWeightPercent < 100.0
                        ? 'Lengkapi komponen hingga 100% untuk mengaktifkan perhitungan nilai akhir.'
                        : 'Peringatan: Total bobot melebihi 100%.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          if (course.assessmentComponents.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    const Text(
                      'Belum ada komponen penilaian untuk mata kuliah ini.',
                      style: AppTextStyles.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Tambah Komponen Penilaian'),
                      onPressed: () => _showComponentDialog(context, vm),
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (
                    var i = 0;
                    i < course.assessmentComponents.length;
                    i++
                  ) ...[
                    if (i > 0) const Divider(height: 1),
                    _AssessmentComponentTile(
                      component: course.assessmentComponents[i],
                      onSetScore: () => _showScoreDialog(
                        context,
                        vm,
                        course.assessmentComponents[i],
                      ),
                      onEditComponent: () => _showComponentDialog(
                        context,
                        vm,
                        existingComponent: course.assessmentComponents[i],
                      ),
                      onDeleteComponent: () => _showDeleteComponentDialog(
                        context,
                        vm,
                        course.assessmentComponents[i],
                      ),
                      onDeleteScore: () async {
                        final ok = await vm.deleteScore(
                          course.assessmentComponents[i].id,
                        );
                        if (ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Nilai berhasil dihapus.'),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),

          const SizedBox(height: AppSpacing.lg),

          // Seksi: Tugas Terkait Mata Kuliah
          SectionHeader(
            title: 'Tugas Mata Kuliah',
            actionLabel: 'Tambah tugas',
            onActionTap: () => context.pushNamed(AppRoutes.addTask),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (courseTasks.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'Belum ada tugas tercatat untuk mata kuliah ini.',
                  style: AppTextStyles.bodySmall,
                ),
              ),
            )
          else
            ...courseTasks.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: AssignmentCard(
                  item: task,
                  onToggleComplete: () => tasksVm.toggleCompleted(task.id),
                  onTap: () => context.pushNamed(
                    AppRoutes.editTask,
                    pathParameters: {'taskId': task.id},
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- Dialog Operasi Jadwal Kuliah ---

  Future<void> _showScheduleDialog(
    BuildContext context,
    CourseDetailViewModel vm, {
    ScheduleItem? existingSchedule,
  }) async {
    int selectedWeekday = existingSchedule?.dayOfWeek ?? 1;
    String startTime = existingSchedule?.startTime ?? '08:00';
    String endTime = existingSchedule?.endTime ?? '09:40';
    final roomController = TextEditingController(
      text: existingSchedule?.room ?? 'Ruang Kelas',
    );
    String? dialogError;
    List<ScheduleItem> conflicts = [];

    // Cek konflik awal
    conflicts = await vm.checkScheduleConflict(
      weekday: selectedWeekday,
      startTime: startTime,
      endTime: endTime,
      excludeScheduleId: existingSchedule != null
          ? int.tryParse(existingSchedule.id)
          : null,
    );

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> recheckConflict() async {
            final found = await vm.checkScheduleConflict(
              weekday: selectedWeekday,
              startTime: startTime,
              endTime: endTime,
              excludeScheduleId: existingSchedule != null
                  ? int.tryParse(existingSchedule.id)
                  : null,
            );
            setDialogState(() {
              conflicts = found;
            });
          }

          return AlertDialog(
            title: Text(
              existingSchedule == null
                  ? 'Tambah Jadwal Kuliah'
                  : 'Edit Jadwal Kuliah',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: selectedWeekday,
                    decoration: const InputDecoration(
                      labelText: 'Hari Perkuliahan',
                      border: OutlineInputBorder(),
                    ),
                    items: [1, 2, 3, 4, 5, 6, 7]
                        .map(
                          (w) => DropdownMenuItem(
                            value: w,
                            child: Text(DateFormatter.fullDayName(w)),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedWeekday = val);
                        recheckConflict();
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final parts = startTime.split(':');
                            final initialTime = TimeOfDay(
                              hour: int.tryParse(parts[0]) ?? 8,
                              minute: int.tryParse(parts[1]) ?? 0,
                            );
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: initialTime,
                            );
                            if (picked != null) {
                              setDialogState(() {
                                startTime =
                                    '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                              });
                              recheckConflict();
                            }
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mulai',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(startTime, style: AppTextStyles.titleMedium),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final parts = endTime.split(':');
                            final initialTime = TimeOfDay(
                              hour: int.tryParse(parts[0]) ?? 9,
                              minute: int.tryParse(parts[1]) ?? 40,
                            );
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: initialTime,
                            );
                            if (picked != null) {
                              setDialogState(() {
                                endTime =
                                    '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                              });
                              recheckConflict();
                            }
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selesai',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(endTime, style: AppTextStyles.titleMedium),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: roomController,
                    decoration: const InputDecoration(
                      labelText: 'Ruang / Gedung',
                      hintText: 'Contoh: Ruang 402, Lab Komputer',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (conflicts.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.warningSoft,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.warning,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Peringatan Bentrok Jadwal!',
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Bentrok dengan ${conflicts.first.courseName} (${conflicts.first.startTime} - ${conflicts.first.endTime}, ${conflicts.first.room}).',
                                  style: AppTextStyles.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (dialogError != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      dialogError!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () async {
                  final classroom = roomController.text.trim();
                  if (classroom.isEmpty) {
                    setDialogState(() {
                      dialogError = 'Ruang kelas tidak boleh kosong.';
                    });
                    return;
                  }

                  final startParts = startTime.split(':');
                  final endParts = endTime.split(':');
                  final startMin =
                      (int.tryParse(startParts[0]) ?? 0) * 60 +
                      (int.tryParse(startParts[1]) ?? 0);
                  final endMin =
                      (int.tryParse(endParts[0]) ?? 0) * 60 +
                      (int.tryParse(endParts[1]) ?? 0);

                  if (startMin >= endMin) {
                    setDialogState(() {
                      dialogError = 'Jam selesai harus lebih lambat dari jam mulai perkuliahan.';
                    });
                    return;
                  }

                  bool success;
                  if (existingSchedule == null) {
                    success = await vm.addSchedule(
                      weekday: selectedWeekday,
                      startTime: startTime,
                      endTime: endTime,
                      classroom: classroom,
                    );
                  } else {
                    success = await vm.updateSchedule(
                      scheduleId: int.parse(existingSchedule.id),
                      weekday: selectedWeekday,
                      startTime: startTime,
                      endTime: endTime,
                      classroom: classroom,
                    );
                  }

                  if (ctx.mounted) {
                    if (success) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            existingSchedule == null
                                ? 'Jadwal kuliah berhasil ditambahkan.'
                                : 'Jadwal kuliah berhasil diperbarui.',
                          ),
                        ),
                      );
                    } else {
                      setDialogState(() {
                        dialogError =
                            vm.errorMessage ?? 'Gagal menyimpan jadwal.';
                      });
                    }
                  }
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showDeleteScheduleDialog(
    BuildContext context,
    CourseDetailViewModel vm,
    ScheduleItem schedule,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Jadwal Kuliah?'),
        content: Text(
          'Hapus jadwal ${DateFormatter.fullDayName(schedule.dayOfWeek)}, '
          '${schedule.timeRange} (${schedule.room})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final success = await vm.deleteSchedule(int.parse(schedule.id));
      if (context.mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Jadwal kuliah berhasil dihapus.')),
        );
      }
    }
  }

  // --- Dialog Operasi Komponen Penilaian ---

  Future<void> _showComponentDialog(
    BuildContext context,
    CourseDetailViewModel vm, {
    CourseAssessmentComponent? existingComponent,
  }) async {
    final nameController = TextEditingController(
      text: existingComponent?.name ?? '',
    );
    final weightController = TextEditingController(
      text: existingComponent != null
          ? existingComponent.weightPercent.toStringAsFixed(0)
          : '',
    );
    final initialScoreController = TextEditingController();
    bool isMandatory = existingComponent?.isMandatory ?? true;
    String? dialogError;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(
              existingComponent == null
                  ? 'Tambah Komponen Penilaian'
                  : 'Edit Komponen Penilaian',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Komponen',
                      hintText: 'Contoh: UTS, UAS, Tugas, Praktikum',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Bobot Persentase (%)',
                      hintText: 'Contoh: 30',
                      border: OutlineInputBorder(),
                      suffixText: '%',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SwitchListTile(
                    title: const Text('Komponen Wajib'),
                    subtitle: const Text(
                      'Wajib dinilai agar nilai akhir dapat dihitung',
                    ),
                    value: isMandatory,
                    onChanged: (val) {
                      setDialogState(() => isMandatory = val);
                    },
                  ),
                  if (existingComponent == null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: initialScoreController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Nilai Awal (Opsional)',
                        hintText: '0.0 - 100.0',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (dialogError != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      dialogError!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    setDialogState(() {
                      dialogError = 'Nama komponen tidak boleh kosong.';
                    });
                    return;
                  }

                  final weight = double.tryParse(
                    weightController.text.replaceAll(',', '.'),
                  );
                  if (weight == null || weight <= 0.0 || weight > 100.0) {
                    setDialogState(() {
                      dialogError = 'Bobot harus berupa angka lebih besar dari 0% dan maksimal 100%.';
                    });
                    return;
                  }

                  double? initialScore;
                  if (initialScoreController.text.trim().isNotEmpty) {
                    final sc = double.tryParse(
                      initialScoreController.text.trim().replaceAll(',', '.'),
                    );
                    if (sc == null || !AcademicCalculator.isValidScore(sc)) {
                      setDialogState(() {
                        dialogError = 'Nilai awal harus berada di antara 0.0 sampai 100.0.';
                      });
                      return;
                    }
                    initialScore = sc;
                  }

                  bool success;
                  if (existingComponent == null) {
                    success = await vm.addAssessmentComponent(
                      name: name,
                      weightPercent: weight,
                      isRequired: isMandatory,
                      initialScore: initialScore,
                    );
                  } else {
                    success = await vm.updateAssessmentComponent(
                      componentId: existingComponent.id,
                      name: name,
                      weightPercent: weight,
                      isRequired: isMandatory,
                      sortOrder: existingComponent.sortOrder,
                    );
                  }

                  if (ctx.mounted) {
                    if (success) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            existingComponent == null
                                ? 'Komponen penilaian berhasil ditambahkan.'
                                : 'Komponen penilaian berhasil diperbarui.',
                          ),
                        ),
                      );
                    } else {
                      setDialogState(() {
                        dialogError =
                            vm.errorMessage ??
                            'Gagal menyimpan komponen penilaian.';
                      });
                    }
                  }
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showDeleteComponentDialog(
    BuildContext context,
    CourseDetailViewModel vm,
    CourseAssessmentComponent component,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Komponen Penilaian?'),
        content: Text(
          'Hapus komponen "${component.name}" (${component.weightPercent.toStringAsFixed(0)}%)? '
          'Nilai yang tercatat pada komponen ini juga akan terhapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final success = await vm.deleteAssessmentComponent(component.id);
      if (context.mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Komponen penilaian berhasil dihapus.')),
        );
      }
    }
  }

  // --- Dialog Pencatatan Nilai ---

  Future<void> _showScoreDialog(
    BuildContext context,
    CourseDetailViewModel vm,
    CourseAssessmentComponent component,
  ) async {
    final scoreController = TextEditingController(
      text: component.score != null ? component.score!.toStringAsFixed(1) : '',
    );
    final notesController = TextEditingController(text: component.notes);
    String? dialogError;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text('Nilai: ${component.name}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bobot: ${component.weightPercent.toStringAsFixed(0)}% • '
                    '${component.isMandatory ? 'Wajib' : 'Opsional'}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: scoreController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Skor / Nilai (0 - 100)',
                      hintText: 'Contoh: 85.5',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Catatan Penilaian (Opsional)',
                      hintText: 'Contoh: Remedial, Tugas kelompok',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      dialogError!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () async {
                  final text = scoreController.text.trim().replaceAll(',', '.');
                  if (text.isEmpty) {
                    setDialogState(() {
                      dialogError = 'Silakan masukkan skor angka.';
                    });
                    return;
                  }

                  final score = double.tryParse(text);
                  if (score == null ||
                      !AcademicCalculator.isValidScore(score)) {
                    setDialogState(() {
                      dialogError = 'Nilai harus berupa angka valid dalam rentang 0.0 sampai 100.0.';
                    });
                    return;
                  }

                  final success = await vm.recordScore(
                    componentId: component.id,
                    score: score,
                    notes: notesController.text.trim(),
                  );

                  if (ctx.mounted) {
                    if (success) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Nilai ${component.name} berhasil disimpan (${score.toStringAsFixed(1)}).',
                          ),
                        ),
                      );
                    } else {
                      setDialogState(() {
                        dialogError =
                            vm.errorMessage ?? 'Gagal menyimpan nilai.';
                      });
                    }
                  }
                },
                child: const Text('Simpan Nilai'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
      ],
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({
    required this.schedule,
    required this.onEdit,
    required this.onDelete,
  });

  final ScheduleItem schedule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: AppColors.primarySoft,
        child: Icon(Icons.access_time_rounded, color: AppColors.primaryNavy),
      ),
      title: Text(
        '${DateFormatter.fullDayName(schedule.dayOfWeek)}, ${schedule.timeRange}',
        style: AppTextStyles.titleSmall,
      ),
      subtitle: Text(
        schedule.room.isNotEmpty ? schedule.room : 'Ruang Kelas',
        style: AppTextStyles.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Edit Jadwal',
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              size: 20,
              color: AppColors.error,
            ),
            tooltip: 'Hapus Jadwal',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _AssessmentComponentTile extends StatelessWidget {
  const _AssessmentComponentTile({
    required this.component,
    required this.onSetScore,
    required this.onEditComponent,
    required this.onDeleteComponent,
    required this.onDeleteScore,
  });

  final CourseAssessmentComponent component;
  final VoidCallback onSetScore;
  final VoidCallback onEditComponent;
  final VoidCallback onDeleteComponent;
  final VoidCallback onDeleteScore;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Row(
        children: [
          Expanded(
            child: Text(component.name, style: AppTextStyles.titleSmall),
          ),
          if (component.hasScore)
            Text(
              component.score!.toStringAsFixed(1),
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.primaryNavy,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bobot ${component.weightPercent.toStringAsFixed(0)}% • '
            '${component.isMandatory ? 'Wajib' : 'Opsional'}'
            '${component.hasScore ? ' • Kontribusi: ${(component.score! * component.weightPercent / 100.0).toStringAsFixed(1)}' : ''}',
            style: AppTextStyles.bodySmall,
          ),
          if (component.notes.isNotEmpty)
            Text(
              'Catatan: ${component.notes}',
              style: AppTextStyles.bodySmall.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (component.hasScore)
            IconButton(
              icon: const Icon(Icons.edit_note_rounded, size: 22),
              tooltip: 'Ubah Nilai',
              onPressed: onSetScore,
            )
          else
            OutlinedButton(
              onPressed: onSetScore,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Beri Nilai', style: TextStyle(fontSize: 12)),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (val) {
              switch (val) {
                case 'edit_score':
                  onSetScore();
                  break;
                case 'delete_score':
                  onDeleteScore();
                  break;
                case 'edit_comp':
                  onEditComponent();
                  break;
                case 'delete_comp':
                  onDeleteComponent();
                  break;
              }
            },
            itemBuilder: (ctx) => [
              if (component.hasScore) ...[
                const PopupMenuItem(
                  value: 'edit_score',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Ubah Nilai'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete_score',
                  child: Row(
                    children: [
                      Icon(
                        Icons.remove_circle_outline,
                        size: 18,
                        color: AppColors.error,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Hapus Nilai',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
              ],
              const PopupMenuItem(
                value: 'edit_comp',
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Edit Komponen'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete_comp',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppColors.error,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Hapus Komponen',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
