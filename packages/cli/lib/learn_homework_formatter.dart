import 'dart:convert';

import 'package:thulium_campus/thulium_campus.dart';

/// Emits numeric homework totals and YAML-safe quoted course names.
String formatLearnHomework(
  List<LearnCourseHomework> courses, {
  required String studentId,
  required String semester,
}) {
  final totals = LearnHomeworkCounts(
    unsubmitted: courses.fold(0, (sum, row) => sum + row.counts.unsubmitted),
    submittedUngraded: courses.fold(
      0,
      (sum, row) => sum + row.counts.submittedUngraded,
    ),
    graded: courses.fold(0, (sum, row) => sum + row.counts.graded),
  );
  final output = StringBuffer()
    ..writeln('studentId: ${jsonEncode(studentId)}')
    ..writeln('semester: ${jsonEncode(semester)}')
    ..writeln('totals:');
  _writeCounts(output, totals, '  ');
  if (courses.isEmpty) {
    output.writeln('courses: []');
  } else {
    output.writeln('courses:');
    for (final row in courses) {
      output
        ..writeln('  - courseId: ${jsonEncode(row.course.id)}')
        ..writeln('    name: ${jsonEncode(row.course.name)}');
      if (row.course.englishName.isNotEmpty) {
        output.writeln(
          '    englishName: ${jsonEncode(row.course.englishName)}',
        );
      }
      output.writeln('    homework:');
      _writeCounts(output, row.counts, '      ');
    }
  }
  return output.toString().trimRight();
}

void _writeCounts(
  StringBuffer output,
  LearnHomeworkCounts counts,
  String indent,
) {
  output
    ..writeln('${indent}unsubmitted: ${counts.unsubmitted}')
    ..writeln('${indent}submittedUngraded: ${counts.submittedUngraded}')
    ..writeln('${indent}graded: ${counts.graded}')
    ..writeln('${indent}total: ${counts.total}');
}
