import 'dart:ui' as ui;

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thulium/calendar/calendar_export_labels.dart';
import 'package:thulium/calendar/calendar_visual_export.dart';
import 'package:thulium/calendar/calendar_xlsx_export.dart';
import 'package:thulium_campus/thulium_campus.dart';

void main() {
  test('XLSX retains Unicode text and typed date/time values', () {
    final bytes = buildCalendarXlsx(
      [_entry],
      labels: _labels,
      categoryName: (_) => 'Lesson',
    );
    expect(bytes.sublist(0, 2), [0x50, 0x4b]);

    final workbook = Excel.decodeBytes(bytes);
    final sheet = workbook['Events'];
    expect((sheet.rows[0][3]?.value as TextCellValue).value.toString(), 'Name');
    expect((sheet.rows[1][0]?.value as DateCellValue).year, 2026);
    expect((sheet.rows[1][1]?.value as TimeCellValue).hour, 9);
    expect((sheet.rows[1][3]?.value as TextCellValue).value.toString(), '大学物理');
    expect((sheet.rows[1][4]?.value as TextCellValue).value.toString(), '六教');
  });

  testWidgets('PNG renders the event list with real image bytes', (
    tester,
  ) async {
    final bytes = await tester.runAsync(
      () => buildCalendarPng(
        [_entry],
        labels: _labels,
        subtitle: 'Current week',
        categoryName: (_) => 'Lesson',
      ),
    );
    expect(bytes, isNotNull);
    expect(bytes!.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final codec = await tester.runAsync(() => ui.instantiateImageCodec(bytes));
    expect(codec, isNotNull);
    final frame = await tester.runAsync(() => codec!.getNextFrame());
    expect(frame, isNotNull);
    expect(frame!.image.width, 1120);
    expect(frame.image.height, greaterThan(200));
    frame.image.dispose();
    codec!.dispose();
  });

  testWidgets('PDF exports multiple populated pages', (tester) async {
    final entries = List.generate(10, (index) {
      final start = DateTime(2026, 9, 14, 9).add(Duration(hours: index));
      return CalendarPlanEntry(
        occurrence: CourseOccurrence(
          name: 'Course $index',
          location: 'Room $index',
          startsAt: start,
          endsAt: start.add(const Duration(hours: 1)),
          category: PlanCategories.LESSON,
        ),
        sourceId: 'lesson-$index',
        originalStartsAt: start,
        fetchedLesson: true,
      );
    });
    final bytes = await tester.runAsync(
      () => buildCalendarPdf(
        entries,
        labels: _labels,
        subtitle: 'Current week',
        categoryName: (_) => 'Lesson',
      ),
    );
    expect(bytes, isNotNull);
    expect(String.fromCharCodes(bytes!.sublist(0, 5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });
}

const _labels = CalendarExportLabels(
  title: 'Calendar',
  date: 'Date',
  start: 'Start',
  end: 'End',
  name: 'Name',
  location: 'Location',
  category: 'Category',
  eventsSheet: 'Events',
);

final _entry = CalendarPlanEntry(
  occurrence: CourseOccurrence(
    name: '大学物理',
    location: '六教',
    startsAt: DateTime(2026, 9, 14, 9, 50),
    endsAt: DateTime(2026, 9, 14, 11, 25),
    category: PlanCategories.LESSON,
  ),
  sourceId: 'lesson-1',
  originalStartsAt: DateTime(2026, 9, 14, 9, 50),
  fetchedLesson: true,
);
