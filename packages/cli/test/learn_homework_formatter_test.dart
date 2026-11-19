import 'package:test/test.dart';
import 'package:thulium_campus/thulium_campus.dart';
import 'package:thulium_cli/learn_homework_formatter.dart';

void main() {
  test('prints course counts and matching aggregate totals as YAML', () {
    final output = formatLearnHomework(
      const [
        LearnCourseHomework(
          course: LearnCourse(
            id: 'course-1',
            name: 'Physics: "B"\nPart 2',
            englishName: 'Physics B',
            teacherName: '',
            schedule: '',
          ),
          counts: LearnHomeworkCounts(
            unsubmitted: 12,
            submittedUngraded: 3,
            graded: 8,
          ),
        ),
        LearnCourseHomework(
          course: LearnCourse(
            id: 'course-2',
            name: 'Empty',
            englishName: '',
            teacherName: '',
            schedule: '',
          ),
          counts: LearnHomeworkCounts(
            unsubmitted: 0,
            submittedUngraded: 0,
            graded: 0,
          ),
        ),
      ],
      studentId: 'test-student',
      semester: '2026-2027-1',
    );
    expect(
      output,
      startsWith(
        'studentId: "test-student"\nsemester: "2026-2027-1"\ntotals:\n  unsubmitted: 12\n  submittedUngraded: 3\n  graded: 8\n  total: 23',
      ),
    );
    expect(output, contains('name: "Physics: \\"B\\"\\nPart 2"'));
    expect(output, contains('    homework:\n      unsubmitted: 12'));
    expect(output, contains('    homework:\n      unsubmitted: 0'));
  });

  test('an empty semester still reports zero totals', () {
    final output = formatLearnHomework(
      [],
      studentId: 'test-student',
      semester: '2026-2027-1',
    );
    expect(output, contains('  total: 0'));
    expect(output, endsWith('courses: []'));
  });
}
