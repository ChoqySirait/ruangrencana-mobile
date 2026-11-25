import 'package:flutter/foundation.dart';

import '../../data/models/assignment_item.dart';
import '../../data/repositories/task_repository.dart';

/// ViewModel untuk daftar tugas, pencarian, filter status, pengurutan,
/// serta operasi CRUD tugas kuliah.
class TasksViewModel extends ChangeNotifier {
  TasksViewModel({required this.repository, this.onDataChanged});

  final TaskRepository repository;
  final VoidCallback? onDataChanged;

  AssignmentFilter _selectedFilter = AssignmentFilter.all;
  AssignmentSort _selectedSort = AssignmentSort.dueSoonest;
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;

  AssignmentFilter get selectedFilter => _selectedFilter;
  AssignmentSort get selectedSort => _selectedSort;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<AssignmentItem> get allAssignments => repository.getAllAssignments();

  /// Mengembalikan daftar tugas yang telah disaring berdasarkan pencarian,
  /// filter status (mendatang, terlambat, selesai), dan diurutkan sesuai preferensi pengguna.
  List<AssignmentItem> get filteredAssignments {
    final now = DateTime.now();
    var items = allAssignments;

    // 1. Filter pencarian teks
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      items = items
          .where((item) {
            final titleMatch = item.title.toLowerCase().contains(query);
            final notesMatch = item.notes.toLowerCase().contains(query);
            final courseNameMatch = item.courseName.toLowerCase().contains(
              query,
            );
            final courseCodeMatch = item.courseCode.toLowerCase().contains(
              query,
            );
            return titleMatch ||
                notesMatch ||
                courseNameMatch ||
                courseCodeMatch;
          })
          .toList(growable: false);
    }

    // 2. Filter status
    items = switch (_selectedFilter) {
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

    // 3. Pengurutan
    final sorted = List<AssignmentItem>.from(items);
    switch (_selectedSort) {
      case AssignmentSort.dueSoonest:
        sorted.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        break;
      case AssignmentSort.priorityHighest:
        sorted.sort((a, b) {
          final priorityDiff = b.priority.rank.compareTo(a.priority.rank);
          if (priorityDiff != 0) return priorityDiff;
          return a.dueDate.compareTo(b.dueDate);
        });
        break;
      case AssignmentSort.courseName:
        sorted.sort((a, b) {
          final nameDiff = a.courseName.toLowerCase().compareTo(
            b.courseName.toLowerCase(),
          );
          if (nameDiff != 0) return nameDiff;
          return a.dueDate.compareTo(b.dueDate);
        });
        break;
      case AssignmentSort.newest:
        sorted.sort((a, b) {
          final timeA = a.createdAt ?? a.dueDate;
          final timeB = b.createdAt ?? b.dueDate;
          return timeB.compareTo(timeA);
        });
        break;
    }

    return List.unmodifiable(sorted);
  }

  /// Menghitung jumlah tugas untuk setiap filter status (dengan tetap memperhitungkan pencarian aktif).
  int countForFilter(AssignmentFilter filter) {
    final now = DateTime.now();
    var items = allAssignments;

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      items = items
          .where((item) {
            final titleMatch = item.title.toLowerCase().contains(query);
            final notesMatch = item.notes.toLowerCase().contains(query);
            final courseNameMatch = item.courseName.toLowerCase().contains(
              query,
            );
            final courseCodeMatch = item.courseCode.toLowerCase().contains(
              query,
            );
            return titleMatch ||
                notesMatch ||
                courseNameMatch ||
                courseCodeMatch;
          })
          .toList(growable: false);
    }

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

  AssignmentItem? findById(String id) => repository.getAssignmentById(id);

  void setFilter(AssignmentFilter filter) {
    if (_selectedFilter == filter) return;
    _selectedFilter = filter;
    notifyListeners();
  }

  void setSort(AssignmentSort sort) {
    if (_selectedSort == sort) return;
    _selectedSort = sort;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    if (_searchQuery.isEmpty) return;
    _searchQuery = '';
    notifyListeners();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await repository.load();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleCompleted(String id) async {
    try {
      await repository.toggleCompleted(id);
      notifyListeners();
      onDataChanged?.call();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> markCompleted(String id) async {
    try {
      await repository.markCompleted(id);
      notifyListeners();
      onDataChanged?.call();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> reopenAssignment(String id) async {
    try {
      await repository.reopenAssignment(id);
      notifyListeners();
      onDataChanged?.call();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> saveNewAssignment({
    required String title,
    required String courseId,
    required String courseName,
    String courseCode = '',
    required DateTime dueDate,
    required AssignmentPriority priority,
    String notes = '',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final newItem = AssignmentItem(
        id: 'tgs-${DateTime.now().millisecondsSinceEpoch}',
        title: title.trim(),
        courseId: courseId,
        courseName: courseName,
        courseCode: courseCode,
        dueDate: dueDate,
        priority: priority,
        notes: notes.trim(),
        createdAt: now,
        updatedAt: now,
      );
      await repository.addAssignment(newItem);
      onDataChanged?.call();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveEditedAssignment(AssignmentItem updated) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final itemToSave = updated.copyWith(updatedAt: DateTime.now());
      await repository.updateAssignment(itemToSave);
      onDataChanged?.call();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteAssignment(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await repository.deleteAssignment(id);
      onDataChanged?.call();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
