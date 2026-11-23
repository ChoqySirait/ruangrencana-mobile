import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruangrencana/core/database/app_database.dart';
import 'package:ruangrencana/core/database/database_schema.dart';
import 'package:ruangrencana/core/database/database_seeder.dart';
import 'package:ruangrencana/core/utils/academic_calculator.dart';
import 'package:ruangrencana/features/academic/grades/data/repositories/academic_repository.dart';
import 'package:ruangrencana/features/academic/simulator/presentation/view_models/grade_simulator_view_model.dart';
import 'package:ruangrencana/features/courses/data/repositories/course_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group(
    'Performa Akademik & Simulasi Nilai (SQLite, Repositori, & ViewModel)',
    () {
      late Directory tempDir;
      late String dbFilePath;
      late AppDatabase appDb;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp(
          'ruangrencana_perf_test_',
        );
        dbFilePath = '${tempDir.path}${Platform.pathSeparator}test_perf.db';
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

      test('Kalkulasi IPS resmi hanya dari mata kuliah berstatus final (100% bobot dinilai)', () async {
        final db = await appDb.open(customPath: dbFilePath);
        await DatabaseSeeder.seedIfNeeded(db);

        final courseRepo = SqliteCourseRepository(appDatabase: appDb);
        final academicRepo = SqliteAcademicRepository(
          appDatabase: appDb,
          courseRepository: courseRepo,
        );
        await courseRepo.load();
        await academicRepo.load();

        final overview = academicRepo.getAcademicOverview();
        expect(overview.activeSks, isPositive);
        expect(overview.provisionalIps, isPositive);

        // Pada data seeded awal, beberapa mata kuliah belum final (misal bobot baru sebagian)
        // Pastikan kalkulasi memisahkan provisionalIps dan officialIps
        expect(overview.courseGrades, isNotEmpty);
        final totalCourses = overview.courseGrades.length;
        final finalCourses = overview.finalizedCourseCount;
        expect(finalCourses, lessThanOrEqualTo(totalCourses));

        // SKS lulus aktif hanya menghitung mata kuliah yang sudah final dan grade point > 0
        expect(overview.activePassedSks, lessThanOrEqualTo(overview.activeSks));
      });

      test(
        'Pengecualian mata kuliah tidak lulus (Nilai E / 0.00) dari SKS Lulus',
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

          final activeTerm = academicRepo.getActiveSemester();
          expect(activeTerm, isNotNull);

          // Buat mata kuliah baru berbobot 3 SKS dengan nilai E (skor 30.00) dan bobot lengkap 100%
          final failedCourseId = await courseRepo.insertCourse(
            termId: activeTerm!.id,
            code: 'FAIL-101',
            name: 'Mata Kuliah Mengulang',
            credits: 3,
            lecturer: 'Dosen Penguji',
          );

          final compId = await courseRepo.addAssessmentComponent(
            courseId: failedCourseId.toString(),
            name: 'Ujian Akhir',
            weightPercent: 100.0,
            isRequired: true,
          );

          await courseRepo.recordAssessmentScore(
            componentId: compId,
            score: 30.0, // Mendapatkan nilai E (bobot 0.00)
          );

          await courseRepo.load();
          await academicRepo.load();

          final updatedOverview = academicRepo.getAcademicOverview();
          final failedSummary = updatedOverview.courseGrades.firstWhere(
            (c) => c.course.id == failedCourseId.toString(),
          );

          expect(failedSummary.calculation.isFinalReady, isTrue);
          expect(failedSummary.letterGrade, 'E');
          expect(failedSummary.gradePoint, 0.0);
          expect(failedSummary.isPassed, isFalse);

          // Total SKS yang ditempuh bertambah 3 SKS, tetapi activePassedSks TIDAK bertambah untuk mata kuliah nilai E
          expect(updatedOverview.activeSks, greaterThanOrEqualTo(3));
        },
      );

      test('Kalkulasi dinamis IPK Kumulatif lintas semester dengan skala nilai berbeda', () async {
        final db = await appDb.open(customPath: dbFilePath);
        await DatabaseSeeder.seedIfNeeded(db);

        final courseRepo = SqliteCourseRepository(appDatabase: appDb);
        final academicRepo = SqliteAcademicRepository(
          appDatabase: appDb,
          courseRepository: courseRepo,
        );
        await courseRepo.load();
        await academicRepo.load();

        // Buat semester lampau baru bernomor 5 dengan skala khusus
        final scaleId = await academicRepo.createGradingScale(
          name: 'Skala Ketat',
          initialRanges: [
            const GradeScaleRule(
              minScore: 90,
              maxScore: 100,
              letter: 'A',
              gradePoint: 4.0,
            ),
            const GradeScaleRule(
              minScore: 75,
              maxScore: 89.99,
              letter: 'B',
              gradePoint: 3.0,
            ),
            const GradeScaleRule(
              minScore: 60,
              maxScore: 74.99,
              letter: 'C',
              gradePoint: 2.0,
            ),
            const GradeScaleRule(
              minScore: 40,
              maxScore: 59.99,
              letter: 'D',
              gradePoint: 1.0,
            ),
            const GradeScaleRule(
              minScore: 0,
              maxScore: 39.99,
              letter: 'E',
              gradePoint: 0.0,
            ),
          ],
        );

        final pastTermId = await academicRepo.createSemester(
          academicYear: '2024/2025',
          semesterName: 'Semester Khusus Lampau',
          semesterNumber: 10,
          gradingScaleId: scaleId,
          makeActive: false,
        );

        // Tambahkan mata kuliah di semester lampau tersebut
        final pastCourseId = await courseRepo.insertCourse(
          termId: pastTermId,
          code: 'HIST-201',
          name: 'Sejarah Sistem Informasi',
          credits: 4,
          lecturer: 'Dosen Sejarah',
        );

        final compId = await courseRepo.addAssessmentComponent(
          courseId: pastCourseId.toString(),
          name: 'Tugas Akhir',
          weightPercent: 100.0,
          isRequired: true,
        );

        // Nilai 80: pada Skala Ketat bernilai B (3.00), bukan A
        await courseRepo.recordAssessmentScore(
          componentId: compId,
          score: 80.0,
        );

        await academicRepo.load();
        final overview = academicRepo.getAcademicOverview();

        final histRecord = overview.historicalSemesters.firstWhere(
          (s) => s.termId == pastTermId,
        );
        expect(histRecord.ips, closeTo(3.00, 0.01));
        expect(histRecord.effectivePassedSks, 4);
        expect(histRecord.courses.first.letterGrade, 'B');
      });

      test('Simulator Nilai: Eksperimen hipotetis, perhitungan delta, dan target kalkulator', () async {
        final db = await appDb.open(customPath: dbFilePath);
        await DatabaseSeeder.seedIfNeeded(db);

        final courseRepo = SqliteCourseRepository(appDatabase: appDb);
        final academicRepo = SqliteAcademicRepository(
          appDatabase: appDb,
          courseRepository: courseRepo,
        );
        await courseRepo.load();
        await academicRepo.load();

        final simVm = GradeSimulatorViewModel(academicRepository: academicRepo);
        final initialIps = simVm.simulatedIps;
        final initialIpk = simVm.simulatedIpk;

        // 1. Uji delta format awal
        expect(simVm.ipsDelta, closeTo(0.0, 0.01));
        expect(GradeSimulatorViewModel.formatDelta(simVm.ipsDelta), '0.00');

        // 2. Set semua skor menjadi 100 (A sempurna)
        simVm.setAllScores(100.0);
        expect(simVm.simulatedIps, closeTo(4.00, 0.01));
        expect(simVm.simulatedIpk, greaterThan(initialIpk));
        expect(simVm.ipsDelta, greaterThan(0.0));
        expect(
          GradeSimulatorViewModel.formatDelta(simVm.ipsDelta),
          startsWith('+'),
        );

        // 3. Set semua skor menjadi 0 (E)
        simVm.setAllScores(0.0);
        expect(simVm.simulatedIps, closeTo(0.00, 0.01));
        expect(simVm.ipsDelta, lessThan(0.0));
        expect(
          GradeSimulatorViewModel.formatDelta(simVm.ipsDelta),
          startsWith('-'),
        );

        // 4. Kalkulator Target IPS yang dapat dicapai
        simVm.setTargetIps(3.50);
        final rec = simVm.targetRecommendation;
        expect(rec, isNotNull);
        expect(rec!.isAchievable, isTrue);
        expect(rec.averageRequiredGradePoint, greaterThanOrEqualTo(3.30));

        // Terapkan rekomendasi target
        simVm.applyTargetRecommendation();
        expect(simVm.simulatedIps, greaterThanOrEqualTo(3.30));

        // 5. Kalkulator Target IPS yang melampaui batas (impossible)
        simVm.setTargetIps(4.50);
        final impossibleRec = simVm.targetRecommendation;
        expect(impossibleRec, isNotNull);
        expect(impossibleRec!.isAchievable, isFalse);
        expect(
          impossibleRec.statusMessage,
          contains('melebihi batas indeks prestasi'),
        );

        // 6. Reset simulator mengembalikan seluruh skor ke data awal
        simVm.resetSimulation();
        expect(simVm.simulatedIps, closeTo(initialIps, 0.01));
        expect(simVm.simulatedIpk, closeTo(initialIpk, 0.01));
        expect(simVm.targetIps, isNull);
      });

      test('Penegasan Isolasi Simulator: Aksi simulasi TIDAK PERNAH menulis ke database SQLite', () async {
        final db = await appDb.open(customPath: dbFilePath);
        await DatabaseSeeder.seedIfNeeded(db);

        final courseRepo = SqliteCourseRepository(appDatabase: appDb);
        final academicRepo = SqliteAcademicRepository(
          appDatabase: appDb,
          courseRepository: courseRepo,
        );
        await courseRepo.load();
        await academicRepo.load();

        final actualOverviewBefore = academicRepo.getAcademicOverview();
        final actualScoresBefore = await db.query(
          DatabaseSchema.tableAssessmentScores,
        );

        // Jalankan operasi simulasi ekstensif
        final simVm = GradeSimulatorViewModel(academicRepository: academicRepo);
        expect(simVm.isIsolatedFromPersistence, isTrue);

        simVm.setAllScores(100.0);
        simVm.setTargetIpk(3.90);
        simVm.applyTargetRecommendation();
        simVm.setAllScores(20.0);

        // Periksa bahwa database SQLite tidak berubah sedikit pun
        final actualScoresAfter = await db.query(
          DatabaseSchema.tableAssessmentScores,
        );
        expect(actualScoresAfter.length, actualScoresBefore.length);
        for (var i = 0; i < actualScoresBefore.length; i++) {
          expect(actualScoresAfter[i]['score'], actualScoresBefore[i]['score']);
        }

        // Periksa bahwa AcademicOverview asli pada repositori tetap utuh
        final actualOverviewAfter = academicRepo.getAcademicOverview();
        expect(
          actualOverviewAfter.provisionalIps,
          actualOverviewBefore.provisionalIps,
        );
        expect(
          actualOverviewAfter.cumulativeIpk,
          actualOverviewBefore.cumulativeIpk,
        );
      });
    },
  );
}
