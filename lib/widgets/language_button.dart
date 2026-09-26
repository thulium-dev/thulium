import 'package:flutter/material.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';

/// Displays the supported locales using their native names.
final class LanguageButton extends StatelessWidget {
  const LanguageButton({required this.onSelected, this.buttonSize, super.key});

  final ValueChanged<Locale> onSelected;
  final double? buttonSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Language options use autonyms rather than translated names. This keeps
    // every language recognizable even when the current interface language is
    // unfamiliar to the user.
    final button = PopupMenuButton<Locale>(
      tooltip: l10n.language,
      icon: const Icon(Icons.language_outlined),
      iconSize: buttonSize == null ? null : 20,
      padding: buttonSize == null ? const EdgeInsets.all(8) : EdgeInsets.zero,
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: const Locale('en'),
          child: Text(l10n.englishLanguage),
        ),
        PopupMenuItem(
          value: const Locale('zh', 'CN'),
          child: Text(l10n.simplifiedChineseLanguage),
        ),
        PopupMenuItem(
          value: const Locale('zh', 'TW'),
          child: Text(l10n.traditionalChineseLanguage),
        ),
      ],
    );
    return buttonSize == null
        ? button
        : SizedBox.square(dimension: buttonSize, child: button);
  }
}
