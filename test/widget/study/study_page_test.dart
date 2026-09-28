import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';
import 'package:thulium/pages/study_page.dart';
import 'package:thulium_campus/thulium_campus.dart';

void main() {
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
