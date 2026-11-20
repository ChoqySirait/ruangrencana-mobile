import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:ruangrencana/app/router/app_router.dart';
import 'package:ruangrencana/app/theme/app_colors.dart';
import 'package:ruangrencana/app/theme/app_spacing.dart';
import 'package:ruangrencana/app/theme/app_text_styles.dart';
import 'package:ruangrencana/core/widgets/info_badge.dart';
import 'package:ruangrencana/features/courses/data/models/course_item.dart';
import 'package:ruangrencana/features/courses/presentation/view_models/courses_view_model.dart';

/// Layar Daftar Mata Kuliah dengan filter berbasis semester dan status arsip.
class CoursesView extends StatelessWidget {
  const CoursesView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CoursesViewModel>();
    final semesters = vm.availableSemesters;
    final selectedTerm = vm.currentSelectedSemester;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Mata Kuliah'),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: vm.showArchived
                ? 'Tampilkan Mata Kuliah Aktif'
                : 'Tampilkan Arsip',
            color: vm.showArchived ? AppColors.secondaryTeal : null,
            onPressed: vm.toggleShowArchived,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(AppRoutes.addCourse),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Mata Kuliah'),
      ),
      body: Column(
        children: [
          // Bar Pemilih Semester & Pencarian
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageHorizontal,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: selectedTerm?.id,
                        decoration: const InputDecoration(
                          labelText: 'Semester',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                        ),
                        items: semesters.map((term) {
                          return DropdownMenuItem<int>(
                            value: term.id,
                            child: Text(
                              '${term.fullLabel}${term.isActive ? ' (Aktif)' : ''}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => vm.selectSemester(val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Cari kode, nama, atau dosen...',
                    prefixIcon: Icon(Icons.search_rounded),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                  ),
                  onChanged: vm.setSearchQuery,
                ),
              ],
            ),
          ),

          if (vm.showArchived)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageHorizontal,
                vertical: AppSpacing.xs,
              ),
              color: AppColors.surfaceSubtle,
              child: const Row(
                children: [
                  Icon(Icons.archive, size: 16, color: AppColors.textSecondary),
                  SizedBox(width: AppSpacing.xs),
                  Text(
                    'Menampilkan mata kuliah yang diarsipkan',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),

          Expanded(
            child: vm.isLoading
                ? const Center(child: CircularProgressIndicator())
                : vm.courses.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.school_outlined,
                            size: 48,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            vm.showArchived
                                ? 'Tidak ada mata kuliah yang diarsipkan.'
                                : 'Belum ada mata kuliah pada semester ini.',
                            style: AppTextStyles.titleSmall,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          const Text(
                            'Gunakan tombol di bawah untuk menambahkan mata kuliah baru.',
                            style: AppTextStyles.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async => vm.loadCourses(),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageHorizontal,
                        AppSpacing.xs,
                        AppSpacing.pageHorizontal,
                        80,
                      ),
                      itemCount: vm.courses.length,
                      itemBuilder: (context, index) {
                        final course = vm.courses[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _CourseItemCard(
                            course: course,
                            isArchived: vm.showArchived,
                            onTap: () => context.pushNamed(
                              AppRoutes.courseDetail,
                              pathParameters: {'courseId': course.id},
                            ),
                            onEdit: () => context.pushNamed(
                              AppRoutes.editCourse,
                              pathParameters: {'courseId': course.id},
                            ),
                            onArchive: () => vm.archiveCourse(course.id),
                            onUnarchive: () => vm.unarchiveCourse(course.id),
                            onDelete: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Hapus Mata Kuliah?'),
                                  content: Text(
                                    'Apakah Anda yakin ingin menghapus "${course.name}"? '
                                    'Tindakan ini akan menghapus jadwal dan komponen penilaian terkait.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
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
                                final success = await vm.deleteCourse(
                                  course.id,
                                  force: true,
                                );
                                if (context.mounted && success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Mata kuliah berhasil dihapus.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CourseItemCard extends StatelessWidget {
  const _CourseItemCard({
    required this.course,
    required this.isArchived,
    required this.onTap,
    required this.onEdit,
    required this.onArchive,
    required this.onUnarchive,
    required this.onDelete,
  });

  final CourseItem course;
  final bool isArchived;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onUnarchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final calc = course.gradeCalculation;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InfoBadge(label: course.code, tone: BadgeTone.primary),
                  const SizedBox(width: AppSpacing.xs),
                  InfoBadge(
                    label: '${course.sks} SKS',
                    tone: BadgeTone.neutral,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  if (isArchived)
                    const InfoBadge(
                      label: 'Diarsipkan',
                      tone: BadgeTone.warning,
                    )
                  else
                    InfoBadge(
                      label: calc.isFinalReady ? 'Final' : 'Sementara',
                      tone: calc.isFinalReady
                          ? BadgeTone.secondary
                          : BadgeTone.neutral,
                    ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      switch (val) {
                        case 'edit':
                          onEdit();
                          break;
                        case 'archive':
                          onArchive();
                          break;
                        case 'unarchive':
                          onUnarchive();
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
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      if (!isArchived)
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
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: AppColors.error,
                            ),
                            SizedBox(width: 8),
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
              const SizedBox(height: AppSpacing.xs),
              Text(course.name, style: AppTextStyles.titleMedium),
              if (course.lecturer.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  course.lecturer,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Expanded(
                    child: Text(
                      course.scheduleLabel,
                      style: AppTextStyles.bodySmall,
                      overflow: TextOverflow.ellipsis,
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
