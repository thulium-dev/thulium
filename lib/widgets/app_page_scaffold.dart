import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../l10n/generated/app_localizations.dart';

/// Stable chrome and a shared reading width across nested pages.
class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    required this.title,
    required this.child,
    this.actions = const [],
    this.fullBleed = false,
    this.maxWidth = 720,
    super.key,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final bool fullBleed;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return ColoredBox(
      color: theme.colors.background,
      child: FScaffold(
        childPad: false,
        header: FHeader.nested(
          title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
          prefixes: [
            FButton.icon(
              variant: FButtonVariant.ghost,
              semanticsLabel: AppLocalizations.of(context)!.backAction,
              onPress: () => Navigator.of(context).pop(),
              child: const Icon(FLucideIcons.arrowLeft),
            ),
          ],
          suffixes: actions,
        ),
        child: fullBleed
            ? child
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Padding(
                    padding: theme.style.pagePadding,
                    child: child,
                  ),
                ),
              ),
      ),
    );
  }
}
