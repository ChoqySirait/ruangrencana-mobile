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

## Tahap 1.1 — Audit Basis Data & Penyempurnaan Integritas Data (Selesai)

**Tujuan**: Menjamin otoritas data akademik relasional murni, konsistensi data demo fiktif, validasi skala nilai, perlindungan riwayat rekaman, dan konsistensi zona waktu.

- [x] Mengalihkan sumber riwayat semester lampau sepenuhnya ke tabel `academic_terms` dan `courses` (menghapus duplikasi riwayat di `app_preferences`).
- [x] Menstandarkan data demonstrasi awal yang fiktif, konsisten, dan aman (`Mahasiswa Demo`, `DEMO-001`, `S1 Sistem Informasi`, `Universitas Contoh`).
- [x] Menerapkan mekanisme perlindungan terhadap penghapusan mata kuliah (`getDependentStats`, blokir penghapusan mata kuliah berpenilaian tanpa `force: true`, dan rekomendasi utama pengarsipan).
- [x] Memperkuat validasi skala penilaian (`validateGradingScale`: anti-overlap, deteksi celah cakupan nilai, dukungan nilai 100.0 dan 0.0, dan pembulatan desimal ambang).
- [x] Memastikan konsistensi zona waktu (penyimpanan UTC mutlak di basis data dan konversi waktu lokal di lapisan tampilan).
- [x] Memperluas pengujian unit dan integrasi untuk memvalidasi seluruh perbaikan integritas data.

---

## Tahap 2 — Manajemen Semester, Mata Kuliah, Jadwal & Komponen Penilaian (Selesai)

**Tujuan**: Mengimplementasikan manajemen siklus perkuliahan aktif, penjadwalan mingguan, dan pencatatan komponen penilaian berbasis SQLite.

- [x] Manajemen Semester: Tambah, ubah, aktifkan/nonaktifkan semester dengan validasi tanggal dan proteksi nomor semester unik.
- [x] Manajemen Mata Kuliah: CRUD mata kuliah dengan atribut kode, nama, SKS, dosen, ruang, warna identitas, dan status aktif.
- [x] Penjadwalan Perkuliahan: Manajemen sesi perkuliahan mingguan (hari, jam mulai, jam selesai) dengan deteksi bentrok jadwal.
- [x] Komponen Penilaian Fleksibel: Manajemen komponen evaluasi per mata kuliah (bobot persen, status wajib, dan input skor 0.0 - 100.0 dengan penolakan silent clamping).

---

## Tahap 3 — Konfigurasi Skala Nilai Kampus, Performa Akademik & Simulator IPK (Selesai)

**Tujuan**: Mengimplementasikan kustomisasi skala penilaian perguruan tinggi, ringkasan capaian akademik dinamis, dan simulator target IPK/IPS terisolasi.

- [x] Manajemen Skala Nilai Kampus: CRUD skala penilaian dengan preset standar (Standar 4.0 A-E, Skala Plus/Minus A-E, dan Skala Angka Ketat).
- [x] Validasi Skala Presisi: Validasi anti-overlap, deteksi celah cakupan nilai (0.0 - 100.0), proteksi skala default (`CANNOT_DELETE_DEFAULT`), dan proteksi skala yang sedang digunakan semester (`SCALE_IN_USE`).
- [x] Performa Akademik Relasional: Kalkulasi dinamis IPS Resmi (hanya mata kuliah berstatus final 100% bobot), IPS Sementara, IPK Kumulatif multi-semester, SKS Lulus efektif (pengecualian nilai E/0.00), dan total SKS Terdaftar.
- [x] Riwayat Semester Terekspansi: Kartu riwayat semester dengan daftar rincian mata kuliah, huruf mutu, nilai akhir, dan SKS yang dapat diciutkan/dibuka (*collapsible*).
- [x] Simulator Target IPK/IPS: Fitur target solver dinamis untuk merekomendasikan nilai yang harus dicapai, kalkulasi selisih delta, preset cepat, dan jaminan isolasi penuh dari database SQLite.

---

## Tahap 4 — Manajemen Tugas Lengkap, Pengingat Lokal & Sinkronisasi Beranda

**Tujuan**: Memperkaya perencanaan target akademik dan pengingat tepat waktu.

- Simulasi per komponen penilaian yang belum dinilai (misalnya menghitung *"nilai UAS minimal agar mendapat huruf A"*).
- Pengingat lokal terjadwal (*local notifications*) untuk jadwal kelas dan tenggat tugas sesuai preferensi di halaman Profil.
- Ekspor/cadangan data lokal (*backup & restore* JSON lokal) agar data aman saat ganti perangkat.

---

## Tahap 5 — Penyempurnaan UX & Kesiapan Rilis

- Penyelarasan presisi UI terhadap frame final Figma (jika aset/file Figma tersedia) serta dukungan font Inter berlisensi bila disertakan.
- Pengujian integrasi menyeluruh pada emulator dan perangkat Android fisik berbagai ukuran layar.
- Penyiapan ikon peluncur, *splash screen*, serta konfigurasi build rilis Android (`.aab` / `.apk`).
