import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:thulium/widgets/calendar_now_line.dart';

void main() {
  testWidgets('marks the current time across the seven day columns', (
    tester,
  ) async {
    var taps = 0;
    final now = ValueNotifier(DateTime(2026, 9, 10, 15, 30));
    addTearDown(now.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: FTheme(
          data: FThemes.neutral.light.touch,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 312,
                height: 840,
                child: Stack(
                  key: const ValueKey('calendar-now-grid'),
                  children: [
                    Positioned.fill(
                      child: GestureDetector(onTap: () => taps++),
                    ),
                    ValueListenableBuilder<DateTime>(
                      valueListenable: now,
                      builder: (context, currentTime, child) => CalendarNowLine(
                        now: currentTime,
                        weekStart: DateTime(2026, 9, 7),
                        firstHour: 8,
                        lastHour: 22,
                        hourHeight: 60,
                        timeAxisWidth: 32,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final line = find.byKey(const ValueKey('calendar-now-line'));
    final grid = find.byKey(const ValueKey('calendar-now-grid'));
    expect(line, findsOneWidget);
    expect(tester.getTopLeft(line).dx - tester.getTopLeft(grid).dx, 32);
    expect(tester.getTopLeft(line).dy - tester.getTopLeft(grid).dy, 450);
    expect(tester.getSize(line), const Size(280, 1));

    await tester.tapAt(tester.getCenter(line));
    expect(taps, 1);

    now.value = DateTime(2026, 9, 10, 15, 31);
    await tester.pump();
    expect(tester.getTopLeft(line).dy - tester.getTopLeft(grid).dy, 451);
  });

  testWidgets('hides the line outside this week or the visible hours', (
    tester,
  ) async {
    Future<void> showAt(DateTime now) => tester.pumpWidget(
      MaterialApp(
        home: FTheme(
          data: FThemes.neutral.light.touch,
          child: Scaffold(
            body: SizedBox(
              width: 312,
              height: 840,
              child: Stack(
                children: [
                  CalendarNowLine(
                    now: now,
                    weekStart: DateTime(2026, 9, 7),
                    firstHour: 8,
                    lastHour: 22,
                    hourHeight: 60,
                    timeAxisWidth: 32,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final line = find.byKey(const ValueKey('calendar-now-line'));
    await showAt(DateTime(2026, 9, 10, 7, 59));
    expect(line, findsNothing);
    await showAt(DateTime(2026, 9, 10, 22));
    expect(line, findsNothing);
    await showAt(DateTime(2026, 9, 14, 15, 30));
    expect(line, findsNothing);
  });
}
