import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:thulium/widgets/calendar_course_block.dart';
import 'package:thulium_campus/thulium_campus.dart';

void main() {
  testWidgets('switches text orientation with width hysteresis', (
    tester,
  ) async {
    Future<void> showAtWidth(double width) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FTheme(
            data: FThemes.neutral.light.touch,
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  height: 100,
                  child: CalendarCourseBlock(
                    course: _course,
                    width: width,
                    height: 100,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await showAtWidth(70);
    expect(find.byType(RotatedBox), findsOneWidget);

    await showAtWidth(105);
    expect(find.byType(RotatedBox), findsNothing);
    expect(find.text('Course A'), findsOneWidget);
    expect(find.text('Room 101'), findsOneWidget);

    // A width between the thresholds keeps the previous wide layout.
    await showAtWidth(88);
    expect(find.byType(RotatedBox), findsNothing);

    await showAtWidth(75);
    expect(find.byType(RotatedBox), findsOneWidget);
  });

  testWidgets('respects the reduced-motion setting', (tester) async {
    Future<void> showAtWidth(double width) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: FTheme(
              data: FThemes.neutral.light.touch,
              child: Scaffold(
                body: CalendarCourseBlock(
                  course: _course,
                  width: width,
                  height: 100,
                ),
              ),
            ),
          ),
        ),
      );
    }

    await showAtWidth(70);
    await showAtWidth(105);

    expect(
      tester
          .getSize(find.byKey(const ValueKey('calendar-course-surface')))
          .width,
      105,
    );
    expect(
      tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
      Duration.zero,
    );
  });

  testWidgets('card width snaps while only the text transitions', (
    tester,
  ) async {
    Future<void> showAtWidth(double width) => tester.pumpWidget(
      MaterialApp(
        home: FTheme(
          data: FThemes.neutral.light.touch,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                height: 100,
                child: CalendarCourseBlock(
                  course: _course,
                  width: width,
                  height: 100,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await showAtWidth(70);
    await showAtWidth(105);
    final card = find.byKey(const ValueKey('calendar-course-surface'));
    expect(tester.getSize(card).width, 105);
    expect(find.byType(FadeTransition), findsWidgets);

    await tester.pumpAndSettle();
    expect(tester.getSize(card).width, 105);
    expect(find.byType(RotatedBox), findsNothing);
  });
}

final _course = CourseOccurrence(
  name: 'Course A',
  location: 'Room 101',
  category: PlanCategories.LESSON,
  startsAt: DateTime(2026, 9, 7, 8),
  endsAt: DateTime(2026, 9, 7, 9, 35),
);
