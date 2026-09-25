// ignore_for_file: constant_identifier_names

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:intl/intl.dart';
import 'package:thulium_campus/thulium_campus.dart';
import 'package:thulium_auth/thulium_auth.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';

import '../auth/secure_auth_session_store.dart';

/// Displays one Monday-to-Sunday week of the student's fetched courses.
final class AcademicCalendarPage extends StatefulWidget {
  const AcademicCalendarPage({
    required this.onSessionExpired,
    this.sessionStore,
    super.key,
  });

  final VoidCallback onSessionExpired;
  final AuthSessionStore? sessionStore;

  @override
  State<AcademicCalendarPage> createState() => _AcademicCalendarPageState();
}

final class _AcademicCalendarPageState extends State<AcademicCalendarPage> {
  static const _HOUR_HEIGHT = 60.0;
  static const _FIRST_HOUR = 8;
  static const _LAST_HOUR = 22;
  static const _TIME_AXIS_WIDTH = 36.0;

  CourseSchedule? _schedule;
  Object? _loadError;
  bool _isLoading = true;
  int? _selectedWeek;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final client = TsinghuaAuthClient(
        sessionStore: widget.sessionStore ?? SecureAuthSessionStore(),
      );
      final schedule = await CourseScheduleService(client).loadCurrentTerm();
      if (!mounted) return;
      final todayWeek = schedule.term.weekFor(DateTime.now());
      setState(() {
        _schedule = schedule;
        _selectedWeek = (_selectedWeek ?? todayWeek).clamp(
          1,
          schedule.term.weekCount,
        );
        _isLoading = false;
      });
    } on CourseScheduleSessionExpired {
      widget.onSessionExpired();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  void _changeWeek(int delta) {
    final schedule = _schedule;
    if (schedule == null) return;
    setState(() {
      _selectedWeek = (_selectedWeek! + delta).clamp(
        1,
        schedule.term.weekCount,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final schedule = _schedule;
    return Column(
      children: [
        _buildWeekControls(context, l10n, schedule),
        const SizedBox(height: 8),
        if (_isLoading)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FCircularProgress(
                    size: FCircularProgressSizeVariant.md,
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.calendarLoading),
                ],
              ),
            ),
          )
        else if (_loadError != null)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.calendarLoadError),
                  const SizedBox(height: 12),
                  FButton(
                    variant: FButtonVariant.outline,
                    onPress: _loadSchedule,
                    child: Text(l10n.calendarRetry),
                  ),
                ],
              ),
            ),
          )
        else if (schedule != null)
          Expanded(child: _buildWeekGrid(context, l10n, schedule)),
      ],
    );
  }

  Widget _buildWeekControls(
    BuildContext context,
    AppLocalizations l10n,
    CourseSchedule? schedule,
  ) {
    final week = _selectedWeek;
    return Row(
      children: [
        Tooltip(
          message: l10n.calendarPreviousWeek,
          child: FButton(
            variant: FButtonVariant.outline,
            size: FButtonSizeVariant.sm,
            mainAxisSize: MainAxisSize.min,
            onPress: schedule == null || week == null || week <= 1
                ? null
                : () => _changeWeek(-1),
            child: const Icon(Icons.chevron_left),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Center(
            child: Text(
              week == null
                  ? schedule?.term.name ?? ''
                  : l10n.calendarWeek(week),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.theme.typography.md.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: l10n.calendarNextWeek,
          child: FButton(
            variant: FButtonVariant.outline,
            size: FButtonSizeVariant.sm,
            mainAxisSize: MainAxisSize.min,
            onPress:
                schedule == null ||
                    week == null ||
                    week >= schedule.term.weekCount
                ? null
                : () => _changeWeek(1),
            child: const Icon(Icons.chevron_right),
          ),
        ),
        const SizedBox(width: 4),
        Tooltip(
          message: l10n.calendarRefresh,
          child: FButton(
            variant: FButtonVariant.ghost,
            size: FButtonSizeVariant.sm,
            mainAxisSize: MainAxisSize.min,
            onPress: _isLoading ? null : _loadSchedule,
            child: const Icon(Icons.refresh),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekGrid(
    BuildContext context,
    AppLocalizations l10n,
    CourseSchedule schedule,
  ) {
    final week = _selectedWeek!;
    final weekStart = schedule.term.firstMonday.add(
      Duration(days: (week - 1) * 7),
    );
    final weekEnd = weekStart.add(const Duration(days: 7));
    final weekCourses = schedule.occurrences
        .where(
          (course) =>
              !course.startsAt.isBefore(weekStart) &&
              course.startsAt.isBefore(weekEnd),
        )
        .toList(growable: false);

    if (weekCourses.isEmpty) {
      return Center(child: Text(l10n.calendarNoCourses));
    }

    final locale = l10n.localeName;
    return LayoutBuilder(
      builder: (context, constraints) {
        final dayWidth =
            (constraints.maxWidth - _TIME_AXIS_WIDTH) / DateTime.daysPerWeek;
        return Column(
          children: [
            Row(
              children: [
                const SizedBox(width: _TIME_AXIS_WIDTH),
                for (var day = 0; day < DateTime.daysPerWeek; day++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          Text(
                            DateFormat.E(
                              locale,
                            ).format(weekStart.add(Duration(days: day))),
                            maxLines: 1,
                            style: context.theme.typography.xs,
                          ),
                          Text(
                            DateFormat.Md(
                              locale,
                            ).format(weekStart.add(Duration(days: day))),
                            maxLines: 1,
                            style: context.theme.typography.xs.copyWith(
                              color: context.theme.colors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                child: SizedBox(
                  height: (_LAST_HOUR - _FIRST_HOUR) * _HOUR_HEIGHT,
                  child: Row(
                    children: [
                      SizedBox(
                        width: _TIME_AXIS_WIDTH,
                        child: _buildTimeAxis(context),
                      ),
                      for (var day = 0; day < DateTime.daysPerWeek; day++)
                        SizedBox(
                          width: dayWidth,
                          child: _buildDayColumn(
                            context,
                            weekStart.add(Duration(days: day)),
                            weekCourses,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimeAxis(BuildContext context) => Stack(
    children: [
      for (var hour = _FIRST_HOUR; hour <= _LAST_HOUR; hour++)
        Positioned(
          top: (hour - _FIRST_HOUR) * _HOUR_HEIGHT - 7,
          left: 0,
          right: 4,
          child: Text(
            '${hour.toString().padLeft(2, '0')}:00',
            textAlign: TextAlign.right,
            style: context.theme.typography.xs.copyWith(
              color: context.theme.colors.mutedForeground,
              fontSize: 9,
            ),
          ),
        ),
    ],
  );

  Widget _buildDayColumn(
    BuildContext context,
    DateTime date,
    List<CourseOccurrence> weekCourses,
  ) {
    final dailyCourses = weekCourses
        .where(
          (course) =>
              course.startsAt.year == date.year &&
              course.startsAt.month == date.month &&
              course.startsAt.day == date.day,
        )
        .toList(growable: false);
    final colors = context.theme.colors;
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        for (var hour = 0; hour <= _LAST_HOUR - _FIRST_HOUR; hour++)
          Positioned(
            top: hour * _HOUR_HEIGHT,
            left: 0,
            right: 0,
            child: Container(
              height: _HOUR_HEIGHT,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: colors.border, width: 0.5),
                  left: BorderSide(color: colors.border, width: 0.5),
                ),
              ),
            ),
          ),
        for (final course in dailyCourses) _buildCourseBlock(context, course),
      ],
    );
  }

  Widget _buildCourseBlock(BuildContext context, CourseOccurrence course) {
    final startMinutes =
        (course.startsAt.hour - _FIRST_HOUR) * 60 + course.startsAt.minute;
    final durationMinutes = course.endsAt.difference(course.startsAt).inMinutes;
    final totalMinutes = (_LAST_HOUR - _FIRST_HOUR) * 60;
    final clippedStart = startMinutes.clamp(0, totalMinutes);
    final clippedEnd = (startMinutes + durationMinutes).clamp(
      clippedStart,
      totalMinutes,
    );
    final top = clippedStart / 60 * _HOUR_HEIGHT;
    final height = math.max(
      30.0,
      (clippedEnd - clippedStart) / 60 * _HOUR_HEIGHT - 2,
    );
    final colors = context.theme.colors;
    return Positioned(
      top: top,
      left: 1,
      right: 1,
      height: height,
      child: Semantics(
        label: '${course.name}, ${course.location}',
        child: LayoutBuilder(
          builder: (context, constraints) => Container(
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.2),
              border: Border.all(color: colors.primary, width: 0.8),
              borderRadius: BorderRadius.circular(5),
            ),
            child: RotatedBox(
              quarterTurns: 1,
              child: SizedBox(
                width: constraints.maxHeight,
                height: constraints.maxWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        course.name,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: context.theme.typography.xs.copyWith(
                          color: colors.foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        course.location,
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
