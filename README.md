# RuangRencana Mobile

> **"Rencanakan kuliah. Pahami progres."**

**RuangRencana** adalah aplikasi mobile *Android-first* berbasis Flutter untuk membantu mahasiswa Indonesia merencanakan dan memantau aktivitas akademik secara terintegrasi — mulai dari semester, mata kuliah, jadwal kuliah, tugas, komponen penilaian, nilai sementara dan akhir, hingga IPS, IPK, serta simulasi nilai.

---

## Status Proyek

Saat ini proyek telah menyelesaikan **Tahap 1 — Implementasi Basis Data SQLite & Persistensi Repositori**:

- Fondasi proyek Flutter (Android-first) dengan arsitektur **MVVM** dan struktur *feature-first*.
- Sistem desain **Material Design 3** (Mode Terang) dengan token warna, tipografi, dan spasi 8-poin terpusat.
- Navigasi lima halaman utama persisten menggunakan **GoRouter** (`StatefulShellRoute`) beserta rute sekunder (Detail Mata Kuliah, Tambah/Ubah/Hapus Tugas, Simulasi Nilai).
- Lapisan basis data relasional **SQLite** (`sqflite`) dengan 10 tabel ternormalisasi, penegakan *foreign key*, transaksi atomik, 13 indeks query, serta manajer migrasi skema (`DatabaseMigrationManager`).
- Repositori terintegrasi penuh ke SQLite (`SqliteProfileRepository`, `SqliteCourseRepository`, `SqliteScheduleRepository`, `SqliteTaskRepository`, `SqliteAcademicRepository`) dengan strategi *cache-backed / offline-first*.
- Strategi *seeding* awal *idempotent* (`DatabaseSeeder`) dengan data demonstrasi fiktif yang tidak menimpa data pengguna.
- Perhitungan akademik murni terpisah di `AcademicCalculator` (provisional grade, kesiapan final grade, IPS/IPK dinamis, isolasi simulasi nilai).
- Pengujian komprehensif mencakup *unit test* kalkulator, *database schema test*, *repository persistence lifecycle test*, dan *widget test* pada viewport `393 × 852 px`.

---

## Teknologi Utama

| Komponen | Teknologi |
| --- | --- |
| Framework | Flutter (SDK 3.50.0, stable) |
| Bahasa | Dart (3.14.0) |
| Sistem Desain | Material Design 3 (`material_ui`) |
| Arsitektur | MVVM (*feature-first*) + Repository Pattern |
| State Management | `provider` (`ChangeNotifier`) |
| Navigasi | `go_router` (`StatefulShellRoute.indexedStack`) |
| Persistensi Lokal | SQLite melalui `sqflite` & `path` |
| Pengujian Database Lokal | `sqflite_common_ffi` (eksekusi pengujian di lingkungan Windows) |

---

## Struktur Direktori

```text
lib/
├── main.dart                     # Entry point aplikasi
├── app/
│   ├── app.dart                  # Root widget, Provider DI, Theme, GoRouter
│   ├── router/app_router.dart    # Definisi rute utama & sekunder
│   └── theme/                    # Token warna, spasi, tipografi, ThemeData
├── core/
│   ├── constants/                # Konstanta global aplikasi
│   ├── errors/                   # Kontrak error domain (AppFailure)
│   ├── utils/                    # Kalkulator akademik & pemformat tanggal ID
│   └── widgets/                  # Widget presentasi bersama (shell, badge, kartu)
└── features/
    ├── dashboard/                # Beranda
    ├── schedule/                 # Jadwal kuliah mingguan
    ├── tasks/                    # Daftar tugas, filter, tambah/ubah tugas
    ├── courses/                  # Model mata kuliah & detail mata kuliah
    ├── academic/
    │   ├── grades/               # Ringkasan IPS, IPK, nilai mata kuliah
    │   └── simulator/            # Simulasi nilai hipotetis (terpisah dari data asli)
    └── profile/                  # Profil mahasiswa & preferensi
```

---

## Prasyarat & Cara Menjalankan

### Prasyarat

- Flutter SDK stabil (`>= 3.50.0`) dan Dart SDK (`^3.14.0`).
- Android SDK & Android Studio / Android Emulator (atau perangkat fisik Android dengan *USB Debugging*).

### Menjalankan Secara Lokal

```bash
# 1. Unduh dependensi
flutter pub get

# 2. Jalankan analisis statis & pengujian
flutter analyze
flutter test

# 3. Jalankan pada emulator / perangkat Android
flutter emulators --launch <emulator_id>
flutter run

# 4. Build APK debug Android
flutter build apk --debug
```

---

## Dokumentasi Proyek

- [Ruang Lingkup Produk](docs/PRODUCT_SCOPE.md)
- [Arsitektur Aplikasi](docs/ARCHITECTURE.md)
- [Rancangan Model Data](docs/DATA_MODEL.md)
- [Aturan Kalkulasi Akademik](docs/ACADEMIC_CALCULATION_RULES.md)
- [Peta Jalan Implementasi](docs/IMPLEMENTATION_ROADMAP.md)

---

## Catatan Data & Privasi

Seluruh nama mahasiswa, NIM (`2024010099`), email, dan data perkuliahan di dalam repositori ini adalah **data demonstrasi fiktif**. Jangan pernah menyimpan NIM asli, kredensial, atau data pribadi ke dalam repositori publik.
