import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';
import 'package:thulium/pages/add_plan_page.dart';
import 'package:thulium_campus/thulium_campus.dart';

void main() {
  testWidgets('saves a new weekly plan and its category together', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    CustomPlan? savedPlan;
    CustomPlanCategory? savedCategory;
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
        home: AddPlanPage(
          initialDate: DateTime(2026, 9, 21),
          categories: const [],
          onSave: (plan, category) async {
            savedPlan = plan;
            savedCategory = category;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(FTextFormField).at(0), 'Study group');
    await tester.enterText(find.byType(FTextFormField).at(1), 'Library');
    expect(find.text('Lesson'), findsOneWidget);
    await tester.tap(find.text('Lesson'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New category'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(FTextField).last, 'Study');
    await tester.ensureVisible(find.text('Weekly'));
    await tester.tap(find.text('Weekly'));
    await tester.ensureVisible(find.text('Save plan'));
    await tester.tap(find.text('Save plan'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    expect(savedPlan?.name, 'Study group');
    expect(savedPlan?.location, 'Library');
    expect(savedPlan?.startsAt, DateTime(2026, 9, 21, 9));
    expect(savedPlan?.endsAt, DateTime(2026, 9, 21, 10));
    expect(savedPlan?.repeat, PlanRepeat.weekly);
    expect(savedCategory?.name, 'Study');
    expect(savedPlan?.category, savedCategory?.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers a saved category on the next plan', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    CustomPlan? savedPlan;
    CustomPlanCategory? createdCategory;
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
        home: AddPlanPage(
          initialDate: DateTime(2026, 9, 21),
          categories: const [
            CustomPlanCategory(
              id: 'user.study',
              name: 'Study',
              colorValue: 0xFF6B5CE7,
            ),
          ],
          onSave: (plan, category) async {
            savedPlan = plan;
            createdCategory = category;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(FTextFormField).at(0), 'New plan');
    await tester.enterText(find.byType(FTextFormField).at(1), 'Library');
    await tester.tap(find.text('Lesson'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Study'));
    await tester.pumpAndSettle();
    expect(find.text('Study'), findsOneWidget);
    await tester.ensureVisible(find.text('Save plan'));
    await tester.tap(find.text('Save plan'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(savedPlan?.category, 'user.study');
    expect(createdCategory, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('prefills a lesson with no location for a one-off edit', (
    tester,
  ) async {
    final lesson = CourseOccurrence(
      name: 'Physics',
      location: '',
      startsAt: DateTime(2026, 9, 21, 13),
      endsAt: DateTime(2026, 9, 21, 14),
      category: PlanCategories.LESSON,
    );
    CustomPlan? edited;
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
        home: AddPlanPage(
          initialDate: lesson.startsAt,
          initialOccurrence: lesson,
          singleOccurrence: true,
          categories: const [],
          onSave: (plan, _) async => edited = plan,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Edit plan'), findsOneWidget);
    expect(find.text('Physics'), findsOneWidget);
    expect(find.text('Repeat'), findsNothing);
    await tester.enterText(find.byType(FTextFormField).at(1), 'Room 101');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(edited?.name, 'Physics');
    expect(edited?.location, 'Room 101');
    expect(edited?.startsAt, lesson.startsAt);
    expect(edited?.repeat, PlanRepeat.none);
  });

  testWidgets('prefills and preserves the repeat rule for a series edit', (
    tester,
  ) async {
    final original = CustomPlan(
      id: 'study',
      name: 'Study group',
      location: 'Library',
      startsAt: DateTime(2026, 9, 21, 13),
      endsAt: DateTime(2026, 9, 21, 14),
      category: PlanCategories.LESSON,
      repeat: PlanRepeat.weekly,
    );
    CustomPlan? edited;
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
        home: AddPlanPage(
          initialDate: original.startsAt,
          initialPlan: original,
          categories: const [],
          onSave: (plan, _) async => edited = plan,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Edit plan'), findsOneWidget);
    expect(find.text('Study group'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    await tester.enterText(find.byType(FTextFormField).first, 'Revised group');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(edited?.id, original.id);
    expect(edited?.name, 'Revised group');
    expect(edited?.startsAt, original.startsAt);
    expect(edited?.repeat, PlanRepeat.weekly);
  });
}
