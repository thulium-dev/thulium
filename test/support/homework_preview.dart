import 'package:thulium_campus/thulium_campus.dart';

final previewNow = DateTime.utc(2026, 10, 21, 8);
const previewCourse = LearnCourse(
  id: 'physics',
  name: '大学物理 B（2）',
  englishName: 'University Physics B',
  teacherName: '',
  schedule: '',
);
final previewAssignments = [
  LearnHomework(
    id: 'overdue',
    course: previewCourse,
    title: '第一次作业：力学基础',
    deadline: previewNow.subtract(const Duration(hours: 2)),
  ),
  LearnHomework(
    id: 'urgent',
    course: previewCourse,
    title: '第二次作业：电场与电势',
    deadline: previewNow.add(const Duration(minutes: 35)),
  ),
  LearnHomework(
    id: 'ungraded',
    course: previewCourse,
    title: '课前练习：磁场与电磁感应',
    deadline: previewNow.add(const Duration(days: 2)),
  ),
];
