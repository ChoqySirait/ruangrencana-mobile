import 'package:sqflite/sqflite.dart';

import '../errors/app_failure.dart';

/// Kontrak migrasi skema database SQLite antarversi.
abstract class DatabaseMigration {
  const DatabaseMigration();

  int get fromVersion;
  int get toVersion;

  Future<void> migrate(DatabaseExecutor db);
}

/// Manajer migrasi skema database yang bertanggung jawab menjalankan migrasi
/// secara berurutan dan membungkusnya dalam transaksi aman.
class DatabaseMigrationManager {
  DatabaseMigrationManager([List<DatabaseMigration>? migrations])
    : _migrations = List.unmodifiable(migrations ?? const []);

  final List<DatabaseMigration> _migrations;

  /// Menjalankan rantai migrasi dari [oldVersion] ke [newVersion].
  Future<void> executeMigrations(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion >= newVersion) return;

    final applicable =
        _migrations
            .where(
              (m) => m.fromVersion >= oldVersion && m.toVersion <= newVersion,
            )
            .toList()
          ..sort((a, b) => a.fromVersion.compareTo(b.fromVersion));

    var currentVersion = oldVersion;
    for (final migration in applicable) {
      if (migration.fromVersion != currentVersion) {
        throw AppFailure(
          'Urutan migrasi database terputus dari versi $currentVersion ke ${migration.fromVersion}',
          code: 'DB_MIGRATION_GAP',
        );
      }

      await db.transaction((txn) async {
        await migration.migrate(txn);
      });
      currentVersion = migration.toVersion;
    }

    if (currentVersion != newVersion && applicable.isNotEmpty) {
      throw AppFailure(
        'Migrasi database belum mencapai target versi $newVersion (terhenti di $currentVersion)',
        code: 'DB_MIGRATION_INCOMPLETE',
      );
    }
  }
}
