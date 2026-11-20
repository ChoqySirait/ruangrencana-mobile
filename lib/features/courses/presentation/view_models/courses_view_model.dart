import 'package:flutter/foundation.dart';
import 'package:ruangrencana/core/errors/app_failure.dart';
import 'package:ruangrencana/features/academic/grades/data/repositories/academic_repository.dart';
import 'package:ruangrencana/features/academic/terms/data/models/academic_term_item.dart';
import 'package:ruangrencana/features/courses/data/models/course_item.dart';
import 'package:ruangrencana/features/courses/data/repositories/course_repository.dart';

/// ViewModel untuk daftar mata kuliah dengan penyaringan berbasis semester dan status arsip.
class CoursesViewModel extends ChangeNotifier {
  CoursesViewModel({
    required this.courseRepository,
    required this.academicRepository,
    this.onCoursesChanged,
  }) {
    _selectedTermId = academicRepository.getActiveSemester()?.id;
  }

  final CourseRepository courseRepository;
  final AcademicRepository academicRepository;
  final AsyncCallback? onCoursesChanged;

  int? _selectedTermId;
  bool _showArchived = false;
  String _searchQuery = '';
  List<CourseItem> _courses = const [];
  bool _isLoading = false;
  String? _errorMessage;

  int? get selectedTermId => _selectedTermId;
  bool get showArchived => _showArchived;
  String get searchQuery => _searchQuery;
  List<CourseItem> get courses => _courses;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<AcademicTermItem> get availableSemesters =>
      academicRepository.getAllSemesters();

  AcademicTermItem? get activeSemester =>
      academicRepository.getActiveSemester();

  AcademicTermItem? get currentSelectedSemester {
    if (_selectedTermId == null) return activeSemester;
    return academicRepository.getSemesterById(_selectedTermId!);
  }

  Future<void> loadCourses() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final termId = _selectedTermId ?? activeSemester?.id;
      if (termId == null) {
        _courses = const [];
      } else {
        final fetched = await courseRepository.getCoursesBySemester(
          termId,
          includeArchived: true,
        );

        _courses = fetched
            .where((c) {
              if (!_showArchived && c.isArchived) return false;
              if (_showArchived && !c.isArchived) return false;
              if (_searchQuery.isNotEmpty) {
                final q = _searchQuery.toLowerCase();
                final matchCode = c.code.toLowerCase().contains(q);
                final matchName = c.name.toLowerCase().contains(q);
                final matchLecturer = c.lecturer.toLowerCase().contains(q);
                return matchCode || matchName || matchLecturer;
              }
              return true;
            })
            .toList(growable: false);
      }
    } catch (e) {
      _errorMessage = 'Gagal memuat mata kuliah: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectSemester(int? termId) {
    _selectedTermId = termId;
    loadCourses();
  }

  void toggleShowArchived() {
    _showArchived = !_showArchived;
    loadCourses();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    loadCourses();
  }

  Future<bool> archiveCourse(String id) async {
    try {
      await courseRepository.archiveCourse(id);
      await loadCourses();
      if (onCoursesChanged != null) {
        await onCoursesChanged!();
      }
      return true;
    } on AppFailure catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Gagal mengarsipkan mata kuliah: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> unarchiveCourse(String id) async {
    try {
      await courseRepository.unarchiveCourse(id);
      await loadCourses();
      if (onCoursesChanged != null) {
        await onCoursesChanged!();
      }
      return true;
    } on AppFailure catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Gagal membatalkan arsip mata kuliah: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCourse(String id, {bool force = false}) async {
    try {
      await courseRepository.deleteCourse(id, force: force);
      await loadCourses();
      if (onCoursesChanged != null) {
        await onCoursesChanged!();
      }
      return true;
    } on AppFailure catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Gagal menghapus mata kuliah: $e';
      notifyListeners();
      return false;
    }
  }
}
