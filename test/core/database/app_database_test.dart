import 'package:flutter_test/flutter_test.dart';
import 'package:ruangrencana/core/database/app_database.dart';
import 'package:ruangrencana/core/database/database_migrations.dart';
import 'package:ruangrencana/core/database/database_schema.dart';
import 'package:ruangrencana/core/errors/app_failure.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('AppDatabase & DatabaseSchema V1 Initialization', () {
    late AppDatabase appDb;

    setUp(() {
      appDb = AppDatabase(databaseFactory: databaseFactoryFfi);
    });

    tearDown(() async {
      await appDb.close();
    });

    test(
      'membuat seluruh 10 tabel ternormalisasi pada skema versi 1',
      () async {
        final db = await appDb.open(inMemory: true);

        // Verifikasi versi skema database
        final version = await db.getVersion();
        expect(version, DatabaseSchema.version);

        // Ambil seluruh daftar tabel yang terbentuk di sqlite_master
        final tableResult = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%';",
        );
        final createdTables = tableResult
            .map((row) => row['name'] as String)
            .toSet();

        final expectedTables = {
          DatabaseSchema.tableStudentProfiles,
          DatabaseSchema.tableGradingScales,
          DatabaseSchema.tableGradingScaleRanges,
          DatabaseSchema.tableAcademicTerms,
          DatabaseSchema.tableCourses,
          DatabaseSchema.tableClassSchedules,
          DatabaseSchema.tableAssignments,
          DatabaseSchema.tableAssessmentComponents,
          DatabaseSchema.tableAssessmentScores,
          DatabaseSchema.tableAppPreferences,
        };

        expect(createdTables, containsAll(expectedTables));
      },
    );

    test('membuat seluruh indeks optimasi query', () async {
      final db = await appDb.open(inMemory: true);

      final indexResult = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND name NOT LIKE 'sqlite_%';",
      );
      final createdIndexes = indexResult
          .map((row) => row['name'] as String)
          .toSet();

      expect(
        createdIndexes,
        containsAll([
          'idx_academic_terms_is_active',
          'idx_academic_terms_grading_scale',
          'idx_courses_academic_term',
          'idx_courses_archived_at',
          'idx_class_schedules_course',
          'idx_class_schedules_weekday',
          'idx_assignments_course',
          'idx_assignments_due_at',
          'idx_assignments_status',
          'idx_assessment_components_course',
          'idx_assessment_scores_component',
          'idx_grading_scale_ranges_scale',
          'idx_app_preferences_key',
        ]),
      );
    });

    test('menegakkan aturan foreign keys (PRAGMA foreign_keys = ON)', () async {
      final db = await appDb.open(inMemory: true);

      // Coba memasukkan mata kuliah dengan academic_term_id yang tidak ada di tabel academic_terms
      expect(
        () async => await db.insert(DatabaseSchema.tableCourses, {
          'academic_term_id': 9999, // ID tidak ada
          'course_code': 'IF101',
          'course_name': 'Dasar Pemrograman',
          'credits': 3,
          'lecturer_name': 'Dosen Fiktif',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test(
      'menggulung balik (rollback) perubahan saat transaksi gagal',
      () async {
        final db = await appDb.open(inMemory: true);

        // Pastikan tabel student_profiles awalnya kosong
        expect(await db.query(DatabaseSchema.tableStudentProfiles), isEmpty);

        try {
          await appDb.transaction((txn) async {
            await txn.insert(DatabaseSchema.tableStudentProfiles, {
              'full_name': 'Mahasiswa Uji',
              'student_number': '12345',
              'study_program': 'Informatika',
              'institution_name': 'Kampus Uji',
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            });
            // Picu error sengaja di dalam transaksi
            throw Exception('Simulasi kegagalan di tengah transaksi');
          });
        } catch (_) {
          // Expected
        }

        // Record harus digulung balik sehingga tabel tetap kosong
        final after = await db.query(DatabaseSchema.tableStudentProfiles);
        expect(after, isEmpty);
      },
    );
  });

  group('DatabaseMigrationManager', () {
    test('berjalan aman tanpa operasi jika versi sama', () async {
      final manager = DatabaseMigrationManager();
      final appDb = AppDatabase(databaseFactory: databaseFactoryFfi);
      final db = await appDb.open(inMemory: true);

      await expectLater(manager.executeMigrations(db, 1, 1), completes);

      await appDb.close();
    });

    test('melemparkan AppFailure jika terjadi jeda urutan migrasi', () async {
      final manager = DatabaseMigrationManager([
        _TestMigration(from: 2, to: 3), // Jeda: tidak ada migrasi dari 1 ke 2
      ]);

      final appDb = AppDatabase(databaseFactory: databaseFactoryFfi);
      final db = await appDb.open(inMemory: true);

      expect(
        () => manager.executeMigrations(db, 1, 3),
        throwsA(
          isA<AppFailure>().having((e) => e.code, 'code', 'DB_MIGRATION_GAP'),
        ),
      );

      await appDb.close();
    });
  });
}

class _TestMigration extends DatabaseMigration {
  const _TestMigration({required this.from, required this.to});

  final int from;
  final int to;

  @override
  int get fromVersion => from;

  @override
  int get toVersion => to;

  @override
  Future<void> migrate(DatabaseExecutor db) async {}
}
