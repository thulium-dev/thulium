/// Localized captions shared by the PDF, image, and spreadsheet exports.
final class CalendarExportLabels {
  const CalendarExportLabels({
    required this.title,
    required this.date,
    required this.start,
    required this.end,
    required this.name,
    required this.location,
    required this.category,
    required this.eventsSheet,
  });

  final String title;
  final String date;
  final String start;
  final String end;
  final String name;
  final String location;
  final String category;
  final String eventsSheet;

  List<String> get headers => [date, start, end, name, location, category];
}
