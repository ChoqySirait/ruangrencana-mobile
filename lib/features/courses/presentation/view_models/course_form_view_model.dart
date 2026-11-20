import 'package:flutter/foundation.dart';
import 'package:ruangrencana/core/errors/app_failure.dart';
import 'package:ruangrencana/features/academic/grades/data/repositories/academic_repository.dart';
import 'package:ruangrencana/features/academic/terms/data/models/academic_term_item.dart';
import 'package:ruangrencana/features/courses/data/repositories/course_repository.dart';

/// ViewModel untuk formulir tambah dan edit mata kuliah.
class CourseFormViewModel extends ChangeNotifier {
  CourseFormViewModel({
    required this.courseRepository,
    required this.academicRepository,
    this.courseId,
  }) {
    _init();
  }

  final CourseRepository courseRepository;
  final AcademicRepository academicRepository;
  final String? courseId;

  bool _isInit = false;
  bool _isLoading = false;
  String? _errorMessage;

  int? _termId;
  String _code = '';
  String _name = '';
  int _credits = 3;
  String _lecturer = '';

  bool get isEditing => courseId != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int? get termId => _termId;
  String get code => _code;
  String get name => _name;
  int get credits => _credits;
  String get lecturer => _lecturer;

  List<AcademicTermItem> get availableSemesters =>
      academicRepository.getAllSemesters();

  void _init() {
    if (_isInit) return;
    _isInit = true;

    if (courseId != null) {
      final course = courseRepository.getCourseById(courseId!);
      if (course != null) {
        _termId = course.termId;
        _code = course.code;
        _name = course.name;
        _credits = course.sks;
        _lecturer = course.lecturer;
      }
    } else {
      final active = academicRepository.getActiveSemester();
      _termId =
          active?.id ?? academicRepository.getAllSemesters().firstOrNull?.id;
    }
    notifyListeners();
  }

  void setTermId(int? id) {
    _termId = id;
    notifyListeners();
  }

  void setCode(String val) {
    _code = val;
    notifyListeners();
  }

  void setName(String val) {
    _name = val;
    notifyListeners();
  }

  void setCredits(int val) {
    _credits = val;
    notifyListeners();
  }

  void setLecturer(String val) {
    _lecturer = val;
    notifyListeners();
  }

  Future<bool> save() async {
    if (_termId == null) {
      _errorMessage = 'Silakan pilih semester akademik.';
      notifyListeners();
      return false;
    }
    if (_code.trim().isEmpty) {
      _errorMessage = 'Kode mata kuliah tidak boleh kosong.';
      notifyListeners();
      return false;
    }
    if (_name.trim().isEmpty) {
      _errorMessage = 'Nama mata kuliah tidak boleh kosong.';
      notifyListeners();
      return false;
    }
    if (_credits <= 0) {
      _errorMessage = 'SKS harus lebih besar dari 0.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (isEditing) {
        await courseRepository.updateCourse(
          id: courseId!,
          code: _code,
          name: _name,
          credits: _credits,
          lecturer: _lecturer,
          termId: _termId,
        );
      } else {
        await courseRepository.insertCourse(
          termId: _termId!,
          code: _code,
          name: _name,
          credits: _credits,
          lecturer: _lecturer,
        );
      }
      return true;
    } on AppFailure catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Gagal menyimpan mata kuliah: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
