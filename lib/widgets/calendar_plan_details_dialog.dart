import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:intl/intl.dart';
import 'package:thulium_campus/thulium_campus.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';

/// Actions returned to the calendar, which owns all persistence and routing.
enum CalendarPlanAction { editOne, editSeries, cancelOne, deleteSeries }

/// Shows a dated occurrence before the user chooses any edit or removal.
Future<CalendarPlanAction?> showCalendarPlanDetailsDialog(
  BuildContext context,
  CalendarPlanEntry entry, {
  required String categoryName,
  required String repeatLabel,
}) {
  final l10n = AppLocalizations.of(context)!;
  final dateFormat = DateFormat.yMMMd(l10n.localeName);
  final timeFormat = DateFormat.Hm(l10n.localeName);
  final occurrence = entry.occurrence;
  return showFDialog<CalendarPlanAction>(
    context: context,
    useSafeArea: true,
    barrierDismissible: true,
    routeStyle: FDialogRouteStyle.inherit(colors: context.theme.colors),
    builder: (context, style, animation) => FDialog.raw(
      animation: animation,
      semanticsLabel: l10n.planDetailsTitle,
      builder: (context, style) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Tooltip(
                  message: l10n.planEditOccurrence,
                  child: FButton.icon(
                    key: const ValueKey('plan-edit-one'),
                    semanticsLabel: l10n.planEditOccurrence,
                    variant: FButtonVariant.ghost,
                    onPress: () =>
                        Navigator.of(context).pop(CalendarPlanAction.editOne),
                    child: const Icon(Icons.edit_outlined),
                  ),
                ),
                Text(l10n.planDetailsTitle, style: context.theme.typography.lg),
                Tooltip(
                  message: entry.repeats
                      ? l10n.planEditSeries
                      : l10n.planEditSeriesUnavailable,
                  child: FButton.icon(
                    key: const ValueKey('plan-edit-series'),
                    semanticsLabel: l10n.planEditSeries,
                    variant: FButtonVariant.ghost,
                    onPress: entry.repeats
                        ? () => Navigator.of(
                            context,
                          ).pop(CalendarPlanAction.editSeries)
                        : null,
                    child: const Icon(Icons.edit_calendar_outlined),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _detail(context, l10n.planName, occurrence.name),
            _detail(context, l10n.planLocation, occurrence.location),
            _detail(
              context,
              l10n.planTimeRange,
              '${dateFormat.format(occurrence.startsAt)} '
              '${timeFormat.format(occurrence.startsAt)}–'
              '${timeFormat.format(occurrence.endsAt)}',
            ),
            _detail(context, l10n.planCategory, categoryName),
            _detail(context, l10n.planRepeat, repeatLabel),
            const SizedBox(height: 16),
            FButton(
              variant: FButtonVariant.destructive,
              onPress: () =>
                  Navigator.of(context).pop(CalendarPlanAction.deleteSeries),
              child: Text(
                entry.repeats
                    ? l10n.planDeleteSeries
                    : l10n.planDeleteOccurrence,
              ),
            ),
            const SizedBox(height: 8),
            FButton(
              variant: FButtonVariant.outline,
              onPress: () =>
                  Navigator.of(context).pop(CalendarPlanAction.cancelOne),
              child: Text(l10n.planCancelOccurrence),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _detail(BuildContext context, String label, String value) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: context.theme.typography.xs.copyWith(
          color: context.theme.colors.mutedForeground,
        ),
      ),
      const SizedBox(height: 2),
      Text(value, style: context.theme.typography.sm),
    ],
  ),
);

/// Whether the user confirmed and wants to skip this warning in the future.
final class PlanConfirmationDecision {
  const PlanConfirmationDecision(this.skipNextTime);

  final bool skipNextTime;
}

/// Confirms the exact scope of deletion or one-off cancellation.
Future<PlanConfirmationDecision?> showPlanActionConfirmation(
  BuildContext context, {
  required bool deleteSeries,
  required bool repeating,
  required bool fetchedLesson,
}) {
  final l10n = AppLocalizations.of(context)!;
  final title = deleteSeries
      ? l10n.planConfirmDeleteTitle
      : l10n.planConfirmCancelTitle;
  final scope = fetchedLesson
      ? l10n.planConfirmFetchedLesson
      : deleteSeries && repeating
      ? l10n.planConfirmDeleteSeries
      : l10n.planConfirmOneOccurrence;
  var skipNextTime = false;
  return showFDialog<PlanConfirmationDecision>(
    context: context,
    builder: (context, style, animation) => StatefulBuilder(
      builder: (context, setDialogState) => FDialog.adaptive(
        animation: animation,
        title: Text(title),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(scope),
            const SizedBox(height: 16),
            FCheckbox(
              value: skipNextTime,
              onChange: (value) => setDialogState(() => skipNextTime = value),
              label: Text(l10n.planDontAskAgain),
            ),
          ],
        ),
        actions: [
          FButton(
            variant: deleteSeries
                ? FButtonVariant.destructive
                : FButtonVariant.primary,
            onPress: () => Navigator.of(
              context,
            ).pop(PlanConfirmationDecision(skipNextTime)),
            child: Text(
              deleteSeries ? l10n.planDeleteAction : l10n.planCancelAction,
            ),
          ),
          FButton(
            variant: FButtonVariant.outline,
            onPress: () => Navigator.of(context).pop(),
            child: Text(l10n.backAction),
          ),
        ],
      ),
    ),
  );
}
