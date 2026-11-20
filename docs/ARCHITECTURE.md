# Arsitektur Aplikasi — RuangRencana

## 1. Prinsip Arsitektur

RuangRencana dirancang dengan empat prinsip utama:

1. **Pemisahan Tanggung Jawab (*Separation of Concerns*)**: Widget Flutter hanya merender tampilan dan meneruskan interaksi pengguna. State tampilan dan alur aplikasi berada di **ViewModel**, akses dan mutasi data di **Repository**, dan perhitungan akademik murni di domain calculator (`AcademicCalculator`).
2. **Organisasi *Feature-First***: Setiap fitur bisnis dikelompokkan dalam foldernya sendiri (`courses`, `schedule`, `tasks`, `academic`, `profile`, `dashboard`) agar mudah diuji, dimutasi, atau direfaktor secara terisolasi.
3. **Pola Repositori Terabstraksi (*Abstract Repository Pattern*)**: ViewModel hanya bergantung pada kontrak antarmuka abstrak (`abstract class CourseRepository`, `TaskRepository`, dsb.), bukan langsung pada driver basis data SQLite. Hal ini memungkinkan transisi mulus dari *in-memory* ke *SQLite* (`sqflite`), dan nantinya ke sinkronisasi REST API tanpa merombak lapisan antarmuka pengguna (UI).
4. **Strategi *Cache-Backed / Offline-First***: Repositori membaca dari SQLite saat inisialisasi dan memelihara cache lokal dalam memori untuk pembacaan UI sinkron yang instan. Setiap mutasi data (CREATE, UPDATE, DELETE) langsung dieksekusi ke basis data SQLite menggunakan kueri terparameterisasi dan transaksi atomik.

---

## 2. Alur Eksekusi Aplikasi dari `main.dart`

```text
lib/main.dart
   │  WidgetsFlutterBinding.ensureInitialized()
   │  AppDatabase.instance.open()  ──► Mengaktifkan PRAGMA foreign_keys = ON & Skema V1
   │  DatabaseSeeder.seedIfNeeded() ──► Idempotent initial seed (data demo fiktif)
   │  Sqlite*Repository.load()     ──► Memuat data SQLite ke memori repositori
   │  runApp(RuangRencanaApp(...))
   ▼
lib/app/app.dart (RuangRencanaApp)
   ├─ Menyusun Provider dependency injection (MultiProvider)
   ├─ Menginstansiasi ViewModel (ChangeNotifier) terhubung ke repositori
   └─ Merender MaterialApp.router(theme: AppTheme.light, routerConfig: _router)
         │
         ▼
lib/app/router/app_router.dart
   ├─ StatefulShellRoute.indexedStack -> AppShellScaffold (Bottom Navigation Bar)
   │    ├─ /beranda   -> DashboardView
   │    ├─ /jadwal    -> ScheduleView
   │    ├─ /tugas     -> TasksView
   │    ├─ /akademik  -> AcademicView
   │    └─ /profil    -> ProfileView
   └─ Rute sekunder (rootNavigatorKey, tampil di atas bottom navigation)
        ├─ /mata-kuliah/:courseId     -> CourseDetailView
        ├─ /tugas/tambah              -> TaskFormView (mode tambah)
        ├─ /tugas/:taskId/edit        -> TaskFormView (mode ubah & hapus)
        └─ /akademik/simulasi-nilai   -> GradeSimulatorView
```

---

## 3. Alur Data Melalui Lapisan MVVM dan SQLite

```text
  [ User Interaction di UI ]
              │ (1. Panggil metode ViewModel, mis. saveNewAssignment)
              ▼
    [ TasksViewModel ]
              │ (2. Panggil TaskRepository.addAssignment)
              ▼
  [ SqliteTaskRepository ]
              │ (3. Parameterized INSERT ke SQLite)
              ▼
   [ AppDatabase (SQLite) ]  ──► Disimpan permanen ke disk
              │ (4. Kueri data termutakhir)
              ▼
  [ SqliteTaskRepository ]
              │ (5. Memperbarui cache memori)
              ▼
    [ TasksViewModel ]
              │ (6. notifyListeners() & _onDataChanged callback)
              ▼
 [ UI Widgets (Consumer/watch) ] ──► Tampilan terbarui otomatis tanpa flicker
```

---

## 4. Lapisan Arsitektur dan Tanggung Jawab

| Lapisan | Lokasi | Tanggung Jawab |
| --- | --- | --- |
| **View & Feature Widgets** | `features/<fitur>/presentation/views/` & `widgets/` | Menampilkan antarmuka dari state ViewModel; tidak memuat SQL, rumus akademik mentah, atau kredensial. |
| **ViewModel** | `features/<fitur>/presentation/view_models/` | Mengelola state UI berbasis `ChangeNotifier`, memanggil Repository, dan memicu pembaruan melalui `notifyListeners()`. |
| **Repository** | `features/<fitur>/data/repositories/` | Kontrak abstrak (`CourseRepository`, `TaskRepository`, dsb.) dan implementasi konkret berbasis SQLite (`Sqlite*Repository`). |
| **Model** | `features/<fitur>/data/models/` | Representasi data domain dan pemetaan entitas. |
| **Database Layer** | `lib/core/database/` | `AppDatabase` (koneksi & transaksi), `DatabaseSchema` (tabel V1 & indeks), `DatabaseMigrations` (manajer migrasi), `DatabaseSeeder` (seeder idempotent). |
| **Core & Domain Utils** | `lib/core/` | `AcademicCalculator` (fungsi murni kalkulasi), `DateFormatter` (pemformat tanggal ID), `AppFailure` (penanganan error domain). |

---

## 5. Strategi Masa Depan Menuju Integrasi REST API

Arsitektur saat ini dirancang agar siap diintegrasikan dengan backend REST API di masa mendatang:

1. **Titik Sinkronisasi pada Repositori**: Repositori tetap menjadi satu-satunya sumber data bagi ViewModel. Repositori dapat menerapkan strategi *NetworkBoundResource* atau *SyncAdapter*:
   - Tulis lokal ke SQLite terlebih dahulu (*Offline-First*).
   - Kirim *payload* mutasi ke REST API di latar belakang saat jaringan tersedia.
2. **Tanpa Perubahan pada UI & ViewModel**: ViewModel dan UI tidak memedulikan apakah data berasal dari SQLite lokal, memori, atau REST API jarak jauh karena antarmuka `TaskRepository`, `CourseRepository`, dll. tetap identik.
3. **Pemisahan Identitas dan Token**: Sesi otentikasi (JWT / OAuth2) nantinya disimpan aman menggunakan `flutter_secure_storage`, sementara profil pengguna dan data akademik tetap di-cache secara relasional di SQLite lokal.

---

## 6. Audit Integritas Data & Perlindungan Rekaman (Tahap 1.1)

1. **Otoritas Relasional Murni**: Tabel `academic_terms` dan `courses` menjadi otoritas tunggal riwayat akademik. `app_preferences` hanya menampung preferensi sistem, bukan data riwayat nilai terduplikasi.
2. **Perlindungan Terhadap Penghapusan Rekaman Berharga**: `CourseRepository` menyediakan `getDependentStats()` dan mewajibkan konfirmasi eksplisit (`force: true`) jika mata kuliah memiliki riwayat penilaian akademik, dengan rekomendasi utama berupa pengarsipan (`archiveCourse`).
3. **Penegakan Integritas Waktu UTC**: Konsistensi penulisan stempel waktu UTC di database dan konversi waktu lokal pengguna pada saat penyajian mencegah kesalahan deteksi keterlambatan tugas (*overdue tasks*).
