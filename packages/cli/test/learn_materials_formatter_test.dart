import 'package:test/test.dart';
import 'package:thulium_campus/thulium_campus.dart';
import 'package:thulium_cli/learn_materials_formatter.dart';

void main() {
  test('prints YAML-safe metadata, UTC times and honest bounded counts', () {
    final material = LearnMaterial.fromResponse({
      'kjxxid': 'material-1',
      'wlkcid': 'course-1',
      'bt': 'ATP: "synthase"\nPaper',
      'wjid': 'file&1',
      'wjlx': 'pdf',
      'wjdx': 2855509,
      'fileSize': '2.0M',
      'scsj': '2026-10-20 15:12',
      'isNew': 1,
      'llcs': 0,
      'sfqd': 0,
    });
    final output = formatLearnMaterials(
      [
        LearnCourseMaterials(
          course: _course,
          materials: [material],
          requestedLimit: 1,
        ),
      ],
      studentId: 'student',
      semester: '2026-2027-1',
    );
    expect(
      output,
      startsWith('studentId: "student"\nsemester: "2026-2027-1"\ncourses:'),
    );
    expect(output, contains('title: "ATP: \\"synthase\\"\\nPaper"'));
    expect(output, contains('fileId: "file&1"'));
    expect(
      output,
      contains(
        'requestedLimit: 1\n    returnedCount: 1\n    mayBeTruncated: true',
      ),
    );
    expect(output, contains('sizeBytes: 2855509'));
    expect(output, contains('uploadedAt: "2026-10-20T07:12:00.000Z"'));
    expect(output, contains('isNew: true'));
    expect(output, contains('viewCount: 0'));
    expect(output, isNot(contains('availableAt:')));
    expect(output, isNot(contains('sfqd:')));
    expect(output, isNot(contains('important:')));
    expect(output, isNot(contains('total:')));
  });

  test('empty courses and semesters remain valid YAML collections', () {
    final empty = formatLearnMaterials(
      [],
      studentId: 'student',
      semester: '2026-2027-1',
    );
    expect(empty, endsWith('courses: []'));
    final output = formatLearnMaterials(
      [
        LearnCourseMaterials(
          course: _course,
          materials: [],
          requestedLimit: 200,
        ),
      ],
      studentId: 'student',
      semester: '2026-2027-1',
    );
    expect(
      output,
      contains(
        'returnedCount: 0\n    mayBeTruncated: false\n    materials: []',
      ),
    );
  });
}

const _course = LearnCourse(
  id: 'course-1',
  name: '生物化学',
  englishName: 'Biochemistry',
  teacherName: '',
  schedule: '',
);
