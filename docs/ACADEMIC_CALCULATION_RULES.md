# Aturan Kalkulasi Akademik — RuangRencana

Dokumen ini menetapkan aturan bisnis resmi untuk seluruh perhitungan nilai, konversi huruf, IPS, IPK, dan simulasi nilai pada **RuangRencana**. Seluruh logika kalkulasi wajib ditempatkan di luar lapisan UI (saat ini pada `lib/core/utils/academic_calculator.dart`) dan dilindungi oleh *unit test*.

---

## A. Komponen Penilaian yang Dapat Dikonfigurasi Pengguna

Setiap mata kuliah dapat memiliki susunan komponen penilaian yang berbeda sesuai Rencana Pembelajaran Semester (RPS) dosen. Oleh karena itu, pengguna harus dapat menentukan sendiri:

1. **Nama komponen** (contoh: Tugas, Kuis, Praktikum, UTS, Proyek UAS, Kehadiran).
2. **Bobot penilaian** dalam persen (`weightPercent`).
3. **Nilai yang diperoleh** (`score`, rentang `0`–`100`, boleh kosong/`null` apabila belum diumumkan).
4. **Status wajib** (`isMandatory`): menandakan apakah komponen tersebut wajib memiliki nilai sebelum mata kuliah dapat dinilai final.

**Aturan validasi bobot**:
- Total bobot seluruh komponen pada suatu mata kuliah harus sama dengan **100%** sebelum penilaian akhir mata kuliah dapat dianggap lengkap.
- Jika total bobot masih di bawah atau di atas 100%, sistem tetap dapat menampilkan ringkasan sementara tetapi harus menandai bahwa konfigurasi bobot belum lengkap untuk nilai akhir.

---

## B. Perhitungan Nilai Sementara (*Provisional Grade*)

Selama semester masih berjalan, tidak semua komponen sudah memiliki nilai (misalnya UAS belum dilaksanakan). Sistem tidak boleh menganggap komponen yang belum dinilai sebagai angka `0`, karena hal itu menyesatkan mahasiswa.

Untuk komponen yang sudah memiliki nilai (`score != null`):

$$\text{Rata-rata Sementara} = \frac{\sum (\text{score}_i \times \text{weight}_i)}{\sum \text{weight}_i}$$

di mana indeks $i$ hanya mencakup komponen yang **sudah memiliki nilai**.

Ketentuan tampilan:
- Aplikasi **wajib menampilkan persentase bobot yang sudah dinilai** (contoh: *"65% bobot sudah dinilai"*).
- Aplikasi **wajib membedakan secara visual** antara label **Sementara** (*Provisional*) dan **Final**.
- Apabila belum ada satu pun komponen yang memiliki nilai ($\sum \text{weight}_i = 0$), rata-rata sementara bernilai `null` dan ditampilkan sebagai `-`.

---

## C. Nilai Akhir Mata Kuliah (*Final Course Grade*)

Skor akhir mata kuliah hanya dinyatakan **Final** apabila seluruh syarat berikut terpenuhi:

1. Total bobot seluruh komponen yang dikonfigurasi sama dengan **100%** (dengan toleransi pembulatan *floating-point* `0.001`).
2. Seluruh komponen bertanda **wajib** (`isMandatory == true`) telah memiliki nilai.
3. Bobot komponen yang sudah dinilai telah mencapai **100%**.

Jika seluruh syarat terpenuhi, maka:

$$\text{Skor Akhir} = \frac{\sum (\text{score}_i \times \text{weight}_i)}{100}$$

---

## D. Skala Konversi Nilai Perguruan Tinggi yang Dapat Dikonfigurasi

Perguruan tinggi di Indonesia menerapkan aturan konversi nilai yang beragam (misalnya `A / A- / B+ / B` atau `A / AB / B / BC`, dengan batas ambang dan bobot mutu berbeda). RuangRencana **tidak boleh mengunci** satu standar huruf sebagai aturan universal.

Sistem harus mendukung konfigurasi skala nilai milik pengguna yang mencakup:
- **Rentang skor** (`minScore` sampai `maxScore`, inklusif).
- **Nilai huruf** (`letter`).
- **Bobot mutu** (`gradePoint`).
- **Validasi anti-tumpang tindih (*non-overlapping*) & Kelengkapan Skala**:
  - Setiap aturan harus memenuhi `minScore <= maxScore`.
  - Setelah diurutkan naik berdasarkan `minScore`, tidak boleh ada aturan ke-$k$ yang memiliki `minScore < previous.maxScore` (toleransi numerik `0.001`).
  - Tidak boleh ada celah cakupan nilai (*coverage gaps*): batas bawah skala harus mencakup `0.0`, batas atas skala harus mencakup `100.0`, dan jarak antar-rentang tidak boleh meninggalkan celah nilai tak terdefinisi.
  - Skala yang tidak lengkap atau tidak valid dilarang secara diam-diam menghasilkan nilai huruf palsu (*silent grade fallback*); sistem mengembalikan `null` / status tidak terdefinisi (`'-'`).
