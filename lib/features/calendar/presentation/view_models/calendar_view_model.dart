import 'package:flutter/foundation.dart';

import '../../../schedule/data/models/schedule_item.dart';
import '../../../schedule/data/repositories/schedule_repository.dart';
import '../../../tasks/data/models/assignment_item.dart';
import '../../../tasks/data/repositories/task_repository.dart';

/// ViewModel untuk Kalender Akademik.
/// Mengintegrasikan jadwal perkuliahan mingguan aktif dan tenggat tugas
/// dari basis data SQLite secara dinamis tanpa duplikasi entitas.
class CalendarViewModel extends ChangeNotifier {
  CalendarViewModel({
    required this.taskRepository,
    required this.scheduleRepository,
    DateTime? initialDate,
  }) {
    final now = initialDate ?? DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  final TaskRepository taskRepository;
  final ScheduleRepository scheduleRepository;

  late DateTime _focusedMonth;
  late DateTime _selectedDate;

  DateTime get focusedMonth => _focusedMonth;
  DateTime get selectedDate => _selectedDate;

  void selectDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    if (_selectedDate.year != _focusedMonth.year ||
        _selectedDate.month != _focusedMonth.month) {
      _focusedMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    }
    notifyListeners();
  }

  void previousMonth() {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    notifyListeners();
  }

  void nextMonth() {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    notifyListeners();
  }

  void goToToday() {
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);
    notifyListeners();
  }

  /// Jadwal perkuliahan pada tanggal tertentu (berdasarkan hari dalam seminggu: weekday 1-7).
  List<ScheduleItem> getSchedulesForDate(DateTime date) {
    return scheduleRepository.getSchedulesForDay(date.weekday);
  }

  /// Daftar tugas kuliah yang memiliki tenggat pada tanggal tersebut (berdasarkan waktu lokal).
  List<AssignmentItem> getAssignmentsForDate(DateTime date) {
    return taskRepository
        .getAllAssignments()
        .where((item) {
          final dueLocal = item.dueDate.toLocal();
          return dueLocal.year == date.year &&
              dueLocal.month == date.month &&
              dueLocal.day == date.day;
        })
        .toList(growable: false);
  }

  bool hasClassesOnDate(DateTime date) => getSchedulesForDate(date).isNotEmpty;

  bool hasAssignmentsOnDate(DateTime date) =>
      getAssignmentsForDate(date).isNotEmpty;

  List<ScheduleItem> get selectedDateSchedules =>
      getSchedulesForDate(_selectedDate);

  List<AssignmentItem> get selectedDateAssignments =>
      getAssignmentsForDate(_selectedDate);

  int get totalEventsOnSelectedDate =>
      selectedDateSchedules.length + selectedDateAssignments.length;

  /// Nama bulan dan tahun dalam bahasa Indonesia.
  String get focusedMonthName {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${months[_focusedMonth.month - 1]} ${_focusedMonth.year}';
  }
}
