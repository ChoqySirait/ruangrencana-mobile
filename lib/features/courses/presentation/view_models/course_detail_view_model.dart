import 'package:flutter/foundation.dart';
import 'package:ruangrencana/core/errors/app_failure.dart';
import 'package:ruangrencana/core/utils/academic_calculator.dart';
import 'package:ruangrencana/features/academic/grades/data/repositories/academic_repository.dart';
import 'package:ruangrencana/features/courses/data/models/course_item.dart';
import 'package:ruangrencana/features/courses/data/repositories/course_repository.dart';
import 'package:ruangrencana/features/tasks/data/models/assignment_item.dart';
import 'package:ruangrencana/features/tasks/data/repositories/task_repository.dart';

/// ViewModel untuk layar Detail Mata Kuliah.
class CourseDetailViewModel extends ChangeNotifier {
  CourseDetailViewModel({
    required this.courseId,
    required this.courseRepository,
    required this.taskRepository,
    required this.academicRepository,
    this.onCourseUpdated,
  }) {
    load();
  }

  final String courseId;
  final CourseRepository courseRepository;
  final TaskRepository taskRepository;
  final AcademicRepository academicRepository;
  final AsyncCallback? onCourseUpdated;

  CourseItem? _course;
  List<AssignmentItem> _assignments = const [];
  GradeScaleRule? _resolvedGradeRule;
  String? _errorMessage;

  CourseItem? get course => _course;
  List<AssignmentItem> get assignments => _assignments;
  GradeScaleRule? get resolvedGradeRule => _resolvedGradeRule;
  String? get errorMessage => _errorMessage;

  void load() {
    _course = courseRepository.getCourseById(courseId);
    if (_course != null) {
      _assignments = taskRepository.getAssignmentsByCourse(courseId);
      final score = _course!.gradeCalculation.provisionalAverage;
      if (score != null) {
        _resolvedGradeRule = AcademicCalculator.resolveGradeRule(
          score,
          academicRepository.getActiveGradingScale(),
        );
      } else {
        _resolvedGradeRule = null;
      }
    }
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> archiveCourse() async {
    try {
      await courseRepository.archiveCourse(courseId);
      load();
      if (onCourseUpdated != null) await onCourseUpdated!();
      return true;
    } on AppFailure catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> unarchiveCourse() async {
    try {
      await courseRepository.unarchiveCourse(courseId);
      load();
      if (onCourseUpdated != null) await onCourseUpdated!();
      return true;
    } on AppFailure catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCourse({bool force = false}) async {
    try {
      await courseRepository.deleteCourse(courseId, force: force);
      if (onCourseUpdated != null) await onCourseUpdated!();
      return true;
    } on AppFailure catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }
}
