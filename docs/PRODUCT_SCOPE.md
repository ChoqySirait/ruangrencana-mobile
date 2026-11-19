# Ruang Lingkup Produk — RuangRencana

## 1. Visi Produk

**RuangRencana** membantu mahasiswa Indonesia mengelola kehidupan akademik melalui satu aplikasi terpadu yang menghubungkan semester, mata kuliah, jadwal kuliah, tugas, komponen penilaian, nilai, IPS, dan IPK.

- **Tagline**: *"Rencanakan kuliah. Pahami progres."*
- **Platform Utama**: Android (*Android-first*), referensi ukuran layar `393 × 852 px`.
- **Bahasa Antarmuka**: Bahasa Indonesia natural.

## 2. Masalah yang Diselesaikan

Mahasiswa sering memisahkan informasi akademik di berbagai alat: jadwal di catatan gambar, tenggat tugas di pengingat terpisah, bobot nilai di spreadsheet, dan perhitungan IPK secara manual di akhir semester. RuangRencana menyatukan seluruh konteks tersebut agar mahasiswa dapat:

1. Mengetahui jadwal kelas dan tenggat mendesak hari ini dalam sekali pandang.
2. Mengelola daftar tugas berdasarkan status (`Semua`, `Mendatang`, `Terlambat`, `Selesai`) dan prioritas.
3. Memahami perkembangan nilai mata kuliah secara transparan (memisahkan **nilai sementara** dari **nilai akhir**).
4. Menyesuaikan bobot komponen penilaian serta skala konversi nilai sesuai aturan perguruan tinggi masing-masing.
5. Menjalankan simulasi nilai untuk merencanakan target IPS dan IPK tanpa merusak catatan nilai asli.

## 3. Cakupan Tahap Fondasi (Saat Ini)

Yang **sudah masuk** pada tahap inisialisasi ini:

- Shell aplikasi dengan 5 halaman utama: **Beranda**, **Jadwal**, **Tugas**, **Akademik**, dan **Profil**.
- 4 rute sekunder awal: **Detail Mata Kuliah**, **Tambah Tugas**, **Ubah Tugas**, dan **Simulasi Nilai**.
- Sistem tema Material Design 3 terpusat (Mode Terang) dengan token warna, spasi 8-poin, dan tipografi.
- Struktur MVVM + Repository Pattern dengan data demonstrasi fiktif di memori.
- Utilitas kalkulasi akademik (`AcademicCalculator`) beserta pengujian unit dan widget.

## 4. Batasan Cakupan (Di Luar Tahap Fondasi)

Hal-hal berikut **sengaja belum diimplementasikan** pada tahap ini agar fondasi tetap bersih dan mudah dirawat:

- Sistem autentikasi lengkap (login/register).
- Backend jarak jauh, integrasi REST API, dan sinkronisasi cloud.
- Skema database SQLite produksi (`sqflite`) dan migrasi.
- Push notification atau penjadwalan alarm latar belakang OS.
- Analitik lanjutan dan fitur AI.
- Mode Gelap (*Dark Mode*).

## 5. Catatan Arah Desain Visual

Implementasi awal mengacu pada spesifikasi desain RuangRencana (Material Design 3, Light Mode, palet Primary Navy `#17324D`, Secondary Teal `#2D8C83`, Background `#F7F8FA`, Surface `#FFFFFF`, spasi 8-poin). Berkas Figma asli belum diakses langsung oleh alat inspeksi desain, sehingga ukuran spasi dan proporsi pada tahap ini merupakan implementasi rapi berbasis spesifikasi tertulis dan akan diselaraskan ulang apabila frame Figma tersedia.
