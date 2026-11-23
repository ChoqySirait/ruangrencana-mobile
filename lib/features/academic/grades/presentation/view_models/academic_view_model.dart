import 'package:flutter/foundation.dart';

import '../../data/models/academic_overview.dart';
import '../../data/repositories/academic_repository.dart';

/// ViewModel untuk halaman Akademik (ringkasan IPS, IPK, nilai mata kuliah,
/// dan progres studi).
class AcademicViewModel extends ChangeNotifier {
  AcademicViewModel({required this._repository}) {
    refresh();
  }

  final AcademicRepository _repository;
  late AcademicOverview _overview;

  AcademicOverview get overview => _overview;

  /// Rasio progres SKS yang telah lulus terhadap target kelulusan.
  double get sksProgressRatio {
    if (_overview.targetGraduationSks <= 0) return 0;
    return (_overview.totalPassedSks / _overview.targetGraduationSks).clamp(
      0.0,
      1.0,
    );
  }

  /// Rasio total SKS yang ditempuh (lulus lampau + aktif) terhadap target kelulusan.
  double get enrolledSksRatio {
    if (_overview.targetGraduationSks <= 0) return 0;
    return (_overview.totalEnrolledSks / _overview.targetGraduationSks).clamp(
      0.0,
      1.0,
    );
  }

  void refresh() {
    _overview = _repository.getAcademicOverview();
    notifyListeners();
  }
}
