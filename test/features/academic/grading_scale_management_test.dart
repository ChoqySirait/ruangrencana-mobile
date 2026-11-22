import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruangrencana/core/database/app_database.dart';
import 'package:ruangrencana/core/database/database_seeder.dart';
import 'package:ruangrencana/core/errors/app_failure.dart';
import 'package:ruangrencana/core/utils/academic_calculator.dart';
import 'package:ruangrencana/features/academic/grades/data/repositories/academic_repository.dart';
import 'package:ruangrencana/features/academic/scales/presentation/view_models/grading_scale_form_view_model.dart';
import 'package:ruangrencana/features/academic/scales/presentation/view_models/grading_scales_view_model.dart';
import 'package:ruangrencana/features/courses/data/repositories/course_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Manajemen & Validasi Skala Penilaian Kampus (SQLite & ViewModel)', () {
    late Directory tempDir;
    late String dbFilePath;
    late AppDatabase appDb;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'ruangrencana_scale_test_',
      );
      dbFilePath = '${tempDir.path}${Platform.pathSeparator}test_scale.db';
      appDb = AppDatabase(databaseFactory: databaseFactoryFfi);
    });

    tearDown(() async {
      await appDb.close();
      if (await tempDir.exists()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    });

    test(
      'Validasi aturan skala nilai (AcademicCalculator.validateGradingScale)',
      () {
        // 1. Skala kosong
        final emptyResult = AcademicCalculator.validateGradingScale([]);
        expect(emptyResult.isValid, isFalse);
        expect(emptyResult.errors.first, contains('tidak boleh kosong'));

        // 2. Batas minimum melebihi maksimum
        final invertedResult = AcademicCalculator.validateGradingScale([
          const GradeScaleRule(
            minScore: 80,
            maxScore: 60,
            letter: 'X',
            gradePoint: 3.0,
          ),
        ]);
        expect(invertedResult.isValid, isFalse);
        expect(
          invertedResult.errors.first,
          contains('melebihi batas maksimum'),
        );

        // 3. Tumpang tindih (overlap)
        final overlapResult = AcademicCalculator.validateGradingScale([
          const GradeScaleRule(
            minScore: 0,
            maxScore: 60,
            letter: 'C',
            gradePoint: 2.0,
          ),
          const GradeScaleRule(
            minScore: 50,
            maxScore: 100,
            letter: 'A',
            gradePoint: 4.0,
          ),
        ]);
        expect(overlapResult.isValid, isFalse);
        expect(overlapResult.hasOverlaps, isTrue);

        // 4. Celah nilai (gap)
        final gapResult = AcademicCalculator.validateGradingScale([
          const GradeScaleRule(
            minScore: 0,
            maxScore: 50,
            letter: 'C',
            gradePoint: 2.0,
          ),
          const GradeScaleRule(
            minScore: 60,
            maxScore: 100,
            letter: 'A',
            gradePoint: 4.0,
          ),
        ]);
        expect(gapResult.isValid, isFalse);
        expect(gapResult.hasCoverageGaps, isTrue);

        // 5. Tidak mencakup 0.0 atau 100.0
        final partialResult = AcademicCalculator.validateGradingScale([
          const GradeScaleRule(
            minScore: 10,
            maxScore: 90,
            letter: 'B',
            gradePoint: 3.0,
          ),
        ]);
        expect(partialResult.isValid, isFalse);
        expect(partialResult.hasCoverageGaps, isTrue);

        // 6. Skala valid penuh
        final validRules = [
          const GradeScaleRule(
            minScore: 85,
            maxScore: 100,
            letter: 'A',
            gradePoint: 4.0,
          ),
          const GradeScaleRule(
            minScore: 70,
            maxScore: 84.99,
            letter: 'B',
            gradePoint: 3.0,
          ),
          const GradeScaleRule(
            minScore: 55,
            maxScore: 69.99,
            letter: 'C',
            gradePoint: 2.0,
          ),
          const GradeScaleRule(
            minScore: 40,
            maxScore: 54.99,
            letter: 'D',
            gradePoint: 1.0,
          ),
          const GradeScaleRule(
            minScore: 0,
            maxScore: 39.99,
            letter: 'E',
            gradePoint: 0.0,
          ),
        ];
        final validResult = AcademicCalculator.validateGradingScale(validRules);
        expect(validResult.isValid, isTrue);
        expect(validResult.errors, isEmpty);
      },
    );

    test('Operasi CRUD & Keamanan Relasional Skala Nilai pada SqliteAcademicRepository', () async {
      final db = await appDb.open(customPath: dbFilePath);
      await DatabaseSeeder.seedIfNeeded(db);

      final courseRepo = SqliteCourseRepository(appDatabase: appDb);
      final academicRepo = SqliteAcademicRepository(
        appDatabase: appDb,
        courseRepository: courseRepo,
      );
      await courseRepo.load();
      await academicRepo.load();

      final initialScales = academicRepo.getAllGradingScales();
      expect(initialScales, isNotEmpty);
      final defaultScale = academicRepo.getDefaultGradingScale();
      expect(defaultScale, isNotNull);
      expect(defaultScale!.isDefault, isTrue);

      // 1. Buat skala baru khusus
      final customRules = [
        const GradeScaleRule(
          minScore: 80,
          maxScore: 100,
          letter: 'A',
          gradePoint: 4.0,
        ),
        const GradeScaleRule(
          minScore: 65,
          maxScore: 79.99,
          letter: 'B',
          gradePoint: 3.0,
        ),
        const GradeScaleRule(
          minScore: 50,
          maxScore: 64.99,
          letter: 'C',
          gradePoint: 2.0,
        ),
        const GradeScaleRule(
          minScore: 35,
          maxScore: 49.99,
          letter: 'D',
          gradePoint: 1.0,
        ),
        const GradeScaleRule(
          minScore: 0,
          maxScore: 34.99,
          letter: 'E',
          gradePoint: 0.0,
        ),
      ];

      final newScaleId = await academicRepo.createGradingScale(
        name: 'Skala Kampus Khusus',
        isDefault: false,
        initialRanges: customRules,
      );
      expect(newScaleId, isPositive);

      final createdScale = academicRepo.getGradingScaleById(newScaleId);
      expect(createdScale, isNotNull);
      expect(createdScale!.name, 'Skala Kampus Khusus');
      expect(createdScale.ranges.length, 5);

      // 2. Set skala baru sebagai default
      await academicRepo.setDefaultGradingScale(newScaleId);
      final updatedDefault = academicRepo.getDefaultGradingScale();
      expect(updatedDefault?.id, newScaleId);

      // 3. Proteksi: Tidak boleh menghapus skala default
      expect(
        () => academicRepo.deleteGradingScale(newScaleId),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.code,
            'code',
            'CANNOT_DELETE_DEFAULT',
          ),
        ),
      );

      // Kembalikan default ke skala awal
      await academicRepo.setDefaultGradingScale(defaultScale.id);

      // 4. Hubungkan skala baru ke semester akademik
      final semesters = academicRepo.getAllSemesters();
      expect(semesters, isNotEmpty);
      final targetSemester = semesters.first;

      await academicRepo.assignGradingScaleToSemester(
        termId: targetSemester.id,
        scaleId: newScaleId,
      );

      final termsUsing = await academicRepo.getTermsUsingScale(newScaleId);
      expect(termsUsing.any((t) => t.id == targetSemester.id), isTrue);

      // 5. Proteksi: Tidak boleh menghapus skala yang sedang digunakan oleh semester (SCALE_IN_USE)
      expect(
        () => academicRepo.deleteGradingScale(newScaleId),
        throwsA(
          isA<AppFailure>().having((e) => e.code, 'code', 'SCALE_IN_USE'),
        ),
      );

      // 6. Duplikasi skala (cloning) untuk perlindungan riwayat
      final duplicatedId = await academicRepo.duplicateGradingScale(
        sourceScaleId: newScaleId,
        newName: 'Skala Kampus Khusus Revisi 2026',
      );
      final duplicatedScale = academicRepo.getGradingScaleById(duplicatedId);
      expect(duplicatedScale, isNotNull);
      expect(duplicatedScale!.name, 'Skala Kampus Khusus Revisi 2026');
      expect(duplicatedScale.ranges.length, 5);
      expect(duplicatedScale.isDefault, isFalse);

      // 7. Hapus skala duplikasi yang tidak dipakai
      await academicRepo.deleteGradingScale(duplicatedId);
      expect(academicRepo.getGradingScaleById(duplicatedId), isNull);

      // 8. Verifikasi persistensi setelah restart database
      await appDb.close();
      final reopenedDb = await appDb.open(customPath: dbFilePath);
      expect(reopenedDb.isOpen, isTrue);

      final restartedRepo = SqliteAcademicRepository(
        appDatabase: appDb,
        courseRepository: courseRepo,
      );
      await restartedRepo.load();

      final reloadedScale = restartedRepo.getGradingScaleById(newScaleId);
      expect(reloadedScale, isNotNull);
      expect(reloadedScale!.name, 'Skala Kampus Khusus');
      expect(reloadedScale.ranges.length, 5);
    });

    test(
      'Interaksi GradingScalesViewModel & GradingScaleFormViewModel',
      () async {
        final db = await appDb.open(customPath: dbFilePath);
        await DatabaseSeeder.seedIfNeeded(db);

        final courseRepo = SqliteCourseRepository(appDatabase: appDb);
        final academicRepo = SqliteAcademicRepository(
          appDatabase: appDb,
          courseRepository: courseRepo,
        );
        await courseRepo.load();
        await academicRepo.load();

        final listVm = GradingScalesViewModel(repository: academicRepo);
        expect(listVm.scales, isNotEmpty);

        // Form ViewModel untuk skala baru
        final formVm = GradingScaleFormViewModel(repository: academicRepo);
        expect(formVm.isValid, isTrue);

        // Uji preset Standar 5
        formVm.applyPreset('simple_5');
        expect(formVm.ranges.length, 5);
        expect(formVm.isValid, isTrue);

        // Uji preset Skala 7
        formVm.applyPreset('scale_7');
        expect(formVm.ranges.length, 7);
        expect(formVm.isValid, isTrue);

        // Tambah baris baru lalu verifikasi validasi mendeteksi celah/tumpang tindih
        formVm.addRange();
        // Mengubah rentang menjadi tidak valid
        formVm.updateRange(
          0,
          letter: 'A+',
          gradePoint: 4.0,
          minScore: 90,
          maxScore: 80, // Inverted!
        );
        expect(formVm.isValid, isFalse);

        // Kembalikan ke preset valid dan simpan
        formVm.applyPreset('standard_plus_minus');
        formVm.setName('Skala VM Test');
        expect(formVm.isValid, isTrue);

        final savedId = await formVm.save();
        expect(savedId, isNotNull);

        listVm.loadScales();
        expect(listVm.scales.any((s) => s.id == savedId), isTrue);
      },
    );
  });
}
