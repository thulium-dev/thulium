import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';

enum CalendarExportRange { currentWeek, currentTerm }

enum CalendarExportFormat { ics, pdf, xlsx, png }

final class CalendarExportSelection {
  const CalendarExportSelection({
    required this.range,
    required this.format,
    required this.includeSchoolCourses,
    required this.includePersonalPlans,
  });

  final CalendarExportRange range;
  final CalendarExportFormat format;
  final bool includeSchoolCourses;
  final bool includePersonalPlans;
}

Future<CalendarExportSelection?> showCalendarExportDialog(
  BuildContext context,
) {
  final l10n = AppLocalizations.of(context)!;
  var range = CalendarExportRange.currentWeek;
  var format = CalendarExportFormat.ics;
  var includeSchoolCourses = true;
  var includePersonalPlans = true;

  return showFDialog<CalendarExportSelection>(
    context: context,
    useSafeArea: true,
    barrierDismissible: true,
    routeStyle: FDialogRouteStyle.inherit(colors: context.theme.colors),
    builder: (context, style, animation) => StatefulBuilder(
      builder: (context, setDialogState) => FDialog.adaptive(
        animation: animation,
        title: Text(l10n.calendarExportDialogTitle),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FSelect<CalendarExportFormat>.rich(
              label: Text(l10n.calendarExportFormat),
              control: FSelectControl<CalendarExportFormat>.lifted(
                value: format,
                onChange: (value) {
                  if (value == null) return;
                  setDialogState(() {
                    format = value;
                    if (format == CalendarExportFormat.png) {
                      range = CalendarExportRange.currentWeek;
                    }
                  });
                },
              ),
              format: (value) => switch (value) {
                CalendarExportFormat.ics => l10n.calendarExportFormatIcs,
                CalendarExportFormat.pdf => l10n.calendarExportFormatPdf,
                CalendarExportFormat.xlsx => l10n.calendarExportFormatXlsx,
                CalendarExportFormat.png => l10n.calendarExportFormatPng,
              },
              children: [
                FSelectItem(
                  title: Text(l10n.calendarExportFormatIcs),
                  value: CalendarExportFormat.ics,
                ),
                FSelectItem(
                  title: Text(l10n.calendarExportFormatPdf),
                  value: CalendarExportFormat.pdf,
                ),
                FSelectItem(
                  title: Text(l10n.calendarExportFormatXlsx),
                  value: CalendarExportFormat.xlsx,
                ),
                FSelectItem(
                  title: Text(l10n.calendarExportFormatPng),
                  value: CalendarExportFormat.png,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(l10n.calendarExportRange),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FButton(
                    variant: range == CalendarExportRange.currentWeek
                        ? FButtonVariant.primary
                        : FButtonVariant.outline,
                    onPress: () => setDialogState(
                      () => range = CalendarExportRange.currentWeek,
                    ),
                    child: Text(l10n.calendarExportCurrentWeek),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FButton(
                    variant: range == CalendarExportRange.currentTerm
                        ? FButtonVariant.primary
                        : FButtonVariant.outline,
                    onPress: format == CalendarExportFormat.png
                        ? null
                        : () => setDialogState(
                            () => range = CalendarExportRange.currentTerm,
                          ),
                    child: Text(l10n.calendarExportEntireTerm),
                  ),
                ),
              ],
            ),
            if (format == CalendarExportFormat.png) ...[
              const SizedBox(height: 8),
              Text(l10n.calendarExportPngCurrentWeekOnly),
            ],
            const SizedBox(height: 12),
            FCheckbox(
              value: includeSchoolCourses,
              onChange: (value) =>
                  setDialogState(() => includeSchoolCourses = value),
              label: Text(l10n.calendarExportSchoolCourses),
            ),
            const SizedBox(height: 8),
            FCheckbox(
              value: includePersonalPlans,
              onChange: (value) =>
                  setDialogState(() => includePersonalPlans = value),
              label: Text(l10n.calendarExportPersonalPlans),
            ),
          ],
        ),
        actions: [
          FButton(
            onPress: includeSchoolCourses || includePersonalPlans
                ? () => Navigator.of(context).pop(
                    CalendarExportSelection(
                      range: range,
                      format: format,
                      includeSchoolCourses: includeSchoolCourses,
                      includePersonalPlans: includePersonalPlans,
                    ),
                  )
                : null,
            child: Text(l10n.calendarExportAction),
          ),
          FButton(
            variant: FButtonVariant.outline,
            onPress: () => Navigator.of(context).pop(),
            child: Text(l10n.cancelAction),
          ),
        ],
      ),
    ),
  );
}
