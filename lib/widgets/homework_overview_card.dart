import 'dart:async';

import 'package:flutter/material.dart' show Icons, RefreshIndicator;
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:intl/intl.dart';
import 'package:thulium_campus/thulium_campus.dart';

import '../homework/homework_presentation.dart';
import '../homework/homework_urgency.dart';
import '../homework/homework_theme.dart';
import 'scrolling_badge.dart';
import '../l10n/generated/app_localizations.dart';

/// Presentation of the existing snapshot. No network, cache, or submission
/// state is owned here. The historic class name is retained for its callers.
final class HomeworkOverviewCard extends StatefulWidget {
  const HomeworkOverviewCard({
    required this.assignments,
    required this.isLoading,
    required this.failed,
    required this.onRefresh,
    this.hasSnapshot = false,
    this.isStale = false,
    this.updatedAt,
    this.now,
    this.deviceTimeZoneOffset,
    this.actions = const HomeworkActions(),
    this.countsTowardGrade,
    super.key,
  });

  final List<LearnHomework> assignments;
  final bool isLoading;
  final bool failed;
  final FutureOr<void> Function() onRefresh;
  final bool hasSnapshot;
  final bool isStale;
  final DateTime? updatedAt;
  final DateTime? now;
  final Duration? deviceTimeZoneOffset;
  final HomeworkActions actions;

  /// Unknown grading policy stays null; only explicit false shows a badge.
  final bool? Function(LearnHomework)? countsTowardGrade;

  @override
  State<HomeworkOverviewCard> createState() => _HomeworkOverviewCardState();
}

