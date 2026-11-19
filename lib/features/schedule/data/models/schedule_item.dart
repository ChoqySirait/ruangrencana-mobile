/// Model satu sesi jadwal perkuliahan mingguan.
class ScheduleItem {
  const ScheduleItem({
    required this.id,
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.room,
    required this.sks,
    required this.lecturer,
  });

  final String id;
  final String courseId;
  final String courseCode;
  final String courseName;

  /// Hari kuliah: 1 = Senin, 2 = Selasa, ..., 6 = Sabtu.
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final String room;
  final int sks;
  final String lecturer;

  String get timeRange => '$startTime - $endTime';
}
