import 'package:flutter/foundation.dart';

import '../../data/models/student_profile.dart';
import '../../data/repositories/profile_repository.dart';

/// ViewModel untuk halaman Profil, pengaturan akademik dasar, dan preferensi notifikasi.
class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({required this._repository, this._onProfileChanged}) {
    _profile = _repository.getProfile();
  }

  final ProfileRepository _repository;
  final VoidCallback? _onProfileChanged;

  late StudentProfile _profile;
  StudentProfile get profile => _profile;

  void refresh() {
    _profile = _repository.getProfile();
    notifyListeners();
  }

  Future<void> updateProfile({
    required String fullName,
    required String studentId,
    required String email,
    required String university,
    required String studyProgram,
    required String academicYear,
    required String activeSemesterLabel,
  }) async {
    _profile = _profile.copyWith(
      fullName: fullName.trim(),
      studentId: studentId.trim(),
      email: email.trim(),
      university: university.trim(),
      studyProgram: studyProgram.trim(),
      academicYear: academicYear.trim(),
      activeSemesterLabel: activeSemesterLabel.trim(),
    );
    await _repository.saveProfile(_profile);
    notifyListeners();
    _onProfileChanged?.call();
  }

  Future<void> setClassReminder(bool enabled) async {
    _profile = _profile.copyWith(notifyClassReminder: enabled);
    await _repository.saveProfile(_profile);
    notifyListeners();
  }

  Future<void> setDeadlineReminder(bool enabled) async {
    _profile = _profile.copyWith(notifyDeadlineReminder: enabled);
    await _repository.saveProfile(_profile);
    notifyListeners();
  }

  Future<void> setWeeklySummary(bool enabled) async {
    _profile = _profile.copyWith(notifyWeeklySummary: enabled);
    await _repository.saveProfile(_profile);
    notifyListeners();
  }
}