final class _HomeworkOverviewCardState extends State<HomeworkOverviewCard>
    with WidgetsBindingObserver {
  Timer? _timer;
  late DateTime _now;
  late DateTime _enteredAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enter();
  }

  void _enter() {
    _enteredAt = _now = widget.now ?? DateTime.now();
    _scheduleUrgentUpdates();
  }

  void _scheduleUrgentUpdates() {
    _timer?.cancel();
    if (widget.now != null ||
        !widget.assignments.any(
          (item) =>
              homeworkUrgency(item.deadline, _now) ==
              HomeworkUrgency.withinHour,
        )) {
      return;
    }
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      if (!widget.assignments.any(
        (item) =>
            homeworkUrgency(item.deadline, _now) == HomeworkUrgency.withinHour,
      )) {
        _timer?.cancel();
      }
    });
  }

  @override
  void didUpdateWidget(covariant HomeworkOverviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _enter();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(_enter);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refresh() async => await widget.onRefresh();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final gap = theme.style.pagePadding.top;
    final groups = groupHomework(widget.assignments, _now);
    return ColoredBox(
      color: theme.colors.background,
      child: FScaffold(
        childPad: false,
        header: FHeader(
          title: Text(
            l10n.homeworkTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: theme.colors.foreground,
          backgroundColor: theme.colors.background,
          semanticsLabel: l10n.homeworkRefresh,
          child: ListView(
            key: const ValueKey('homework-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: theme.style.pagePadding,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: gap,
                runSpacing: gap,
                children: [
                  _UpdateAge(updatedAt: widget.updatedAt, now: widget.now),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: theme.style.sizes.tile,
                      minWidth: theme.style.sizes.tile,
                    ),
                    child: FButton.icon(
                      size: FButtonSizeVariant.lg,
                      variant: FButtonVariant.ghost,
                      semanticsLabel: l10n.homeworkRefresh,
                      onPress: widget.isLoading
                          ? null
                          : () => unawaited(_refresh()),
                      child: const Icon(Icons.refresh),
                    ),
                  ),
                ],
              ),
              SizedBox(height: gap),
              if (widget.isStale) ...[
                FAlert(title: Text(l10n.homeworkStale)),
                SizedBox(height: gap),
              ],
              if (widget.isLoading && !widget.hasSnapshot)
                _HomeworkSkeleton(label: l10n.homeworkLoading)
              else if (widget.failed) ...[
                FAlert(title: Text(l10n.homeworkLoadError)),
                SizedBox(height: gap),
                FButton(
                  onPress: () => unawaited(_refresh()),
                  child: Flexible(
                    child: Text(
                      l10n.calendarRetry,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ] else if (groups.isEmpty)
                Padding(
                  padding: theme.style.pagePadding,
                  child: Text(l10n.homeworkEmpty, style: theme.typography.lg),
                )
              else
                for (final entry in groups.entries) ...[
                  SizedBox(height: gap),
                  SizedBox(
                    width: double.infinity,
                    child: FTileGroup(
                      intrinsicWidth: false,
                      physics: const NeverScrollableScrollPhysics(),
                      divider: FItemDivider.full,
                      label: Row(
                        children: [
                          Expanded(child: Text(_groupName(l10n, entry.key))),
                          FBadge(
                            variant: FBadgeVariant.outline,
                            child: Text(
                              NumberFormat.decimalPattern(
                                l10n.localeName,
                              ).format(entry.value.length),
                            ),
                          ),
                        ],
                      ),
                      children: [
                        for (final item in entry.value)
                          FTile.raw(
                            style: homeworkTileStyle(theme),
                            key: ValueKey(
                              'homework-${item.course.id}-${item.id}',
                            ),
                            onPress: () => _showDetails(context, item),
                            onLongPress: () => _showActions(context, item),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: theme.style.sizes.tile,
                              ),
                              child: Padding(
                                padding: theme.style.pagePadding,
                                child: _AssignmentContent(
                                  homework: item,
                                  now: _rowNow(item),
                                  deviceOffset:
                                      widget.deviceTimeZoneOffset ??
                                      DateTime.now().timeZoneOffset,
                                  countsTowardGrade: widget.countsTowardGrade
                                      ?.call(item),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: gap),
                ],
            ],
          ),
        ),
      ),
    );
  }

  DateTime _rowNow(LearnHomework item) =>
      homeworkUrgency(item.deadline, _enteredAt) == HomeworkUrgency.withinHour
      ? _now
      : _enteredAt;

  Future<void> _showDetails(
    BuildContext context,
    LearnHomework homework,
  ) async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, _, _) {
          final l10n = AppLocalizations.of(context)!;
          final theme = context.theme;
          return FScaffold(
            header: FHeader.nested(
              title: Text(l10n.homeworkDetails),
              prefixes: [
                FButton.icon(
                  size: FButtonSizeVariant.lg,
                  variant: FButtonVariant.ghost,
                  semanticsLabel: l10n.homeworkBack,
                  onPress: () => Navigator.of(context).pop(),
                  child: const Icon(FLucideIcons.arrowLeft),
                ),
              ],
            ),
            child: ListView(
              padding: theme.style.pagePadding,
              children: [
                FTileGroup(
                  intrinsicWidth: false,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    FTile.raw(
                      style: homeworkTileStyle(theme),
                      child: Padding(
                        padding: theme.style.pagePadding,
                        child: _AssignmentContent(
                          homework: homework,
                          now: widget.now ?? DateTime.now(),
                          deviceOffset:
                              widget.deviceTimeZoneOffset ??
                              DateTime.now().timeZoneOffset,
                          countsTowardGrade: widget.countsTowardGrade?.call(
                            homework,
                          ),
                          fullTitle: true,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: theme.style.pagePadding.top),
                FButton(
                  variant: FButtonVariant.outline,
                  onPress: () => _showActions(context, homework),
                  child: Flexible(
                    child: Text(
                      l10n.homeworkActions,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (mounted) setState(_enter);
  }

  void _showActions(BuildContext context, LearnHomework homework) {
    final l10n = AppLocalizations.of(context)!;
    final options = [
      (l10n.homeworkOpenWeb, widget.actions.openWeb),
      (l10n.homeworkRemindLater, widget.actions.remindLater),
      (l10n.homeworkMarkSubmitted, widget.actions.markSubmitted),
    ];
    unawaited(
      showFSheet<void>(
        context: context,
        side: FLayout.btt,
        useSafeArea: true,
        builder: (sheetContext) => SingleChildScrollView(
          padding: sheetContext.theme.style.pagePadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.homeworkActions,
                style: sheetContext.theme.typography.lg,
              ),
              if (options.any((option) => option.$2 == null)) ...[
                SizedBox(height: sheetContext.theme.style.pagePadding.top),
                FAlert(title: Text(l10n.homeworkActionsUnavailable)),
              ],
              for (final option in options) ...[
                SizedBox(height: sheetContext.theme.style.pagePadding.top),
                FButton(
                  size: FButtonSizeVariant.lg,
                  variant: FButtonVariant.outline,
                  onPress: option.$2 == null
                      ? null
                      : () {
                          Navigator.of(sheetContext).pop();
                          unawaited(_execute(context, option.$2!, homework));
                        },
                  child: Flexible(
                    child: Text(option.$1, textAlign: TextAlign.center),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _execute(
    BuildContext context,
    Future<void> Function(LearnHomework) action,
    LearnHomework homework,
  ) async {
    try {
      await action(homework);
    } on Object {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      await showFDialog<void>(
        context: context,
        builder: (context, _, animation) => FDialog.adaptive(
          animation: animation,
          title: Text(l10n.homeworkActionFailed),
          actions: [
            FButton(
              onPress: () => Navigator.of(context).pop(),
              child: Flexible(
                child: Text(l10n.confirmAction, textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      );
    }
  }
}

class _AssignmentContent extends StatelessWidget {
  const _AssignmentContent({
    required this.homework,
    required this.now,
    required this.deviceOffset,
    this.countsTowardGrade,
    this.fullTitle = false,
  });
  final LearnHomework homework;
  final DateTime now;
  final Duration deviceOffset;
  final bool? countsTowardGrade;
  final bool fullTitle;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final gap = theme.style.pagePadding.top;
    final urgency = homeworkUrgency(homework.deadline, now);
    final palette =
        theme.extensions.whereType<HomeworkPalette>().firstOrNull ??
        HomeworkPalette.forBrightness(theme.colors.brightness);
    final statusColor = switch (urgency) {
      HomeworkUrgency.expired ||
      HomeworkUrgency.unknown => readableSecondary(theme),
      HomeworkUrgency.withinHour ||
      HomeworkUrgency.withinDay => theme.colors.destructive,
      HomeworkUrgency.withinThreeDays => palette.yellow,
      HomeworkUrgency.later => palette.green,
    };
    final muted =
        urgency == HomeworkUrgency.expired ||
        urgency == HomeworkUrgency.unknown;
    final background = muted ? theme.colors.secondary : statusColor;
    final foreground = muted
        ? theme.colors.secondaryForeground
        : badgeTextOn(theme, background);
    final badgeStyle = theme.badgeStyles.secondary.copyWith(
      decoration: DecorationDelta.shapeDelta(color: background),
      contentStyle: FBadgeContentStyleDelta.delta(
        labelTextStyle: TextStyleDelta.delta(color: foreground),
      ),
    );
    final locale = l10n.localeName;
    final deadline = homework.deadline;
    final date = deadline == null
        ? l10n.homeworkUnknownDeadline
        : l10n.homeworkDeadline(
            DateFormat.yMMMd(locale).add_Hm().format(beijingTime(deadline)),
          );
    final course =
        Localizations.localeOf(context).languageCode == 'en' &&
            homework.course.englishName.isNotEmpty
        ? homework.course.englishName
        : homework.course.name;
    final secondary = theme.typography.xs.copyWith(
      color: readableSecondary(theme),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Text(
                homework.title,
                maxLines: fullTitle ? null : 2,
                overflow: fullTitle ? null : TextOverflow.ellipsis,
                style: theme.typography.sm.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(width: gap),
            Flexible(
              flex: 2,
              child: Align(
                alignment: AlignmentDirectional.topEnd,
                child: ScrollingBadge(
                  label: _urgencyName(l10n, urgency),
                  style: badgeStyle,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: gap),
        Text(course, style: secondary),
        SizedBox(height: gap),
        Wrap(
          spacing: gap,
          runSpacing: gap,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              deviceOffset == const Duration(hours: 8)
                  ? date
                  : '$date · ${l10n.homeworkRowTimezone}',
              style: secondary,
            ),
            if (deadline != null && deadline.isAfter(now))
              Text(
                _countdown(l10n, deadline, now),
                key: ValueKey('homework-countdown-${homework.id}'),
                style: secondary.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            if (countsTowardGrade == false)
              FBadge(
                variant: FBadgeVariant.outline,
                child: Text(l10n.homeworkNoGrade),
              ),
          ],
        ),
      ],
    );
  }
}

class _HomeworkSkeleton extends StatelessWidget {
  const _HomeworkSkeleton({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final gap = theme.style.pagePadding.top;
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Column(
          children: [
            for (var index = 0; index < 3; index++)
              Padding(
                padding: theme.style.pagePadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final size in [
                      theme.typography.sm.fontSize!,
                      theme.typography.xs.fontSize!,
                      theme.typography.xs.fontSize!,
                    ]) ...[
                      Container(
                        height: size,
                        width: index.isEven
                            ? double.infinity
                            : theme.style.sizes.tile * 4,
                        decoration: BoxDecoration(
                          color: theme.colors.muted,
                          borderRadius: theme.style.borderRadius.sm,
                        ),
                      ),
                      SizedBox(height: gap),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UpdateAge extends StatefulWidget {
  const _UpdateAge({required this.updatedAt, this.now});
  final DateTime? updatedAt;
  final DateTime? now;
  @override
  State<_UpdateAge> createState() => _UpdateAgeState();
}

class _UpdateAgeState extends State<_UpdateAge> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    if (widget.now == null) {
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final updatedAt = widget.updatedAt;
    final minutes = updatedAt == null
        ? null
        : (widget.now ?? DateTime.now()).difference(updatedAt).inMinutes;
    final label = minutes == null
        ? l10n.homeworkNeverUpdated
        : minutes <= 0
        ? l10n.homeworkUpdatedNow
        : l10n.homeworkUpdatedMinutes(minutes);
    return Text(
      label,
      style: context.theme.typography.xs.copyWith(
        color: readableSecondary(context.theme),
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

String _groupName(AppLocalizations l10n, HomeworkGroup group) =>
    switch (group) {
      HomeworkGroup.overdue => l10n.homeworkGroupOverdue,
      HomeworkGroup.today => l10n.homeworkGroupToday,
      HomeworkGroup.thisWeek => l10n.homeworkGroupThisWeek,
      HomeworkGroup.later => l10n.homeworkGroupLater,
    };
String _urgencyName(AppLocalizations l10n, HomeworkUrgency urgency) =>
    switch (urgency) {
      HomeworkUrgency.expired => l10n.homeworkExpired,
      HomeworkUrgency.withinHour => l10n.homeworkWithinHour,
      HomeworkUrgency.withinDay => l10n.homeworkWithinDay,
      HomeworkUrgency.withinThreeDays => l10n.homeworkWithinThreeDays,
      HomeworkUrgency.later => l10n.homeworkLater,
      HomeworkUrgency.unknown => l10n.homeworkUnknownDeadline,
    };
String _countdown(AppLocalizations l10n, DateTime? deadline, DateTime now) {
  if (deadline == null) return l10n.homeworkUnknownDeadline;
  final remaining = deadline.difference(now);
  if (remaining <= Duration.zero) return l10n.homeworkExpired;
  if (remaining.inDays > 0) {
    return l10n.homeworkRemainingDays(remaining.inDays, remaining.inHours % 24);
  }
  if (remaining.inHours > 0) {
    return l10n.homeworkRemainingHours(
      remaining.inHours,
      remaining.inMinutes % 60,
    );
  }
  return l10n.homeworkRemainingMinutes(
    (remaining.inMilliseconds / 60000).ceil(),
  );
}
