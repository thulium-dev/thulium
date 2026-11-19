import 'dart:convert';

import 'package:thulium_campus/thulium_campus.dart';

/// Quotes provider text as YAML-safe JSON strings; never includes credentials.
String formatLearnMaterials(
  List<LearnCourseMaterials> courses, {
  required String studentId,
  required String semester,
}) {
  final output = StringBuffer()
    ..writeln('studentId: ${jsonEncode(studentId)}')
    ..writeln('semester: ${jsonEncode(semester)}');
  if (courses.isEmpty) return '${output}courses: []';
  output.writeln('courses:');
  for (final row in courses) {
    output
      ..writeln('  - courseId: ${jsonEncode(row.course.id)}')
      ..writeln('    name: ${jsonEncode(row.course.name)}');
    if (row.course.englishName.isNotEmpty) {
      output.writeln('    englishName: ${jsonEncode(row.course.englishName)}');
    }
    output
      ..writeln('    requestedLimit: ${row.requestedLimit}')
      ..writeln('    returnedCount: ${row.materials.length}')
      ..writeln('    mayBeTruncated: ${row.mayBeTruncated}');
    if (row.materials.isEmpty) {
      output.writeln('    materials: []');
      continue;
    }
    output.writeln('    materials:');
    for (final item in row.materials) {
      output
        ..writeln('      - materialId: ${jsonEncode(item.id)}')
        ..writeln('        title: ${jsonEncode(item.title)}')
        ..writeln('        fileId: ${jsonEncode(item.fileId)}');
      final fields = <String, Object?>{
        'fileType': item.fileType,
        'sizeBytes': item.sizeBytes,
        'displaySize': item.displaySize,
        'uploadedAt': item.uploadedAt?.toIso8601String(),
        'availableAt': item.availableAt?.toIso8601String(),
        'isNew': item.isNew,
        'description': item.description,
        'categoryId': item.categoryId,
        'viewCount': item.viewCount,
        'downloadCount': item.downloadCount,
      };
      for (final field in fields.entries) {
        final value = field.value;
        if (value == null || value == '') continue;
        output.writeln(
          '        ${field.key}: ${value is String ? jsonEncode(value) : value}',
        );
      }
    }
  }
  return output.toString().trimRight();
}
