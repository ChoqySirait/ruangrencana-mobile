import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:ruangrencana/app/router/app_router.dart';
import 'package:ruangrencana/app/theme/app_colors.dart';
import 'package:ruangrencana/app/theme/app_spacing.dart';
import 'package:ruangrencana/app/theme/app_text_styles.dart';
import 'package:ruangrencana/core/widgets/info_badge.dart';
import 'package:ruangrencana/core/widgets/section_header.dart';
import 'package:ruangrencana/features/academic/grades/data/repositories/academic_repository.dart';
import 'package:ruangrencana/features/academic/grades/presentation/view_models/academic_view_model.dart';
import 'package:ruangrencana/features/courses/data/repositories/course_repository.dart';
import 'package:ruangrencana/features/courses/presentation/view_models/course_detail_view_model.dart';
import 'package:ruangrencana/features/dashboard/presentation/view_models/dashboard_view_model.dart';
import 'package:ruangrencana/features/schedule/presentation/view_models/schedule_view_model.dart';
import 'package:ruangrencana/features/tasks/data/repositories/task_repository.dart';
import 'package:ruangrencana/features/tasks/presentation/view_models/tasks_view_model.dart';
import 'package:ruangrencana/features/tasks/presentation/widgets/assignment_card.dart';

/// Layar sekunder Detail Mata Kuliah: informasi kelas, komponen bobot penilaian,
/// status nilai sementara/akhir, dan daftar tugas terkait mata kuliah tersebut.
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
        onCourseUpdated: () async {
          if (context.mounted) {
            context.read<DashboardViewModel>().refresh();
            context.read<AcademicViewModel>().refresh();
            final schedVm = context.read<ScheduleViewModel>();
            schedVm.selectDay(schedVm.selectedDayOfWeek);
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
                        'Jika mata kuliah memiliki riwayat akademik, pertimbangkan untuk mengarsipkannya.',
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
          // Header mata kuliah
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
                      else
                        InfoBadge(
                          label: calc.isFinalReady
                              ? 'Nilai Final'
                              : 'Nilai Sementara (${calc.gradedWeightPercent.toStringAsFixed(0)}%)',
                          tone: calc.isFinalReady
                              ? BadgeTone.secondary
                              : BadgeTone.warning,
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

          // Ringkasan kalkulasi nilai
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
                              : 'Rata-rata Sementara',
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
                          'Bobot dinilai: ${calc.gradedWeightPercent.toStringAsFixed(0)}% dari ${calc.totalConfiguredWeightPercent.toStringAsFixed(0)}%',
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

          // Komponen Penilaian
          const SectionHeader(title: 'Komponen Penilaian'),
          const SizedBox(height: AppSpacing.xs),
          if (course.assessmentComponents.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'Belum ada komponen penilaian untuk mata kuliah ini.',
                  style: AppTextStyles.bodySmall,
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
                    if (i > 0) const Divider(),
                    ListTile(
                      title: Text(
                        course.assessmentComponents[i].name,
                        style: AppTextStyles.titleSmall,
                      ),
                      subtitle: Text(
                        'Bobot ${course.assessmentComponents[i].weightPercent.toStringAsFixed(0)}% • ${course.assessmentComponents[i].isMandatory ? 'Wajib' : 'Opsional'}',
                        style: AppTextStyles.bodySmall,
                      ),
                      trailing: course.assessmentComponents[i].hasScore
                          ? Text(
                              course.assessmentComponents[i].score!
                                  .toStringAsFixed(0),
                              style: AppTextStyles.titleMedium.copyWith(
                                color: AppColors.primaryNavy,
                              ),
                            )
                          : const InfoBadge(
                              label: 'Belum dinilai',
                              tone: BadgeTone.neutral,
                            ),
                    ),
                  ],
                ],
              ),
            ),

          const SizedBox(height: AppSpacing.lg),

          // Tugas Terkait
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
