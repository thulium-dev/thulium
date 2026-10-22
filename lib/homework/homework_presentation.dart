import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:thulium_campus/thulium_campus.dart';

/// Presentation-only capabilities. Null means the data layer cannot supply it.
/// Callbacks must perform real operations; the list never changes submission
/// state optimistically or invents grading metadata.
final class HomeworkActions {
  const HomeworkActions({this.openWeb, this.remindLater, this.markSubmitted});
  final Future<void> Function(LearnHomework)? openWeb;
  final Future<void> Function(LearnHomework)? remindLater;
  final Future<void> Function(LearnHomework)? markSubmitted;
}

double textContrast(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  return (a > b ? a + .05 : b + .05) / (a > b ? b + .05 : a + .05);
}

/// Choose only existing theme tokens; do not introduce a second palette.
Color readableSecondary(FThemeData theme) =>
    textContrast(theme.colors.mutedForeground, theme.colors.background) >= 4.5
    ? theme.colors.mutedForeground
    : theme.colors.foreground;

Color destructiveBadgeText(FThemeData theme) {
  return badgeTextOn(theme, theme.colors.destructive);
}

Color badgeTextOn(FThemeData theme, Color background) {
  final candidates = [
    theme.colors.destructiveForeground,
    theme.colors.foreground,
    theme.colors.background,
  ];
  return candidates.reduce(
    (a, b) =>
        textContrast(a, background) >= textContrast(b, background) ? a : b,
  );
}

/// Flat resting surface; interaction feedback continues to use Forui variants.
FItemStyleDelta homeworkTileStyle(FThemeData theme) => FItemStyleDelta.delta(
  backgroundColor: FVariantsValueDelta.delta([
    FVariantValueDeltaOperation.base(theme.colors.background),
  ]),
  contentDecoration: FVariantsDelta.delta([
    FVariantOperation.base(
      DecorationDelta.shapeDelta(color: theme.colors.background),
    ),
  ]),
);
