import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';
import 'package:thulium/widgets/calendar_export_dialog.dart';

void main() {
  testWidgets('format dropdown selects PNG and limits it to the current week', (
    tester,
  ) async {
    CalendarExportSelection? selection;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [
          ...AppLocalizations.localizationsDelegates,
          ...FLocalizations.localizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => FTheme(
          data: FThemes.neutral.light.touch,
          child: child ?? const SizedBox.shrink(),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  selection = await showCalendarExportDialog(context),
              child: const Text('Open export'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open export'));
    await tester.pumpAndSettle();
    expect(find.text('File format'), findsOneWidget);
    await tester.tap(find.text('iCalendar (.ics)').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Image (.png)').last);
    await tester.pumpAndSettle();
    expect(find.text('PNG exports the current week only.'), findsOneWidget);
    await tester.tap(find.text('Export').last);
    await tester.pumpAndSettle();
    expect(selection?.format, CalendarExportFormat.png);
    expect(selection?.range, CalendarExportRange.currentWeek);
  });
}
