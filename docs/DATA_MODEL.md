# Rancangan dan Realisasi Model Data SQLite — RuangRencana

Dokumen ini mendokumentasikan skema basis data relasional SQLite (`sqflite`) yang diimplementasikan pada **Tahap 1 (Skema Versi 1)** beserta relasi, batasan (*constraints*), dan indeks performanya.

---

## 1. Diagram Relasi Entitas Relasional (ERD)

```text
student_profiles (1)
       │ (preferensi & profil aktif)
       ▼
app_preferences (Key-Value)

grading_scales (1) ──< (1..N) grading_scale_ranges
       │ (1)
       │ (referensi skala penilaian)
       ▼ (N)
academic_terms (1) ──< (1..N) courses
                                  │
                                  ├──< (1..N) class_schedules
                                  ├──< (0..N) assignments
                                  └──< (1..N) assessment_components
                                                    │ (1)
                                                    └──< (0..1) assessment_scores
```

---

## 2. Struktur Tabel SQLite (Skema Versi 1)

### 2.1 `student_profiles`
Menyimpan identitas mahasiswa dan institusi di perangkat lokal.

| Kolom | Tipe Data | Batasan / Konstrain | Keterangan |
| --- | --- | --- | --- |
| `id` | `INTEGER` | `PRIMARY KEY AUTOINCREMENT` | Identifier unik profil |
| `full_name` | `TEXT` | `NOT NULL` | Nama lengkap mahasiswa |
| `student_number` | `TEXT` | `NULLABLE` | Nomor Induk Mahasiswa (NIM) |
| `study_program` | `TEXT` | `NOT NULL` | Program studi |
| `institution_name` | `TEXT` | `NOT NULL` | Nama perguruan tinggi / institut |
| `created_at` | `TEXT` | `NOT NULL` | Waktu dibuat (format ISO-8601 UTC) |
| `updated_at` | `TEXT` | `NOT NULL` | Waktu terakhir diubah |

### 2.2 `grading_scales`
Master skala konversi penilaian yang dapat dibuat dan disesuaikan pengguna.

| Kolom | Tipe Data | Batasan / Konstrain | Keterangan |
| --- | --- | --- | --- |
| `id` | `INTEGER` | `PRIMARY KEY AUTOINCREMENT` | Identifier skala |
| `scale_name` | `TEXT` | `NOT NULL` | Nama skala (mis. *Skala 4.00 Standar Kampus*) |
| `is_default` | `INTEGER` | `NOT NULL DEFAULT 0 CHECK (is_default IN (0, 1))` | Penanda skala default |
| `created_at` | `TEXT` | `NOT NULL` | Waktu dibuat (ISO-8601) |
| `updated_at` | `TEXT` | `NOT NULL` | Waktu diperbarui |

### 2.3 `grading_scale_ranges`
Rentang batas nilai angka menuju huruf dan bobot mutu (grade point).

| Kolom | Tipe Data | Batasan / Konstrain | Keterangan |
| --- | --- | --- | --- |
| `id` | `INTEGER` | `PRIMARY KEY AUTOINCREMENT` | Identifier rentang |
| `grading_scale_id` | `INTEGER` | `NOT NULL REFERENCES grading_scales(id) ON DELETE CASCADE` | Tautan ke master skala |
| `minimum_score` | `REAL` | `NOT NULL CHECK (minimum_score >= 0.0 AND minimum_score <= 100.0)` | Batas bawah inklusif |
| `maximum_score` | `REAL` | `NOT NULL CHECK (maximum_score >= 0.0 AND maximum_score <= 100.0)` | Batas atas inklusif |
| `letter_grade` | `TEXT` | `NOT NULL` | Simbol huruf (A, AB, B, dll.) |
| `grade_point` | `REAL` | `NOT NULL CHECK (grade_point >= 0.0)` | Bobot mutu (4.00, 3.50, dst.) |

*Konstrain Tambahan:* `CHECK (minimum_score <= maximum_score)`

### 2.4 `academic_terms`
Periode semester akademik.

