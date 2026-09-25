// ignore_for_file: constant_identifier_names

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:thulium_campus/thulium_campus.dart';

/// A course card whose text layout responds to the available day-column width.
///
/// The card follows its column immediately. Only its text animates between
/// fully rotated and fully upright layouts, avoiding intermediate angles.
final class CalendarCourseBlock extends StatefulWidget {
  const CalendarCourseBlock({
    required this.course,
    required this.width,
    required this.height,
    super.key,
  });

  final CourseOccurrence course;
  final double width;
  final double height;

  @override
  State<CalendarCourseBlock> createState() => _CalendarCourseBlockState();
}

final class _CalendarCourseBlockState extends State<CalendarCourseBlock> {
  static const _WIDE_ENTER_WIDTH = 96.0;
  static const _WIDE_EXIT_WIDTH = 80.0;
  static const _TEXT_DURATION = Duration(milliseconds: 190);

  bool? _isWide;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: '${widget.course.name}, ${widget.course.location}',
      child: Container(
        key: const ValueKey('calendar-course-surface'),
        width: widget.width,
        height: widget.height,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.2),
          border: Border.all(color: colors.primary, width: 0.8),
          borderRadius: BorderRadius.circular(5),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            // Separate enter/exit thresholds prevent orientation flicker
            // when resizing a window near the layout boundary.
            final wasWide = _isWide ?? width >= _WIDE_ENTER_WIDTH;
            final isWide = wasWide
                ? width > _WIDE_EXIT_WIDTH
                : width >= _WIDE_ENTER_WIDTH;
            _isWide = isWide;

            return ExcludeSemantics(
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
                      scale: Tween<double>(begin: 0.96, end: 1).animate(reveal),
                      child: child,
                    ),
                  );
                },
                child: SizedBox(
                  key: ValueKey(isWide),
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: isWide
                      ? _courseText(context, wide: true)
                      : RotatedBox(
                          quarterTurns: 1,
                          child: _courseText(context, wide: false),
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _courseText(BuildContext context, {required bool wide}) {
    final colors = context.theme.colors;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: wide ? 6 : 3, vertical: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: wide
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Text(
            widget.course.name,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: context.theme.typography.xs.copyWith(
              color: colors.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
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
