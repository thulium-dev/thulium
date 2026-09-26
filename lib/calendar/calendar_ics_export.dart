import 'dart:convert';

import 'package:thulium_campus/thulium_campus.dart';

/// Creates a portable iCalendar snapshot from the selected dated occurrences.
String buildCalendarIcs(
  Iterable<CalendarPlanEntry> entries, {
  required String Function(String category) categoryName,
  DateTime? generatedAt,
}) {
  final timestamp = _icsDateTime((generatedAt ?? DateTime.now()).toUtc());
  final sorted = entries.toList()
    ..sort((a, b) => a.occurrence.startsAt.compareTo(b.occurrence.startsAt));
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Thulium//Calendar Export//EN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'X-WR-CALNAME:Thulium',
  ];

  for (final entry in sorted) {
    final occurrence = entry.occurrence;
    lines.addAll([
      'BEGIN:VEVENT',
      'UID:${_uid(entry)}',
      'DTSTAMP:$timestamp',
      'DTSTART:${_icsDateTime(occurrence.startsAt.toUtc())}',
      'DTEND:${_icsDateTime(occurrence.endsAt.toUtc())}',
      'SUMMARY:${_escapeText(occurrence.name)}',
      if (occurrence.location.isNotEmpty)
        'LOCATION:${_escapeText(occurrence.location)}',
      'CATEGORIES:${_escapeText(categoryName(occurrence.category))}',
      'END:VEVENT',
    ]);
  }
  lines.add('END:VCALENDAR');
  return '${lines.map(_foldLine).join('\r\n')}\r\n';
}

String _icsDateTime(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}'
    '${value.month.toString().padLeft(2, '0')}'
    '${value.day.toString().padLeft(2, '0')}T'
    '${value.hour.toString().padLeft(2, '0')}'
    '${value.minute.toString().padLeft(2, '0')}'
    '${value.second.toString().padLeft(2, '0')}Z';

String _escapeText(String value) => value
    .replaceAll('\\', '\\\\')
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .replaceAll('\n', r'\n')
    .replaceAll(',', r'\,')
    .replaceAll(';', r'\;');

String _foldLine(String line) {
  final output = StringBuffer();
  var column = 0;
  for (final rune in line.runes) {
    final character = String.fromCharCode(rune);
    final byteLength = utf8.encode(character).length;
    if (column + byteLength > 75) {
      output.write('\r\n ');
      column = 1;
    }
    output.write(character);
    column += byteLength;
  }
  return output.toString();
}

String _uid(CalendarPlanEntry entry) {
  final occurrence = entry.occurrence;
  final key =
      '${entry.sourceId}|${entry.originalStartsAt.toUtc().toIso8601String()}|'
      '${occurrence.startsAt.toUtc().toIso8601String()}|'
      '${occurrence.endsAt.toUtc().toIso8601String()}';
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(key)) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  return '${hash.toRadixString(16).padLeft(8, '0')}@thulium.app';
}
