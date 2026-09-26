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
import '../auth/secure_custom_plan_store.dart';
import 'add_plan_page.dart';
import '../widgets/calendar_course_block.dart';
import '../widgets/calendar_course_layout.dart';
import '../widgets/calendar_now_line.dart';
import '../widgets/calendar_overlap_dialog.dart';
import '../widgets/calendar_plan_details_dialog.dart';
import '../widgets/calendar_week_pager.dart';
import '../widgets/calendar_week_scroll_sync.dart';

/// Displays fetched lessons and locally stored plans in a Monday-to-Sunday week.
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
  static const _FIRST_HOUR = 0;
  static const _LAST_HOUR = 24;
  static const _INITIAL_SCROLL_HOUR = 8;
  static const _TIME_AXIS_WIDTH = 32.0;
  static const _LOAD_TIMEOUT = Duration(minutes: 2);

  CourseSchedule? _schedule;
  CustomPlanCollection _customPlans = CustomPlanCollection.empty();
  String? _userId;
  final _customPlanStore = SecureCustomPlanStore();
  Object? _loadError;
  bool _isLoading = true;
  bool _showingStaleCache = false;
  int? _selectedWeek;
  late final _weekScrollSync = CalendarWeekScrollSync(
    initialOffset: _INITIAL_SCROLL_HOUR * _HOUR_HEIGHT,
  );
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
    _weekScrollSync.dispose();
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
      final customPlans = await _customPlanStore.readFor(savedSession.userId);
      if (!mounted) return;
      debugPrint(
        '[calendar] loading completed occurrences=${schedule.occurrences.length}',
      );
      final todayWeek = schedule.term.weekFor(DateTime.now());
      setState(() {
        _schedule = schedule;
        _customPlans = customPlans;
        _userId = savedSession.userId;
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

  Future<void> _addPlan() async {
    final schedule = _schedule;
    if (schedule == null || _userId == null) return;
    final week = _selectedWeek ?? 1;
    final monday = schedule.term.firstMonday.add(
      Duration(days: (week - 1) * 7),
    );
    final today = DateTime.now();
    final date =
        !today.isBefore(monday) &&
            today.isBefore(monday.add(const Duration(days: 7)))
        ? today
        : monday;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => AddPlanPage(
          initialDate: date,
          categories: _customPlans.categories,
          onSave: (plan, category) async {
            await _persistCustomPlans(
              _customPlans.copyWith(
                categories: [..._customPlans.categories, ?category],
                plans: [..._customPlans.plans, plan],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _persistCustomPlans(CustomPlanCollection next) async {
    final userId = _userId;
    if (userId == null) throw StateError('No student account is available.');
    await _customPlanStore.writeFor(userId, next);
    if (mounted) setState(() => _customPlans = next);
  }

  String _categoryName(AppLocalizations l10n, String category) {
    if (category == PlanCategories.LESSON) return l10n.planLessonCategory;
    for (final custom in _customPlans.categories) {
      if (custom.id == category) return custom.name;
    }
    return category;
  }

  String _repeatName(AppLocalizations l10n, CalendarPlanEntry entry) {
    final rule = entry.rule;
    if (rule == null) return l10n.planRepeatNone;
    return switch (rule.repeat) {
      PlanRepeat.none => l10n.planRepeatNone,
      PlanRepeat.daily => l10n.planRepeatDaily,
      PlanRepeat.weekly => l10n.planRepeatWeekly,
      PlanRepeat.intervalDays => l10n.planRepeatEveryDays(rule.intervalDays),
    };
  }

  Future<void> _showPlanDetails(
    BuildContext context,
    CalendarPlanEntry entry,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final action = await showCalendarPlanDetailsDialog(
      context,
      entry,
      categoryName: _categoryName(l10n, entry.occurrence.category),
      repeatLabel: _repeatName(l10n, entry),
    );
    if (!mounted || !context.mounted || action == null) return;
    switch (action) {
      case CalendarPlanAction.editOne:
      case CalendarPlanAction.editSeries:
        await _editPlan(
          context,
          entry,
          editSeries: action == CalendarPlanAction.editSeries,
        );
        return;
      case CalendarPlanAction.cancelOne:
      case CalendarPlanAction.deleteSeries:
        await _removePlanOccurrence(
          context,
          entry,
          deleteSeries: action == CalendarPlanAction.deleteSeries,
        );
        return;
    }
  }

  Future<void> _editPlan(
    BuildContext context,
    CalendarPlanEntry entry, {
    required bool editSeries,
  }) async {
    final initialRule = editSeries ? entry.rule! : null;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => AddPlanPage(
          initialDate: editSeries
              ? initialRule!.startsAt
              : entry.occurrence.startsAt,
          initialPlan: initialRule,
          initialOccurrence: editSeries ? null : entry.occurrence,
          singleOccurrence: !editSeries,
          categories: _customPlans.categories,
          onSave: (edited, category) async {
            final categories = [..._customPlans.categories, ?category];
            final next = editSeries
                ? _customPlans.replaceSeries(edited)
                : _customPlans.replaceOccurrence(
                    entry,
                    CourseOccurrence(
                      name: edited.name,
                      location: edited.location,
                      startsAt: edited.startsAt,
                      endsAt: edited.endsAt,
                      category: edited.category,
                    ),
                  );
            await _persistCustomPlans(next.copyWith(categories: categories));
          },
        ),
      ),
    );
  }

  Future<void> _removePlanOccurrence(
    BuildContext context,
    CalendarPlanEntry entry, {
    required bool deleteSeries,
  }) async {
    final skipWarning = deleteSeries
        ? _customPlans.skipDeleteConfirmation
        : _customPlans.skipCancelConfirmation;
    PlanConfirmationDecision? decision;
    if (!skipWarning) {
      decision = await showPlanActionConfirmation(
        context,
        deleteSeries: deleteSeries,
        repeating: entry.repeats,
        fetchedLesson: entry.fetchedLesson,
      );
      if (decision == null || !mounted || !context.mounted) return;
    }
    var next = deleteSeries
        ? _customPlans.deleteSeries(entry)
        : _customPlans.replaceOccurrence(entry, null);
    if (decision?.skipNextTime == true) {
      next = deleteSeries
          ? next.copyWith(skipDeleteConfirmation: true)
          : next.copyWith(skipCancelConfirmation: true);
    }
    try {
      await _persistCustomPlans(next);
    } catch (_) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      await showFDialog<void>(
        context: context,
        builder: (context, style, animation) => FDialog.adaptive(
          animation: animation,
          title: Text(l10n.planSaveError),
          actions: [
            FButton(
              onPress: () => Navigator.of(context).pop(),
              child: Text(l10n.confirmAction),
            ),
          ],
        ),
      );
    }
  }

  void _handleWeekChanged(int week) {
    setState(() => _selectedWeek = week);
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
              onWeekChanged: _handleWeekChanged,
              itemBuilder: (context, week) => _buildWeekGrid(
                context,
                l10n,
                schedule,
                week,
                _weekScrollSync.controllerForWeek(week),
              ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideWidth = math.min(128.0, constraints.maxWidth * 0.4);
        return Row(
          children: [
            SizedBox(
              width: sideWidth,
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
                  key: const ValueKey('calendar-week-label'),
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
            SizedBox(
              width: sideWidth,
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
                    message: l10n.planAddTitle,
                    child: FButton(
                      variant: FButtonVariant.ghost,
                      size: FButtonSizeVariant.sm,
                      mainAxisSize: MainAxisSize.min,
                      onPress: schedule == null || _userId == null
                          ? null
                          : _addPlan,
                      child: const Icon(Icons.add),
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
      },
    );
  }

  Widget _buildWeekGrid(
    BuildContext context,
    AppLocalizations l10n,
    CourseSchedule schedule,
    int week,
    ScrollController scrollController,
  ) {
    final weekStart = schedule.term.firstMonday.add(
      Duration(days: (week - 1) * 7),
    );
    final weekEnd = weekStart.add(const Duration(days: 7));
    final weekEntries = _customPlans.entriesForWeek(
      schedule.occurrences,
      weekStart,
      weekEnd,
    );
    final weekCourses = [for (final entry in weekEntries) entry.occurrence];
    final entryByCourse = {
      for (final entry in weekEntries) entry.occurrence: entry,
    };

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
                controller: scrollController,
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
                                entryByCourse,
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
    Map<CourseOccurrence, CalendarPlanEntry> entryByCourse,
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
              _buildCourseBlock(
                context,
                placement,
                constraints.maxWidth,
                entryByCourse[placement.course]!,
              ),
          // Tap targets span each maximal continuous overlap region, not just
          // the narrow visible cards. Vertical scroll and week swipes still
          // win the gesture arena when the user drags instead of tapping.
          for (final group in groups)
            if (group.hasOverlap)
              _buildOverlapTarget(context, group, entryByCourse),
        ],
      ),
    );
  }

  Widget _buildOverlapTarget(
    BuildContext context,
    CalendarCourseGroup group,
    Map<CourseOccurrence, CalendarPlanEntry> entryByCourse,
  ) {
    final dayStart = DateTime(
      group.startsAt.year,
      group.startsAt.month,
      group.startsAt.day,
    );
    final startMinutes =
        group.startsAt.difference(dayStart).inMinutes - _FIRST_HOUR * 60;
    final endMinutes =
        group.endsAt.difference(dayStart).inMinutes - _FIRST_HOUR * 60;
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
          onTap: () async {
            final selected = await showCalendarOverlapDialog(
              context,
              group,
              categoryColor: _colorForCategory,
            );
            if (selected != null && context.mounted) {
              await _showPlanDetails(context, entryByCourse[selected]!);
            }
          },
        ),
      ),
    );
  }

  Widget _buildCourseBlock(
    BuildContext context,
    CalendarCoursePlacement placement,
    double dayWidth,
    CalendarPlanEntry entry,
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showPlanDetails(context, entry),
        child: Padding(
          // Keep even exceptionally narrow lanes visible without borrowing
          // pixels from their neighbors.
          padding: EdgeInsets.symmetric(horizontal: math.min(1, laneWidth / 8)),
          child: LayoutBuilder(
            builder: (context, constraints) => CalendarCourseBlock(
              course: course,
              categoryColor: _colorForCategory(course.category),
              width: constraints.maxWidth,
              height: constraints.maxHeight,
            ),
          ),
        ),
      ),
    );
  }

  Color? _colorForCategory(String category) {
    for (final custom in _customPlans.categories) {
      if (custom.id == category) return Color(custom.colorValue);
    }
    return null;
  }
}
