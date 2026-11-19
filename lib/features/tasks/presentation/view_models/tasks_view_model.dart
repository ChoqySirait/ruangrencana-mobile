import 'package:flutter/foundation.dart';

import '../../data/models/assignment_item.dart';
import '../../data/repositories/task_repository.dart';

/// ViewModel untuk daftar tugas, filter status, serta penambahan/pembaruan tugas.
class TasksViewModel extends ChangeNotifier {
  TasksViewModel({required this._repository, this._onDataChanged});

  final TaskRepository _repository;
  final VoidCallback? _onDataChanged;

  AssignmentFilter _selectedFilter = AssignmentFilter.all;

  AssignmentFilter get selectedFilter => _selectedFilter;

  List<AssignmentItem> get allAssignments => _repository.getAllAssignments();

  List<AssignmentItem> get filteredAssignments {
    final now = DateTime.now();
    final items = allAssignments;
    return switch (_selectedFilter) {
      AssignmentFilter.all => items,
      AssignmentFilter.upcoming =>
        items
            .where((item) => item.statusAt(now) == AssignmentStatus.upcoming)
            .toList(growable: false),
      AssignmentFilter.overdue =>
        items
            .where((item) => item.statusAt(now) == AssignmentStatus.overdue)
            .toList(growable: false),
      AssignmentFilter.completed =>
        items
            .where((item) => item.statusAt(now) == AssignmentStatus.completed)
            .toList(growable: false),
    };
  }

  int countForFilter(AssignmentFilter filter) {
    final now = DateTime.now();
    final items = allAssignments;
    return switch (filter) {
      AssignmentFilter.all => items.length,
      AssignmentFilter.upcoming =>
        items.where((i) => i.statusAt(now) == AssignmentStatus.upcoming).length,
      AssignmentFilter.overdue =>
        items.where((i) => i.statusAt(now) == AssignmentStatus.overdue).length,
      AssignmentFilter.completed =>
        items
            .where((i) => i.statusAt(now) == AssignmentStatus.completed)
            .length,
    };
  }

  AssignmentItem? findById(String id) => _repository.getAssignmentById(id);

  void setFilter(AssignmentFilter filter) {
    if (_selectedFilter == filter) return;
    _selectedFilter = filter;
    notifyListeners();
  }

  void toggleCompleted(String id) {
    _repository.toggleCompleted(id);
    notifyListeners();
    _onDataChanged?.call();
  }

  void saveNewAssignment({
    required String title,
    required String courseId,
    required String courseName,
    required DateTime dueDate,
    required AssignmentPriority priority,
    String notes = '',
  }) {
    final newItem = AssignmentItem(
      id: 'tgs-${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim(),
      courseId: courseId,
      courseName: courseName,
      dueDate: dueDate,
      priority: priority,
      notes: notes.trim(),
    );
    _repository.addAssignment(newItem);
    notifyListeners();
    _onDataChanged?.call();
  }

  void saveEditedAssignment(AssignmentItem updated) {
    _repository.updateAssignment(updated);
    notifyListeners();
    _onDataChanged?.call();
  }
}
