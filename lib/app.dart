import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';

import 'pages/home_page.dart';

/// The root application widget owns global locale and theme state.
final class ThuliumApp extends StatefulWidget {
  const ThuliumApp({super.key});

  @override
  State<ThuliumApp> createState() => _ThuliumAppState();
}

final class _ThuliumAppState extends State<ThuliumApp> {
  // The initial value follows the operating system. Once the user presses
  // the theme button, the app switches to an explicit light or dark mode.
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('en');

  @override
  Widget build(BuildContext context) {
    final lightTheme = FThemes.neutral.light.touch;
    final darkTheme = FThemes.neutral.dark.touch;

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
      builder: (context, child) {
        // Resolve Forui from MaterialApp's effective brightness so
        // ThemeMode.system updates correctly when the OS theme changes.
        final foruiTheme = Theme.of(context).brightness == Brightness.dark
            ? darkTheme
            : lightTheme;
        return FTheme(
          data: foruiTheme,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: HomePage(onLocaleSelected: _setLocale, onThemeToggle: _toggleTheme),
    );
  }

  void _setLocale(Locale locale) {
    setState(() => _locale = locale);
  }

  void _toggleTheme() {
    setState(() {
      final isDark =
          _themeMode == ThemeMode.dark ||
          (_themeMode == ThemeMode.system &&
              WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                  Brightness.dark);
      _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    });
  }
}
