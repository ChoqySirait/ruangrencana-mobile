import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../errors/app_failure.dart';
import 'database_migrations.dart';
import 'database_schema.dart';

/// Pengelola koneksi, inisialisasi, dan transaksi database SQLite RuangRencana.
class AppDatabase {
  AppDatabase({
    DatabaseFactory? databaseFactory,
    DatabaseMigrationManager? migrationManager,
  }) : _databaseFactory = databaseFactory ?? sqfliteDatabaseFactory,
       _migrationManager = migrationManager ?? DatabaseMigrationManager();

  static AppDatabase? _instance;

  /// Akses instans global (singleton) untuk digunakan di seluruh aplikasi.
  static AppDatabase get instance => _instance ??= AppDatabase();

  /// Mengizinkan override instans global (berguna untuk pengujian).
  static void setInstance(AppDatabase db) {
    _instance = db;
  }

  static DatabaseFactory get sqfliteDatabaseFactory => databaseFactory;

  final DatabaseFactory _databaseFactory;
  final DatabaseMigrationManager _migrationManager;

  Database? _database;

  /// Mengembalikan instance database yang aktif.
  /// Jika belum terbuka, akan membuka database secara otomatis.
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await open();
    return _database!;
  }

  /// Membuka koneksi database dengan konfigurasi PRAGMA foreign keys dan migrasi.
  Future<Database> open({String? customPath, bool inMemory = false}) async {
    try {
      final String dbPath;
      if (inMemory) {
        dbPath = inMemoryDatabasePath;
      } else if (customPath != null) {
        dbPath = customPath;
      } else {
        final defaultDir = await _databaseFactory.getDatabasesPath();
        dbPath = p.join(defaultDir, DatabaseSchema.databaseName);
      }

      final db = await _databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: DatabaseSchema.version,
          onConfigure: (db) async {
            // Wajib mengaktifkan foreign key enforcement pada setiap koneksi
            await db.execute('PRAGMA foreign_keys = ON;');
          },
          onCreate: (db, version) async {
            await _createSchemaV1(db);
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            await _migrationManager.executeMigrations(
              db,
              oldVersion,
              newVersion,
            );
          },
        ),
      );

      _database = db;
      return db;
    } catch (e) {
      if (e is AppFailure) rethrow;
      throw AppFailure(
        'Gagal menginisialisasi database SQLite: $e',
        code: 'DB_OPEN_FAILED',
      );
    }
  }

  /// Menjalankan aksi dalam transaksi database terisolasi.
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    try {
      return await db.transaction<T>(action);
    } catch (e) {
      if (e is AppFailure) rethrow;
      throw AppFailure(
        'Gagal mengeksekusi transaksi database: $e',
        code: 'DB_TRANSACTION_FAILED',
      );
    }
  }

  /// Menutup koneksi database yang sedang aktif.
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }

  /// Mengeksekusi seluruh skrip pembuatan tabel dan indeks versi 1.
  Future<void> _createSchemaV1(DatabaseExecutor db) async {
    for (final sql in DatabaseSchema.createTableStatements) {
      await db.execute(sql);
    }
    for (final indexSql in DatabaseSchema.createIndexes) {
      await db.execute(indexSql);
    }
  }
}
