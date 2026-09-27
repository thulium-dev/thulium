// ignore_for_file: constant_identifier_names

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:thulium_campus/thulium_campus.dart';

import 'calendar_export_labels.dart';

const _REPORT_WIDTH = 1120.0;
const _REPORT_HEADER_HEIGHT = 164.0;
const _REPORT_ROW_HEIGHT = 64.0;
const _PDF_ROWS_PER_PAGE = 9;
const _COLUMN_WIDTHS = <double>[120, 90, 90, 330, 300, 110];

/// Renders the selected week's complete event list into a single PNG.
///
/// Flutter paints the text using its platform font fallback, so Chinese course
/// names remain visible without bundling a large CJK font with the app.
Future<Uint8List> buildCalendarPng(
  Iterable<CalendarPlanEntry> entries, {
  required CalendarExportLabels labels,
  required String subtitle,
  required String Function(String category) categoryName,
}) async {
  final sorted = _sortedEntries(entries);
  return _renderReport(
    sorted,
    labels: labels,
    subtitle: subtitle,
    categoryName: categoryName,
  );
}

/// Creates a multi-page A4 PDF, with readable Unicode text on each page.
///
/// The rasterized page content reuses the PNG renderer instead of requiring a
/// bundled full CJK PDF font; each page is limited to nine event rows.
Future<Uint8List> buildCalendarPdf(
  Iterable<CalendarPlanEntry> entries, {
  required CalendarExportLabels labels,
  required String subtitle,
  required String Function(String category) categoryName,
}) async {
  final sorted = _sortedEntries(entries);
  final document = pw.Document();
  for (var first = 0; first < sorted.length; first += _PDF_ROWS_PER_PAGE) {
    final last = (first + _PDF_ROWS_PER_PAGE).clamp(0, sorted.length);
    final imageBytes = await _renderReport(
      sorted.sublist(first, last),
      labels: labels,
      subtitle: subtitle,
      categoryName: categoryName,
    );
    final pageImage = pw.MemoryImage(imageBytes);
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (context) =>
            pw.Center(child: pw.Image(pageImage, fit: pw.BoxFit.contain)),
      ),
    );
  }
  return Uint8List.fromList(await document.save());
}

List<CalendarPlanEntry> _sortedEntries(Iterable<CalendarPlanEntry> entries) =>
    entries.toList()
      ..sort((a, b) => a.occurrence.startsAt.compareTo(b.occurrence.startsAt));

Future<Uint8List> _renderReport(
  List<CalendarPlanEntry> entries, {
  required CalendarExportLabels labels,
  required String subtitle,
  required String Function(String category) categoryName,
}) async {
  final height = (_REPORT_HEADER_HEIGHT + entries.length * _REPORT_ROW_HEIGHT)
      .ceil();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
  _drawText(
    canvas,
    labels.title,
    const Rect.fromLTWH(40, 24, 1040, 42),
    color: const Color(0xFF20283D),
    size: 30,
    weight: FontWeight.w700,
  );
  _drawText(
    canvas,
    subtitle,
    const Rect.fromLTWH(40, 74, 1040, 30),
    color: const Color(0xFF596579),
    size: 16,
  );
  canvas.drawRect(
    const Rect.fromLTWH(40, 112, 1040, 44),
    Paint()..color = const Color(0xFF28324B),
  );

  var left = 40.0;
  for (var column = 0; column < labels.headers.length; column++) {
    _drawText(
      canvas,
      labels.headers[column],
      Rect.fromLTWH(left + 8, 112, _COLUMN_WIDTHS[column] - 16, 44),
      color: const Color(0xFFFFFFFF),
      size: 15,
      weight: FontWeight.w600,
    );
    left += _COLUMN_WIDTHS[column];
  }

  final dateFormat = DateFormat('yyyy-MM-dd');
  final timeFormat = DateFormat('HH:mm');
  for (var row = 0; row < entries.length; row++) {
    final event = entries[row].occurrence;
    final top = 156.0 + row * _REPORT_ROW_HEIGHT;
    canvas.drawRect(
      Rect.fromLTWH(40, top, 1040, _REPORT_ROW_HEIGHT),
      Paint()
        ..color = row.isEven
            ? const Color(0xFFF6F8FC)
            : const Color(0xFFFFFFFF),
    );
    final values = [
      dateFormat.format(event.startsAt),
      timeFormat.format(event.startsAt),
      timeFormat.format(event.endsAt),
      event.name,
      event.location,
      categoryName(event.category),
    ];
    left = 40;
    for (var column = 0; column < values.length; column++) {
      _drawText(
        canvas,
        values[column],
        Rect.fromLTWH(
          left + 8,
          top,
          _COLUMN_WIDTHS[column] - 16,
          _REPORT_ROW_HEIGHT,
        ),
        color: const Color(0xFF20283D),
        size: 16,
      );
      left += _COLUMN_WIDTHS[column];
    }
  }

  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(_REPORT_WIDTH.ceil(), height);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('Could not encode the calendar image.');
      }
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

void _drawText(
  Canvas canvas,
  String value,
  Rect area, {
  required Color color,
  required double size,
  FontWeight weight = FontWeight.w400,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(color: color, fontSize: size, fontWeight: weight),
    ),
    textDirection: ui.TextDirection.ltr,
    maxLines: 2,
    ellipsis: '…',
  )..layout(maxWidth: area.width);
  painter.paint(
    canvas,
    Offset(area.left, area.top + (area.height - painter.height) / 2),
  );
  painter.dispose();
}
