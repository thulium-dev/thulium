import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';
import 'package:thulium/pages/study_page.dart';
import 'package:thulium_campus/thulium_campus.dart';

void main() {
  testWidgets('course badges show only positive, available homework counts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final catalog = LearnCourseCatalog(
      userId: 'student',
      semester: '2026-2027-1',
      courses: const [
        LearnCourse(
          id: 'physics',
          name: '大学物理',
          englishName: 'A long physics course name that wraps on mobile',
          teacherName: 'Teacher',
          schedule: 'Room 101',
        ),
        LearnCourse(
          id: 'math',
          name: 'Math',
          englishName: '',
          teacherName: '',
          schedule: '',
        ),
      ],
    );
    Future<void> show(Map<String, int> counts, {bool failed = false}) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: [
            ...AppLocalizations.localizationsDelegates,
            ...FLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) =>
              FTheme(data: FThemes.neutral.light.touch, child: child!),
          home: Scaffold(
            body: StudyPage(
              semester: catalog.semester,
              catalog: catalog,
              isLoading: false,
              isStale: false,
              error: null,
              onRefresh: () {},
              unsubmittedHomework: counts,
              homeworkFailed: failed,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show({'physics': 12, 'math': 0});
    expect(find.byType(FBadge), findsOneWidget);
    expect(
      find.byKey(const ValueKey('homework-badge-physics')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('homework-badge-math')), findsNothing);
    expect(find.byTooltip('Unsubmitted assignments: 12'), findsOneWidget);
    final title = find.text(catalog.courses.first.englishName);
    expect(
      tester.getTopRight(find.byType(FBadge)).dx,
      greaterThan(tester.getTopRight(title).dx),
    );
    expect(tester.takeException(), isNull);

    await show({'physics': 0, 'math': 0});
    expect(find.byType(FBadge), findsNothing);
    await show({});
    expect(find.byType(FBadge), findsNothing);
    await show({'physics': 12}, failed: true);
    expect(find.byType(FBadge), findsNothing);
    expect(
      find.text('Could not load assignment counts. Try refreshing.'),
      findsOneWidget,
    );
    expect(title, findsOneWidget);
  });

  testWidgets('reserves shortcut space and displays localized course titles', (
    tester,
  ) async {
    final catalog = LearnCourseCatalog(
      userId: 'student',
      semester: '2026-2027-1',
      courses: [
        const LearnCourse(
          id: 'course-1',
          name: '大学物理',
          englishName: 'University Physics',
          teacherName: 'Teacher',
          schedule: 'Monday, Room 101',
        ),
      ],
    );

    Future<void> show(Locale locale) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
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
            body: StudyPage(
              semester: catalog.semester,
              catalog: catalog,
              isLoading: false,
              isStale: false,
              error: null,
              onRefresh: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show(const Locale('en'));
    expect(
      find.byKey(const ValueKey('study-shortcut-reserved')),
      findsOneWidget,
    );
    expect(find.text('My courses'), findsOneWidget);
    expect(find.text('University Physics'), findsOneWidget);

    await show(const Locale('zh', 'CN'));
    expect(find.text('我的课程'), findsOneWidget);
    expect(find.text('大学物理'), findsOneWidget);
    expect(find.text('University Physics'), findsNothing);
  });
}
