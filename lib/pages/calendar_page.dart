// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:intl/intl.dart';
import 'package:thulium_campus/thulium_campus.dart';
import 'package:thulium_auth/thulium_auth.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';

import '../auth/secure_auth_session_store.dart';
import '../auth/secure_course_schedule_cache_store.dart';
import '../widgets/calendar_course_block.dart';
import '../widgets/calendar_course_layout.dart';
import '../widgets/calendar_now_line.dart';
import '../widgets/calendar_overlap_dialog.dart';
import '../widgets/calendar_week_pager.dart';

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

final class _AcademicCalendarPageState extends State<AcademicCalendarPage>
    with WidgetsBindingObserver {
  static const _HOUR_HEIGHT = 60.0;
  static const _FIRST_HOUR = 8;
  static const _LAST_HOUR = 22;
  static const _TIME_AXIS_WIDTH = 32.0;
  static const _LOAD_TIMEOUT = Duration(minutes: 2);

  CourseSchedule? _schedule;
  Object? _loadError;
  bool _isLoading = true;
  bool _showingStaleCache = false;
  int? _selectedWeek;
  final _weekPagerKey = GlobalKey<CalendarWeekPagerState>();
  final _now = ValueNotifier<DateTime>(DateTime.now());
  Timer? _nowTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Read the clock again on every tick instead of advancing a stored time;
    // this also corrects drift after the app has been suspended.
    _nowTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _now.value = DateTime.now(),
    );
    _loadSchedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _now.value = DateTime.now();
  }

  @override
  void dispose() {
    _nowTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _now.dispose();
    super.dispose();
  }

  Future<void> _loadSchedule({bool forceRefresh = false}) async {
    debugPrint('[calendar] loading started');
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final sessionStore = widget.sessionStore ?? SecureAuthSessionStore();
      final credentialStore = sessionStore is AuthCredentialStore
          ? sessionStore as AuthCredentialStore
          : null;
      final client = TsinghuaAuthClient(
        sessionStore: sessionStore,
        credentialStore: credentialStore,
        trace: (message) => debugPrint('[auth] $message'),
      );
      final savedSession = await client.restore();
      if (savedSession == null) throw const CourseScheduleSessionExpired();
      final cache = widget.sessionStore == null
          ? CourseScheduleCache(SecureCourseScheduleCacheStore())
          : null;
      final service = CourseScheduleService(
        client,
        cache: cache,
        trace: (message) => debugPrint('[calendar] $message'),
      );
      CourseSchedule schedule;
      try {
        schedule = await service
            .loadCurrentTerm(forceRefresh: forceRefresh)
            .timeout(_LOAD_TIMEOUT);
      } on CourseScheduleException catch (error) {
        if (error.cause is! PortalCsrfUnavailable) rethrow;
        // An empty WebVPN cookie response alone does not prove logout. Only
        // after the bounded cookie/SSO recovery fails do we try one fresh
        // password-based login, then repeat the calendar request once.
        if (!await _reconnect(client, credentialStore, savedSession)) rethrow;
        debugPrint('[calendar] reconnect succeeded; retrying once');
        schedule = await service
            .loadCurrentTerm(forceRefresh: true)
            .timeout(_LOAD_TIMEOUT);
      } on CourseScheduleSessionExpired {
        if (!await _reconnect(client, credentialStore, savedSession)) rethrow;
        debugPrint('[calendar] reconnect succeeded; retrying once');
        schedule = await service
            .loadCurrentTerm(forceRefresh: true)
            .timeout(_LOAD_TIMEOUT);
      }
      if (!mounted) return;
      debugPrint(
        '[calendar] loading completed occurrences=${schedule.occurrences.length}',
      );
      final todayWeek = schedule.term.weekFor(DateTime.now());
      setState(() {
        _schedule = schedule;
        _showingStaleCache =
            service.lastSource == CourseScheduleSource.staleCache;
        _selectedWeek = (_selectedWeek ?? todayWeek).clamp(
          1,
          schedule.term.weekCount,
        );
        _isLoading = false;
      });
    } on CourseScheduleSessionExpired {
      debugPrint('[calendar] session expired');
      widget.onSessionExpired();
    } on TwoFactorInteractionRequired {
      debugPrint('[calendar] interactive two-factor verification required');
      widget.onSessionExpired();
    } catch (error) {
      debugPrint('[calendar] loading failed type=${error.runtimeType}');
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _isLoading = false;
        _showingStaleCache = false;
      });
    }
  }

  Future<bool> _reconnect(
    TsinghuaAuthClient client,
    AuthCredentialStore? credentialStore,
    AuthSession savedSession,
  ) async {
    final credentials = await credentialStore?.readCredentials();
    if (credentials == null || credentials.userId != savedSession.userId) {
      debugPrint('[calendar] no matching saved credentials for reconnect');
      return false;
    }

    debugPrint('[calendar] reconnecting with saved credentials');
    try {
      await client
          .login(
            userId: savedSession.userId,
            password: credentials.password,
            fingerprint: savedSession.fingerprint,
          )
          .timeout(_LOAD_TIMEOUT);
      return true;
    } catch (error) {
      // A trusted device may not need a second factor; otherwise the regular
      // sign-in screen can collect one. Do not print secrets from the error.
      debugPrint(
        '[calendar] credential reconnect failed type=${error.runtimeType}',
      );
      rethrow;
    }
  }

  void _changeWeek(int delta) {
    _weekPagerKey.currentState?.animateBy(delta);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final schedule = _schedule;
    return Column(
      children: [
        _buildWeekControls(context, l10n, schedule),
        const SizedBox(height: 8),
        if (_showingStaleCache && !_isLoading && _loadError == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              l10n.calendarStaleCache,
              style: context.theme.typography.sm,
            ),
          ),
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
                    onPress: () => _loadSchedule(forceRefresh: true),
                    child: Text(l10n.calendarRetry),
                  ),
                ],
              ),
            ),
          )
        else if (schedule != null)
          Expanded(
            child: CalendarWeekPager(
              key: _weekPagerKey,
              weekCount: schedule.term.weekCount,
              initialWeek: _selectedWeek!,
              onWeekChanged: (week) => setState(() => _selectedWeek = week),
              itemBuilder: (context, week) =>
                  _buildWeekGrid(context, l10n, schedule, week),
            ),
          ),
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
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Tooltip(
                message: l10n.calendarRefresh,
                child: FButton(
                  variant: FButtonVariant.ghost,
                  size: FButtonSizeVariant.sm,
                  mainAxisSize: MainAxisSize.min,
                  onPress: _isLoading
                      ? null
                      : () => _loadSchedule(forceRefresh: true),
                  child: const Icon(Icons.refresh),
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: l10n.calendarPreviousWeek,
                child: FButton(
                  variant: FButtonVariant.ghost,
                  size: FButtonSizeVariant.sm,
                  mainAxisSize: MainAxisSize.min,
                  onPress: schedule == null || week == null || week <= 1
                      ? null
                      : () => _changeWeek(-1),
                  child: const Icon(Icons.chevron_left),
                ),
              ),
            ],
          ),
        ),
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
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Tooltip(
                message: l10n.calendarNextWeek,
                child: FButton(
                  variant: FButtonVariant.ghost,
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
                message: l10n.calendarExport,
                child: FButton(
                  variant: FButtonVariant.ghost,
                  size: FButtonSizeVariant.sm,
                  mainAxisSize: MainAxisSize.min,
                  onPress: null,
                  child: const Icon(Icons.ios_share_outlined),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeekGrid(
    BuildContext context,
    AppLocalizations l10n,
    CourseSchedule schedule,
    int week,
  ) {
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
                  Builder(
                    builder: (context) {
                      final date = weekStart.add(Duration(days: day));
                      final isToday = DateUtils.isSameDay(date, DateTime.now());
                      final colors = context.theme.colors;
                      final markerSize = math.min(dayWidth, 42.0);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: SizedBox.square(
                            dimension: markerSize,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isToday
                                    ? colors.foreground
                                    : Colors.transparent,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    DateFormat.E(locale).format(date),
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                    style: context.theme.typography.xs.copyWith(
                                      color: isToday
                                          ? colors.background
                                          : colors.foreground,
                                    ),
                                  ),
                                  Text(
                                    DateFormat.Md(locale).format(date),
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                    style: context.theme.typography.xs.copyWith(
                                      color: isToday
                                          ? colors.background
                                          : colors.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                child: SizedBox(
                  height: (_LAST_HOUR - _FIRST_HOUR) * _HOUR_HEIGHT,
                  child: Stack(
                    children: [
                      Row(
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
                      if (weekCourses.isEmpty)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Center(child: Text(l10n.calendarNoCourses)),
                          ),
                        ),
                      ValueListenableBuilder<DateTime>(
                        valueListenable: _now,
                        builder: (context, now, child) => CalendarNowLine(
                          now: now,
                          weekStart: weekStart,
                          firstHour: _FIRST_HOUR,
                          lastHour: _LAST_HOUR,
                          hourHeight: _HOUR_HEIGHT,
                          timeAxisWidth: _TIME_AXIS_WIDTH,
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
    final groups = layoutCalendarCourseGroups(dailyCourses);
    final colors = context.theme.colors;
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
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
          for (final group in groups)
            for (final placement in group.placements)
              _buildCourseBlock(context, placement, constraints.maxWidth),
          // Tap targets span each maximal continuous overlap region, not just
          // the narrow visible cards. Vertical scroll and week swipes still
          // win the gesture arena when the user drags instead of tapping.
          for (final group in groups)
            if (group.hasOverlap) _buildOverlapTarget(context, group),
        ],
      ),
    );
  }

  Widget _buildOverlapTarget(BuildContext context, CalendarCourseGroup group) {
    final startMinutes =
        (group.startsAt.hour - _FIRST_HOUR) * 60 + group.startsAt.minute;
    final endMinutes =
        (group.endsAt.hour - _FIRST_HOUR) * 60 + group.endsAt.minute;
    final totalMinutes = (_LAST_HOUR - _FIRST_HOUR) * 60;
    final clippedStart = startMinutes.clamp(0, totalMinutes);
    final clippedEnd = endMinutes.clamp(clippedStart, totalMinutes);
    return Positioned(
      top: clippedStart / 60 * _HOUR_HEIGHT,
      left: 0,
      right: 0,
      height: math.max(1, (clippedEnd - clippedStart) / 60 * _HOUR_HEIGHT),
      child: Semantics(
        button: true,
        label: AppLocalizations.of(context)!.calendarOverlappingPlans,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showCalendarOverlapDialog(context, group),
        ),
      ),
    );
  }

  Widget _buildCourseBlock(
    BuildContext context,
    CalendarCoursePlacement placement,
    double dayWidth,
  ) {
    final course = placement.course;
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
    final laneWidth = dayWidth / placement.laneCount;
    return Positioned(
      key: ValueKey(
        '${course.category}|${course.name}|${course.location}|'
        '${course.startsAt.toIso8601String()}|${course.endsAt.toIso8601String()}',
      ),
      top: top,
      left: placement.lane * laneWidth,
      width: laneWidth,
      height: height,
      child: Padding(
        // Keep even exceptionally narrow lanes visible without borrowing
        // pixels from their neighbors.
        padding: EdgeInsets.symmetric(horizontal: math.min(1, laneWidth / 8)),
        child: LayoutBuilder(
          builder: (context, constraints) => CalendarCourseBlock(
            course: course,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
          ),
        ),
      ),
    );
  }
}
