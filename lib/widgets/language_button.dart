import 'package:flutter/material.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';

/// Displays the supported locales using their native names.
final class LanguageButton extends StatelessWidget {
  const LanguageButton({required this.onSelected, super.key});

  final ValueChanged<Locale> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Language options use autonyms rather than translated names. This keeps
    // every language recognizable even when the current interface language is
    // unfamiliar to the user.
    return PopupMenuButton<Locale>(
      tooltip: l10n.language,
      icon: const Icon(Icons.language_outlined),
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
  }
}