- **Perilaku Batas Ambang (*Boundary Behavior*) & Kebijakan Pembulatan**:
  - **Penolakan Skor di Luar Rentang (*No Silent Clamping*)**: Sistem menolak secara tegas skor `< 0.0` atau `> 100.0` (mengembalikan `null` atau melempar kegagalan validasi `INVALID_SCORE`). Sistem dilarang melakukan pemotongan diam-diam (*silent clamping*) yang dapat mengubah input pengguna yang keliru menjadi nilai valid.
  - **Dukungan Batas Ekstrem**: Nilai batas tepat `0.0` dan `100.0` didukung penuh secara presisi.
  - **Kebijakan Pembulatan Dua Desimal (*Round Half-Up*)**: Skor dinormalisasi menggunakan pembulatan standar dua desimal:
    $$\text{score}_{\text{normalized}} = \frac{\text{round}(\text{score} \times 100)}{100.0}$$
  - **Penanganan Pecahan Mikro Ambang**:
    - Skor seperti `84.995` dibulatkan secara deterministik menjadi `85.00` (memenuhi batas bawah rentang nilai A `85.00 - 100.00`).
    - Skor seperti `84.994` dibulatkan menjadi `84.99` (tetap berada pada rentang nilai A- `80.00 - 84.99`).
  - **Pencegahan Nilai Palsu**: Skala yang tidak mencakup skor atau skala tidak lengkap tidak akan menghasilkan nilai huruf palsu; sistem mengembalikan status tidak terdefinisi (`'-'`).
- **Kebijakan dapat diubah**: pengguna dapat membuat, mengubah, atau memilih profil skala sesuai aturan kampusnya.

> Catatan tahap fondasi: Skala 4.00 yang muncul pada data demo saat ini hanyalah **contoh konfigurasi awal**, bukan standar baku yang dipaksakan.

---

## E. Perhitungan IPS dan IPK

### 1. Indeks Prestasi Semester (IPS)
IPS dihitung sebagai rata-rata tertimbang bobot mutu terhadap SKS mata kuliah dalam satu semester:

$$\text{IPS} = \frac{\sum (\text{SKS}_j \times \text{GradePoint}_j)}{\sum \text{SKS}_j}$$

- Pada semester yang masih berjalan, nilai yang ditampilkan wajib dilabeli **IPS Sementara** karena berasal dari nilai sementara mata kuliah yang sudah memiliki komponen bernilai.
- Mata kuliah dengan `SKS <= 0` atau belum memiliki nilai sama sekali tidak dimasukkan ke penyebut SKS pembagi.

### 2. Indeks Prestasi Kumulatif (IPK)
IPK dihitung menggunakan seluruh hasil mata kuliah selesai dan SKS yang termasuk dalam perhitungan kumulatif lintas semester:

$$\text{IPK} = \frac{\sum_{\text{semester}} \sum (\text{SKS} \times \text{GradePoint})}{\sum_{\text{semester}} \sum \text{SKS}}$$

**Asumsi eksplisit yang diterapkan dan wajib transparan ke pengguna**:
- Pada tahap awal, IPK kumulatif dihitung dari semester-semester yang berstatus **selesai** (*completed*), terpisah dari **IPS Sementara** semester aktif.
- Kebijakan khusus tiap kampus — seperti aturan mata kuliah mengulang (*retake*: ambil nilai tertinggi vs nilai terakhir vs semua nilai dihitung) — tidak boleh diasumsikan diam-diam; opsi kebijakan mata kuliah ulang akan ditambahkan sebagai pengaturan eksplisit pada fase implementasi penuh.

---

## F. Simulasi Nilai (*Grade Simulation*)

- Seluruh nilai yang diubah di layar Simulasi Nilai bersifat **hipotetis**.
- Simulasi **tidak pernah** menulis ulang, mengubah, atau menimpa data nilai asli di repository maupun database lokal.
- Kalkulasi proyeksi IPS dan proyeksi IPK selalu dijalankan pada objek/state terisolasi (`GradeSimulatorViewModel`) dengan memanfaatkan fungsi murni `AcademicCalculator`.

---

## G. Otoritas Riwayat Semester & Perlindungan Rekaman Akademik

1. **Sumber Kebenaran Riwayat Akademik Tunggal**:
   - Tabel `academic_terms` adalah pemegang otoritas tunggal periode semester.
   - Tabel `courses` mereferensikan `academic_terms(id)` terkait.
   - Hasil nilai dan IPS riwayat semester lampau selalu **dihitung secara relasional dinamis** dari mata kuliah, komponen penilaian, dan skor yang terhubung.
   - Tabel `app_preferences` murni digunakan untuk konfigurasi preferensi pengguna (seperti notifikasi dan target SKS kelulusan); tidak ada data riwayat akademik yang diduplikasi dalam format JSON di preferensi.

2. **Perlindungan Terhadap Penghapusan Mata Kuliah**:
   - Mata kuliah yang telah memiliki riwayat penilaian (`assessment_scores`) atau berada pada semester yang sudah ditutup tidak boleh dihapus secara gegabah.
   - **Pengarsipan (*archiving*)** merupakan operasi yang direkomendasikan untuk mempertahankan integritas riwayat transkrip.
   - Penghapusan permanen memerlukan konfirmasi eksplisit (`force: true`) dan seluruh entitas dependen dihapus secara bersih dalam transaksi atomik untuk mencegah *orphaned assessment scores*.

---

## H. Strategi Konsistensi Waktu dan Zona Waktu (*Timezone Strategy*)

- **Penyimpanan (*Storage*)**: Seluruh tanggal dan stempel waktu disimpan dalam format ISO 8601 berbasis UTC (`.toUtc().toIso8601String()`) di basis data SQLite.
- **Penyajian (*Presentation*)**: Seluruh tanggal dikonversi secara eksplisit ke waktu lokal perangkat pengguna (`.toLocal()`) saat dimuat dan diformat oleh `DateFormatter`.
- **Evaluasi Tenggat Waktu**: Perbandingan status tenggat waktu (`overdue` vs `upcoming`) dilakukan secara mutlak menggunakan representasi waktu UTC terstandardisasi (`dueDate.toUtc().isBefore(reference.toUtc())`), sehingga mencegah kesalahan status tugas akibat perbedaan zona waktu atau pergantian waktu musim.
