import 'package:forui/forui.dart';

/// Flat resting surface; interaction feedback continues to use Forui variants.
FItemStyleDelta flatTileStyle(FThemeData theme) => FItemStyleDelta.delta(
  backgroundColor: FVariantsValueDelta.delta([
    FVariantValueDeltaOperation.base(theme.colors.background),
  ]),
  contentDecoration: FVariantsDelta.delta([
    FVariantOperation.base(
      DecorationDelta.shapeDelta(color: theme.colors.background),
    ),
  ]),
);
