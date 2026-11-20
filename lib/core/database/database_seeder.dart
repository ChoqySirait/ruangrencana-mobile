import 'package:sqflite/sqflite.dart';

import 'database_schema.dart';

/// Seeder data demonstrasi awal RuangRencana.
///
/// Menerapkan strategi idempotent: memeriksa apakah database sudah pernah diinisialisasi
/// melalui tabel `app_preferences`. Jika sudah pernah, data pengguna tidak akan pernah
/// ditimpa atau diduplikasi. Seluruh data demonstrasi bersifat fiktif dan aman untuk publik.
abstract final class DatabaseSeeder {
  static const String keySeedCompleted = 'initial_seed_completed';

  /// Menjalankan seeding hanya apabila basis data belum pernah diisi sebelumnya.
  static Future<bool> seedIfNeeded(Database db) async {
    final existingPref = await db.query(
      DatabaseSchema.tableAppPreferences,
      where: 'preference_key = ?',
      whereArgs: [keySeedCompleted],
      limit: 1,
    );

    if (existingPref.isNotEmpty &&
        existingPref.first['preference_value'] == 'true') {
      return false; // Sudah pernah di-seed sebelumnya
    }

    await db.transaction((txn) async {
      final now = DateTime.now().toUtc().toIso8601String();

      // 1. Skala Nilai Default (Contoh Skala 4.00 Standar Kampus)
      final scaleId = await txn.insert(DatabaseSchema.tableGradingScales, {
        'scale_name': 'Contoh Skala 4.00 (Dapat Dikonfigurasi)',
        'is_default': 1,
        'created_at': now,
        'updated_at': now,
      });

      final ranges = [
        {'min': 85.0, 'max': 100.0, 'letter': 'A', 'point': 4.00},
        {'min': 80.0, 'max': 84.99, 'letter': 'A-', 'point': 3.70},
        {'min': 75.0, 'max': 79.99, 'letter': 'B+', 'point': 3.30},
        {'min': 70.0, 'max': 74.99, 'letter': 'B', 'point': 3.00},
        {'min': 65.0, 'max': 69.99, 'letter': 'B-', 'point': 2.70},
        {'min': 60.0, 'max': 64.99, 'letter': 'C+', 'point': 2.30},
        {'min': 55.0, 'max': 59.99, 'letter': 'C', 'point': 2.00},
        {'min': 45.0, 'max': 54.99, 'letter': 'D', 'point': 1.00},
        {'min': 0.0, 'max': 44.99, 'letter': 'E', 'point': 0.00},
      ];

      for (final r in ranges) {
        await txn.insert(DatabaseSchema.tableGradingScaleRanges, {
          'grading_scale_id': scaleId,
          'minimum_score': r['min'],
          'maximum_score': r['max'],
          'letter_grade': r['letter'],
          'grade_point': r['point'],
        });
      }

      // 2. Profil Mahasiswa Demonstrasi (Data fiktif konsisten)
      await txn.insert(DatabaseSchema.tableStudentProfiles, {
        'full_name': 'Mahasiswa Demo',
        'student_number': 'DEMO-001',
        'study_program': 'S1 Sistem Informasi',
        'institution_name': 'Universitas Contoh',
        'created_at': now,
        'updated_at': now,
      });

      // Preferensi Notifikasi & Target SKS Murni
      await txn.insert(DatabaseSchema.tableAppPreferences, {
        'preference_key': 'notify_class_reminder',
        'preference_value': 'true',
        'updated_at': now,
      });
      await txn.insert(DatabaseSchema.tableAppPreferences, {
        'preference_key': 'notify_deadline_reminder',
        'preference_value': 'true',
        'updated_at': now,
      });
      await txn.insert(DatabaseSchema.tableAppPreferences, {
        'preference_key': 'notify_weekly_summary',
        'preference_value': 'false',
        'updated_at': now,
      });
      await txn.insert(DatabaseSchema.tableAppPreferences, {
        'preference_key': 'target_graduation_sks',
        'preference_value': '144',
        'updated_at': now,
      });

      // 3. Periode Semester Akademik (3 semester lampau selesai + 1 semester aktif)
      final term1Id = await txn.insert(DatabaseSchema.tableAcademicTerms, {
        'academic_year': '2024/2025',
        'semester_name': 'Semester 1 (Ganjil)',
        'semester_number': 1,
        'start_date': '2024-09-01',
        'end_date': '2025-01-31',
        'grading_scale_id': scaleId,
        'is_active': 0,
        'created_at': now,
        'updated_at': now,
      });
      final term2Id = await txn.insert(DatabaseSchema.tableAcademicTerms, {
        'academic_year': '2024/2025',
        'semester_name': 'Semester 2 (Genap)',
        'semester_number': 2,
        'start_date': '2025-02-01',
        'end_date': '2025-06-30',
        'grading_scale_id': scaleId,
        'is_active': 0,
        'created_at': now,
        'updated_at': now,
      });
      final term3Id = await txn.insert(DatabaseSchema.tableAcademicTerms, {
        'academic_year': '2025/2026',
        'semester_name': 'Semester 3 (Ganjil)',
        'semester_number': 3,
        'start_date': '2025-09-01',
        'end_date': '2026-01-31',
        'grading_scale_id': scaleId,
        'is_active': 0,
        'created_at': now,
        'updated_at': now,
      });

      final activeTermId = await txn.insert(DatabaseSchema.tableAcademicTerms, {
        'academic_year': '2025/2026',
        'semester_name': 'Semester 4 (Genap)',
        'semester_number': 4,
        'start_date': '2026-02-01',
        'end_date': '2026-06-30',
        'grading_scale_id': scaleId,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });

      // Seeding mata kuliah dan nilai untuk semester lampau (otoritas riwayat akademik relasional murni)
      Future<void> seedHistoricalTerm({
        required int termId,
        required List<Map<String, dynamic>> courses,
      }) async {
        for (final c in courses) {
          final courseId = await txn.insert(DatabaseSchema.tableCourses, {
            'academic_term_id': termId,
            'course_code': c['code'],
            'course_name': c['name'],
            'credits': c['sks'],
            'lecturer_name': c['lecturer'],
            'created_at': now,
            'updated_at': now,
          });

          final compId = await txn.insert(
            DatabaseSchema.tableAssessmentComponents,
            {
              'course_id': courseId,
              'component_name': 'Nilai Akhir',
              'weight_percentage': 100.0,
              'is_required': 1,
              'sort_order': 0,
              'created_at': now,
              'updated_at': now,
            },
          );

          await txn.insert(DatabaseSchema.tableAssessmentScores, {
            'assessment_component_id': compId,
            'score': c['score'],
            'graded_at': now,
            'notes': 'Nilai akhir semester selesai',
          });
        }
      }

      await seedHistoricalTerm(
        termId: term1Id,
        courses: [
          {
            'code': 'SI1101',
            'name': 'Dasar Sistem Informasi',
            'sks': 3,
            'lecturer': 'Dr. Hendra Wijaya, M.Kom.',
            'score': 88.0,
          },
          {
            'code': 'SI1102',
            'name': 'Algoritma & Pemrograman',
            'sks': 4,
            'lecturer': 'Siti Rahmawati, M.T.',
            'score': 82.0,
          },
          {
            'code': 'MA1101',
            'name': 'Matematika Diskrit',
            'sks': 3,
            'lecturer': 'Dr. Agus Pratama, M.Sc.',
            'score': 86.0,
          },
          {
            'code': 'SI1103',
            'name': 'Pengantar Bisnis & Manajemen',
            'sks': 3,
            'lecturer': 'Rina Marlina, S.E., M.M.',
            'score': 78.0,
          },
          {
            'code': 'KU1101',
            'name': 'Bahasa Indonesia',
            'sks': 2,
            'lecturer': 'Dewi Lestari, M.Pd.',
            'score': 85.0,
          },
          {
            'code': 'KU1102',
            'name': 'Bahasa Inggris',
            'sks': 2,
            'lecturer': 'Robertus Budi, M.Hum.',
            'score': 82.0,
          },
          {
            'code': 'KU1103',
            'name': 'Pendidikan Agama',
            'sks': 2,
            'lecturer': 'H. Ahmad Fauzi, M.Ag.',
            'score': 80.0,
          },
        ],
      );

      await seedHistoricalTerm(
        termId: term2Id,
        courses: [
          {
            'code': 'SI1201',
            'name': 'Struktur Data & Algoritma',
            'sks': 4,
            'lecturer': 'Dr. Hendra Wijaya, M.Kom.',
            'score': 86.0,
          },
          {
            'code': 'SI1202',
            'name': 'Basis Data Dasar',
            'sks': 4,
            'lecturer': 'Siti Rahmawati, M.T.',
            'score': 83.0,
          },
          {
            'code': 'SI1203',
            'name': 'Sistem Informasi Manajemen',
            'sks': 3,
            'lecturer': 'Rina Marlina, S.E., M.M.',
            'score': 88.0,
          },
          {
            'code': 'MA1201',
            'name': 'Aljabar Linear',
            'sks': 3,
            'lecturer': 'Dr. Agus Pratama, M.Sc.',
            'score': 77.0,
          },
          {
            'code': 'MA1202',
            'name': 'Statistika Terapan',
            'sks': 3,
            'lecturer': 'Dr. Joko Susilo, M.Stat.',
            'score': 81.0,
          },
          {
            'code': 'KU1201',
            'name': 'Pendidikan Kewarganegaraan',
            'sks': 2,
            'lecturer': 'Dewi Lestari, M.Pd.',
            'score': 85.0,
          },
          {
            'code': 'KU1202',
            'name': 'Komunikasi Interpersonal',
            'sks': 2,
            'lecturer': 'Robertus Budi, M.Hum.',
            'score': 82.0,
          },
        ],
      );

      await seedHistoricalTerm(
        termId: term3Id,
        courses: [
          {
            'code': 'SI2301',
            'name': 'Pemrograman Berorientasi Objek',
            'sks': 4,
            'lecturer': 'Dr. Hendra Wijaya, M.Kom.',
            'score': 87.0,
          },
          {
            'code': 'SI2302',
            'name': 'Analisis & Perancangan SI',
            'sks': 4,
            'lecturer': 'Rina Marlina, S.E., M.M.',
            'score': 86.0,
          },
          {
            'code': 'SI2303',
            'name': 'Basis Data Lanjutan',
            'sks': 3,
            'lecturer': 'Siti Rahmawati, M.T.',
            'score': 82.0,
          },
          {
            'code': 'SI2304',
            'name': 'Jaringan Komputer',
            'sks': 3,
            'lecturer': 'Ir. Bambang Tri, M.T.',
            'score': 78.0,
          },
          {
            'code': 'SI2305',
            'name': 'Arsitektur Perusahaan',
            'sks': 2,
            'lecturer': 'Dr. Agus Pratama, M.Sc.',
            'score': 85.0,
          },
          {
            'code': 'KU2301',
            'name': 'Etika Profesi Sistem Informasi',
            'sks': 2,
            'lecturer': 'Dewi Lestari, M.Pd.',
            'score': 84.0,
          },
          {
            'code': 'KU2302',
            'name': 'Technopreneurship',
            'sks': 2,
            'lecturer': 'H. Ahmad Fauzi, M.Ag.',
            'score': 82.0,
          },
        ],
      );

      // 4. Mata Kuliah Semester 4
      final coursesData = [
        {
          'code': 'IF2401',
          'name': 'Pemrograman Mobile',
          'sks': 3,
          'lecturer': 'Dr. Hendra Wijaya, M.Kom.',
          'weekday': 1,
          'start': '08:00',
          'end': '10:30',
          'room': 'Lab Komputasi 2',
          'components': [
            {
              'name': 'Tugas & Praktikum',
              'weight': 30.0,
              'req': 1,
              'score': 88.0,
            },
            {'name': 'Kuis', 'weight': 10.0, 'req': 1, 'score': 84.0},
            {'name': 'UTS', 'weight': 25.0, 'req': 1, 'score': 86.0},
            {'name': 'Proyek UAS', 'weight': 35.0, 'req': 1, 'score': null},
          ],
        },
        {
          'code': 'IF2402',
          'name': 'Basis Data Lanjut',
          'sks': 3,
          'lecturer': 'Siti Rahmawati, M.T.',
          'weekday': 1,
          'start': '13:00',
          'end': '15:30',
          'room': 'Ruang R-304',
          'components': [
            {
              'name': 'Tugas Terstruktur',
              'weight': 25.0,
              'req': 1,
              'score': 82.0,
            },
            {'name': 'Praktikum SQL', 'weight': 20.0, 'req': 1, 'score': 90.0},
            {'name': 'UTS', 'weight': 25.0, 'req': 1, 'score': 79.0},
            {'name': 'UAS', 'weight': 30.0, 'req': 1, 'score': null},
          ],
        },
        {
          'code': 'IF2403',
          'name': 'Rekayasa Perangkat Lunak',
          'sks': 3,
          'lecturer': 'Budi Santoso, M.Sc.',
          'weekday': 2,
          'start': '09:30',
          'end': '12:00',
          'room': 'Ruang R-201',
          'components': [
            {'name': 'Studi Kasus', 'weight': 20.0, 'req': 1, 'score': 91.0},
            {
              'name': 'Presentasi Desain',
              'weight': 20.0,
              'req': 1,
              'score': 87.0,
            },
            {'name': 'UTS', 'weight': 25.0, 'req': 1, 'score': 85.0},
            {
              'name': 'UAS & Dokumen SRS',
              'weight': 35.0,
              'req': 1,
              'score': null,
            },
          ],
        },
        {
          'code': 'IF2404',
          'name': 'Jaringan Komputer',
          'sks': 3,
          'lecturer': 'Arif Nugroho, M.Eng.',
          'weekday': 3,
          'start': '08:00',
          'end': '10:30',
          'room': 'Lab Jaringan',
          'components': [
            {
              'name': 'Praktikum Topologi',
              'weight': 30.0,
              'req': 1,
              'score': 80.0,
            },
            {'name': 'UTS', 'weight': 30.0, 'req': 1, 'score': 76.0},
            {'name': 'UAS', 'weight': 40.0, 'req': 1, 'score': null},
          ],
        },
        {
          'code': 'IF2405',
          'name': 'Interaksi Manusia dan Komputer',
          'sks': 3,
          'lecturer': 'Dina Kusuma, M.Ds.',
          'weekday': 4,
          'start': '10:00',
          'end': '12:30',
          'room': 'Ruang Studio UX',
          'components': [
            {
              'name': 'Evaluasi Heuristik',
              'weight': 25.0,
              'req': 1,
              'score': 92.0,
            },
            {
              'name': 'Prototipe Figma',
              'weight': 35.0,
              'req': 1,
              'score': 89.0,
            },
            {'name': 'UTS', 'weight': 20.0, 'req': 1, 'score': 86.0},
            {
              'name': 'Uji Kebergunaan Akhir',
              'weight': 20.0,
              'req': 1,
              'score': 90.0,
            },
          ],
        },
        {
          'code': 'IF2406',
          'name': 'Statistika dan Probabilitas',
          'sks': 3,
          'lecturer': 'Prof. Bambang Suryadi',
          'weekday': 4,
          'start': '14:00',
          'end': '16:30',
          'room': 'Ruang R-105',
          'components': [
            {
              'name': 'Latihan Mingguan',
              'weight': 20.0,
              'req': 1,
              'score': 78.0,
            },
            {'name': 'UTS', 'weight': 35.0, 'req': 1, 'score': 74.0},
            {'name': 'UAS', 'weight': 45.0, 'req': 1, 'score': null},
          ],
        },
        {
          'code': 'KU2407',
          'name': 'Kewirausahaan Digital',
          'sks': 2,
          'lecturer': 'Rina Lestari, M.B.A.',
          'weekday': 5,
          'start': '09:00',
          'end': '10:40',
          'room': 'Ruang Seminar B',
          'components': [
            {'name': 'Pitch Deck', 'weight': 40.0, 'req': 1, 'score': 88.0},
            {'name': 'Validasi Pasar', 'weight': 30.0, 'req': 1, 'score': 85.0},
            {
              'name': 'Demo Produk Akhir',
              'weight': 30.0,
              'req': 1,
              'score': null,
            },
          ],
        },
      ];

      final courseIdMap = <String, int>{};

      for (final c in coursesData) {
        final courseId = await txn.insert(DatabaseSchema.tableCourses, {
          'academic_term_id': activeTermId,
          'course_code': c['code'],
          'course_name': c['name'],
          'credits': c['sks'],
          'lecturer_name': c['lecturer'],
          'created_at': now,
          'updated_at': now,
        });

        courseIdMap[c['code'] as String] = courseId;

        // Jadwal Kuliah
        await txn.insert(DatabaseSchema.tableClassSchedules, {
          'course_id': courseId,
          'weekday': c['weekday'],
          'start_time': c['start'],
          'end_time': c['end'],
          'classroom': c['room'],
          'created_at': now,
          'updated_at': now,
        });

        // Komponen Penilaian & Skor
        final comps = c['components'] as List<Map<String, dynamic>>;
        var sortOrder = 1;
        for (final comp in comps) {
          final compId = await txn.insert(
            DatabaseSchema.tableAssessmentComponents,
            {
              'course_id': courseId,
              'component_name': comp['name'],
              'weight_percentage': comp['weight'],
              'is_required': comp['req'],
              'sort_order': sortOrder++,
              'created_at': now,
              'updated_at': now,
            },
          );

          if (comp['score'] != null) {
            await txn.insert(DatabaseSchema.tableAssessmentScores, {
              'assessment_component_id': compId,
              'score': (comp['score'] as num).toDouble(),
              'graded_at': now,
              'notes': 'Penilaian awal semester',
            });
          }
        }
      }

      // 5. Tugas Kuliah Awal
      final today = DateTime.now();
      final baseDate = DateTime(today.year, today.month, today.day, 23, 59);

      final assignmentsData = [
        {
          'courseCode': 'IF2401',
          'title': 'Implementasi Navigasi & State Provider',
          'description':
              'Pastikan struktur MVVM bersih dan lolos flutter analyze.',
          'due': baseDate.add(const Duration(days: 1)),
          'priority': 'high',
          'status': 'upcoming',
          'completed_at': null,
        },
        {
          'courseCode': 'IF2402',
          'title': 'Optimasi Query Indeks & Normalisasi BCNF',
          'description':
              'Lampirkan hasil EXPLAIN QUERY PLAN sebelum dan sesudah indeks.',
          'due': baseDate.subtract(const Duration(days: 1)),
          'priority': 'high',
          'status': 'overdue',
          'completed_at': null,
        },
        {
          'courseCode': 'IF2403',
          'title': 'Review Dokumen SRS & Use Case Diagram',
          'description':
              'Fokus pada spesifikasi kebutuhan fungsional dan non-fungsional.',
          'due': baseDate.add(const Duration(days: 3)),
          'priority': 'medium',
          'status': 'upcoming',
          'completed_at': null,
        },
        {
          'courseCode': 'IF2404',
          'title': 'Simulasi Subnetting & Routing Statis',
          'description': 'Kumpulkan berkas topologi dan tabel routing.',
          'due': baseDate.add(const Duration(days: 5)),
          'priority': 'medium',
          'status': 'upcoming',
          'completed_at': null,
        },
        {
          'courseCode': 'IF2405',
          'title': 'Laporan Evaluasi Heuristik Antarmuka',
          'description': 'Sudah dikumpulkan melalui portal akademik.',
          'due': baseDate.subtract(const Duration(days: 3)),
          'priority': 'low',
          'status': 'completed',
          'completed_at': baseDate
              .subtract(const Duration(days: 3))
              .toIso8601String(),
        },
        {
          'courseCode': 'IF2406',
          'title': 'Analisis Distribusi Normal & Uji Hipotesis',
          'description':
              'Kerjakan soal nomor 1 sampai 5 dengan langkah perhitungan.',
          'due': baseDate.add(const Duration(days: 7)),
          'priority': 'low',
          'status': 'upcoming',
          'completed_at': null,
        },
      ];

      for (final a in assignmentsData) {
        final cCode = a['courseCode'] as String;
        final cId = courseIdMap[cCode] ?? activeTermId;
        await txn.insert(DatabaseSchema.tableAssignments, {
          'course_id': cId,
          'title': a['title'],
          'description': a['description'],
          'due_at': (a['due'] as DateTime).toIso8601String(),
          'priority': a['priority'],
          'status': a['status'],
          'completed_at': a['completed_at'],
          'created_at': now,
          'updated_at': now,
        });
      }

      // Tandai seed sudah selesai
      await txn.insert(DatabaseSchema.tableAppPreferences, {
        'preference_key': keySeedCompleted,
        'preference_value': 'true',
        'updated_at': now,
      });
    });

    return true;
  }
}
