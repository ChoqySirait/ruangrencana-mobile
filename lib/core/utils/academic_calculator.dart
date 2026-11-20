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

/// Hasil evaluasi validitas konfigurasi skala konversi nilai.
class GradingScaleValidationResult {
  const GradingScaleValidationResult({
    required this.isValid,
    required this.errors,
    this.hasCoverageGaps = false,
    this.hasOverlaps = false,
  });

  final bool isValid;
  final List<String> errors;
  final bool hasCoverageGaps;
  final bool hasOverlaps;
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
        if (isValidScore(component.score)) {
          final normalized = normalizeScore(component.score!);
          enteredWeight += component.weightPercent;
          weightedScoreSum += normalized * component.weightPercent;
        } else {
          // Komponen dengan skor di luar rentang valid tidak dianggap memiliki nilai valid
          if (component.isMandatory) {
            allMandatoryScored = false;
          }
        }
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

  /// Memeriksa apakah nilai skor berada dalam rentang valid akademik (0.0 s/d 100.0).
  ///
  /// Menolak nilai null, NaN, tak terhingga (infinite), negatif (< 0.0), dan di atas 100.0.
  static bool isValidScore(double? score) {
    if (score == null) return false;
    if (score.isNaN || score.isInfinite) return false;
    return score >= 0.0 && score <= 100.0;
  }

  /// Kebijakan Pembulatan Desimal Skor Akademik:
  /// Skor dinormalisasi menggunakan pembulatan dua angka di belakang koma dengan
  /// metode standard half-up: `(score * 100).round() / 100.0`.
  ///
  /// Nilai batas tepat 0.0 dan 100.0 dipertahankan secara utuh.
  /// Contoh:
  /// - `84.995` dibulatkan menjadi `85.00` (memenuhi batas bawah rentang nilai A).
  /// - `84.994` dibulatkan menjadi `84.99` (tetap berada pada rentang nilai A-).
  /// - `100.0` tetap `100.0`.
  /// - `0.0` tetap `0.0`.
  ///
  /// Melempar [ArgumentError] jika nilai [score] tidak valid (di luar rentang 0.0 - 100.0).
  static double normalizeScore(double score) {
    if (!isValidScore(score)) {
      throw ArgumentError.value(
        score,
        'score',
        'Skor nilai harus berada dalam rentang valid 0.0 sampai 100.0.',
      );
    }
    return (score * 100).round() / 100.0;
  }

  /// Mencari aturan huruf & bobot mutu yang cocok dari skala yang dikonfigurasi.
  ///
  /// Aturan Validasi Skor:
  /// 1. Menolak nilai di bawah 0.0 dan di atas 100.0 secara mutlak dengan mengembalikan `null`
  ///    (TIDAK melakukan silent clamping yang dapat mengubah input tidak valid menjadi valid).
  /// 2. Mendukung secara presisi nilai batas tepat 0.0 dan 100.0.
  /// 3. Menerapkan kebijakan pembulatan 2 desimal standar kampus (round half-up)
  ///    sehingga pecahan mikro seperti `84.995` secara deterministik dipetakan ke ambang terdekat.
  /// 4. Skala yang tidak lengkap atau tidak mencakup skor akan mengembalikan `null`,
  ///    mencegah pembuatan nilai huruf palsu (*false letter grade*).
  static GradeScaleRule? resolveGradeRule(
    double score,
    List<GradeScaleRule> rules,
  ) {
    if (rules.isEmpty) return null;
    if (!isValidScore(score)) return null;

    final normalizedScore = normalizeScore(score);

    for (final rule in rules) {
      if (normalizedScore >= (rule.minScore - 0.0001) &&
          normalizedScore <= (rule.maxScore + 0.0001)) {
        return rule;
      }
    }

    // Toleransi batas bertetangga (misal antara 84.99 dan 85.0)
    final sorted = List<GradeScaleRule>.from(rules)
      ..sort((a, b) => b.minScore.compareTo(a.minScore));

    for (final rule in sorted) {
      if (normalizedScore >= rule.minScore - 0.005 &&
          normalizedScore <= rule.maxScore + 0.005) {
        return rule;
      }
    }

    return null;
  }

