# Rancangan Model Data — RuangRencana

Dokumen ini menjelaskan entitas data utama, relasi antarentitas, dan rencana pemetaan menuju basis data lokal SQLite (`sqflite`) pada fase pengembangan selanjutnya.

---

## 1. Gambaran Relasi Entitas

```text
StudentProfile (1)
   │
   ├──< Semester (1..N)
   │       │
   │       └──< Course (1..N)
   │              ├──< ScheduleSlot (1..N)
   │              ├──< Assignment (0..N)
   │              └──< AssessmentComponent (1..N)
   │
   └──< GradingScalePolicy (1..N)
           └──< GradeScaleRule (1..N)
```

---

## 2. Daftar Entitas Utama

### 2.1 `StudentProfile`
Menyimpan identitas pengguna dan preferensi lokal (bukan akun server pada tahap awal).

| Kolom / Properti | Tipe | Keterangan |
| --- | --- | --- |
| `id` | `TEXT` / `INTEGER` | Identifier profil lokal |
| `full_name` | `TEXT` | Nama lengkap mahasiswa |
| `student_id` | `TEXT` | NIM / nomor induk (opsional, hanya disimpan lokal di perangkat) |
| `email` | `TEXT` | Email akademik |
| `university` | `TEXT` | Nama perguruan tinggi |
| `study_program` | `TEXT` | Program studi |
| `academic_year` | `TEXT` | Tahun akademik aktif (contoh: `2025/2026`) |
| `active_semester_id` | `TEXT` | Referensi ke semester aktif |
| `target_graduation_sks` | `INTEGER` | Target total SKS kelulusan (mis. `144`) |
| `notify_class_reminder` | `INTEGER` (bool) | Preferensi pengingat kelas |
| `notify_deadline_reminder` | `INTEGER` (bool) | Preferensi pengingat tenggat |
| `notify_weekly_summary` | `INTEGER` (bool) | Preferensi ringkasan mingguan |

### 2.2 `Semester`
Menghubungkan periode kuliah dengan mata kuliah, IPS semester, serta riwayat IPK.

| Kolom / Properti | Tipe | Keterangan |
| --- | --- | --- |
| `id` | `TEXT` (PK) | Identifier semester |
| `name` | `TEXT` | Contoh: `Semester 4 (Genap)` |
| `academic_year` | `TEXT` | Contoh: `2025/2026` |
| `order_index` | `INTEGER` | Urutan kronologis semester (`1, 2, 3, ...`) |
| `status` | `TEXT` | `planned`, `active`, atau `completed` |
| `grading_policy_id` | `TEXT` (FK) | Kebijakan skala nilai yang berlaku pada semester tersebut |

### 2.3 `Course`
Representasi mata kuliah dalam satu semester.

| Kolom / Properti | Tipe | Keterangan |
| --- | --- | --- |
| `id` | `TEXT` (PK) | Identifier mata kuliah |
| `semester_id` | `TEXT` (FK) | Referensi ke `Semester.id` |
| `code` | `TEXT` | Kode mata kuliah (contoh: `IF2401`) |
| `name` | `TEXT` | Nama mata kuliah |
| `sks` | `INTEGER` | Bobot kredit SKS (`> 0`) |
| `lecturer` | `TEXT` | Nama dosen pengampu |
| `default_room` | `TEXT` | Ruang kelas utama |
| `include_in_gpa` | `INTEGER` (bool) | Penanda apakah mata kuliah dihitung pada IPS/IPK |

### 2.4 `ScheduleSlot`
Satu atau lebih slot jadwal mingguan untuk mata kuliah tertentu (mendukung kelas teori dan praktikum terpisah).

| Kolom / Properti | Tipe | Keterangan |
| --- | --- | --- |
| `id` | `TEXT` (PK) | Identifier slot jadwal |
| `course_id` | `TEXT` (FK) | Referensi ke `Course.id` |
| `day_of_week` | `INTEGER` | `1` (Senin) hingga `7` (Minggu) |
| `start_time` | `TEXT` | Format `HH:mm` (24 jam) |
| `end_time` | `TEXT` | Format `HH:mm` (24 jam) |
| `room` | `TEXT` | Lokasi ruangan/lab |

### 2.5 `Assignment`
Daftar tugas yang tertaut ke mata kuliah.

| Kolom / Properti | Tipe | Keterangan |
| --- | --- | --- |
| `id` | `TEXT` (PK) | Identifier tugas |
| `course_id` | `TEXT` (FK) | Referensi ke `Course.id` |
| `title` | `TEXT` | Judul tugas |
| `due_date` | `TEXT` (ISO-8601) | Tanggal dan waktu tenggat |
| `priority` | `TEXT` | `low`, `medium`, `high` |
| `is_completed` | `INTEGER` (bool) | Status penyelesaian |
| `notes` | `TEXT` | Catatan tambahan |

### 2.6 `AssessmentComponent`
Komponen penilaian yang dapat dikonfigurasi bebas oleh mahasiswa untuk setiap mata kuliah.

| Kolom / Properti | Tipe | Keterangan |
| --- | --- | --- |
| `id` | `TEXT` (PK) | Identifier komponen |
| `course_id` | `TEXT` (FK) | Referensi ke `Course.id` |
| `name` | `TEXT` | Contoh: `Tugas`, `Kuis`, `UTS`, `UAS`, `Praktikum` |
| `weight_percent` | `REAL` | Bobot persentase (`0 < w <= 100`) |
| `score` | `REAL` (nullable) | Nilai yang diperoleh (`0..100`), `NULL` jika belum dinilai |
| `is_mandatory` | `INTEGER` (bool) | Apakah wajib terisi sebelum nilai dinyatakan final |

### 2.7 `GradingScalePolicy` & `GradeScaleRule`
Menyimpan skala konversi angka ke huruf dan bobot mutu milik pengguna (tanpa mengunci satu standar kampus tertentu).

| Kolom / Properti (`GradeScaleRule`) | Tipe | Keterangan |
| --- | --- | --- |
| `id` | `TEXT` (PK) | Identifier aturan rentang |
| `policy_id` | `TEXT` (FK) | Referensi ke `GradingScalePolicy.id` |
| `min_score` | `REAL` | Batas bawah inklusif |
| `max_score` | `REAL` | Batas atas inklusif |
| `letter` | `TEXT` | Label huruf (mis. `A`, `AB`, `A-`, sesuai kampus pengguna) |
| `grade_point` | `REAL` | Bobot mutu (mis. `4.00`, `3.75`, `3.50`, dst.) |

---

## 3. Pemisahan Data Simulasi

Data simulasi nilai **tidak** disimpan ke tabel `AssessmentComponent` maupun catatan hasil resmi `Course`. Apabila fitur penyimpanan skenario simulasi dibutuhkan di masa depan, skenario harus ditempatkan pada tabel terpisah (`SimulationScenario` / `SimulationEntry`) agar integritas riwayat akademik asli selalu terjaga.
