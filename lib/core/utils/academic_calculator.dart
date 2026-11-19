/// Komponen penilaian mata kuliah yang dapat dikonfigurasi oleh pengguna.
class AssessmentComponentInput {
  const AssessmentComponentInput({
    required this.name,
    required this.weightPercent,
    this.score,
    this.isMandatory = true,
  });

  final String name;
  final double weightPercent;
  final double? score;
  final bool isMandatory;

  bool get hasScore => score != null;
}

/// Hasil kalkulasi nilai mata kuliah yang memisahkan nilai sementara
/// (provisional) dan status kelengkapan nilai akhir (final).
class CourseGradeCalculation {
  const CourseGradeCalculation({
    required this.provisionalAverage,
    required this.gradedWeightPercent,
    required this.totalConfiguredWeightPercent,
    required this.isFinalReady,
  });

  /// Rata-rata tertimbang dari komponen yang sudah memiliki nilai.
  /// Bernilai `null` jika belum ada komponen yang dinilai.
  final double? provisionalAverage;

  /// Persentase bobot penilaian yang sudah terisi nilainya.
  final double gradedWeightPercent;

  /// Total bobot seluruh komponen yang dikonfigurasi.
  final double totalConfiguredWeightPercent;

  /// Bernilai `true` hanya apabila total bobot == 100% dan seluruh
  /// komponen wajib telah memiliki nilai.
  final bool isFinalReady;

  /// Nilai akhir hanya tersedia saat seluruh syarat kelulusan bobot terpenuhi.
  double? get finalScore => isFinalReady ? provisionalAverage : null;
}

/// Aturan satu rentang nilai pada skala konversi kampus yang dapat diatur user.
class GradeScaleRule {
  const GradeScaleRule({
    required this.minScore,
    required this.maxScore,
    required this.letter,
    required this.gradePoint,
  });

  final double minScore;
  final double maxScore;
  final String letter;
  final double gradePoint;
}

/// Pasangan SKS dan bobot mutu (grade point) untuk perhitungan IPS/IPK.
class WeightedGradePoint {
  const WeightedGradePoint({required this.sks, required this.gradePoint});

  final int sks;
  final double gradePoint;
}

/// Utilitas murni (pure functions) untuk kalkulasi akademik RuangRencana.
///
/// Seluruh perhitungan akademik dipisahkan dari lapisan UI agar mudah diuji
/// secara unit dan menjadi satu sumber kebenaran aturan bisnis.
abstract final class AcademicCalculator {
  static const double _weightTolerance = 0.001;

  /// Menghitung nilai sementara (provisional) dan kesiapan nilai akhir.
  ///
  /// Rumus nilai sementara:
  /// `SUM(score * weight) / SUM(entered component weights)`
  static CourseGradeCalculation calculateCourseGrade(
    List<AssessmentComponentInput> components,
  ) {
    if (components.isEmpty) {
      return const CourseGradeCalculation(
        provisionalAverage: null,
        gradedWeightPercent: 0,
        totalConfiguredWeightPercent: 0,
        isFinalReady: false,
      );
    }

    double totalConfiguredWeight = 0;
    double enteredWeight = 0;
    double weightedScoreSum = 0;
    var allMandatoryScored = true;

    for (final component in components) {
      totalConfiguredWeight += component.weightPercent;
      if (component.score != null) {
        enteredWeight += component.weightPercent;
        weightedScoreSum += component.score! * component.weightPercent;
      } else if (component.isMandatory) {
        allMandatoryScored = false;
      }
    }

    final provisionalAverage = enteredWeight > 0
        ? weightedScoreSum / enteredWeight
        : null;

    final isTotalWeightComplete =
        (totalConfiguredWeight - 100.0).abs() <= _weightTolerance;
    final isFinalReady =
        isTotalWeightComplete &&
        allMandatoryScored &&
        (enteredWeight - 100.0).abs() <= _weightTolerance;

    return CourseGradeCalculation(
      provisionalAverage: provisionalAverage,
      gradedWeightPercent: enteredWeight,
      totalConfiguredWeightPercent: totalConfiguredWeight,
      isFinalReady: isFinalReady,
    );
  }

  /// Menghitung IPS atau IPK berbasis rata-rata tertimbang SKS.
  ///
  /// Mengembalikan `0.0` jika total SKS <= 0.
  static double calculateWeightedGpa(List<WeightedGradePoint> items) {
    var totalSks = 0;
    double totalQualityPoints = 0;

    for (final item in items) {
      if (item.sks <= 0) continue;
      totalSks += item.sks;
      totalQualityPoints += item.sks * item.gradePoint;
    }

    if (totalSks == 0) return 0.0;
    return totalQualityPoints / totalSks;
  }

  /// Mencari aturan huruf & bobot mutu yang cocok dari skala yang dikonfigurasi.
  static GradeScaleRule? resolveGradeRule(
    double score,
    List<GradeScaleRule> rules,
  ) {
    for (final rule in rules) {
      if (score >= rule.minScore && score <= rule.maxScore) {
        return rule;
      }
    }
    return null;
  }

  /// Memvalidasi apakah daftar rentang skala nilai memiliki tumpang tindih
  /// (overlap) atau rentang tidak valid (`minScore > maxScore`).
  static bool hasOverlappingGradeRanges(List<GradeScaleRule> rules) {
    for (final rule in rules) {
      if (rule.minScore > rule.maxScore) {
        return true;
      }
    }

    final sorted = List<GradeScaleRule>.from(rules)
      ..sort((a, b) => a.minScore.compareTo(b.minScore));

    for (var i = 1; i < sorted.length; i++) {
      final previous = sorted[i - 1];
      final current = sorted[i];
      if (current.minScore <= previous.maxScore) {
        return true;
      }
    }
    return false;
  }
}
