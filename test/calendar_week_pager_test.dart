import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thulium/widgets/calendar_week_pager.dart';

void main() {
  testWidgets('a swipe moves the current and adjacent weeks with the finger', (
    tester,
  ) async {
    var selectedWeek = 2;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 320,
            height: 300,
            child: CalendarWeekPager(
              weekCount: 3,
              initialWeek: 2,
              onWeekChanged: (week) => selectedWeek = week,
              itemBuilder: (context, week) => Center(child: Text('Week $week')),
            ),
          ),
        ),
      ),
    );

    final currentX = tester.getCenter(find.text('Week 2')).dx;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(CalendarWeekPager)),
    );
    await gesture.moveBy(const Offset(-200, 0));
    await tester.pump();

    expect(tester.getCenter(find.text('Week 2')).dx, lessThan(currentX));
    expect(find.text('Week 3'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selectedWeek, 3);

    // The first and last pages are hard bounds, including for further swipes.
    await tester.drag(find.byType(CalendarWeekPager), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(selectedWeek, 3);
  });

  testWidgets('arrow navigation animates through the same pages', (
    tester,
  ) async {
    final pagerKey = GlobalKey<CalendarWeekPagerState>();
    var selectedWeek = 2;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 320,
            height: 300,
            child: CalendarWeekPager(
              key: pagerKey,
              weekCount: 3,
              initialWeek: 2,
              onWeekChanged: (week) => selectedWeek = week,
              itemBuilder: (context, week) => Center(child: Text('Week $week')),
            ),
          ),
        ),
      ),
    );

    pagerKey.currentState!.animateBy(-1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Week 2'), findsOneWidget);
    expect(find.text('Week 1'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(selectedWeek, 1);

    pagerKey.currentState!.animateBy(-1);
    await tester.pumpAndSettle();
    expect(selectedWeek, 1);
  });

  testWidgets('vertical drags still scroll within a week', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 320,
            height: 300,
            child: CalendarWeekPager(
              weekCount: 2,
              initialWeek: 1,
              onWeekChanged: (_) {},
              itemBuilder: (context, week) => SingleChildScrollView(
                child: SizedBox(width: 320, height: 700, child: Text('$week')),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(CalendarWeekPager), const Offset(0, -120));
    await tester.pump();
    final verticalScroll = find.descendant(
      of: find.byType(SingleChildScrollView).first,
      matching: find.byType(Scrollable),
    );
    expect(
      tester.state<ScrollableState>(verticalScroll).position.pixels,
      greaterThan(0),
    );
  });
}
