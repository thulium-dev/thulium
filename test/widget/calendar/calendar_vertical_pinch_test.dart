import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thulium/widgets/calendar_vertical_pinch.dart';
import 'package:thulium/widgets/calendar_week_scroll_sync.dart';

void main() {
  test('the 24-hour grid never becomes shorter than its viewport', () {
    for (final viewport in [300.0, 500.0, 900.0, 5000.0]) {
      final minimum = CalendarZoomGeometry.minimumHourHeight(viewport);
      expect(minimum * 24, greaterThanOrEqualTo(viewport));
      expect(
        CalendarZoomGeometry.maximumHourHeight(viewport),
        greaterThanOrEqualTo(minimum),
      );
    }
    final minimum = CalendarZoomGeometry.zoom(
      initialHourHeight: 60,
      initialOffset: 480,
      initialFocalY: 200,
      currentFocalY: 200,
      initialSpan: 200,
      currentSpan: 1,
      viewportHeight: 600,
    );
    expect(minimum.hourHeight, 25);
    expect(minimum.offset, 0);
    final maximum = CalendarZoomGeometry.zoom(
      initialHourHeight: 60,
      initialOffset: 480,
      initialFocalY: 200,
      currentFocalY: 200,
      initialSpan: 100,
      currentSpan: 1000,
      viewportHeight: 600,
    );
    expect(maximum.hourHeight, 180);
  });

  test('the focal time remains under the fingers', () {
    final result = CalendarZoomGeometry.zoom(
      initialHourHeight: 60,
      initialOffset: 480,
      initialFocalY: 200,
      currentFocalY: 220,
      initialSpan: 100,
      currentSpan: 200,
      viewportHeight: 500,
    );
    expect(result.hourHeight, 120);
    expect(
      (result.offset + 220) / result.hourHeight,
      closeTo((480 + 200) / 60, 0.001),
    );
  });

  testWidgets('two-finger pinch zooms while one-finger drag still scrolls', (
    tester,
  ) async {
    final sync = CalendarWeekScrollSync(initialOffset: 480);
    addTearDown(sync.dispose);
    var hourHeight = 60.0;
    var pinching = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 500,
              child: StatefulBuilder(
                builder: (context, setState) => CalendarVerticalPinchRegion(
                  hourHeight: hourHeight,
                  scrollOffset: sync.offset,
                  viewportHeight: 500,
                  onPinchChanged: (height, offset) {
                    sync.setOffsetForLayout(offset);
                    setState(() => hourHeight = height);
                  },
                  onPinchingChanged: (value) =>
                      setState(() => pinching = value),
                  child: SingleChildScrollView(
                    controller: sync.controllerForWeek(1),
                    physics: pinching
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    child: SizedBox(height: hourHeight * 24),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final region = find.byKey(const ValueKey('calendar-pinch-region'));
    final center = tester.getCenter(region);
    final first = await tester.createGesture(pointer: 1);
    final second = await tester.createGesture(pointer: 2);
    await first.down(center + const Offset(0, -60));
    await second.down(center + const Offset(0, 60));
    await tester.pump();
    expect(pinching, isTrue);
    await first.moveTo(center + const Offset(0, -120));
    await second.moveTo(center + const Offset(0, 120));
    await tester.pump();
    expect(hourHeight, closeTo(120, 0.01));
    expect(sync.offset, closeTo(1210, 1));
    await first.up();
    await second.up();
    await tester.pump();
    expect(pinching, isFalse);

    final beforeDrag = sync.offset;
    await tester.drag(region, const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(hourHeight, closeTo(120, 0.01));
    expect(sync.offset, greaterThan(beforeDrag));

    final horizontalFirst = await tester.createGesture(pointer: 5);
    final horizontalSecond = await tester.createGesture(pointer: 6);
    await horizontalFirst.down(center + const Offset(-50, 0));
    await horizontalSecond.down(center + const Offset(50, 0));
    await horizontalFirst.moveTo(center + const Offset(-100, 0));
    await horizontalSecond.moveTo(center + const Offset(100, 0));
    await tester.pump();
    expect(hourHeight, closeTo(120, 0.01));
    await horizontalFirst.up();
    await horizontalSecond.up();
    await tester.pump();

    final third = await tester.createGesture(pointer: 3);
    final fourth = await tester.createGesture(pointer: 4);
    await third.down(center + const Offset(0, -150));
    await fourth.down(center + const Offset(0, 150));
    await tester.pump();
    await third.moveTo(center + const Offset(0, -15));
    await fourth.moveTo(center + const Offset(0, 15));
    await tester.pump();
    expect(hourHeight * 24, greaterThanOrEqualTo(500));
    expect(hourHeight, closeTo(500 / 24, 0.01));
    expect(sync.offset, closeTo(0, 0.01));
    await third.up();
    await fourth.up();
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
