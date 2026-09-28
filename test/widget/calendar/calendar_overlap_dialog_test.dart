import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';
import 'package:thulium/widgets/calendar_course_layout.dart';
import 'package:thulium/widgets/calendar_overlap_dialog.dart';
import 'package:thulium_campus/thulium_campus.dart';

void main() {
  testWidgets('shows every overlapping course and dismisses outside', (
    tester,
  ) async {
    CourseOccurrence? selected;
    final groups = layoutCalendarCourseGroups([
      CourseOccurrence(
        name: 'Physics',
        location: 'Room 101',
        category: PlanCategories.LESSON,
        startsAt: DateTime(2026, 9, 7, 8),
        endsAt: DateTime(2026, 9, 7, 10),
      ),
      CourseOccurrence(
        name: 'Chemistry',
        location: 'Room 202',
        category: PlanCategories.LESSON,
        startsAt: DateTime(2026, 9, 7, 9),
        endsAt: DateTime(2026, 9, 7, 11),
      ),
    ]);
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
              onPressed: () async => selected = await showCalendarOverlapDialog(
                context,
                groups.single,
              ),
              child: const Text('Open overlap'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open overlap'));
    await tester.pumpAndSettle();

    expect(find.text('Overlapping plans'), findsOneWidget);
    expect(find.text('Physics'), findsOneWidget);
    expect(find.text('Room 101'), findsOneWidget);
    expect(find.text('Chemistry'), findsOneWidget);
    expect(find.text('Room 202'), findsOneWidget);
    final route = ModalRoute.of(tester.element(find.byType(FDialog)));
    expect(route, isA<FDialogRoute<CourseOccurrence>>());
    expect(
      (route! as FDialogRoute<CourseOccurrence>).style.barrierFilter,
      isNotNull,
    );

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Overlapping plans'), findsNothing);

    await tester.tap(find.text('Open overlap'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Physics'));
    await tester.pumpAndSettle();
    expect(selected?.name, 'Physics');
    expect(find.text('Overlapping plans'), findsNothing);
  });
}
