import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';
import 'package:thulium/widgets/calendar_plan_details_dialog.dart';
import 'package:thulium_campus/thulium_campus.dart';

void main() {
  testWidgets('details show fields and both edit scopes for a repeated plan', (
    tester,
  ) async {
    final rule = CustomPlan(
      id: 'study',
      name: 'Study group',
      location: 'Library',
      startsAt: DateTime(2026, 9, 21, 9),
      endsAt: DateTime(2026, 9, 21, 10),
      category: 'user.study',
      repeat: PlanRepeat.weekly,
    );
    final entry = CustomPlanCollection(
      categories: [],
      plans: [rule],
    ).entriesForWeek([], DateTime(2026, 9, 21), DateTime(2026, 9, 28)).single;
    CalendarPlanAction? chosen;
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
                  chosen = await showCalendarPlanDetailsDialog(
                    context,
                    entry,
                    categoryName: 'Study',
                    repeatLabel: 'Weekly',
                  ),
              child: const Text('Open details'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();
    expect(find.text('Study group'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Study'), findsOneWidget);
    expect(find.text('Weekly'), findsOneWidget);
    expect(find.text('Delete entire series'), findsOneWidget);
    expect(find.text('Cancel this occurrence'), findsOneWidget);
    final editAll = tester.widget<FButton>(
      find.byKey(const ValueKey('plan-edit-series')),
    );
    expect(editAll.onPress, isNotNull);
    await tester.tap(find.byKey(const ValueKey('plan-edit-series')));
    await tester.pumpAndSettle();
    expect(chosen, CalendarPlanAction.editSeries);
  });

  testWidgets('a fetched lesson is non-repeating and has no series edit', (
    tester,
  ) async {
    final lesson = CourseOccurrence(
      name: 'Physics',
      location: 'Room 1',
      startsAt: DateTime(2026, 9, 21, 9),
      endsAt: DateTime(2026, 9, 21, 10),
      category: PlanCategories.LESSON,
    );
    final entry = CustomPlanCollection.empty()
        .entriesForWeek([lesson], DateTime(2026, 9, 21), DateTime(2026, 9, 28))
        .single;
    CalendarPlanAction? chosen;
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
                  chosen = await showCalendarPlanDetailsDialog(
                    context,
                    entry,
                    categoryName: 'Lesson',
                    repeatLabel: 'Never',
                  ),
              child: const Text('Open details'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();
    expect(find.text('Never'), findsOneWidget);
    final editAll = tester.widget<FButton>(
      find.byKey(const ValueKey('plan-edit-series')),
    );
    expect(editAll.onPress, isNull);
    await tester.tap(find.byKey(const ValueKey('plan-edit-one')));
    await tester.pumpAndSettle();
    expect(chosen, CalendarPlanAction.editOne);
  });

  testWidgets('confirmation returns the persistent skip-warning choice', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    PlanConfirmationDecision? decision;
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
                  decision = await showPlanActionConfirmation(
                    context,
                    deleteSeries: true,
                    repeating: true,
                    fetchedLesson: false,
                  ),
              child: const Text('Open confirmation'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open confirmation'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Every occurrence'), findsOneWidget);
    await tester.tap(find.text("Don't ask again for this action"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(decision?.skipNextTime, isTrue);
  });
}
