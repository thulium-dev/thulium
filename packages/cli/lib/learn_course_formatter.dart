import 'dart:convert';

/// Formats the useful, understood fields of a Learn course list as YAML.
///
/// The service keeps the complete provider response. This CLI view deliberately
/// omits undocumented counters rather than guessing what their abbreviations
/// mean. JSON-quoted strings are also valid YAML double-quoted scalars, so
/// names containing colons, quotes, or newlines remain safe to print.
String formatLearnCourses(
  Map<String, dynamic> response, {
  required String semester,
}) {
  final rows = response['resultList'];
  if (rows is! List || rows.any((row) => row is! Map)) {
    throw const FormatException('The course list is not a list of courses.');
  }

  final output = StringBuffer();
  _writeField(output, 'studentId', response['currentUser']);
  _writeField(output, 'semester', semester);
  if (rows.isEmpty) return '${output}courses: []';

  output.writeln('courses:');
  for (final row in rows.cast<Map>()) {
    final fields = StringBuffer();
    _writeField(fields, 'courseId', row['wlkcid']);
    _writeField(fields, 'courseCode', row['kch']);
    _writeField(fields, 'sectionNumber', row['kxh'] ?? row['kxhnumber']);
    _writeField(fields, 'name', row['kcm'] ?? row['zywkcm']);
    if (row['zywkcm'] != row['kcm']) {
      _writeField(fields, 'chineseName', row['zywkcm']);
    }
    _writeField(fields, 'englishName', row['ywkcm']);
    _writeField(fields, 'teacherName', row['jsm']);
    _writeField(fields, 'teacherId', row['jsh']);
    _writeField(fields, 'schedule', row['sjddb']);
    _writeField(fields, 'startTime', row['kssj']);
    _writeField(fields, 'endTime', row['jssj']);
    _writeField(fields, 'credits', row['xf']);
    _writeField(fields, 'hours', row['xs']);
    _writeField(fields, 'lectureHours', row['lls']);
    _writeField(fields, 'studentCount', row['xss']);
    _writeField(fields, 'boundStudentCount', row['xsbds']);
    _writeField(fields, 'electiveStudentCount', row['xzxss']);
    _writeField(fields, 'withdrawnStudentCount', row['tkxss']);
    _writeField(fields, 'teachingClassPeriodCount', row['jxbjs']);
    _writeField(fields, 'coursePeriodCount', row['jxkjs']);
    _writeField(fields, 'teachingMethod', row['jxfs']);
    _writeField(fields, 'courseType', row['kclx']);
    _writeField(fields, 'examMethod', row['ksfs']);
    _writeField(fields, 'referenceBooks', row['cks']);
    _writeField(fields, 'courseContent', row['kcnr']);
    _writeField(fields, 'remark', row['bz']);
    _writeField(fields, 'notes', row['bznr']);
    _writeField(fields, 'lastUpdated', row['czsj']);

    final lines = fields.toString().trimRight().split('\n');
    if (lines.length == 1 && lines.single.isEmpty) {
      output.writeln('  - {}');
      continue;
    }
    for (var index = 0; index < lines.length; index++) {
      output.writeln('${index == 0 ? '  - ' : '    '}${lines[index]}');
    }
  }
  return output.toString().trimRight();
}

void _writeField(StringBuffer output, String name, Object? value) {
  if (value == null || value == '') return;
  if (value is String) {
    output.writeln('$name: ${jsonEncode(value)}');
  } else if (value is num || value is bool) {
    output.writeln('$name: $value');
  }
}
