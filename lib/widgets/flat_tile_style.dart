import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// Keep only the group's internal dividers, without a surrounding card border.
const flatTileGroupStyle = FTileGroupStyleDelta.delta(
  decoration: DecorationDelta.value(BoxDecoration()),
);

/// Navigation rows stay on the page surface, including while pressed/hovered.
/// Forui's keyboard focus outline is retained independently of the background.
FItemStyleDelta flatTileStyle(
  FThemeData theme, {
  bool highlightOnInteraction = false,
}) => FItemStyleDelta.delta(
  padding: const EdgeInsetsGeometryDelta.value(EdgeInsets.zero),
  rawContentStyle: const FRawItemContentStyleDelta.delta(
    padding: EdgeInsetsGeometryDelta.value(EdgeInsets.zero),
  ),
  backgroundColor: FVariantsValueDelta.delta([
    FVariantValueDeltaOperation.all(theme.colors.background),
  ]),
  contentDecoration: FVariantsDelta.delta([
    if (highlightOnInteraction)
      FVariantOperation.base(
        DecorationDelta.shapeDelta(color: theme.colors.background),
      )
    else
      FVariantOperation.all(
        DecorationDelta.shapeDelta(color: theme.colors.background),
      ),
  ]),
);
