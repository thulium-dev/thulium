// ignore_for_file: constant_identifier_names

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:thulium_campus/thulium_campus.dart';

/// Displays a plan using the text that its allocated lane can actually fit.
///
/// A very narrow lane keeps its full hit/semantics area but paints only a
/// centered vertical stroke. Wider lanes add the name, then the location,
/// while keeping both lines rotated until the horizontal layout fits.
/// Only text changes are animated.
final class CalendarCourseBlock extends StatefulWidget {
  const CalendarCourseBlock({
    required this.course,
    required this.width,
    required this.height,
    this.categoryColor,
    super.key,
  });

  final CourseOccurrence course;
  final double width;
  final double height;
  final Color? categoryColor;

  @override
  State<CalendarCourseBlock> createState() => _CalendarCourseBlockState();
}

final class _CalendarCourseBlockState extends State<CalendarCourseBlock> {
  static const _MIN_NAME_WIDTH = 12.0;
  static const _MIN_LOCATION_WIDTH = 36.0;
  static const _MIN_HORIZONTAL_WIDTH = 96.0;
  static const _TEXT_DURATION = Duration(milliseconds: 190);

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final surfaceColor = widget.categoryColor ?? colors.primary;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: '${widget.course.name}, ${widget.course.location}',
      child: SizedBox(
        key: const ValueKey('calendar-course-surface'),
        width: widget.width,
        height: widget.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            if (constraints.maxHeight < 18) {
              // At a full-day zoom, short events must keep their true time
              // height instead of expanding over neighboring events.
              return ExcludeSemantics(
                child: DecoratedBox(
                  key: const ValueKey('calendar-course-compact'),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }
            if (width < _MIN_NAME_WIDTH) {
              return ExcludeSemantics(
                child: Center(
                  child: Container(
                    key: const ValueKey('calendar-course-line'),
                    width: width.clamp(0.0, 4.0),
                    height: (constraints.maxHeight - 4).clamp(
                      0.0,
                      double.infinity,
                    ),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            }

            // Content density and orientation are independent decisions: a
            // rotated two-line label fits long before an upright one does.
            final showLocation = width >= _MIN_LOCATION_WIDTH;
            final horizontal = width >= _MIN_HORIZONTAL_WIDTH;
            return Container(
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: surfaceColor.withValues(alpha: 0.2),
                border: Border.all(color: surfaceColor, width: 0.8),
                borderRadius: BorderRadius.circular(5),
              ),
              child: ExcludeSemantics(
                child: AnimatedSwitcher(
                  duration: reducedMotion ? Duration.zero : _TEXT_DURATION,
                  // The old text fades out before the new layout fades in.
                  transitionBuilder: (child, animation) {
                    final reveal = CurvedAnimation(
                      parent: animation,
                      curve: const Interval(0.5, 1, curve: Curves.easeOut),
                    );
                    return FadeTransition(
                      opacity: reveal,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.96,
                          end: 1,
                        ).animate(reveal),
                        child: child,
                      ),
                    );
                  },
                  child: SizedBox(
                    key: ValueKey((showLocation, horizontal)),
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: horizontal
                        ? _courseText(
                            context,
                            showLocation: showLocation,
                            horizontal: true,
                            availableWidth: width,
                          )
                        : RotatedBox(
                            quarterTurns: 1,
                            child: _courseText(
                              context,
                              showLocation: showLocation,
                              horizontal: false,
                              availableWidth: width,
                            ),
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _courseText(
    BuildContext context, {
    required bool showLocation,
    required bool horizontal,
    required double availableWidth,
  }) {
    final colors = context.theme.colors;
    // At the smallest text-capable width, the normal line height would be
    // taller than the rotated lane. Keep the name legible without overflowing.
    final compactName = !horizontal && availableWidth < 24;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontal ? 6 : 3,
        vertical: compactName ? 0 : 2,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        // For rotated labels, the text control's left edge maps to the top
        // edge of the course block. Keep every plan's text origin aligned.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.course.name,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: context.theme.typography.xs.copyWith(
              color: colors.foreground,
              fontWeight: FontWeight.w600,
              fontSize: compactName ? 9 : null,
              height: compactName ? 1 : null,
            ),
          ),
          if (showLocation)
            Text(
              widget.course.location,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: context.theme.typography.xs.copyWith(
                color: colors.mutedForeground,
                fontSize: 9,
              ),
            ),
        ],
      ),
    );
  }
}
