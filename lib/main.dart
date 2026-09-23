import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';

void main() {
  // The root widget owns localization, theming, and the shared application
  // shell. Keeping startup this small also makes it straightforward to reuse
  // the same domain packages from the future command-line client.
  runApp(const ThuliumApp());
}

class ThuliumApp extends StatelessWidget {
  const ThuliumApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Forui supplies the design tokens and interaction behavior, while the
    // approximate Material theme keeps Flutter widgets visually consistent.
    final lightTheme = FThemes.neutral.light.touch;

    return MaterialApp(
      title: 'Thulium',
      theme: lightTheme.toApproximateMaterialTheme(),
      localizationsDelegates: [
        // AppLocalizations contains all user-facing Thulium strings. No
        // localized copy is hard-coded in the widget tree.
        ...AppLocalizations.localizationsDelegates,
        ...FLocalizations.localizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) =>
          FTheme(data: lightTheme, child: child ?? const SizedBox.shrink()),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Resolve strings from the current locale at build time so the page reacts
    // immediately when the system locale changes.
    final l10n = AppLocalizations.of(context)!;

    return FScaffold(
      header: Text(l10n.appTitle),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.welcomeTitle, style: context.theme.typography.xl2),
                const SizedBox(height: 8),
                Text(
                  l10n.welcomeDescription,
                  style: context.theme.typography.md,
                ),
                const SizedBox(height: 24),
                FButton(
                  onPress: () {},
                  prefix: Image.asset(
                    'assets/thulium.png',
                    width: 20,
                    height: 20,
                  ),
                  child: Text(l10n.explore),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
