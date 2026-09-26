import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// A non-interactive current-time marker across all seven day columns.
///
/// The line appears only for the actual current week and during the hours
/// represented by the vertical calendar grid.
final class CalendarNowLine extends StatelessWidget {
  const CalendarNowLine({
    required this.now,
    required this.weekStart,
    required this.firstHour,
    required this.lastHour,
    required this.hourHeight,
    required this.timeAxisWidth,
    super.key,
  });

  final DateTime now;
  final DateTime weekStart;
  final int firstHour;
  final int lastHour;
  final double hourHeight;
  final double timeAxisWidth;

  @override
  Widget build(BuildContext context) {
    final weekEnd = weekStart.add(const Duration(days: DateTime.daysPerWeek));
    if (now.isBefore(weekStart) || !now.isBefore(weekEnd)) {
      return const SizedBox.shrink();
    }

    final minutesSinceMidnight = now.hour * 60 + now.minute;
    if (minutesSinceMidnight < firstHour * 60 ||
        minutesSinceMidnight >= lastHour * 60) {
      return const SizedBox.shrink();
    }

    final elapsedHours =
        now.hour -
        firstHour +
        now.minute / 60 +
        now.second / 3600 +
        now.millisecond / 3600000;
    return Positioned(
      key: const ValueKey('calendar-now-line'),
      top: elapsedHours * hourHeight,
      left: timeAxisWidth,
      right: 0,
      height: 1,
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: ColoredBox(color: context.theme.colors.primary),
        ),
      ),
    );
  }
}
