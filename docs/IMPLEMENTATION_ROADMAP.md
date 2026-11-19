# Peta Jalan Implementasi — RuangRencana

Peta jalan ini membagi pengembangan **RuangRencana** menjadi tahapan terukur agar setiap fase dapat diuji, diverifikasi, dan dirawat dengan baik.

---

## Tahap 0 — Inisialisasi Fondasi (Selesai)

**Tujuan**: Membangun struktur proyek Flutter yang bersih, dapat diuji, dan siap dikembangkan.

- [x] Inspeksi lingkungan Flutter, Dart, Git, dan Android toolchain.
- [x] Inisialisasi proyek Flutter Android-first (`ruangrencana`).
- [x] Sistem desain Material Design 3 (Mode Terang) terpusat (`AppColors`, `AppSpacing`, `AppTextStyles`, `AppTheme`).
- [x] Struktur direktori *feature-first* + MVVM (`Provider + ChangeNotifier`) + Repository Pattern.
- [x] Navigasi 5 tab utama (`GoRouter` `StatefulShellRoute`) dan 4 rute sekunder awal.
- [x] Utilitas kalkulasi akademik (`AcademicCalculator`) + *unit test* & *widget test*.
- [x] Dokumentasi awal produk, arsitektur, model data, dan aturan kalkulasi akademik.

---

## Tahap 1 — Persistensi Lokal SQLite (`sqflite`) & Integrasi Repositori (Selesai)

**Tujuan**: Mengganti implementasi *in-memory* menjadi penyimpanan lokal relasional permanen di perangkat Android.

- [x] Menambahkan dependensi produksi `sqflite`, `path`, dan pengujian `sqflite_common_ffi`.
- [x] Merancang dan menguji Skema Database SQLite Versi 1 (10 tabel ternormalisasi, konstrain foreign key, dan 13 indeks query).
- [x] Mengembangkan infrastruktur migrasi skema (`DatabaseMigrationManager`) dan transaksi atomik.
- [x] Mengimplementasikan strategi seeding data demonstrasi idempotent (`DatabaseSeeder`).
- [x] Mengonversi repositori `ProfileRepository`, `CourseRepository`, `ScheduleRepository`, `TaskRepository`, dan `AcademicRepository` ke implementasi SQLite (`Sqlite*Repository`).
- [x] Mengintegrasikan persistensi penuh pada alur aplikasi (CRUD Profil, Mata Kuliah, Jadwal Kuliah, Tugas, dan Skala Nilai).
- [x] Menjaga isolasi simulasi nilai agar tidak memodifikasi data riwayat asli.
- [x] Pengujian unit & integrasi persistensi siklus hidup (reopening DB antar-sesi).

---

## Tahap 2 — Manajemen Tugas Lengkap & Sinkronisasi Beranda

**Tujuan**: Menyempurnakan pengelolaan tugas dan indikator prioritas.

- Persistensi CRUD Tugas (tambah, ubah, hapus, tandai selesai, pencarian, dan penyortiran berdasarkan tenggat/prioritas).
- Pengelolaan filter cerdas dan pengelompokan tugas per mata kuliah.
- Validasi formulir tanggal & jam tenggat yang lebih lengkap.

---

## Tahap 3 — Konfigurasi Komponen Penilaian & Skala Nilai Kampus

**Tujuan**: Mengimplementasikan secara penuh seluruh aturan bisnis pada [docs/ACADEMIC_CALCULATION_RULES.md](ACADEMIC_CALCULATION_RULES.md).

- Editor komponen penilaian per mata kuliah (tambah/ubah/hapus komponen, bobot persen, status wajib, input skor, validasi total bobot = 100%).
- Editor skala konversi nilai kampus (tambah/ubah/hapus rentang skor, huruf, bobot mutu, serta validasi anti-overlap).
- Kebijakan eksplisit penanganan mata kuliah mengulang (*retake*) untuk perhitungan IPK.

---

## Tahap 4 — Simulasi Nilai Lanjutan & Pengingat Lokal

**Tujuan**: Memperkaya perencanaan target akademik dan pengingat tepat waktu.

- Simulasi per komponen penilaian yang belum dinilai (misalnya menghitung *"nilai UAS minimal agar mendapat huruf A"*).
- Pengingat lokal terjadwal (*local notifications*) untuk jadwal kelas dan tenggat tugas sesuai preferensi di halaman Profil.
- Ekspor/cadangan data lokal (*backup & restore* JSON lokal) agar data aman saat ganti perangkat.

---

## Tahap 5 — Penyempurnaan UX & Kesiapan Rilis

- Penyelarasan presisi UI terhadap frame final Figma (jika aset/file Figma tersedia) serta dukungan font Inter berlisensi bila disertakan.
- Pengujian integrasi menyeluruh pada emulator dan perangkat Android fisik berbagai ukuran layar.
- Penyiapan ikon peluncur, *splash screen*, serta konfigurasi build rilis Android (`.aab` / `.apk`).
