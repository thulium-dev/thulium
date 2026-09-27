import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:thulium_campus/thulium_campus.dart';

import 'calendar_export_labels.dart';

/// Writes one dated occurrence per row, with native date and time cell types.
Uint8List buildCalendarXlsx(
  Iterable<CalendarPlanEntry> entries, {
  required CalendarExportLabels labels,
  required String Function(String category) categoryName,
}) {
  final workbook = Excel.createExcel();
  final defaultSheet = workbook.getDefaultSheet();
  final sheetName = labels.eventsSheet;
  if (defaultSheet != null && defaultSheet != sheetName) {
    workbook.rename(defaultSheet, sheetName);
  }
  final sheet = workbook[sheetName];
  final headerStyle = CellStyle(
    bold: true,
    fontColorHex: ExcelColor.white,
    backgroundColorHex: ExcelColor.fromHexString('FF28324B'),
  );
  sheet.appendRow(labels.headers.map(TextCellValue.new).toList());
  for (var column = 0; column < labels.headers.length; column++) {
    sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0))
            .cellStyle =
        headerStyle;
  }
  for (final (index, width) in [17.0, 12.0, 12.0, 38.0, 32.0, 20.0].indexed) {
    sheet.setColumnWidth(index, width);
  }

  final sorted = entries.toList()
    ..sort((a, b) => a.occurrence.startsAt.compareTo(b.occurrence.startsAt));
  for (final entry in sorted) {
    final event = entry.occurrence;
    sheet.appendRow([
      DateCellValue(
        year: event.startsAt.year,
        month: event.startsAt.month,
        day: event.startsAt.day,
      ),
      TimeCellValue(hour: event.startsAt.hour, minute: event.startsAt.minute),
      TimeCellValue(hour: event.endsAt.hour, minute: event.endsAt.minute),
      TextCellValue(event.name),
      TextCellValue(event.location),
      TextCellValue(categoryName(event.category)),
    ]);
  }

  final encoded = workbook.encode();
  if (encoded == null) {
    throw StateError('Could not encode the calendar workbook.');
  }
  return Uint8List.fromList(encoded);
}
