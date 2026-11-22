import 'package:flutter/foundation.dart';

import '../../data/models/schedule_item.dart';
import '../../data/repositories/schedule_repository.dart';

/// ViewModel untuk halaman Jadwal Kuliah mingguan.
class ScheduleViewModel extends ChangeNotifier {
  ScheduleViewModel({required this._repository, int? initialDayOfWeek})
    : _selectedDayOfWeek = _normalizeWeekday(
        initialDayOfWeek ?? DateTime.now().weekday,
      );

  final ScheduleRepository _repository;
  int _selectedDayOfWeek;

  /// Daftar hari kuliah aktif: Senin (1) sampai Sabtu (6).
  static const List<int> activeDays = [1, 2, 3, 4, 5, 6];

  int get selectedDayOfWeek => _selectedDayOfWeek;

  List<ScheduleItem> get schedulesForSelectedDay =>
      _repository.getSchedulesForDay(_selectedDayOfWeek);

  int classCountForDay(int dayOfWeek) =>
      _repository.getSchedulesForDay(dayOfWeek).length;

  int get totalSksForSelectedDay =>
      schedulesForSelectedDay.fold<int>(0, (sum, item) => sum + item.sks);

  void selectDay(int dayOfWeek) {
    if (_selectedDayOfWeek == dayOfWeek) return;
    _selectedDayOfWeek = dayOfWeek;
    notifyListeners();
  }

  Future<void> refresh() async {
    await _repository.load();
    notifyListeners();
  }

  static int _normalizeWeekday(int weekday) {
    if (weekday < 1 || weekday > 6) return 1;
    return weekday;
  }
}
