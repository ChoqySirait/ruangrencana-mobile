import 'package:flutter/foundation.dart';

import '../../data/models/dashboard_summary.dart';
import '../../data/repositories/dashboard_repository.dart';

/// ViewModel untuk halaman Beranda.
///
/// Bertanggung jawab memuat ringkasan akademik, jadwal terdekat, dan tugas
/// mendesak tanpa meletakkan logika agregasi di dalam widget.
class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel({required this._repository}) {
    refresh();
  }

  final DashboardRepository _repository;

  late DashboardSummary _summary;
  DashboardSummary get summary => _summary;

  String get greetingPrefix {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat pagi';
    if (hour < 15) return 'Selamat siang';
    if (hour < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  void refresh() {
    _summary = _repository.loadDashboard();
    notifyListeners();
  }
}
