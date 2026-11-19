import '../models/schedule_item.dart';

/// Kontrak akses data jadwal kuliah mingguan.
abstract class ScheduleRepository {
  List<ScheduleItem> getAllSchedules();
  List<ScheduleItem> getSchedulesForDay(int dayOfWeek);
}

/// Implementasi jadwal perkuliahan fiktif berbasis memori.
class InMemoryScheduleRepository implements ScheduleRepository {
  final List<ScheduleItem> _schedules = const [
    ScheduleItem(
      id: 'sch-1',
      courseId: 'mk-mob',
      courseCode: 'IF2401',
      courseName: 'Pemrograman Mobile',
      dayOfWeek: 1,
      startTime: '08:00',
      endTime: '10:30',
      room: 'Lab Komputasi 2',
      sks: 3,
      lecturer: 'Dr. Hendra Wijaya, M.Kom.',
    ),
    ScheduleItem(
      id: 'sch-2',
      courseId: 'mk-bdl',
      courseCode: 'IF2402',
      courseName: 'Basis Data Lanjut',
      dayOfWeek: 1,
      startTime: '13:00',
      endTime: '15:30',
      room: 'Ruang R-304',
      sks: 3,
      lecturer: 'Siti Rahmawati, M.T.',
    ),
    ScheduleItem(
      id: 'sch-3',
      courseId: 'mk-rpl',
      courseCode: 'IF2403',
      courseName: 'Rekayasa Perangkat Lunak',
      dayOfWeek: 2,
      startTime: '09:30',
      endTime: '12:00',
      room: 'Ruang R-201',
      sks: 3,
      lecturer: 'Budi Santoso, M.Sc.',
    ),
    ScheduleItem(
      id: 'sch-4',
      courseId: 'mk-jarkom',
      courseCode: 'IF2404',
      courseName: 'Jaringan Komputer',
      dayOfWeek: 3,
      startTime: '08:00',
      endTime: '10:30',
      room: 'Lab Jaringan',
      sks: 3,
      lecturer: 'Arif Nugroho, M.Eng.',
    ),
    ScheduleItem(
      id: 'sch-5',
      courseId: 'mk-imk',
      courseCode: 'IF2405',
      courseName: 'Interaksi Manusia dan Komputer',
      dayOfWeek: 4,
      startTime: '10:00',
      endTime: '12:30',
      room: 'Ruang Studio UX',
      sks: 3,
      lecturer: 'Dina Kusuma, M.Ds.',
    ),
    ScheduleItem(
      id: 'sch-6',
      courseId: 'mk-stat',
      courseCode: 'IF2406',
      courseName: 'Statistika dan Probabilitas',
      dayOfWeek: 4,
      startTime: '14:00',
      endTime: '16:30',
      room: 'Ruang R-105',
      sks: 3,
      lecturer: 'Prof. Bambang Suryadi',
    ),
    ScheduleItem(
      id: 'sch-7',
      courseId: 'mk-kwu',
      courseCode: 'KU2407',
      courseName: 'Kewirausahaan Digital',
      dayOfWeek: 5,
      startTime: '09:00',
      endTime: '10:40',
      room: 'Ruang Seminar B',
      sks: 2,
      lecturer: 'Rina Lestari, M.B.A.',
    ),
  ];

  @override
  List<ScheduleItem> getAllSchedules() => List.unmodifiable(_schedules);

  @override
  List<ScheduleItem> getSchedulesForDay(int dayOfWeek) {
    return _schedules
        .where((item) => item.dayOfWeek == dayOfWeek)
        .toList(growable: false);
  }
}
