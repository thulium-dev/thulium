import 'package:test/test.dart';
import 'package:thulium_cli/learn_course_formatter.dart';

void main() {
  test('prints meaningful English keys and omits unknown counters', () {
    final output = formatLearnCourses({
      'currentUser': '2022012050',
      'resultList': [
        {
          'wlkcid': '2026-2027-1152224984',
          'kch': '00000042',
          'kxh': 90,
          'kcm': 'New Cities',
          'ywkcm': 'A New Science of Cities',
          'jsm': 'Teacher',
          'sjddb': 'Week 1-16, Thursday',
          'xss': 25,
          'xsbds': 22,
          'lls': 20,
          'wpgs': 0,
          'xf': null,
        },
      ],
    }, semester: '2026-2027-1');

    expect(output, contains('studentId: "2022012050"'));
    expect(output, contains('semester: "2026-2027-1"'));
    expect(output, contains('  - courseId: "2026-2027-1152224984"'));
    expect(output, contains('    sectionNumber: 90'));
    expect(output, contains('    studentCount: 25'));
    expect(output, contains('    boundStudentCount: 22'));
    expect(output, contains('    lectureHours: 20'));
    expect(output, isNot(contains('wpgs')));
    expect(output, isNot(contains('credits:')));
  });

  test('quotes punctuation and newlines in provider strings', () {
    final output = formatLearnCourses({
      'resultList': [
        {'kcm': 'A: "B"\nC'},
      ],
    }, semester: '2026-2027-1');

    expect(output, contains('name: "A: \\"B\\"\\nC"'));
  });

  test('prints an empty course list as a YAML sequence', () {
    expect(
      formatLearnCourses({'resultList': []}, semester: '2026-2027-1'),
      'semester: "2026-2027-1"\ncourses: []',
    );
  });
}
