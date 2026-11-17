import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../l10n/generated/app_localizations.dart';

/// Displays recognizable language autonyms in the shared Forui menu surface.
final class LanguageButton extends StatelessWidget {
  const LanguageButton({required this.onSelected, this.buttonSize, super.key});
  final ValueChanged<Locale> onSelected;
  final double? buttonSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languages = [
      (const Locale('en'), l10n.englishLanguage),
      (const Locale('zh', 'CN'), l10n.simplifiedChineseLanguage),
      (const Locale('zh', 'TW'), l10n.traditionalChineseLanguage),
    ];
    return SizedBox.square(
      dimension: buttonSize ?? context.theme.style.sizes.tile,
      child: FPopoverMenu.tiles(
        menuAnchor: Alignment.topLeft,
        childAnchor: Alignment.bottomLeft,
        menuBuilder: (context, controller, _) => [
          FTileGroup(
            children: [
              for (final (locale, label) in languages)
                FTile(
                  title: Text(label),
                  selected: Localizations.localeOf(context) == locale,
                  onPress: () async {
                    await controller.hide();
                    onSelected(locale);
                  },
                ),
            ],
          ),
        ],
        builder: (context, controller, _) => FButton.icon(
          variant: FButtonVariant.ghost,
          semanticsLabel: l10n.language,
          onPress: controller.toggle,
          child: const Icon(FLucideIcons.languages, size: 20),
        ),
      ),
    );
  }
}
