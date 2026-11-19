import 'package:flutter/foundation.dart';

import '../../../../core/utils/academic_calculator.dart';
import '../../../academic/grades/data/repositories/academic_repository.dart';
import '../../../tasks/data/models/assignment_item.dart';
import '../../../tasks/data/repositories/task_repository.dart';
import '../../data/models/course_item.dart';
import '../../data/repositories/course_repository.dart';

/// ViewModel untuk layar Detail Mata Kuliah.
class CourseDetailViewModel extends ChangeNotifier {
  CourseDetailViewModel({
    required this._courseId,
    required this._courseRepository,
    required this._taskRepository,
    required this._academicRepository,
  }) {
    load();
  }

  final String _courseId;
  final CourseRepository _courseRepository;
  final TaskRepository _taskRepository;
  final AcademicRepository _academicRepository;

  CourseItem? _course;
  List<AssignmentItem> _assignments = const [];
  GradeScaleRule? _resolvedGradeRule;

  CourseItem? get course => _course;
  List<AssignmentItem> get assignments => _assignments;
  GradeScaleRule? get resolvedGradeRule => _resolvedGradeRule;

  void load() {
    _course = _courseRepository.getCourseById(_courseId);
    if (_course != null) {
      _assignments = _taskRepository.getAssignmentsByCourse(_courseId);
      final score = _course!.gradeCalculation.provisionalAverage;
      if (score != null) {
        _resolvedGradeRule = AcademicCalculator.resolveGradeRule(
          score,
          _academicRepository.getActiveGradingScale(),
        );
      } else {
        _resolvedGradeRule = null;
      }
    }
    notifyListeners();
  }
}
