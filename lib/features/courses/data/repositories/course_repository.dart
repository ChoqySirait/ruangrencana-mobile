import '../../../../core/utils/academic_calculator.dart';
import '../models/course_item.dart';

/// Kontrak akses data mata kuliah.
///
/// Pada tahap selanjutnya, implementasi [InMemoryCourseRepository] dapat
/// diganti dengan implementasi SQLite (`sqflite`) tanpa mengubah ViewModel.
abstract class CourseRepository {
  List<CourseItem> getActiveCourses();
  CourseItem? getCourseById(String id);
}

/// Implementasi sementara berbasis memori dengan data demonstrasi fiktif.
class InMemoryCourseRepository implements CourseRepository {
  final List<CourseItem> _courses = const [
    CourseItem(
      id: 'mk-mob',
      code: 'IF2401',
      name: 'Pemrograman Mobile',
      sks: 3,
      lecturer: 'Dr. Hendra Wijaya, M.Kom.',
      room: 'Lab Komputasi 2',
      scheduleLabel: 'Senin, 08:00 - 10:30',
      assessmentComponents: [
        AssessmentComponentInput(
          name: 'Tugas & Praktikum',
          weightPercent: 30,
          score: 88,
        ),
        AssessmentComponentInput(name: 'Kuis', weightPercent: 10, score: 84),
        AssessmentComponentInput(name: 'UTS', weightPercent: 25, score: 86),
        AssessmentComponentInput(name: 'Proyek UAS', weightPercent: 35),
      ],
    ),
    CourseItem(
      id: 'mk-bdl',
      code: 'IF2402',
      name: 'Basis Data Lanjut',
      sks: 3,
      lecturer: 'Siti Rahmawati, M.T.',
      room: 'Ruang R-304',
      scheduleLabel: 'Senin, 13:00 - 15:30',
      assessmentComponents: [
        AssessmentComponentInput(
          name: 'Tugas Terstruktur',
          weightPercent: 25,
          score: 82,
        ),
        AssessmentComponentInput(
          name: 'Praktikum SQL',
          weightPercent: 20,
          score: 90,
        ),
        AssessmentComponentInput(name: 'UTS', weightPercent: 25, score: 79),
        AssessmentComponentInput(name: 'UAS', weightPercent: 30),
      ],
    ),
    CourseItem(
      id: 'mk-rpl',
      code: 'IF2403',
      name: 'Rekayasa Perangkat Lunak',
      sks: 3,
      lecturer: 'Budi Santoso, M.Sc.',
      room: 'Ruang R-201',
      scheduleLabel: 'Selasa, 09:30 - 12:00',
      assessmentComponents: [
        AssessmentComponentInput(
          name: 'Studi Kasus',
          weightPercent: 20,
          score: 91,
        ),
        AssessmentComponentInput(
          name: 'Presentasi Desain',
          weightPercent: 20,
          score: 87,
        ),
        AssessmentComponentInput(name: 'UTS', weightPercent: 25, score: 85),
        AssessmentComponentInput(name: 'UAS & Dokumen SRS', weightPercent: 35),
      ],
    ),
    CourseItem(
      id: 'mk-jarkom',
      code: 'IF2404',
      name: 'Jaringan Komputer',
      sks: 3,
      lecturer: 'Arif Nugroho, M.Eng.',
      room: 'Lab Jaringan',
      scheduleLabel: 'Rabu, 08:00 - 10:30',
      assessmentComponents: [
        AssessmentComponentInput(
          name: 'Praktikum Topologi',
          weightPercent: 30,
          score: 80,
        ),
        AssessmentComponentInput(name: 'UTS', weightPercent: 30, score: 76),
        AssessmentComponentInput(name: 'UAS', weightPercent: 40),
      ],
    ),
    CourseItem(
      id: 'mk-imk',
      code: 'IF2405',
      name: 'Interaksi Manusia dan Komputer',
      sks: 3,
      lecturer: 'Dina Kusuma, M.Ds.',
      room: 'Ruang Studio UX',
      scheduleLabel: 'Kamis, 10:00 - 12:30',
      assessmentComponents: [
        AssessmentComponentInput(
          name: 'Evaluasi Heuristik',
          weightPercent: 25,
          score: 92,
        ),
        AssessmentComponentInput(
          name: 'Prototipe Figma',
          weightPercent: 35,
          score: 89,
        ),
        AssessmentComponentInput(name: 'UTS', weightPercent: 20, score: 86),
        AssessmentComponentInput(
          name: 'Uji Kebergunaan Akhir',
          weightPercent: 20,
          score: 90,
        ),
      ],
    ),
    CourseItem(
      id: 'mk-stat',
      code: 'IF2406',
      name: 'Statistika dan Probabilitas',
      sks: 3,
      lecturer: 'Prof. Bambang Suryadi',
      room: 'Ruang R-105',
      scheduleLabel: 'Kamis, 14:00 - 16:30',
      assessmentComponents: [
        AssessmentComponentInput(
          name: 'Latihan Mingguan',
          weightPercent: 20,
          score: 78,
        ),
        AssessmentComponentInput(name: 'UTS', weightPercent: 35, score: 74),
        AssessmentComponentInput(name: 'UAS', weightPercent: 45),
      ],
    ),
    CourseItem(
      id: 'mk-kwu',
      code: 'KU2407',
      name: 'Kewirausahaan Digital',
      sks: 2,
      lecturer: 'Rina Lestari, M.B.A.',
      room: 'Ruang Seminar B',
      scheduleLabel: 'Jumat, 09:00 - 10:40',
      assessmentComponents: [
        AssessmentComponentInput(
          name: 'Pitch Deck',
          weightPercent: 40,
          score: 88,
        ),
        AssessmentComponentInput(
          name: 'Validasi Pasar',
          weightPercent: 30,
          score: 85,
        ),
        AssessmentComponentInput(name: 'Demo Produk Akhir', weightPercent: 30),
      ],
    ),
  ];

  @override
  List<CourseItem> getActiveCourses() => List.unmodifiable(_courses);

  @override
  CourseItem? getCourseById(String id) {
    for (final course in _courses) {
      if (course.id == id) return course;
    }
    return null;
  }
}
