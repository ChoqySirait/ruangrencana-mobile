import 'package:flutter/foundation.dart';
import 'package:ruangrencana/core/errors/app_failure.dart';
import 'package:ruangrencana/core/utils/academic_calculator.dart';
import 'package:ruangrencana/features/academic/grades/data/repositories/academic_repository.dart';
import 'package:ruangrencana/features/courses/data/models/course_item.dart';
import 'package:ruangrencana/features/courses/data/repositories/course_repository.dart';
import 'package:ruangrencana/features/schedule/data/models/schedule_item.dart';
import 'package:ruangrencana/features/schedule/data/repositories/schedule_repository.dart';
import 'package:ruangrencana/features/tasks/data/models/assignment_item.dart';
import 'package:ruangrencana/features/tasks/data/repositories/task_repository.dart';

/// ViewModel untuk layar Detail Mata Kuliah: informasi kelas, jadwal mingguan,
/// komponen penilaian, pencatatan nilai, dan daftar tugas terkait.
class CourseDetailViewModel extends ChangeNotifier {
  CourseDetailViewModel({
    required this.courseId,
    required this.courseRepository,
    required this.taskRepository,
    required this.academicRepository,
    required this.scheduleRepository,
    this.onCourseUpdated,
  }) {
    load();
  }

  final String courseId;
  final CourseRepository courseRepository;
  final TaskRepository taskRepository;
  final AcademicRepository academicRepository;
  final ScheduleRepository scheduleRepository;
  final AsyncCallback? onCourseUpdated;

  CourseItem? _course;
  List<ScheduleItem> _schedules = const [];
  List<AssignmentItem> _assignments = const [];
  GradeScaleRule? _resolvedGradeRule;
  String? _errorMessage;
  bool _isLoading = false;

  CourseItem? get course => _course;
  List<ScheduleItem> get schedules => _schedules;
  List<AssignmentItem> get assignments => _assignments;
  GradeScaleRule? get resolvedGradeRule => _resolvedGradeRule;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  void load() {
    _course = courseRepository.getCourseById(courseId);
    if (_course != null) {
      _assignments = taskRepository.getAssignmentsByCourse(courseId);
      _schedules = scheduleRepository.getSchedulesForCourse(courseId);
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

  // --- Operasi Jadwal Kuliah ---

  Future<List<ScheduleItem>> checkScheduleConflict({
    required int weekday,
    required String startTime,
    required String endTime,
    int? excludeScheduleId,
  }) async {
    try {
      return await scheduleRepository.findConflictingSchedules(
        weekday: weekday,
        startTime: startTime,
        endTime: endTime,
        excludeScheduleId: excludeScheduleId,
        courseId: int.tryParse(courseId),
      );
    } catch (_) {
      return const [];
    }
  }

  Future<bool> addSchedule({
    required int weekday,
    required String startTime,
    required String endTime,
    required String classroom,
  }) async {
    final cId = int.tryParse(courseId);
    if (cId == null) {
      _errorMessage = 'ID mata kuliah tidak valid.';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();
      await scheduleRepository.addSchedule(
        courseId: cId,
        weekday: weekday,
        startTime: startTime,
        endTime: endTime,
        classroom: classroom,
      );
      load();
      if (onCourseUpdated != null) await onCourseUpdated!();
      return true;
    } on AppFailure catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateSchedule({
    required int scheduleId,
    required int weekday,
    required String startTime,
    required String endTime,
    required String classroom,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();
      await scheduleRepository.updateSchedule(
        scheduleId: scheduleId,
        weekday: weekday,
        startTime: startTime,
        endTime: endTime,
        classroom: classroom,
      );
      load();
      if (onCourseUpdated != null) await onCourseUpdated!();
      return true;
    } on AppFailure catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteSchedule(int scheduleId) async {
    try {
      _isLoading = true;
      notifyListeners();
      await scheduleRepository.deleteSchedule(scheduleId);
      load();
      if (onCourseUpdated != null) await onCourseUpdated!();
      return true;
    } on AppFailure catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Operasi Komponen Penilaian & Skor ---

  Future<bool> addAssessmentComponent({
    required String name,
    required double weightPercent,
    bool isRequired = true,
    int sortOrder = 0,
    double? initialScore,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();
      await courseRepository.addAssessmentComponent(
        courseId: courseId,
        name: name,
        weightPercent: weightPercent,
        isRequired: isRequired,
        sortOrder: sortOrder,
        initialScore: initialScore,
        validateTotalWeight: true,
      );
      load();
      if (onCourseUpdated != null) await onCourseUpdated!();
      return true;
    } on AppFailure catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateAssessmentComponent({
    required int componentId,
    required String name,
    required double weightPercent,
    bool isRequired = true,
    int sortOrder = 0,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();
      await courseRepository.updateAssessmentComponent(
        componentId: componentId,
        name: name,
        weightPercent: weightPercent,
        isRequired: isRequired,
        sortOrder: sortOrder,
        validateTotalWeight: true,
      );
      load();
      if (onCourseUpdated != null) await onCourseUpdated!();
      return true;
    } on AppFailure catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteAssessmentComponent(int componentId) async {
    try {
      _isLoading = true;
      notifyListeners();
      await courseRepository.deleteAssessmentComponent(componentId);
      load();
      if (onCourseUpdated != null) await onCourseUpdated!();
      return true;
    } on AppFailure catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> recordScore({
    required int componentId,
    required double score,
    String notes = '',
  }) async {
    try {
      _isLoading = true;
      notifyListeners();
      await courseRepository.recordAssessmentScore(
        componentId: componentId,
        score: score,
        notes: notes,
      );
      load();
      if (onCourseUpdated != null) await onCourseUpdated!();
      return true;
    } on AppFailure catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteScore(int componentId) async {
    try {
      _isLoading = true;
      notifyListeners();
      await courseRepository.deleteAssessmentScore(componentId);
      load();
      if (onCourseUpdated != null) await onCourseUpdated!();
      return true;
    } on AppFailure catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
