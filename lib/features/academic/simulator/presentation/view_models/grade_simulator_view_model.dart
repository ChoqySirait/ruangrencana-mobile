import 'package:flutter/foundation.dart';

import '../../../../../core/utils/academic_calculator.dart';
import '../../../grades/data/models/academic_overview.dart';
import '../../../grades/data/repositories/academic_repository.dart';

/// ViewModel untuk Simulasi Nilai dan proyeksi IPS/IPK.
///
/// Sesuai aturan bisnis RuangRencana: seluruh perubahan nilai pada simulasi
/// disimpan terpisah di memori ViewModel ini dan tidak pernah menimpa
/// catatan akademik asli pada repository.
class GradeSimulatorViewModel extends ChangeNotifier {
  GradeSimulatorViewModel({required this._academicRepository}) {
    _overview = _academicRepository.getAcademicOverview();
    _resetHypotheticalScoresInternal();
  }

  final AcademicRepository _academicRepository;
  late AcademicOverview _overview;
  final Map<String, double> _hypotheticalScores = {};

  AcademicOverview get overview => _overview;

  double scoreForCourse(String courseId) => _hypotheticalScores[courseId] ?? 80;

  GradeScaleRule? simulatedRuleForCourse(String courseId) {
    return AcademicCalculator.resolveGradeRule(
      scoreForCourse(courseId),
      _overview.gradingScale,
    );
  }

  /// Proyeksi IPS semester berjalan berdasarkan skor simulasi saat ini.
  double get simulatedIps {
    final weighted = <WeightedGradePoint>[];
    for (final summary in _overview.courseGrades) {
      final rule = simulatedRuleForCourse(summary.course.id);
      weighted.add(
        WeightedGradePoint(
          sks: summary.course.sks,
          gradePoint: rule?.gradePoint ?? 0.0,
        ),
      );
    }
    return AcademicCalculator.calculateWeightedGpa(weighted);
  }

  /// Proyeksi IPK kumulatif jika semester berjalan diselesaikan dengan
  /// hasil simulasi saat ini.
  double get simulatedIpk {
    final weighted = <WeightedGradePoint>[
      ..._overview.historicalSemesters.map(
        (sem) => WeightedGradePoint(sks: sem.sks, gradePoint: sem.ips),
      ),
      WeightedGradePoint(sks: _overview.activeSks, gradePoint: simulatedIps),
    ];
    return AcademicCalculator.calculateWeightedGpa(weighted);
  }

  void updateHypotheticalScore(String courseId, double score) {
    final clamped = score.clamp(0.0, 100.0);
    if (_hypotheticalScores[courseId] == clamped) return;
    _hypotheticalScores[courseId] = clamped;
    notifyListeners();
  }

  void resetSimulation() {
    _resetHypotheticalScoresInternal();
    notifyListeners();
  }

  void _resetHypotheticalScoresInternal() {
    _hypotheticalScores.clear();
    for (final summary in _overview.courseGrades) {
      _hypotheticalScores[summary.course.id] =
          summary.calculation.provisionalAverage ?? 80.0;
    }
  }
}