  /// Evaluasi komprehensif validitas konfigurasi skala konversi nilai:
  /// - Batas minimum tidak boleh melebihi batas maksimum.
  /// - Tidak boleh ada rentang yang saling bertabrakan (overlapping).
  /// - Harus mencakup batas bawah 0.0 dan batas atas 100.0.
  /// - Tidak boleh ada celah nilai signifikan antar-rentang.
  static GradingScaleValidationResult validateGradingScale(
    List<GradeScaleRule> rules,
  ) {
    final errors = <String>[];
    if (rules.isEmpty) {
      return const GradingScaleValidationResult(
        isValid: false,
        errors: ['Skala penilaian tidak boleh kosong.'],
        hasCoverageGaps: true,
      );
    }

    var hasInverted = false;
    for (final rule in rules) {
      if (rule.minScore > rule.maxScore) {
        hasInverted = true;
        errors.add(
          'Rentang nilai "${rule.letter}" tidak valid: batas minimum (${rule.minScore}) melebihi batas maksimum (${rule.maxScore}).',
        );
      }
      if (rule.minScore < 0.0 || rule.maxScore > 100.0) {
        errors.add(
          'Rentang skor "${rule.letter}" harus berada dalam batas 0.0 sampai 100.0.',
        );
      }
      if (rule.gradePoint < 0.0) {
        errors.add('Bobot mutu untuk "${rule.letter}" tidak boleh negatif.');
      }
    }

    if (hasInverted) {
      return GradingScaleValidationResult(
        isValid: false,
        errors: errors,
        hasOverlaps: true,
      );
    }

    final sorted = List<GradeScaleRule>.from(rules)
      ..sort((a, b) => a.minScore.compareTo(b.minScore));

    var hasOverlaps = false;
    for (var i = 1; i < sorted.length; i++) {
      final prev = sorted[i - 1];
      final curr = sorted[i];
      if (curr.minScore < prev.maxScore - 0.001) {
        hasOverlaps = true;
        errors.add(
          'Rentang "${prev.letter}" (${prev.minScore}-${prev.maxScore}) bertabrakan dengan rentang "${curr.letter}" (${curr.minScore}-${curr.maxScore}).',
        );
      }
    }

    var hasCoverageGaps = false;
    final topRule = sorted.last;
    if (topRule.maxScore < 100.0 - 0.001) {
      hasCoverageGaps = true;
      errors.add('Skala penilaian tidak mencakup nilai sempurna 100.0.');
    }

    final bottomRule = sorted.first;
    if (bottomRule.minScore > 0.0 + 0.001) {
      hasCoverageGaps = true;
      errors.add('Skala penilaian tidak mencakup batas bawah 0.0.');
    }

    for (var i = 1; i < sorted.length; i++) {
      final prev = sorted[i - 1];
      final curr = sorted[i];
      if (curr.minScore > prev.maxScore + 0.011) {
        hasCoverageGaps = true;
        errors.add(
          'Terdapat celah nilai yang tidak terdefinisi antara batas atas "${prev.letter}" (${prev.maxScore}) dan batas bawah "${curr.letter}" (${curr.minScore}).',
        );
      }
    }

    return GradingScaleValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      hasCoverageGaps: hasCoverageGaps,
      hasOverlaps: hasOverlaps,
    );
  }

  /// Memvalidasi apakah daftar rentang skala nilai memiliki tumpang tindih
  /// (overlap) atau rentang tidak valid.
  static bool hasOverlappingGradeRanges(List<GradeScaleRule> rules) {
    return !validateGradingScale(rules).isValid;
  }
}