| Kolom | Tipe Data | Batasan / Konstrain | Keterangan |
| --- | --- | --- | --- |
| `id` | `INTEGER` | `PRIMARY KEY AUTOINCREMENT` | Identifier semester |
| `academic_year` | `TEXT` | `NOT NULL` | Tahun ajaran (mis. `2025/2026`) |
| `semester_name` | `TEXT` | `NOT NULL` | Nama semester (mis. `Semester 4 (Genap)`) |
| `semester_number` | `INTEGER` | `NOT NULL CHECK (semester_number > 0)` | Urutan semester kronologis |
| `start_date` | `TEXT` | `NULLABLE` | Tanggal mulai (ISO-8601) |
| `end_date` | `TEXT` | `NULLABLE` | Tanggal selesai (ISO-8601) |
| `grading_scale_id` | `INTEGER` | `NOT NULL REFERENCES grading_scales(id) ON DELETE RESTRICT` | Skala nilai yang berlaku |
| `is_active` | `INTEGER` | `NOT NULL DEFAULT 0 CHECK (is_active IN (0, 1))` | Penanda semester aktif |
| `created_at` | `TEXT` | `NOT NULL` | Waktu dibuat |
| `updated_at` | `TEXT` | `NOT NULL` | Waktu diperbarui |

### 2.5 `courses`
Mata kuliah yang diambil dalam semester tertentu.

| Kolom | Tipe Data | Batasan / Konstrain | Keterangan |
| --- | --- | --- | --- |
| `id` | `INTEGER` | `PRIMARY KEY AUTOINCREMENT` | Identifier mata kuliah |
| `academic_term_id` | `INTEGER` | `NOT NULL REFERENCES academic_terms(id) ON DELETE CASCADE` | Semester tempat MK diambil |
| `course_code` | `TEXT` | `NOT NULL` | Kode mata kuliah (mis. `IF2401`) |
| `course_name` | `TEXT` | `NOT NULL` | Nama mata kuliah |
| `credits` | `INTEGER` | `NOT NULL CHECK (credits > 0)` | Bobot SKS |
| `lecturer_name` | `TEXT` | `NOT NULL DEFAULT ''` | Nama dosen pengampu |
| `archived_at` | `TEXT` | `NULLABLE` | Penanda waktu arsip (soft-delete/historical) |
| `created_at` | `TEXT` | `NOT NULL` | Waktu dibuat |
| `updated_at` | `TEXT` | `NOT NULL` | Waktu diperbarui |

### 2.6 `class_schedules`
Slot jadwal kelas perkuliahan mingguan.

| Kolom | Tipe Data | Batasan / Konstrain | Keterangan |
| --- | --- | --- | --- |
| `id` | `INTEGER` | `PRIMARY KEY AUTOINCREMENT` | Identifier slot |
| `course_id` | `INTEGER` | `NOT NULL REFERENCES courses(id) ON DELETE CASCADE` | Tautan mata kuliah |
| `weekday` | `INTEGER` | `NOT NULL CHECK (weekday BETWEEN 1 AND 7)` | 1 = Senin, ..., 7 = Minggu |
| `start_time` | `TEXT` | `NOT NULL` | Format jam mulai `HH:mm` |
| `end_time` | `TEXT` | `NOT NULL` | Format jam selesai `HH:mm` |
| `classroom` | `TEXT` | `NOT NULL DEFAULT ''` | Ruang kuliah / lab |
| `created_at` | `TEXT` | `NOT NULL` | Waktu dibuat |
| `updated_at` | `TEXT` | `NOT NULL` | Waktu diperbarui |

### 2.7 `assignments`
Daftar tugas kuliah dan penanda status.

| Kolom | Tipe Data | Batasan / Konstrain | Keterangan |
| --- | --- | --- | --- |
| `id` | `INTEGER` | `PRIMARY KEY AUTOINCREMENT` | Identifier tugas |
| `course_id` | `INTEGER` | `NOT NULL REFERENCES courses(id) ON DELETE CASCADE` | Mata kuliah terkait |
| `title` | `TEXT` | `NOT NULL` | Judul tugas |
| `description` | `TEXT` | `NOT NULL DEFAULT ''` | Deskripsi / catatan pengumpulan |
| `due_at` | `TEXT` | `NOT NULL` | Waktu tenggat (ISO-8601) |
| `priority` | `TEXT` | `NOT NULL CHECK (priority IN ('low', 'medium', 'high'))` | Tingkat prioritas |
| `status` | `TEXT` | `NOT NULL CHECK (status IN ('upcoming', 'overdue', 'completed'))` | Status pengerjaan |
| `completed_at` | `TEXT` | `NULLABLE` | Waktu diselesaikan (ISO-8601) |
| `created_at` | `TEXT` | `NOT NULL` | Waktu dibuat |
| `updated_at` | `TEXT` | `NOT NULL` | Waktu diperbarui |

### 2.8 `assessment_components`
Komponen rencana penilaian untuk setiap mata kuliah.

