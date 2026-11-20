import 'package:flutter_test/flutter_test.dart';
import 'package:ruangrencana/core/utils/academic_calculator.dart';

void main() {
  group('AcademicCalculator.calculateCourseGrade', () {
    test(
      'menghitung rata-rata sementara dari komponen yang sudah dinilai saja',
      () {
        final result = AcademicCalculator.calculateCourseGrade(const [
          AssessmentComponentInput(name: 'Tugas', weightPercent: 30, score: 90),
          AssessmentComponentInput(name: 'UTS', weightPercent: 30, score: 80),
          AssessmentComponentInput(name: 'UAS', weightPercent: 40),
        ]);

        // (90 * 30 + 80 * 30) / (30 + 30) = 5100 / 60 = 85.0
        expect(result.provisionalAverage, closeTo(85.0, 0.001));
        expect(result.gradedWeightPercent, closeTo(60.0, 0.001));
        expect(result.totalConfiguredWeightPercent, closeTo(100.0, 0.001));
        expect(result.isFinalReady, isFalse);
        expect(result.finalScore, isNull);
      },
    );

    test('menandai nilai final hanya jika total bobot 100% dan semua komponen dinilai', () {
      final result = AcademicCalculator.calculateCourseGrade(const [
        AssessmentComponentInput(name: 'Tugas', weightPercent: 30, score: 80),
        AssessmentComponentInput(name: 'UTS', weightPercent: 30, score: 85),
        AssessmentComponentInput(name: 'UAS', weightPercent: 40, score: 90),
      ]);

      // (2400 + 2550 + 3600) / 100 = 85.5
      expect(result.provisionalAverage, closeTo(85.5, 0.001));
      expect(result.isFinalReady, isTrue);
      expect(result.finalScore, closeTo(85.5, 0.001));
    });

    test('belum final jika total bobot kurang dari 100%', () {
      final result = AcademicCalculator.calculateCourseGrade(const [
        AssessmentComponentInput(name: 'Tugas', weightPercent: 40, score: 90),
        AssessmentComponentInput(name: 'UTS', weightPercent: 40, score: 80),
      ]);

      expect(result.provisionalAverage, closeTo(85.0, 0.001));
      expect(result.totalConfiguredWeightPercent, closeTo(80.0, 0.001));
      expect(result.isFinalReady, isFalse);
      expect(result.finalScore, isNull);
    });
  });

  group('AcademicCalculator.calculateWeightedGpa', () {
    test('menghitung IPS/IPK tertimbang berdasarkan SKS', () {
      final gpa = AcademicCalculator.calculateWeightedGpa(const [
        WeightedGradePoint(sks: 3, gradePoint: 4.0),
        WeightedGradePoint(sks: 3, gradePoint: 3.0),
        WeightedGradePoint(sks: 2, gradePoint: 3.5),
      ]);

      // (12 + 9 + 7) / 8 = 28 / 8 = 3.5
      expect(gpa, closeTo(3.5, 0.001));
    });

    test('mengembalikan 0.0 untuk daftar kosong', () {
      expect(AcademicCalculator.calculateWeightedGpa(const []), 0.0);
    });
  });

  group('AcademicCalculator grading scale validation', () {
    test('mendeteksi tidak ada overlap pada rentang yang valid', () {
      const rules = [
        GradeScaleRule(minScore: 85, maxScore: 100, letter: 'A', gradePoint: 4),
        GradeScaleRule(
          minScore: 75,
          maxScore: 84.99,
          letter: 'B+',
          gradePoint: 3.5,
        ),
        GradeScaleRule(
          minScore: 0,
          maxScore: 74.99,
          letter: 'B',
          gradePoint: 3,
        ),
      ];

      final validation = AcademicCalculator.validateGradingScale(rules);
      expect(validation.isValid, isTrue);
      expect(validation.errors, isEmpty);
      expect(AcademicCalculator.hasOverlappingGradeRanges(rules), isFalse);
      expect(AcademicCalculator.resolveGradeRule(85, rules)?.letter, 'A');
      expect(AcademicCalculator.resolveGradeRule(80, rules)?.letter, 'B+');
    });

    test('mendeteksi overlap pada rentang nilai yang bertabrakan', () {
      const invalidRules = [
        GradeScaleRule(minScore: 80, maxScore: 100, letter: 'A', gradePoint: 4),
        GradeScaleRule(minScore: 70, maxScore: 85, letter: 'B', gradePoint: 3),
      ];

      final validation = AcademicCalculator.validateGradingScale(invalidRules);
      expect(validation.isValid, isFalse);
      expect(validation.hasOverlaps, isTrue);
      expect(
        AcademicCalculator.hasOverlappingGradeRanges(invalidRules),
        isTrue,
      );
    });

    test('mendeteksi rentang terbalik, celah nilai, dan batas ambang tidak lengkap', () {
      // 1. Skala kosong
      expect(AcademicCalculator.validateGradingScale([]).isValid, isFalse);

      // 2. Rentang terbalik (min > max)
      const invertedRules = [
        GradeScaleRule(
          minScore: 90,
          maxScore: 80,
          letter: 'A',
          gradePoint: 4.0,
        ),
      ];
      final invertedRes = AcademicCalculator.validateGradingScale(
        invertedRules,
      );
      expect(invertedRes.isValid, isFalse);
      expect(
        invertedRes.errors.any((e) => e.contains('melebihi batas maksimum')),
        isTrue,
      );

      // 3. Skala tidak mencakup 100.0 atau 0.0
      const incompleteScale = [
        GradeScaleRule(
          minScore: 60,
          maxScore: 90,
          letter: 'C',
          gradePoint: 2.0,
        ),
      ];
      final incompleteRes = AcademicCalculator.validateGradingScale(
        incompleteScale,
      );
      expect(incompleteRes.isValid, isFalse);
      expect(incompleteRes.hasCoverageGaps, isTrue);

      // 4. Celah nilai antar-rentang (gap)
      const gapScale = [
        GradeScaleRule(
          minScore: 80,
          maxScore: 100,
          letter: 'A',
          gradePoint: 4.0,
        ),
        GradeScaleRule(minScore: 0, maxScore: 60, letter: 'D', gradePoint: 1.0),
      ];
      final gapRes = AcademicCalculator.validateGradingScale(gapScale);
      expect(gapRes.isValid, isFalse);
      expect(gapRes.hasCoverageGaps, isTrue);
    });

    test('penanganan batas ekstrem (100.0, 0.0, pembulatan, dan skor di luar skala)', () {
      const standardScale = [
        GradeScaleRule(
          minScore: 85.0,
          maxScore: 100.0,
          letter: 'A',
          gradePoint: 4.0,
        ),
        GradeScaleRule(
          minScore: 80.0,
          maxScore: 84.99,
          letter: 'A-',
          gradePoint: 3.7,
        ),
        GradeScaleRule(
          minScore: 70.0,
          maxScore: 79.99,
          letter: 'B',
          gradePoint: 3.0,
        ),
        GradeScaleRule(
          minScore: 0.0,
          maxScore: 69.99,
          letter: 'E',
          gradePoint: 0.0,
        ),
      ];

      // Tepat 100.0 didukung penuh
      expect(
        AcademicCalculator.resolveGradeRule(100.0, standardScale)?.letter,
        'A',
      );
      expect(
        AcademicCalculator.resolveGradeRule(100.0, standardScale)?.gradePoint,
        4.0,
      );

      // Tepat 0.0 didukung penuh
      expect(
        AcademicCalculator.resolveGradeRule(0.0, standardScale)?.letter,
        'E',
      );

      // Batas ambang 85.0 dan 84.99
      expect(
        AcademicCalculator.resolveGradeRule(85.0, standardScale)?.letter,
        'A',
      );
      expect(
        AcademicCalculator.resolveGradeRule(84.99, standardScale)?.letter,
        'A-',
      );

      // Skor pada celah desimal mikro (84.995 dibulatkan ke 85.00)
      expect(
        AcademicCalculator.resolveGradeRule(84.995, standardScale)?.letter,
        'A',
      );

      // Skor di luar batas (> 100 atau < 0) di-clamp
      expect(
        AcademicCalculator.resolveGradeRule(105.0, standardScale)?.letter,
        'A',
      );
      expect(
        AcademicCalculator.resolveGradeRule(-5.0, standardScale)?.letter,
        'E',
      );

      // Skala tidak lengkap dan skor jatuh di luar rentang
      const partialScale = [
        GradeScaleRule(
          minScore: 70.0,
          maxScore: 80.0,
          letter: 'B',
          gradePoint: 3.0,
        ),
      ];
      expect(AcademicCalculator.resolveGradeRule(50.0, partialScale), isNull);
    });
  });
}
