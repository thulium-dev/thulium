import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';

void main() {
  // The root widget owns localization, theming, and the shared application
  // shell. Keeping startup this small also makes it straightforward to reuse
  // the same domain packages from the future command-line client.
  runApp(const ThuliumApp());
}

class ThuliumApp extends StatefulWidget {
  const ThuliumApp({super.key});

  @override
  State<ThuliumApp> createState() => _ThuliumAppState();
}

class _ThuliumAppState extends State<ThuliumApp> {
  // The first release intentionally exposes only explicit light and dark
  // modes. The selected values are kept in memory until persistent settings
  // storage is introduced.
  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('en');

  @override
  Widget build(BuildContext context) {
    // Forui supplies the design tokens and interaction behavior, while the
    // approximate Material theme keeps Flutter widgets visually consistent.
    final lightTheme = FThemes.neutral.light.touch;
    final darkTheme = FThemes.neutral.dark.touch;
    final foruiTheme = _themeMode == ThemeMode.dark ? darkTheme : lightTheme;

    return MaterialApp(
      title: 'Thulium',
      theme: lightTheme.toApproximateMaterialTheme(),
      darkTheme: darkTheme.toApproximateMaterialTheme(),
      themeMode: _themeMode,
      locale: _locale,
      localizationsDelegates: [
        // AppLocalizations contains all user-facing Thulium strings. No
        // localized copy is hard-coded in the widget tree.
        ...AppLocalizations.localizationsDelegates,
        ...FLocalizations.localizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) =>
          FTheme(data: foruiTheme, child: child ?? const SizedBox.shrink()),
      home: HomePage(onLocaleSelected: _setLocale, onThemeToggle: _toggleTheme),
    );
  }

  void _setLocale(Locale locale) {
    setState(() => _locale = locale);
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }
}

class HomePage extends StatelessWidget {
  const HomePage({
    required this.onLocaleSelected,
    required this.onThemeToggle,
    super.key,
  });

  final ValueChanged<Locale> onLocaleSelected;
  final VoidCallback onThemeToggle;

  @override
  Widget build(BuildContext context) {
    // Resolve strings from the current locale at build time so the page reacts
    // immediately when the system locale changes.
    final l10n = AppLocalizations.of(context)!;

    return FScaffold(
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.welcomeTitle,
                        style: context.theme.typography.xl2,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.welcomeDescription,
                        style: context.theme.typography.md,
                      ),
                      const SizedBox(height: 24),
                      FButton(onPress: () {}, child: Text(l10n.explore)),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LanguageButton(onSelected: onLocaleSelected),
                  IconButton(
                    tooltip: l10n.theme,
                    icon: Icon(
                      Theme.of(context).brightness == Brightness.dark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                    ),
                    onPressed: onThemeToggle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({required this.onSelected});

  final ValueChanged<Locale> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Language options use autonyms rather than translated names. This keeps
    // every language recognizable even when the current interface language is
    // unfamiliar to the user, and remains scalable as more locales are added.
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