| Kolom | Tipe Data | Batasan / Konstrain | Keterangan |
| --- | --- | --- | --- |
| `id` | `INTEGER` | `PRIMARY KEY AUTOINCREMENT` | Identifier komponen |
| `course_id` | `INTEGER` | `NOT NULL REFERENCES courses(id) ON DELETE CASCADE` | Mata kuliah terkait |
| `component_name` | `TEXT` | `NOT NULL` | Nama komponen (Tugas, UTS, UAS, dll.) |
| `weight_percentage`| `REAL` | `NOT NULL CHECK (weight_percentage >= 0.0 AND weight_percentage <= 100.0)` | Bobot persen (0..100) |
| `is_required` | `INTEGER` | `NOT NULL DEFAULT 1 CHECK (is_required IN (0, 1))` | 1 = Wajib, 0 = Opsional |
| `sort_order` | `INTEGER` | `NOT NULL DEFAULT 0` | Urutan tampilan |
| `created_at` | `TEXT` | `NOT NULL` | Waktu dibuat |
| `updated_at` | `TEXT` | `NOT NULL` | Waktu diperbarui |

### 2.9 `assessment_scores`
Nilai capaian mahasiswa untuk komponen penilaian tertentu.

| Kolom | Tipe Data | Batasan / Konstrain | Keterangan |
| --- | --- | --- | --- |
| `id` | `INTEGER` | `PRIMARY KEY AUTOINCREMENT` | Identifier nilai |
| `assessment_component_id` | `INTEGER` | `NOT NULL REFERENCES assessment_components(id) ON DELETE CASCADE` | Komponen penilaian |
| `score` | `REAL` | `NOT NULL CHECK (score >= 0.0 AND score <= 100.0)` | Nilai yang diperoleh (0..100) |
| `graded_at` | `TEXT` | `NOT NULL` | Tanggal penilaian diinput |
| `notes` | `TEXT` | `NOT NULL DEFAULT ''` | Catatan opsional dosen/mahasiswa |

### 2.10 `app_preferences`
Penyimpanan pasangan kunci-nilai untuk pengaturan aplikasi (pengingat notifikasi, semester aktif cadangan, dsb.).

| Kolom | Tipe Data | Batasan / Konstrain | Keterangan |
| --- | --- | --- | --- |
| `id` | `INTEGER` | `PRIMARY KEY AUTOINCREMENT` | Identifier preferensi |
| `preference_key` | `TEXT` | `NOT NULL UNIQUE` | Kunci unik pengaturan |
| `preference_value` | `TEXT` | `NOT NULL` | Nilai pengaturan (string/JSON) |
| `updated_at` | `TEXT` | `NOT NULL` | Waktu pembaruan terakhir |

---

## 3. Indeks Performa Query

Untuk menjamin kueri seleksi cepat pada relasi foreign key dan filter berbasis waktu, 13 indeks berikut otomatis dibuat saat skema diinisialisasi:

1. `idx_academic_terms_is_active` ON `academic_terms(is_active)`
2. `idx_academic_terms_grading_scale` ON `academic_terms(grading_scale_id)`
3. `idx_courses_academic_term` ON `courses(academic_term_id)`
4. `idx_courses_archived_at` ON `courses(archived_at)`
5. `idx_class_schedules_course` ON `class_schedules(course_id)`
6. `idx_class_schedules_weekday` ON `class_schedules(weekday)`
7. `idx_assignments_course` ON `assignments(course_id)`
8. `idx_assignments_due_at` ON `assignments(due_at)`
9. `idx_assignments_status` ON `assignments(status)`
10. `idx_assessment_components_course` ON `assessment_components(course_id)`
11. `idx_assessment_scores_component` ON `assessment_scores(assessment_component_id)`
12. `idx_grading_scale_ranges_scale` ON `grading_scale_ranges(grading_scale_id)`
13. `idx_app_preferences_key` ON `app_preferences(preference_key)`

---

## 4. Prinsip Integritas Data & Non-Persistensi IPS/IPK

1. **Foreign Key Enforcement**: Dieksekusi melalui `PRAGMA foreign_keys = ON;` pada callback `onConfigure` di setiap pembukaan koneksi.
2. **IPS dan IPK Tidak Disimpan**: Sesuai prinsip arsitektur, nilai IPS dan IPK adalah hasil turunan agregat matematis dan **tidak disimpan sebagai nilai otoritatif statis** di tabel basis data. Keduanya dihitung secara dinamis dari SKS dan nilai mutu menggunakan `AcademicCalculator`.
3. **Pemisahan Simulasi**: Nilai pada Simulasi Nilai dihitung di memori UI (`GradeSimulatorViewModel`) dan tidak pernah ditulis ke tabel `assessment_scores`.
