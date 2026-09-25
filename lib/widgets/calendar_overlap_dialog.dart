import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:intl/intl.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';

import 'calendar_course_block.dart';
import 'calendar_course_layout.dart';

/// Shows every course in an overlap group with the same card style as the grid.
///
/// The Forui route supplies an animated blurred barrier. Its dismissible
/// barrier closes the popup when the user taps outside the dialog.
Future<void> showCalendarOverlapDialog(
  BuildContext context,
  CalendarCourseGroup group,
) {
  final l10n = AppLocalizations.of(context)!;
  final timeFormat = DateFormat.Hm(l10n.localeName);
  return showFDialog<void>(
    context: context,
    useSafeArea: true,
    barrierDismissible: true,
    routeStyle: FDialogRouteStyle.inherit(colors: context.theme.colors),
    builder: (context, style, animation) => FDialog.raw(
      animation: animation,
      semanticsLabel: l10n.calendarOverlappingPlans,
      builder: (context, style) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.calendarOverlappingPlans,
              style: context.theme.typography.lg,
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.65,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: group.courses.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final course = group.courses[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${timeFormat.format(course.startsAt)}–'
                        '${timeFormat.format(course.endsAt)}',
                        style: context.theme.typography.xs,
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 72,
                        child: LayoutBuilder(
                          builder: (context, constraints) =>
                              CalendarCourseBlock(
                                course: course,
                                width: constraints.maxWidth,
                                height: constraints.maxHeight,
                              ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
