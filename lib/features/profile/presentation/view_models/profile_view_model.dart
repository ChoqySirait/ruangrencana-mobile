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

  void updateProfile({
    required String fullName,
    required String studentId,
    required String email,
    required String university,
    required String studyProgram,
    required String academicYear,
    required String activeSemesterLabel,
  }) {
    _profile = _profile.copyWith(
      fullName: fullName.trim(),
      studentId: studentId.trim(),
      email: email.trim(),
      university: university.trim(),
      studyProgram: studyProgram.trim(),
      academicYear: academicYear.trim(),
      activeSemesterLabel: activeSemesterLabel.trim(),
    );
    _repository.saveProfile(_profile);
    notifyListeners();
    _onProfileChanged?.call();
  }

  void setClassReminder(bool enabled) {
    _profile = _profile.copyWith(notifyClassReminder: enabled);
    _repository.saveProfile(_profile);
    notifyListeners();
  }

  void setDeadlineReminder(bool enabled) {
    _profile = _profile.copyWith(notifyDeadlineReminder: enabled);
    _repository.saveProfile(_profile);
    notifyListeners();
  }

  void setWeeklySummary(bool enabled) {
    _profile = _profile.copyWith(notifyWeeklySummary: enabled);
    _repository.saveProfile(_profile);
    notifyListeners();
  }
}
