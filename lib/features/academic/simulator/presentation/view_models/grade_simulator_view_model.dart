import 'package:flutter/foundation.dart';
import 'package:ruangrencana/core/utils/academic_calculator.dart';
import 'package:ruangrencana/features/academic/grades/data/models/academic_overview.dart';
import 'package:ruangrencana/features/academic/grades/data/repositories/academic_repository.dart';

/// Rekomendasi perhitungan target IPS / IPK pada simulator.
class TargetGpaRecommendation {
  const TargetGpaRecommendation({
    required this.targetIps,
    required this.isAchievable,
    required this.averageRequiredScore,
    required this.averageRequiredGradePoint,
    required this.recommendedLetter,
    required this.statusMessage,
  });

  final double targetIps;
  final bool isAchievable;
  final double averageRequiredScore;
  final double averageRequiredGradePoint;
  final String recommendedLetter;
  final String statusMessage;
}

/// ViewModel untuk Simulasi Nilai dan proyeksi performa akademik IPS & IPK.
///
/// Seluruh manipulasi nilai di simulator disimpan strictly in-memory
/// dan diisolasi penuh dari database SQLite maupun repositori akademik.
class GradeSimulatorViewModel extends ChangeNotifier {
  GradeSimulatorViewModel({required this.academicRepository}) {
    _overview = academicRepository.getAcademicOverview();
    _resetHypotheticalScoresInternal();
  }

  final AcademicRepository academicRepository;
  late AcademicOverview _overview;
  final Map<String, double> _hypotheticalScores = {};

  double? _targetIps;
  double? _targetIpk;

  AcademicOverview get overview => _overview;
  double? get targetIps => _targetIps;
  double? get targetIpk => _targetIpk;

  /// Penegasan isolasi: simulator tidak pernah menulis ke database persisten.
  bool get isIsolatedFromPersistence => true;

  double scoreForCourse(String courseId) =>
      _hypotheticalScores[courseId] ?? 80.0;

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

  /// Selisih proyeksi IPS terhadap IPS sementara saat ini.
  double get ipsDelta => simulatedIps - _overview.provisionalIps;

  /// Selisih proyeksi IPK terhadap IPK kumulatif saat ini.
  double get ipkDelta => simulatedIpk - _overview.cumulativeIpk;

  /// Format delta desimal bertanda (+0.15, -0.10, atau 0.00).
  static String formatDelta(double delta) {
    if (delta.abs() < 0.005) return '0.00';
    final sign = delta > 0 ? '+' : '';
    return '$sign${delta.toStringAsFixed(2)}';
  }

  void updateHypotheticalScore(String courseId, double score) {
    if (!AcademicCalculator.isValidScore(score)) return;
    final normalized = AcademicCalculator.normalizeScore(score);
    if (_hypotheticalScores[courseId] == normalized) return;
    _hypotheticalScores[courseId] = normalized;
    notifyListeners();
  }

  /// Menetapkan semua skor simulasi mata kuliah aktif ke nilai tertentu.
  void setAllScores(double score) {
    if (!AcademicCalculator.isValidScore(score)) return;
    final normalized = AcademicCalculator.normalizeScore(score);
    for (final summary in _overview.courseGrades) {
      _hypotheticalScores[summary.course.id] = normalized;
    }
    notifyListeners();
  }

  void setTargetIps(double? target) {
    if (target != null && target < 0.0) return;
    _targetIps = target;
    notifyListeners();
  }

  void setTargetIpk(double? target) {
    if (target != null && target < 0.0) return;
    _targetIpk = target;
    notifyListeners();
  }

  /// Evaluasi rekomendasi skor yang dibutuhkan berdasarkan target IPS atau IPK.
  TargetGpaRecommendation? get targetRecommendation {
    double neededIps;

    if (_targetIpk != null) {
      final targetIpkVal = _targetIpk!;
      if (_overview.activeSks <= 0) {
        return TargetGpaRecommendation(
          targetIps: 0.0,
          isAchievable: false,
          averageRequiredScore: 0.0,
          averageRequiredGradePoint: 0.0,
          recommendedLetter: '-',
          statusMessage: 'Tidak ada SKS aktif di semester ini.',
        );
      }

      double pastPoints = 0.0;
      int pastSks = 0;
      for (final sem in _overview.historicalSemesters) {
        pastPoints += sem.sks * sem.ips;
        pastSks += sem.sks;
      }

      final totalSks = pastSks + _overview.activeSks;
      final targetTotalQuality = targetIpkVal * totalSks;
      final requiredActivePoints = targetTotalQuality - pastPoints;
      neededIps = requiredActivePoints / _overview.activeSks;
    } else if (_targetIps != null) {
      neededIps = _targetIps!;
    } else {
      return null;
    }

    if (neededIps > 4.00) {
      return TargetGpaRecommendation(
        targetIps: neededIps,
        isAchievable: false,
        averageRequiredScore: 100.0,
        averageRequiredGradePoint: 4.0,
        recommendedLetter: 'A',
        statusMessage:
            'Target membutuhkan IPS ${neededIps.toStringAsFixed(2)}, melebihi batas indeks prestasi maksimum 4.00.',
      );
    }

    if (neededIps <= 0.0) {
      return TargetGpaRecommendation(
        targetIps: neededIps,
        isAchievable: true,
        averageRequiredScore: 0.0,
        averageRequiredGradePoint: 0.0,
        recommendedLetter: 'E',
        statusMessage: 'Target IPK telah terpenuhi tanpa nilai tambahan.',
      );
    }

    // Cari aturan nilai minimum pada skala aktif yang memenuhi atau melampaui neededIps
    final sortedRules = List<GradeScaleRule>.from(_overview.gradingScale)
      ..sort((a, b) => a.gradePoint.compareTo(b.gradePoint));

    GradeScaleRule? matchedRule;
    for (final r in sortedRules) {
      if (r.gradePoint >= (neededIps - 0.001)) {
        matchedRule = r;
        break;
      }
    }
    matchedRule ??= sortedRules.isNotEmpty ? sortedRules.last : null;

    final reqScore = matchedRule?.minScore ?? 85.0;
    final reqLetter = matchedRule?.letter ?? 'A';
    final reqGp = matchedRule?.gradePoint ?? 4.0;

    return TargetGpaRecommendation(
      targetIps: neededIps,
      isAchievable: true,
      averageRequiredScore: reqScore,
      averageRequiredGradePoint: reqGp,
      recommendedLetter: reqLetter,
      statusMessage:
          'Dibutuhkan rata-rata nilai minimal skor ${reqScore.toStringAsFixed(0)} (Huruf $reqLetter, bobot ${reqGp.toStringAsFixed(2)}) di seluruh mata kuliah aktif.',
    );
  }

  /// Terapkan rekomendasi target skor ke seluruh mata kuliah aktif pada simulasi.
  void applyTargetRecommendation() {
    final rec = targetRecommendation;
    if (rec != null && rec.isAchievable) {
      setAllScores(rec.averageRequiredScore);
    }
  }

  void resetSimulation() {
    _resetHypotheticalScoresInternal();
    _targetIps = null;
    _targetIpk = null;
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
