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

      expect(AcademicCalculator.hasOverlappingGradeRanges(rules), isFalse);
      expect(AcademicCalculator.resolveGradeRule(85, rules)?.letter, 'A');
      expect(AcademicCalculator.resolveGradeRule(80, rules)?.letter, 'B+');
    });

    test('mendeteksi overlap pada rentang nilai yang bertabrakan', () {
      const invalidRules = [
        GradeScaleRule(minScore: 80, maxScore: 100, letter: 'A', gradePoint: 4),
        GradeScaleRule(minScore: 70, maxScore: 85, letter: 'B', gradePoint: 3),
      ];

      expect(
        AcademicCalculator.hasOverlappingGradeRanges(invalidRules),
        isTrue,
      );
    });
  });
}
