# Arsitektur Aplikasi — RuangRencana

## 1. Prinsip Arsitektur

RuangRencana dirancang dengan tiga prinsip utama:

1. **Pemisahan Tanggung Jawab (*Separation of Concerns*)**: Widget Flutter hanya merender tampilan dan meneruskan interaksi pengguna. State tampilan dan alur aplikasi berada di **ViewModel**, akses data di **Repository**, dan perhitungan akademik di utilitas domain murni (`AcademicCalculator`).
2. **Organisasi *Feature-First***: Setiap fitur bisnis dikelompokkan dalam foldernya sendiri agar mudah ditambah, diuji, atau direfaktor secara terisolasi.
3. **Siap Migrasi ke SQLite tanpa Mengubah UI**: ViewModel bergantung pada kontrak abstrak (`abstract class *Repository`), bukan langsung pada implementasi *in-memory*. Saat `sqflite` ditambahkan pada tahap berikutnya, cukup mengganti implementasi repository pada titik penyusunan dependensi (`lib/app/app.dart`).

## 2. Alur Mulai Aplikasi dari `main.dart`

```text
lib/main.dart
   │  WidgetsFlutterBinding.ensureInitialized()
   │  runApp(const RuangRencanaApp())
   ▼
lib/app/app.dart (RuangRencanaApp)
   ├─ Membuat instance GoRouter (AppRouter.createRouter)
   ├─ Menginisialisasi Repository (InMemory*Repository)
   ├─ Menginisialisasi ViewModel (ChangeNotifier)
   ├─ Membungkus pohon widget dengan MultiProvider
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
        ├─ /tugas/:taskId/edit        -> TaskFormView (mode ubah)
        └─ /akademik/simulasi-nilai   -> GradeSimulatorView
```

## 3. Lapisan Arsitektur (MVVM + Repository)

| Lapisan | Lokasi | Tanggung Jawab |
| --- | --- | --- |
| **View & Feature Widgets** | `features/<fitur>/presentation/views/` & `widgets/` | Menampilkan UI dari state ViewModel; tidak memuat rumus akademik maupun data mentah. |
| **ViewModel** | `features/<fitur>/presentation/view_models/` | Mengelola state UI menggunakan `ChangeNotifier`, memanggil Repository, dan memberi tahu View melalui `notifyListeners()`. |
| **Repository** | `features/<fitur>/data/repositories/` | Menyediakan kontrak abstrak akses data dan implementasinya (saat ini *in-memory*, nantinya SQLite). |
| **Model** | `features/<fitur>/data/models/` | Representasi struktur data tidak langsung terikat ke widget. |
| **Core & Domain Utils** | `lib/core/` | Utilitas murni (`AcademicCalculator`, `DateFormatter`), kontrak error (`AppFailure`), konstanta, dan widget UI bersama. |
| **App Shell & Theme** | `lib/app/` | Konfigurasi `ThemeData`, token warna/spasi/tipografi, GoRouter, serta komposisi Provider. |

## 4. Keputusan Teknis Penting

### Pemilihan `StatefulShellRoute.indexedStack` (GoRouter)
Mempertahankan state masing-masing tab (misalnya filter aktif pada halaman Tugas atau hari terpilih pada halaman Jadwal) ketika pengguna berpindah antar tab bawah, sementara rute sekunder menggunakan `rootNavigatorKey` agar bilah navigasi bawah otomatis tersembunyi saat membuka detail atau formulir.

### Pemilihan `Provider + ChangeNotifier`
Ringan, resmi direkomendasikan ekosistem Flutter, mudah dipahami untuk pemeliharaan jangka panjang, dan cukup untuk mengelola komunikasi antar fitur (misalnya pembaruan tugas atau profil langsung memicu `DashboardViewModel.refresh()`).

### Pemisahan `GradeSimulatorViewModel`
`GradeSimulatorViewModel` dibuat dengan siklus hidup lokal pada layar `GradeSimulatorView` dan hanya membaca `AcademicRepository` secara *read-only*. Skor hipotetis disimpan terpisah pada peta memori lokal sehingga mustahil menimpa nilai akademik sebenarnya.

### Substitusi Font (Roboto)
Spesifikasi desain menyarankan font **Inter** jika aset berlisensi tersedia. Pada tahap inisialisasi ini, aplikasi menggunakan **Roboto** (font bawaan Android) yang didefinisikan terpusat pada `lib/app/theme/app_text_styles.dart` sehingga penggantian ke Inter di masa depan cukup dilakukan di satu tempat plus pendaftaran aset pada `pubspec.yaml`.

### Rencana Persistensi Lokal (SQLite / `sqflite`)
Tahap berikutnya akan memperkenalkan lapisan `local_database` (pembukaan DB, manajemen versi skema, dan DAO/tabel) di balik antarmuka `CourseRepository`, `ScheduleRepository`, `TaskRepository`, `AcademicRepository`, dan `ProfileRepository`. Pada tahap fondasi ini, kelas placeholder database sengaja tidak dibuat agar tidak meninggalkan kode mati (*dead code*).
