import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/widgets/info_badge.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../academic/grades/data/repositories/academic_repository.dart';
import '../view_models/profile_view_model.dart';

/// Halaman Profil: informasi mahasiswa yang dapat diubah, kampus & prodi,
/// konfigurasi tahun akademik & semester, akses pengaturan konversi nilai,
/// serta preferensi notifikasi.
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  Future<void> _showEditProfileDialog(
    BuildContext context,
    ProfileViewModel vm,
  ) async {
    final profile = vm.profile;
    final nameController = TextEditingController(text: profile.fullName);
    final nimController = TextEditingController(text: profile.studentId);
    final emailController = TextEditingController(text: profile.email);
    final universityController = TextEditingController(
      text: profile.university,
    );
    final programController = TextEditingController(text: profile.studyProgram);
    final yearController = TextEditingController(text: profile.academicYear);
    final semesterController = TextEditingController(
      text: profile.activeSemesterLabel,
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ubah Profil Akademik'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nama Lengkap'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: nimController,
                decoration: const InputDecoration(labelText: 'NIM (Contoh)'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email Kampus'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: universityController,
                decoration: const InputDecoration(
                  labelText: 'Perguruan Tinggi',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: programController,
                decoration: const InputDecoration(labelText: 'Program Studi'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: yearController,
                decoration: const InputDecoration(labelText: 'Tahun Akademik'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: semesterController,
                decoration: const InputDecoration(labelText: 'Semester Aktif'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              vm.updateProfile(
                fullName: nameController.text,
                studentId: nimController.text,
                email: emailController.text,
                university: universityController.text,
                studyProgram: programController.text,
                academicYear: yearController.text,
                activeSemesterLabel: semesterController.text,
              );
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    nameController.dispose();
    nimController.dispose();
    emailController.dispose();
    universityController.dispose();
    programController.dispose();
    yearController.dispose();
    semesterController.dispose();

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil diperbarui pada sesi lokal saat ini.'),
        ),
      );
    }
  }

  void _showGradeScalePreview(BuildContext context) {
    final overview = context.read<AcademicRepository>().getAcademicOverview();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pengaturan Skala Konversi Nilai',
                  style: AppTextStyles.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${overview.gradingScaleName}. Skala ini tidak bersifat baku untuk semua kampus dan akan dapat diubah penuh pada fase implementasi database lokal.',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: overview.gradingScale.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (_, index) {
                      final rule = overview.gradingScale[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: InfoBadge(
                          label: rule.letter,
                          tone: BadgeTone.primary,
                        ),
                        title: Text(
                          'Rentang ${rule.minScore.toStringAsFixed(0)} – ${rule.maxScore.toStringAsFixed(2)}',
                          style: AppTextStyles.bodyMedium,
                        ),
                        trailing: Text(
                          'Mutu ${rule.gradePoint.toStringAsFixed(2)}',
                          style: AppTextStyles.labelLarge,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Tutup'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileViewModel>();
    final profile = vm.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          TextButton.icon(
            onPressed: () => _showEditProfileDialog(context, vm),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Ubah'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal,
          vertical: AppSpacing.xs,
        ),
        children: [
          // Kartu identitas mahasiswa
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primaryNavy,
                    child: Text(
                      profile.firstName.isNotEmpty
                          ? profile.firstName[0].toUpperCase()
                          : 'M',
                      style: AppTextStyles.headlineMedium.copyWith(
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.fullName,
                          style: AppTextStyles.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          'NIM ${profile.studentId}',
                          style: AppTextStyles.bodySmall,
                        ),
                        Text(
                          profile.email,
                          style: AppTextStyles.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Informasi perguruan tinggi & konfigurasi semester
          const SectionHeader(title: 'Informasi Akademik'),
          const SizedBox(height: AppSpacing.xs),
          Card(
            child: Column(
              children: [
                _ProfileDetailTile(
                  icon: Icons.account_balance_outlined,
                  label: 'Perguruan Tinggi',
                  value: profile.university,
                ),
                const Divider(),
                _ProfileDetailTile(
                  icon: Icons.menu_book_outlined,
                  label: 'Program Studi',
                  value: profile.studyProgram,
                ),
                const Divider(),
                _ProfileDetailTile(
                  icon: Icons.date_range_outlined,
                  label: 'Tahun Akademik',
                  value: profile.academicYear,
                ),
                const Divider(),
                _ProfileDetailTile(
                  icon: Icons.layers_outlined,
                  label: 'Semester Aktif',
                  value: profile.activeSemesterLabel,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Konfigurasi konversi nilai
          const SectionHeader(title: 'Pengaturan Penilaian'),
          const SizedBox(height: AppSpacing.xs),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.tune_rounded,
                color: AppColors.primaryNavy,
              ),
              title: const Text(
                'Skala Konversi Nilai Kampus',
                style: AppTextStyles.titleSmall,
              ),
              subtitle: const Text(
                'Tinjau aturan rentang nilai huruf dan bobot mutu yang dapat dikonfigurasi',
                style: AppTextStyles.bodySmall,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showGradeScalePreview(context),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Preferensi notifikasi
          const SectionHeader(title: 'Preferensi Notifikasi'),
          const SizedBox(height: AppSpacing.xs),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: profile.notifyClassReminder,
                  onChanged: vm.setClassReminder,
                  activeThumbColor: AppColors.secondaryTeal,
                  title: const Text(
                    'Pengingat Kelas',
                    style: AppTextStyles.titleSmall,
                  ),
                  subtitle: const Text(
                    'Notifikasi sebelum jadwal kuliah dimulai',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  value: profile.notifyDeadlineReminder,
                  onChanged: vm.setDeadlineReminder,
                  activeThumbColor: AppColors.secondaryTeal,
                  title: const Text(
                    'Pengingat Tenggat Tugas',
                    style: AppTextStyles.titleSmall,
                  ),
                  subtitle: const Text(
                    'Peringatan untuk tugas yang mendekati batas waktu',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  value: profile.notifyWeeklySummary,
                  onChanged: vm.setWeeklySummary,
                  activeThumbColor: AppColors.secondaryTeal,
                  title: const Text(
                    'Ringkasan Mingguan',
                    style: AppTextStyles.titleSmall,
                  ),
                  subtitle: const Text(
                    'Rekap jadwal dan progres tugas setiap akhir pekan',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _ProfileDetailTile extends StatelessWidget {
  const _ProfileDetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryNavy),
      title: Text(label, style: AppTextStyles.labelMedium),
      subtitle: Text(value, style: AppTextStyles.bodyLarge),
    );
  }
}
