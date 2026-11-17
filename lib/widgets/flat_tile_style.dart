import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// Keep only the group's internal dividers, without a surrounding card border.
const flatTileGroupStyle = FTileGroupStyleDelta.delta(
  decoration: DecorationDelta.value(BoxDecoration()),
);

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
