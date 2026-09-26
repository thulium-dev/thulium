import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thulium/widgets/calendar_week_scroll_sync.dart';

void main() {
  testWidgets('restores a detached week before its first frame is painted', (
    tester,
  ) async {
    final sync = CalendarWeekScrollSync(initialOffset: 480);

    Future<void> showWeek(int week) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              height: 300,
              child: SingleChildScrollView(
                controller: sync.controllerForWeek(week),
                child: SizedBox(height: 1440, child: Text('Week $week')),
              ),
            ),
          ),
        ),
      ),
    );

    await showWeek(1);
    final first = sync.controllerForWeek(1);
    expect(first.offset, 480);

    first.jumpTo(700);
    await tester.pump();
    await showWeek(2);
    final second = sync.controllerForWeek(2);
    expect(second.offset, 700);

    second.jumpTo(900);
    await tester.pump();
    await showWeek(1);
    // No extra pump is allowed here: the old offset must never be painted.
    expect(first.offset, 900);

    await tester.pumpWidget(const SizedBox.shrink());
    sync.dispose();
  });

  testWidgets('keeps simultaneously attached week pages aligned', (
    tester,
  ) async {
    final sync = CalendarWeekScrollSync(initialOffset: 480);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              for (final week in [1, 2])
                SizedBox(
                  width: 200,
                  height: 300,
                  child: SingleChildScrollView(
                    controller: sync.controllerForWeek(week),
                    child: SizedBox(height: 1440, child: Text('Week $week')),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    sync.controllerForWeek(1).jumpTo(650);
    expect(sync.controllerForWeek(2).offset, 650);

    await tester.pumpWidget(const SizedBox.shrink());
    sync.dispose();
  });

  testWidgets('a zoomed week keeps its offset on the next week', (
    tester,
  ) async {
    final sync = CalendarWeekScrollSync(initialOffset: 480);
    Future<void> showWeek(int week, double hourHeight) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: SingleChildScrollView(
              controller: sync.controllerForWeek(week),
              child: SizedBox(height: hourHeight * 24),
            ),
          ),
        ),
      ),
    );

    await showWeek(1, 60);
    sync.setOffsetForLayout(1200);
    await showWeek(1, 120);
    expect(sync.controllerForWeek(1).offset, 1200);
    await showWeek(2, 120);
    expect(sync.controllerForWeek(2).offset, 1200);

    await tester.pumpWidget(const SizedBox.shrink());
    sync.dispose();
  });
}
